import Foundation

/// Bounded continuity signals for a relationship over time.
///
/// These values are contextual estimates, not claims about human intent or emotion.
/// The host decides when and why to supply a delta.
public struct LunalithRelationshipState: Codable, Equatable, Sendable {
    public var rapport: Double
    public var trust: Double
    public var playfulness: Double
    public var friction: Double
    public var repair: Double
    public var novelty: Double
    public var momentum: Double
    public var uncertainty: Double
    public var engagement: Double
    public var interactionCount: Int
    public var lastUpdated: Date

    public init(
        rapport: Double = 0.50,
        trust: Double = 0.50,
        playfulness: Double = 0.30,
        friction: Double = 0.10,
        repair: Double = 0,
        novelty: Double = 0.50,
        momentum: Double = 0.40,
        uncertainty: Double = 0.20,
        engagement: Double = 0.50,
        interactionCount: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.rapport = rapport.lunalithClamped01
        self.trust = trust.lunalithClamped01
        self.playfulness = playfulness.lunalithClamped01
        self.friction = friction.lunalithClamped01
        self.repair = repair.lunalithClamped01
        self.novelty = novelty.lunalithClamped01
        self.momentum = momentum.lunalithClamped01
        self.uncertainty = uncertainty.lunalithClamped01
        self.engagement = engagement.lunalithClamped01
        self.interactionCount = max(0, interactionCount)
        self.lastUpdated = lastUpdated
    }

    public static func baseline(at timestamp: Date = Date()) -> Self {
        .init(lastUpdated: timestamp)
    }

    public mutating func apply(_ delta: LunalithRelationshipDelta, at timestamp: Date = Date()) {
        rapport = (rapport + delta.rapport).lunalithClamped01
        trust = (trust + delta.trust).lunalithClamped01
        playfulness = (playfulness + delta.playfulness).lunalithClamped01
        friction = (friction + delta.friction).lunalithClamped01
        repair = (repair + delta.repair).lunalithClamped01
        novelty = (novelty + delta.novelty).lunalithClamped01
        momentum = (momentum + delta.momentum).lunalithClamped01
        uncertainty = (uncertainty + delta.uncertainty).lunalithClamped01
        engagement = (engagement + delta.engagement).lunalithClamped01
        interactionCount += 1
        lastUpdated = timestamp
    }
}

public struct LunalithRelationshipDelta: Codable, Equatable, Sendable {
    public var rapport: Double
    public var trust: Double
    public var playfulness: Double
    public var friction: Double
    public var repair: Double
    public var novelty: Double
    public var momentum: Double
    public var uncertainty: Double
    public var engagement: Double

    public init(
        rapport: Double = 0,
        trust: Double = 0,
        playfulness: Double = 0,
        friction: Double = 0,
        repair: Double = 0,
        novelty: Double = 0,
        momentum: Double = 0,
        uncertainty: Double = 0,
        engagement: Double = 0
    ) {
        self.rapport = rapport
        self.trust = trust
        self.playfulness = playfulness
        self.friction = friction
        self.repair = repair
        self.novelty = novelty
        self.momentum = momentum
        self.uncertainty = uncertainty
        self.engagement = engagement
    }
}
