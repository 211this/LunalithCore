# Security policy

This pre-release repository contains no provider credentials, sensory capture, network client, or concrete persistence layer.

## Reporting

Before public release, replace this section with a private security-reporting address controlled by the maintainer. Do not ask reporters to disclose exploitable issues in a public issue.

## Host responsibilities

Integrators must protect provider credentials outside source control, validate imported data, constrain file access, encrypt sensitive records where appropriate, and apply least-privilege permissions.

Telemetry and conversational memory can be sensitive personal data. Collect the minimum necessary data, retain it only as long as necessary, and make deletion effective across primary storage and backups.
