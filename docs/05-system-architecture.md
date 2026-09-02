# System Architecture & Technical Design

**Product:** PC Usage Intelligence  
**Document:** 05 — System Architecture & Technical Design  
**Status:** Authoritative architecture baseline — Pre-development  
**Parent documents:** `docs/01-product-requirements.md`, `docs/02-scope-feature-specification.md`, `docs/03-information-architecture-ux.md`, `docs/04-visual-design-system.md`  
**Platform:** Windows 10 and Windows 11  
**Last updated:** 2026-09-02

---

## 1. Purpose

This document defines the technical architecture for PC Usage Intelligence.

It converts the product and UX requirements into concrete system boundaries, process responsibilities, technology choices, data flow rules, communication contracts, and engineering constraints.

The architecture is optimized for the project's unusual combination of requirements:

- Continuous background tracking.
- Very low CPU/RAM/I/O overhead.
- Deep Windows integration.
- Rich native-feeling desktop UI.
- High-resolution local history.
- Browser acquisition.
- Offline-first behavior.
- Optional encrypted Google Drive synchronization.
- Long-term maintainability.
- AI-agent-friendly development.

---

# 2. Executive Architecture Decision

## 2.1 Chosen stack

The project will use a **C#/.NET + WinUI 3 + Windows App SDK** architecture for the primary Windows desktop application, with a separate lightweight **.NET background tracking runtime**.

The system will use native Windows APIs through narrowly isolated interop adapters where the Windows App SDK does not provide the required observation capability.

The local persistence layer will use **SQLite** behind a repository/data-access boundary.

The initial stack is therefore:

| Area | Decision |
|---|---|
| Primary language | C# |
| Runtime | Modern supported .NET release, initially .NET 10 |
| Desktop UI | WinUI 3 |
| Windows platform layer | Windows App SDK + Windows SDK/Win32 interop |
| Background tracker | Separate .NET executable/process |
| Local database | SQLite |
| Application architecture | Layered + modular, dependency-injected |
| UI pattern | MVVM-oriented presentation architecture |
| IPC | Local authenticated IPC, initially named pipes |
| Browser acquisition | Isolated per-browser adapters with shared normalized contract |
| Sync transport | Google Drive API |
| Cloud payload | Client-side encrypted ciphertext |
| Authentication | Google OAuth 2.0 for installed/desktop application |
| Packaging | Evaluate packaged/MSIX and unpackaged self-contained distribution during release engineering |

This is a deliberate Windows-first decision. The core domain/data/analytics libraries should remain sufficiently platform-neutral to permit future cross-platform work, but cross-platform UI is not a V1 requirement.

Microsoft's current Windows developer guidance recommends WinUI 3 with the Windows App SDK for new native Windows desktop applications, and WinUI 3 supports Windows 10 version 1809 and later including Windows 11. citeturn184177search0turn184177search1turn184177search11

---

# 3. Why This Architecture

## 3.1 Why native Windows rather than Electron

Electron provides a mature UI/web development ecosystem, but its architecture inherently carries Chromium's multi-process rendering model, with renderer processes for BrowserWindow instances and a Node.js main process. citeturn348163search0turn348163search1

That overhead is not automatically unacceptable, but it conflicts with this product's unusually strict requirement that the application be almost invisible while continuously tracking. A native Windows stack also provides a more direct path to Win32 observation APIs, Windows lifecycle integration, accessibility, packaging, and Windows-specific behavior.

Electron therefore remains a useful reference point but is not the selected stack.

## 3.2 Why not a webview-first Tauri architecture

Tauri can produce substantially smaller desktop applications than Electron and uses the system WebView; on Windows it uses WebView2. citeturn348163search5turn348163search6

However, this project is Windows-only initially and requires deep desktop integration plus a high-performance always-running native tracker. Introducing a browser-rendered UI and a Rust/native backend would create a two-language stack without providing a decisive product advantage over a native C# architecture for V1.

Tauri remains viable for a future cross-platform rewrite or if later benchmarking demonstrates a compelling advantage, but it is not the default architecture.

## 3.3 Why not Avalonia

Avalonia is a strong .NET cross-platform option with its own rendering engine and explicit support for Windows, macOS, Linux, mobile, and WebAssembly. Its current documentation describes Win32 use on Windows and a shared cross-platform UI architecture. citeturn791788search0turn791788search1turn791788search8

However, the immediate product is intentionally Windows-only, and the strongest priority is first-class Windows integration plus a polished native Windows experience. Choosing Avalonia now would optimize for a future requirement rather than a current one.

The architecture should preserve the ability to move domain/data code into a cross-platform UI later without forcing this choice today.

## 3.4 Why not WPF

WPF is mature and well understood, but Microsoft's current guidance recommends WinUI 3 for new native Windows desktop applications. WPF remains a valid technology and can interoperate with Windows App SDK, but this is a new application rather than an existing WPF modernization effort. citeturn184177search0turn184177search5

WinUI 3 is therefore preferred unless a later benchmark reveals a concrete blocker.

---

# 4. Architectural Goals

The architecture must satisfy these goals in priority order:

1. Tracking correctness.
2. Low runtime overhead.
3. Data integrity.
4. Privacy/security.
5. Maintainability.
6. Rich, responsive UI.
7. Straightforward AI-agent implementation boundaries.
8. Future extensibility.

The architecture must **not** optimize for theoretical scalability to millions of users before optimizing the single-user desktop experience.

---

# 5. Top-Level System

```text
┌────────────────────────────────────────────────────────────────┐
│                         Windows User Session                    │
│                                                                │
│  ┌──────────────────────┐       Local IPC       ┌────────────┐ │
│  │ Tracking Runtime     │ <───────────────────> │ Desktop UI │ │
│  │                      │                       │ WinUI 3    │ │
│  │ - Observation        │                       │            │ │
│  │ - Session engine     │                       │ Dashboard  │ │
│  │ - Identity resolver  │                       │ Timeline   │ │
│  │ - Browser adapters   │                       │ Reports    │ │
│  │ - Event buffer       │                       │ Settings   │ │
│  │ - Persistence        │                       │            │ │
│  └──────────┬───────────┘                       └─────┬──────┘ │
│             │                                         │        │
│             └───────────────┬─────────────────────────┘        │
│                             │                                  │
│                       ┌─────▼──────┐                           │
│                       │ Local Data │                           │
│                       │ SQLite     │                           │
│                       └─────┬──────┘                           │
│                             │                                  │
│                    async encrypted sync                        │
└─────────────────────────────┼──────────────────────────────────┘
                              │
                              ▼
                       ┌───────────────┐
                       │ Google Drive  │
                       │ ciphertext    │
                       └───────────────┘
```

The UI and tracker are peers around the local data model, but the tracker is the authority for acquisition and continuous recording.

---

# 6. Process Architecture

## 6.1 Process A — Tracking Runtime

**Purpose:** Continuous observation and durable recording.

Characteristics:

- Minimal dependencies.
- No heavy UI framework.
- No chart rendering.
- No browser engine.
- No network requirement for tracking.
- No dependency on the dashboard being open.
- Long-lived process.
- User-session context.

Responsibilities:

1. OS observation.
2. Browser observation.
3. Identity normalization.
4. Interval/session state.
5. Event buffering.
6. Local persistence.
7. Lifecycle handling.
8. Tracker health state.

The runtime must **not** perform expensive analytics, cloud synchronization, report rendering, or UI animation.

## 6.2 Process B — Desktop UI

**Purpose:** Interactive visualization and user control.

Responsibilities:

- Overview.
- Timeline.
- Application analytics.
- Browser analytics.
- Category management.
- Reports.
- Settings.
- Data inspection/edit/delete.
- Account/authentication UI.
- Sync management.

The UI can query local database projections directly or request services from the shared application/domain layer, but it must not own tracking state.

## 6.3 Optional future process — Sync Worker

Sync may initially run as an asynchronous component in the UI/application process while the UI is open and as a small dedicated worker when background sync requirements justify it.

A separate sync process is **not required for V1 architecture** if the implementation can safely maintain asynchronous synchronization without affecting tracker performance.

If background synchronization eventually requires a persistent process, it must not become a dependency of the tracking runtime.

---

# 7. Why the Tracker Is Not a Traditional Windows Service

A traditional Windows Service is not the default mechanism for the tracker.

Windows services are not designed to directly interact with the user's desktop; Microsoft documents that services cannot directly interact with users on modern Windows and explains that services run in session 0, requiring a separate interactive user-session application when desktop interaction is needed. citeturn173932search1

PC Usage Intelligence must observe the interactive user's desktop/window state. Therefore the primary tracker will run as a user-session background runtime with controlled lifecycle management rather than as a privileged interactive service.

A future privileged service may be introduced only for a concrete requirement that cannot be satisfied safely in the user session.

---

# 8. Application/Project Structure

Recommended solution structure:

```text
src/
  PcUsageIntelligence.sln

  Core/
    Domain/
    Contracts/
    Time/
    Classification/
    Analytics/
    Configuration/

  Data/
    Sqlite/
    Repositories/
    Migrations/
    Aggregation/

  Windows/
    Interop/
    Windowing/
    Processes/
    Lifecycle/
    Display/
    Identity/

  Browser/
    Abstractions/
    Chromium/
    Firefox/
    Adapters/
    Normalization/

  Tracking/
    Runtime/
    Observation/
    Sessionization/
    Buffering/
    Health/

  Sync/
    Contracts/
    Encryption/
    GoogleDrive/
    Queue/
    Reconciliation/

  Desktop/
    App/
    Views/
    ViewModels/
    Components/
    Resources/
    Navigation/

  Installer/

  Tests/
    Core.Tests/
    Data.Tests/
    Windows.Tests/
    Browser.Tests/
    Tracking.Tests/
    Sync.Tests/
    Integration.Tests/
    Performance.Tests/
```

The actual repository layout may evolve, but dependency direction must remain controlled.

---

# 9. Dependency Rules

## 9.1 Core

`Core` must not depend on WinUI, Windows-specific observation APIs, Google Drive, or the database implementation.

It contains:

- Domain models.
- Time semantics.
- Classification abstractions.
- Analytics algorithms.
- Contracts.

## 9.2 Data

`Data` depends on Core and implements persistence interfaces.

## 9.3 Windows

`Windows` depends on Core contracts but contains platform-specific APIs.

## 9.4 Browser

`Browser` depends on Core contracts and platform acquisition interfaces.

## 9.5 Tracking

`Tracking` coordinates Windows and Browser acquisition, normalization, buffering, and persistence.

## 9.6 Sync

`Sync` depends on Core/Data contracts but does not participate in real-time tracking.

## 9.7 Desktop

`Desktop` consumes Core/Data/Sync services and presents the UI.

The Desktop project must not directly call low-level Win32 observation APIs.

---

# 10. Data Flow

## 10.1 Observation pipeline

```text
Windows / Browser
      ↓
Raw observation
      ↓
Normalization
      ↓
Identity resolution
      ↓
State transition detection
      ↓
Interval generation
      ↓
Buffered persistence
      ↓
Aggregate maintenance
      ↓
Analytics queries
      ↓
UI
```

## 10.2 Principle

Each layer should add information without destroying the previous layer's meaning.

Example:

```text
HWND 1234
 ↓
process instance X
 ↓
C:\Program Files\...
 ↓
Visual Studio canonical app
 ↓
Development
 ↓
Productivity
```

The later interpretations must not replace the original observed identity.

---

# 11. Windows Observation Strategy

The Windows acquisition subsystem should use native APIs through an isolated interop layer.

For foreground tracking, the architecture can use `GetForegroundWindow`, which retrieves the handle of the foreground window. citeturn173932search0

For window/title information, `GetWindowText` can retrieve the title-bar text for another application's window when it has a caption, with the documented limitations for controls in other processes. citeturn173932search5

For top-level window enumeration, `EnumWindows` provides a Windows-supported mechanism to enumerate top-level desktop windows. citeturn173932search6

The exact event/polling hybrid belongs in Document 06.

### Architectural rule

No application feature outside `Windows`/`Tracking` may directly call these native APIs.

This isolates platform-specific behavior and allows deterministic unit tests against interfaces.

---

# 12. Browser Architecture

Browser tracking is an acquisition problem, not an analytics problem.

The architecture therefore defines:

```text
Browser adapter
      ↓
Browser observation contract
      ↓
Common browser normalization
      ↓
Core observation model
```

Each browser adapter may use a different acquisition technique, but the rest of the application must not care whether the source was:

- UI Automation.
- Browser-specific integration.
- A supported extension/companion mechanism.
- Window/title parsing.
- Another verified local technique.

UI Automation provides programmatic access to UI elements exposed by other applications and is therefore one possible browser-acquisition primitive, subject to browser-specific support and privacy/security constraints. citeturn184177search12

The browser architecture must degrade independently. Failure to obtain a domain must never disable browser application tracking.

---

# 13. Identity Resolution Architecture

Identity resolution is a pipeline, not a single function.

```text
Raw process/window
      ↓
Executable identity
      ↓
Windows package/application metadata
      ↓
Canonical application resolver
      ↓
Canonical application entity
      ↓
User override
```

For browsers:

```text
Browser process/window
      ↓
Browser instance/context
      ↓
Domain/service resolver
      ↓
Domain entity
      ↓
Optional page metadata
```

Identity resolution must be deterministic and versioned.

---

# 14. Tracking State Machine

The tracker should maintain an explicit state machine rather than relying on ad hoc timers.

Conceptual states:

```text
Starting
   ↓
Observing
   ├── LifecycleBoundary
   ├── StorageDegraded
   └── Shutdown
        ↓
     Stopped
```

A separate availability dimension should represent:

- Observable.
- Locked.
- Sleeping.
- User signed out.
- Storage unavailable.
- Tracker recovering.
- Unknown.

These are not necessarily mutually exclusive process states.

---

# 15. Interval Engine

The interval engine converts state changes into compact durations.

Example:

```text
10:00  foreground = VS Code
10:05  foreground = Chrome
10:14  foreground = VS Code
```

becomes approximately:

```text
09:??–10:05 VS Code
10:05–10:14 Chrome
10:14–...    VS Code
```

Repeated unchanged observations do not create repeated intervals.

The engine must use monotonic timing where appropriate for duration calculation and wall-clock timestamps for historical placement. The exact clock strategy is defined in the tracking/data documents.

---

# 16. Persistence Strategy

SQLite is the intended local data store.

The tracker writes through a bounded persistence layer:

```text
Observation
  ↓
In-memory bounded buffer
  ↓
Batch transaction
  ↓
SQLite
```

The tracker must never issue a database transaction for every high-frequency observation when multiple observations can be coalesced safely.

The UI performs read-heavy analytical workloads through optimized queries/projections.

Long-running analytics should use aggregates rather than scanning raw history unnecessarily.

Exact schema and indexing are defined in Document 07.

---

# 17. SQLite Ownership Rule

The local database is a shared application resource, but access must be mediated.

Two supported patterns are acceptable during implementation evaluation:

### Pattern A — Shared database with disciplined concurrency

Both tracker and UI access the same SQLite database through a shared data-access library, using SQLite's concurrency model and carefully bounded write transactions.

### Pattern B — Tracker owns writes; UI reads through projections/IPC

The tracker remains the sole writer while the UI reads a read-optimized data path.

The initial implementation should benchmark both if necessary, but should prefer the simplest model that reliably meets the performance and integrity requirements.

The architecture must prevent simultaneous independent schema migrations from different processes.

Schema migration ownership belongs to a dedicated startup/maintenance mechanism.

---

# 18. IPC Architecture

The tracker and UI require limited local communication.

## Selected initial mechanism

**Named pipes with strict local access control**.

Reasons:

- Native Windows support.
- Efficient local IPC.
- Suitable for request/response and event notification.
- Does not require a network port.
- Can be protected using Windows security descriptors/ACLs.

The IPC protocol must use explicit versioned messages.

## IPC responsibilities

Tracker → UI:

- Tracker health/status.
- Current tracking state.
- Sync-independent lifecycle notifications.
- Optional current active entity summary.

UI → Tracker:

- Start/stop/pause tracking if product settings permit.
- Request diagnostics.
- Reload configuration.
- Maintenance commands.

The UI must never command the tracker to perform expensive analytics.

---

# 19. IPC Security

The named-pipe endpoint must be restricted to the intended local user/context.

Do not expose the tracker API over TCP localhost by default.

Every command must be validated and versioned.

The tracker must reject unexpected or malformed messages without crashing.

---

# 20. Tracker Configuration

The tracker reads a small configuration surface containing only runtime-relevant settings.

Examples:

- Tracking enabled/disabled.
- Browser domain collection enabled/disabled.
- Page-title collection enabled/disabled.
- Retention parameters.
- Diagnostic opt-in state where relevant.

The tracker should avoid loading the complete UI configuration model into memory.

Configuration changes should propagate through IPC or another lightweight mechanism rather than restarting the tracker unnecessarily.

---

# 21. Analytics Architecture

Analytics are a read-side concern.

```text
Raw observations
      ↓
Normalized intervals
      ↓
Sessions
      ↓
Aggregates
      ↓
Analytical query services
      ↓
UI view models
```

The analytics layer must not modify raw observations.

Analytics should use deterministic functions and explicit period definitions.

Time periods, timezone behavior, daylight-saving transitions, and incomplete-period handling must be centralized in the domain/time layer.

---

# 22. Aggregate Strategy

The system should maintain multiple levels of analytical resolution to support the zoomable timeline.

Potential aggregate levels:

- Minute.
- 15-minute.
- Hour.
- Day.
- Week.
- Month.

The system may derive some levels lazily if benchmarked as sufficiently fast.

The rule is:

> Do not materialize an aggregate solely because it is conceptually possible; materialize it when it produces a measurable query-performance or memory benefit.

---

# 23. Classification Architecture

Classification is a versioned interpretation layer.

```text
Entity
  ↓
System classification rules
  ↓
Confidence
  ↓
User override
  ↓
Effective classification
```

A user override always takes precedence over a system rule until explicitly removed.

The system must preserve enough metadata to explain which rule/version produced a classification where practical.

Classification recomputation must be possible without re-running Windows observation.

---

# 24. Privacy Architecture Boundary

Privacy-sensitive features must be structurally isolated.

Examples:

- Browser page-title collection.
- Domain collection.
- Sync payload construction.
- Diagnostics.

Each component should receive the minimum data required.

A tracker operation that only needs application identity must not request page-title data unnecessarily.

---

# 25. Cloud Sync Architecture

Cloud synchronization is downstream of local storage:

```text
SQLite
  ↓
Sync selection
  ↓
Serialization
  ↓
Local encryption
  ↓
Ciphertext package
  ↓
Google Drive
```

Download reverses the process:

```text
Google Drive
  ↓
Ciphertext
  ↓
Local decryption
  ↓
Validation
  ↓
Conflict/reconciliation
  ↓
SQLite
```

The tracker must not wait for any of these operations.

The exact E2EE construction belongs to Document 10; sync protocol details belong to Document 11.

Google Drive is a user-owned destination rather than a proprietary application database.

---

# 26. Authentication Boundary

Google OAuth belongs in the account/sync layer.

The core tracking engine does not need:

- Google account identity.
- Access tokens.
- Network connectivity.
- Cloud configuration.

This makes the core tracker fully usable without sign-in and substantially reduces the security surface of the always-running process.

OAuth credential storage and refresh lifecycle must remain outside the raw tracking data model.

---

# 27. Data Protection Boundary

Local behavioral data is sensitive.

The architecture must support a final protection design that balances:

- Confidentiality.
- Performance.
- Crash safety.
- Recoverability.
- Schema migration.

Possible approaches include:

- OS-protected encryption keys.
- Selective encryption.
- Encrypted SQLite/database layer.
- Field-level protection.

No approach is frozen by this document. Document 10 must make the final decision using a threat model and performance testing.

---

# 28. Error Handling

The architecture uses explicit error classes:

### Recoverable acquisition error

Continue tracking other signals and record degraded capability.

### Recoverable storage error

Retry with bounded backoff and buffering.

### Permanent/structural configuration error

Surface actionable diagnostics.

### Data integrity error

Fail closed for the affected operation and preserve as much valid history as possible.

### Tracker crash

Restart and record a gap.

### UI crash

Tracking continues independently.

### Sync error

Queue/retry without affecting local analytics.

---

# 29. Logging and Diagnostics

Logging must be privacy-conscious.

Default logs should contain technical events such as:

- Tracker started.
- Adapter initialized.
- Database migration completed.
- Browser adapter unavailable.
- Sync retry scheduled.
- Storage failure.

Logs must not routinely contain:

- Full page titles.
- Browser history.
- Full window-title histories.
- Detailed usage timelines.

Diagnostic logging must avoid becoming an accidental second behavioral database.

---

# 30. Performance Architecture

Performance requirements are enforced structurally.

## Tracker

- No UI stack.
- No network dependency.
- No continuous chart/data processing.
- Batched DB writes.
- Coalesced unchanged observations.
- Bounded buffers.
- Minimal polling.
- Event-driven mechanisms where appropriate.

## UI

- Lazy page loading.
- Virtualized lists.
- Aggregate-backed charts.
- Timeline virtualization.
- Cached recent queries.
- Background analytical computation.

## Sync

- Asynchronous.
- Chunked.
- Bounded memory usage.
- No tracker dependency.

---

# 31. Benchmark Architecture

A dedicated performance test harness must execute reproducible scenarios.

At minimum:

### Scenario A — Idle

Tracker running, user not switching windows frequently.

### Scenario B — Developer

IDE + terminal + browser + file manager, frequent switching.

### Scenario C — Browser heavy

Many tabs and frequent navigation/title changes.

### Scenario D — Gaming

High CPU/GPU foreground application with tracker active.

### Scenario E — Multi-monitor

Several visible windows across displays.

### Scenario F — Long running

24-hour and multi-day stability.

Measure:

- CPU.
- RAM.
- Wakeups where measurable.
- Disk writes.
- Database growth.
- Event throughput.
- Tracking latency.
- Data loss after forced termination.

Target budgets are defined in the PRD and must remain release criteria.

---

# 32. Testing Architecture

## Unit tests

Cover:

- Time calculations.
- Interval merging.
- Sessionization.
- Classification.
- Aggregation.
- Period comparisons.
- Deduplication.
- Serialization.
- Sync reconciliation.

## Integration tests

Cover:

- Tracker → database.
- Windows adapter → normalized observation.
- Browser adapter → browser contract.
- Tracker ↔ UI IPC.
- Sync → encrypted package → Drive mock/test endpoint → local merge.

## Scenario tests

Build deterministic replay fixtures for:

- Application switches.
- Title changes.
- Multiple instances.
- Lock/unlock.
- Sleep/resume.
- Display changes.
- Browser private mode.
- Browser acquisition failure.
- Crash gaps.
- Device migration.

## Performance tests

Performance tests must run on representative Windows hardware profiles and produce machine-readable results.

---

# 33. Versioning Strategy

Version independently:

- Database schema.
- Observation schema.
- Classification rules.
- Sessionization rules.
- Sync protocol.
- Encryption envelope format.
- IPC contract.
- Browser adapter contracts.

Never assume that application version equality means data/schema equality.

A future application version must be able to understand or migrate supported historical data versions.

---

# 34. Upgrade/Migration Strategy

Application update sequence:

```text
Installer/update
      ↓
Validate environment
      ↓
Ensure tracker compatibility
      ↓
Acquire database migration lock
      ↓
Run migrations
      ↓
Validate schema
      ↓
Start/restart tracker
      ↓
Start UI
```

If migration fails:

- Preserve the original database where possible.
- Restore from a verified backup/copy if migration is transactional and fails.
- Do not silently delete history.
- Surface a recoverable error.

---

# 35. Packaging Direction

The product requires both Microsoft Store and standalone distribution.

Windows App SDK supports packaged and unpackaged deployment models. Microsoft currently documents framework-dependent and self-contained options, and self-contained unpackaged WinUI 3 applications can use single-file publication; framework-dependent deployment is the default Windows App SDK mode and is designed for efficient machine-resource use. citeturn184177search3turn184177search14turn184177search6

Final packaging should be decided after evaluating:

- Store requirements.
- Startup behavior.
- Tracker lifecycle.
- Update reliability.
- Install/uninstall semantics.
- Runtime footprint.
- Self-contained versus framework-dependent deployment.

Packaging is therefore not allowed to force architectural coupling between tracker and UI.

---

# 36. Security Boundaries

Trust boundaries are:

```text
[Windows OS]
     ↓
[Tracker]
     ↓
[Local DB]
     ↓
[Sync Encryption Boundary]
     ↓
[Google Drive]
```

The UI is a local untrusted presentation client relative to the tracker data model and should not automatically receive secrets it does not need.

The tracker should not hold Google OAuth refresh tokens unless future requirements prove this necessary.

---

# 37. Privacy-by-Construction Rules

1. Tracker runs without an account.
2. Tracker runs without network access.
3. Google credentials are outside the tracker.
4. Cloud payloads are encrypted before upload.
5. Sensitive browser data is collected only when the relevant setting is enabled.
6. Private browsing fails closed for domain/title acquisition when private status cannot be determined reliably.
7. Logs do not replicate behavioral history.
8. Analytics operate on local data.
9. Data deletion is represented explicitly and propagated to synchronization according to the sync protocol.
10. Optional diagnostics remain separate from product analytics.

---

# 38. AI-Agent Development Rules

Because much of the project will be implemented using AI coding agents, architecture must be easy to reason about mechanically.

Every major module should have:

- A short responsibility statement.
- Explicit public interfaces.
- Input/output contracts.
- Invariants.
- Unit tests.
- Performance expectations where relevant.
- Clear dependency direction.

Agents must not bypass architectural boundaries simply because a direct API call is shorter.

Examples:

- UI agents do not call Win32 observation APIs directly.
- Tracking agents do not perform Google API calls.
- Analytics agents do not mutate raw observations.
- Browser adapters do not write directly to arbitrary tables.
- Sync agents do not bypass the encryption boundary.

---

# 39. Observability Without Behavioral Telemetry

Internal diagnostics should measure system health, not user behavior.

Acceptable local metrics include:

- Events processed per second.
- Write batch size.
- Database write latency.
- Tracker restart count.
- Adapter health.
- IPC latency.
- Sync queue size.

These may be visible locally to the user/developer.

They must not automatically leave the device.

---

# 40. Failure Isolation

The architecture should isolate failures according to this matrix:

| Failure | Tracker | UI | Sync | History |
|---|---|---|---|---|
| UI crash | Continues | Restarts | Unaffected | Safe |
| Tracker crash | Restarts | Displays gap/status | Unaffected | Gap recorded |
| Browser adapter failure | Other tracking continues | Shows degraded detail | Unaffected | Browser detail gap |
| Network failure | Continues | Continues | Queues | Safe |
| Google auth failure | Continues | Sync attention state | Pauses | Safe |
| Analytics query failure | Continues | Local UI issue | Unaffected | Safe |
| Database failure | Buffered/recovery mode | Degraded | Pauses | No fabrication |

The desired property is **graceful degradation, not all-or-nothing operation**.

---

# 41. Architecture Invariants

The following are hard invariants:

1. Tracking does not depend on UI availability.
2. Tracking does not depend on network availability.
3. Tracking does not depend on Google authentication.
4. Tracker does not perform heavy analytics.
5. Tracker does not render UI.
6. Raw observations are not destroyed by classification.
7. User overrides do not rewrite raw facts.
8. Sync never blocks tracking.
9. Cloud storage never becomes the local runtime's source of truth.
10. Tracking gaps are explicit.
11. Browser acquisition failure cannot disable application tracking.
12. Private browsing does not expose domain/title data.
13. Behavioral telemetry is off by default.
14. UI cannot directly mutate raw observation history without going through domain/data policies.
15. Schema migrations are versioned and controlled.
16. All sensitive IPC endpoints are local and access-controlled.
17. Performance budgets apply to the background runtime independently of UI performance.

---

# 42. Architecture Decision Records Required

The following ADRs should be created before implementation reaches the corresponding area:

- `ADR-001` — WinUI 3 + Windows App SDK selection.
- `ADR-002` — Tracker process/lifecycle architecture.
- `ADR-003` — Foreground/visible observation strategy.
- `ADR-004` — SQLite concurrency/ownership model.
- `ADR-005` — IPC protocol and named-pipe security.
- `ADR-006` — Browser acquisition strategy.
- `ADR-007` — Local data protection strategy.
- `ADR-008` — E2EE protocol/key management.
- `ADR-009` — Google Drive sync model.
- `ADR-010` — Packaging/update strategy.

An ADR may reverse an architecture decision when evidence warrants it. Reversals should cite benchmark/test evidence rather than preference alone.

---

# 43. Technology Decision Matrix

| Criterion | WinUI 3 + .NET | WPF + .NET | Avalonia | Tauri | Electron |
|---|---:|---:|---:|---:|---:|
| Windows integration | Excellent | Excellent | Good | Good | Good |
| Native Windows UX | Excellent | Very good | Good | Depends on UI | Depends on UI |
| UI customization | Excellent | Very good | Excellent | Excellent | Excellent |
| Background tracker integration | Excellent | Excellent | Excellent | Excellent | Good |
| System resource potential | Excellent | Excellent | Very good | Very good | Weakest fit |
| Windows API access | Excellent | Excellent | Excellent via interop | Excellent via Rust | Good via native modules |
| .NET ecosystem | Excellent | Excellent | Excellent | None | None |
| Cross-platform future | Low | Low | Excellent | Excellent | Excellent |
| Current Windows-first fit | **Excellent** | Very good | Very good | Very good | Fair |
| Chosen | **Yes** | No | No | No | No |

This table is a product-fit assessment, not a benchmark result. Performance benchmarking remains mandatory.

---

# 44. Architecture Validation Plan

The chosen stack is considered provisionally accepted pending implementation spikes.

Before substantial product UI development, build three proof-of-concept slices:

### Spike A — Tracker

- Foreground observation.
- Process/window identity.
- Basic visibility detection.
- SQLite batch persistence.
- Resource benchmark.

### Spike B — UI

- WinUI 3 shell.
- Timeline prototype.
- Theme system.
- Large-list/chart rendering benchmark.

### Spike C — IPC

- Tracker ↔ UI named pipe.
- Auth/access control.
- Health/status updates.
- Tracker restart resilience.

If the spikes violate product requirements, update the relevant ADR rather than forcing production architecture around an invalid assumption.

---

# 45. Implementation Order

The system should be implemented in this order:

1. Core domain/time contracts.
2. Windows observation interfaces and adapters.
3. Tracking state machine.
4. SQLite persistence.
5. Deterministic replay/test fixtures.
6. Canonical application identity.
7. Tracker runtime.
8. IPC.
9. Basic WinUI shell.
10. Analytical read model.
11. Timeline.
12. Classification UI.
13. Browser adapters.
14. Reports/advanced analytics.
15. Sync/security.
16. Packaging/release hardening.

Do not start with a polished dashboard against mocked data and postpone tracking correctness.

---

# 46. Definition of Done

This architecture document is complete when engineers/AI agents can implement the system without making foundational choices about:

- Process boundaries.
- Primary stack.
- Core dependency direction.
- Tracker/UI separation.
- Local persistence role.
- IPC direction.
- Browser adapter boundary.
- Sync isolation.
- Security boundaries.
- Performance constraints.

The following documents now own the detailed technical designs:

- **Document 06:** Windows Tracking Engine.
- **Document 07:** Data Architecture & Storage.
- **Document 08:** Browser Activity Acquisition.
- **Document 09:** Privacy & Data Governance.
- **Document 10:** Security & Cryptography.
- **Document 11:** Google Drive Sync.
- **Document 12:** Performance, QA & Release.

This document should be revised through ADRs when benchmark evidence or platform constraints invalidate an architectural assumption.

---

## References

- Microsoft Windows developer platform guidance: WinUI 3 is currently recommended for new native Windows desktop applications. citeturn184177search0turn184177search2
- Microsoft WinUI 3: native Windows desktop framework, Windows 10 version 1809+ and Windows 11 support. citeturn184177search1turn184177search11
- Microsoft packaging/deployment guidance for Windows App SDK, including packaged, unpackaged, framework-dependent, self-contained, and single-file options. citeturn184177search3turn184177search6turn184177search14
- Microsoft guidance on Windows services and interactive user-session applications. citeturn173932search1
- Microsoft Win32 foreground/window APIs. citeturn173932search0turn173932search5turn173932search6
- Microsoft UI Automation fundamentals. citeturn184177search12
- Electron process model. citeturn348163search0turn348163search1
- Tauri/WebView2 architecture. citeturn348163search5turn348163search6
- Avalonia current cross-platform/Windows architecture. citeturn791788search0turn791788search1turn791788search8
