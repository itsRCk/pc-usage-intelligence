# Information Architecture & UX Specification

**Product:** PC Usage Intelligence  
**Document:** 03 — Information Architecture & UX Specification  
**Status:** Authoritative UX baseline — Pre-development  
**Parent documents:** `docs/01-product-requirements.md`, `docs/02-scope-feature-specification.md`  
**Platform:** Windows 10 and Windows 11  
**Last updated:** 2026-09-02

---

## 1. Purpose

This document defines how users navigate, understand, inspect, and modify their computer-usage history.

It is the bridge between product requirements and visual design. It defines the application's information architecture, page hierarchy, interaction patterns, data navigation model, privacy UX, and accessibility expectations.

It does **not** define final colors, typography tokens, exact component styling, iconography, motion curves, or implementation-specific UI framework decisions. Those belong to `docs/04-visual-design-system.md` and later technical documents.

---

# 2. UX Vision

PC Usage Intelligence should feel like a **personal instrument for inspecting computer history** rather than a monitoring dashboard, productivity coach, or administrative control panel.

The UX should make complex historical data progressively understandable:

> **Overview → pattern → time range → entity → event/detail**

A user should be able to begin with almost no context and answer increasingly specific questions without learning an analytics system.

The interface should remain calm even when the underlying data is dense.

---

# 3. Core UX Principles

## 3.1 History before judgment

The primary UI should describe what happened rather than tell the user what they should have done.

Avoid language that implies moral evaluation of computer activity.

## 3.2 Progressive disclosure

Show the minimum information necessary at the current level of exploration. Deeper detail should become available through intentional drill-down.

## 3.3 One coherent history

Applications, browsers, domains, categories, sessions, and insights are different views over one underlying history. Navigation should reinforce this rather than make them feel like unrelated products.

## 3.4 Time is the primary navigation dimension

Usage is fundamentally temporal. The user should always know:

- What time range they are viewing.
- What granularity they are viewing.
- Where they are in history.
- How to move to adjacent or broader/narrower periods.

## 3.5 Explain data provenance

The UI should distinguish:

- Observed facts.
- Derived intervals/sessions.
- Classification.
- User overrides.
- Statistical inference.

The user should never need to inspect implementation details to understand whether a statement is observed or inferred.

## 3.6 Low interaction cost

Common actions — changing period, inspecting an application, drilling into a day, returning to the current date — should require few interactions.

## 3.7 Richness without dashboard noise

The interface may contain substantial information, but every visual element should answer a question or aid navigation.

## 3.8 Privacy should be part of normal UX

Sensitive collection settings must be understandable from the product itself, not hidden in legal text.

## 3.9 Non-blocking product

The analytics UI is a consumer of the history. It must never imply that closing, freezing, or minimizing the dashboard stops recording.

---

# 4. Mental Model

Users should understand the product through five nested concepts:

### 4.1 History

Everything the product has reliably observed over time.

### 4.2 Activity

A period in which an application, browser, window, or domain was observed in a defined state.

### 4.3 Entity

A stable thing the user can reason about, such as an application or browser domain.

### 4.4 Classification

An interpretation assigned to an entity, such as Development or Leisure.

### 4.5 Insight

A derived observation about the user's own history.

A useful conceptual model is:

```text
History
 ├── Applications
 │    ├── Sessions
 │    └── Windows / instances
 ├── Browsers
 │    └── Domains
 │         └── Page titles (optional)
 ├── Categories
 ├── Timeline
 ├── Reports
 └── Insights
```

The UI should let users move between these perspectives without losing their current time context.

---

# 5. Global Application Structure

The recommended primary navigation is:

```text
PC Usage Intelligence
│
├── Overview
├── Timeline
├── Applications
├── Browser
├── Categories
├── History
├── Reports
└── Settings
```

The exact visual navigation pattern is left to the visual design document. The information hierarchy is normative.

## 5.1 Overview

Purpose: answer “What has my computer usage looked like recently?”

Primary period selector:

- Today
- This week
- This month
- Custom

The overview should surface the most important summaries and act as an entry point to deeper analysis.

## 5.2 Timeline

Purpose: reconstruct activity over a selected period.

This is the most direct representation of what happened over time.

## 5.3 Applications

Purpose: inspect application usage, ranking, sessions, switching, trends, and classification.

## 5.4 Browser

Purpose: understand browser usage at the application, domain, and optional page-title levels.

## 5.5 Categories

Purpose: analyze usage grouped by the configured taxonomy and productivity/leisure dimensions.

## 5.6 History

Purpose: browse historical days/weeks/months through a calendar-oriented entry point.

## 5.7 Reports

Purpose: generate and review structured period summaries.

## 5.8 Settings

Purpose: configure privacy, retention, classification, appearance, account, sync, and diagnostics.

---

# 6. Persistent Global Context

The following concepts should remain consistent across primary screens:

### Current period

The user should never wonder which dates a metric represents.

### Period navigation

Users can move backward/forward and jump to today/current week/current month.

### Granularity

The interface should clearly indicate whether the current view is day, week, month, or a more detailed timeline level.

### Data state

Where relevant, the UI should expose:

- Tracking active.
- Tracking paused/unavailable.
- Data still processing.
- Sync pending.
- Offline.

This should remain subtle and informational rather than alarm-oriented.

---

# 7. Overview Information Architecture

## 7.1 Purpose

The Overview is the default landing experience and must provide immediate value after opening the application.

It should answer three questions:

1. How much did I use my computer?
2. What did I use it for?
3. When did I use it?

## 7.2 Recommended hierarchy

```text
Overview
│
├── Period selector
├── Primary usage summary
│   ├── Foreground time
│   ├── Visible time
│   └── Comparison vs previous period
│
├── Usage distribution
│   ├── Top applications
│   ├── Categories
│   └── Productivity / Leisure
│
├── Temporal pattern
│   └── Hour/day distribution
│
├── Browser summary
│   └── Top domains
│
├── Notable patterns
│   └── Statistical insights/anomalies
│
└── Continue exploring
    ├── Open timeline
    ├── Open calendar/history
    └── Open report
```

## 7.3 Overview hierarchy rules

Foreground time should receive visual priority over visible time because it is the authoritative active-use metric.

Visible time should be present as a complementary measure and clearly labeled.

The dashboard should not become a wall of cards. Related information should be grouped into meaningful analytical sections.

---

# 8. Timeline Information Architecture

The timeline is a core differentiator and requires a stricter interaction model than ordinary dashboard charts.

## 8.1 Timeline goals

A user should be able to:

- Understand the structure of a day.
- See which applications occupied different periods.
- Distinguish foreground and visible activity.
- Identify transitions and long sessions.
- Detect tracking gaps.
- Drill into browser domains/page titles where available.
- Move smoothly from coarse history to fine-grained history.

## 8.2 Semantic zoom

The intended conceptual navigation is:

```text
Month
  ↓
Week
  ↓
Day
  ↓
Hour
  ↓
15 minutes
  ↓
1 minute
  ↓
Individual events
```

Zooming changes both spatial resolution and the level of semantic detail shown.

The product should not merely scale the same chart indefinitely.

## 8.3 Timeline levels

### Month level

Show distribution and density of usage across the month.

Useful context:

- Daily usage amount.
- Notable high/low days.
- Category composition.
- Tracking gaps.

### Week level

Show daily patterns and major application/category distributions.

### Day level

Primary detailed exploration surface.

Show:

- Hour-by-hour structure.
- Major foreground sessions.
- Visible applications where useful.
- Browser activity.
- Gaps.
- Switch density.

### Hour level

Increase detail around app/window transitions and browser activity.

### 15-minute level

Allow precise inspection of local activity structure.

### 1-minute level

Support high-resolution event reconstruction where retained data permits it.

### Event level

Expose original observation metadata or a clean user-facing representation of it where appropriate.

## 8.4 Timeline lanes

The semantic model should support separate but related lanes such as:

- Foreground application.
- Visible applications.
- Browser/domain detail.
- System/lifecycle state.
- Tracking gaps.

The visual design may combine or collapse lanes at different zoom levels.

## 8.5 Timeline selection

Users can select a time interval.

Selection should support:

- Summary of selected duration.
- Top application/domain within selection.
- Open relevant entity detail.
- Create/open a report for the selection where supported.

## 8.6 Timeline gaps

Unknown/untracked periods must have a distinct visual treatment.

Never display a blank space that could be mistaken for “no usage” when the product actually has insufficient observations.

## 8.7 Timeline navigation

Required interactions:

- Scroll/pan through nearby time.
- Zoom in/out.
- Jump to a known date.
- Return to current time.
- Select a date from calendar navigation.

Keyboard navigation should support moving between adjacent time units.

---

# 9. Application Section

## 9.1 Application list

The Applications screen should support:

- Ranking by foreground time.
- Ranking by visible time.
- Session count.
- Switching count.
- Search.
- Period selection.
- Category filtering.
- Productivity/leisure filtering.

Foreground-time ranking is the default.

## 9.2 Application detail

Application detail should provide a coherent profile of one application.

Recommended hierarchy:

```text
Application detail
│
├── Identity
│   ├── Name
│   ├── Icon
│   └── Classification
│
├── Usage summary
│   ├── Foreground
│   ├── Visible
│   ├── Sessions
│   └── Switches
│
├── Trend
│   └── Usage over selected period
│
├── Time pattern
│   └── Hour/day usage distribution
│
├── Sessions
│   └── Longest/recent sessions
│
├── Timeline
│   └── Application-specific activity
│
└── Classification
    ├── Category
    ├── Productivity/leisure
    └── Override controls
```

## 9.3 Raw identity detail

Advanced detail may expose process/window identity information without making it part of the primary experience.

Raw technical identity should be available when it helps answer “why did this get tracked this way?”

---

# 10. Browser Section

## 10.1 Browser overview

The browser section should distinguish three levels:

```text
Browser application
    ↓
Domain/service
    ↓
Page title (optional)
```

## 10.2 Browser overview content

Show:

- Browser usage.
- Top domains.
- Domain trends.
- Domain/category relationships where available.
- Page-title detail where enabled.

## 10.3 Domain detail

Recommended hierarchy:

```text
Domain
├── Time summary
├── Trend
├── Session distribution
├── Time-of-day pattern
├── Browser distribution
└── Page-title detail
```

## 10.4 Privacy presentation

A visible privacy status should make it clear whether:

- Domain collection is enabled.
- Page-title collection is enabled.
- The selected context contains private/incognito exclusions.

Do not expose private browsing information simply by showing an identifiable “private session” page history.

## 10.5 Domain aggregation

Multiple tabs representing the same domain/service may be grouped for standard analytics.

The user should not need to understand tab-level implementation to use domain analytics.

---

# 11. Categories Section

## 11.1 Category hierarchy

The user should see the configured taxonomy as a navigable hierarchy.

Example:

```text
Development
 ├── Code editors
 ├── IDEs
 └── Developer tools

Education
 ├── Courses
 └── Reference

Gaming
 ├── Games
 └── Game launchers
```

The final subcategory set is owned by the classification specification, not this UX document.

## 11.2 Category detail

Category detail should show:

- Total foreground time.
- Visible time where relevant.
- Top entities.
- Trend.
- Time-of-day pattern.
- Productivity/leisure mix.

## 11.3 Classification editing

Editing should be straightforward and reversible.

A user should not need to open a global settings screen just to correct one application's category.

---

# 12. History / Calendar

## 12.1 Purpose

Calendar navigation provides a spatial index into historical time.

## 12.2 Calendar behavior

Each period/day should communicate:

- Whether tracking data exists.
- Approximate usage magnitude.
- Whether there are significant gaps.
- Whether notable patterns are available.

Do not turn the calendar into a “good day/bad day” scorecard.

## 12.3 Day opening

Selecting a day should open the day-level timeline with that date as the persistent context.

## 12.4 Month/week transition

The calendar should support moving between month and week contexts without losing the selected date.

---

# 13. Reports Section

## 13.1 Report creation flow

Recommended flow:

```text
Reports
  ↓
Select period
  ↓
Select report type/template
  ↓
Preview
  ↓
Generate
  ↓
View / Export
```

## 13.2 Report contents

Initial reports may include:

- Usage overview.
- Top applications.
- Categories.
- Browser domains.
- Temporal patterns.
- Comparisons.
- Notable statistical patterns.

## 13.3 Report trust

Every report should display its covered period and relevant data-quality caveats, especially incomplete or untracked intervals.

---

# 14. Settings Information Architecture

Settings should prioritize the categories users are likely to understand.

Recommended hierarchy:

```text
Settings
│
├── General
│   ├── Startup / tracking behavior
│   └── Current device information
│
├── Privacy & Data
│   ├── Domain collection
│   ├── Page-title collection
│   ├── Private browsing behavior
│   ├── Retention
│   └── Delete history
│
├── Classification
│   ├── Taxonomy
│   ├── Overrides
│   └── Productivity/leisure defaults
│
├── Appearance
│   ├── Light
│   ├── Dark
│   └── System
│
├── Account & Sync
│   ├── Google account
│   ├── Sync status
│   ├── Device list
│   └── Recovery/key information
│
├── Diagnostics
│   ├── Crash reporting
│   └── Local diagnostic tools
│
└── About
    ├── Version
    ├── Licenses
    └── Data/storage information
```

## 14.1 Privacy & Data settings

This is a high-trust area.

Each setting should explain:

- What it controls.
- What data is affected.
- Whether it affects future data only or also existing data.
- Whether cloud-synced records are affected.

## 14.2 Delete history

Deletion should be deliberate and scoped.

Supported concepts should include:

- Delete selected time range.
- Delete browser detail.
- Delete all local history.
- Account/sync data deletion where applicable.

Dangerous actions should explain downstream consequences before confirmation.

---

# 15. Global Search

A global search capability is recommended but not required as a foundational architectural dependency.

Search should be able to find, where available:

- Applications.
- Browser domains.
- Calendar dates.
- Reports.

Search results should preserve the current period context whenever possible.

Example:

> Search “YouTube” → open YouTube domain detail for the currently selected period rather than discarding the period unexpectedly.

---

# 16. Cross-Page Navigation Rules

## Rule 1 — Preserve time context

When moving from Overview to Applications, Timeline, Browser, or Categories, preserve the selected date/range whenever semantically possible.

## Rule 2 — Preserve entity context

When drilling into an application/domain/category, retain the period that led the user there.

## Rule 3 — Support upward navigation

Every deep view must provide an obvious path back to its parent analytical context.

## Rule 4 — Avoid dead ends

A user should never need to return to the Overview merely to continue exploring a selected date/entity.

## Rule 5 — Deep links

Later releases may support direct URLs/deep links into local views, but V1 navigation must work without them.

---

# 17. Core User Flows

## Flow A — First launch

```text
Install
 ↓
Launch
 ↓
Privacy / data-collection introduction
 ↓
Confirm defaults
 ↓
Tracker starts
 ↓
Dashboard available
```

The onboarding should explain the important browser privacy distinction without overwhelming the user.

The product should not require account creation.

## Flow B — Review today's usage

```text
Open app
 ↓
Overview defaults to today
 ↓
See foreground time + major applications
 ↓
Open Timeline
 ↓
Inspect activity period
 ↓
Open application/domain detail if needed
```

## Flow C — Investigate a specific day

```text
History / Calendar
 ↓
Select date
 ↓
Day Timeline
 ↓
Zoom
 ↓
Select period
 ↓
Inspect contributing entities
```

## Flow D — Correct classification

```text
Application detail
 ↓
Classification
 ↓
Choose category
 ↓
Choose productivity/leisure interpretation
 ↓
Save
 ↓
Affected analytics refresh
```

The correction should clearly indicate whether it affects future observations only or historical interpretation as well. The product baseline expects historical derived analytics to be recalculable.

## Flow E — Disable page-title collection

```text
Settings
 ↓
Privacy & Data
 ↓
Page titles
 ↓
Off
 ↓
Explain effect
 ↓
Confirm
```

Existing data-handling consequences must be disclosed.

## Flow F — Review application history

```text
Applications
 ↓
Search/select application
 ↓
Application detail
 ↓
Change period
 ↓
View trend/session/timeline
 ↓
Optional classification edit
```

## Flow G — Sync setup

```text
Settings
 ↓
Account & Sync
 ↓
Connect Google account
 ↓
Explain E2EE + Drive storage
 ↓
Authenticate
 ↓
Establish encryption/recovery state
 ↓
Enable sync
```

The UI must not imply that signing into Google automatically makes plaintext behavioral history available to Google or the application provider.

## Flow H — New-device migration

```text
Install on new PC
 ↓
Sign in
 ↓
Recover/establish sync encryption state
 ↓
Download encrypted history
 ↓
Merge/reconcile
 ↓
Continue local tracking
```

The user should see that the new PC is a new device while the history remains one logical personal history.

---

# 18. Data States in the UI

The interface must distinguish at least these states:

### Recorded activity

Reliable observed activity.

### Derived activity

Sessions, categories, or insights computed from recorded activity.

### Unknown / tracking gap

The system could not reliably observe activity.

### Private browsing exclusion

Browser application time exists, but sensitive browser details were intentionally not collected.

### Not collected by setting

A feature such as page-title tracking is intentionally disabled.

### Unsupported / unavailable

The system could not obtain a particular detail due to a technical limitation.

These states should not be conflated. For example, “domain not shown because page-title collection is disabled” differs from “domain data was unavailable because the browser adapter failed.”

---

# 19. Empty States

The UI must define meaningful empty states for:

- New installation with no history.
- Selected period with no tracked usage.
- Selected period containing only tracking gaps.
- Browser detail unavailable.
- No entities matching a search/filter.
- Reports with insufficient data.
- Sync not configured.
- Classification not yet resolved.

Empty states should explain why something is empty where the reason is knowable.

Avoid implying that “no data” means “no usage” when tracking was not active.

---

# 20. Error States

Errors should distinguish:

### Local tracking problem

Example: acquisition subsystem unavailable.

### Local storage problem

Example: database cannot be written.

### Browser adapter problem

Application tracking may continue while browser detail is unavailable.

### Sync problem

Local history remains available; sync may be delayed.

### Authentication problem

The user can continue local usage tracking.

The primary principle is graceful degradation: a failure in a secondary layer should not make the whole application appear broken.

---

# 21. Notifications and System Tray UX

The product may expose a Windows system-tray entry for status and access to the dashboard.

The tray experience should remain intentionally quiet.

It may expose:

- Open application.
- Tracking status.
- Privacy/sync status summary.
- Settings.
- Exit/stop tracking where applicable.

It should not routinely notify users about their usage.

Behavioral reminders and productivity interventions are out of scope.

---

# 22. Onboarding UX

Onboarding must establish trust before collecting sensitive browser details.

Minimum concepts to explain:

1. Tracking runs locally.
2. The app works without an account.
3. Browser domain/page-title collection are configurable.
4. Private browsing details are excluded.
5. Behavioral telemetry is off by default.
6. Optional sync uses encrypted data.

The onboarding should avoid a long wizard. A small number of well-designed steps is preferable.

---

# 23. Privacy UX Copy Rules

Privacy explanations should use concrete language.

Prefer:

> “Page titles are saved on this PC so the timeline can show what you were viewing. Turn this off to keep only browser/domain information.”

Avoid:

> “Enhanced browser telemetry can be disabled.”

Privacy settings must answer the user's likely questions:

- What is collected?
- Why?
- Where is it stored?
- Does it leave this PC?
- What happens if I turn this off?

---

# 24. Classification UX Rules

Classification editing is part of the analytical experience, not an administrative afterthought.

The UI should show:

- Current category.
- Whether classification is system-derived or user-overridden.
- Confidence where useful.
- Productivity/leisure interpretation.
- A simple edit action.
- A clear way to restore the system default.

Example semantic state:

> **Development** · User override

rather than exposing implementation-oriented terms such as `classification_source = USER_OVERRIDE`.

---

# 25. Comparison UX

Period comparisons must communicate comparability.

When comparing complete periods:

> This week: 31h 42m  
> Previous week: 27h 18m  
> Change: +4h 24m

For incomplete current periods, the UI should explicitly mark the comparison as partial or use a normalized comparable calculation where appropriate.

Avoid red/green value judgment as the only communication mechanism. The visual design system should define neutral, accessible comparison semantics.

---

# 26. Insight UX

Insights are secondary to the underlying data.

Each insight should have an easy path to the supporting evidence.

Example:

> “You spent more time in development applications this week than your recent average.”
>
> **View evidence**

The evidence view should select the relevant period/application/category context.

The user should never be forced to trust an insight without a path to inspect the source pattern.

---

# 27. Accessibility Requirements

The application should support:

- Full keyboard navigation for core workflows.
- Logical focus order.
- Visible focus indication.
- Semantic control names.
- Accessible chart alternatives or data tables.
- Text scaling without destructive layout failures.
- Sufficient contrast under all supported themes.
- Reduced-motion preferences where supported by the platform.
- Tooltips or descriptions for unfamiliar visual encodings.

Charts must not be the only way to access important numerical information.

---

# 28. Responsive Window Behavior

Although this is a desktop application, it must accommodate meaningful ranges of window sizes.

### Compact window

Prioritize:

- Current period.
- Main usage metric.
- Top applications.
- Primary navigation.

### Standard desktop window

Show the intended full dashboard hierarchy.

### Wide window / multi-monitor

Use additional space for deeper timeline detail, comparisons, and secondary analytical context rather than simply enlarging cards.

The application should not depend on full-screen use.

---

# 29. Interaction Patterns

## 29.1 Selection

Selection should generally be explicit and persistent enough for the user to inspect details.

## 29.2 Hover

Hover can provide lightweight context but must never be the only way to access important information.

## 29.3 Context actions

Right-click/context actions may support advanced operations such as:

- Open application detail.
- Reclassify.
- Exclude/delete where supported.
- Copy diagnostic information.

They must have accessible alternatives.

## 29.4 Modals

Use modal dialogs sparingly for destructive or consequential actions.

Prefer inline editing for ordinary classification changes.

## 29.5 Confirmation

Confirm destructive operations, but do not confirm harmless navigation or ordinary edits unnecessarily.

---

# 30. Performance-Aware UX Requirements

UX decisions must account for the distinction between data volume and rendering volume.

### Requirement 1

Opening the dashboard must not cause the application to load the entire historical database.

### Requirement 2

Timeline rendering should request only the resolution and time window needed for the current viewport.

### Requirement 3

Changing the period should reuse cached/aggregated data where possible rather than rebuilding the entire history.

### Requirement 4

Animations must not delay access to numerical information.

### Requirement 5

The tracker must remain independent of UI rendering workload.

---

# 31. Sync UX

Sync should feel like a background continuity feature rather than a cloud-first architecture.

### Status states

- Not configured.
- Connecting.
- Syncing.
- Up to date.
- Waiting for network.
- Needs attention.

### User expectations

When sync is unavailable:

> “Your local history is safe. Sync will resume when available.”

Avoid language that implies local history is incomplete merely because cloud synchronization is pending.

---

# 32. Device UX

The Account & Sync area should expose participating devices.

For each device, useful information may include:

- User-defined device name.
- Device type/Windows identity where appropriate.
- Last sync time.
- First/last observed contribution.
- Current device indicator.

The user should understand that devices contribute to one logical history while retaining distinct origins.

---

# 33. Deletion UX

Deletion is a high-risk workflow and requires strong clarity.

The UI should communicate:

- What is being deleted.
- The affected period/entities.
- Whether the deletion affects classifications/aggregates.
- Whether synchronized copies are affected.
- Whether the action is reversible.

A delete operation should not silently become an “exclude from this chart” operation or vice versa.

---

# 34. Terminology

Preferred user-facing terms:

| Concept | Preferred term |
|---|---|
| Foreground duration | Foreground time |
| Visible duration | Visible time |
| Canonical application | Application |
| Domain entity | Domain / website |
| Raw observation | Usually hidden; “recorded activity” where needed |
| Interval | Activity period / timeline segment |
| Classification | Category / classification depending context |
| User override | User classification |
| Tracking gap | Tracking gap / untracked period |
| Device identity | Device |

Avoid exposing implementation vocabulary unless the user opens an advanced/diagnostic context.

---

# 35. Required UX Scenarios for Design Validation

Before visual design is finalized, prototype at least these scenarios:

1. First launch and privacy setup.
2. Open Overview and understand today in under a few seconds.
3. Navigate from month to day timeline.
4. Zoom from day to minute/event detail.
5. Inspect a long application session.
6. Search for an application.
7. Inspect a browser domain.
8. Understand an incognito/private browsing exclusion.
9. Disable page-title collection.
10. Reclassify an application.
11. Compare this week with last week.
12. Understand a tracking gap.
13. Delete a selected period.
14. Set up Google sync.
15. View sync/device status while offline.
16. Use the application at a compact desktop window size.
17. Perform core navigation entirely from keyboard.

---

# 36. UX Quality Bar

The experience should satisfy these qualitative tests:

### “I understand it.”

A user can explain what foreground time, visible time, a tracking gap, and a category mean.

### “I can find it.”

A user can reach a specific day, application, or domain without wandering through unrelated screens.

### “I can verify it.”

An analytical conclusion can be traced back to its supporting history.

### “I can correct it.”

Incorrect classifications can be fixed without fighting the interface.

### “I trust it.”

Privacy behavior is visible, predictable, and controllable.

### “It stays out of my way.”

The background tracker is not experienced as another application demanding attention.

---

# 37. Deferred UX Decisions

The following belong in the Visual Design System or later product exploration:

- Exact color palette.
- Typography family and type scale.
- Spacing tokens.
- Surface/elevation language.
- Icon system.
- Chart grammar.
- Timeline visual encoding.
- Animation curves/durations.
- Navigation component treatment.
- Exact responsive breakpoints.
- Illustration strategy.
- Empty-state artwork.

The following belong in technical design:

- UI framework.
- IPC.
- Data-query architecture.
- Rendering implementation.
- Caching architecture.
- Process lifecycle.

---

# 38. Relationship to Later Documents

| Document | Responsibility |
|---|---|
| `docs/01-product-requirements.md` | Product-level requirements and invariants |
| `docs/02-scope-feature-specification.md` | V1 features, priorities, behavior, acceptance criteria |
| `docs/03-information-architecture-ux.md` | This document: structure, navigation, interaction, UX behavior |
| `docs/04-visual-design-system.md` | Visual language and component system |
| `docs/05-system-architecture.md` | Application/process/data architecture |
| `docs/06-windows-tracking-engine.md` | Tracking implementation semantics |
| `docs/07-data-architecture-storage.md` | Data schema, retention, aggregation |
| `docs/08-browser-activity-acquisition.md` | Browser acquisition mechanisms and constraints |
| `docs/09-privacy-data-governance.md` | Privacy lifecycle and governance |
| `docs/10-security-cryptography.md` | Local/cloud security and E2EE |
| `docs/11-google-drive-sync.md` | Sync protocol and device continuity |
| `docs/12-performance-qa-release.md` | Validation, performance, accessibility, release |

---

# 39. UX Definition of Done

This document is complete when a designer or AI design agent can determine:

- What the primary navigation contains.
- What each major screen is for.
- How users move between analytical levels.
- How time context is preserved.
- How the timeline behaves at multiple resolutions.
- How application/browser/category detail is structured.
- How privacy and classification controls behave.
- How gaps and unavailable data are represented conceptually.
- Which interactions are core and which are advanced.
- What scenarios must be validated in prototypes.

The next document should define the visual system that turns this information architecture into a distinctive, cohesive interface.
