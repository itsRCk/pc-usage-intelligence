# Test Fixtures

This directory contains deterministic fixtures used to validate PC Usage Intelligence across tracking, browser acquisition, privacy, classification, analytics, storage, synchronization, lifecycle recovery, performance, release safety, accessibility, and user-facing edge cases.

The suite currently contains **97 named scenarios** across nine fixture families.

## Fixture contract

Each fixture should define:

- `id` — stable fixture identifier.
- `scenario` — human-readable intent.
- `preconditions` — required initial state where applicable.
- `events` / `actions` — ordered synthetic observations/actions.
- `input` — optional initial data/configuration.
- `expected` — exact or invariant-based outcomes.
- `userFriction` — what a real user could experience.
- `severity` — impact if behavior regresses when applicable.
- `tags` — reusable selection labels when added to executable test harnesses.

Fixtures are deterministic and must not depend on the wall clock, live browser state, current installed applications, network availability, or production user data.

## Fixture groups

| File | Coverage |
|---|---|
| `tracking-core.json` | Foreground/visible time, switching, process/HWND identity, windows, titles, monitors |
| `lifecycle-time.json` | Lock, sleep, resume, crash/restart, storage gaps, clock/timezone/session boundaries |
| `browser-privacy.json` | Chrome/Edge/Firefox/Brave/Arc behavior, domains, titles, private browsing, permissions, degradation |
| `classification-analytics.json` | Classification, overrides, historical correction, aggregates, comparisons, timeline, reports |
| `storage-data-integrity.json` | Transactions, crashes, migrations, retention, deletion, corruption, export |
| `ipc-ui-runtime.json` | IPC negotiation, reconnects, malformed clients, authorization, backpressure, UI/runtime separation |
| `sync-distributed.json` | Offline sync, retries, deduplication, concurrent devices, conflicts, tombstones, migration, rollback |
| `security-cryptography.json` | Local secret boundaries, OAuth isolation, nonce safety, authenticated envelopes, replay, privacy, telemetry |
| `performance-release.json` | CPU/RAM/network budgets, large histories, browser load, endurance, install/update/rollback |
| `accessibility-ui-data-quality.json` | Reduced motion, keyboard, screen readers, semantic zoom, search, gaps, partial data, processing state |
| `user-friction-cases.json` | Real-world confusion, distrust, privacy anxiety, support burden, destructive-action risk |

## Cross-cutting requirements

### Correctness

The test harness must distinguish:

```text
known activity
known system state
tracking unavailable
browser-detail unavailable
unknown/uncertain identity
```

It must never convert uncertainty or unavailability into fabricated usage.

### Privacy

Private/incognito domain and page-title data must fail closed at every boundary: acquisition, normalization, storage, aggregation, sync, diagnostics, and export.

### Provenance

Tests should verify whether a value came from observed evidence, deterministic derivation, user override, statistical inference, import, or synchronization.

### User experience

A technically correct implementation still fails the fixture suite when it creates misleading totals, unexpected privacy disclosure, unexplained gaps, repeated permission prompts, surprising destructive effects, or unnecessary performance impact.

### Regression discipline

When a bug is found in production or manual testing:

1. Create or extend a deterministic fixture reproducing it.
2. Define the expected behavior and user-visible consequence.
3. Make the fixture fail before the fix.
4. Keep the fixture permanently as a regression case.

## Execution mapping

These fixture files are specification data, not executable tests by themselves. Test projects should load them and map each scenario to the appropriate unit, integration, replay, security, performance, or end-to-end harness.

The fixture suite must remain synchronized with the schemas and authoritative specifications. A breaking schema change requires affected fixture updates.
