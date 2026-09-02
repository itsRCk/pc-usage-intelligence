# Visual Design System Specification

**Product:** PC Usage Intelligence  
**Document:** 04 — Visual Design System Specification  
**Status:** Authoritative visual baseline — Pre-development  
**Parent documents:** `docs/01-product-requirements.md`, `docs/02-scope-feature-specification.md`, `docs/03-information-architecture-ux.md`  
**Platform:** Windows 10 and Windows 11  
**Last updated:** 2026-09-02

---

## 1. Purpose

This document defines the visual language and interaction polish for PC Usage Intelligence.

It is deliberately more specific than the UX specification while remaining implementation-framework agnostic. It defines visual principles, design tokens, typography, surfaces, states, chart grammar, timeline visual language, motion, accessibility, and component behavior.

The goal is not to imitate Vercel/Geist, Arc, Notion, Apple, or Superhuman. Those products are references for restraint, typography, hierarchy, and polish. PC Usage Intelligence requires an original visual identity appropriate to a serious personal analytics application.

---

# 2. Design Direction

## 2.1 Desired character

The product should feel:

- **Precise** rather than decorative.
- **Calm** rather than sterile.
- **Dense** when information warrants density, but never cramped.
- **Premium** without visual excess.
- **Native** rather than web-wrapped.
- **Analytical** without feeling corporate.
- **Personal** without becoming playful or gamified.

The interface should communicate that the underlying data is trustworthy.

## 2.2 Visual thesis

> **A quiet instrument for understanding time.**

The interface should not compete with the data. Surfaces, borders, typography, icons, and motion should establish hierarchy while allowing timelines and usage patterns to remain the visual focus.

## 2.3 Anti-goals

Avoid:

- Dashboard-card overload.
- Excessive gradients.
- Glassmorphism as a default surface treatment.
- Large decorative illustrations.
- Heavy shadows.
- Excessive rounded containers.
- Rainbow analytics charts.
- Aggressive gamification.
- Constant animation.
- Generic SaaS-admin aesthetics.
- Web-style loading spinners for every small operation.

---

# 3. Design Principles

## 3.1 Hierarchy before decoration

Visual emphasis should correspond to information importance.

## 3.2 Time is the primary visual axis

Usage is fundamentally temporal. Charts, timelines, comparisons, and calendar views should share a consistent temporal grammar.

## 3.3 One visual language, many lenses

Applications, domains, categories, productivity/leisure, and sessions are different interpretations of the same history. They should feel like views of one system rather than separate mini-applications.

## 3.4 Restraint creates trust

The interface should avoid visual tricks that make insignificant changes appear important.

## 3.5 Precision without false certainty

The design should not communicate more precision than the underlying observation supports.

## 3.6 Color carries meaning, not decoration

Color should communicate state, category, selection, emphasis, or semantic distinction. It should not be used merely to make charts colorful.

## 3.7 Motion should explain

Animation should communicate continuity, causality, selection, and state change. It should never delay access to information.

## 3.8 Background tracking has no visual personality

The tracking runtime should remain invisible except for necessary status/diagnostic surfaces. The visual system belongs primarily to the UI application.

---

# 4. Layout System

## 4.1 Base grid

Use an 8-point base spacing system with 4-point subdivisions where necessary.

Recommended spacing scale:

| Token | Value | Typical use |
|---|---:|---|
| `space-1` | 4 px | Icon/text micro-gap |
| `space-2` | 8 px | Compact component gap |
| `space-3` | 12 px | Small internal padding |
| `space-4` | 16 px | Standard component padding |
| `space-5` | 20 px | Section spacing |
| `space-6` | 24 px | Card/section separation |
| `space-8` | 32 px | Major grouping |
| `space-10` | 40 px | Page section spacing |
| `space-12` | 48 px | Major page rhythm |
| `space-16` | 64 px | Large visual separation |
| `space-20` | 80 px | Exceptional hero/empty-state spacing |

The implementation may introduce additional values only when necessary to maintain optical alignment.

## 4.2 Page margins

Desktop content should generally use generous horizontal margins with a responsive maximum content width.

The application should not force a narrow mobile-style content column on desktop.

## 4.3 Density modes

Do not introduce a user-facing density selector in V1.

Instead, use a deliberate default density:

- Compact enough for analytical tables and timelines.
- Spacious enough for dashboards and settings.

---

# 5. Shape and Geometry

## 5.1 Corner radii

Use a restrained radius system:

| Token | Suggested value | Use |
|---|---:|---|
| `radius-sm` | 6 px | Inputs, small controls |
| `radius-md` | 8 px | Buttons, compact surfaces |
| `radius-lg` | 12 px | Cards, panels |
| `radius-xl` | 16 px | Major containers |
| `radius-pill` | 999 px | Tags, pills, compact status |

Do not make every surface rounded.

## 5.2 Borders

Prefer subtle borders over strong shadows for structural separation.

Borders should establish hierarchy without creating a grid of visible boxes around every element.

## 5.3 Shadows

Shadows should be:

- Sparse.
- Soft.
- Contextual.
- Primarily used to communicate elevation for menus, dialogs, and floating surfaces.

A flat surface should not require a shadow merely to look polished.

---

# 6. Color System

## 6.1 Strategy

The color system should be semantic rather than component-specific.

Define tokens by role:

- Background.
- Elevated background.
- Primary surface.
- Secondary surface.
- Border.
- Strong border.
- Primary text.
- Secondary text.
- Muted text.
- Disabled text.
- Accent.
- Accent foreground.
- Positive.
- Warning.
- Negative.
- Informational.
- Selection.
- Focus ring.

Exact hexadecimal values should be selected during visual prototyping and accessibility validation rather than treated as immutable product requirements at this stage.

## 6.2 Neutral-first palette

The majority of the interface should use neutral tones.

Semantic accent colors should be used selectively.

A dashboard with ten categories should not automatically produce ten saturated colors.

## 6.3 Dark mode

Dark mode should be designed as a native dark palette, not a mathematically inverted light palette.

Requirements:

- Avoid pure black as the dominant background unless justified by a specific surface.
- Maintain clear hierarchy between base, elevated, and interactive surfaces.
- Reduce excessive contrast between neighboring surfaces.
- Preserve chart readability without neon saturation.

## 6.4 Light mode

Light mode should remain calm and slightly warm/neutral where appropriate rather than resembling a default white web page.

## 6.5 System theme

System theme follows the Windows appearance preference and updates without requiring a restart where supported by the chosen framework.

---

# 7. Typography

## 7.1 Goals

Typography is a primary part of the product identity.

It should be:

- Highly legible.
- Compact enough for analytics.
- Distinctive through hierarchy rather than decorative fonts.
- Excellent for numbers and timestamps.

## 7.2 Font strategy

Prefer a high-quality native Windows/system sans-serif stack appropriate to the chosen UI framework, with an optional bundled fallback only where necessary for consistency.

Do not ship a custom display font merely for branding.

## 7.3 Type scale

Recommended starting scale:

| Role | Size | Weight |
|---|---:|---|
| Display | 32–40 px | Semibold |
| Page title | 24–28 px | Semibold |
| Section title | 18–20 px | Semibold |
| Body | 14–16 px | Regular |
| Secondary | 13–14 px | Regular |
| Caption | 11–12 px | Medium/Regular |
| Metric | 28–40 px | Semibold |
| Compact metric | 18–24 px | Semibold |

Exact values should be refined against the selected Windows typography stack.

## 7.4 Numerical typography

Usage metrics should use tabular or otherwise stable numeral behavior where supported so changing values do not cause excessive horizontal movement.

Duration and timestamp formats must be visually distinguishable from ordinary prose.

---

# 8. Iconography

Use a coherent outline/icon system with:

- Consistent stroke weight.
- Consistent optical size.
- Simple silhouettes.
- Strong recognition at small sizes.

Icons should support labels rather than replace them where ambiguity would result.

Do not mix multiple unrelated icon families.

Application icons are an exception: canonical application branding may be shown when available.

---

# 9. Surfaces and Containers

## 9.1 Surface hierarchy

Recommended hierarchy:

1. Window background.
2. Content surface.
3. Elevated panel.
4. Floating surface.
5. Modal/dialog.

Not every page section requires a separate surface.

## 9.2 Card philosophy

Cards are useful for:

- Distinct metrics.
- Independent analytical summaries.
- Actions with a clear boundary.

Cards should not be used merely to put a border around ordinary text.

## 9.3 Dashboard composition

Prefer compositions such as:

```text
Page header
    ↓
Primary usage summary
    ↓
Large temporal visualization
    ↓
Supporting analytical views
    ↓
Detailed ranking/history
```

rather than:

```text
12 equal cards
12 unrelated charts
```

The visual hierarchy should tell the user where to look first.

---

# 10. Navigation Visual Language

The primary navigation should be quiet and persistent.

Recommended major destinations:

- Overview
- Timeline
- Applications
- Browser
- Categories
- Reports
- Settings

Navigation should communicate the current location without oversized active-state containers.

The selected state should be obvious through a combination of:

- Text/icon emphasis.
- Subtle surface or indicator.
- Accessible focus/selection state.

---

# 11. Metrics

## 11.1 Metric hierarchy

A metric should visually communicate:

1. Value.
2. Unit.
3. Time period/context.
4. Comparison, if present.
5. Confidence/qualification, if necessary.

Example structure:

```text
7h 42m
Foreground time
Today        ↑ 12%
```

## 11.2 Comparisons

Comparison indicators should be secondary to the primary value.

Do not use red/green solely because a number went up/down when the direction has no inherent positive or negative meaning.

For example, increased gaming time is not automatically negative.

---

# 12. Timeline Visual System

The timeline is the signature visualization of the product.

## 12.1 Core visual grammar

Every timeline representation should communicate:

- Time position.
- Duration.
- Entity/application.
- Foreground vs visible state where relevant.
- Category/classification where useful.
- Tracking gaps.

## 12.2 Foreground representation

Foreground intervals should have the strongest visual weight because foreground time is the authoritative active-use metric.

## 12.3 Visible representation

Visible-only time should have a clearly subordinate visual treatment.

It must not visually imply equal confidence or importance with foreground time.

## 12.4 Tracking gaps

Gaps should be visually distinct from zero usage.

A gap means “the system could not reliably observe this period,” not “the user did nothing.”

Use:

- A neutral patterned/segmented treatment.
- Explicit labels on inspection.
- No alarming error color unless a diagnostic state requires it.

## 12.5 Semantic zoom

As the user zooms:

- Month: distribution and density.
- Week: day-level patterns.
- Day: major sessions and application bands.
- Hour: detailed activity blocks.
- 15-minute: fine-grained intervals.
- 1-minute: detailed transitions.
- Event: raw/near-raw observations.

The visual language should remain recognizably the same at every level.

---

# 13. Calendar Visual System

Calendar history should use density as an analytical encoding, not as a score.

A day with high usage may appear visually stronger, but the UI must not label it “good” or “bad.”

Use hover/focus/selection states to reveal:

- Total foreground time.
- Visible time.
- Top application.
- Category mix.
- Tracking completeness.

Incomplete/current days should be visually distinguished from completed historical days when comparisons require it.

---

# 14. Charts

## 14.1 Chart philosophy

Charts should answer a question.

Every chart must have:

- A clear purpose.
- A readable scale.
- A meaningful title or contextual label.
- Appropriate units.
- Accessible alternatives where necessary.

## 14.2 Preferred chart vocabulary

Prefer:

- Area/line charts for trends.
- Horizontal bars for rankings.
- Heatmaps for temporal density.
- Stacked bars/areas for composition over time.
- Timeline bands for event/interval history.

Use pie/donut charts sparingly. They are acceptable for simple composition views but should not be the default visualization for every breakdown.

## 14.3 Color discipline

Use a small semantic palette.

A chart should normally emphasize one or two series and mute supporting context.

## 14.4 Interaction

Charts should support:

- Hover/focus inspection.
- Selection where meaningful.
- Cross-filtering/navigation where useful.
- Consistent date/time formatting.

Interaction must not require precise mouse placement when keyboard alternatives are possible.

---

# 15. Application and Browser Entities

## 15.1 Application rows

An application row should typically contain:

- Application icon.
- Canonical name.
- Category/context.
- Primary metric.
- Optional comparison.
- Optional secondary metric.

Avoid showing raw executable/process names in the primary presentation.

## 15.2 Detail hierarchy

Application detail should visually establish:

```text
Application identity
        ↓
Period summary
        ↓
Trend
        ↓
Sessions/timeline
        ↓
Classification
        ↓
Raw/detail metadata when requested
```

## 15.3 Browser/domain detail

Browser analytics should make the hierarchy explicit:

```text
Browser
  └── Domain/service
        └── Page titles (if enabled/available)
```

Private/incognito activity should never reveal domain/title detail.

---

# 16. Classification UI

Classification editing should feel like editing metadata, not changing history.

The interface should communicate:

- Current system classification.
- User override, if present.
- Confidence where meaningful.
- Productivity/leisure interpretation.

When the user changes a classification, the UI should explain that historical analytics may update because the interpretation changed, while the recorded usage remains unchanged.

---

# 17. Privacy UI

Privacy settings are a trust surface and should receive the same design quality as analytics.

Each sensitive setting should answer:

1. **What is collected?**
2. **Why is it collected?**
3. **Where is it stored?**
4. **What happens if I disable it?**

Avoid legalistic copy for the primary setting interface.

Advanced technical explanations may be available through secondary help/details.

---

# 18. Sync UI

Cloud synchronization should be represented as a state, not as a distracting dashboard feature.

Useful states include:

- Local only.
- Sync enabled.
- Syncing.
- Up to date.
- Waiting for network.
- Authentication required.
- Sync needs attention.

Do not expose cryptographic internals in the main UI unless they help the user make a meaningful decision.

The UI should make clear that synchronized data is encrypted before upload under the final E2EE design.

---

# 19. Status and Feedback

## 19.1 Success

Use quiet confirmation for non-critical successful operations.

Examples:

- Classification saved.
- Setting updated.
- Report generated.

## 19.2 Warning

Use warning styling for states that require awareness but do not prevent use.

Examples:

- Browser detail temporarily unavailable.
- Sync waiting for network.

## 19.3 Error

Use stronger visual emphasis only when the user needs to act.

Examples:

- Database cannot be opened.
- Authentication failure requiring action.

## 19.4 Informational states

Prefer inline status where the state is persistent. Use transient notifications for completed actions rather than persistent banners.

---

# 20. Empty States

Empty states should explain the absence of data without making the application feel broken.

Examples:

### New installation

Explain that tracking is ready and that history will appear after normal computer use.

### No browser data

Explain whether browser tracking is disabled or whether supported data has not yet been observed.

### No category data

Explain that classification will appear as activity is recorded.

### No sync history

Explain the difference between local-only history and synchronized history.

Empty states should never fabricate example data that could be mistaken for the user's actual history.

---

# 21. Loading and Performance States

The application should feel immediate.

Prefer:

- Skeletons for large views.
- Incremental rendering.
- Placeholder structure matching the final layout.
- Background aggregation.
- Cached recent results.

Avoid blocking the entire application while one analytical query loads.

The tracker must remain unaffected by UI rendering or analytics queries.

---

# 22. Motion System

## 22.1 Motion principles

Motion should be:

- Short.
- Purposeful.
- Interruptible.
- Consistent.
- Subtle.

## 22.2 Suggested durations

| Token | Duration | Use |
|---|---:|---|
| `motion-instant` | 80 ms | Tiny state changes |
| `motion-fast` | 120 ms | Hover/selection |
| `motion-standard` | 180 ms | Panels/popovers |
| `motion-slow` | 240–320 ms | Page/large layout transitions |

These are starting targets, not rigid implementation requirements.

## 22.3 Easing

Use natural ease-out/ease-in-out curves appropriate to the interaction.

Do not use spring physics everywhere.

## 22.4 Data visualization animation

Do not animate charts from zero on every page load.

Animation should primarily communicate:

- Change of selected period.
- Addition/removal of a series.
- Drill-down/zoom.
- Filter changes.

Users reviewing historical data should not have to wait for decorative chart animation.

## 22.5 Reduced motion

Respect Windows reduced-motion/accessibility preferences where available.

When reduced motion is enabled:

- Remove nonessential transitions.
- Preserve state-change clarity through opacity, focus, or immediate layout changes.

---

# 23. Interaction States

Every interactive component must define:

- Default.
- Hover.
- Pressed.
- Focused.
- Selected.
- Disabled.
- Loading where applicable.
- Error where applicable.

Keyboard focus must remain visible even when mouse interaction dominates the visual design.

---

# 24. Accessibility

## 24.1 Contrast

All text and important interactive states must meet appropriate WCAG contrast expectations for their size and role.

## 24.2 Color independence

Color must never be the only way to communicate:

- Selection.
- Error.
- Warning.
- Category distinction.
- Tracking gaps.

## 24.3 Keyboard navigation

All primary application functions must be reachable by keyboard.

Timeline and chart interactions require a keyboard-accessible inspection path rather than mouse-only tooltips.

## 24.4 Screen readers

Controls, metrics, chart summaries, and navigation landmarks should expose meaningful semantic names through the chosen Windows UI framework.

## 24.5 Text scaling

The UI should remain functional under Windows text/display scaling. Layouts must not assume a single fixed font size.

---

# 25. Data Visualization Accessibility

Visual analytics must have non-visual equivalents where the information is important.

Examples:

- Chart with accessible summary.
- Timeline event with textual duration.
- Heatmap day with exact usage metrics on focus.
- Ranking represented as an accessible list/table as well as bars.

Do not make a decorative chart the only representation of a critical metric.

---

# 26. Microcopy Guidelines

## 26.1 Voice

The product voice should be:

- Clear.
- Calm.
- Direct.
- Factual.
- Non-judgmental.

## 26.2 Avoid

- “You wasted…”
- “Bad habit.”
- “You failed.”
- “Discipline score.”
- “Productivity police” style language.

## 26.3 Prefer

- “You spent…”
- “Unusual compared with your recent history.”
- “Classified as…”
- “Tracking gap.”
- “Not enough history yet.”

The product describes behavior; it does not moralize it.

---

# 27. Dashboard Visual Hierarchy

The Overview screen should generally follow this hierarchy:

```text
┌─────────────────────────────────────────────────────┐
│ Context: Today / Week / Month             Controls │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Primary usage metric                                │
│ Foreground time + comparison                        │
│                                                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Main temporal visualization                         │
│                                                     │
├───────────────────────────────┬─────────────────────┤
│ Top applications              │ Category mix        │
├───────────────────────────────┼─────────────────────┤
│ Browser/domain trend          │ Sessions/switching  │
├───────────────────────────────┴─────────────────────┤
│ Notable patterns / statistical insights             │
└─────────────────────────────────────────────────────┘
```

This is a conceptual composition, not a pixel-level wireframe.

The actual dashboard should adapt to window size and available data.

---

# 28. Design Tokens and Implementation Boundary

The eventual UI implementation should centralize design tokens rather than scattering literal values throughout components.

At minimum, token categories should include:

```text
color/*
spacing/*
radius/*
typography/*
shadow/*
border/*
motion/*
icon/*
chart/*
```

The chosen UI framework should expose these tokens through a coherent theme system.

Changing the theme should not require changing component-specific business logic.

---

# 29. Component Inventory

The initial design system should cover at least:

### Foundation

- App shell.
- Navigation.
- Page header.
- Section header.
- Surface/panel.
- Divider.
- Tooltip.
- Popover.
- Dialog.

### Controls

- Button.
- Icon button.
- Toggle.
- Checkbox.
- Radio/select where required.
- Segmented period selector.
- Date range selector.
- Search/filter field.
- Dropdown/menu.

### Data

- Metric.
- Comparison indicator.
- Application row.
- Domain row.
- Category row.
- Timeline band.
- Calendar cell.
- Table.
- Chart wrapper.
- Legend.
- Empty state.
- Status indicator.

### System

- Toast/notification.
- Error state.
- Loading skeleton.
- Sync status.
- Tracking status.
- Confirmation dialog.

The component inventory is a starting contract. It should grow only when a new reusable semantic need exists.

---

# 30. Performance Constraints for the UI

The visual system must not undermine the product's performance goals.

Requirements:

1. Animations should be GPU-friendly and short.
2. Avoid continuous animations on dashboards.
3. Avoid rendering thousands of timeline elements simultaneously.
4. Use virtualization for large lists where necessary.
5. Use pre-aggregated data for historical charts.
6. Avoid high-frequency bindings to the tracker.
7. Do not make the tracker process responsible for UI rendering.
8. Closing/minimizing the UI must reduce UI workload without affecting tracking.

The UI may be visually sophisticated; the background tracker must remain computationally boring.

---

# 31. Visual QA Checklist

Before a major UI surface is considered complete, verify:

### Layout

- Alignment is consistent.
- Spacing follows the token system.
- No accidental container nesting.
- Window resizing remains coherent.

### Typography

- Hierarchy is obvious.
- Numbers align appropriately.
- Long names truncate gracefully.
- Scaling does not break layouts.

### Color

- Contrast is sufficient.
- Semantic colors are consistent.
- No unnecessary saturation.
- Dark mode remains readable.

### Interaction

- Hover/pressed/focus states exist.
- Keyboard navigation works.
- Tooltips do not obscure critical information.

### Data visualization

- Units are clear.
- Gaps are distinct from zero.
- Foreground/visible distinction is understandable.
- Charts do not imply false precision.

### Motion

- No unnecessary animation.
- Reduced motion is respected.
- Transitions do not delay information access.

---

# 32. Design Decision Summary

The visual system establishes these non-negotiable principles:

1. **Time is the visual backbone.**
2. **Foreground time has stronger visual authority than visible time.**
3. **Tracking gaps are distinct from zero activity.**
4. **Neutral surfaces dominate; color is semantic.**
5. **Typography carries hierarchy.**
6. **Cards are used selectively.**
7. **Charts are analytical tools, not decoration.**
8. **Motion explains state rather than entertaining the user.**
9. **Dark and light modes are independently designed.**
10. **Accessibility is part of the visual system.**
11. **Privacy and sync settings receive first-class design quality.**
12. **The UI can be rich; the tracking runtime must remain lightweight.**

---

# 33. Deferred Visual Decisions

The following should be finalized during implementation/prototyping rather than frozen prematurely:

- Exact color values.
- Exact font family after framework evaluation.
- Exact chart library, if any.
- Exact application icon treatment.
- Final logo/brand identity.
- Exact shadow/elevation values.
- Exact timeline glyphs.
- Exact animation curves.
- Exact responsive breakpoints.

These decisions should be captured in the implementation design system once validated against Windows 10/11, accessibility requirements, and performance.

---

# 34. Definition of Done

The visual design system is ready for implementation when:

- A designer can create new screens without inventing visual primitives.
- An engineer can implement components without choosing arbitrary spacing/colors/radii.
- Light, dark, and system themes have a coherent token model.
- Timeline, charts, metrics, and classifications share a common visual grammar.
- Accessibility behavior is explicit.
- Motion is bounded and purposeful.
- The design can scale to future features without becoming a collection of unrelated screens.

The next authoritative document is **Document 05 — System Architecture & Technical Design**, which will map this product and design model onto concrete processes, components, communication boundaries, technology candidates, and platform integration.
