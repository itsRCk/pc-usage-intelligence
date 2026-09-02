# Domain Model Schema

**Status:** Implementation contract baseline — pre-development  
**Source:** `docs/05-system-architecture.md` through `docs/11-google-drive-sync-specification.md`

## 1. Identity rules

Every durable entity has an application-generated opaque `id`.

Required properties:

- Unique across the logical dataset where the entity can participate in sync.
- Never derived solely from display names, PIDs, HWNDs, paths, or SQLite row IDs.
- Stable for the lifetime of the logical entity.
- Safe to serialize across processes/devices.

For event-like records, globally unique mutation/event identity is required for deduplication.

## 2. Time rules

```text
Instant        = UTC timestamp
Duration       = signed/unsigned integer milliseconds as appropriate
Interval       = [start, end)
MonotonicTime  = implementation/platform-specific integer ticks
```

Persist wall-clock UTC for historical placement and monotonic timestamps where required for duration/recovery reasoning.

## 3. Core entities

### Device

```text
Device
- device_id: string
- installation_id: string, unique
- display_name: string?
- created_at_utc: instant
- first_seen_at_utc: instant
- last_seen_at_utc: instant?
- app_version: string?
- os_family: string?
- status: DeviceStatus
```

`installation_id` is random application identity and is not a hardware fingerprint.

### RuntimeSession

```text
RuntimeSession
- runtime_session_id: string
- device_id: string
- windows_session_id: integer
- started_at_utc: instant
- ended_at_utc: instant?
- monotonic_start: integer?
- monotonic_end: integer?
- clean_shutdown: boolean
- shutdown_reason: string?
- last_checkpoint_at_utc: instant?
```

Tracker restart creates a new runtime session.

### ProcessInstance

```text
ProcessInstance
- process_instance_id: string
- runtime_session_id: string?
- windows_session_id: integer
- pid: integer
- process_start_at_utc: instant?
- process_end_at_utc: instant?
- executable_path: string?
- executable_name: string?
- package_identity: string?
- canonical_application_id: string?
- first_seen_at_utc: instant
- last_seen_at_utc: instant
```

PID alone is not an identity key.

### WindowInstance

```text
WindowInstance
- window_instance_id: string
- process_instance_id: string?
- hwnd_value: integer
- created_at_utc: instant?
- destroyed_at_utc: instant?
- first_seen_at_utc: instant
- last_seen_at_utc: instant
- initial_title: string?
- latest_title: string?
- canonical_application_id: string?
```

HWND reuse must create a distinct lifetime identity.

### CanonicalApplication

```text
CanonicalApplication
- canonical_application_id: string
- stable_key: string, unique
- display_name: string
- default_icon_ref: string?
- source: IdentitySource
- created_at_utc: instant
- archived_at_utc: instant?
```

The display name is mutable; `stable_key` is the durable identity anchor.

### ApplicationIdentityRule

```text
ApplicationIdentityRule
- rule_id: string
- observed_identity_type: string
- observed_identity_key: string
- canonical_application_id: string
- priority: integer
- confidence: number [0,1]?
- created_at_utc: instant
- effective_from_utc: instant
- effective_to_utc: instant?
- source: RuleSource
```

Rules are time-effective so historical corrections can be reproduced.

### Category

```text
Category
- category_id: string
- parent_category_id: string?
- stable_key: string, unique
- display_name: string
- system_defined: boolean
- archived_at_utc: instant?
- created_at_utc: instant
```

Initial root keys:

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

### ProductivityClassification

```text
ProductivityClassification
- classification_id: string
- target_type: ClassificationTargetType
- target_id: string
- value: ProductivityValue
- confidence: number [0,1]?
- source: ClassificationSource
- effective_from_utc: instant
- effective_to_utc: instant?
- created_at_utc: instant
```

Initial values:

```text
Productive
Leisure
Neutral
Unclassified
```

### RawObservation

```text
RawObservation
- observation_id: string
- runtime_session_id: string
- device_id: string
- observed_at_utc: instant
- monotonic_ticks: integer
- source: ObservationSource
- source_sequence: integer?
- windows_session_id: integer?
- hwnd_value: integer?
- process_id: integer?
- process_start_at_utc: instant?
- executable_path: string?
- executable_name: string?
- package_identity: string?
- window_title: string?
- is_visible: boolean?
- is_minimized: boolean?
- is_cloaked: boolean?
- monitor_key: string?
- foreground_state: boolean?
- idle_state: IdleState
- lifecycle_state: TrackerAvailabilityState
```

Raw observations are append-only evidence.

### LifecycleEvent

```text
LifecycleEvent
- lifecycle_event_id: string
- runtime_session_id: string
- device_id: string
- occurred_at_utc: instant
- monotonic_ticks: integer?
- event_type: LifecycleEventType
- windows_session_id: integer?
- details_json: object?
```

### UsageInterval

```text
UsageInterval
- interval_id: string
- device_id: string
- runtime_session_id: string?
- dimension: IntervalDimension
- start_at_utc: instant
- end_at_utc: instant?
- start_monotonic_ticks: integer?
- end_monotonic_ticks: integer?
- duration_ms: integer?
- derived_session_id: string?
- window_instance_id: string?
- process_instance_id: string?
- canonical_application_id: string?
- monitor_key: string?
- browser_identity_id: string?
- idle_state: IdleState
- provenance: Provenance
- completion_reason: CompletionReason
- source_version: integer
- derived_at_utc: instant
```

For a completed interval, `duration_ms = end - start` in normalized duration terms. Open intervals are transient and must be closed or resolved safely during shutdown/recovery.

### BrowserInstance

```text
BrowserInstance
- browser_instance_id: string
- browser_type: BrowserType
- process_instance_id: string?
- profile_key: string?
- started_at_utc: instant
- ended_at_utc: instant?
```

### BrowserWindow

```text
BrowserWindow
- browser_window_id: string
- browser_instance_id: string
- window_instance_id: string?
- browser_window_native_id: string?
- private_mode: PrivateModeState
- created_at_utc: instant
- closed_at_utc: instant?
```

### BrowserTab

```text
BrowserTab
- browser_tab_instance_id: string
- browser_window_id: string
- browser_native_tab_id: string?
- created_at_utc: instant
- closed_at_utc: instant?
```

Native tab IDs are session-scoped evidence, not durable identity.

### Domain

```text
Domain
- domain_id: string
- normalized_domain: string
- display_name: string
- domain_kind: DomainKind
```

### BrowserPageObservation

```text
BrowserPageObservation
- observation_id: string
- browser_tab_instance_id: string
- observed_at_utc: instant
- domain_id: string?
- page_title: string?
- private_mode: PrivateModeState
- navigation_state: NavigationState
- source: BrowserObservationSource
```

Raw URL storage is optional and privacy-sensitive; if persisted it must be explicitly covered by the privacy schema. It is not required for the durable domain model.

### AggregateBucket

```text
AggregateBucket
- bucket_id: string
- bucket_kind: AggregateBucketKind
- bucket_start_utc: instant
- bucket_end_utc: instant
- canonical_application_id: string?
- domain_id: string?
- category_id: string?
- productivity_value: ProductivityValue?
- foreground_ms: integer
- visible_ms: integer
- session_count: integer
- switch_count: integer
- data_quality: DataQuality
- algorithm_version: integer
```

Aggregates are derived/cache data and must be rebuildable.

## 4. Enumerations

### IntervalDimension

```text
Foreground
Visible
Idle
Gap
```

### IdleState

```text
Active
Idle
Unknown
```

### TrackerAvailabilityState

```text
Observable
Locked
Sleeping
SignedOut
StorageUnavailable
Recovering
Unknown
```

### BrowserType

```text
Chrome
Edge
Firefox
Brave
Arc
Unknown
```

### PrivateModeState

```text
Public
Private
Unknown
NotApplicable
```

**Rule:** `Private` and `Unknown` MUST NOT produce durable domain/page-title identity.

### DomainKind

```text
WebDomain
BrowserInternal
LocalFile
ExtensionPage
Unclassified
```

### LifecycleEventType

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

### ObservationSource

```text
ForegroundEvent
ForegroundReconciliation
WindowEvent
WindowReconciliation
LifecycleEvent
BrowserEvent
BrowserReconciliation
Recovery
SyntheticTest
```

### Provenance

```text
Observed
Derived
UserOverride
Statistical
Imported
Synchronized
```

### CompletionReason

```text
StateTransition
LifecycleBoundary
ProcessEnded
WindowDestroyed
TrackerShutdown
RecoveryBoundary
ExplicitGap
DataCorrection
```

### DataQuality

```text
Complete
Partial
GapAdjacent
Uncertain
```

### AggregateBucketKind

```text
Hour
Day
Week
Month
```

## 5. Invariants

1. Raw observations and lifecycle events are immutable.
2. Foreground intervals for one resolved observation stream MUST NOT overlap.
3. Visible intervals MAY overlap across windows.
4. Gaps MUST remain distinguishable from zero activity.
5. Private/unknown browser state MUST NOT persist domain or page-title identity.
6. Derived records MUST retain algorithm/version provenance.
7. User overrides MUST NOT mutate raw evidence.
8. SQLite row identity MUST NOT be used as cross-device identity.
9. Duration arithmetic MUST NOT depend on floating-point primary storage.
10. Deleting/reclassifying derived data MUST NOT silently delete raw evidence.