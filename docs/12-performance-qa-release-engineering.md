# Performance, QA & Release Engineering Specification

**Product:** PC Usage Intelligence  
**Document:** 12 — Performance, QA & Release Engineering Specification  
**Status:** Authoritative engineering-quality baseline — Pre-development  
**Parent documents:** `docs/01-product-requirements.md` through `docs/11-google-drive-sync-specification.md`  
**Platform:** Windows 10 and Windows 11  
**Last updated:** 2026-09-02

---

# 1. Purpose

PC Usage Intelligence is a background system that should remain nearly invisible while continuously collecting high-resolution usage history.

The quality bar is therefore different from an ordinary desktop application.

The product must simultaneously be:

```text
Accurate
Low overhead
Reliable over weeks/months
Privacy-preserving
Crash-resilient
Update-safe
Recoverable
```

A tracker that is accurate but consumes noticeable CPU is not acceptable.

A beautiful UI that causes tracking gaps is not acceptable.

A sync feature that corrupts local history is not acceptable.

This document turns the product's qualitative goals into measurable engineering gates.

It defines:

- Resource budgets.
- Performance measurement methodology.
- Accuracy validation.
- Endurance testing.
- Fault injection.
- Privacy/security regression testing.
- Database/storage testing.
- Browser integration QA.
- UI quality gates.
- Accessibility requirements.
- Packaging.
- Installer/update behavior.
- Microsoft Store and standalone release requirements.
- Crash/recovery validation.
- CI/CD.
- Release channels.
- Go/no-go criteria.

---

# 2. Normative Language

- **MUST** — required for release.
- **MUST NOT** — prohibited.
- **SHOULD** — strong recommendation.
- **MAY** — optional.

---

# 3. Quality Philosophy

The project should optimize for **trustworthy longitudinal history**, not benchmark theater.

The most important product test is:

```text
Install
↓
Leave running for a month
↓
Use the PC normally
↓
Open the history
↓
The recorded history is accurate
↓
The machine remained fast
↓
No unexpected data left the device
```

This should be treated as the primary end-to-end acceptance scenario.

---

# 4. Release-Critical Components

The following are release-critical:

1. Tracking runtime.
2. Windows observation layer.
3. SQLite persistence.
4. Sessionization/interval engine.
5. Browser acquisition.
6. Identity resolution.
7. Privacy enforcement.
8. Local IPC.
9. Desktop UI data consumption.
10. Sync/cryptography when enabled.
11. Installer/update mechanism.
12. Data migration logic.

A failure in any release-critical component requires explicit severity assessment before release.

---

# 5. Performance Budgets

These are initial product acceptance targets and must be measured on representative hardware.

## 5.1 Tracking runtime

### Idle

```text
CPU: <1% sustained
RAM: <150 MB
GPU: effectively zero
Network: zero
Disk writes: batched / near-zero steady-state
```

### Typical active tracking

```text
CPU: <2% sustained
RAM: <150 MB target
Wakeups: event-driven with low-frequency reconciliation
GPU: effectively zero
Network: zero
```

These values refer to the tracking runtime rather than the full interactive UI.

## 5.2 Sync worker

Steady-state sync target:

```text
CPU: <2% sustained during normal synchronization
RAM: <150 MB; substantially lower preferred
No tight idle polling
Bounded concurrency
```

## 5.3 Desktop UI

The UI can consume more resources than the tracker, but must remain responsive.

Targets:

- Cold launch to usable shell: ≤3 seconds on reference hardware.
- Normal navigation: no perceptible blocking during local-data queries.
- Timeline interaction: target ≥60 FPS on representative datasets where hardware permits; gracefully degrade when not possible.
- Large history views must use virtualization/aggregation rather than rendering every event simultaneously.

## 5.4 Disk

The tracker must batch SQLite persistence.

The implementation should avoid one disk write per observation.

The database must remain within a reasonable storage envelope under the raw-observation retention policy defined in Document 07.

Exact disk targets require a storage-growth experiment before release.

---

# 6. Reference Hardware Matrix

Performance testing must not rely on one developer machine.

Maintain at least three representative tiers:

### Tier A — Modern developer/gaming PC

```text
Recent multi-core CPU
16–32 GB RAM
NVMe SSD
Discrete GPU
```

### Tier B — Mainstream student laptop

```text
4–8 CPU cores
8–16 GB RAM
SSD
Integrated or entry GPU
```

### Tier C — Older supported Windows device

```text
Older supported CPU
8 GB RAM
SSD
Integrated graphics
```

Windows 10 and Windows 11 coverage must be represented.

Exact hardware models should be recorded in CI/performance reports so regressions are comparable.

---

# 7. Benchmark Methodology

Performance measurements must distinguish:

```text
Cold start
Warm start
Idle
Active foreground changes
Many windows
Many browser tabs
Long history
Sync backlog
Initial import
```

Use repeated runs rather than a single sample.

At minimum record:

- Median.
- P95 where useful.
- Maximum for bounded operations.
- CPU time.
- Wall-clock duration.
- Working-set/private memory.
- Disk bytes written.
- Wakeups where measurable.
- Network bytes for sync/update tests.

Avoid declaring improvement based only on one benchmark run.

---

# 8. Performance Instrumentation

Use an internal performance instrumentation layer that can be enabled in test builds.

It should expose:

```text
Tracker loop duration
Observation queue depth
Persistence batch latency
SQLite transaction latency
IPC round-trip latency
Browser bridge latency
Sync queue depth
Encryption throughput
Timeline query latency
UI render duration
Memory growth
```

The instrumentation itself must be negligible in normal release builds and must not become behavioral telemetry.

---

# 9. Tracking Accuracy Testing

Tracking correctness is more important than small performance wins.

Create deterministic observation fixtures representing:

```text
App A foreground
App B foreground
rapid A→B→A switching
minimized window
occluded window
multiple instances
multiple monitors
window close
process restart
sleep
resume
lock
unlock
sign-out
tracker restart
clock change
```

Each fixture should have an expected interval timeline.

The test compares actual results against the expected event model.

---

# 10. Ground-Truth Harness

A dedicated test harness should generate known application/window states and independently record the expected sequence.

Conceptually:

```text
Test harness state
      ↓
Known truth
      ↓
Windows observation APIs
      ↓
Tracker
      ↓
SQLite
      ↓
Reconstructed timeline
      ↓
Compare
```

The harness must not simply call the same internal function that is under test to produce the expected result.

---

# 11. Foreground Accuracy

Test cases must verify:

- Foreground transitions are captured.
- Duplicate events do not create overlapping foreground intervals.
- Very short switches are handled according to defined debounce semantics.
- Process restarts are distinguishable from continued process identity.
- Window handle reuse does not merge unrelated windows.
- Lock/sleep do not become application usage.
- Tracking gaps remain explicit.

Accuracy reports should quantify:

```text
Missed transitions
False transitions
Timing error
Duplicate intervals
Unexplained gaps
```

---

# 12. Visible-Time Accuracy

Visible-time logic must be tested independently from foreground logic.

Scenarios:

```text
Two non-minimized windows
Overlapping windows
Occluded window
Different monitors
Virtual desktops where supported/observable
Minimized window
Cloaked window
Foreground window change
```

The expected model is OS-visible window presence, not human gaze estimation.

---

# 13. Multi-Monitor Testing

Every release candidate should test:

- One monitor.
- Two monitors.
- Mixed resolutions.
- Different DPI scales.
- Primary-monitor changes.
- Monitor connect/disconnect.
- Full-screen application transitions.
- Window moved between monitors.

No monitor configuration should corrupt timestamps or canonical application identity.

---

# 14. Process/Application Identity Testing

Test:

```text
Same executable, multiple instances
Same application, multiple process trees
Packaged app
Classic Win32 app
Store app
Launcher + game
Browser child processes
Executable moved/updated
Process restart with same executable
```

The expected behavior is:

```text
Raw identity preserved
Canonical identity stable where possible
User override remains higher-level
```

---

# 15. Browser QA Matrix

Launch browsers:

- Chrome.
- Edge.
- Firefox.
- Brave.
- Arc.

Test:

```text
Normal tab
Multiple tabs
Same-domain multiple tabs
Different domains
Window switching
Browser window switching
Private/incognito browsing
Browser restart
Profile restart
Extension unavailable
Bridge disconnected
Browser update
```

Expected behavior must match Document 08.

---

# 16. Browser Privacy Tests

Mandatory tests:

```text
Private tab active
→ application time may exist
→ private domain absent
→ private title absent

Unknown private state
→ detail withheld
```

Also verify that:

- Private data cannot enter raw observations through fallback paths.
- Private data cannot enter encrypted sync objects.
- Private data cannot enter diagnostics.
- Private data cannot enter logs.
- Disabling page-title collection actually prevents new page-title persistence.

---

# 17. Sessionization Tests

Verify:

- Sessions start at expected transitions.
- Sessions end on inactivity/termination according to policy.
- Process restarts do not merge unrelated sessions.
- Sleep/lock boundaries are explicit.
- Gaps are not converted into active time.
- Long-running sessions remain numerically stable.

Use deterministic clocks in unit tests and controlled monotonic/wall-clock sources in integration tests.

---

# 18. Timekeeping Tests

Test:

- Clock moves forward.
- Clock moves backward.
- Time zone changes.
- Daylight-saving transitions where applicable.
- Sleep/resume.
- Suspend/resume.
- Long system uptime.
- Timestamp precision.

Expected principle:

```text
Duration uses monotonic time where available.
Historical placement uses wall-clock time.
```

A wall-clock correction must not create impossible negative active durations.

---

# 19. Database Correctness

SQLite tests must cover:

- Transaction rollback.
- Crash during transaction.
- Crash after commit.
- WAL recovery if used.
- Migration failure.
- Constraint violations.
- Partial writes.
- Corrupt page/database handling.
- Index consistency.
- Large-history queries.
- Concurrent readers.
- Tracker write pressure.

Every migration must have an explicit upgrade test from the previous supported schema.

---

# 20. Data Integrity Invariants

Automated integrity checks should assert:

```text
No impossible negative durations.
No overlapping foreground intervals for one observation stream.
Visible intervals may overlap.
Every interval references valid identity records.
Every sync mutation has stable identity.
Every tombstone has valid scope.
No private browser detail exists.
```

These checks should be runnable against both live and fixture databases.

---

# 21. Replay Testing

The system should support replaying raw observations into derived intervals and aggregates.

This enables:

```text
same observations
+ new algorithm version
→ compare output
```

Replay tests are required before changing core sessionization/aggregation logic.

---

# 22. Deterministic Analytics Tests

Known datasets should have expected values for:

- Daily totals.
- Weekly totals.
- Category totals.
- Foreground totals.
- Visible totals.
- Browser/domain totals.
- Session count.
- Average session duration.
- App-switch count.
- Productivity/leisure totals.

Analytics tests must compare against hand-verified fixtures.

---

# 23. Historical Correction Tests

Test:

```text
Record history
↓
Change classification
↓
Invalidate affected aggregates
↓
Rebuild
↓
Verify historical reports
```

Also test undo/replacement semantics if supported.

A historical correction must not rewrite immutable raw observations merely because a presentation label changed.

---

# 24. Sync QA

Sync tests from Document 11 become release gates once sync ships.

Required scenarios:

```text
single-device sync
offline backlog
reconnect
process termination during upload
process termination during download
concurrent devices
classification conflict
range deletion race
delete-all race
device rejoin
remote corruption
rollback attempt
OAuth expiry
permission revocation
```

---

# 25. Property-Based Merge Testing

The merge engine should be stress-tested with generated mutation sequences.

Properties to test where semantics permit:

```text
idempotence
convergence
non-resurrection after deletion
stable event identity
monotonic generation/checkpoint behavior
```

Where commutativity/associativity is not mathematically valid for a mutation class, the intended ordering must be specified and tested instead.

---

# 26. Fault Injection

Fault injection is mandatory for release-critical infrastructure.

Inject failures at:

```text
Before SQLite commit
After SQLite commit
During serialization
During encryption
Before upload
After upload
Before manifest publish
After manifest publish
During download
During decryption
During merge
During update installation
```

Expected principle:

```text
Crash → restart → converge without silent data loss.
```

---

# 27. Tracker Crash Recovery

Test the tracker process being terminated:

- During idle.
- During observation processing.
- During persistence.
- During shutdown.
- During browser reconciliation.

Expected:

- Valid committed history remains intact.
- A tracking gap is recorded when appropriate.
- The next runtime starts cleanly.
- No phantom usage is fabricated.

---

# 28. Desktop UI Crash Recovery

The UI may crash without affecting the tracker.

After restart:

```text
Tracker continues or has already restarted.
UI reconnects.
Current state becomes visible.
No duplicated tracking data is created.
```

---

# 29. Installer Crash Recovery

Interrupted installation/update must not leave the application in a state where:

- Tracker binary is missing.
- Database is unintentionally deleted.
- Configuration is lost.
- The application launches an incompatible component set.

The release mechanism must preserve a recoverable previous installation during upgrades where supported by the chosen packaging/update technology.

---

# 30. Long-Running Endurance Test

A release candidate should undergo an endurance run.

Recommended initial test:

```text
7 days minimum for pre-release
30 days for major releases
```

During the run:

- Use multiple applications.
- Switch frequently.
- Use browsers.
- Lock/unlock.
- Sleep/resume.
- Connect/disconnect displays.
- Restart the UI.
- Restart the tracker where safe.
- Simulate network loss when sync is enabled.

Measure:

```text
CPU trend
RAM trend
DB growth
queue growth
error count
tracking gaps
crashes
```

A monotonic memory-growth trend without explanation is a release blocker until understood.

---

# 31. Memory-Leak Testing

Particular attention should be paid to:

- Repeated window changes.
- Browser tab changes.
- Window-title updates.
- Display topology changes.
- UI navigation.
- Timeline zooming.
- Sync retry loops.
- Repeated encryption operations.

Record memory after controlled workloads rather than relying solely on visual inspection.

---

# 32. Resource-Wakeup Testing

The background tracker should not poll aggressively.

Measure event-loop/wakeup behavior in:

```text
Idle desktop
Locked workstation
No active changes
Browser closed
After midnight
During sleep/resume
```

Unexpected high-frequency wakeups are performance bugs.

---

# 33. Disk Write Testing

Measure:

- Writes per minute at idle.
- Writes per minute during normal use.
- Average batch size.
- Transaction frequency.
- Database growth per day.

The tracker should coalesce observations rather than issuing one transaction per event.

---

# 34. Network Testing

For local tracking:

```text
Expected network activity: 0
```

A test environment should be able to run the tracker with outbound network blocked.

For sync-enabled tests, capture:

- Destination domains.
- Bytes sent/received.
- Request counts.
- Retry counts.

Unexpected third-party network activity is a release blocker.

---

# 35. Privacy Regression Testing

CI must assert:

```text
No telemetry endpoint configured.
No usage events sent to developer infrastructure.
Tracker has no normal network dependency.
Private browser fields are not persisted.
Private browser fields are not synced.
Raw domains/titles are absent from production logs.
OAuth tokens are absent from usage DB.
Keys are absent from application logs.
```

Where feasible, architecture tests should enforce dependency boundaries at compile/build time.

---

# 36. Security Regression Testing

Security gates must include:

- Static analysis.
- Dependency vulnerability scanning.
- Secret scanning.
- Authenticated-encryption tests.
- Tamper tests.
- Replay/rollback tests.
- IPC authorization tests.
- Safe deserialization tests.
- Browser extension permission review.
- Installer/update signature validation.

Security tooling must be version-pinned or otherwise reproducible in CI.

---

# 37. Fuzz Testing

Fuzz targets should include:

```text
sync envelope parser
sync manifest parser
browser bridge messages
window/application identity normalization
SQLite import/export formats
configuration input
user classification rules
```

The expected result of malformed data is graceful rejection rather than process corruption.

---

# 38. IPC Testing

Named-pipe tests must cover:

- Unauthorized client connection.
- Malformed messages.
- Oversized messages.
- Version mismatch.
- Connection loss.
- Tracker restart.
- UI restart.
- Request timeout.
- Message replay where relevant.

No malformed IPC message should crash the tracker.

---

# 39. Browser Adapter Contract Testing

Every adapter must satisfy a shared contract suite.

For each browser:

```text
start
connect
heartbeat
active-tab update
private-state handling
disconnect
reconnect
unsupported state
upgrade
```

Browser-specific behavior belongs in adapter-specific tests; common invariants belong in the contract suite.

---

# 40. Accessibility QA

The desktop UI must support:

- Keyboard navigation.
- Visible focus.
- Logical tab order.
- Screen reader labels.
- High-contrast/appropriate Windows accessibility behavior.
- Sufficient semantic distinction without relying exclusively on color.
- Reduced-motion preferences.
- Text scaling without destructive layout breakage.

Charts must provide textual/accessible equivalents for important values.

Accessibility regressions that make core navigation unusable are release blockers.

---

# 41. Visual Regression Testing

The design system from Document 04 should have reference screenshots for:

```text
Overview
Timeline
Application detail
Browser detail
Categories
Reports
Settings
Privacy state
Sync states
Error states
Empty states
```

Visual regression tests should detect:

- Accidental spacing changes.
- Broken typography hierarchy.
- Clipped content.
- Incorrect dark-mode rendering.
- Misaligned charts.
- Responsive/layout failures.

Screenshots must not contain real user usage history.

Use deterministic fixture data.

---

# 42. UI Responsiveness Testing

Measure interaction latency for:

- Navigation.
- Time-range changes.
- Timeline zoom.
- App selection.
- Filter changes.
- Report rendering.
- Search.
- Settings changes.

The UI must not run expensive whole-database queries on the UI thread.

---

# 43. Timeline Scalability

The timeline is a signature surface and must scale from:

```text
One day
→ one week
→ one month
→ many months
→ multiple years
```

Rendering strategy should use semantic zoom and aggregation rather than attempting to render every raw event simultaneously.

Large datasets must remain navigable.

---

# 44. Analytics Scalability

Benchmark analytics against synthetic histories such as:

```text
30 days
180 days
365 days
3 years
5 years
```

At each scale measure:

- Query latency.
- Memory consumption.
- Aggregation rebuild time.
- Initial screen render time.

The system should remain responsive as history grows.

---

# 45. Database Migration Testing

Every schema migration must have:

```text
Fresh install test
N-1 → N
N-2 → N where supported
Interrupted migration test
Rollback/recovery strategy
Large database test
```

A migration must never silently destroy usage history.

---

# 46. Data Backup Before Destructive Migration

Before migrations that alter or rewrite user history, the application should create/verify a recoverable safety point where practical.

The exact mechanism is governed by Documents 07, 10, and 11.

The application must never depend on the cloud sync copy as the only migration safety mechanism.

---

# 47. Release Build Reproducibility

Build inputs should be reproducible enough to establish what was shipped.

Record:

- Source commit SHA.
- Version number.
- Build configuration.
- .NET/Windows App SDK versions.
- Installer version.
- Browser extension versions.
- Schema/protocol/crypto versions.
- Dependency lock state.

Binary provenance should be retained for every release.

---

# 48. CI Pipeline

Recommended pipeline:

```text
Commit
 ↓
Format/lint
 ↓
Static analysis
 ↓
Unit tests
 ↓
Integration tests
 ↓
Privacy/security tests
 ↓
Fuzz/sanitized test subset
 ↓
Build
 ↓
Packaging validation
 ↓
Performance smoke tests
 ↓
Artifact signing
 ↓
Release candidate
```

Long endurance/performance suites may run on scheduled hardware agents rather than every commit, but must gate release candidates.

---

# 49. CI Test Layers

## Layer 1 — Fast

- Unit tests.
- Pure Core tests.
- Schema/serialization tests.
- Static architecture checks.

## Layer 2 — Integration

- SQLite.
- Windows APIs.
- IPC.
- Browser adapters.
- Sync fake remote.

## Layer 3 — System

- Full tracker + UI.
- Installer.
- Update.
- Multi-process lifecycle.

## Layer 4 — Endurance/performance

- Long-running tracking.
- Large histories.
- Multi-device sync.
- Low-end hardware.

---

# 50. Test Data Policy

Test datasets must be synthetic.

Never use real:

- Window titles.
- Browser history.
- Personal file paths.
- User accounts.
- OAuth credentials.
- Production usage history.

CI artifacts containing usage-like data should be scrubbed and disposable.

---

# 51. Secrets Management in CI

CI must not embed:

- Google production refresh tokens.
- Encryption keys.
- Signing private keys in source.
- Real user datasets.

Use the CI platform's secret facility for release credentials and isolate signing steps.

Development/test crypto keys must be generated specifically for tests.

---

# 52. Packaging Strategy

The product targets two principal distribution paths:

```text
Microsoft Store
Standalone installer
```

The packaging mechanism must preserve the same core local-data model.

Packaging-specific behavior should be isolated from Core/Tracking/Data.

The standalone package should support automatic updates without requiring the user to manage binaries manually.

---

# 53. Installer Requirements

Installer must:

- Detect supported Windows versions.
- Install required runtime components.
- Preserve user data across upgrades.
- Create/unregister startup behavior correctly.
- Cleanly uninstall binaries without silently deleting user history.
- Provide clear data-retention/deletion semantics during uninstall.
- Support repair/reinstall where feasible.

Uninstallation must not be conflated with “delete all history.”

---

# 54. Startup Behavior

The background tracker should start reliably with the user session according to the selected distribution mechanism.

Test:

- Fresh boot.
- User logon.
- Fast user switching where supported.
- Sleep/resume.
- Explorer restart.
- UI not launched.

Startup failure should not silently look like successful tracking.

---

# 55. Update Strategy

Updates must preserve:

```text
Database
Configuration
Encryption keys
Device identity
Sync state
```

The tracker/UI/version compatibility matrix must be defined for each release.

A component update must not leave incompatible protocol versions running simultaneously.

---

# 56. Update Rollback

For major releases, the update mechanism should have a supported rollback/recovery story.

At minimum test:

```text
update success
update interrupted
update process terminated
reboot during update
new version launch failure
```

The user must not lose local history because an application binary failed to update.

---

# 57. Application Versioning

Use explicit version components:

```text
ProductVersion
SchemaVersion
SyncProtocolVersion
CryptoVersion
BrowserExtensionProtocolVersion
```

They should not be overloaded into one opaque number.

---

# 58. Release Channels

Recommended:

```text
Nightly / internal
↓
Canary
↓
Beta
↓
Stable
```

Major changes to:

- tracking behavior
- browser permissions
- privacy behavior
- sync
- cryptography

should spend time in pre-stable channels.

---

# 59. Canary Monitoring

Canary builds may collect local diagnostic health metrics only when explicitly configured for development/testing.

Public product builds must retain the zero-behavioral-telemetry policy.

Canary release evaluation should focus on:

- Crash rate if locally measurable.
- Tracking gaps.
- Browser adapter failures.
- CPU/RAM regression.
- Migration failures.
- Sync convergence.

---

# 60. Release Notes

Every release should summarize changes in user-relevant terms.

Security/privacy-sensitive changes must be explicitly identified.

Examples:

```text
Improved tracking after sleep/resume.

Added Firefox browser detail support.

Changed page-title storage controls.

Improved sync recovery after interrupted uploads.
```

Do not describe new collection as a generic “analytics improvement.”

---

# 61. Privacy Release Gate

Before release, verify:

```text
No new telemetry
unless explicitly approved.

No new data field
without data-inventory update.

No new browser permission
without privacy review.

No new network destination
without architecture/security review.
```

This should be part of the release checklist rather than an informal convention.

---

# 62. Security Release Gate

Before release:

- Dependency scan passes.
- Secret scan passes.
- Signing succeeds.
- Installer integrity verified.
- Crypto tests pass.
- IPC authorization tests pass.
- Fuzz smoke tests pass.
- No known release-blocking security issue remains.

Critical/high findings require explicit disposition by the release owner.

---

# 63. Data Migration Release Gate

Before release containing schema/data migration:

```text
Fresh DB migration → pass
Existing representative DB → pass
Large DB → pass
Interrupted migration → pass
Rollback/recovery → pass
Post-migration analytics → match expected values
```

A release cannot ship with an untested destructive migration.

---

# 64. Performance Release Gate

Stable release must satisfy reference benchmarks within agreed tolerances.

Mandatory checks:

```text
Tracker idle CPU
Tracker active CPU
Tracker RAM
Disk write rate
Wakeups
UI responsiveness
Timeline performance
Large-history analytics
Sync performance if enabled
```

A regression may be accepted only with an explicit documented rationale.

---

# 65. Accuracy Release Gate

The release must pass:

- Foreground timing tests.
- Visible-time tests.
- Lifecycle tests.
- Multi-monitor tests.
- Browser contract tests.
- Sessionization fixtures.
- Timekeeping tests.
- Historical correction tests.

The project should track a measurable accuracy error budget instead of relying on subjective confidence.

---

# 66. Release Blockers

The following are presumed release blockers until explicitly resolved:

- Corruption or loss of local usage history.
- Private browser detail leakage.
- Unexpected behavioral telemetry.
- Credential/key leakage.
- Silent deletion/resurrection bug.
- Tracker consistently exceeding CPU target.
- Unbounded memory growth.
- Tracking disabled by offline state.
- Update that can destroy local history.
- Critical security vulnerability.
- Installer that leaves incompatible components running.

---

# 67. Severity Model

Use a simple release-oriented classification:

### P0 — Catastrophic

Data loss, key compromise, private-data exposure, arbitrary code execution, update-induced corruption.

### P1 — Critical

Major tracking loss, persistent crash loop, sync corruption, severe performance regression.

### P2 — High

Important feature broken for a supported configuration, significant UX/accessibility problem.

### P3 — Normal

Non-critical defect with workaround.

### P4 — Cosmetic

Minor visual/documentation issue.

P0/P1 issues generally block stable release.

---

# 68. Support Diagnostics

When a user submits diagnostics, support tooling should use sanitized packages defined by Document 09.

A diagnostic package may include:

```text
Version
OS build
Architecture
Component health
Sanitized exception details
Performance counters
Sync state
Browser adapter status
```

It should exclude usage history by default.

---

# 69. Reproduction Bundles

For hard-to-reproduce technical bugs, create synthetic reproduction bundles containing:

- Sanitized configuration.
- Synthetic observation fixture.
- Component versions.
- Failure timeline.
- Diagnostic event sequence.

Avoid asking users to upload their complete usage database merely to reproduce a generic bug.

---

# 70. Recovery Runbook

The engineering team must maintain recovery procedures for:

```text
Tracker won't start
Database corruption
Failed migration
Sync divergence
Stuck outbox
Broken browser bridge
Update failure
Account disconnect
Encryption-key recovery failure
```

Runbooks should prefer non-destructive operations first.

---

# 71. Disaster Recovery Principles

The product should always preserve the user's best available local copy.

For recovery:

```text
Preserve
→ copy
→ validate
→ diagnose
→ repair
→ only then replace
```

Avoid:

```text
Delete
→ reinstall
→ hope sync restores it
```

---

# 72. Release Artifact Set

A release should produce:

```text
Desktop application package
Installer / Store package
Browser extension packages
Symbols where appropriate
Release metadata
Checksums
SBOM or dependency manifest where practical
Migration/version notes
```

Sensitive signing material must never be included in the artifact set.

---

# 73. Supply-Chain Security

The build should minimize untrusted dependencies.

Requirements:

- Pin versions where practical.
- Review new dependencies.
- Prefer maintained, well-understood libraries.
- Scan for known vulnerabilities.
- Keep a software bill of materials where practical.
- Reproduce release builds sufficiently to detect unexpected source/toolchain changes.

---

# 74. Automatic Update Safety

An update is allowed to change code, but must not silently change the privacy contract.

When a release introduces a new collection category, browser permission, cloud-processing feature, or other privacy-significant behavior, the product must follow Document 09 disclosure/consent requirements.

Security fixes may be applied through normal automatic update mechanisms when necessary to protect users.

---

# 75. Windows Compatibility Matrix

Each stable release must record support/test status for:

```text
Windows 10 supported baseline
Windows 11 supported baseline
x64
ARM64 if/when officially supported
```

The build system must reject unsupported configurations clearly.

The project should maintain an explicit minimum Windows version rather than relying on accidental compatibility.

---

# 76. Store vs. Standalone Parity

Where possible, Microsoft Store and standalone builds should share:

- Core code.
- Data schema.
- Tracking engine.
- Browser integrations.
- Security model.
- Privacy behavior.

Packaging-specific differences must be documented.

A user switching distribution channels should not unexpectedly lose local history.

---

# 77. Uninstall Semantics

The uninstall flow must clearly distinguish:

```text
Remove application

from

Delete local usage history
```

Default expectation:

```text
Uninstall → application binaries removed
History preserved unless user explicitly deletes it.
```

This behavior should be validated for both Store and standalone distribution.

---

# 78. Test Environment Isolation

Windows integration tests can interact with real OS state.

Therefore:

- Use isolated test accounts/VMs where possible.
- Use synthetic application fixtures.
- Do not run destructive lifecycle tests on developer machines without safeguards.
- Clean up test-created windows/processes.
- Avoid registering permanent startup behavior in ordinary CI hosts.

---

# 79. Virtual Machine Testing

VMs are useful for:

- Clean installs.
- Upgrade paths.
- Uninstall/reinstall.
- Windows version coverage.
- Failure injection.
- Reproducible system states.

Performance results from VMs should not be treated as equivalent to bare-metal results.

---

# 80. Golden Dataset

Maintain a versioned synthetic golden dataset containing:

```text
Applications
Windows
Browser domains/titles
Intervals
Sessions
Categories
Productivity classifications
Corrections
Tracking gaps
Device transitions
```

Every significant analytics/data-model change should be run against this dataset.

Expected outputs should be versioned along with algorithm versions.

---

# 81. Accuracy Metrics

Recommended metrics:

```text
Foreground duration absolute error
Foreground duration relative error
Visible duration absolute error
Transition detection recall
Transition false-positive rate
Gap detection accuracy
Browser domain attribution accuracy
Session boundary accuracy
```

Set numerical thresholds after initial measurement rather than inventing arbitrary precision requirements without baseline data.

---

# 82. Browser Attribution Accuracy

For each supported browser:

```text
Known active tab
+ known foreground browser window
→ expected domain
```

Measure:

- Correct attribution rate.
- Unknown attribution rate.
- Incorrect cross-tab attribution.
- Private-detail leakage rate.

A privacy leak has a zero-tolerance threshold even if aggregate attribution accuracy is high.

---

# 83. Resource Regression Tracking

Maintain historical benchmark results in a local/repository performance dataset.

Track changes over releases:

```text
CPU
RAM
Disk writes
Wakeups
Startup time
Timeline latency
Sync throughput
```

A regression budget should be defined so small noise does not create false alarms while meaningful degradation is caught early.

---

# 84. Performance Test Reproducibility

Performance tests must record:

- Hardware.
- Windows build.
- Power mode where relevant.
- Background workload.
- Dataset size.
- Build SHA.
- Test duration.
- Measurement tool/version.

Do not compare results from materially different environments without labeling them.

---

# 85. Manual QA Checklist

Each release candidate should include manual verification of:

```text
Fresh install
First-run privacy explanation
Tracker startup
Overview
Timeline
Application details
Browser details
Category editing
Reports
Privacy settings
Data export
Data deletion
Google sign-in
Sync enable/disable
Device management
Update
Uninstall
```

The manual flow should use only synthetic test data.

---

# 86. First-Run Trust Review

Before stable release, review the first-run experience specifically for privacy clarity.

The user should understand:

- What the app tracks.
- What it does not track.
- Where data is stored.
- That telemetry is off by default.
- What browser/private-mode behavior means.
- What Google sign-in does.
- That sync is separate and opt-in.

Trust messaging is part of QA, not merely marketing.

---

# 87. Release Checklist

A release candidate is ready for final review only when:

```text
☐ Tests pass
☐ Security gates pass
☐ Privacy gates pass
☐ Accuracy gates pass
☐ Performance gates pass
☐ Migration tests pass
☐ Installer/update tests pass
☐ Store/standalone packages validated
☐ Release notes complete
☐ Artifact provenance recorded
☐ No unresolved P0/P1 issue
```

---

# 88. Go / No-Go Decision

The release owner evaluates four dimensions:

```text
Correctness
Privacy/Security
Performance
Distribution safety
```

A release is **GO** only if all release-critical blockers are resolved or explicitly accepted by the designated owner.

A strong feature set does not compensate for privacy/security or data-integrity failure.

---

# 89. Hard Invariants

1. Tracker performance budgets are measurable, not aspirational.
2. Tracking accuracy is tested with independent ground truth.
3. Local history is never sacrificed to make an update succeed.
4. Tracker failure does not depend on UI availability.
5. Sync failure does not stop tracking.
6. Offline operation is tested explicitly.
7. Private browser detail has zero-tolerance leakage requirements.
8. Behavioral telemetry remains disabled by default.
9. No release may add a new sensitive collection path without privacy review.
10. Production logs remain privacy-minimized.
11. Migrations are tested on representative existing data.
12. Update interruption must have a recovery path.
13. Uninstall does not silently mean data deletion.
14. Remote sync is never the only recovery copy relied upon by migration.
15. Test data is synthetic.
16. Release artifacts have traceable source/build provenance.
17. Critical security issues block stable releases.
18. Unbounded memory growth blocks release until explained/resolved.
19. Unexpected tracker network activity blocks release.
20. Release candidates must pass both Windows 10 and Windows 11 coverage appropriate to the support baseline.

---

# 90. Implementation Order

Recommended sequence:

### Phase 1 — Test foundation

- Test project structure.
- Deterministic clock abstractions.
- Synthetic datasets.
- Fake Windows/browser observation providers.
- Golden dataset.

### Phase 2 — Core correctness

- Interval tests.
- Session tests.
- Identity tests.
- SQLite integrity tests.
- Replay engine.

### Phase 3 — Windows integration

- Ground-truth harness.
- Lifecycle tests.
- Multi-monitor tests.
- Process/window identity tests.

### Phase 4 — Browser integration

- Contract tests.
- Privacy tests.
- Browser-specific integration suite.

### Phase 5 — Security/privacy gates

- IPC tests.
- Secret scanning.
- Privacy architecture tests.
- Crypto/sync tests.

### Phase 6 — Performance engineering

- Performance instrumentation.
- Resource benchmark harness.
- Large-history datasets.
- Endurance suite.

### Phase 7 — Packaging/release

- Installer tests.
- Upgrade tests.
- Rollback/recovery tests.
- Store validation.
- Release provenance/signing.

Do not wait until the first release to begin measuring tracker overhead.

---

# 91. Definition of Done for Document 12

Document 12 is implemented when:

- CI runs unit, integration, security, privacy, and architecture tests.
- Synthetic golden datasets validate analytics/data correctness.
- Windows tracking has an independent ground-truth harness.
- Browser adapters use a shared contract suite.
- Private/incognito privacy behavior is regression-tested.
- Database migrations are automatically tested.
- Fault injection covers critical persistence/sync/update boundaries.
- Performance benchmarks measure CPU, RAM, disk writes, wakeups, and latency.
- Long-running endurance tests exist.
- Installer and update interruption/recovery are tested.
- Microsoft Store and standalone packaging are validated.
- Release artifacts have traceable provenance.
- Stable releases use explicit privacy/security/performance/accuracy gates.
- P0/P1 issues block release by default.
- The release checklist is executable by a team member rather than existing only as tribal knowledge.

This completes the core specification sequence. Supporting ADRs, schemas, test fixtures, and implementation plans should now be created from Documents 01–12 before substantial product implementation begins.