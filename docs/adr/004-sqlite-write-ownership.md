# ADR-004: Isolate SQLite Write Ownership

- **Status:** Proposed — benchmark required
- **Date:** 2026-09-02

## Context

The tracker produces time-sensitive observations and intervals while the UI and other components need read access. SQLite is the local source of truth, and reliability plus low write overhead are more important than maximizing concurrent writers.

Two primary patterns are under consideration:

- tracker-owned writes with other processes reading;
- multiple processes performing disciplined SQLite writes.

## Decision

Adopt **single-owner tracker writes as the preferred architecture**, subject to a benchmark spike before the storage implementation is finalized. The tracker should own authoritative event/interval persistence. Other components should use read models or controlled repository boundaries rather than independently writing tracking state.

The final concurrency decision must be recorded here after benchmarking if evidence favors a different design.

## Rationale

- Simplifies write ordering and crash recovery.
- Reduces lock contention and coordination complexity.
- Fits the tracker-as-source-of-observation model.
- Helps keep the hot tracking path predictable.

## Consequences

- UI edits and other mutations require explicit commands/repositories rather than arbitrary direct writes.
- Read access still needs SQLite concurrency discipline.
- Storage migrations and checkpoints must preserve tracker ownership.

## Validation

Benchmark sustained observation writes, batched transactions, concurrent analytical reads, large-history queries, crash recovery, WAL behavior, and worst-case contention on reference hardware.
