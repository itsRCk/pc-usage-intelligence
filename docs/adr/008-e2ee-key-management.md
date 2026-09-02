# ADR-008: Separate Sync Encryption Keys from Google Identity

- **Status:** Proposed — key-management design required
- **Date:** 2026-09-02

## Context

Google Drive is a storage destination, not the source of truth. Cloud copies must be end-to-end encrypted so Google Drive contains ciphertext rather than readable usage history. A Google account authenticates access to the storage destination but should not itself be treated as the encryption key.

Cross-device migration and recovery create a key-management problem: encryption must remain independent of any single Windows machine while avoiding an unusable recovery design.

## Decision

Use a **dataset-level encryption root separate from Google authentication**, with versioned key epochs and encrypted object envelopes. The exact user recovery/key-unwrapping mechanism remains a design item and must be finalized before sync is considered production-ready.

The cloud must never receive plaintext usage records or raw encryption keys. Encryption metadata required for processing is authenticated as associated data. Key rotation creates a new epoch while preserving the ability to decrypt valid historical objects according to retention policy.

## Rationale

- Compromise of Google storage access does not automatically reveal usage history.
- Account identity and data ownership remain separate concepts.
- Key epochs provide a controlled basis for rotation and revocation.
- The design supports device enrollment and migration without making a device's local key the permanent root.

## Consequences

- Recovery is a first-class security feature and cannot be left implicit.
- Device revocation and lost-device handling require explicit key-state transitions.
- Sync implementation depends on this ADR plus the threat model in the security specification.

## Validation

Threat-model key compromise, stolen Drive access, stolen device, lost device, account takeover, rollback, replay, key rotation, device enrollment/revocation, and recovery. Add property-based tests for envelope validation and key-epoch transitions.
