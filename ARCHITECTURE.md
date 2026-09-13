# Architecture

LunalithCore separates five concerns that were intertwined in the original Bridget prototype.

## State engine

`LunalithStateEngine` is a pure deterministic transformation:

`previous state + user input + optional consented telemetry -> transition`

Values are bounded. Telemetry is never acquired by the package and is ignored unless the host marks consent as granted.

## Relationship state

`LunalithRelationshipState` preserves bounded continuity signals such as rapport, trust, repair, uncertainty, and engagement. A host must supply every delta explicitly. These values are estimates for interaction continuity, not claims about a person's internal state.

## Meaning graph

`LunalithMeaningGraph` stores statements with significance, confidence, provenance, and epistemic status. Equivalent active statements reinforce one record. Corrections supersede rather than erase the original and create explicit revision history.

## Memory retrieval

`LunalithMemoryRetriever` ranks complete records using lexical overlap, importance, confidence, recency, and relationship relevance. It structurally excludes the current user message, including a matching `Lunalith:` or `User:` line embedded inside a completed-turn record.

The retriever returns records, never an opaque formatted memory string.

## Turn ledger

`LunalithTurnLedger` enforces FIFO order and at most one active turn. A failed turn pauses later work. Its retry copy retains the same UUID while disabling state processing, user journaling, and natural-feedback routing so those side effects are not repeated.

The host remains responsible for performing side effects only at the transitions it chooses.

## Context assembly

`LunalithContextAssembler` accepts already-prioritized sections and includes complete records while space remains. It never slices a record and never truncates the current user message. When the user message alone exceeds the requested budget, the effective budget expands rather than altering the message.

Records render with epistemic status, provenance, and confidence so a host model can distinguish facts from interpretations.

## Coordinator

`LunalithCore` is an actor that owns a snapshot and turn ledger. It coordinates the pure algorithms but performs no networking, persistence, sensing, speech, or UI work.

## Host boundary

The host application must provide:

- user consent and permission handling;
- provider transport and provider-specific safety controls;
- encrypted or otherwise appropriate persistence;
- UI publication;
- deletion and export behavior;
- authentication, rate limiting, and abuse prevention.

These responsibilities are excluded intentionally so the reference algorithm cannot become a turnkey surveillance or autonomous-agent package.
