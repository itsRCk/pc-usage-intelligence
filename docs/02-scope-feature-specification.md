# Scope & Feature Specification

**Product:** PC Usage Intelligence  
**Document:** 02 — Scope & Feature Specification  
**Status:** Authoritative V1 scope baseline — Pre-development  
**Parent document:** `docs/01-product-requirements.md`  
**Platform:** Windows 10 and Windows 11  
**Last updated:** 2026-09-02

---

## 1. Purpose

This document converts the Product Requirements Document into an implementable product scope.

It defines:

- What belongs in the first release.
- What is deferred.
- Feature priority.
- User-visible behavior.
- Important edge cases.
- Acceptance criteria.
- Release gates.

This document is intentionally more concrete than the PRD but does **not** define implementation details such as exact APIs, class structures, SQLite tables, cryptographic primitives, or UI component code. Those belong to later specifications.

---

## 2. Scope Model

The project uses four scope levels:

| Level | Meaning |
|---|---|
| **V1** | Required for the first credible public release. |
| **V1.x** | Valuable shortly after V1 but should not block the initial product. |
| **Future** | Product direction worth preserving architecturally, but intentionally deferred. |
| **Out of scope** | Not part of the product direction unless the product definition changes. |

Feature priority additionally uses:

- **P0 — Core:** release blocker if absent or unreliable.
- **P1 — Important:** expected in V1 unless explicitly descoped.
- **P2 — Enhancement:** useful but not required for the first release.
- **P3 — Future:** retained as direction only.

---

## 3. V1 Product Boundary

The V1 product is a **Windows usage-history system** with four essential layers:

1. **Acquisition** — observe computer/browser activity.
2. **History** — persist trustworthy local records.
3. **Interpretation** — resolve applications and classify activity.
4. **Analysis** — present useful historical patterns.

V1 succeeds when a user can install the product, leave it running for weeks, and later explore an accurate history of what applications and supported browser services they used and when.

Cloud sync is part of the intended product, but the local experience must remain complete and independent of it. If necessary for release sequencing, encrypted sync can ship after the local tracking/analytics foundation while preserving its architecture from the beginning.

---

# 4. Feature Matrix

| Feature | Priority | V1 | Notes |
|---|---:|:---:|---|
| Background tracking runtime | P0 | Yes | Core product |
| Foreground tracking | P0 | Yes | Authoritative active metric |
| Visible-time tracking | P0 | Yes | Separate from foreground |
| Process/window observation | P0 | Yes | Raw identity layer |
| Canonical app identity | P0 | Yes | Historical reclassification required |
| App switching detection | P1 | Yes | Derived from transitions |
| Session derivation | P1 | Yes | Rules documented separately |
| Multi-monitor awareness | P1 | Yes | First-class support |
| Crash/restart gap handling | P0 | Yes | Never fabricate usage |
| Local SQLite history | P0 | Yes | Primary source of truth |
| Retention/compaction | P1 | Yes | Sensible defaults + advanced controls |
| App categorization | P0 | Yes | Local deterministic rules |
| Classification confidence | P1 | Yes | Where meaningful |
| User classification overrides | P0 | Yes | Persistent and historical |
| Productivity/leisure dimension | P1 | Yes | User-controlled |
| Daily analytics | P0 | Yes | Core dashboard |
| Weekly analytics | P0 | Yes | Core dashboard |
| Monthly analytics | P0 | Yes | Core dashboard |
| Application rankings | P0 | Yes | Core analytics |
| Category breakdown | P0 | Yes | Core analytics |
| Hour/day patterns | P1 | Yes | Heatmaps |
| Longest/average sessions | P1 | Yes | Core analytics |
| Switching analytics | P1 | Yes | Core analytics |
| Browser application tracking | P0 | Yes | Supported browsers |
| Domain tracking | P0 | Yes | Browser analytics identity |
| Page-title tracking | P1 | Yes | Enabled by default, configurable |
| Incognito privacy behavior | P0 | Yes | App tracked, domain/title excluded |
| Browser trends | P1 | Yes | Core browser analytics |
| Zoomable timeline | P0 | Yes | Core product surface |
| Calendar history | P1 | Yes | Day navigation |
| Previous-period comparisons | P1 | Yes | Week/month initially |
| Anomaly indicators | P2 | Yes | Statistical/rule based |
| Personalized statistical insights | P2 | Yes | No LLM dependency |
| Reports | P1 | Yes | Local generation |
| Local history inspection/edit/delete | P0 | Yes | Trust requirement |
| Offline operation | P0 | Yes | Mandatory |
| Google sign-in | P1 | Yes* | Optional |
| E2EE Google Drive sync | P1 | Yes* | May follow local V1 if release sequencing requires |
| Device continuity | P1 | Yes* | Coupled to sync |
| Light/dark/system theme | P1 | Yes | Core polish |
| Zero telemetry by default | P0 | Yes | Product trust requirement |
| Optional diagnostics | P2 | Yes if shipped | Explicit opt-in only |
| Microsoft Store distribution | P1 | Release | Distribution target |
| Standalone installer | P1 | Release | Distribution target |
| Automatic updates | P1 | Release | Mechanism varies by channel |
| Focus score | — | No | Explicitly removed |
| Blocking/intervention | — | No | Explicitly removed |
| Focus sessions | — | No | Explicitly removed |
| Productivity coaching | — | No | Explicitly removed |

\* Cloud functionality must never be allowed to compromise the local-first product.

---

# 5. V1 Feature Specifications

## F-001 — Background Tracking Runtime

**Priority:** P0  
**Release:** V1

### Purpose

Provide a small, independent runtime that continuously observes usage without requiring the rich UI to remain open.

### User-visible behavior

- Tracking starts automatically according to the user's installation/settings state.
- Closing the main UI does not stop tracking.
- The tracker survives ordinary UI restarts.
- Tracking status is discoverable from the UI/settings.
- A failure produces a tracking gap rather than invented activity.

### Requirements

- Must run in the interactive user session where Windows desktop observation is available.
- Must not depend on a traditional service architecture if that would prevent access to the interactive desktop session.
- Must communicate with the UI through a controlled interface.
- Must buffer observations and persist them efficiently.
- Must expose enough diagnostics to determine whether tracking is active without collecting behavioral telemetry.

### Acceptance criteria

- Starting the PC and signing into Windows eventually produces tracking without opening the dashboard.
- Closing and reopening the UI does not reset tracking.
- Killing the tracker does not cause a synthetic usage interval to be created.
- After restart, the history clearly identifies the unavailable period.
- The runtime remains within the background performance budget under benchmark conditions.

---

## F-002 — Foreground Tracking

**Priority:** P0  
**Release:** V1

### Definition

Foreground time is the authoritative active application metric.

### Behavior

When the foreground window changes, the active interval for the previous target is closed and a new interval begins when reliable observation permits.

Repeated observations of an unchanged foreground target must not create unnecessary database records.

### Acceptance criteria

- Switching A → B produces a bounded A interval and a bounded B interval.
- Remaining on A does not produce a new event every polling cycle solely because the tracker checked the state.
- The recorded duration matches the observed state within the documented accuracy tolerance.

---

## F-003 — Visible-Time Tracking

**Priority:** P0  
**Release:** V1

### Definition

Visible time represents time during which an application/window is considered visible according to the supported Windows window/display semantics.

### Behavior

Visible time is tracked independently from foreground time.

Example:

- Browser visible on monitor 1.
- Editor visible on monitor 2.
- Browser is foreground.

Both may accumulate visible time, while only the browser accumulates foreground time.

### Acceptance criteria

- Visible and foreground metrics can differ.
- Multi-monitor scenarios do not cause hidden/occluded windows to be treated as active simply because their process exists.
- The product never labels visible time as active use.

---

## F-004 — Raw Process and Window Identity

**Priority:** P0  
**Release:** V1

### Capture

Where available and useful, retain:

- Process identifier/instance identity.
- Executable path.
- Process start identity.
- Window identifier.
- Window title.
- Application/package metadata.
- Timestamp.
- Monitor/display context.

### Important rule

Process IDs are not durable application identity. They are observation metadata.

### Acceptance criteria

- Two simultaneous instances of the same application can be distinguished at raw observation level.
- Reused process IDs across time do not merge unrelated sessions.
- Historical data remains interpretable after an application is updated or moved where the resolver can identify it.

---

## F-005 — Canonical Application Identity

**Priority:** P0  
**Release:** V1

### Purpose

Turn raw executable/process observations into a stable user-facing application entity.

### Resolution hierarchy

The implementation should prefer the strongest locally available identity evidence, such as:

1. Windows package/application metadata.
2. Executable identity and path.
3. File/application metadata.
4. Controlled fallback heuristics.

The exact resolver algorithm is defined in the architecture/tracking documents.

### User behavior

Users see canonical application names/icons rather than raw process names whenever resolution succeeds.

### Acceptance criteria

- Multiple process instances of the same application aggregate to the same canonical entity.
- Raw process identities remain available to the system for debugging and accurate interval reconstruction.
- User classification is attached to the canonical entity rather than a transient process ID.

---

## F-006 — Application Switching

**Priority:** P1  
**Release:** V1

### Definition

A switch occurs when the authoritative foreground target changes between distinct relevant application/window identities.

### Analytics

The system shall support:

- Switches per day.
- Switches per hour.
- Switches per application.
- Average time between switches where meaningful.

### Edge cases

- Repeated focus changes between windows belonging to the same canonical application may be represented as window switches without necessarily counting as application switches.
- System/transient windows should not create misleading application-switch counts where they can be identified reliably.

### Acceptance criteria

- Switching between two apps increments the relevant switch metric once per transition.
- Switching between windows of one app can be distinguished from switching applications.

---

## F-007 — Sessions

**Priority:** P1  
**Release:** V1

### Purpose

Provide human-readable periods of continuous use without discarding underlying intervals.

### Initial concept

A session is derived from contiguous or near-contiguous activity according to explicit rules. Sessionization must account for known system lifecycle boundaries and configured inactivity/gap rules.

### Requirements

- Session boundaries must be reproducible.
- Session rules must be versionable.
- Session duration must be derived, not manually maintained as the only record.

### Acceptance criteria

- Long uninterrupted use produces a coherent session.
- Known tracking gaps do not silently bridge unrelated sessions.
- Changing sessionization logic can be performed without destroying raw observations.

---

## F-008 — Multi-Monitor Support

**Priority:** P1  
**Release:** V1

### Behavior

The system must understand that a user can have multiple simultaneous visible application windows.

### Scope

V1 requires accurate tracking semantics rather than an elaborate multi-monitor visualization.

Monitor-aware visualizations are optional if they materially improve understanding without complicating the product.

### Acceptance criteria

- Connecting a second monitor does not corrupt active intervals.
- Display topology changes create appropriate state boundaries where necessary.
- An application can be associated with the correct display context when the underlying OS observation supports it.

---

## F-009 — Lifecycle and Tracking Gaps

**Priority:** P0  
**Release:** V1

### Covered transitions

- Lock.
- Unlock.
- Sleep.
- Resume.
- Sign-out.
- Sign-in.
- Shutdown.
- Restart.
- Tracker crash.
- Storage failure.

### Rule

The system must never infer that the user continued using the computer during a period for which observation was unavailable.

### Acceptance criteria

A timeline can visibly distinguish:

- Known activity.
- Known inactivity/system state where supported.
- Unknown/untracked gap.

---

# 6. Browser Features

## F-010 — Browser Application Tracking

**Priority:** P0  
**Release:** V1

Supported launch browsers:

- Chrome
- Edge
- Firefox
- Brave
- Arc, subject to a reliable supported acquisition path

Browser tracking must remain useful even when domain-level acquisition is unavailable.

### Acceptance criteria

- Browser process/application usage is recorded using the same core usage model as other applications.
- Browser acquisition failures do not break application-level tracking.

---

## F-011 — Domain Tracking

**Priority:** P0  
**Release:** V1

### Purpose

Provide a durable browser analytics identity.

### Behavior

The system normalizes browser observations to a domain/service identity suitable for aggregation.

Examples:

- Multiple YouTube tabs can contribute to one YouTube entity.
- Multiple tabs on the same domain can be aggregated while their raw observations remain distinct where retained.

### Requirements

- Domain collection is stored locally.
- Domain collection can be independently disabled.
- Unsupported/ambiguous browser observations must degrade gracefully.

### Acceptance criteria

- A browser session with several tabs on one service produces meaningful aggregate domain time.
- Domain analytics do not require page titles to be enabled.
- Turning off domain collection prevents new domain records while application tracking continues.

---

## F-012 — Page Titles

**Priority:** P1  
**Release:** V1

### Default

Enabled.

### Privacy control

User can disable page-title collection without disabling application tracking or domain tracking.

### Acceptance criteria

- Default installation records page-title data when supported.
- Disabling the setting stops new page-title collection.
- Existing stored page-title data is not silently retained forever after a user explicitly requests deletion; deletion behavior follows the privacy/data-governance specification.

---

## F-013 — Private/Incognito Browsing

**Priority:** P0  
**Release:** V1

### Required behavior

When a browser window is identifiable as private/incognito:

- Track the browser application.
- Do not store domain data.
- Do not store page-title data.

### Acceptance criteria

A private browsing session contributes to browser application usage but does not appear as identifiable website/page history.

---

# 7. Classification Features

## F-014 — System Taxonomy

**Priority:** P0  
**Release:** V1

Initial taxonomy:

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

The taxonomy is hierarchical and extensible.

### Acceptance criteria

- Every canonical application can resolve to a category or `Other`.
- Category changes do not alter raw observations.
- Aggregates can be recalculated when classification changes.

---

## F-015 — Automatic Classification

**Priority:** P0  
**Release:** V1

### Initial approach

Deterministic local rules.

Potential evidence includes:

- Application identity.
- Executable/package metadata.
- Known application mappings.
- Browser domain/service identity.

### Requirements

- No cloud dependency.
- Confidence represented where meaningful.
- Rules versioned.
- Unknown entities fall back safely.

### Future compatibility

Architecture should allow:

- Better deterministic rules.
- Local ML.
- Optional cloud-assisted classification.

None is required for V1.

---

## F-016 — User Overrides

**Priority:** P0  
**Release:** V1

Users can override system classifications.

Overrides should survive application updates and classification-rule changes.

### Acceptance criteria

- User changes an application's category.
- New observations use the user override.
- Existing analytics can be recalculated under the new classification.
- Removing the override returns the entity to the current system classification.

---

## F-017 — Productivity/Leisure Classification

**Priority:** P1  
**Release:** V1

This is a separate dimension from taxonomy.

Example:

> Development → Productivity

or

> YouTube → Leisure

The exact labels and UI treatment are defined by UX/design specifications.

### Rule

Productivity/leisure is an interpretation, not an OS-observed fact.

### Acceptance criteria

- Users can change the productivity/leisure interpretation.
- Analytics update consistently.
- The UI does not present the classification as objective truth.

---

# 8. Analytics Features

## F-018 — Core Period Analytics

**Priority:** P0  
**Release:** V1

Supported periods:

- Day
- Week
- Month
- Custom range where practical

Required metrics:

- Total foreground time.
- Total visible time where meaningful.
- Top applications.
- Category distribution.
- Productivity/leisure distribution.
- Top browser domains.
- Session statistics.

### Acceptance criteria

For any period with available data, totals shown in summary views reconcile with the underlying normalized history within the documented aggregation precision.

---

## F-019 — Application Rankings

**Priority:** P0  
**Release:** V1

Users can rank applications by:

- Foreground duration.
- Visible duration.
- Session count.
- Switch count where meaningful.

Default ranking should use foreground time because it is the authoritative active-use measure.

---

## F-020 — Category Analytics

**Priority:** P0  
**Release:** V1

Users can see usage grouped by the taxonomy hierarchy.

The analytics layer must distinguish:

- Raw application time.
- Classified category time.
- Productivity/leisure interpretation.

A classification change should be reflected in derived analytics without changing raw time.

---

## F-021 — Temporal Patterns

**Priority:** P1  
**Release:** V1

Required views:

- Hour-of-day heatmap.
- Day-of-week pattern.
- Calendar-style history.
- Intraday timeline.

### Acceptance criteria

A user can move from a month-level view to a selected day and inspect the relevant usage timeline without needing to manually construct a query.

---

## F-022 — Session Analytics

**Priority:** P1  
**Release:** V1

Required metrics:

- Longest sessions.
- Average session length.
- Session count.
- Application/session distribution.

Session metrics must use documented sessionization rules.

---

## F-023 — Switching Analytics

**Priority:** P1  
**Release:** V1

Required metrics:

- Total switches.
- Switches per active hour.
- Frequently switched-to/from applications where data volume supports it.

The UI should avoid implying that high switching frequency is inherently bad.

---

## F-024 — Browser/Domain Analytics

**Priority:** P0  
**Release:** V1

Required:

- Top domains.
- Domain time trends.
- Browser-to-domain relationship.
- Period comparisons.
- Domain detail where page titles are available.

---

## F-025 — Previous-Period Comparison

**Priority:** P1  
**Release:** V1

Initial comparisons:

- Today vs previous comparable day.
- This week vs previous week.
- This month vs previous month.

Comparison logic must account for incomplete current periods.

Example: a partially completed week must not misleadingly claim a full-week decline merely because fewer days have elapsed.

---

## F-026 — Anomaly Indicators

**Priority:** P2  
**Release:** V1

Initial implementation should be local, statistical/rule-based.

Potential examples:

- Unusually long application session.
- Unusually high usage of an application relative to personal baseline.
- Unusual late-night usage pattern relative to personal history.

### Constraint

An anomaly means unusual relative to the user's history, not inherently unhealthy or undesirable.

---

## F-027 — Personalized Insights

**Priority:** P2  
**Release:** V1

Initial insights are deterministic/statistical.

Examples:

- “Development accounted for more of your foreground time than your previous four-week average.”
- “You spent unusually long in [application] yesterday compared with your recent baseline.”

Future AI-generated explanations are explicitly deferred.

### Requirement

Every insight must be traceable to measurable historical data.

---

# 9. Timeline and History

## F-028 — Zoomable Timeline

**Priority:** P0  
**Release:** V1

Supported conceptual levels:

**Month → Week → Day → Hour → 15 min → 1 min → Individual events**

The implementation may use different internal resolutions provided the user experience preserves the intended semantic zoom.

### Interaction requirements

- Zoom into a period.
- Pan through history.
- Select a time range.
- Inspect contributing applications/domains.
- Navigate from aggregate data to finer detail.
- Clearly identify tracking gaps.

### Performance requirement

High-level views must use aggregates/intervals rather than loading all raw events for the entire history.

---

## F-029 — Calendar History

**Priority:** P1  
**Release:** V1

The user can navigate historical days through a calendar-oriented interface.

Calendar cells may communicate usage density, but visual intensity must not be presented as a value judgment.

Selecting a day opens its timeline and summary.

---

## F-030 — History Inspection and Correction

**Priority:** P0  
**Release:** V1

The user must be able to inspect what the system recorded and correct supported interpretations.

Correction hierarchy:

1. Prefer classification/entity metadata correction.
2. Use direct historical edits only where required.
3. Never silently rewrite raw observations as though the OS originally reported something different.

---

# 10. Reports

## F-031 — Reports

**Priority:** P1  
**Release:** V1

Reports should summarize a selected period using:

- Total usage.
- Top applications.
- Categories.
- Browser/domain usage.
- Temporal patterns.
- Comparisons.
- Notable statistical observations.

Reports are generated locally.

Exact export formats may be finalized after UX and reporting design. The initial implementation should prioritize a polished in-app report experience over a large number of export formats.

---

# 11. Local Data and Retention

## F-032 — Local-First Storage

**Priority:** P0  
**Release:** V1

The local database is the authoritative source of truth.

The system must support:

- High-resolution recent history.
- Derived intervals.
- Aggregates.
- Classifications.
- User overrides.
- Device metadata.
- Sync metadata.

### Acceptance criteria

The application remains fully functional when:

- The user has no account.
- Network is disconnected.
- Google authentication is unavailable.

---

## F-033 — Retention and Compaction

**Priority:** P1  
**Release:** V1

### Default policy

Use sensible defaults that preserve recent detail and compact older history.

### Advanced controls

Users can adjust retention within documented safe limits.

### Requirements

- Compaction must not unexpectedly erase the ability to answer supported long-term analytics questions.
- Aggregated history must remain attributable to its documented resolution.
- Deletion must be explicit and irreversible once completed, subject to normal filesystem/database recovery limitations.

---

# 12. Privacy and Settings

## F-034 — Privacy Controls

**Priority:** P0  
**Release:** V1

Required settings:

- Domain collection on/off.
- Page-title collection on/off.
- Private browsing handling explanation.
- Retention.
- Local history deletion.
- Cloud sync on/off.
- Account connection/disconnection.
- Optional diagnostics/crash reporting.

The user should be able to understand these settings without reading technical documentation.

---

## F-035 — Telemetry Policy

**Priority:** P0  
**Release:** V1

Behavioral telemetry is disabled by default.

Never send by default:

- Application usage history.
- Browser history.
- Domains.
- Page titles.
- Window titles.
- Productivity classifications.
- Usage-derived analytics.

Optional diagnostics must be explicit and separately consented.

---

# 13. Cloud and Device Continuity

## F-036 — Google Account Authentication

**Priority:** P1  
**Release:** V1 / V1.x

Authentication is optional.

Purpose:

- Associate a sync identity.
- Support device continuity.
- Support account-based recovery workflows where designed.

The Google account is not itself the encryption key.

---

## F-037 — End-to-End Encrypted Google Drive Sync

**Priority:** P1  
**Release:** V1 / V1.x

### Required behavior

- Encrypt sync payload locally before upload.
- Store ciphertext in the user's Google Drive.
- Synchronize asynchronously.
- Queue changes while offline.
- Continue tracking during sync.
- Never require the cloud to render local analytics.

### Scope constraint

High-resolution raw data may remain local and only selected/compacted records need synchronization, provided the resulting product still supports device continuity and the documented recovery model.

### Acceptance criteria

- Turning off the network does not stop tracking.
- Reconnecting eventually processes the sync queue.
- Cloud inspection does not expose plaintext behavioral records under the final E2EE design.
- Local analytics remain available while sync is unavailable.

---

## F-038 — Device Migration

**Priority:** P1  
**Release:** V1 / V1.x

A second Windows device can connect to the same logical user history.

### Requirements

- Unique device identity.
- Device origin retained for synchronized records.
- Deduplication.
- Chronological merge.
- Device-switch boundary available to history views where useful.

### Acceptance criteria

A user can install the application on a second PC, recover/synchronize history, and continue recording without overwriting or duplicating the first device's history.

---

# 14. Appearance and UI

## F-039 — Theme System

**Priority:** P1  
**Release:** V1

Supported modes:

- Light
- Dark
- System

### Design requirements

- Strong typography.
- Restrained surfaces.
- Precise spacing.
- Clear information hierarchy.
- Subtle borders and depth.
- Polished micro-interactions.
- No excessive decorative motion.

The visual design system will define exact tokens and components.

---

## F-040 — Responsive Desktop UI

**Priority:** P1  
**Release:** V1

The UI should work across typical laptop and desktop window sizes and remain useful on multi-monitor setups.

The application should not require a large monitor to understand basic daily usage.

---

# 15. Distribution

## F-041 — Microsoft Store

**Priority:** P1  
**Release:** Production V1

The product should be distributable through the Microsoft Store using an appropriate supported Windows packaging route.

Store constraints must not compromise the local-first data model.

---

## F-042 — Standalone Installer

**Priority:** P1  
**Release:** Production V1

A standalone installer is required for users who do not use the Store.

Installation should establish the tracker/UI lifecycle cleanly and provide a straightforward uninstall path.

---

## F-043 — Automatic Updates

**Priority:** P1  
**Release:** Production V1

Updates should preserve user history and safely migrate local schemas.

A failed update must not corrupt the primary local database.

---

# 16. Edge-Case Requirements

## 16.1 Application exits unexpectedly

Close the interval at the last reliable observation boundary and record a process/session boundary where appropriate.

Do not extend usage until a new observation confirms activity.

## 16.2 Computer locks

End/transition foreground and visible intervals according to supported Windows semantics. Do not count locked time as application use.

## 16.3 Computer sleeps

Record a lifecycle boundary. Do not interpolate usage across sleep.

## 16.4 Computer wakes

Begin new intervals only after reliable observations resume.

## 16.5 User switches monitors

Preserve monitor context where available. Do not double-count foreground time.

## 16.6 Multiple instances of one application

Maintain instance-level raw identity but aggregate to canonical application identity for standard analytics.

Where the user explicitly inspects instances, instance-level history may be exposed.

## 16.7 Window title changes

Treat title changes as metadata transitions rather than separate applications unless identity resolution indicates otherwise.

## 16.8 Browser tab changes

A domain/page-title observation change should update browser-level detail without unnecessarily creating a new application session.

## 16.9 Unsupported browser version

Continue application-level browser tracking and clearly degrade domain/page-title collection rather than failing the entire tracker.

## 16.10 Private browsing detection unavailable

Do not guess private status. The browser acquisition layer should fail closed for sensitive domain/title collection where privacy cannot be determined reliably, subject to the final browser specification.

## 16.11 Network unavailable

Track locally. Queue sync work.

## 16.12 Database temporarily unavailable

Keep a bounded in-memory buffer and attempt recovery. If durability cannot be guaranteed, record a tracking gap rather than silently losing the distinction.

## 16.13 User changes classification

Do not rewrite raw observations. Recalculate affected derived analytics.

## 16.14 User deletes data

Apply deletion consistently to local derived/aggregate data and synchronized representations according to the deletion protocol.

## 16.15 New device

Never assume that identical account identity means identical physical device. Device IDs remain distinct.

---

# 17. UX Acceptance Principles

Every major feature should satisfy these product-level UX principles:

### Discoverability

A user should be able to understand what a metric means without knowing implementation terminology.

### Explainability

Classification-derived metrics should indicate that they depend on classification.

### Reversibility

Destructive operations require appropriate confirmation and clear consequences.

### Privacy clarity

Sensitive collection settings should state what is collected, where it is stored, and what disabling the setting affects.

### No false precision

The UI must not display highly precise-looking metrics when the underlying observation is uncertain or aggregated.

### No judgment by default

Terms such as “productive,” “leisure,” “distracting,” or “unusual” must be framed as analytical classifications/patterns rather than moral judgments.

---

# 18. V1 Non-Goals

The following must not creep into V1 merely because they are technically possible:

- Website blocking.
- App blocking.
- Focus timers.
- Pomodoro.
- Break enforcement.
- Notifications encouraging productivity.
- Gamified streaks.
- Social comparisons.
- Public sharing of behavioral history.
- Advertising.
- Selling usage data.
- Mandatory account creation.
- Mandatory cloud processing.
- Cloud-only analytics.
- AI chatbot as the primary interface.
- A single composite productivity/focus score.

Any proposal in these areas requires an explicit product decision rather than being treated as a natural extension of the tracker.

---

# 19. Release Gates

A feature is not V1-ready merely because it works in a happy-path demo.

## Gate A — Tracking correctness

- Foreground intervals correct.
- Visible intervals correct for supported scenarios.
- Process/window identity stable.
- Lifecycle gaps handled.
- Browser application tracking independent of browser detail.

## Gate B — Data integrity

- No duplicate records from normal polling.
- Crash recovery tested.
- Database migrations tested.
- Retention/compaction tested.
- Historical recalculation tested.

## Gate C — Privacy

- No behavioral telemetry by default.
- Browser settings operate independently.
- Incognito behavior verified.
- Local deletion verified.
- Cloud payload is ciphertext under the production E2EE design.

## Gate D — Performance

Background runtime meets target:

- <1% idle CPU.
- <2% typical CPU.
- <150 MB idle memory.
- Minimal wakeups.
- Batched disk writes.
- Effectively zero GPU activity in tracker.

## Gate E — UX

- Daily usage understandable without documentation.
- Timeline navigation feels immediate for retained history.
- Light/dark/system modes are coherent.
- Classification corrections are discoverable.
- Privacy settings are understandable.

## Gate F — Long-running stability

The tracker must pass sustained tests representing at least several days of continuous operation and should be validated against longer-duration scenarios before production release.

---

# 20. Suggested V1 Milestones

## Milestone 1 — Observable computer

Deliver:

- Background runtime.
- Foreground tracking.
- Basic visible-time model.
- Raw process/window identity.
- Lifecycle boundaries.
- Minimal SQLite persistence.
- Performance harness.

**Exit condition:** trustworthy raw history exists for several days without unacceptable resource usage.

## Milestone 2 — Usable history

Deliver:

- Canonical application resolver.
- Sessions.
- Switching metrics.
- Taxonomy.
- User overrides.
- Daily/weekly/monthly analytics.
- Basic timeline.

**Exit condition:** a user can understand a week's computer usage from the application.

## Milestone 3 — Browser intelligence

Deliver:

- Supported browser adapters.
- Domain identity.
- Page titles.
- Incognito behavior.
- Browser analytics.

**Exit condition:** browser usage becomes a first-class part of the historical model without compromising privacy.

## Milestone 4 — Analytical depth

Deliver:

- Calendar history.
- Semantic timeline zoom.
- Previous-period comparisons.
- Session analytics.
- Switching analytics.
- Anomaly indicators.
- Statistical insights.
- Reports.

**Exit condition:** product provides meaningful long-term analysis rather than merely a screen-time counter.

## Milestone 5 — Product polish

Deliver:

- Final visual system.
- Light/dark/system modes.
- Motion/micro-interactions.
- Settings/privacy UX.
- Accessibility pass.
- Performance tuning.

**Exit condition:** product feels production-grade and remains within performance budgets.

## Milestone 6 — Cloud continuity

Deliver:

- Google authentication.
- E2EE key management.
- Google Drive sync.
- Conflict resolution.
- Device migration.
- Recovery workflows.

**Exit condition:** users can safely preserve and continue history across devices without weakening the privacy model.

---

# 21. Dependency Map

```text
Windows observation
        ↓
Raw observations
        ↓
Normalization + identity resolution
        ↓
Intervals ───────────────┐
        ↓                │
Sessions                 │
        ↓                │
Aggregates               │
        ↓                │
Analytics ← Classification
        ↓
Timeline / Dashboard / Reports

Browser acquisition ─→ Raw browser observations ─→ same normalization path

Local database ─────────→ source of truth
        ↓
Sync queue ─→ E2EE ─→ Google Drive
```

The critical dependency rule is that **UI and cloud are downstream of the local tracking model**. Neither may become a prerequisite for recording history.

---

# 22. Definition of V1 Success

V1 is successful if a new user can:

1. Install the application.
2. Leave it running without noticeable system impact.
3. Use their PC normally for weeks.
4. Return to the application and immediately understand their usage.
5. Inspect a specific day.
6. Zoom into a specific period.
7. See which applications and browser domains consumed time.
8. Understand category and productivity/leisure classifications.
9. Correct an incorrect classification.
10. Compare recent usage with previous periods.
11. Trust that gaps represent missing observation rather than invented usage.
12. Control sensitive browser data collection.
13. Delete their history if desired.
14. Continue using the product offline.

Cloud synchronization should extend this experience across devices, not define whether the core product works.

---

# 23. Open Decisions for Subsequent Documents

The following decisions remain intentionally deferred:

### UX

- Exact navigation model.
- Dashboard layout.
- Timeline interaction model.
- Visual encoding for gaps and visible/foreground time.
- Exact wording of classifications and insights.

### Architecture

- WinUI 3 vs WPF vs other native/desktop approaches.
- Tracker process lifecycle.
- IPC mechanism.
- Exact Windows APIs and event/polling strategy.
- Browser acquisition architecture.

### Data

- Exact SQLite schema.
- Event retention periods.
- Aggregate resolutions.
- Compaction algorithms.
- Historical recomputation strategy.

### Security

- Local database protection.
- E2EE protocol.
- Key derivation.
- Key recovery.
- Device trust.
- Sync metadata minimization.

### Release engineering

- Packaging format.
- Store submission route.
- Standalone installer technology.
- Update strategy.
- Crash reporting implementation, if any.

These decisions must be documented in later specifications or ADRs rather than silently embedded in implementation.

---

# 24. Requirement Traceability

This document refines `docs/01-product-requirements.md`.

The next documents should refine this scope in the following order:

1. `docs/03-information-architecture-ux.md`
2. `docs/04-visual-design-system.md`
3. `docs/05-system-architecture.md`
4. `docs/06-windows-tracking-engine.md`
5. `docs/07-data-architecture-storage.md`
6. `docs/08-browser-activity-acquisition.md`
7. `docs/09-privacy-data-governance.md`
8. `docs/10-security-cryptography.md`
9. `docs/11-google-drive-sync.md`
10. `docs/12-performance-qa-release.md`

Any later document that materially changes a P0 requirement, privacy invariant, performance budget, or explicit non-goal must record the change through an appropriate ADR and, where necessary, revise the PRD or this specification.

---

## Definition of Done

This document is complete when implementation agents can determine, for every proposed V1 feature:

- Whether it is in scope.
- Its priority.
- Its expected user-visible behavior.
- Its major edge cases.
- Its acceptance criteria.
- Which later document owns the implementation details.

The next artifact should be the **Information Architecture & UX Specification**, which converts these features into a concrete application structure and interaction model before the visual design system and technical architecture are finalized.
