# Browser Activity Acquisition Specification

**Product:** PC Usage Intelligence  
**Document:** 08 — Browser Activity Acquisition Specification  
**Status:** Authoritative browser-acquisition baseline — Pre-development  
**Parent documents:** `docs/01-product-requirements.md`, `docs/02-scope-feature-specification.md`, `docs/03-information-architecture-ux.md`, `docs/04-visual-design-system.md`, `docs/05-system-architecture.md`, `docs/06-windows-tracking-engine.md`, `docs/07-data-architecture-storage.md`  
**Platform:** Windows 10 and Windows 11  
**Launch browsers:** Chrome, Edge, Firefox, Brave, Arc  
**Last updated:** 2026-09-02

---

# 1. Purpose

This document defines how PC Usage Intelligence acquires browser activity and combines it with Windows application tracking.

Browser activity is intentionally a separate subsystem. The Windows tracker knows that a browser window/process is active; the browser subsystem adds browser-specific identity such as:

- Tab.
- Domain.
- Page title.
- Browser profile where safely available.
- Private/incognito state.
- Navigation/activation state.

The browser subsystem must preserve the product's core properties:

- Local-first.
- Offline-first.
- No behavioral telemetry.
- Low resource usage.
- Explicit privacy controls.
- Fail-closed private browsing behavior.
- Browser-specific failures must not disable ordinary application tracking.

The goal is **durable browser analytics**, not a general-purpose browser history manager.

The primary browser analytics identity is the normalized **domain**. Page title is optional high-resolution local metadata.

---

# 2. Normative Language

- **MUST** — required.
- **MUST NOT** — prohibited.
- **SHOULD** — strong default.
- **MAY** — optional.

---

# 3. Browser Acquisition Principles

## 3.1 Browser acquisition is an adapter system

Do not implement one giant `BrowserTracker` containing browser-specific logic.

Instead:

```text
IBrowserAdapter
    ├── ChromiumAdapter
    │     ├── Chrome
    │     ├── Edge
    │     ├── Brave
    │     └── Arc
    │
    └── FirefoxAdapter
```

The shared interface exposes normalized facts while browser-specific code handles discovery, events, permissions, process/profile differences, and API quirks.

## 3.2 Windows and browser state are separate evidence streams

```text
Windows tracker
    → HWND/process/application/window state

Browser adapter
    → tab/domain/title/private state
```

Neither stream should overwrite the other.

A browser tab observation without a matching Windows foreground interval is still valid browser evidence, but it does not automatically mean the user was actively using that tab.

Likewise, a Chrome foreground interval remains valid even when the browser adapter is unavailable.

## 3.3 Domain is the stable analytical identity

Examples:

```text
https://www.github.com/itsRCk/project
https://github.com/itsRCk/another-project
```

both normalize to:

```text
github.com
```

The normalized domain should be stable across navigation paths and page-title changes.

## 3.4 Page title is subordinate metadata

Page title enables richer timeline inspection, but it is not the durable identity of web activity.

Users can disable page-title collection independently of domain tracking.

---

# 4. Required Launch Support

V1 browser support:

| Browser | Required | Acquisition family |
|---|---:|---|
| Google Chrome | Yes | Chromium/WebExtension |
| Microsoft Edge | Yes | Chromium/WebExtension |
| Mozilla Firefox | Yes | WebExtension |
| Brave | Yes | Chromium/WebExtension |
| Arc | Yes | Chromium-derived adapter strategy, validated during implementation |

The implementation must not assume that all Chromium browsers have identical profile layouts, process models, extension policies, or update channels.

---

# 5. Acquisition Architecture

Recommended architecture:

```text
                 ┌─────────────────────────┐
                 │ Browser Adapter Manager │
                 └────────────┬────────────┘
                              │
            ┌─────────────────┴────────────────┐
            │                                  │
     Chromium Adapter                    Firefox Adapter
            │                                  │
     ┌──────┼──────┐                            │
     │      │      │                            │
  Chrome  Edge  Brave                       Firefox
     │
    Arc adapter capability/profile rules

            ↓ normalized events

       Browser Event Normalizer

            ↓

       Correlation Engine
            ↑
            │
     Windows Tracking Runtime

            ↓
       Browser intervals
            ↓
           SQLite
```

The browser adapter manager is responsible for lifecycle, capability detection, adapter health, and routing.

---

# 6. Preferred Acquisition Mechanism

For the supported launch browsers, the preferred path is a **browser extension/WebExtension-based local acquisition component** communicating with the native desktop runtime through a local bridge.

This is preferred over scraping browser memory, reading internal SQLite history databases while browsers are running, or parsing process command lines because extension APIs provide browser-aware tab/window state and are less dependent on undocumented internals.

Browser extension APIs expose tab metadata such as URL/title subject to the browser's permission model. Firefox's current documentation, for example, states that the `tabs` permission or appropriate host permissions are needed to access `Tab.url` and `Tab.title`; it also documents tab APIs and tab/window events. citeturn252539search0turn252539search3turn252539search1

## 6.1 Native messaging / local bridge

The extension must communicate only with the local PC Usage Intelligence runtime.

Preferred conceptual flow:

```text
Browser extension
      │
      │ local browser extension/native bridge
      ▼
Browser Bridge
      │
      │ authenticated local IPC
      ▼
Tracking Runtime
      │
      ▼
SQLite
```

The extension must not send usage data to a remote analytics endpoint.

## 6.2 Why not browser history databases

Browser history databases are unsuitable as the primary acquisition source because:

- They are retrospective rather than authoritative for real-time active tab state.
- Schemas are implementation details.
- Databases can be locked while browsers run.
- Deletion/retention semantics differ by browser.
- Private browsing activity may not appear there.
- They do not directly provide the exact active/visible state the product needs.

History databases may be considered a recovery/diagnostic source only if a future requirement justifies it.

## 6.3 Why not process command lines alone

Process command lines can identify browser processes but generally cannot provide reliable per-tab domain/title attribution.

They remain useful as a Windows-level fallback for confirming browser presence, not browser-content identity.

---

# 7. Common Browser Adapter Contract

Every browser adapter should expose typed operations equivalent to:

```text
IBrowserAdapter {
    BrowserType BrowserType { get; }

    ValueTask<BrowserCapabilities> GetCapabilitiesAsync();

    ValueTask<AdapterStatus> GetStatusAsync();

    ValueTask StartAsync(CancellationToken ct);
    ValueTask StopAsync(CancellationToken ct);

    ValueTask<IReadOnlyList<BrowserWindowState>> GetCurrentWindowsAsync(ct);
    ValueTask<IReadOnlyList<BrowserTabState>> GetCurrentTabsAsync(ct);

    event EventHandler<BrowserNavigationEvent> NavigationChanged;
    event EventHandler<BrowserTabEvent> TabChanged;
    event EventHandler<BrowserWindowEvent> WindowChanged;
    event EventHandler<BrowserLifecycleEvent> LifecycleChanged;
}
```

The exact C# API may differ, but the boundary must preserve these semantic capabilities.

---

# 8. Normalized Browser Data Model

## 8.1 Browser instance

```text
BrowserInstance {
    browser_instance_id
    browser_type
    process_instance_id?
    profile_key?
    started_at_utc
    ended_at_utc?
}
```

## 8.2 Browser window

```text
BrowserWindow {
    browser_window_id
    browser_instance_id
    window_instance_id?
    browser_window_native_id?
    private_mode
    created_at_utc
    closed_at_utc?
}
```

The Windows `window_instance_id` is the preferred correlation key when available.

## 8.3 Browser tab

```text
BrowserTab {
    browser_tab_instance_id
    browser_window_id
    browser_native_tab_id?
    created_at_utc
    closed_at_utc?
}
```

Browser tab IDs are not assumed to be globally stable over browser restarts. Firefox documentation explicitly notes that tab IDs are unique only within a browser session and can be reused after restart. citeturn252539search3

Therefore the durable ID must be locally generated and scoped to a browser-tab lifetime.

## 8.4 Domain

```text
Domain {
    domain_id
    normalized_domain
    display_name
}
```

Domain normalization must be deterministic.

## 8.5 Page observation

```text
BrowserPageObservation {
    observation_id
    browser_tab_instance_id
    observed_at_utc
    url?
    domain_id?
    page_title?
    private_mode
    navigation_state
    source
}
```

---

# 9. Browser Extension Permission Model

Browser permissions directly affect acquisition quality and user trust.

The extension should request the minimum capability required for V1.

For tab-level URL/title metadata, the implementation must account for the browser's extension permission system. Firefox documentation specifies that the `tabs` permission grants access to privileged tab properties such as URL and title, while matching host permissions can also grant access. citeturn252539search1turn252539search3

## 9.1 Permission principles

1. Do not request unrelated permissions.
2. Do not request page-script access unless needed.
3. Do not inject arbitrary content scripts simply to obtain URL/title data.
4. Explain why browser access is required.
5. Treat denied/removed permissions as a supported degraded state.
6. Never silently substitute a more invasive acquisition technique after permission denial.

## 9.2 No content scraping by default

The extension does not need to read page DOM/content to track domain and title.

Therefore V1 should not request content-script permissions merely for analytics.

This sharply reduces privacy surface area.

## 9.3 Native bridge authorization

The extension may communicate only with the locally installed PC Usage Intelligence native component.

The native bridge must authenticate/validate the extension origin or registration identity where the browser platform permits it.

Unrecognized local bridge clients must be rejected.

---

# 10. Private / Incognito Browsing

Private browsing has the strictest privacy requirement.

## 10.1 Product policy

Default V1 behavior:

```text
Browser application tracking       → enabled
Private browser window detection   → enabled where browser exposes it
Private domain tracking            → disabled
Private page-title tracking        → disabled
Private tab identifiers            → minimize retention
```

## 10.2 Fail-closed rule

If the adapter cannot confidently determine whether a tab/window is private:

```text
Treat it as private for data-capture purposes.
```

That means do not persist its domain or page title until privacy state is confidently established.

## 10.3 No privacy leakage through correlation

Private observations must not be joined with non-private observations in a way that reconstructs private identity.

For example, the system must not infer:

```text
private-tab URL ≈ same domain as a public tab
```

and store a reconstructed private domain.

## 10.4 Firefox-specific privacy behavior

Firefox's WebExtension model exposes an `incognito` property and separately controls whether extensions can access private browsing windows. Current MDN documentation describes `spanning`, `split`, and `not_allowed` modes and notes that private-window access is user-controlled. citeturn252539search2

The Firefox adapter must therefore treat private-window access as a capability that can be unavailable even when the extension itself is installed.

## 10.5 Chromium-family privacy behavior

Chromium-family browsers expose an extension incognito/private capability model, but availability/configuration may vary by browser and user/policy settings.

The adapter must inspect actual runtime capability rather than assuming that an installed extension can observe private windows.

Where private observation is not permitted, the system should record only the browser-level Windows activity that remains observable.

---

# 11. Domain Normalization

Domain normalization must be deterministic and versioned.

Recommended normalization pipeline:

```text
URL
 ↓
parse URI
 ↓
extract hostname
 ↓
lowercase
 ↓
IDN/punycode normalization as appropriate
 ↓
remove trailing dot
 ↓
classify special/local schemes
 ↓
normalized domain
```

Do not derive domain by string splitting on `/`.

## 11.1 Special URL schemes

The adapter must explicitly classify non-HTTP(S) schemes such as:

```text
chrome://
edge://
about:
file://
view-source:
blob:
data:
extension://
```

These should not be blindly normalized into public domains.

The normalized browser identity should preserve an internal scheme/type classification such as:

```text
WebDomain
BrowserInternal
LocalFile
ExtensionPage
Unclassified
```

Exact user-facing labels belong to UX/analytics.

## 11.2 Public suffix behavior

V1 should preserve the registrable hostname rather than attempting to infer an organization unless a reliable public-suffix implementation is available.

Example:

```text
www.example.co.uk
```

may normalize to:

```text
example.co.uk
```

This requires a maintained public-suffix dataset and should not be implemented with a simplistic “last two labels” rule.

---

# 12. Page Title Semantics

Page title is sampled/evented metadata associated with a browser tab.

## 12.1 Collection default

Enabled by default.

## 12.2 Independent setting

The user can disable title collection while retaining domain tracking.

## 12.3 Title change handling

A title change should create a new page observation or a title-state transition, not rewrite earlier observations.

Example:

```text
10:00 github.com — repo A
10:04 github.com — repo B
```

Both title states remain historically visible in high-resolution timeline data when page-title tracking is enabled.

## 12.4 Title storage limits

Window/title strings can become unexpectedly large or contain sensitive content.

The storage layer should:

- Enforce a maximum size.
- Normalize invalid Unicode.
- Avoid logging raw titles.
- Preserve enough text for normal inspection.
- Record truncation metadata when truncation occurs.

The exact maximum should be finalized with storage benchmarks.

---

# 13. Browser Tab State

The adapter should track at least:

```text
created
updated/navigation
activated
moved
attached/detached from window
removed
```

The browser may expose additional events; those are optional unless they materially improve timeline correctness.

## 13.1 Active tab

When the browser identifies an active tab, emit an `ActiveTabChanged` event with:

```text
browser window
previous tab
new tab
observed time
private state
```

## 13.2 Multiple browser windows

Each browser window must remain independently represented.

Two Chrome windows can simultaneously contain different active tabs, but only the browser window that owns the Windows foreground HWND can contribute active browser-domain time in the same way as the foreground application.

Background browser windows remain candidates for visible browser-window presence but do not become the foreground tab merely because their tab is active within that background browser window.

---

# 14. Browser-to-Windows Correlation

Correlation is central to trustworthy browser analytics.

The desired relationship is:

```text
Windows HWND
  ↓
WindowInstance
  ↓
BrowserWindow
  ↓
BrowserTab
  ↓
Domain / PageTitle
```

## 14.1 Primary correlation

Use the browser window's corresponding native window identity when available.

This should be associated with the Windows `window_instance_id`.

## 14.2 Secondary correlation

If native window identity is temporarily unavailable, correlate using a bounded combination of:

- Browser type.
- Browser process instance.
- Browser profile.
- Browser window identity.
- Time proximity.

Any fallback correlation must have an explicit confidence/provenance classification.

## 14.3 Do not correlate by title alone

Window title is not a sufficiently stable identity because:

- Multiple tabs can have similar titles.
- Titles change on navigation.
- Multiple windows can share title text.

A title-only match is not acceptable as the primary correlation mechanism.

---

# 15. Deriving Browser Active Time

Browser-domain active time should be derived from the combination of:

```text
Windows foreground interval
+
Browser active-tab state
+
Browser window correlation
```

Example:

```text
10:00–10:05 Chrome window A foreground
10:00–10:03 github.com active tab
10:03–10:05 docs.google.com active tab
```

Derived result:

```text
github.com       3 min active browser time
docs.google.com  2 min active browser time
```

The system should not count every open tab as active time.

## 15.1 Background browser windows

If Chrome window A is backgrounded while Chrome window B becomes the Windows foreground window:

- A's active tab stops accumulating active-domain time.
- B's active tab becomes eligible.
- Browser visible-window tracking may continue independently where supported by the core Windows tracker.

## 15.2 Browser app interval without domain

If Chrome is foreground but the browser adapter cannot determine the active tab:

```text
Google Chrome foreground time = valid
Browser domain active time   = unavailable
```

Do not invent a domain.

---

# 16. Visible Browser Time

Visible browser time follows the Windows tracker definition from Document 06.

The browser subsystem adds semantic information where possible.

For example:

```text
Chrome window visible
Tab A = github.com
Tab B = docs.example.com
```

The engine may know that the browser window is visible while only one tab is active.

It must not claim that both domains were actively used merely because both tabs existed.

Therefore:

```text
Browser window visible time ≠ domain active time
```

unless active-tab evidence supports the latter.

---

# 17. Browser Sessionization

Browser sessions are derived from active-domain intervals.

A browser-domain session ends when:

- Active domain changes.
- Windows foreground browser window changes away.
- Tab is closed.
- Browser window is closed.
- Browser process ends.
- Private state becomes uncertain.
- Tracker/browser adapter loses authoritative state.
- A tracking gap begins.

A domain may have many sessions during one application foreground period.

---

# 18. Browser Lifecycle Detection

The adapter manager should detect:

```text
Browser installed
Browser running
Extension installed
Extension connected
Extension disconnected
Permission granted
Permission denied
Private access granted/denied
Browser updated/restarted
Adapter crashed
```

The UI can expose a compact browser tracking status such as:

```text
Chrome      Tracking
Edge        Tracking
Firefox     Limited — private windows unavailable
Brave       Tracking
Arc         Setup required
```

This status must distinguish browser absence from acquisition failure.

---

# 19. Browser Discovery

Browser discovery should be based on explicit, testable mechanisms.

Recommended signals:

- Installed application/package metadata.
- Known executable paths where appropriate.
- Process observation.
- Registered extension/bridge state.
- Adapter heartbeat.

The system must not assume that browser install paths are always default.

## 19.1 Running-but-not-installed state

Portable/custom browser deployments may exist.

The Windows tracker can still track the executable as an application even if the browser adapter is unavailable.

---

# 20. Chromium Family Strategy

Chrome, Edge, Brave, and Arc share substantial Chromium/WebExtension concepts, but their identities and runtime behavior are not guaranteed identical.

Use:

```text
ChromiumAdapterCore
       ├── ChromeProfileRules
       ├── EdgeProfileRules
       ├── BraveProfileRules
       └── ArcProfileRules
```

Shared code should cover:

- Extension messaging.
- Tab event normalization.
- URL parsing.
- Domain normalization.
- Title handling.
- Private-mode flag normalization.
- Native-bridge protocol.

Browser-specific code should cover:

- Installation/discovery.
- Extension distribution/loading.
- Profile identification.
- Policy quirks.
- Private-mode capability differences.
- Update/reconnect behavior.
- Native messaging registration.

Do not copy/paste the entire adapter for each browser.

---

# 21. Firefox Strategy

Firefox uses the WebExtensions model but has behavior and permission differences that require a dedicated adapter.

Current Firefox documentation states that its Tabs API exposes tab/window operations and that privileged tab metadata such as URL and title depends on the appropriate permission/host access. citeturn252539search0turn252539search3

The Firefox adapter must support:

- Tab lifecycle events.
- Active-tab changes.
- Window lifecycle.
- URL/title updates.
- Private-window detection where permitted.
- Extension private-access capability detection.
- Reconnect after browser restart/update.

The adapter should not assume Chrome/Chromium event names, permission prompts, or private browsing semantics are identical.

---

# 22. Arc Strategy

Arc must be treated as a separate launch target even though it is Chromium-derived.

The implementation phase must explicitly validate:

1. Which current Arc Windows build exposes the required WebExtension capabilities.
2. Whether the extension model permits reliable active-tab/window events.
3. Whether private-window state is exposed.
4. Whether native bridge communication is supported.
5. Whether browser restart/profile behavior requires special handling.

The adapter must never silently classify Arc as Chrome merely because both use Chromium technology.

If Arc's supported extension capabilities are insufficient for a required signal, the product must present Arc as degraded rather than silently fabricating browser-domain history.

---

# 23. Native Bridge Protocol

The browser extension should send compact normalized messages rather than raw high-volume state dumps.

Example:

```text
BrowserHello
BrowserCapabilities
WindowCreated
WindowRemoved
TabCreated
TabActivated
TabUpdated
TabRemoved
PrivateStateChanged
BrowserHeartbeat
```

Example normalized event:

```text
BrowserTabActivated {
    eventId
    browserType
    browserWindowId
    browserTabId
    observedAtUtc
    privateMode
    url?
    domain?
    title?
}
```

## 23.1 Message versioning

Every bridge message must contain:

```text
protocolVersion
browserAdapterVersion
eventId
sentAtUtc
```

Unknown future fields should be ignored where safe.

Unsupported major protocol versions should cause a controlled adapter degradation rather than undefined behavior.

## 23.2 No network transport

The bridge MUST NOT rely on a remote server for normal operation.

---

# 24. Extension Heartbeat

The browser bridge should send a low-frequency heartbeat while connected.

Suggested starting interval:

```text
30 seconds
```

The heartbeat provides liveness information, not usage data.

The system should not treat a missing heartbeat as proof that the browser was closed. It means only that the adapter's state is no longer authoritative.

---

# 25. Reconciliation Strategy

Browser acquisition should also use event + reconciliation architecture.

## 25.1 Events

Prefer tab/window/navigation events for immediate changes.

## 25.2 Reconciliation

On adapter startup/reconnect and periodically at a low frequency:

1. Query current browser windows.
2. Query current tabs.
3. Compare with adapter state.
4. Create missing entities.
5. Close stale entities.
6. Reconcile active tab state.
7. Reconcile private state.
8. Emit only meaningful differences.

This mirrors the Windows tracker architecture and prevents a missed extension event from permanently corrupting the timeline.

## 25.3 Reconciliation cadence

Start with approximately:

```text
5–10 seconds
```

for connected browser adapters, then benchmark.

Browser reconciliation should normally run less frequently than foreground Windows reconciliation because the browser emits richer tab events.

---

# 26. Failure and Degradation Model

Each browser adapter has independent health.

Examples:

| Condition | Result |
|---|---|
| Browser not installed | Adapter inactive; Windows app tracking unaffected |
| Browser installed, not running | Adapter dormant |
| Browser running, extension absent | Browser app tracked; domain detail unavailable |
| Extension permission denied | Browser app tracked; permitted detail only |
| Private access denied | Public-domain tracking continues; private domain/title absent |
| Native bridge disconnected | Browser detail marked unavailable until reconnect |
| Adapter crash | Other adapters + Windows tracker continue |
| Browser update changes API behavior | Adapter becomes degraded; no fabricated data |
| URL unavailable | Tab may remain identified without domain |
| Title unavailable | Domain may remain tracked without title |
| Browser process identity unavailable | Domain evidence may remain but correlation confidence decreases |

This independent degradation is mandatory.

---

# 27. Gap Semantics for Browser Data

Browser gaps must not necessarily become global tracking gaps.

Example:

```text
Windows tracker: healthy
Chrome adapter: disconnected for 2 minutes
```

Correct representation:

```text
Chrome application foreground time: tracked
Chrome domain time: unavailable for 2 minutes
Global tracking state: healthy with browser-detail degradation
```

The analytics/UI layer can render a browser-detail gap without pretending desktop tracking stopped entirely.

---

# 28. Correlation Confidence

Browser-to-Windows joins can have varying strength.

Recommended internal provenance values:

```text
ExactNativeWindow
ExactBrowserWindow
ProcessScoped
TimeScoped
Uncorrelated
```

Only strong correlations should automatically produce active-domain attribution.

A weak correlation may remain visible in diagnostic data but should not silently become a high-confidence analytics result.

---

# 29. Data Minimization

The browser adapter should collect only what the product uses.

V1 requirements:

```text
Required:
- Browser type
- Tab/window lifecycle
- Active tab state
- Domain
- Private state

Optional:
- Page title
- Browser profile label

Not required:
- Page DOM
- Form fields
- Cookies
- Passwords
- Downloads content
- Clipboard
- Full browsing history
- Network request bodies
```

The absence of those broader permissions is an explicit privacy feature.

---

# 30. URL Handling and Privacy

URL is more sensitive than domain.

The product should conceptually separate:

```text
Domain analytics identity

from

Full URL high-resolution metadata
```

The launch product's durable browser analytics should use domain.

Full URLs should only be retained where a later privacy/security decision explicitly justifies them.

If raw URLs are temporarily needed inside an adapter for parsing, they should remain in process memory and not be logged unnecessarily.

---

# 31. Page-Title Retention and Deletion

When page-title tracking is disabled:

- New titles must not be persisted.
- Cached in-memory titles should be cleared promptly.
- Historical titles may remain only according to the user's explicit deletion/retention choice.

The exact behavior of deleting already-stored titles is a data-governance decision, but the setting must have a documented, predictable meaning.

---

# 32. Browser Extension Update Strategy

The extension and desktop runtime are separate deployable components.

Compatibility must therefore be explicit.

The bridge handshake should negotiate:

```text
extension protocol version
runtime protocol version
browser capability set
```

A runtime must reject incompatible protocol versions safely.

Backward-compatible minor changes should be supported for a defined compatibility window.

---

# 33. Browser Adapter Startup Order

When the tracking runtime starts:

```text
1. Windows tracking becomes authoritative.
2. Browser adapter manager starts.
3. Detect installed/running browsers.
4. Establish extension bridge connections.
5. Enumerate current browser state.
6. Correlate browser windows with known Windows window instances.
7. Begin browser event processing.
```

Windows tracking must not wait for browser initialization.

If browser startup takes 10 seconds, those 10 seconds are simply:

```text
Chrome application time = potentially tracked
Chrome domain detail = unavailable until browser authority established
```

---

# 34. Browser Restart and Reconnect

A browser restart ends prior browser instance/tab lifetimes.

On restart:

1. Close known browser instance entities.
2. Start a new browser instance.
3. Do not reuse old native tab IDs as durable identities.
4. Enumerate current windows/tabs.
5. Create new tab/window lifetimes.
6. Correlate to Windows window instances.
7. Resume domain tracking.

If browser restart occurs while the extension bridge is disconnected, the period is a browser-detail gap, not necessarily a desktop tracking gap.

---

# 35. Browser Crash Recovery

Browser crashes can produce missing closure events.

At reconnect/startup, the adapter should detect stale windows/tabs through full reconciliation and close their previous lifetimes at the last authoritative boundary.

The system must not extend a stale tab's domain interval through an unknown browser crash gap.

---

# 36. Security Requirements

## 36.1 Local bridge trust

Only the installed PC Usage Intelligence native component should accept browser messages.

## 36.2 Message validation

Validate:

- Protocol version.
- Browser identity.
- Event IDs.
- Timestamp ranges.
- String length limits.
- Enum values.
- Tab/window reference validity.

## 36.3 No arbitrary code execution

The native bridge protocol is data-only.

Browser messages must never contain commands that cause arbitrary native code execution.

## 36.4 No secrets

The browser adapter must not collect or persist:

- Passwords.
- Cookies.
- Authentication tokens.
- Form contents.
- Payment data.

---

# 37. Resource Budget

Browser tracking must remain compatible with the global performance targets.

Starting targets for the desktop/native side:

| Metric | Target |
|---|---:|
| Native bridge idle CPU | effectively negligible |
| Browser-adapter CPU | < 0.5% typical aggregate |
| Native memory overhead | < 50 MB typical aggregate |
| Network usage | 0 bytes for acquisition |
| Polling | event-driven primary, low-frequency reconciliation |
| URL/title processing | event-triggered, not continuous scraping |

The browser extension itself is expected to be lightweight and should avoid content scripts and DOM polling.

These are engineering targets to validate, not guarantees.

---

# 38. Browser Extension Performance Rules

The extension must not do this:

```text
setInterval(() => inspect active page DOM, 100ms)
```

It should instead consume browser events:

```text
onActivated
onUpdated
onCreated
onRemoved
onWindowFocusChanged
```

and emit compact state transitions.

Do not repeatedly query every tab if an event provides the exact changed object.

Reconcile the whole browser state only periodically or after recovery.

---

# 39. Testing Strategy

## 39.1 Adapter unit tests

Test:

- URL/domain normalization.
- Special schemes.
- Private-state rules.
- Title truncation/normalization.
- Tab lifetime identity.
- Duplicate event suppression.
- Event ordering.
- Reconnect logic.
- Protocol compatibility.

## 39.2 Contract tests

Every adapter must pass the same normalized contract test suite.

Example:

```text
Create tab
→ navigate
→ activate
→ change title
→ switch tab
→ close tab
```

The normalized event sequence must be semantically equivalent across browsers.

## 39.3 Browser integration tests

For each browser:

- Install/enable extension.
- Open two windows.
- Open multiple tabs.
- Switch tabs.
- Navigate between domains.
- Change titles.
- Enter/leave private mode where supported.
- Minimize/restore browser window.
- Sleep/wake computer.
- Lock/unlock session.
- Restart browser.
- Remove/reinstall extension.
- Change extension permissions.

## 39.4 Correlation tests

Verify:

```text
Windows foreground Chrome
+ active tab github.com
→ github.com active time
```

and:

```text
Windows foreground switches to VS Code
+ Chrome active tab unchanged
→ github.com active interval closes
```

## 39.5 Privacy tests

The test suite must assert that private observations never persist domain/title data.

This should be a hard automated assertion, not a manual review.

---

# 40. Representative Replay Fixture

Example normalized stream:

```text
10:00 Chrome window A foreground
10:00 Chrome tab A active → github.com
10:03 Chrome tab A active → docs.example.com
10:05 Windows foreground → VS Code
10:07 Windows foreground → Chrome window B
10:07 Chrome window B active → youtube.com
10:10 Chrome window B enters private mode
10:10 private domain unavailable
10:15 Chrome window B closes
```

Expected derived active-domain intervals:

```text
github.com         10:00–10:03
docs.example.com   10:03–10:05
youtube.com         10:07–10:10
private domain     no persisted identity
```

The Chrome application foreground intervals remain independently valid.

---

# 41. Acceptance Criteria

### Functional

- Chrome, Edge, Firefox, Brave, and Arc can be detected as separate browser applications.
- Active-tab changes produce domain-state transitions.
- Domain identity survives ordinary navigation within the same domain.
- Page titles are available when enabled and permitted.
- Private domain/title collection is disabled.
- Browser windows correlate with Windows window instances.
- Browser application tracking continues when domain acquisition fails.

### Correctness

- Rapid tab switches are not lost when event-observed.
- A background browser window cannot generate active-domain time merely because one of its tabs is active internally.
- Browser restarts create new tab/window lifetimes.
- Tab/native IDs are not treated as permanent global identities.
- Adapter gaps do not become global desktop tracking gaps unless Windows tracking itself is unavailable.

### Privacy

- No browser-network analytics endpoint exists.
- No passwords/cookies/auth tokens are collected.
- Private browsing fails closed.
- User can disable page-title collection independently.
- Browser permissions are minimal and documented.

### Performance

- No content DOM polling is required for ordinary domain/title acquisition.
- Event callbacks are lightweight.
- Reconciliation is low-frequency.
- Native acquisition contributes negligibly to system CPU/RAM.

### Reliability

- Browser adapter failure does not crash the tracker.
- Extension reconnect recovers current browser state.
- Browser crash/restart does not fabricate continuous domain time.

---

# 42. Hard Invariants

1. **Browser tracking is independent of Windows application tracking.**
2. **Windows application foreground time remains valid when browser detail is unavailable.**
3. **Domain is the durable browser analytics identity.**
4. **Page title is optional high-resolution metadata.**
5. **Private browsing domain/title capture is fail-closed.**
6. **A browser tab ID is never treated as a permanent cross-restart identity.**
7. **Window title alone is never the primary browser-window correlation key.**
8. **Background browser tabs do not become active-domain time without foreground/window evidence.**
9. **Browser adapter failure never disables desktop tracking.**
10. **No remote network is required for acquisition.**
11. **No DOM/content scraping is required for normal V1 domain/title capture.**
12. **Passwords, cookies, tokens, form contents, and network bodies are out of scope.**
13. **Browser gaps are explicit and separate from global tracking gaps.**
14. **URL handling is more sensitive than domain handling and must not be logged casually.**
15. **Extension/native protocol versions are explicit.**
16. **Browser-specific behavior is isolated behind adapter boundaries.**
17. **Reconciliation can repair missed browser events.**
18. **The browser adapter never fabricates a domain when authoritative tab identity is unavailable.**
19. **Arc is validated as its own browser target rather than silently treated as Chrome.**
20. **Private and public state must never be joined in a way that reconstructs private browsing identity.**

---

# 43. Deferred Decisions / ADRs

The following must be finalized during implementation/testing:

- **ADR-006:** Browser acquisition architecture.
- Exact extension/native messaging implementation per browser.
- Exact permission sets for Chrome, Edge, Firefox, Brave, and Arc.
- Whether one extension package can support all Chromium launch browsers or separate packages are preferable.
- Exact private/incognito support matrix.
- Exact stable browser profile identity strategy.
- Full-URL retention policy.
- Exact public-suffix library/dataset.
- Arc-specific capability behavior.
- Browser reconciliation interval.
- Browser extension heartbeat interval.
- Exact bridge authentication mechanism.

---

# 44. Implementation Order

### Phase 1 — Normalized contract

Implement:

```text
BrowserTabState
BrowserWindowState
BrowserPageObservation
BrowserCapabilities
BrowserAdapterStatus
```

with no browser-specific code.

### Phase 2 — Browser event simulation

Build deterministic replay tests using synthetic browser events.

### Phase 3 — Native bridge

Implement the local data-only bridge and protocol versioning.

### Phase 4 — Chromium core

Implement common extension event handling and URL normalization.

### Phase 5 — Chrome

Validate the first production browser adapter end-to-end.

### Phase 6 — Edge + Brave

Reuse Chromium core with browser-specific discovery/profile/private capability logic.

### Phase 7 — Firefox

Implement the WebExtension-specific adapter and private-window capability handling.

### Phase 8 — Arc

Validate current Windows extension capabilities and implement the dedicated adapter path.

### Phase 9 — Windows correlation

Join browser windows/tabs with the Windows tracking engine and derive active-domain intervals.

### Phase 10 — Privacy hardening

Automated private-mode tests, deletion behavior, permissions, data minimization, and diagnostic scrubbing.

### Phase 11 — Performance soak

Measure extension/native CPU, memory, wakeups, IPC volume, SQLite writes, browser restarts, and long-running history growth.

---

# 45. Reference Documentation

Primary references consulted for the browser extension model:

- Mozilla MDN — WebExtensions Tabs API and permissions. citeturn252539search0turn252539search1turn252539search3
- Mozilla MDN — extension private/incognito access modes. citeturn252539search2turn252539search4
- Microsoft Edge Extensions documentation — extension platform and manifest model. citeturn252539search5turn252539search7

Browser-specific implementation details must be revalidated against the current browser documentation at implementation time because extension APIs, permissions, policies, and browser versions can change independently.

---

# 46. Definition of Done for Document 08

Document 08 is implemented when the repository contains a browser subsystem that can:

- Track Chrome, Edge, Firefox, Brave, and Arc as distinct browser applications.
- Receive browser-aware tab/window events through isolated adapters.
- Normalize domains deterministically.
- Capture page titles by default when permitted and enabled.
- Detect and fail closed for private browsing.
- Correlate browser windows with Windows window instances.
- Derive active-domain time only from authoritative browser + Windows state.
- Preserve browser-detail gaps separately from desktop tracking gaps.
- Recover after extension/browser/runtime restarts.
- Handle tab/window ID reuse safely.
- Enforce minimal permissions and strict data minimization.
- Operate with no network requirement for acquisition.
- Remain within the background performance budget.
- Pass deterministic adapter contract tests, privacy tests, Windows-correlation tests, and long-running browser integration tests.

The next document, **Document 09 — Privacy & Data Governance Specification**, should define the product's data classification, collection boundaries, user controls, retention/deletion semantics, local telemetry policy, diagnostic handling, consent UX, and lifecycle rules for sensitive usage history.