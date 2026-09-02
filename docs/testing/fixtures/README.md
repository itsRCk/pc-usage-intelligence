# Test Fixtures

This directory contains deterministic fixtures used to validate PC Usage Intelligence across tracking, browser acquisition, privacy, classification, analytics, storage, synchronization, lifecycle recovery, performance, and user-facing edge cases.

## Fixture contract

Each fixture should define:

- `id` — stable fixture identifier.
- `area` — subsystem under test.
- `scenario` — human-readable intent.
- `preconditions` — required initial state.
- `events` — ordered synthetic observations/actions.
- `expected` — exact or invariant-based outcomes.
- `user_friction` — what a real user could experience.
- `severity` — impact if behavior regresses.
- `tags` — reusable selection labels.

Fixtures are deterministic and must not depend on the wall clock, live browser state, current installed applications, network availability, or production user data.

## Required fixture groups

| File | Coverage |
|---|---|
| `tracking-core.json` | Foreground, visible time, switching, identity, multi-monitor, gaps |
| `lifecycle-time.json` | Lock, sleep, resume, restart, clock changes, session boundaries |
| `browser-privacy.json` | Browser events, domain/title, private browsing, permissions, degradation |
| `classification-analytics.json` | Classification, historical corrections, aggregation, timeline and reports |
| `storage-data-integrity.json` | SQLite, migrations, retention, corruption, crash recovery, deletion |
| `ipc-ui-runtime.json` | IPC compatibility, reconnects, malformed messages, UI/runtime separation |
| `sync-distributed.json` | Offline sync, retries, deduplication, conflicts, devices, tombstones, recovery |
| `performance-release.json` | Performance workloads, endurance, resource regression, install/update behavior |
| `user-friction-cases.json` | Edge cases that can create confusion, distrust, support burden, or privacy anxiety |

## Test philosophy

The expected result must specify what the system is allowed to know, what it must refuse to infer, and what the user should see. A technically valid internal state is not sufficient if it produces misleading history or surprising privacy behavior.
