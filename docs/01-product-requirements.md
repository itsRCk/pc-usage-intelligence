# Product Requirements Document

**Product:** PC Usage Intelligence  
**Document:** 01 — Product Requirements Document (PRD)  
**Status:** Authoritative baseline — Pre-development  
**Audience:** Product owner, designers, engineers, AI coding agents, security reviewers, QA/release contributors  
**Platform:** Windows 10 and Windows 11  
**Last updated:** 2026-09-02

---

## 1. Purpose

PC Usage Intelligence is a privacy-first Windows application that continuously records, organizes, and explains how a person uses their computer.

The product's primary job is **usage tracking and historical analysis**. It is not a productivity coach, blocker, habit-enforcement system, or attention-management tool.

The application should make a user's computer activity understandable at multiple levels of detail — from a monthly overview down to individual observed application/browser events — while remaining nearly invisible during normal operation.

The core product promise is:

> **Accurate, beautiful, long-term computer-usage history with minimal system impact and user-controlled privacy.**

The system is local-first. Tracking, storage, and analytics must work without an account or network connection. Optional Google-account-backed encrypted synchronization allows a user to preserve and migrate their history across devices without making the cloud a source of plaintext behavioral data.

---

## 2. Product Vision

Build the most trustworthy personal computer-usage history available for Windows: a tool that users can leave running for months and later use to answer questions such as:

- What did I spend time doing today, this week, or this month?
- Which applications consumed the most time?
- How much of that time was development, education, gaming, entertainment, communication, or other activity?
- How often did I switch applications?
- What were my longest sessions?
- What times of day do I tend to use particular applications?
- How has my gaming, browsing, development, or entertainment usage changed over time?
- What happened during a particular hour of a particular day?
- Which browser domains or services consumed my time?
- What changed relative to the previous week or month?

The product should answer these questions from a durable, inspectable history rather than from opaque scores or an always-online service.

---

## 3. Product Principles

### 3.1 Tracking first

The product exists primarily to observe, store, and analyze computer usage. Any feature that does not materially improve understanding of usage is secondary.

### 3.2 Accuracy over artificial completeness

The system must distinguish observed facts from inferred or classified information. It must prefer an explicit gap in the timeline to fabricated activity.

### 3.3 Local-first by design

Tracking must not depend on the UI being open, an account being signed in, or the network being available.

### 3.4 Privacy is a product property

Behavioral data is sensitive. Collection should be understandable, configurable, inspectable, deletable, and retained locally by default. Cloud synchronization must not require uploading plaintext behavioral history.

### 3.5 Performance is a hard requirement

The background tracking component is expected to run continuously. Low CPU, memory, wakeup, I/O, and GPU overhead are product requirements, not merely engineering optimizations.

### 3.6 Observe once, normalize once, derive repeatedly

Raw operating-system observations should be captured once, normalized into durable local records, and reused for multiple analytics views instead of repeatedly re-observing or rewriting the same facts.

### 3.7 Raw observations are distinct from interpretation

Application identity, browser identity, taxonomy, productivity/leisure classification, and user labels are interpretations of observations. The underlying observed data should remain recoverable where practical so historical records can be reclassified without pretending the original observation changed.

### 3.8 User control without configuration overload

Users should be able to inspect and correct meaningful classifications and privacy controls, while the default experience remains opinionated and simple.

### 3.9 UI richness must not leak into tracking cost

The rich analytics application and the always-running tracker are separate concerns. Animations, charts, transitions, and rendering complexity belong to the interactive UI, not the tracking runtime.

---

## 4. Target Users

### Primary users

- Developers and software engineers
- Students
- Gamers
- Power users who spend substantial time on a Windows PC

### Secondary users

- General Windows users interested in understanding long-term computer usage
- Users moving between multiple Windows devices who want a continuous personal history

### User mindset

The primary user is generally curious and analytical rather than looking for punishment or behavior control. They want trustworthy records, useful patterns, and a polished interface.

---

## 5. Jobs To Be Done

### Core job

> When I use my Windows computer over days, weeks, and months, I want a trustworthy record of what I used and when, so I can understand my usage without manually logging it.

### Supporting jobs

> When I review a day, I want to reconstruct how my time was distributed across applications, windows, and browser activity.

> When I review a week or month, I want to compare usage patterns and identify meaningful changes.

> When an application is classified incorrectly, I want to correct the classification without losing the underlying observed history.

> When I care about privacy, I want clear control over what browser information is captured and whether data leaves the device.

> When I replace or add a PC, I want my history to remain logically continuous while still knowing which device produced each observation.

---

## 6. Product Scope

### 6.1 In scope for the product

The initial product must support:

1. Continuous Windows application usage tracking.
2. Foreground and visible-time measurement.
3. Application/process/window observation and switching detection.
4. Canonical application identity resolution.
5. Browser activity and domain tracking for supported browsers.
6. Optional page-title collection, enabled by default and independently configurable.
7. Incognito/private-browsing privacy behavior that tracks browser application usage but does not collect browser domain/title data.
8. Multi-monitor awareness.
9. Session and interval modeling.
10. Local SQLite-based durable storage.
11. Automatic local application categorization with confidence scores.
12. User-overridable taxonomy and productivity/leisure classification.
13. Historical analytics at daily, weekly, monthly, and intraday resolutions.
14. A zoomable historical timeline.
15. Reports and historical comparisons.
16. User inspection, correction, editing, and deletion of stored history.
17. Offline operation.
18. Optional Google-account authentication.
19. Optional encrypted synchronization to the user's Google Drive.
20. Device migration with a logically continuous cross-device history.
21. Light, dark, and system themes.
22. Microsoft Store and standalone distribution.
23. Automatic updates.
24. Zero behavioral telemetry by default.

### 6.2 Explicitly out of scope for the initial product

The initial product will not implement:

- Application blocking
- Website blocking
- Focus timers or focus sessions
- Break reminders
- Pomodoro workflows
- Forced downtime
- Productivity scoring as a primary product metric
- A single opaque “focus score”
- Gamification intended to enforce behavior
- Social leaderboards
- Always-on cloud dependency
- Advertising
- Behavioral data monetization
- Mandatory sign-in
- Mandatory internet connectivity

AI-generated personalized coaching may be considered later, but the tracking engine must not depend on it.

---

## 7. Functional Requirements

The requirements below define what the product must do. Implementation details belong in subsequent technical documents unless explicitly stated as a product invariant.

### FR-1 — Continuous tracking runtime

The product shall provide a small background tracking runtime that can remain active for long periods without requiring the main UI to be open.

The runtime shall:

- Start and recover reliably across normal user-session lifecycle events.
- Continue tracking when the main application window is closed or minimized.
- Pause or mark unavailable periods caused by lock, sleep, sign-out, shutdown, or other states where usage cannot legitimately be observed.
- Record tracking gaps rather than fabricate activity after a crash or restart.
- Buffer events and persist them in batches.

### FR-2 — Foreground activity observation

The tracker shall observe the foreground application/window and maintain authoritative foreground usage intervals.

A foreground interval represents the time for which a specific observed window/application is the active foreground target under the operating system's window semantics.

Foreground time is the authoritative metric for active application usage.

### FR-3 — Visible-time observation

The tracker shall also model visible time where the operating system can reliably determine that an application/window is present and visible to the user.

Visible time must be separate from foreground time because an application may remain visible without being the currently active window.

The system must not silently equate visible time with active use.

### FR-4 — Application/process/window identity

The system shall preserve raw observation identity sufficient to distinguish:

- Process identity
- Process instance
- Executable path where available
- Window identity where available
- Window title
- Observation timestamps
- Display/monitor context where relevant

Multiple processes belonging to the same logical application may resolve to a single canonical application entity while their raw process/window identities remain distinct.

### FR-5 — Application identity resolver

The product shall resolve raw application observations into a canonical application identity using locally available evidence such as executable path and Windows application/package metadata.

The identity layer shall support historical reclassification. A change to the canonical identity or display metadata must not require rewriting the raw observation into a different historical fact.

### FR-6 — Application switching

The system shall detect and model application/window switches, including enough information to calculate switching frequency over selectable time ranges.

Switch counts shall be derived from normalized transitions rather than from UI polling performed by the analytics application.

### FR-7 — Sessions

The system shall derive usage sessions from intervals and transitions.

A session is a derived analytical concept and must not replace the underlying observations. Session rules must be explicit, deterministic, and revisable without destroying raw history.

### FR-8 — Multi-monitor support

The system shall support Windows environments with multiple monitors as a first-class case.

Where monitor/display identity can be reliably observed, observations should retain monitor context so the UI can explain or analyze cross-monitor activity later.

The absence of monitor information must never block core application tracking.

### FR-9 — Supported browsers

At launch, browser tracking shall support:

- Google Chrome
- Microsoft Edge
- Mozilla Firefox
- Brave
- Arc, subject to availability of a reliable acquisition path on supported builds

The browser architecture must allow additional Chromium- or Gecko-based browsers to be added without redesigning the core usage model.

### FR-10 — Browser domain tracking

For supported browsers, the system shall collect domain-level browser activity where technically and legally appropriate.

Domain is the durable analytics identity for browser activity. Multiple browser tabs representing the same entity may be grouped for analytics rather than treated as permanently unrelated records.

The design must distinguish the observed browser window/tab metadata from the normalized domain entity.

### FR-11 — Page-title collection

Page-title collection shall be enabled by default.

Users shall have an independent privacy control to disable page-title collection while retaining domain-level tracking.

The product must clearly communicate the distinction between:

- Browser application tracking
- Domain collection
- Page-title collection

### FR-12 — Incognito/private browsing

When a supported browser is operating in an identifiable private/incognito context, the product shall track the browser application itself but shall not collect domain or page-title data from that context.

The product must not attempt to defeat browser privacy modes.

### FR-13 — Taxonomy

The system shall provide an initial hierarchical taxonomy including at least:

- Development
- Education
- Gaming
- Entertainment
- Communication
- Social
- Creative
- Productivity
- Utilities
- System
- Other

The taxonomy must support system-provided defaults plus a user-overridable layer.

Users must be able to correct the classification of an application or other supported entity without modifying the underlying raw observation.

### FR-14 — Productivity/leisure dimension

Productivity versus leisure shall be represented as a separate classification dimension rather than as the primary taxonomy.

Users must be able to control this interpretation.

The system may provide defaults, but analytics must remain transparent about the fact that productivity/leisure is a classification rather than a directly observed operating-system fact.

### FR-15 — Classification confidence

Automatic local classification shall produce a confidence value or confidence band where meaningful.

Low-confidence classification must not be presented as objectively certain.

The architecture shall permit future deterministic improvements, local machine learning, or cloud-assisted classification without requiring a redesign of the underlying observation model.

### FR-16 — Local storage

The local device shall be the primary source of truth for tracking data.

SQLite is the intended local persistence technology unless superseded during architecture benchmarking.

The storage model shall support:

- Raw/high-resolution observations
- Normalized intervals
- Derived sessions
- Canonical entities
- User classifications
- Aggregated analytics
- Sync metadata
- Device identity
- Data deletion and correction

### FR-17 — Retention and compaction

The system shall support high-resolution recent history and compact long-term history.

Default retention behavior should preserve useful historical analytics without allowing storage growth to become unreasonable.

Advanced users must be able to control retention according to documented limits.

Compaction must preserve analytical correctness within the documented fidelity of the retained data.

### FR-18 — Editable history

Users shall be able to inspect, correct, and delete supported historical data.

Corrections should prefer metadata/classification changes where possible and should not silently alter raw facts.

Deletion must be explicit and must propagate to synchronized data according to the sync model.

### FR-19 — Daily/weekly/monthly analytics

The product shall provide at minimum:

- Total screen time by period
- Application rankings
- Category breakdown
- Productivity/leisure breakdown
- Hour-of-day usage patterns
- Day-of-week patterns
- Longest sessions
- Average session length
- Application-switch frequency
- Productivity trends
- Gaming trends
- Browser/domain trends
- Previous-period comparisons
- Anomaly detection or unusual-usage indicators
- Personalized statistical/rule-based insights
- Calendar-style history
- Full-day timeline

### FR-20 — Most productive hours

The product may calculate and display “most productive hours” using the user's configured productivity classification and observed historical distribution.

This must be framed as a descriptive historical pattern, not a prescriptive claim about human performance.

### FR-21 — Most distracting apps

The product may surface “most distracting apps” using transparent, user-understandable heuristics such as time spent, switching behavior, frequency, or configured leisure classification.

The exact metric must be defined in the analytics specification. It must not silently become a global judgment about an application.

### FR-22 — Anomaly detection

The product shall support identification of unusual usage patterns relative to an individual's own history.

Initial anomaly detection should be rule- or statistics-based and computed locally.

No cloud model is required for the initial release.

### FR-23 — Personalized insights

The initial product may provide lightweight local personalized insights based on historical statistics and explicit rules.

A future AI-powered insight layer may be added without changing the tracking engine.

AI-generated claims about behavior must be grounded in stored observations and distinguish inference from fact.

### FR-24 — Zoomable timeline

The UI shall provide a historical timeline whose granularity can change as the user zooms.

Conceptually supported levels are:

**Month → Week → Day → Hour → 15-minute → 1-minute → Individual events**

The UI must not require loading every raw event into memory merely to render a high-level view.

### FR-25 — Reports

The product shall provide reports suitable for personal review and historical comparison.

Report generation must operate on local data without requiring a cloud service.

Export formats and exact templates will be defined in the Scope & Feature Specification and later reporting specification.

### FR-26 — Offline-first behavior

Tracking and analytics shall function with no network connection.

An unavailable network must not block or materially degrade the tracking runtime.

Synchronization must be queued and handled asynchronously when connectivity returns.

### FR-27 — Account and identity

The product shall function without an account.

Users may optionally authenticate with a Google account for synchronization and device continuity.

Authentication is an identity mechanism, not the encryption key for behavioral data.

### FR-28 — Encrypted synchronization

The cloud synchronization model shall use end-to-end encryption such that the Google Drive copy is stored as ciphertext and the service does not require plaintext behavioral history.

The exact cryptographic construction, key lifecycle, recovery model, conflict model, and metadata minimization strategy are defined in the Security & Cryptography and Google Drive Sync specifications.

### FR-29 — User-owned cloud destination

Synchronized data shall be stored in the user's Google Drive, using an application-specific storage area where appropriate.

Cloud storage is a backup/sync destination, not the primary system of record.

### FR-30 — Device continuity

A user may install the application on a new Windows device and continue the same logical history.

The system shall:

- Assign each installation/device a durable device identity.
- Record the originating device for synchronized observations.
- Detect or safely handle duplicate synchronized records.
- Preserve chronology across devices.
- Mark device-switch boundaries where useful for UI/history analysis.

### FR-31 — Data privacy controls

The product shall provide understandable settings for at least:

- Domain collection
- Page-title collection
- Private/incognito handling behavior
- Data retention
- Local data deletion
- Cloud synchronization
- Account connection
- Diagnostics/crash reporting, if offered

Browser data controls must be independently configurable where technically possible.

### FR-32 — Diagnostics and telemetry

Behavioral telemetry shall be disabled by default.

The product shall not transmit application usage, browsing history, window titles, or similar behavioral data for product analytics by default.

Optional diagnostics or crash reporting may be offered only with clear disclosure and explicit opt-in.

### FR-33 — Theme support

The UI shall support:

- Light theme
- Dark theme
- System theme

The visual language should be coherent across all three modes rather than treating dark mode as an inverted light mode.

### FR-34 — Distribution

The product shall support both:

- Microsoft Store distribution
- Standalone installer distribution

The application shall support automatic updates subject to the distribution mechanism in use.

---

## 8. Non-Functional Requirements

### NFR-1 — Background CPU budget

Target resource budget for the tracking runtime:

- Idle CPU: **< 1%** of a modern user's system CPU capacity under normal conditions.
- Typical active tracking CPU: **< 2%**.

Benchmark methodology must define hardware, sampling duration, browser scenarios, number of running applications, and whether UI is open.

### NFR-2 — Memory budget

Target background/runtime idle memory: **< 150 MB**.

The product should minimize resident UI dependencies in the tracking process. The analytics UI may consume more memory when actively open, but its memory use must not be conflated with the background tracking budget.

### NFR-3 — Disk I/O

Tracking shall avoid continuous synchronous database writes.

Requirements:

- Batch persistence.
- Bounded in-memory buffering.
- Durable flushing at documented intervals and lifecycle boundaries.
- No unnecessary write amplification.
- Recovery behavior must be tested after forced termination during pending writes.

### NFR-4 — Wakeups and polling

The tracker shall minimize high-frequency polling and use event-driven Windows mechanisms where practical.

A polling loop may be used where no sufficiently reliable event exists, but its cadence must be justified and benchmarked.

### NFR-5 — GPU usage

The tracking runtime should have effectively zero GPU workload during normal operation.

UI rendering may use GPU resources when the dashboard is open; this is not part of the background tracking requirement.

### NFR-6 — Availability

The tracker should be resilient to:

- Application crashes
- Explorer restarts
- Browser restarts
- User logoff/logon
- Lock/unlock
- Sleep/resume
- Display connect/disconnect
- Monitor topology changes
- Temporary storage failures

### NFR-7 — Accuracy

For supported scenarios, timestamps and interval boundaries must be precise enough to support second-level usage analytics.

When observation is unavailable or ambiguous, the product must record a gap/unknown state rather than inventing usage.

### NFR-8 — Determinism

Given the same normalized observation stream, classification and derived analytics should be deterministic unless a future explicitly versioned model is used.

### NFR-9 — Privacy

The product shall follow data minimization principles. The system must collect no more behavioral detail than required for supported analytics and explicit user-configured features.

### NFR-10 — Security

Secrets, OAuth tokens, encryption keys, synchronization state, and local behavioral data must be stored using platform-appropriate protections.

Cryptographic decisions must be documented separately and reviewed before production sync is enabled.

### NFR-11 — Maintainability

The architecture shall separate:

- Observation/acquisition
- Normalization
- Storage
- Derivation/analytics
- Classification
- UI
- Account/authentication
- Synchronization

Changes in one area should not require invasive changes throughout the system.

### NFR-12 — Testability

The tracker and data model shall be testable with deterministic fixtures representing window transitions, process changes, browser activity, lock/sleep cycles, crashes, and device synchronization.

### NFR-13 — Accessibility

The interactive application should meet practical Windows accessibility expectations for keyboard navigation, semantic controls, contrast, text scaling, and screen-reader compatibility where supported by the chosen UI framework.

### NFR-14 — Upgradability

Data schemas must support versioning and forward migration so a user can retain years of historical data while the product evolves.

---

## 9. Data Model Requirements at Product Level

The exact schema is deferred to the Data Architecture & Storage Specification. At product level, the following conceptual entities are required.

### 9.1 Observation

A low-level fact emitted by the Windows/browser acquisition layer.

Examples:

- Foreground-window change
- Visibility-state change
- Process start/stop
- Window title change
- Browser domain observation
- Monitor/display association
- Session/lifecycle boundary

### 9.2 Interval

A normalized time span representing a stable state or activity condition.

Intervals are the main bridge between observations and analytics.

### 9.3 Canonical application

A stable logical identity for an application independent of an individual process instance.

### 9.4 Browser entity/domain

A stable analytics identity for browser-hosted services or domains.

### 9.5 Session

A derived span of continuous or semantically grouped use.

### 9.6 Classification

System- and user-defined category and productivity/leisure interpretation applied to an entity or observation class.

### 9.7 Aggregate

Precomputed time-bucket summaries used for efficient dashboard and timeline rendering.

### 9.8 Device

A stable identity representing an installation/device that contributed observations to a synchronized logical history.

### 9.9 Sync record

Metadata required to replicate, reconcile, encrypt, upload, download, and deduplicate synchronized history.

### 9.10 Tracking gap

An explicit representation of a period for which reliable tracking was not available.

---

## 10. Browser Privacy Model

Browser data is materially more sensitive than application-level usage. The product therefore separates browser collection into independently understandable layers.

### Default behavior

- Browser application usage: tracked.
- Domain: tracked for supported browsers.
- Page title: tracked by default.
- Private/incognito domain/title: not tracked.

### User controls

The user can independently disable page-title collection. The design should also allow domain collection to be disabled without requiring application tracking to be disabled.

### Product requirement

The UI must make it possible for a reasonable user to understand what is collected before enabling optional cloud synchronization.

---

## 11. Privacy and Trust Requirements

The product must make the following promises operationally true, not merely marketing language:

1. No account is required to track usage locally.
2. Tracking works offline.
3. Behavioral telemetry is off by default.
4. Local history can be inspected and deleted.
5. Browser-domain and page-title collection are controllable.
6. Private browsing is not treated as permission to collect private page/domain data.
7. Cloud sync does not require plaintext behavioral history to be stored in the cloud.
8. Authentication credentials and encryption material are handled separately.
9. Data collection and synchronization states are visible in settings.
10. The product does not silently expand collection during updates without appropriate disclosure and user control.

---

## 12. User Experience Requirements

The application UI should embody the following qualities:

- Modern
- Restrained
- Premium
- Typographically strong
- Spacious but information-dense where useful
- Precise spacing and alignment
- Subtle surfaces and borders
- Strong light/dark/system theming
- Fast perceived response
- Polished but restrained motion
- Clear hierarchy
- Minimal visual noise

The design direction draws inspiration from products such as Vercel/Geist, Arc, Notion, Apple, and Superhuman, while remaining an original design system.

The product should feel more like a carefully designed native Windows utility than a web dashboard wrapped in a desktop shell.

---

## 13. Information Architecture Requirements

The initial application should organize its major experiences around:

1. **Overview** — high-level current/recent usage summary.
2. **Timeline** — zoomable historical reconstruction.
3. **Applications** — application-level rankings, trends, sessions, and details.
4. **Browser** — domains/services, trends, and browser-specific history.
5. **Categories** — taxonomy and productivity/leisure analysis.
6. **Reports** — period summaries and comparisons.
7. **History/Calendar** — day-oriented navigation across historical usage.
8. **Settings** — privacy, retention, classification, appearance, account, sync, diagnostics.

Exact navigation structure is intentionally deferred to the Information Architecture & UX Specification.

---

## 14. Analytics Philosophy

The analytics layer should answer questions from multiple perspectives without introducing a single master score.

### Descriptive analytics

What happened?

- Time spent
- Frequency
- Sessions
- Switching
- Domain usage
- Category distribution

### Comparative analytics

How did it change?

- Previous day/week/month
- Trend lines
- Growth/decline
- Distribution shifts

### Temporal analytics

When did it happen?

- Hourly heatmaps
- Day-of-week patterns
- Calendar views
- Intraday timeline

### Interpretive analytics

What patterns are unusual or notable?

- Anomalies
- Long sessions
- Concentrated usage periods
- Changes in category mix
- Recurring patterns

Interpretive analytics must remain traceable to underlying observations and documented heuristics.

---

## 15. Performance Acceptance Criteria

Performance must be validated empirically rather than assumed from framework choice.

The architecture/implementation phases must establish repeatable benchmark scenarios including:

- Idle desktop with no active UI.
- Typical developer workflow.
- Typical browser-heavy workflow.
- Gaming session.
- Multiple monitors.
- Multiple simultaneously running applications.
- Long-running 24-hour and multi-day stability.
- High-event-rate application switching.

Release readiness for the background runtime requires demonstrating compliance with the target CPU/memory/I/O budgets across representative hardware.

A performance regression that materially violates the budget is a release blocker for the tracking runtime.

---

## 16. Success Metrics

The product's primary success criterion is sustained usefulness without noticeable system cost.

### Primary success signals

- User installs the application and leaves tracking enabled for at least one month.
- Historical timelines remain coherent and useful after weeks/months of use.
- Application and browser attribution is sufficiently accurate to support personal analysis.
- Background tracking remains effectively invisible in normal system usage.
- Users can understand and correct classification mistakes.
- Users trust the privacy model enough to keep tracking enabled.

### Product quality indicators

- Low rate of unexplained tracking gaps.
- Low frequency of incorrect canonical application resolution.
- Low browser attribution failure rate for supported browsers.
- Low data-loss rate after crashes/restarts.
- No silent duplication after synchronization/device migration.
- No measurable behavioral telemetry without explicit opt-in.

Exact numerical quality thresholds will be established in the QA and release specification after instrumentation and benchmark fixtures exist.

---

## 17. Risks and Product Responses

### Risk: OS/browser APIs change

**Response:** isolate acquisition adapters from the normalized data model; version and test browser/Windows integrations independently.

### Risk: Low-resource tracking conflicts with high-resolution data

**Response:** use event-driven observation where practical, compact normalized intervals, batched writes, and precomputed aggregates.

### Risk: Browser privacy expectations evolve

**Response:** make browser collection modular and independently configurable; do not build a model that assumes unrestricted browser introspection.

### Risk: Classification is subjective

**Response:** separate observed facts from classification, expose confidence, provide user override, and version classification rules.

### Risk: E2EE sync complicates account recovery

**Response:** design key management and recovery as a dedicated security problem; do not derive long-term encryption keys directly from a Google OAuth token or account identifier.

### Risk: Long-term database growth

**Response:** tiered retention, aggregation, compaction, and user-controlled retention settings.

### Risk: Background process becomes a hidden resource consumer

**Response:** treat resource budgets as acceptance criteria and benchmark continuously.

### Risk: UI complexity distracts from tracking accuracy

**Response:** enforce a strict boundary between tracking runtime and rich UI; tracking correctness takes precedence over decorative features.

---

## 18. Architecture Constraints Established by This PRD

This PRD intentionally does not freeze every technology choice. However, the following architectural constraints are considered product requirements:

1. The tracker and UI must be separable processes/components.
2. Tracking must continue when the UI is not running.
3. Local storage is the primary source of truth.
4. The normalized data model must outlive the current UI implementation.
5. Browser acquisition must be modular.
6. Classification must be replaceable/versionable.
7. Analytics must be derivable from durable local records.
8. Synchronization must be asynchronous and non-authoritative.
9. The cloud copy must be encrypted before upload under the final E2EE design.
10. Windows integration must be first-class.
11. The architecture must not make cross-platform expansion impossible, but cross-platform support is not a V1 deliverable.

Technology decisions such as WinUI 3 versus WPF versus other desktop stacks, IPC design, exact Windows API strategy, database layout, cryptographic primitives, and packaging architecture belong in later technical documents and ADRs.

---

## 19. Release Shape

The product should be built in vertical slices rather than by implementing the entire UI before the tracking foundation is proven.

A sensible release sequence is:

### Foundation

- Tracking runtime
- Foreground/visible observation
- Local database
- Crash/restart handling
- Basic application identity
- Resource benchmarks

### Core history

- Sessions
- Switching
- Classification
- Daily/weekly/monthly analytics
- Timeline
- User corrections/deletion

### Browser layer

- Supported browsers
- Domain tracking
- Page-title control
- Private browsing behavior

### Polish

- Advanced analytics
- Reports
- Light/dark/system themes
- Refined interactions
- Multi-monitor visualization where useful

### Cloud continuity

- Google authentication
- Encrypted Google Drive sync
- Device migration
- Conflict resolution
- Recovery/key lifecycle

Distribution readiness, Store packaging, standalone installation, and automatic updates are release-engineering concerns to be validated alongside production readiness.

---

## 20. Requirement Traceability

The following authoritative documents are expected to refine these requirements without contradicting them:

| Document | Primary purpose |
|---|---|
| `docs/02-scope-feature-specification.md` | V1 scope, feature behavior, priorities, acceptance criteria |
| `docs/03-information-architecture-ux.md` | Navigation, user flows, interaction behavior |
| `docs/04-visual-design-system.md` | Visual language, tokens, typography, motion |
| `docs/05-system-architecture.md` | Components, process boundaries, IPC, runtime architecture |
| `docs/06-windows-tracking-engine.md` | Windows observation and tracking semantics |
| `docs/07-data-architecture-storage.md` | SQLite model, retention, aggregation, migrations |
| `docs/08-browser-activity-acquisition.md` | Browser/domain/page-title acquisition and privacy behavior |
| `docs/09-privacy-data-governance.md` | Data lifecycle, user controls, minimization, policy |
| `docs/10-security-cryptography.md` | Local protection, E2EE, keys, recovery |
| `docs/11-google-drive-sync.md` | Sync protocol, conflict resolution, device continuity |
| `docs/12-performance-qa-release.md` | Benchmarks, correctness, testing, packaging, release gates |
| `docs/adr/` | Explicit architectural decisions and reversals |

Later documents may sharpen ambiguous implementation details but may not silently remove or weaken an established product invariant. Material changes to scope, privacy, performance budgets, or tracking semantics should result in a PRD revision or ADR with explicit rationale.

---

## 21. Open Questions Deferred to Architecture/Scope

The following are intentionally unresolved at this stage:

- Exact Windows observation APIs and event/polling cadence.
- Exact process model and IPC mechanism between tracker and UI.
- Exact desktop UI framework and rendering stack.
- Exact SQLite schema and aggregation cadence.
- Exact browser acquisition mechanism for each supported browser and browser-version compatibility policy.
- Exact encryption-at-rest strategy for the local database.
- Exact E2EE protocol and recovery model.
- Exact Google Drive API storage layout.
- Conflict-resolution semantics for simultaneous offline devices.
- Final report/export formats.
- Exact anomaly thresholds and insight heuristics.
- Exact benchmark hardware profiles.
- Exact installer/update architecture for each distribution channel.

These are not blockers for this PRD. They are explicit inputs to the subsequent technical documents.

---

## 22. Definition of Done for the PRD

This document is considered complete when the project team and AI development agents can use it as the stable product-level contract for:

- What the product is.
- Who it is for.
- What it must track.
- What it must analyze.
- What it explicitly must not become.
- What privacy guarantees shape implementation.
- What performance budgets constrain the architecture.
- What later specifications must define.

The next authoritative artifact is the **Scope & Feature Specification**, which should convert these product requirements into concrete V1 features, priorities, user-visible behaviors, edge cases, and acceptance criteria.
