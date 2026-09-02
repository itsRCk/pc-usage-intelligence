# Windows Tracking Engine Specification

**Product:** PC Usage Intelligence  
**Document:** 06 — Windows Tracking Engine Specification  
**Status:** Authoritative tracking-engine baseline — Pre-development  
**Parent documents:** `docs/01-product-requirements.md`, `docs/02-scope-feature-specification.md`, `docs/03-information-architecture-ux.md`, `docs/04-visual-design-system.md`, `docs/05-system-architecture.md`  
**Platform:** Windows 10 and Windows 11  
**Last updated:** 2026-09-02

---

## 1. Purpose

This document defines how PC Usage Intelligence observes Windows desktop activity and converts operating-system state into trustworthy usage intervals.

It is the implementation contract for the **Tracking Runtime** described in Document 05. It deliberately goes deeper than the product requirements and system architecture documents: an engineer or AI coding agent should be able to implement the first tracking engine from this document without inventing product semantics.

The tracking engine is responsible for:

- Identifying the interactive Windows user session being tracked.
- Detecting the foreground window and foreground application.
- Tracking OS-visible top-level application windows.
- Recording process and window identity.
- Associating windows with displays/monitors.
- Detecting application switches.
- Deriving active/idle state.
- Detecting workstation/session lifecycle transitions.
- Detecting sleep/resume and shutdown conditions where observable.
- Converting observations into foreground and visible-time intervals.
- Preserving explicit tracking gaps instead of fabricating usage.
- Buffering and durably persisting observations with bounded I/O.
- Recovering safely after tracker crashes/restarts.

The tracking engine does **not** own:

- Browser-domain/page-level acquisition semantics.
- Cloud synchronization.
- Encryption/key management.
- User-facing analytics rendering.
- Behavioral intervention.
- Productivity coaching.
- Focus scoring.
- Network telemetry.

Browser acquisition integrates with this engine through the normalized browser boundary specified in Document 05 and detailed further in Document 08.

---

# 2. Normative Language

The following terms are normative:

- **MUST** — required for correctness or architecture.
- **MUST NOT** — prohibited.
- **SHOULD** — strong default; deviation requires an explicit engineering reason.
- **MAY** — optional implementation detail.

When this document conflicts with an implementation convenience, the document's tracking semantics win. When this document conflicts with a later ADR or explicit product decision, the later authoritative decision wins and this document must be updated.

---

# 3. Core Tracking Model

PC Usage Intelligence records a sequence of observations and derives time intervals from state transitions.

The authoritative model is:

```text
Windows / user-session signals
        │
        ├── event notifications
        └── reconciliation polls
                │
                ▼
        Observation Normalizer
                │
                ▼
        State Resolver
                │
        ┌───────┴────────┐
        ▼                ▼
 Foreground State   Visible Window State
        │                │
        └───────┬────────┘
                ▼
        Interval Engine
                │
                ▼
        Buffered Events
                │
                ▼
             SQLite
```

The fundamental principle is **state, not sampling**.

A five-second timer does not mean an application received five seconds of usage. Timers are used to verify state and recover from missed events; elapsed time is assigned from the actual start/end boundaries of resolved states.

This means:

```text
Foreground interval = [resolved foreground start, resolved foreground end)

Visible interval   = [resolved visible start, resolved visible end)
```

Intervals are half-open: the start instant is included; the end instant is excluded. This makes adjacent intervals composable without double-counting.

---

# 4. Authoritative Definitions

## 4.1 Foreground application

The **foreground application** is the canonical application identity associated with the current foreground window returned by Windows for the tracked interactive user session.

The raw foreground object is an `HWND`. The canonical application is resolved from that window's process and application identity.

Foreground time is the product's primary **active-use** metric.

Foreground time MUST NOT be inferred from:

- Mouse movement alone.
- Keyboard activity alone.
- Process lifetime.
- Window creation alone.
- Whether an executable remains running.
- Whether a window exists but is backgrounded.

The foreground window source should be `GetForegroundWindow`. Microsoft documents it as returning the handle to the window currently in the foreground. citeturn173932search0

## 4.2 Visible application

For V1, **visible** means:

1. The top-level window exists.
2. Windows considers the window visible.
3. The window is not minimized.
4. The window is not cloaked when cloaking can be detected.
5. The window belongs to the tracked interactive session.

Visible does **not** mean "a human can currently see any pixels from this window."

A window fully covered by another application can still satisfy the OS-level visible definition. Exact occlusion/visible-pixel accounting is explicitly out of scope for V1 because it would substantially increase observation complexity and overhead while producing ambiguous product semantics.

Visible time therefore measures **window presence in the desktop**, not perceptual attention.

Visible time is secondary to foreground time.

## 4.3 Application instance

An **application instance** is a process/window instance observed at the Windows level.

Examples:

- Two separate Visual Studio windows may have separate HWNDs but may map to one canonical application.
- Two browser windows map to the same browser application but remain separately identifiable by HWND/process metadata.
- Multiple processes belonging to one application family may map to one canonical application while retaining raw process identity.

Application instances MUST NOT be silently collapsed at collection time.

## 4.4 Canonical application

A **canonical application** is the stable user-facing identity to which one or more observed processes/windows resolve.

Examples:

```text
chrome.exe process A ─┐
chrome.exe process B ─┼──► Google Chrome
chrome.exe process C ─┘
```

The canonical identity layer is user-correctable and must be separate from raw observation data.

## 4.5 Tracking gap

A **tracking gap** is an interval for which the tracker cannot prove the user's desktop state.

Gaps are first-class data.

The engine MUST NOT backfill a gap with inferred application usage simply because the process later restarted or the same application is foreground after restart.

Examples:

- Tracker process crashed at 14:32:07 and restarted at 14:33:01.
- Database was unavailable and the in-memory buffer overflowed.
- OS/user-session state became unavailable.
- System was asleep or locked and the transition boundary could not be reconstructed precisely.

The UI can later distinguish:

```text
No tracked activity
       vs
Tracking unavailable
```

That distinction is required by the product's trust model.

---

# 5. Tracking Runtime Architecture

## 5.1 Dedicated process

The tracking engine runs in the separate user-session Tracking Runtime process defined in Document 05.

It MUST NOT depend on the WinUI dashboard process for continuous collection.

The runtime MUST continue tracking when:

- The dashboard is closed.
- The dashboard is not yet launched.
- The dashboard is rendering a heavy report.
- The UI crashes.
- Network connectivity is absent.
- Google authentication has expired.

## 5.2 Internal components

Recommended internal boundaries:

```text
Tracking.Runtime
│
├── LifecycleHost
├── ObservationCoordinator
│   ├── ForegroundObserver
│   ├── WindowInventoryObserver
│   ├── InputIdleObserver
│   ├── SessionObserver
│   ├── PowerObserver
│   └── DisplayTopologyObserver
│
├── WindowsAdapters
│   ├── WindowApi
│   ├── ProcessApi
│   ├── SessionApi
│   ├── PowerApi
│   └── DisplayApi
│
├── IdentityResolver
├── StateStore
├── IntervalEngine
├── EventBuffer
├── HealthTracker
└── PersistenceWriter
```

Each Windows API surface should be wrapped behind a narrow interface so Windows interop is replaceable in tests and replay fixtures can run without a live desktop.

## 5.3 One authoritative state machine

There must be one authoritative state model for the tracker. UI, analytics, or individual observer implementations MUST NOT invent independent elapsed-time calculations.

The state machine consumes normalized observations and emits state transitions.

---

# 6. Hybrid Event + Reconciliation Strategy

The tracker will use a **hybrid event-driven architecture**.

## 6.1 Event-driven signals

Events are preferred for immediate state transitions.

The initial event sources are:

| Signal | Preferred mechanism | Purpose |
|---|---|---|
| Foreground window change | `SetWinEventHook(EVENT_SYSTEM_FOREGROUND, ...)` | Detect active-window changes promptly |
| Window creation/destruction | WinEvent hooks where useful | Maintain window inventory efficiently |
| Window show/hide | WinEvent hooks where useful | Update visible-window state |
| Minimize/maximize/show state | WinEvent hooks + reconciliation | Visible-state transitions |
| Session lock/unlock/logon/logoff | `WTSRegisterSessionNotification` + `WM_WTSSESSION_CHANGE` | Stop/start user-session observation |
| Suspend/resume | `RegisterSuspendResumeNotification` | Detect sleep/wake boundaries |
| Display topology changes | `WM_DISPLAYCHANGE`, `WM_SETTINGCHANGE`, reconciliation | Update display association |

`SetWinEventHook` supports out-of-context event delivery without injecting the callback into target processes. The registering thread requires a Windows message loop to receive events. citeturn750935search3

For this tracker, the preferred implementation is an **out-of-context hook on a dedicated observer thread with its own message loop**, not on the WinUI UI thread.

## 6.2 Reconciliation loop

Events are not considered the sole source of truth.

A reconciliation loop periodically samples authoritative Windows state to catch:

- Missed callbacks.
- Hook registration failure.
- Window state changes not covered by selected events.
- Process lifetime changes.
- Display topology changes.
- Unexpected state divergence.
- Tracker restart recovery.

The default reconciliation interval should be **2 seconds**, subject to performance benchmarking. It is a correctness safety net rather than a primary timing mechanism.

The interval MUST be configurable internally for test and benchmark builds, but SHOULD NOT be exposed as a normal product setting in V1.

## 6.3 Event debounce and coalescing

Windows can emit bursts of related events for one user-visible transition.

The observer layer MUST normalize and coalesce duplicate events before they reach the interval engine.

Example:

```text
EVENT_SYSTEM_FOREGROUND(hwnd=100)
EVENT_SYSTEM_FOREGROUND(hwnd=100)
reconciliation(hwnd=100)
reconciliation(hwnd=100)
```

These four observations may resolve to one state:

```text
ForegroundWindow = 100
```

No additional foreground interval should be created.

## 6.4 Event ordering

Observed timestamps MUST be assigned as close as possible to acquisition time.

The observer must not assume that OS callbacks arrive at the exact instant the underlying state changed.

Every normalized observation therefore carries:

- Acquisition timestamp.
- Monotonic acquisition timestamp.
- Source type.
- Source sequence number where applicable.
- Raw object identity.

The interval engine is responsible for resolving state transitions deterministically from the observation stream.

---

# 7. Foreground Window Acquisition

## 7.1 Primary API

Use:

```text
GetForegroundWindow()
```

The returned `HWND` becomes the raw foreground-window candidate.

## 7.2 Event hook

Register an out-of-context `SetWinEventHook` listener for:

```text
EVENT_SYSTEM_FOREGROUND → EVENT_SYSTEM_FOREGROUND
```

with:

```text
WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS
```

The hook's purpose is low-latency transition detection.

The tracker must maintain a strong reference to the managed callback delegate for the hook lifetime. The hook MUST be explicitly removed during shutdown using `UnhookWinEvent`.

## 7.3 Reconciliation

On each reconciliation tick:

1. Call `GetForegroundWindow`.
2. Compare the result with current foreground HWND.
3. If different, process the result exactly as an event-driven transition.
4. If equal, verify that the current identity remains resolvable.
5. If identity resolution has changed, close/open the appropriate derived interval without inventing a window change.

## 7.4 Null foreground window

`GetForegroundWindow` can return no window.

A null result MUST NOT automatically become an application named `Unknown`.

Instead the tracker enters a platform-unresolved foreground state:

```text
ForegroundUnavailable
```

The interval engine records either:

- a known non-application system state, if confidently identified, or
- a tracking gap/unresolved state.

The exact UI label is an analytics concern and is not defined here.

---

# 8. Window Metadata Acquisition

For every new or materially changed window identity, the tracker should collect the following normalized fields.

| Field | Required | Notes |
|---|---:|---|
| HWND | Yes | Raw window identity during its lifetime |
| PID | Yes when available | Owning process |
| Process start time | Strongly recommended | Prevents PID-reuse ambiguity |
| Executable path | Strongly recommended | Raw executable identity |
| Executable name | Yes when path unavailable | Fallback identity |
| Package/app identity | Optional | Microsoft Store/package metadata where available |
| Window title | Yes for ordinary windows when available | User-configurable data surface; stored locally |
| Window style/state | Yes where observable | Used for visibility semantics |
| IsVisible | Yes | OS visibility state |
| IsMinimized | Yes | Minimized windows are not visible-time candidates |
| IsCloaked | Recommended | Prevents counting certain shell/virtualized windows as visible |
| Monitor ID | Yes when display mapping succeeds | Stable display identity is separately defined |
| Windows session ID | Yes | Isolates interactive sessions |
| Observation source | Yes | Event/poll/recovery/etc. |

Microsoft's `GetWindowText` retrieves the title-bar text for a window when it has one, with documented limitations for controls belonging to another process. For this product, it is therefore a metadata signal rather than a universal UI-text extraction mechanism. citeturn173932search5

The engine does not scrape arbitrary UI content. UI Automation/browser-specific acquisition remains a separate subsystem.

---

# 9. Process Identity and PID Reuse

A Windows PID is not globally unique over time.

The tracker MUST NOT identify an application instance using PID alone.

The minimum instance key should be conceptually:

```text
ProcessInstanceKey = (WindowsSessionId, ProcessId, ProcessStartTime)
```

The window key is:

```text
WindowInstanceKey = (HWND lifetime, ProcessInstanceKey)
```

Because an HWND can be reused after destruction, the implementation must treat an HWND as valid only during the lifetime in which it has been observed to exist.

When a process exits:

- The process instance becomes closed.
- Its windows are no longer considered active.
- Any open intervals must be closed at the last defensible observation boundary.

If Windows no longer permits metadata retrieval for a window/process, the engine closes the raw identity rather than silently attaching later observations to it.

---

# 10. Canonical Application Identity Resolution

The identity pipeline is:

```text
HWND
  │
  ▼
PID + process start time
  │
  ▼
Executable path / package identity
  │
  ▼
Application metadata
  │
  ▼
Canonical application
  │
  ▼
User override
```

## 10.1 Identity resolution must be deterministic

Given the same raw observation and the same identity configuration version, the resolver should return the same canonical application.

## 10.2 Raw and canonical identities are separate

Example:

```text
Observed executable: C:\Program Files\Google\Chrome\Application\chrome.exe
Observed process: PID 1234, start 2026-09-02T10:11:12Z
Canonical app: Google Chrome
```

The raw observed identity must remain available even if the user later changes the application name/category.

## 10.3 Identity changes

When user overrides change:

- Historical raw observations remain immutable.
- User-facing resolution may change retroactively according to product data-governance rules.
- The system records the configuration/effective identity version so analytics can reproduce or explain the result.

This prevents user corrections from corrupting the acquisition layer.

---

# 11. Visible Window Inventory

Visible-time tracking requires a maintained inventory of candidate top-level windows.

Microsoft provides `EnumWindows` for enumerating top-level windows. citeturn173932search6

## 11.1 Inventory policy

The tracker SHOULD maintain an incrementally updated inventory using window lifecycle events where practical and use `EnumWindows` during:

- Startup.
- Tracker recovery.
- Reconciliation after detected divergence.
- Display/session topology changes.
- Periodic full reconciliation at a low frequency.

The tracker SHOULD NOT call a full `EnumWindows` scan on every 2-second tick unless benchmarking proves it harmless.

## 11.2 Candidate filtering

A candidate window must satisfy all applicable conditions:

```text
Top-level window
AND belongs to tracked user session
AND IsWindow(hwnd)
AND IsWindowVisible(hwnd)
AND NOT minimized
AND NOT cloaked
AND resolvable to a process identity
```

Additional shell/system-window exclusions MAY be applied only through explicit, testable rules. The engine must not maintain a large undocumented blacklist of executables.

## 11.3 Occlusion

Do not calculate exact visible pixel area in V1.

The interval model intentionally defines visible time as OS-level window presence.

This is both a correctness and performance boundary.

---

# 12. Multi-Monitor Semantics

Multiple monitors are first-class and must not be treated as a single-screen edge case.

## 12.1 Window-to-monitor mapping

For each tracked visible/foreground window, resolve the display monitor associated with its current window rectangle.

The initial API should be:

```text
MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST)
```

`MonitorFromWindow` returns the monitor with the largest intersection with the window's bounding rectangle, with explicit fallback behavior when no monitor intersects. citeturn750935search12

## 12.2 Monitor identity

The raw `HMONITOR` is an OS handle, not a sufficient long-lived database identity.

Normalize it into a display record containing enough information to identify a physical/logical display across topology observations, such as:

- Device/display name when available.
- Monitor EDID-derived identity when safely available and justified.
- Resolution.
- Position.
- Primary flag.
- DPI/scaling characteristics where relevant.

The precise stable display identity algorithm is a later implementation detail and must be covered by tests against topology changes.

## 12.3 Window movement across monitors

If a visible or foreground window crosses to another monitor and the resolved monitor changes, the engine MUST close the prior monitor-attributed interval and start a new interval at the transition boundary.

This allows future analytics such as:

```text
Application X on Monitor A: 42 min
Application X on Monitor B: 17 min
```

without changing the application-level totals.

## 12.4 Display topology changes

When monitors are connected, disconnected, reordered, or resolution changes materially:

1. Receive the relevant Windows display/settings signal where available.
2. Mark display topology as dirty.
3. Reconcile display mappings.
4. Re-evaluate all open visible-window associations.
5. Do not generate artificial application switches unless the foreground HWND actually changed.

---

# 13. Foreground Time Semantics

Foreground time is attributed to exactly one raw foreground window at a time, provided the foreground state is observable.

Conceptually:

```text
10:00:00 Chrome foreground begins
10:12:14 VS Code foreground begins
10:12:14 Chrome foreground ends
10:35:02 VS Code foreground ends
```

Foreground intervals MUST NOT overlap.

## 13.1 Foreground attribution hierarchy

The interval engine retains both:

```text
Raw foreground window
Raw process instance
Canonical application
```

Analytics may aggregate by any of these dimensions later.

## 13.2 Application switches

An application-switch event occurs when the canonical foreground application changes.

A raw-window change inside the same canonical application is still recorded as a window transition but is not counted as a canonical application switch.

Example:

```text
Chrome window A → Chrome window B
```

Results:

```text
Foreground window transition: yes
Application switch: no
```

Whereas:

```text
Chrome window → VS Code window
```

results in both.

This allows analytics to distinguish:

- Window switching.
- Application switching.

## 13.3 Micro-switches

Switches shorter than the sampling/reconciliation period MUST still be preserved when observed by the event hook.

The engine must not introduce an arbitrary minimum duration merely to simplify charts.

Any analytics aggregation that hides micro-events belongs in the analytics layer, not acquisition.

---

# 14. Idle Detection

Idle is a **derived input signal**, not a replacement for foreground tracking.

The primary Windows signal is `GetLastInputInfo`, which provides the time of the last user input event at the desktop level.

## 14.1 Default idle threshold

V1 default:

```text
Idle threshold = 60 seconds
```

This threshold should be internal configuration and eventually user-configurable through advanced settings if product requirements justify it.

## 14.2 Idle semantics

At time `T`:

```text
Idle = (T - LastInputTime) >= IdleThreshold
```

However, the tracker MUST continue collecting foreground and visible state while idle.

Example:

```text
14:00–14:10 VS Code foreground
14:04–14:07 no input
```

Foreground time remains 10 minutes, while an idle-derived subinterval covers 3 minutes.

The product can use that distinction in analytics without pretending that no keyboard/mouse input means no application use.

## 14.3 Idle transition boundaries

When idle begins:

- Do not close the foreground interval.
- Emit an idle-state transition.

When input resumes:

- Close the idle subinterval.
- Continue the same foreground interval if the foreground window is unchanged.

## 14.4 Why idle is separate from “focus”

The system does not calculate a Focus Score from idle state.

Idle is simply additional provenance about the desktop state.

---

# 15. Session, Lock, Unlock, Logon, Logoff

Windows session state must be treated as a hard boundary for ordinary foreground/visible observation.

`WTSRegisterSessionNotification` allows a window to receive `WM_WTSSESSION_CHANGE` notifications for session changes, including events such as logon, logoff, connect, disconnect, and related transitions. citeturn750935search0turn750935search7

## 15.1 Session observer implementation

The tracker should create a small message-only/native helper window on the observer thread and register it for session notifications for the current session.

This helper is an infrastructure object, not a product UI.

## 15.2 Lock

When receiving `WTS_SESSION_LOCK`:

1. Record the lock event immediately.
2. Close open foreground/visible intervals at the best defensible boundary.
3. Enter `Locked` availability state.
4. Do not attribute lock-screen time to the previous application.
5. Continue minimal lifecycle monitoring needed to detect unlock/recovery.

Microsoft explicitly recommends session notifications for determining workstation lock/logon transitions because there is no direct general API that simply returns a “locked” flag. citeturn750935search4

## 15.3 Unlock

On `WTS_SESSION_UNLOCK`:

1. Mark observation available again.
2. Reconcile foreground/window/process state immediately.
3. Start a new foreground interval from the resolved post-unlock state.
4. Do not bridge the locked period.

## 15.4 Session logoff / disconnect

On logoff or session disconnect:

- Close open intervals.
- Mark session unavailable.
- Stop normal desktop polling/observation for that session.
- Preserve the session boundary in event history.

The tracker must not accidentally continue counting a disconnected session simply because the process itself remains alive.

## 15.5 Multiple simultaneous user sessions

V1 tracks the session in which the tracker is running.

It MUST NOT silently aggregate other logged-in Windows user sessions.

Remote Desktop and Fast User Switching boundaries are therefore explicit session changes, not hidden duplicate activity.

---

# 16. Sleep, Suspend, Resume, Shutdown

The tracker must recognize OS power transitions so that sleeping time is never mistaken for application use.

`RegisterSuspendResumeNotification` provides a user-mode mechanism for receiving suspend/resume notifications. citeturn750935search6

## 16.1 Suspend

On suspend:

1. Close all open foreground/visible/idle intervals.
2. Record a suspend lifecycle event.
3. Mark observation unavailable.
4. Stop active observation loops where possible.

## 16.2 Resume

On resume:

1. Reset observation caches that may have become stale.
2. Reconcile session state.
3. Rebuild or validate window inventory.
4. Re-query foreground HWND.
5. Re-query process identity.
6. Re-query display topology.
7. Re-query idle state.
8. Start new intervals from the recovered state.

No pre-suspend interval may be implicitly extended across sleep.

## 16.3 Abrupt shutdown

On clean process/system shutdown where a signal is received, flush buffered data and close active intervals.

If no shutdown signal is observed, recovery on next startup must conservatively mark the previous runtime as terminated unexpectedly rather than assuming continuous tracking through the downtime.

---

# 17. Tracker Lifecycle State Machine

The runtime lifecycle is:

```text
Starting
   │
   ▼
Initializing
   │
   ├── success ─────► Observing
   │
   └── failure ─────► Degraded / Recovery
                          │
                          ▼
                      Observing
                          │
                          ▼
                      Shutdown
                          │
                          ▼
                       Stopped
```

Tracking availability is a separate dimension:

```text
Available
Locked
Sleeping
SessionUnavailable
StorageUnavailable
Recovering
Unknown
```

The implementation MUST NOT encode these two dimensions as one giant enum because lifecycle and observation availability evolve independently.

---

# 18. Startup and Initial State Resolution

At tracker startup:

1. Initialize logging with privacy-safe local diagnostics.
2. Open/create SQLite through the data layer.
3. Initialize monotonic and wall-clock providers.
4. Identify current Windows session.
5. Register event hooks.
6. Create session/power/display observers.
7. Enumerate initial window inventory.
8. Resolve current foreground HWND.
9. Resolve current process/window identity.
10. Resolve current display association.
11. Query idle state.
12. Establish initial state.
13. Persist a tracker-start lifecycle event.
14. Begin normal observation.

The startup sequence MUST establish a known state before starting normal interval accumulation.

The tracker MUST NOT create a fictional interval from process start time to tracker startup time.

Example:

```text
Tracker starts at 09:00.
VS Code has been foreground since 08:20.

Recorded foreground interval begins at 09:00,
not 08:20.
```

This is essential for avoiding fabricated historical activity.

---

# 19. Crash and Restart Recovery

The tracker is expected to run continuously, but crashes must be survivable.

## 19.1 On normal operation

Active intervals are buffered in memory and periodically persisted.

## 19.2 On crash

The OS may terminate the process without allowing a final interval close.

On next startup:

1. Identify the last persisted runtime heartbeat/checkpoint.
2. Mark the previous runtime as unexpectedly terminated if no clean shutdown marker exists.
3. Close any open persisted interval at the last **persisted** defensible boundary, not at current time.
4. Record a tracking gap from that boundary until the new observation session establishes state.
5. Start new intervals only after fresh state resolution.

The system MUST NOT do this:

```text
last foreground start → new tracker startup
```

as one continuous interval unless the process demonstrably remained alive and state continuity is proven.

## 19.3 Heartbeat/checkpoint

A lightweight local heartbeat should be persisted at a bounded cadence, suggested default:

```text
30 seconds
```

This is not an analytics event. It exists only to bound uncertainty during abnormal termination.

The heartbeat cadence must be benchmarked against write amplification and can be implemented as metadata within an existing batched write rather than an independent SQLite transaction.

---

# 20. Timing Model

Accurate duration requires two clocks.

## 20.1 Wall clock

Wall clock is used for historical placement:

```text
UTC instant
```

The normalized event model should store UTC timestamps. Local timezone/offset context is retained as needed for calendar presentation and date-boundary calculations.

## 20.2 Monotonic clock

A monotonic clock is used for elapsed-duration measurement inside the runtime.

This protects interval duration from:

- NTP corrections.
- Manual clock changes.
- Daylight-saving transitions.
- Timezone changes.

## 20.3 Dual timestamp

Each observation should conceptually contain:

```text
ObservedAtUtc
MonotonicTicks
```

The interval engine uses monotonic deltas to determine elapsed duration while wall-clock values determine historical placement.

## 20.4 Wall-clock discontinuity

If the wall clock jumps significantly relative to monotonic elapsed time:

1. Preserve monotonic duration.
2. Detect and record a clock-discontinuity diagnostic event.
3. Re-anchor subsequent wall-clock placement.
4. Never silently manufacture negative or duplicated durations.

## 20.5 Daylight-saving transitions

A DST boundary must not change elapsed duration.

For example, a two-hour monotonic interval crossing a DST transition remains two hours of elapsed time even if local wall-clock labels appear to skip or repeat an hour.

---

# 21. Interval Engine

The interval engine is the authoritative owner of time segmentation.

## 21.1 State tuple

A resolved desktop state can be conceptually modeled as:

```text
DesktopState {
    sessionId
    availability
    foregroundWindow
    foregroundProcess
    foregroundApplication
    foregroundMonitor
    idleState
    visibleWindows[]
    displayTopologyVersion
}
```

## 21.2 State transition

Each normalized observation produces one of:

```text
No change
State change
State unavailable
State recovered
```

The engine compares the new state with the previous state and closes/opens intervals only for dimensions that changed.

## 21.3 Independence of dimensions

Foreground, visible, idle, session availability, and monitor association are separate dimensions.

Example:

```text
Foreground: Chrome
Visible: Chrome + Discord + VS Code
Idle: false
Monitor: 2
```

A monitor movement should not close the application foreground interval unless foreground application/window state also changes.

An idle transition should not close foreground time.

A background window becoming hidden should not change foreground state.

## 21.4 Interval closure

An open interval is closed at the earliest trustworthy boundary:

- Explicit observed state transition.
- Lifecycle event.
- Persisted last-known boundary during crash recovery.
- Tracker shutdown boundary.

If no trustworthy boundary exists, the interval ends at the last trustworthy checkpoint and the remainder becomes a gap.

---

# 22. Visible-Time Overlap Model

Multiple visible application windows can overlap in time.

This is intentional.

Example:

```text
14:00–14:30 Chrome visible
14:10–14:25 Discord visible
14:15–14:20 VS Code visible
```

The engine records all three visible intervals.

Therefore:

```text
Sum of app visible durations
```

is **not** a measure of unique desktop time and may exceed elapsed wall-clock time.

Analytics must label this correctly.

Foreground time, by contrast, is mutually exclusive within a tracked session whenever the foreground state is observable.

---

# 23. Application Switching Semantics

The engine emits a canonical switch event when:

```text
PreviousCanonicalApp != CurrentCanonicalApp
```

at a valid foreground transition boundary.

It SHOULD also preserve:

```text
PreviousWindow
CurrentWindow
PreviousProcess
CurrentProcess
```

for detailed timeline inspection.

The switch counter must not be based on polling samples because that would undercount rapid changes and make the result dependent on the polling interval.

---

# 24. Browser Boundary

The core Windows tracker does not parse URLs or page contents.

It provides browser/application/window state to the browser subsystem.

Browser acquisition may add:

```text
browser app
browser window/tab identity
URL/domain
page title
private/incognito state
```

The browser subsystem must explicitly merge or correlate its data with Windows foreground/visible intervals.

## 24.1 Incognito/private browsing

At launch:

```text
Browser application tracking: enabled
Domain tracking in private mode: disabled
Page-title tracking in private mode: disabled
```

The fail-closed behavior is mandatory when the subsystem cannot confidently distinguish private browsing.

## 24.2 Page titles

Page titles are high-resolution local metadata and can be stored separately from domain identity.

The user can disable page-title collection without disabling browser/domain tracking.

This boundary prevents browser-specific logic from contaminating the Windows observation engine.

---

# 25. Buffering and Persistence

The tracker must minimize disk I/O while preserving data integrity.

## 25.1 In-memory buffer

Observations and small interval mutations should first enter a bounded in-memory buffer.

Recommended initial target:

```text
Normal persistence batch: 1–5 seconds
Maximum buffered volume: enough for at least 60 seconds of normal operation
```

These are starting engineering targets, not user-facing promises.

## 25.2 SQLite writes

Use transactions for logically related state changes.

Prefer:

```text
many logical events
        ↓
small batched transaction
        ↓
one durable write boundary
```

rather than one SQLite transaction per OS callback.

## 25.3 Backpressure

If the persistence writer falls behind:

1. Continue bounded observation for as long as the buffer remains below its safety threshold.
2. Surface a `StorageDegraded` health state.
3. Increase batch efficiency rather than allowing unbounded memory growth.
4. If data loss becomes unavoidable, stop pretending the period is fully tracked.
5. Persist an explicit gap/loss marker where possible.

The tracker MUST NOT grow memory without bound to avoid acknowledging persistence failure.

## 25.4 Tracker/UI concurrency

The tracker is the authority for acquisition writes.

The exact SQLite concurrency model remains an implementation benchmark/ADR decision, but the tracking runtime MUST be able to durably append observation data without waiting on UI analytics queries.

Long-running UI queries must never block acquisition.

---

# 26. Performance Budget

Tracking is a background instrument, not a continuously active desktop application.

Acceptance targets inherited from the architecture baseline are:

| Metric | Target |
|---|---:|
| Idle tracker CPU | < 1% |
| Typical tracker CPU | < 2% |
| Idle tracker RAM | < 150 MB |
| GPU usage while tracking | Effectively zero |
| Disk writes | Batched; near-zero when state is unchanged |
| Polling | Reconciliation only; event-driven primary |
| Network | None required for tracking |

These targets are measured for the **tracking runtime**, excluding the dashboard UI process.

## 26.1 Wakeup budget

The tracker should minimize periodic wakeups.

Preferred pattern:

```text
OS event
   ↓
process immediately

No event
   ↓
low-frequency reconciliation
```

The tracker must not use a high-frequency loop such as:

```text
while true:
    enumerate windows
    inspect processes
    sleep 50 ms
```

as its V1 architecture.

## 26.2 Reconciliation tuning

The 2-second starting interval may be changed after measurement.

Correctness requirements take priority over minimizing wakeups, but a shorter interval must demonstrate a measurable correctness benefit before adoption.

## 26.3 Metadata acquisition caching

Expensive metadata should be cached by process/window lifetime.

Examples:

- Executable path.
- Package identity.
- Stable application metadata.
- Process start time.

Window title remains more dynamic and should be refreshed only when relevant events or reconciliation indicate a change.

---

# 27. Privacy and Data Boundaries

The tracker is local-first and must have no network dependency.

## 27.1 No behavioral telemetry

The tracker MUST NOT send:

- Usage events.
- Application names.
- Window titles.
- Browser domains.
- User activity statistics.
- Diagnostics with identifying data.

anywhere by default.

## 27.2 Local data

Window titles, raw executable identities, domain data, and derived history are local application data under the privacy/security architecture.

## 27.3 Diagnostics

Debug logging must avoid copying sensitive content unnecessarily.

Examples of preferred logs:

```text
Foreground hook registered successfully
Window identity resolution failed: access denied
SQLite batch commit duration: 7 ms
```

Avoid logs such as:

```text
User was on https://example.com/private/... 
Window title was: My private document ...
```

unless an explicit secure diagnostic workflow requires it and the user has opted in.

## 27.4 No privileged observation by default

The tracker should request only the OS privileges necessary for normal user-session observation.

It should not run elevated merely because some optional metadata path is more convenient under elevation.

---

# 28. Failure Isolation

Individual acquisition failures must degrade independently.

| Failure | Expected effect |
|---|---|
| Foreground hook fails | Reconciliation can maintain reduced foreground correctness; health marked degraded |
| Window inventory hook fails | Periodic/full enumeration restores inventory |
| One process metadata lookup fails | Raw window may become unresolved; other apps continue |
| Browser adapter fails | Windows app tracking continues |
| Display lookup fails | Application timing continues without monitor attribution |
| Idle API fails | Foreground/visible tracking continues; idle dimension unavailable |
| Session notification failure | Reconciliation/lifecycle health enters degraded state; no silent confidence |
| SQLite temporary failure | Buffer and retry within bounded limits |
| SQLite unavailable | Tracking health becomes storage unavailable; no false persistence claim |
| UI crashes | Tracker continues |
| Network unavailable | No impact on local tracking |

The tracker must prefer an explicit degraded state over silently producing plausible-looking but incorrect analytics.

---

# 29. Health Model

The tracker should expose a compact local health state to the UI.

Recommended dimensions:

```text
Tracker process: Healthy | Degraded | Recovering | Stopped
Foreground observation: Healthy | Degraded | Unavailable
Visible observation: Healthy | Degraded | Unavailable
Session observation: Healthy | Degraded | Unavailable
Display observation: Healthy | Degraded | Unavailable
Persistence: Healthy | Degraded | Unavailable
Idle observation: Healthy | Degraded | Unavailable
```

Health status is operational metadata, not behavioral analytics.

The UI can display:

```text
Tracking normally
Tracking with reduced browser detail
Tracking gap detected
Storage temporarily unavailable
```

rather than hiding these states.

---

# 30. Data Contracts

The precise database schema belongs in Document 07, but the tracking engine must emit normalized records that contain enough information to reconstruct and audit the interval stream.

## 30.1 Observation record

Conceptual shape:

```text
RawObservation {
    observationId
    observedAtUtc
    monotonicTicks
    sessionId
    source
    sourceSequence

    hwnd?
    processId?
    processStartTimeUtc?

    executablePath?
    executableName?
    packageIdentity?

    windowTitle?
    isVisible?
    isMinimized?
    isCloaked?

    monitorKey?

    foregroundState?
    idleState?

    lifecycleState
}
```

## 30.2 State transition record

Conceptual shape:

```text
StateTransition {
    transitionId
    observedAtUtc
    monotonicTicks
    transitionType
    previousStateReference
    currentStateReference
    confidence
}
```

## 30.3 Interval record

Conceptual shape:

```text
UsageInterval {
    intervalId
    dimension            // Foreground | Visible | Idle | Gap
    startUtc
    endUtc?
    monotonicDuration?

    sessionId
    windowInstanceKey?
    processInstanceKey?
    canonicalAppId?
    monitorKey?

    provenance
    completionReason
}
```

An interval must retain enough provenance to explain why it exists.

---

# 31. Provenance and Confidence

Not all observations have equal acquisition strength.

The engine should preserve a provenance/source classification such as:

```text
EventHook
DirectPoll
FullReconciliation
StartupRecovery
LifecycleSignal
```

This is not a user-facing confidence score for application classification. It is an internal provenance mechanism.

A later analytics layer may use provenance to explain unusual periods or investigate tracking quality.

---

# 32. Deterministic Event Processing

Event processing must be deterministic enough that a captured observation stream can be replayed and yield the same interval result.

## 32.1 Ordering key

When multiple observations have similar wall-clock timestamps, processing should use:

1. Monotonic timestamp.
2. Source sequence where available.
3. Runtime receive sequence as final tie-breaker.

## 32.2 Duplicate events

Equivalent observations with no state change should not create extra intervals.

## 32.3 Late observations

An observation arriving after the engine has already advanced beyond its boundary must be classified according to a deterministic policy.

The default policy is:

- Do not rewrite previously persisted intervals inside the hot path.
- Preserve the late observation.
- Schedule bounded reconciliation/correction if it materially changes state history.

Historical correction logic belongs in the data layer/repair tooling if needed.

---

# 33. Reconciliation Algorithm

The initial reconciliation loop should conceptually execute:

```text
1. Check runtime/session availability.
2. Get current foreground HWND.
3. Validate current foreground HWND/process identity.
4. Refresh relevant visible-window inventory.
5. Detect stale/dead process or window instances.
6. Reconcile display topology if dirty.
7. Query last-input idle state.
8. Build normalized current desktop state.
9. Compare with authoritative state store.
10. Emit only necessary transitions.
11. Flush pending state changes according to persistence policy.
12. Update health/checkpoint metadata.
```

The implementation should avoid performing every expensive operation on every tick when cached state proves it unnecessary.

For example, if display topology is unchanged, display metadata need not be recomputed for every window on every foreground reconciliation.

---

# 34. Message-Loop Threading Model

Because out-of-context WinEvent delivery requires a message loop, the tracking runtime should isolate event hooks on a dedicated native-observation thread.

Recommended model:

```text
Tracking process
│
├── Observer thread
│    ├── WinEvent hook
│    ├── hidden/message-only window
│    ├── session notifications
│    ├── suspend/resume notifications
│    └── message loop
│
├── State/interval worker
│
└── Persistence worker
```

The UI thread must never be required for tracking.

Observer callbacks should be tiny:

```text
capture signal
→ enqueue normalized event
→ return
```

They should not:

- Query SQLite.
- Render UI.
- Perform large process enumeration.
- Resolve a complex identity graph synchronously.
- Make network calls.

This protects callback latency and keeps the event source responsive.

---

# 35. Thread-Safety Requirements

The engine should use a single serialized state-processing lane for interval state.

Recommended approach:

```text
Windows callbacks ─┐
Reconciliation ─────┼──► event queue ─► single state worker
Lifecycle signals ──┤
Browser signals ────┘
```

This avoids lock-heavy concurrent mutation of the authoritative interval state.

The persistence writer may run asynchronously downstream from the state worker.

The observer layer must never mutate state objects owned by the state worker directly.

---

# 36. Graceful Shutdown

On normal shutdown:

1. Stop accepting new observer events.
2. Unhook WinEvent hooks.
3. Unregister session/power notifications.
4. Stop reconciliation timer.
5. Resolve/close open intervals at shutdown boundary.
6. Flush state-event buffers.
7. Commit final persistence transaction.
8. Write clean-shutdown marker.
9. Exit.

Shutdown should be idempotent.

If a shutdown step fails, the runtime must continue best-effort cleanup without corrupting already persisted records.

---

# 37. Testing Strategy

The tracking engine must be testable without requiring a real interactive desktop for most logic.

## 37.1 Unit tests

Test:

- Foreground state transitions.
- Application-switch counting.
- Same-app window switching.
- Visible interval overlaps.
- Idle transitions.
- Session lock/unlock.
- Suspend/resume.
- PID reuse.
- HWND lifetime changes.
- Monitor changes.
- Duplicate event coalescing.
- Event ordering.
- Clock jumps.
- Crash recovery boundaries.
- Buffer overflow/backpressure.
- Gap creation.

## 37.2 Replay fixtures

Create deterministic input fixtures:

```text
fixture:
  10:00:00 foreground Chrome A
  10:02:00 visible Discord
  10:05:00 foreground VS Code
  10:06:00 idle=true
  10:08:00 idle=false
  10:10:00 foreground Chrome A
```

Expected output should contain exact intervals and switch counts.

Replay tests should not depend on real wall-clock time.

## 37.3 Windows integration tests

On supported Windows CI/dev machines, integration tests should verify:

- `GetForegroundWindow` resolution.
- WinEvent hook setup/teardown.
- Session notification registration.
- Suspend/resume registration.
- Window enumeration.
- Monitor mapping.
- Process identity resolution.

Tests that mutate actual desktop state should be clearly separated from deterministic unit/replay tests and should not be required for every local code change.

## 37.4 Soak tests

Run the tracker continuously under realistic desktop workloads:

- Browser-heavy.
- IDE-heavy.
- Gaming.
- Multi-monitor.
- Frequent window switching.
- Many concurrent applications.
- Sleep/wake cycles.
- Lock/unlock cycles.
- Remote Desktop/Fast User Switching where supported.

Measure resource use, missed transitions, buffer growth, and SQLite write patterns.

---

# 38. Accuracy Acceptance Criteria

The implementation is not considered tracking-correct merely because the dashboard shows plausible numbers.

Minimum acceptance criteria:

### Foreground

- A normal application switch is detected without waiting for the reconciliation interval.
- Foreground intervals do not overlap.
- Rapid event-observed switches are not discarded because they are short.
- Same-application window changes are distinguishable from application switches.

### Visible

- Multiple visible applications can have overlapping intervals.
- Minimized windows do not accumulate visible time.
- Lock/sleep periods do not accumulate as visible application time.

### Identity

- PID reuse cannot merge two process lifetimes into one instance.
- Canonical application aggregation preserves raw process/window provenance.
- User corrections do not rewrite raw observations.

### Lifecycle

- Lock/unlock boundaries are explicit.
- Suspend/resume boundaries are explicit.
- Tracker crashes create a gap rather than a fabricated continuous interval.
- Startup never backfills before first proven observation.

### Multi-monitor

- Window monitor association updates after movement/topology change.
- Application time totals remain correct regardless of monitor changes.

### Performance

- Background tracker meets the CPU/RAM/I/O targets under representative workloads.
- No busy polling loop is present.
- Observer callbacks remain lightweight.

---

# 39. Performance Benchmark Plan

Before finalizing implementation parameters, build a small benchmark harness with:

1. Foreground event hook active.
2. Reconciliation loop active.
3. Window inventory maintained.
4. Process identity cache.
5. SQLite batch persistence.

Benchmark scenarios:

| Scenario | Measure |
|---|---|
| Idle desktop | CPU, RAM, wakeups, writes |
| One app switching every minute | Event latency and CPU |
| Rapid switching | Event loss and CPU |
| 20–50 open windows | Inventory cost |
| Browser-heavy session | Metadata overhead |
| Multi-monitor | Display-resolution overhead |
| Sleep/wake | Recovery latency |
| Lock/unlock | Recovery correctness |
| Tracker restart | Gap correctness |
| SQLite contention | Persistence latency |

The benchmark should record:

```text
CPU average + p95
RAM average + peak
wakeups/sec
callbacks/sec
SQLite writes/sec
SQLite bytes written
queue depth
state-transition latency
missed-event count
```

Parameter changes such as changing reconciliation from 2 seconds to 5 seconds must be justified against measured correctness and resource impact.

---

# 40. Implementation Order

Build the tracking engine in the following order:

### Phase 1 — Platform abstraction

- `IWindowApi`
- `IProcessApi`
- `ISessionApi`
- `IPowerApi`
- `IDisplayApi`
- `IClock`
- `IInputActivityApi`

### Phase 2 — Deterministic state engine

Implement entirely synthetic observation input:

```text
observation → normalized state → interval transitions
```

Before any Win32 integration is added, prove:

- Correct half-open intervals.
- Non-overlapping foreground time.
- Overlapping visible time.
- Idle subintervals.
- Gaps.
- Crash recovery semantics.

### Phase 3 — Foreground Win32 adapter

Implement:

- `GetForegroundWindow`.
- `SetWinEventHook`.
- Observer message loop.
- Reconciliation polling.

### Phase 4 — Identity adapter

Implement:

- HWND → PID.
- PID → process start time.
- PID → executable identity.
- Canonical application resolution.

### Phase 5 — Window inventory

Implement:

- `EnumWindows` startup inventory.
- Visibility/minimize/cloak state.
- Lifecycle updates.

### Phase 6 — Lifecycle integration

Implement:

- Session notifications.
- Lock/unlock.
- Suspend/resume.
- Shutdown/restart.

### Phase 7 — Display integration

Implement:

- Window → monitor mapping.
- Topology invalidation.
- Monitor identity records.

### Phase 8 — Persistence

Implement:

- Buffered writes.
- Checkpoints.
- Crash recovery markers.
- Gap persistence.

### Phase 9 — Browser integration

Only after the Windows tracking core is stable should browser-domain acquisition connect to the interval engine.

---

# 41. Hard Invariants

The following are non-negotiable:

1. **The tracker does not require the UI to run.**
2. **The tracker does not require the network.**
3. **Foreground time is derived from state transitions, not coarse polling samples.**
4. **Visible time may overlap across applications.**
5. **Foreground time is mutually exclusive while state is observable.**
6. **PID alone is never a process-instance identity.**
7. **Raw observation identity is separate from canonical application identity.**
8. **Private browsing data fails closed when privacy state is uncertain.**
9. **A crash creates uncertainty/gap; it does not create invented continuity.**
10. **Lock and sleep time are never attributed to the previous application.**
11. **The observer callback path does not perform heavy work.**
12. **Persistence failure cannot cause unbounded memory growth.**
13. **Network failure cannot stop local tracking.**
14. **Analytics queries cannot block acquisition indefinitely.**
15. **No behavioral telemetry is emitted by the tracker.**
16. **Reconciliation is a correctness safety net, not the authoritative time source.**
17. **Display changes do not fabricate application switches.**
18. **A tracker startup cannot backfill activity that predates proven observation.**
19. **All meaningful lifecycle boundaries are explicit in the event model.**
20. **The tracking engine must be replayable deterministically in tests.**

---

# 42. Deferred Decisions / ADRs

The following should remain explicit ADRs rather than being silently decided in code:

- **ADR-003:** Exact foreground/visible observation strategy.
- **ADR-004:** SQLite writer/concurrency model.
- **ADR-006:** Browser acquisition architecture and correlation.
- **ADR-007:** Local database/data protection.
- **ADR-010:** Packaging/startup/restart mechanism.

Additional tracking-specific ADRs may be added for:

- Exact display identity strategy.
- Window cloaking detection implementation.
- Exact reconciliation cadence after benchmarks.
- Browser-to-window correlation.
- Long-title normalization/storage policy.
- High-volume visible-window persistence strategy.

---

# 43. Open Engineering Questions

These are intentionally deferred because they require implementation measurements rather than documentation-only decisions:

1. Does a 2-second reconciliation interval provide sufficient recovery coverage, or is 3–5 seconds materially cheaper with no practical accuracy loss?
2. Which exact WinEvent event set minimizes polling without producing excessive callback volume?
3. What window-cloaking detection path is reliable across Windows 10/11 desktop environments?
4. What is the cheapest reliable stable monitor identity across reconnects and topology changes?
5. How frequently can window titles be refreshed without becoming the dominant tracker cost?
6. Does a tracker-owned SQLite writer provide materially better tail latency than disciplined shared access?
7. What checkpoint cadence gives the best crash-gap bound per disk-write cost?
8. How should late browser observations be reconciled with already-persisted Windows intervals?
9. How many simultaneous visible windows are typical in representative workloads, and what inventory strategy is cheapest at the 95th percentile?

These questions should be answered with benchmark spikes and documented in ADRs rather than guessed in the production implementation.

---

# 44. Reference Windows APIs

Primary Microsoft references used by this specification:

- `GetForegroundWindow` — foreground window acquisition. citeturn173932search0
- `SetWinEventHook` — out-of-context Windows event hooks and message-loop requirements. citeturn750935search3
- `EnumWindows` — top-level window enumeration. citeturn173932search6
- `GetWindowText` — window title retrieval and limitations. citeturn173932search5
- `MonitorFromWindow` — window/display monitor association. citeturn750935search12
- `WTSRegisterSessionNotification` / `WM_WTSSESSION_CHANGE` — user-session lifecycle signals. citeturn750935search0turn750935search7
- `RegisterSuspendResumeNotification` — suspend/resume notification. citeturn750935search6

This document intentionally does not freeze individual P/Invoke signatures. The Windows interop layer should encapsulate those signatures and expose typed C# contracts to the rest of the tracker.

---

# 45. Definition of Done for Document 06

Document 06 is implemented when the repository contains a tracking runtime capable of:

- Running independently of the UI.
- Detecting foreground changes primarily through Windows event hooks.
- Reconciling state periodically.
- Tracking foreground and visible intervals using explicit state transitions.
- Preserving overlapping visible intervals.
- Counting canonical application switches accurately.
- Distinguishing raw windows/processes from canonical applications.
- Handling PID reuse safely.
- Handling lock/unlock and suspend/resume.
- Maintaining multi-monitor attribution.
- Recording explicit tracking gaps.
- Recovering from crashes without fabricated history.
- Persisting data in bounded batches.
- Remaining offline and telemetry-free.
- Meeting the measurable runtime performance budget.
- Passing deterministic replay tests and representative Windows integration tests.

The next document, **Document 07 — Data Architecture & Storage Specification**, should define the SQLite schema, immutable/raw versus derived tables, interval storage, aggregation strategy, retention/compaction, migrations, indexing, consistency rules, and repair procedures that make these tracking-engine guarantees durable.