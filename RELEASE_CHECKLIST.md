# Release checklist

Do not publish this repository until every required item is complete.

## Build and tests

- [ ] `swift test` passes using the declared Swift tools version.
- [ ] Relationship-state baseline, clamping, and interaction-count tests pass.
- [ ] The package builds in a clean Xcode checkout on supported iOS and macOS versions.
- [ ] Strict concurrency diagnostics contain no package-owned warnings.
- [ ] Public API documentation builds successfully.

## Privacy and security

- [ ] Repository history contains no credentials, personal memories, telemetry, device identifiers, or private paths.
- [ ] Secret scanning reports no findings.
- [ ] Import and persistence examples validate untrusted data and fail safely.
- [ ] Security reporting contact is configured.

## Safety

- [ ] No provider, sensory capture, autonomous attention, or Bridget personality implementation is present.
- [ ] Inferences cannot be rendered as observations without an explicit host-side policy violation.
- [ ] Consent-denied telemetry is ignored by tests.
- [ ] Correction and deletion behavior is documented and tested.

## Governance and release

- [ ] The creator has deliberately selected a license after understanding its permissions and limitations.
- [ ] Attribution, project purpose, and non-consciousness claims are accurate.
- [ ] Known limitations are documented.
- [ ] The release commit is tagged and the archive checksum is published.
- [ ] A small trusted review has been completed before broad distribution.
