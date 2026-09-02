# PC Usage Intelligence — Implementation Roadmap

**Status:** Authoritative implementation planning baseline — pre-development  
**Date:** 2026-09-02  
**Platform:** Windows 10 and Windows 11

## 1. Purpose

This roadmap translates the product specifications, ADRs, schemas, and deterministic test fixtures into an implementation sequence.

It is optimized for:

- Tracking correctness before feature breadth.
- Low background resource usage.
- Explicit architectural boundaries.
- Small, reviewable AI-agent work packages.
- Continuous validation against replay fixtures.
- Early resolution of high-risk Windows/browser/privacy assumptions.
- A releasable local-first product before optional cloud complexity.

This is an execution roadmap, not a promise of calendar dates. Work should advance when the exit criteria of the current phase are satisfied.

## 2. Source of truth and planning authority

Implementation must follow this dependency order:

```text
PRD / Scope
    ↓
UX / Visual Design
    ↓
Architecture
    ↓
Schemas + ADRs
    ↓
Fixtures / test contracts
    ↓
Implementation
    ↓
QA / release gates
```

The numbered specifications define product/system behavior. ADRs explain material architectural choices. Schemas define machine-facing contracts. Fixtures define expected behavior. This roadmap defines sequencing and work ownership.

## 3. Definition of an implementation unit

A work package is considered **agent-sized** when it has:

- One clearly bounded responsibility.
- Explicit inputs and outputs.
- A small set of owning files/projects.
- No hidden dependency on unfinished subsystems.
- Tests that can be run independently.
- A clear acceptance condition.

An agent should not be asked to “build the tracker” or “build the dashboard” as a single task. Large capabilities are decomposed into contracts, adapters, state machines, repositories, views, and tests.

## 4. Non-negotiable implementation rules

1. The Tracking Runtime remains independent from the UI process.
2. Tracking does not require network access, Google authentication, or the dashboard.
3. Raw observations are preserved as evidence; derived data is rebuildable.
4. Tracking gaps are explicit and never silently converted into usage.
5. Foreground time and visible time remain separate semantics.
6. Private/unknown browser state fails closed for domain/title persistence.
7. SQLite is local source of truth.
8. Sync never blocks the tracking hot path.
9. Low-level Windows APIs remain behind narrow adapters.
10. No behavioral telemetry is introduced as an implementation convenience.
11. Every breaking schema/protocol change receives an explicit version update.
12. New functionality should gain a deterministic fixture before or with implementation.

## 5. Phase map

```text
Phase 0  Repository + engineering foundation
   ↓
Phase 1  Core domain/time/contracts
   ↓
Phase 2  Windows observation spike
   ↓
Phase 3  Tracking state machine + interval engine
   ↓
Phase 4  SQLite persistence + replay harness
   ↓
Phase 5  Identity resolution + lifecycle robustness
   ↓
Phase 6  Tracker runtime + process lifecycle + IPC
   ↓
Phase 7  Desktop shell + local analytical read model
   ↓
Phase 8  Timeline + core analytics
   ↓
Phase 9  Classification + historical correction
   ↓
Phase 10 Browser acquisition
   ↓
Phase 11 Privacy/security hardening
   ↓
Phase 12 Encrypted sync + device migration
   ↓
Phase 13 Performance/endurance/release engineering
   ↓
Phase 14 Public release
```

The phase sequence is intentionally **local product first, sync second**. Sync architecture is established early, but encrypted cloud synchronization should not delay proving the core local tracking system.

---

# 6. Phase 0 — Repository and engineering foundation

## Goal

Create the build/test infrastructure needed for all subsequent work.

## Work packages

### P0.1 — Solution scaffold

Create the .NET solution and project structure from Document 05.

Outputs:

- `src/PcUsageIntelligence.sln`
- Core/Data/Windows/Browser/Tracking/Sync/Desktop projects
- Test projects
- shared build configuration

### P0.2 — CI baseline

Add CI for:

- build
- unit tests
- schema validation
- formatting/static analysis

### P0.3 — Fixture loader

Create a reusable loader for `docs/testing/fixtures/*.json`.

The loader must support:

- deterministic timestamps
- synthetic IDs
- event ordering
- expected-result assertions
- fixture tags

### P0.4 — Clock abstractions

Introduce testable wall-clock and monotonic-clock interfaces before implementing elapsed-time logic.

### Exit criteria

- Clean build on supported development environment.
- Tests execute deterministically.
- Fixture loader can load and validate at least one tracking and one lifecycle fixture.
- No production code requires the real system clock directly.

---

# 7. Phase 1 — Core domain, time, and contracts

## Goal

Implement platform-neutral models and invariants.

## Work packages

### P1.1 — Domain IDs

Implement opaque ID/value-object generation and serialization.

### P1.2 — Time model

Implement:

- UTC instants
- durations
- half-open intervals
- monotonic timestamps
- interval overlap helpers

### P1.3 — Domain entities

Implement the core entity model from `docs/schemas/domain-model.md`.

### P1.4 — Enumerations/invariants

Implement compile-time/runtime validation for:

- interval dimensions
- lifecycle states
- browser states
- classification values
- provenance
- completion reasons
- data quality

### P1.5 — Contract serialization

Implement versioned serializers/deserializers for the JSON schemas.

### P1.6 — Property tests

Test interval arithmetic and ID invariants with generated values.

### Exit criteria

All domain-model invariants are executable in automated tests, and no platform-specific dependency enters Core.

---

# 8. Phase 2 — Windows observation spike

## Goal

Resolve the highest-risk native Windows assumptions before building the tracker around them.

## Work packages

### P2.1 — Foreground API adapter

Implement an interface around `GetForegroundWindow`.

### P2.2 — WinEvent hook adapter

Spike `SetWinEventHook` on a dedicated observer thread with a message loop.

Measure event latency and callback reliability.

### P2.3 — Window inventory adapter

Implement wrappers for top-level-window enumeration and relevant show/minimize/cloak state.

### P2.4 — Process identity adapter

Resolve PID → process start time → executable path/package identity where available.

### P2.5 — Display adapter

Resolve window → monitor/display association and topology changes.

### P2.6 — Lifecycle adapter

Spike lock/unlock/logon/logoff/suspend/resume notifications.

### P2.7 — Measurement harness

Record:

- event latency
- reconciliation duration
- API failure rates
- callback drops/reordering
- CPU
- memory
- wakeups

### Exit criteria

The Windows adapters can supply the normalized observation contract and the results are reproducible under automated integration tests. Any blocker becomes an ADR update rather than an implementation workaround.

---

# 9. Phase 3 — Tracking state machine and interval engine

## Goal

Turn observations into trustworthy foreground/visible/gap intervals without a database dependency.

## Work packages

### P3.1 — Observation normalizer

Normalize event and reconciliation inputs into the common tracking observation contract.

### P3.2 — Foreground state machine

Implement one authoritative foreground state machine.

### P3.3 — Visible state machine

Maintain visible-window state separately and support overlapping windows.

### P3.4 — Transition coalescer

Remove duplicate event/poll observations without changing semantics.

### P3.5 — Gap engine

Represent unavailable time explicitly.

### P3.6 — Lifecycle boundary integration

Stop/start interval continuity at lock, sleep, sign-out, shutdown, and tracker restart according to the tracking specification.

### P3.7 — Replay runner

Run fixture event streams through the state engine and compare expected timelines.

### Exit criteria

All `tracking-core.json` and `lifecycle-time.json` fixtures pass. Foreground intervals do not overlap within a stream. Visible intervals may overlap. Gaps are never fabricated as usage.

---

# 10. Phase 4 — SQLite persistence and replay infrastructure

## Goal

Make tracking durable without putting database behavior into the core state engine.

## Work packages

### P4.1 — SQLite initialization

Implement schema creation, migrations, foreign keys, and database lifecycle.

### P4.2 — Tracker write repository

Implement bounded batch writes for observations, lifecycle events, identities, and intervals.

### P4.3 — Read repositories

Implement efficient query interfaces for history and entity lookup.

### P4.4 — Checkpoint/recovery state

Persist tracker checkpoints sufficient to reason about crash recovery without extending unknown time.

### P4.5 — Retention/compaction primitives

Implement storage policy interfaces without hard-coding irreversible user behavior outside configuration.

### P4.6 — Database replay

Replay fixtures into temporary databases and compare resulting rows/intervals/aggregates.

### P4.7 — Integrity checker

Implement invariant validation against a live or fixture database.

### Exit criteria

`storage-data-integrity.json` passes. Crash/transaction/migration behavior is deterministic in tests. Database writes are batched and measurable.

---

# 11. Phase 5 — Identity resolution and lifecycle robustness

## Goal

Make raw Windows entities understandable and resilient to restarts/reuse.

## Work packages

### P5.1 — Process instance resolver

Implement PID + process-start identity handling and conservative fallback behavior.

### P5.2 — Window lifetime resolver

Detect HWND reuse and establish unique window-instance lifetimes.

### P5.3 — Canonical application resolver

Implement deterministic resolver layers from raw executable/package evidence.

### P5.4 — Identity rule store

Implement versioned effective-time identity rules.

### P5.5 — Lifecycle recovery

Implement tracker crash/restart, Windows session, display, and storage transitions as explicit state boundaries.

### P5.6 — Identity fixtures

Add/expand fixtures for:

- PID reuse
- HWND reuse
- process restart
- package/classic app differences
- launcher + child process families

### Exit criteria

Raw identity remains auditable. Canonical identity is stable enough for user-facing analytics. Reuse cases do not merge unrelated history.

---

# 12. Phase 6 — Tracking Runtime, lifecycle host, and IPC

## Goal

Turn the tracking engine into the continuously running product runtime.

## Work packages

### P6.1 — Runtime host

Implement startup, graceful shutdown, restart-safe state, and process-health reporting.

### P6.2 — Buffered event pipeline

Connect observations → state engine → persistence with bounded queues and backpressure rules.

### P6.3 — Health monitor

Expose tracking health without generating behavioral telemetry.

### P6.4 — Named-pipe server

Implement versioned UI/runtime IPC contracts.

### P6.5 — IPC security

Restrict the pipe to the intended user/session and validate client authorization.

### P6.6 — Reconnect behavior

Handle:

- UI start after tracker
- UI restart
- tracker restart
- pipe disconnect
- malformed messages

### P6.7 — Automatic runtime launch

Integrate the runtime with per-user application lifecycle/startup semantics.

### Exit criteria

The tracker continues when the UI is closed, remains operational offline, and records a real gap after a forced crash rather than inventing usage. `ipc-ui-runtime.json` passes.

---

# 13. Phase 7 — Desktop shell and analytical read model

## Goal

Create the native UI without destabilizing the tracker.

## Work packages

### P7.1 — WinUI shell

Implement navigation, application chrome, theme infrastructure, error boundaries, and startup lifecycle.

### P7.2 — Data-access layer

Create UI-facing analytical repositories/read models.

### P7.3 — Overview shell

Create the high-level layout without deep analytics first.

### P7.4 — Settings shell

Implement privacy/data, classification, appearance, diagnostics, and sync settings containers.

### P7.5 — Tracking status surface

Expose current tracker availability, offline state, and data-quality caveats without alarming language.

### Exit criteria

UI can start independently, connect/disconnect from the tracker safely, and display fixture-backed data. Tracker resource use remains within budget while UI is closed.

---

# 14. Phase 8 — Timeline and core analytics

## Goal

Build the product's main value surface on top of durable history.

## Work packages

### P8.1 — Timeline query engine

Support month/week/day/hour/15-minute/1-minute/event granularities.

### P8.2 — Timeline aggregation

Implement semantic zoom rather than merely scaling one raw chart.

### P8.3 — Application analytics

Implement:

- foreground totals
- visible totals
- rankings
- sessions
- switches
- average/longest sessions
- time-of-day patterns

### P8.4 — Browser summary placeholder

Support application-level browser usage before domain-level acquisition is complete.

### P8.5 — Daily/weekly/monthly aggregates

Implement rebuildable aggregate projections.

### P8.6 — Previous-period comparisons

Implement deterministic period boundaries and comparison calculations.

### P8.7 — Calendar history

Implement date-based navigation into day timelines.

### P8.8 — Data quality presentation

Ensure no-activity and tracking-unavailable states remain distinct.

### Exit criteria

`classification-analytics.json` and relevant timeline fixtures pass. The UI can reconstruct a known day/week/month exactly from deterministic fixture data.

---

# 15. Phase 9 — Classification and historical correction

## Goal

Add user-controlled interpretation without modifying raw evidence.

## Work packages

### P9.1 — Category taxonomy

Implement system taxonomy and hierarchy.

### P9.2 — Local rule engine

Implement deterministic application/domain classification.

### P9.3 — Confidence model

Represent confidence and unknown states without fake precision.

### P9.4 — User overrides

Implement persistent, effective-time overrides.

### P9.5 — Productivity/leisure dimension

Implement independently from category taxonomy.

### P9.6 — Historical invalidation

Change classification → invalidate affected derived data → rebuild.

### P9.7 — Reclassification fixtures

Cover:

- override creation
- override removal
- overlapping effective periods
- rule priority
- newly observed unknown apps
- renamed applications

### Exit criteria

User changes never rewrite raw observations. Historical analytics update deterministically. Classification behavior remains explainable through provenance/version metadata.

---

# 16. Phase 10 — Browser acquisition

## Goal

Add durable domain/page-title history while preserving browser privacy guarantees and independent degradation.

## Work packages

### P10.1 — Browser adapter interface

Implement the common adapter boundary.

### P10.2 — Extension/bridge contract

Implement the local browser-extension/native bridge path.

### P10.3 — Chromium family adapter

Implement shared capabilities, then browser-specific discovery/profile/privacy handling for Chrome, Edge, and Brave.

### P10.4 — Arc validation

Treat Arc as independently validated rather than assuming Chrome equivalence.

### P10.5 — Firefox adapter

Implement WebExtension-specific acquisition and private-mode capability handling.

### P10.6 — Domain normalizer

Implement deterministic hostname/domain normalization with special-scheme handling and maintained public-suffix behavior where required.

### P10.7 — Page-title policy

Implement independently switchable title collection and truncation/Unicode handling.

### P10.8 — Private browsing firewall

Enforce the fail-closed rule at the storage boundary, not only in the UI.

### P10.9 — Windows/browser correlation

Correlate browser windows to native window instances without title-only matching.

### P10.10 — Browser degradation UX

Surface browser-detail unavailable states without claiming browser application tracking has failed.

### Exit criteria

All launch-browser fixtures and privacy fixtures pass. Private/unknown browser contexts cannot produce durable domain/title data. Browser adapter failure never disables ordinary application tracking.

---

# 17. Phase 11 — Privacy and security hardening

## Goal

Turn documented privacy/security requirements into enforceable implementation boundaries.

## Work packages

### P11.1 — Data inventory enforcement

Map persisted fields to privacy classifications/purposes.

### P11.2 — Log redaction

Prevent raw domains, titles, secrets, tokens, and usage payloads from normal logs.

### P11.3 — Local secret storage

Implement protected storage for credentials and key material behind interfaces.

### P11.4 — Local database protection

Finalize the local-at-rest protection design after threat-model/performance evidence.

### P11.5 — IPC security audit

Test unauthorized clients, malformed payloads, protocol downgrade, and resource exhaustion.

### P11.6 — Network boundary audit

The tracker should have no ordinary network dependency. Add automated network-blocked tests.

### P11.7 — Privacy regression suite

Verify that private data cannot appear in:

- database rows
- sync payloads
- logs
- diagnostics
- exports

### Exit criteria

Security/privacy fixture suite passes, proposed ADRs have enough evidence to be accepted or remain explicitly deferred, and the tracker can operate with outbound network blocked.

---

# 18. Phase 12 — Encrypted sync and device migration

## Goal

Implement optional encrypted Google Drive replication without coupling it to tracking.

## Work packages

### P12.1 — Cryptographic interface layer

Implement narrow abstractions for:

- random generation
- AEAD encryption
- hashing
- key wrapping
- key storage

### P12.2 — Sync object serializer

Implement the versioned encrypted object envelope.

### P12.3 — Fake remote store

Implement an in-memory/local fake Drive backend before real API integration.

### P12.4 — Durable outbox

Implement retryable local sync mutations.

### P12.5 — Merge engine

Implement deterministic deduplication, append merges, user-edit conflict semantics, and tombstones.

### P12.6 — Manifest/reconciliation

Implement staged download, validation, merge, checkpoint, and recovery.

### P12.7 — Key management

Implement the finalized dataset encryption root, epochs, device authorization, recovery, and revocation model.

### P12.8 — Google OAuth

Integrate official desktop OAuth flow and protected credential storage.

### P12.9 — Google Drive adapter

Implement least-privilege storage access, upload/download, retry/rate-limit handling, and remote namespace management.

### P12.10 — Multi-device migration

Support:

- new device enrollment
- device continuity
- device revocation
- lost-device scenarios
- duplicate local history

### Exit criteria

`sync-distributed.json` and `security-cryptography.json` pass. Sync can be disabled or offline without affecting tracking. Corrupted remote objects cannot damage local data. Two devices converge under supported mutation semantics.

---

# 19. Phase 13 — Performance, endurance, and release engineering

## Goal

Prove that the product remains accurate and nearly invisible in long-running real-world use.

## Work packages

### P13.1 — Performance instrumentation

Measure CPU, RAM, wakeups, disk writes, queue depth, SQLite latency, IPC, browser bridge, encryption, and analytics query latency.

### P13.2 — Reference hardware benchmarks

Run Tier A/B/C hardware tests under Windows 10 and Windows 11.

### P13.3 — Tracker endurance

Run 7-day pre-release and 30-day major-release endurance tests.

### P13.4 — UI scalability

Test large histories, semantic zoom, virtualization, and long timelines.

### P13.5 — Resource regression gates

Fail CI/release review when established budgets are materially exceeded without explicit approval.

### P13.6 — Packaging

Validate Store and standalone packaging paths.

### P13.7 — Update/rollback

Test upgrade, interrupted update, rollback, data preservation, and runtime relaunch.

### P13.8 — Accessibility/visual regression

Validate keyboard navigation, text scaling, contrast, screen-reader behavior, reduced motion, and timeline nonvisual summaries.

### P13.9 — Supply-chain/release provenance

Validate signing, dependency audit, reproducible build metadata, and artifact provenance.

### Exit criteria

All release-critical fixtures pass; no unexplained resource trend; privacy/network tests pass; installation/update/uninstall behavior is safe; release criteria in Document 12 are satisfied.

---

# 20. Phase 14 — Public release

## Release candidate gates

### Gate A — Correctness

- Core tracking fixtures pass.
- Lifecycle fixtures pass.
- Browser/privacy fixtures pass.
- Classification/analytics fixtures pass.
- Storage integrity fixtures pass.
- IPC fixtures pass.
- Security/sync fixtures pass where enabled.

### Gate B — Performance

- Tracker meets CPU/RAM targets.
- Disk writes are bounded/batched.
- No unexpected network activity in local-only mode.
- Long-run memory is stable.

### Gate C — Privacy

- No behavioral telemetry by default.
- Private browser data cannot leak into durable storage.
- Diagnostics are opt-in.
- User deletion semantics are correct.
- Sync is explicitly enabled and encrypted.

### Gate D — User experience

- First-run path is understandable.
- Missing browser permissions do not create excessive friction.
- Tracking gaps are explained without alarming the user.
- Classification corrections are quick and reversible.
- Sync/account states are distinguishable.
- Destructive actions clearly state consequences.

### Gate E — Distribution

- Store package validated.
- Standalone installer validated.
- Automatic update path validated.
- Rollback and data preservation validated.

Only after all gates pass should the build be considered a public-release candidate.

---

# 21. Parallelization strategy for AI agents

Parallel work is encouraged only when contracts are already stable.

## Safe parallel groups

After Phase 1:

```text
Windows adapter work ─────────┐
SQLite repositories ──────────┼─ parallel
Fixture expansion ────────────┘
```

After Phase 6:

```text
UI shell
Analytics read models
Classification engine
Performance harness
```

can progress in parallel behind stable contracts.

After Phase 10:

```text
Privacy hardening
Crypto implementation
Sync fake remote
Browser compatibility
```

can proceed in parallel where interfaces are already defined.

## Unsafe parallelization

Do not concurrently change:

- domain semantics and their fixtures;
- schema contracts without coordinating migration work;
- interval semantics while implementing analytics against those semantics;
- sync merge rules and tombstones independently;
- browser privacy behavior in both adapter and storage layers without a single owner;
- IPC message contracts from multiple branches without version coordination.

---

# 22. AI-agent task template

Every implementation task should provide the agent:

```text
Task ID
Objective
Relevant specifications
Relevant ADRs
Relevant schemas
Relevant fixtures
Allowed files/projects
Forbidden architectural changes
Implementation requirements
Tests to add/run
Acceptance criteria
```

Example:

```text
Task: P3.2 Foreground State Machine

Read:
- docs/06-windows-tracking-engine.md
- docs/schemas/domain-model.md
- docs/schemas/tracking-observation.schema.json
- docs/testing/fixtures/tracking-core.json
- docs/adr/003-foreground-visible-tracking.md

Implement:
- platform-neutral foreground state machine

Do not:
- call Win32 APIs directly
- write SQLite records
- invent alternate duration semantics

Verify:
- foreground switching fixtures
- duplicate event handling
- null/unknown foreground handling
- interval non-overlap invariant
```

This pattern should be used for all agent-assigned implementation work.

---

# 23. Definition of Ready for a work package

Before implementation starts, confirm:

- Owning specification identified.
- Relevant ADRs identified.
- Input/output schemas identified.
- Existing fixtures identified.
- Dependencies complete.
- Acceptance criteria written.
- Architectural boundaries known.

A task that fails these conditions should be refined before being assigned to an agent.

# 24. Definition of Done for a work package

A work package is complete only when:

1. Implementation is isolated to its intended boundary.
2. Unit/integration tests exist.
3. Relevant deterministic fixtures pass.
4. Error/degraded behavior is covered.
5. User-facing friction is considered where applicable.
6. No prohibited telemetry/network behavior was introduced.
7. Performance impact is measured when touching the hot path.
8. Schemas remain compatible or were versioned appropriately.
9. Documentation/ADR updates are made when a decision changed.
10. The change can be understood and operated by another AI agent without hidden context.

---

# 25. First implementation batch

The recommended first coding batch is intentionally narrow:

```text
1. Solution scaffold
2. Core domain/time primitives
3. Fixture loader + replay harness
4. Windows observation interfaces
5. Foreground Win32 spike
6. Basic SQLite initialization
7. Foreground interval engine
8. First end-to-end deterministic fixture
```

Do not begin with the dashboard.

The first demonstrable milestone should be:

```text
Windows foreground changes
        ↓
normalized observations
        ↓
interval engine
        ↓
SQLite
        ↓
fixture replay / verification
```

Once that pipeline is trustworthy, UI work becomes substantially safer because the application can render a proven local history model rather than defining behavior accidentally through presentation code.

---

# 26. Milestone definitions

### M0 — Engineering foundation

Build/test/schema infrastructure exists.

### M1 — Deterministic tracking kernel

Observations can be replayed into correct foreground/visible/gap intervals.

### M2 — Durable tracker

The user-session runtime continuously records to SQLite and survives UI closure/restart.

### M3 — First useful product

Overview + application history + timeline provide meaningful local usage history.

### M4 — Intelligent history

Classification, corrections, analytics, browser/domain detail, and reports are functional.

### M5 — Private sync

Encrypted Google Drive sync, device continuity, recovery, and deletion semantics work.

### M6 — Release candidate

Performance, endurance, privacy, accessibility, packaging, updates, and release gates pass.

---

# 27. Highest-risk items to resolve early

The following should receive spikes before large-scale implementation:

1. Foreground event/reconciliation reliability.
2. Visible-window semantics and multi-monitor behavior.
3. PID/HWND reuse handling.
4. SQLite write ownership and concurrency.
5. Tracker startup/lifecycle reliability under packaging modes.
6. Browser extension/bridge feasibility for every launch browser, especially Arc.
7. Private/incognito capability and fail-closed enforcement.
8. Local encryption performance and key protection.
9. E2EE recovery/device enrollment.
10. Google Drive object/manifest behavior and quota/retry behavior.

These are architectural risk reducers, not optional polish tasks.

---

# 28. Roadmap success condition

The roadmap is successful when implementation converges toward this end-to-end property:

```text
Install
  ↓
Tracker starts independently
  ↓
Windows/browser state is observed accurately
  ↓
Raw evidence is durably preserved
  ↓
Intervals and analytics are reproducible
  ↓
The UI explains history without inventing meaning
  ↓
Privacy boundaries hold under failures
  ↓
Optional sync replicates encrypted data safely
  ↓
Updates preserve history
  ↓
The tracker remains nearly invisible in resource usage
```

That is the product's real acceptance condition: **a month of trustworthy history without making the machine feel heavier.**
