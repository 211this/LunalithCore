# LunalithCore

LunalithCore is a provider-neutral Swift reference implementation for emotionally contextual, persistent, and correctable human–AI interaction.

It is not a model, a claim of consciousness, or a turnkey assistant. It is an orchestration algorithm that gives a host application deterministic state transitions, provenance-aware meaning, memory retrieval, retry-safe turn ordering, and budgeted context assembly.

## Why this exists

Humans are imperfect. We contradict ourselves, revise our understanding, speak emotionally, and repair mistakes. An interaction system should preserve context without turning every sentence into permanent truth. LunalithCore represents uncertainty, correction, provenance, and continuity directly.

## Included

- Bounded emotional-context state transitions
- Bounded relationship-continuity deltas supplied explicitly by the host
- Optional telemetry input that is ignored without explicit host-confirmed consent
- Meaning reinforcement, unresolved status, correction, and revision history
- Record-level memory retrieval with provenance and confidence
- FIFO turn lifecycle with retry-safe side-effect flags
- Whole-record prompt budgeting that preserves the current user message
- A provider-neutral actor that coordinates the pure algorithms
- Automated tests for the core invariants

## Deliberately excluded

- Provider clients and API credentials
- Camera, microphone, and screen capture
- Autonomous sensing or autonomous provider calls
- Speech synthesis and application UI
- Personal memories or Bridget-specific personality prompts
- Instructions that force a model to claim certainty, emotion, or memories
- A concrete persistence implementation

## Package use

Add this repository as a Swift Package dependency and import `LunalithCore`.

```swift
import LunalithCore

let core = LunalithCore()
let turn = LunalithTurn(message: "Humans are unfinished, but we mean well.")

if await core.submit(turn), let active = await core.beginNextTurn() {
    _ = await core.process(
        LunalithInput(text: active.message, sentiment: 0.65)
    )
    _ = await core.completeTurn(active.id)
}
```

The host owns provider calls, consent, persistence, UI publication, and safety policy. LunalithCore does not perform those operations.

Relationship values are contextual estimates, not facts about a person's inner state. The core never derives them secretly; a host must provide each explicit delta.

## Epistemic contract

Every stored record should say where it came from and what kind of knowledge it represents:

- `observed`: directly supplied or measured by an authorized host
- `inferred`: a fallible interpretation
- `userConfirmed`: confirmed by the user
- `corrected`: a correction that supersedes an earlier interpretation
- `unresolved`: deliberately unknown

Do not present inferred records as direct observations. Do not convert missing context into invented memory.

## Current status

Pre-release reference implementation. The package must be compiled and tested in Xcode before any public release because its construction environment did not contain a Swift toolchain.

## License status

No license has been granted yet. All rights are reserved until the creator deliberately selects and adds a license. See `RELEASE_CHECKLIST.md` before publishing.
