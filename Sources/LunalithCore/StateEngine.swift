import Foundation

public struct LunalithState: Codable, Equatable, Sendable {
    public var focus: String
    public var valence: Double
    public var arousal: Double
    public var resonance: Double
    public var velocity: Double
    public var momentum: Double
    public var interactionCount: Int
    public var lastUpdated: Date

    public init(
        focus: String = "Harmonic Baseline",
        valence: Double = 0,
        arousal: Double = 0.4,
        resonance: Double = 0.5,
        velocity: Double = 1,
        momentum: Double = 0.5,
        interactionCount: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.focus = focus
        self.valence = valence.lunalithClampedSigned
        self.arousal = arousal.lunalithClamped01
        self.resonance = resonance.lunalithClamped01
        self.velocity = min(2, max(0.2, velocity))
        self.momentum = momentum.lunalithClamped01
        self.interactionCount = max(0, interactionCount)
        self.lastUpdated = lastUpdated
    }
}

/// Telemetry is optional and is ignored unless the host confirms that consent is active.
/// LunalithCore never acquires telemetry itself.
public struct LunalithTelemetry: Codable, Equatable, Sendable {
    public var normalizedArousal: Double?
    public var consentGranted: Bool

    public init(
        normalizedArousal: Double? = nil,
        consentGranted: Bool
    ) {
        self.normalizedArousal = normalizedArousal.map { $0.lunalithClamped01 }
        self.consentGranted = consentGranted
    }
}

public struct LunalithInput: Codable, Equatable, Sendable {
    public var text: String
    /// Host-supplied sentiment in -1...1. The core does not dictate a sentiment model.
    public var sentiment: Double
    public var telemetry: LunalithTelemetry?

    public init(text: String, sentiment: Double = 0, telemetry: LunalithTelemetry? = nil) {
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sentiment = sentiment.lunalithClampedSigned
        self.telemetry = telemetry
    }
}

public struct LunalithStateConfiguration: Codable, Equatable, Sendable {
    public var valenceLearningRate: Double
    public var arousalLearningRate: Double
    public var resonanceGain: Double
    public var resonanceDecay: Double
    public var momentumRetention: Double

    public init(
        valenceLearningRate: Double = 0.20,
        arousalLearningRate: Double = 0.25,
        resonanceGain: Double = 0.12,
        resonanceDecay: Double = 0.02,
        momentumRetention: Double = 0.80
    ) {
        self.valenceLearningRate = valenceLearningRate.lunalithClamped01
        self.arousalLearningRate = arousalLearningRate.lunalithClamped01
        self.resonanceGain = resonanceGain.lunalithClamped01
        self.resonanceDecay = resonanceDecay.lunalithClamped01
        self.momentumRetention = momentumRetention.lunalithClamped01
    }
}

public struct LunalithTransition: Codable, Equatable, Sendable {
    public let previous: LunalithState
    public let current: LunalithState
    public let telemetryApplied: Bool
    public let dominantConcept: String?

    public init(
        previous: LunalithState,
        current: LunalithState,
        telemetryApplied: Bool,
        dominantConcept: String?
    ) {
        self.previous = previous
        self.current = current
        self.telemetryApplied = telemetryApplied
        self.dominantConcept = dominantConcept
    }
}

public struct LunalithStateEngine: Sendable {
    public var configuration: LunalithStateConfiguration

    public init(configuration: LunalithStateConfiguration = .init()) {
        self.configuration = configuration
    }

    public func process(
        _ input: LunalithInput,
        from previous: LunalithState,
        at timestamp: Date = Date()
    ) -> LunalithTransition {
        let telemetryApplied = input.telemetry?.consentGranted == true
        let telemetryArousal = telemetryApplied ? input.telemetry?.normalizedArousal : nil
        let targetArousal = max(abs(input.sentiment), telemetryArousal ?? previous.arousal)
        let valenceDelta = input.sentiment - previous.valence

        var current = previous
        current.valence = (previous.valence + valenceDelta * configuration.valenceLearningRate)
            .lunalithClampedSigned
        current.arousal = blend(
            previous.arousal,
            targetArousal,
            rate: configuration.arousalLearningRate
        ).lunalithClamped01
        current.resonance = (
            previous.resonance * (1 - configuration.resonanceDecay)
            + abs(input.sentiment) * configuration.resonanceGain
        ).lunalithClamped01
        current.velocity = min(2, max(0.2, 0.2 + current.arousal * 1.8))
        current.momentum = (
            previous.momentum * configuration.momentumRetention
            + abs(valenceDelta) * (1 - configuration.momentumRetention)
        ).lunalithClamped01
        current.interactionCount += input.text.isEmpty ? 0 : 1
        current.lastUpdated = timestamp

        let concept = dominantConcept(in: input.text)
        if let concept {
            current.focus = "Resonating with '\(concept)'"
        }

        return LunalithTransition(
            previous: previous,
            current: current,
            telemetryApplied: telemetryApplied,
            dominantConcept: concept
        )
    }

    private func blend(_ current: Double, _ target: Double, rate: Double) -> Double {
        current + (target - current) * rate
    }

    private func dominantConcept(in text: String) -> String? {
        let stopWords: Set<String> = [
            "and", "are", "but", "for", "from", "have", "that", "the", "this", "was",
            "what", "when", "where", "which", "with", "you", "your"
        ]
        var counts: [String: Int] = [:]
        for token in LunalithText.words(text) where !stopWords.contains(token) {
            counts[token, default: 0] += 1
        }
        return counts.sorted {
            if $0.value == $1.value { return $0.key < $1.key }
            return $0.value > $1.value
        }.first?.key
    }
}
