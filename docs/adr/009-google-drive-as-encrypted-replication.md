# ADR-009: Use Google Drive as an Encrypted Replication Destination

- **Status:** Accepted
- **Date:** 2026-09-02

## Context

Users need optional backup, sync, recovery, and device migration. The product should avoid operating a proprietary usage-data cloud while allowing users to keep encrypted data in their own Google Drive.

## Decision

Use **Google Drive as an optional encrypted replication/storage destination**. Local SQLite remains the authoritative source of truth. Sync is asynchronous and must never block or degrade the tracking hot path.

Use the least-privileged Google Drive scope that supports the required application-owned data area. Prefer immutable/versioned encrypted objects plus a manifest over in-place mutation of large shared files. Maintain a durable local outbox and explicit reconciliation/checkpoints.

## Rationale

- User-owned storage aligns with the local-first privacy model.
- Avoids requiring a hosted usage-data database for the initial product.
- Google Drive provides practical cross-device availability and recovery.
- A downstream replication model isolates network/authentication failures from tracking.

## Consequences

- OAuth, Drive API behavior, quota handling, and revocation must be implemented and tested.
- Sync conflict/reconciliation semantics are part of the product's data model.
- Cloud deletion, local deletion, retention, and reset must be distinct operations.
- Sync depends on ADR-008 for encryption/key management.

## Validation

Use a fake remote before real Drive integration. Test offline operation, retries, duplicate delivery, partial upload/download, manifest rollback, concurrent devices, tombstones, account revocation, quota failures, and eventual convergence.
