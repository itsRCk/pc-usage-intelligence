# ADR-007: Protect Local Sensitive Data at Rest

- **Status:** Proposed — threat model and benchmark required
- **Date:** 2026-09-02

## Context

Local usage history contains sensitive behavioral information. The product is local-first, so the database must remain useful offline while sensitive data is protected against unauthorized local access.

Windows provides OS-backed key/data protection facilities, but the protection mechanism must not be confused with the cross-device encryption architecture defined for sync.

## Decision

Protect sensitive local data using **Windows-backed cryptographic protection**, with the exact primitive and storage layout finalized through the security threat model and performance spike.

The local protection design must:

- avoid hardcoded application encryption keys;
- use cryptographically secure key generation;
- authenticate encrypted data where encryption is used;
- minimize plaintext copies and exposure;
- preserve unattended tracking without requiring repeated user interaction;
- remain independent of Google Drive sync encryption.

## Rationale

OS-backed protection provides a natural Windows trust boundary while avoiding credentials or secrets embedded in application binaries. Separating local protection from sync encryption prevents the Google account from becoming the sole security root for local data.

## Consequences

- Recovery behavior must be explicitly designed for password/account changes, profile migration, uninstall/reinstall, and device loss.
- The design must distinguish confidentiality from availability and recoverability.
- Local protection cannot by itself provide cross-device portability.

## Validation

Complete the threat model and benchmark candidate designs for startup cost, steady-state overhead, database access, key rotation, corruption recovery, and migration scenarios before marking this ADR accepted.
