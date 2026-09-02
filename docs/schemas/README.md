# Schemas

This directory contains the machine-oriented contracts used by PC Usage Intelligence implementation, tests, and synchronization.

The schemas are derived from the authoritative specifications (`docs/05` through `docs/11`) and MUST NOT redefine product behavior. When a schema needs a semantic change, update the owning specification first.

## Schema families

| File | Purpose |
|---|---|
| `domain-model.md` | Canonical entities, IDs, enums, time and provenance semantics |
| `sqlite-schema.sql` | Initial logical SQLite schema and indexes |
| `tracking-observation.schema.json` | Normalized Windows/tracker observation contract |
| `browser-events.schema.json` | Browser adapter event contract |
| `ipc-messages.schema.json` | Versioned UI ↔ tracker IPC messages |
| `sync-envelope.schema.json` | Encrypted sync object/envelope contract |
| `sync-mutations.schema.json` | Logical sync mutation records and tombstones |

## Conventions

- IDs are opaque strings to callers and MUST NOT be derived from SQLite row IDs.
- Timestamps are ISO-8601 UTC instants unless a schema explicitly says otherwise.
- Durations are integer milliseconds.
- Intervals are half-open: `[start, end)`.
- Raw observations are immutable evidence.
- Derived records are rebuildable.
- Unknown/uncertain values are represented explicitly rather than guessed.
- Private/incognito browser domain/title values are prohibited from normalized durable payloads.
- Schema versions are explicit and must be migrated deliberately.

## Authority and compatibility

Schemas are implementation contracts, not arbitrary examples. Any breaking change requires a schema-version change, migration/compatibility notes, and affected test-fixture updates.

The JSON documents use JSON Schema Draft 2020-12 semantics. The SQL file is the logical baseline; physical optimizations may be introduced only when they preserve the documented invariants.
