# Testing Specification Support

This directory contains the deterministic test-data layer that supports `docs/12-performance-qa-release-engineering.md` and the numbered engineering specifications.

## Contents

- `fixtures/` — deterministic replay, integration, security, performance, and user-friction scenarios.

## Relationship to the specifications

- `docs/05-system-architecture.md` defines subsystem boundaries.
- `docs/06-windows-tracking-engine.md` defines tracking semantics.
- `docs/07-data-architecture-storage.md` defines durable data semantics.
- `docs/08-browser-activity-acquisition.md` defines browser behavior and privacy boundaries.
- `docs/09-privacy-data-governance.md` defines collection, retention, deletion, and telemetry requirements.
- `docs/10-security-cryptography-architecture.md` defines security requirements.
- `docs/11-google-drive-sync-specification.md` defines distributed synchronization behavior.
- `docs/12-performance-qa-release-engineering.md` defines the quality gates.
- `fixtures/` turns those requirements into deterministic scenarios with expected outcomes and user-impact considerations.

## Rule

Every significant correctness bug, privacy regression, data-integrity issue, synchronization race, or user-facing edge case should become a permanent deterministic fixture before being considered closed.
