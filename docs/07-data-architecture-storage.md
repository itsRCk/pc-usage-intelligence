# Data Architecture & Storage Specification

**Product:** PC Usage Intelligence  
**Document:** 07 — Data Architecture & Storage Specification  
**Status:** Authoritative data/storage baseline — Pre-development  
**Parent documents:** `docs/01-product-requirements.md`, `docs/02-scope-feature-specification.md`, `docs/03-information-architecture-ux.md`, `docs/04-visual-design-system.md`, `docs/05-system-architecture.md`, `docs/06-windows-tracking-engine.md`  
**Platform:** Windows 10 and Windows 11  
**Primary store:** Local SQLite  
**Last updated:** 2026-09-02

---

# 1. Purpose

This document defines the local data architecture for PC Usage Intelligence.

It translates the tracking-engine semantics from Document 06 into a durable model that supports:

- High-resolution local history.
- Auditable raw observations.
- Foreground and visible intervals.
- Browser/domain/page-title history.
- Application/process/window identity.
- User classification overrides.
- Timeline reconstruction.
- Daily/weekly/monthly aggregation.
- Historical corrections.
- Retention and compaction.
- Crash recovery.
- Offline-first operation.
- Future encrypted Google Drive synchronization.
- Deterministic rebuild of derived analytics.

The design is intentionally split into **source data**, **normalized data**, **user configuration**, and **derived read models**.

The central rule is:

> Raw observation history is the evidence. Derived intervals and aggregates are rebuildable interpretations of that evidence.

This separation is what allows the product to improve its classification logic, repair historical records, change analytics definitions, and migrate schemas without throwing away the user's history.

---

# 2. Normative Language

- **MUST** — required.
- **MUST NOT** — prohibited.
- **SHOULD** — strong default.
- **MAY** — optional.

Schema details marked as implementation examples may change during migration design, but the semantic guarantees in this document must remain intact.

---

# 3. Data Architecture Principles

## 3.1 Local database is the source of truth

SQLite is authoritative for the device's local history.

Cloud synchronization is downstream and asynchronous. Google Drive is never treated as the live analytics database.

## 3.2 Separate observation from interpretation

The database distinguishes at least four layers:

```text
Observed
   ↓
Normalized
   ↓
Derived
   ↓
Presentation / analytics cache
```

Example:

```text
Raw: C:\Program Files\...\chrome.exe, PID 8124, HWND 0x1234
        ↓
Process instance + window instance
        ↓
Canonical application = Google Chrome
        ↓
Foreground interval = 10m 14s
        ↓
Daily Chrome total = 2h 41m
```

Changing the user's classification or the analytics definition must not require rewriting the original raw observation.

## 3.3 Immutable evidence where practical

Raw observations and lifecycle evidence should be append-only.

Derived records may be regenerated or replaced.

User-authored configuration/history corrections are stored as explicit changes rather than mutating evidence in place.

## 3.4 Time is the primary analytical axis

All usage data ultimately resolves to time intervals or events with precise timestamps.

Applications, domains, categories, devices, monitors, and productivity/leisure labels are dimensions over that timeline.

## 3.5 Gaps are data

The database must represent tracking gaps explicitly.

A day with:

```text
6h tracked
2h tracking unavailable
4h tracked
```

is not equivalent to a day with 12h tracked activity.

## 3.6 Derived data must be rebuildable

Aggregates and analytics caches should be disposable and reconstructible from durable source records plus versioned configuration.

---

# 4. Database Ownership and Access Model

## 4.1 Tracker writes

The Tracking Runtime is the authoritative writer for acquisition records and tracker lifecycle state.

This includes:

- Observations.
- Lifecycle events.
- Process instances.
- Window instances.
- Raw usage intervals.
- Health/checkpoint records.
- Browser observations received through the browser subsystem.

## 4.2 UI writes

The UI/application layer owns user-authored data such as:

- Application naming overrides.
- Category definitions.
- Productivity/leisure overrides.
- Browser grouping preferences.
- Retention settings.
- Privacy settings.
- Reports/configuration.
- Account/sync configuration metadata.

Direct writes from the UI to tracker-owned tables should be prohibited except through explicit application/data-layer interfaces.

## 4.3 Analytics reads

Analytics queries can read normalized and derived tables, but must not block the acquisition writer for unbounded periods.

Large analytical operations should operate over read-optimized projections, aggregates, or snapshot transactions rather than long-running queries over high-frequency raw tables whenever possible.

---

# 5. Logical Database Layers

Recommended SQLite logical layers:

```text
┌───────────────────────────────────────┐
│ Presentation / Analytics Cache        │
│ daily_stats / rankings / heatmaps     │
└──────────────────────▲────────────────┘
                       │ rebuild
┌──────────────────────┴────────────────┐
│ Derived Usage Model                    │
│ intervals / sessions / classifications│
└──────────────────────▲────────────────┘
                       │ normalize
┌──────────────────────┴────────────────┐
│ Normalized Observation Model           │
│ apps / processes / windows / events    │
└──────────────────────▲────────────────┘
                       │ preserve
┌──────────────────────┴────────────────┐
│ Raw Evidence                           │
│ observations / lifecycle / browser     │
└───────────────────────────────────────┘
```

The exact physical table layout may combine some layers for performance, but the logical distinction must remain visible in the schema and code.

---

# 6. Database Location and File Layout

The application should use a per-user application-data location appropriate to Windows rather than storing the primary database beside the executable.

Recommended logical files:

```text
PCUsageIntelligence/
  data/
    usage.db
    usage.db-wal
    usage.db-shm
  exports/
  backups/
  diagnostics/
```

The exact path is packaging-dependent and should be centralized in configuration.

The database may use SQLite WAL mode if benchmarked and validated for the chosen concurrency model.

WAL behavior must be covered by backup/recovery testing.

---

# 7. Core Entity Model

The primary entities are:

```text
Device
  │
  └── RuntimeSession
        │
        ├── ProcessInstance
        │      └── WindowInstance
        │
        ├── RawObservation
        ├── LifecycleEvent
        └── UsageInterval

CanonicalApplication
  ├── IdentityOverride
  └── ClassificationAssignment

BrowserIdentity
  ├── Domain
  └── PageTitleObservation

Category
  └── ClassificationAssignment

AggregateBucket
  ├── day
  ├── week
  ├── month
  └── optional hour
```

---

# 8. Device Model

A device identifies one installation/runtime origin participating in local or future synced history.

Conceptual fields:

```text
Device {
    device_id                 TEXT PRIMARY KEY
    installation_id           TEXT UNIQUE NOT NULL
    display_name              TEXT
    created_at_utc            TEXT NOT NULL
    first_seen_at_utc         TEXT NOT NULL
    last_seen_at_utc          TEXT
    app_version               TEXT
    os_family                 TEXT
}
```

`installation_id` is an application-generated random identifier and MUST NOT be derived solely from hardware identifiers.

It is used to attribute historical records to device origin and support migration/deduplication.

---

# 9. Runtime Session Model

A **runtime session** is one continuous execution context of the tracking runtime.

Conceptual fields:

```text
RuntimeSession {
    runtime_session_id        TEXT PRIMARY KEY
    device_id                 TEXT NOT NULL
    windows_session_id        INTEGER NOT NULL
    started_at_utc            TEXT NOT NULL
    ended_at_utc              TEXT
    monotonic_start           INTEGER
    monotonic_end             INTEGER
    shutdown_reason           TEXT
    clean_shutdown            INTEGER NOT NULL
    last_checkpoint_at_utc    TEXT
}
```

This is distinct from the Windows user session because the tracker can crash/restart within one Windows session.

A runtime session is the main boundary used for crash analysis and gap reconstruction.

---

# 10. Process Instance Model

A process instance is a concrete Windows process lifetime.

Conceptual fields:

```text
ProcessInstance {
    process_instance_id       TEXT PRIMARY KEY
    runtime_session_id        TEXT
    windows_session_id        INTEGER NOT NULL
    pid                       INTEGER NOT NULL
    process_start_at_utc      TEXT
    process_end_at_utc        TEXT
    executable_path           TEXT
    executable_name           TEXT
    package_identity          TEXT
    canonical_application_id  TEXT
    first_seen_at_utc         TEXT NOT NULL
    last_seen_at_utc          TEXT NOT NULL
}
```

A logical unique key should prevent accidental PID reuse merging, for example:

```text
(windows_session_id, pid, process_start_at_utc)
```

when process start time is available.

If start time is unavailable, the implementation must use a conservative fallback identity and preserve the uncertainty.

---

# 11. Window Instance Model

A window instance represents the lifetime of an HWND as observed by the tracker.

Conceptual fields:

```text
WindowInstance {
    window_instance_id        TEXT PRIMARY KEY
    process_instance_id       TEXT
    hwnd_value                INTEGER NOT NULL
    created_at_utc             TEXT
    destroyed_at_utc           TEXT
    first_seen_at_utc          TEXT NOT NULL
    last_seen_at_utc           TEXT NOT NULL
    initial_title              TEXT
    latest_title               TEXT
    canonical_application_id  TEXT
}
```

The database MUST NOT assume HWND values are globally unique over all time.

A new observed window lifetime must create a new `window_instance_id` when reuse is detected.

---

# 12. Application Identity Model

Canonical applications are user-facing entities.

Conceptual fields:

```text
CanonicalApplication {
    canonical_application_id   TEXT PRIMARY KEY
    stable_key                 TEXT UNIQUE NOT NULL
    display_name               TEXT NOT NULL
    default_icon_ref           TEXT
    source                     TEXT NOT NULL
    created_at_utc             TEXT NOT NULL
    archived_at_utc            TEXT
}
```

The `stable_key` should be deterministic from normalized app identity where possible.

It must not depend solely on the display name, because users may rename an application.

---

# 13. Identity Resolution History

Identity decisions can evolve.

The database should therefore preserve an effective mapping history rather than only one mutable row.

Conceptual model:

```text
ApplicationIdentityRule {
    rule_id                    TEXT PRIMARY KEY
    observed_identity_type    TEXT NOT NULL
    observed_identity_key     TEXT NOT NULL
    canonical_application_id  TEXT NOT NULL
    priority                   INTEGER NOT NULL
    confidence                 REAL
    created_at_utc             TEXT NOT NULL
    effective_from_utc         TEXT NOT NULL
    effective_to_utc           TEXT
    source                     TEXT NOT NULL
}
```

This enables:

- Automatic resolver rules.
- User overrides.
- Historical correction.
- Reproducible derived data.

The raw observed executable/process identity remains unchanged.

---

# 14. Category Model

Categories use a hierarchical taxonomy.

Conceptual fields:

```text
Category {
    category_id                TEXT PRIMARY KEY
    parent_category_id        TEXT
    stable_key                 TEXT UNIQUE NOT NULL
    display_name               TEXT NOT NULL
    system_defined             INTEGER NOT NULL
    archived_at_utc            TEXT
    created_at_utc             TEXT NOT NULL
}
```

Initial system categories:

```text
Development
Education
Gaming
Entertainment
Communication
Social
Creative
Productivity
Utilities
System
Other
```

Users can override category assignment without modifying the system taxonomy definition itself.

---

# 15. Productivity vs Leisure Dimension

Productivity/leisure is not the top-level category taxonomy.

It is an independent classification dimension.

Conceptual model:

```text
ProductivityClassification {
    classification_id          TEXT PRIMARY KEY
    target_type                TEXT NOT NULL
    target_id                 TEXT NOT NULL
    value                      TEXT NOT NULL
    confidence                 REAL
    source                     TEXT NOT NULL
    effective_from_utc         TEXT NOT NULL
    effective_to_utc           TEXT
    created_at_utc             TEXT NOT NULL
}
```

Allowed initial values:

```text
Productive
Leisure
Neutral
Unclassified
```

The implementation may later support additional values, but the independent-dimension rule remains.

---

# 16. Raw Observation Table

The raw observation table is the closest durable representation of what the tracker saw.

Conceptual schema:

```text
RawObservation {
    observation_id             TEXT PRIMARY KEY
    runtime_session_id        TEXT NOT NULL
    device_id                 TEXT NOT NULL

    observed_at_utc            TEXT NOT NULL
    monotonic_ticks            INTEGER NOT NULL

    source                     TEXT NOT NULL
    source_sequence            INTEGER

    windows_session_id         INTEGER
    hwnd_value                 INTEGER
    process_id                 INTEGER
    process_start_at_utc       TEXT

    executable_path            TEXT
    executable_name            TEXT
    package_identity           TEXT

    window_title               TEXT
    is_visible                 INTEGER
    is_minimized               INTEGER
    is_cloaked                 INTEGER

    monitor_key                TEXT
    foreground_state           INTEGER
    idle_state                 INTEGER

    lifecycle_state            TEXT NOT NULL
}
```

## 16.1 Raw observations are append-only

The tracker should treat raw observations as immutable.

Corrections happen at later layers.

## 16.2 Sampling policy

Not every reconciliation poll must become a durable raw row if it produces no meaningful new state and the retention model would make the resulting data unnecessarily large.

The acquisition layer should distinguish:

```text
Ephemeral observation
Durable observation
State transition
```

The choice of which no-change polls become durable is an implementation/retention decision, but the final database must preserve enough evidence to reconstruct all user-visible intervals and diagnose tracking behavior.

---

# 17. Lifecycle Event Table

Lifecycle events deserve their own append-only table because they are causally different from desktop observations.

Conceptual fields:

```text
LifecycleEvent {
    lifecycle_event_id        TEXT PRIMARY KEY
    runtime_session_id        TEXT NOT NULL
    device_id                 TEXT NOT NULL
    occurred_at_utc            TEXT NOT NULL
    monotonic_ticks            INTEGER
    event_type                 TEXT NOT NULL
    windows_session_id         INTEGER
    details_json               TEXT
}
```

Example event types:

```text
TrackerStarted
TrackerStopped
TrackerCrashDetected
SessionLocked
SessionUnlocked
SessionLogon
SessionLogoff
SessionConnected
SessionDisconnected
SystemSuspend
SystemResume
DisplayTopologyChanged
StorageUnavailable
StorageRecovered
ClockDiscontinuity
```

The event table is also a useful audit trail for timeline explanations and health diagnostics.

---

# 18. Usage Interval Model

The interval table is the principal analytical event table.

Conceptual fields:

```text
UsageInterval {
    interval_id               TEXT PRIMARY KEY
    device_id                 TEXT NOT NULL
    runtime_session_id        TEXT

    dimension                 TEXT NOT NULL
    start_at_utc              TEXT NOT NULL
    end_at_utc                TEXT

    start_monotonic_ticks     INTEGER
    end_monotonic_ticks       INTEGER
    duration_ms               INTEGER

    session_id                INTEGER
    window_instance_id        TEXT
    process_instance_id      TEXT
    canonical_application_id TEXT
    monitor_key               TEXT
    browser_identity_id       TEXT

    idle_state                TEXT
    provenance                TEXT NOT NULL
    completion_reason         TEXT NOT NULL

    source_version            INTEGER NOT NULL
    derived_at_utc             TEXT NOT NULL
}
```

## 18.1 Dimensions

At minimum:

```text
Foreground
Visible
Idle
Gap
```

Later dimensions may be added, but should not be introduced merely because they are convenient denormalizations.

## 18.2 Open intervals

An interval may briefly exist without `end_at_utc` while the tracker is actively observing it.

Before normal shutdown, all open intervals should be closed.

After crash recovery, any previously open persisted interval must be treated according to the last defensible checkpoint and may not be extended automatically to restart time.

## 18.3 Duration storage

Store a normalized integer duration such as milliseconds for reliable aggregation.

Do not use floating-point seconds as the primary persisted duration representation.

---

# 19. Gap Model

Tracking gaps should be represented as intervals using:

```text
UsageInterval.dimension = Gap
```

plus a reason code.

Possible reasons:

```text
TrackerCrash
TrackerRestart
StorageUnavailable
SessionUnavailable
Sleeping
Locked
ObserverUnavailable
ClockUncertain
Unknown
```

Whether `Locked`/`Sleeping` are stored as a distinct state or surfaced as a gap-like availability interval is a product/data-model choice, but analytics must always be able to distinguish them from zero activity.

A gap interval must never be assigned a canonical application.

---

# 20. Sessionization Model

A **usage session** is a derived contiguous foreground period for a canonical application.

Conceptual model:

```text
UsageSession {
    session_id               TEXT PRIMARY KEY
    canonical_application_id TEXT NOT NULL
    start_at_utc             TEXT NOT NULL
    end_at_utc               TEXT NOT NULL
    duration_ms               INTEGER NOT NULL
    first_interval_id        TEXT NOT NULL
    last_interval_id         TEXT NOT NULL
    session_break_reason     TEXT NOT NULL
    derived_version          INTEGER NOT NULL
}
```

The default session break rule is any boundary that terminates a canonical foreground interval, including:

- Application switch.
- Tracking gap.
- Lock.
- Sleep.
- Tracker shutdown.
- Session transition.

A same-app window switch does not necessarily create a new canonical application session if no higher-level session rule requires it.

---

# 21. Browser Data Model

Browser-domain data is modeled separately from core Windows identity.

Recommended entities:

```text
BrowserIdentity
Domain
BrowserPageObservation
BrowserWindowCorrelation
```

## 21.1 Browser identity

```text
BrowserIdentity {
    browser_identity_id       TEXT PRIMARY KEY
    browser_type              TEXT NOT NULL
    browser_profile_key       TEXT
    private_mode              INTEGER NOT NULL
}
```

## 21.2 Domain identity

```text
Domain {
    domain_id                  TEXT PRIMARY KEY
    normalized_domain          TEXT UNIQUE NOT NULL
    display_name               TEXT NOT NULL
}
```

Domain is the durable browser analytics identity.

## 21.3 Page observation

```text
BrowserPageObservation {
    browser_observation_id     TEXT PRIMARY KEY
    browser_identity_id        TEXT NOT NULL
    window_instance_id         TEXT
    observed_at_utc             TEXT NOT NULL
    url_hash_or_reference       TEXT
    domain_id                   TEXT
    page_title                  TEXT
    private_mode                INTEGER NOT NULL
    source                      TEXT NOT NULL
}
```

The exact URL storage strategy is governed by Document 09/10 because it has direct privacy/security implications.

For V1, normalized domain is the durable analytics identity; page title is optional high-resolution local metadata.

Private-mode observations must not persist domain/title data when the browser adapter cannot confidently establish that such data is allowed.

---

# 22. Browser/Windows Correlation

Browser observations may arrive at a different cadence from Windows foreground events.

The data layer must therefore permit correlation using:

```text
window_instance_id
process_instance_id
browser_identity_id
time range
```

Do not require every browser observation to correspond one-to-one with a Windows observation row.

A derived browser interval may be built from multiple browser observations and one or more Windows foreground intervals.

---

# 23. Monitor/Display Model

Recommended display entity:

```text
Display {
    display_id               TEXT PRIMARY KEY
    stable_key               TEXT NOT NULL
    device_name              TEXT
    edid_identity             TEXT
    first_seen_at_utc         TEXT NOT NULL
    last_seen_at_utc          TEXT NOT NULL
}
```

Topology snapshots may additionally store:

```text
DisplayTopologySnapshot {
    topology_version          INTEGER PRIMARY KEY
    observed_at_utc            TEXT NOT NULL
    topology_hash              TEXT NOT NULL
    details_json               TEXT NOT NULL
}
```

A display change increments the topology version and causes relevant open window monitor attribution to be re-evaluated.

---

# 24. User Configuration History

User-configurable settings that affect interpretation should be versioned rather than treated as stateless UI preferences.

Examples:

- Application classification override.
- Category assignment.
- Productivity/leisure classification.
- Browser grouping.
- Page-title collection enabled/disabled.
- Retention policy.
- Idle threshold.

A configuration record should contain:

```text
configuration_id
version
created_at_utc
effective_from_utc
effective_to_utc
source
payload
```

This makes historical derivation reproducible.

---

# 25. Data Versioning

The system should maintain explicit versions for:

1. Database schema.
2. Identity resolver rules.
3. Classification rules.
4. Derived interval algorithm.
5. Aggregate algorithm.
6. Analytics metric definitions.

Example:

```text
schema_version = 7
identity_rules_version = 4
classification_version = 3
interval_derivation_version = 2
aggregate_version = 5
```

Derived tables should record the relevant derivation version.

This avoids ambiguity when a user later views historical reports generated under an older algorithm.

---

# 26. Indexing Strategy

The high-volume tables require careful indexing.

## 26.1 Raw observations

Likely indexes:

```text
(runtime_session_id, observed_at_utc)
(device_id, observed_at_utc)
(windows_session_id, observed_at_utc)
(hwnd_value, observed_at_utc)
(process_id, process_start_at_utc)
```

Avoid indexing every nullable metadata column individually.

## 26.2 Usage intervals

Primary analytical indexes:

```text
(dimension, start_at_utc)
(canonical_application_id, start_at_utc)
(browser_identity_id, start_at_utc)
(monitor_key, start_at_utc)
(runtime_session_id, start_at_utc)
```

The most common timeline query is a time-range scan, so time-oriented indexes are essential.

## 26.3 Aggregates

Aggregate tables should use compact composite primary keys such as:

```text
(bucket_start_utc, dimension_key, entity_key, metric_version)
```

The final key design depends on whether aggregates are rebuilt in batches or incrementally maintained.

---

# 27. Retention Model

Retention must balance:

```text
History quality
Storage size
Privacy
Query performance
Rebuild capability
```

Recommended product policy:

- Recent high-resolution history: retained in full.
- Long-term raw observations: compacted only when the product can prove that required historical fidelity remains available.
- High-level intervals: retained much longer than raw poll-level observations.
- Daily/weekly/monthly aggregates: retained indefinitely while the user retains their history.

The exact durations should be configurable through advanced settings and finalized after measuring database growth from real workloads.

## 27.1 Suggested initial policy

As an implementation starting point, not a final user promise:

```text
Raw high-resolution observations: 90 days
Detailed intervals: indefinite while history retained
Daily/weekly/monthly aggregates: indefinite
Lifecycle/health events: 1 year or longer depending on privacy settings
```

The 90-day value MUST be revisited after storage benchmarks.

The product must never silently delete history against explicit user retention settings.

---

# 28. Compaction

Compaction should be deterministic and reversible only where the retained source model allows it.

Example:

```text
Raw polling observations
        ↓ compact
State transitions
        ↓ derive
Usage intervals
        ↓ aggregate
Daily statistics
```

Before deleting raw rows, the system should verify:

1. Required intervals have been successfully derived.
2. Aggregate rebuild requirements are satisfied.
3. No active repair job depends on the rows.
4. Backup/sync requirements are satisfied where applicable.
5. The retention policy permits deletion.

Compaction must be transactional at the logical unit being compacted.

---

# 29. Aggregation Architecture

Analytics should not repeatedly scan years of high-resolution raw data for every dashboard load.

Use layered aggregation:

```text
Raw / intervals
      ↓
Hourly aggregates
      ↓
Daily aggregates
      ↓
Weekly aggregates
      ↓
Monthly aggregates
```

Not every level must be physically materialized.

The implementation should benchmark which levels materially improve dashboard performance.

## 29.1 Daily aggregate example

```text
DailyApplicationAggregate {
    date_local
    canonical_application_id
    foreground_ms
    visible_ms
    idle_ms
    session_count
    switch_count
    productive_ms
    leisure_ms
    aggregate_version
}
```

## 29.2 Category aggregates

Category metrics should be derived from application classification at query/build time rather than duplicated permanently wherever practical.

If materialized, the classification version must be recorded.

---

# 30. Time-Zone and Local-Day Handling

Stored event timestamps should use UTC.

Local-day aggregates require the user's effective timezone at the time of calculation.

The system should preserve sufficient timezone context to correctly handle:

- DST transitions.
- Timezone changes.
- Travel between time zones.
- Rebuilding reports in a changed local timezone.

The database should not store only a naive local timestamp as the authoritative event time.

For daily analytics, a local-day key may be derived as:

```text
LocalDate = convert(ObservedUtc, effective_timezone)
```

The exact historical timezone model is part of analytics/data-governance implementation and must be tested around DST boundaries.

---

# 31. Timeline Query Model

The timeline UI requires progressively coarser/finer resolutions:

```text
Month
  ↓
Week
  ↓
Day
  ↓
Hour
  ↓
15 minute
  ↓
1 minute
  ↓
Individual event
```

The data layer should expose a common query contract:

```text
TimelineQuery {
    startUtc
    endUtc
    resolution
    filters
    dimensions
}
```

The repository decides whether to serve the result from:

- Raw intervals.
- Hourly aggregates.
- Daily aggregates.
- Derived timeline projections.

The UI must not know which physical table supplied the answer.

---

# 32. Data Correction Model

Historical correction is required without corrupting raw evidence.

Example:

```text
Automatic classification:
Chrome → Productivity

User correction:
Chrome → Leisure
```

The system stores the correction as a new effective rule.

Derived analytics affected by the correction should be invalidated/rebuilt for the affected time range.

## 32.1 Correction scope

A correction may target:

- Application identity.
- Category.
- Productivity/leisure.
- Browser grouping.
- Display identity.

## 32.2 Correction propagation

After a correction:

```text
User rule
   ↓
identity/classification resolver
   ↓
derived interval classification
   ↓
affected aggregate buckets
   ↓
analytics cache invalidation
```

Do not rewrite raw observation rows merely to make the dashboard look updated.

---

# 33. Idempotency and Deduplication

The database must tolerate repeated ingestion caused by:

- Tracker retries.
- Restart recovery.
- Sync reconciliation.
- Browser adapter retries.

Every appendable record should have a stable logical identifier or idempotency key.

Examples:

```text
observation_id
lifecycle_event_id
interval_id
browser_observation_id
```

For deterministic ingestion, a source sequence plus runtime session can form a deduplication key where the producer guarantees sequence uniqueness.

Cloud synchronization must not create a duplicate local event merely because the same ciphertext was encountered twice.

---

# 34. Database Transactions

Transactions must correspond to coherent state changes rather than individual API calls.

Example foreground transition transaction:

```text
BEGIN

close previous foreground interval
insert state transition
insert new foreground interval
update runtime checkpoint

COMMIT
```

The transaction should either make the state transition durable or make none of it durable.

Similarly, a crash-recovery repair should atomically:

```text
mark runtime session unexpectedly terminated
close prior open interval at checkpoint
insert gap interval
insert recovery lifecycle event
```

---

# 35. Checkpoints

Checkpoints bound the amount of data potentially lost after a hard crash.

Conceptual table:

```text
RuntimeCheckpoint {
    checkpoint_id              TEXT PRIMARY KEY
    runtime_session_id         TEXT NOT NULL
    recorded_at_utc            TEXT NOT NULL
    monotonic_ticks            INTEGER NOT NULL
    last_durable_sequence      INTEGER
    last_durable_observation   TEXT
    state_hash                  TEXT
}
```

A checkpoint is not itself usage data.

It is recovery metadata.

The implementation should target approximately a 30-second checkpoint cadence initially while combining the checkpoint with ordinary batch persistence whenever possible.

---

# 36. Crash Recovery Algorithm

At startup:

```text
1. Find most recent runtime session without clean shutdown.
2. Read last durable checkpoint.
3. Validate persisted interval consistency.
4. Close any persisted open intervals at checkpoint boundary.
5. Insert an explicit recovery/gap interval from the last proven boundary
   until current tracking becomes authoritative.
6. Mark previous runtime session as crashed/unclean.
7. Start new runtime session.
8. Reconstruct current state from live Windows observations.
9. Begin new intervals.
```

No historical usage is inferred merely because the same application is foreground at restart.

---

# 37. Database Integrity Checks

The application should run lightweight consistency checks periodically and after abnormal recovery.

Examples:

```text
Foreground intervals do not overlap within one tracked session.
Visible intervals may overlap.
Gap intervals never have application IDs.
end_at_utc >= start_at_utc.
duration_ms >= 0.
Every interval references valid device/runtime entities.
Process instances cannot share an impossible lifetime key.
Window instances do not reference nonexistent process instances.
Aggregate versions are known.
```

SQLite integrity checks should be used during diagnostics/recovery workflows, not on every foreground event.

---

# 38. Repair Procedures

The system should support a local repair operation for corrupted/unfinished derived data.

## 38.1 Rebuild derived data

```text
raw observations
        ↓
normalized state
        ↓
interval rebuild
        ↓
session rebuild
        ↓
classification
        ↓
aggregate rebuild
```

## 38.2 Targeted repair

Where possible, repair only the smallest affected time range.

For example:

```text
User changes classification at 2026-08-20.

Invalidate:
2026-08-20 → current
```

rather than rebuilding several years of history.

## 38.3 Full repair

A full rebuild command should exist for development/diagnostics and potentially for a user-facing recovery workflow.

The implementation must be deterministic from source records plus versioned rules.

---

# 39. Import/Export

The product should support user-controlled data export.

The export layer must be separate from the live database schema.

Recommended formats:

```text
CSV → simple analytical exports
JSON → structured event/history export
```

A future encrypted archive format can support complete migration.

Export should include:

- Time intervals.
- Canonical applications.
- Categories.
- Browser domains where permitted.
- User classifications.
- Device/session provenance where useful.

Raw secrets, authentication tokens, or encryption keys must never be included.

---

# 40. Deletion Semantics

Users can delete data.

Deletion must distinguish:

```text
Delete derived cache
Delete selected historical usage
Delete all local history
Delete account/sync copy
```

## 40.1 Selected historical deletion

When the user deletes a time range:

1. Delete or tombstone source records in that range according to retention/security design.
2. Invalidate derived intervals/aggregates intersecting the range.
3. Rebuild affected aggregates if needed.
4. Record deletion state without retaining the sensitive deleted payload.

## 40.2 Sync implications

Deletion semantics must propagate to synced devices through explicit deletion/tombstone records so that a previously uploaded encrypted record does not reappear during reconciliation.

Exact tombstone/key-destruction design belongs to Documents 09 and 10.

---

# 41. Local Database Security

The database itself is sensitive because it can contain detailed behavior history.

Security requirements:

- Store under the user's application-data boundary.
- Do not expose the DB through unauthenticated network interfaces.
- Do not log raw sensitive fields by default.
- Restrict IPC access to the local user/security boundary.
- Protect sync/export paths separately.
- Evaluate SQLCipher or Windows-protected key/material strategies in the security architecture before finalizing encryption at rest.

Database encryption is a security-architecture decision, not a justification for delaying the logical schema.

---

# 42. SQLite Operational Requirements

The initial storage engine is SQLite.

Requirements:

- Foreign-key enforcement enabled for production connections.
- Explicit transactions.
- Prepared statements/parameterized queries only.
- Schema migrations tracked in a metadata table.
- Busy/lock handling bounded.
- Long-running analytics queries cancellable where practical.
- Database vacuum/maintenance scheduled conservatively.
- WAL/checkpoint behavior benchmarked.

The tracker must never spin aggressively on `SQLITE_BUSY` or equivalent lock conditions.

---

# 43. Migration Strategy

Schema migrations are append-only version transitions.

Example:

```text
v1 → v2 → v3 → v4
```

Do not support arbitrary downgrade paths unless a concrete product requirement exists.

Each migration must define:

- Preconditions.
- Schema/data transformation.
- Postconditions.
- Backfill strategy.
- Rollback safety.
- Performance impact.
- Recovery behavior if interrupted.

Large backfills should be resumable and should not block the tracker for long periods.

## 43.1 Migration safety

Before a high-risk migration:

1. Ensure the database is in a known checkpointed state.
2. Make a local backup when practical.
3. Apply migration transactionally where feasible.
4. Validate integrity.
5. Record successful schema version.

---

# 44. Background Maintenance

Maintenance jobs include:

- Aggregate refresh.
- Compaction.
- Old observation cleanup.
- SQLite checkpoint/optimization.
- Integrity sampling.
- Sync preparation.
- Repair jobs.

Maintenance MUST yield to active tracking.

The tracker should not perform a large compaction transaction synchronously during an application switch.

A maintenance scheduler should have:

```text
priority
work estimate
cancellation
progress
last run
next eligible run
```

---

# 45. Read Models for UI

The UI should consume purpose-built repositories/view models rather than raw SQL.

Recommended read models:

```text
OverviewSummary
TimelineBucket
ApplicationSummary
ApplicationSessionSummary
BrowserDomainSummary
CategorySummary
ProductivityLeisureSummary
HeatmapCell
TrendPoint
InsightInput
TrackingHealthSummary
```

These should be generated from repositories that choose the most efficient physical data source.

---

# 46. Analytics Invalidation

Any change affecting derived results must produce an invalidation scope.

Conceptual model:

```text
InvalidationRequest {
    invalidation_id
    reason
    start_at_utc
    end_at_utc
    entity_type
    entity_id
    created_at_utc
    status
}
```

Examples:

```text
classification changed for Chrome
→ invalidate affected app/category aggregates

page-title setting changed
→ rebuild browser presentation model only

tracking interval repaired
→ rebuild affected time buckets
```

This prevents expensive full-database recomputation for localized edits.

---

# 47. Performance Targets for Storage

The storage layer must support the tracking engine's background constraints.

Initial targets:

| Metric | Target |
|---|---:|
| Normal foreground transition persistence | < 50 ms p95 end-to-end queue-to-durable target |
| Batch commit frequency | ~1–5 seconds under normal operation |
| Tracker write amplification | Minimized; benchmark before finalizing schema |
| Long analytics query impact on tracker | No observable acquisition stall |
| Database growth | Must be measured from representative 30-day workloads |
| Repair | Resumable for large histories |

The `<50 ms` figure is an engineering target, not a product-visible guarantee. The system can acknowledge a transition in memory before the batch becomes durable, provided crash semantics are correctly represented by checkpoints/gaps.

---

# 48. Storage Sizing Experiment

Before freezing retention defaults, run a representative 30-day workload containing:

- Several browsers.
- Frequent application switching.
- 1–3 monitors.
- Many visible windows.
- Typical developer/student usage.
- Gaming sessions.
- Sleep/lock cycles.

Measure:

```text
db size
WAL size
rows/day
rows/month
indexes size
writes/sec
bytes written/day
aggregate rebuild time
vacuum/maintenance cost
query p50/p95
```

Run the experiment with raw observations stored at candidate granularities.

Choose retention and compaction policy from measured results rather than assumptions.

---

# 49. Sync Readiness

Although synchronization is specified in later documents, the data model must already support it.

Every syncable logical record should have:

```text
stable global ID
origin device ID
created_at_utc
updated_at_utc where relevant
logical deletion/tombstone state where relevant
schema/record version
```

The database should not rely on SQLite `rowid` as a sync identity.

Records originating on different devices must be distinguishable even when their local timestamps overlap.

---

# 50. Device Migration Semantics

When a user moves to a new Windows device:

```text
Device A
   ↓
existing logical history
   ↓
Device B
```

The new installation receives a new `device_id`/installation identity.

The logical history remains one user's timeline after encrypted reconciliation.

Records retain device origin so the system can show:

```text
Desktop A
Laptop B
```

without splitting the user's historical analytics into unrelated accounts.

Deduplication must operate on stable record identity rather than timestamp equality alone.

---

# 51. AI-Agent Implementation Rules

To keep future coding agents from collapsing source and derived layers:

1. Never write analytics results into raw observation tables.
2. Never mutate raw process/window identity merely because a classification changed.
3. Never use a display name as the only application identity key.
4. Never use SQLite `rowid` as a cross-device identity.
5. Never infer tracked time from aggregate totals.
6. Never treat a gap as zero usage.
7. Never delete source records before derived products are proven rebuildable.
8. Never perform unbounded analytics scans on the acquisition writer's critical path.
9. Every new derived table must document its source-of-truth records and derivation version.
10. Every user correction that changes interpretation must be represented as explicit configuration/history.

---

# 52. Recommended Repository Interfaces

The data layer should expose typed contracts approximately like:

```text
IRawObservationRepository
IProcessInstanceRepository
IWindowInstanceRepository
ILifecycleEventRepository
IUsageIntervalRepository
ICanonicalApplicationRepository
IClassificationRepository
IBrowserObservationRepository
IAggregateRepository
IAnalyticsReadRepository
ICheckpointRepository
IMaintenanceRepository
IDataRepairService
IDataExportService
```

The tracker should depend on the smallest necessary interfaces.

For example:

```text
Tracking Runtime
    ↓
IUsageIntervalWriter
ICheckpointWriter
ILifecycleEventWriter
```

The UI should depend on read/query abstractions rather than tracker internals.

---

# 53. Testing Requirements

## 53.1 Schema tests

Verify:

- Foreign keys.
- Unique constraints.
- Required fields.
- Index presence.
- Migration ordering.
- Migration idempotency where supported.

## 53.2 Repository tests

Verify:

- Transaction boundaries.
- Idempotent inserts.
- Correct time-range queries.
- Overlapping visible intervals.
- Non-overlapping foreground queries.
- Classification effective-date behavior.
- Deletion/invalidation.

## 53.3 Rebuild tests

Given deterministic raw fixtures:

```text
raw input
→ interval derivation
→ aggregate build
```

must produce deterministic results.

Run rebuild twice and compare the result byte-for-byte where stable serialization permits, or semantically compare all records.

## 53.4 Crash tests

Inject failures during:

- Observation batch write.
- Interval close/open transaction.
- Checkpoint write.
- Migration.
- Compaction.
- Aggregate replacement.

Verify the next startup does not produce fabricated history.

## 53.5 Large-history tests

Generate at least 6–12 months of synthetic data and measure:

- Database size.
- Timeline query latency.
- Overview load latency.
- Aggregate rebuild time.
- Migration time.
- Vacuum/maintenance cost.

---

# 54. Hard Invariants

1. **SQLite is the local source of truth.**
2. **Raw observations are separate from derived analytics.**
3. **Raw process/window evidence is not rewritten to implement classification changes.**
4. **Foreground intervals do not overlap within one tracked session.**
5. **Visible intervals may overlap.**
6. **Gap intervals are explicit and never equal zero activity.**
7. **PID and HWND are not globally unique historical identities.**
8. **Cross-device identity must not depend on SQLite row IDs.**
9. **Derived data records its derivation/version context.**
10. **User corrections are explicit historical rules/configuration.**
11. **Cloud sync is downstream of local persistence.**
12. **Tracker acquisition cannot depend on analytics cache availability.**
13. **Maintenance must not create an unbounded acquisition stall.**
14. **Deletion must not be undone by sync reconciliation.**
15. **Private-browser data rules are fail-closed.**
16. **UTC is authoritative for stored event instants.**
17. **Monotonic timing remains authoritative for elapsed duration inside runtime processing.**
18. **All high-volume source tables have time-oriented access paths.**
19. **Derived analytics can be rebuilt from durable source records and versioned rules.**
20. **A crash cannot manufacture usage between the last proven boundary and restart.**

---

# 55. Deferred Decisions / ADRs

The following should remain explicit decisions rather than being hidden in schema code:

- **ADR-004:** SQLite concurrency and writer ownership.
- **ADR-007:** Local database/data protection.
- **ADR-008:** E2EE key architecture.
- **ADR-009:** Google Drive synchronization/reconciliation.
- Exact retention defaults after storage-size experiments.
- Exact raw-observation compaction policy.
- Exact browser URL storage representation.
- Stable monitor identity algorithm.
- Whether WAL should be permanently enabled in production.
- Exact aggregate materialization levels.
- Full versus targeted rebuild thresholds.

---

# 56. Implementation Order

Implement storage in this order:

### Phase 1 — Schema foundation

- Database bootstrap.
- Migration framework.
- Device/runtime session tables.
- Foreign-key/integrity configuration.

### Phase 2 — Tracking evidence

- Process instances.
- Window instances.
- Raw observations.
- Lifecycle events.
- Checkpoints.

### Phase 3 — Derived timing

- Usage intervals.
- Gaps.
- Sessionization.

### Phase 4 — Identity/classification

- Canonical applications.
- Identity rules.
- Categories.
- Productivity/leisure classifications.

### Phase 5 — Browser/display

- Browser observations.
- Domains.
- Page titles.
- Displays/topology.

### Phase 6 — Aggregates/read models

- Daily aggregates.
- Timeline projections.
- Overview/application/browser read models.

### Phase 7 — Repair/maintenance

- Invalidation.
- Rebuilds.
- Compaction.
- Retention.
- Integrity checks.

### Phase 8 — Export/sync readiness

- Export formats.
- Stable global IDs.
- Tombstones.
- Sync metadata.

---

# 57. Definition of Done for Document 07

Document 07 is implemented when the repository contains a tested SQLite data layer that can:

- Persist tracker evidence without coupling it to UI analytics.
- Represent process/window lifetimes safely.
- Store foreground, visible, idle, and gap intervals.
- Preserve raw identity separately from canonical identity.
- Represent classification history and user overrides.
- Support browser-domain/page-title data with privacy boundaries.
- Track monitor/device/runtime provenance.
- Build daily/weekly/monthly analytical read models.
- Support targeted historical correction and rebuild.
- Recover cleanly from crashes and partial transactions.
- Enforce deduplication/idempotency.
- Support retention and compaction without silently destroying required history.
- Remain viable for future encrypted Google Drive synchronization.
- Meet measured storage/query/performance budgets on representative long-running data.

The next document, **Document 08 — Browser Activity Acquisition Specification**, should define the browser-specific acquisition architecture for Chrome, Edge, Firefox, Brave, and Arc, including domain/page-title capture, private browsing fail-closed behavior, tab/window correlation, permissions, adapter isolation, and browser failure recovery.