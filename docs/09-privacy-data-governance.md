# Privacy & Data Governance Specification

**Product:** PC Usage Intelligence  
**Document:** 09 — Privacy & Data Governance Specification  
**Status:** Authoritative privacy/data-governance baseline — Pre-development  
**Parent documents:** `docs/01-product-requirements.md` through `docs/08-browser-activity-acquisition.md`  
**Platform:** Windows 10 and Windows 11  
**Last updated:** 2026-09-02

---

# 1. Purpose

PC Usage Intelligence records unusually sensitive information: what applications a person uses, when they use them, and potentially which websites they visit.

This document defines the privacy contract for that data.

The product's privacy model is deliberately stronger than “we don't sell data.” The default architecture is:

```text
Collect locally
      ↓
Store locally
      ↓
Analyze locally
      ↓
Sync only if user enables it
      ↓
Encrypt before leaving device
```

The product should require a compelling, explicit reason before introducing any collection or transmission outside the local device.

This document defines:

- Data categories.
- Collection boundaries.
- Purpose limitation.
- Local/cloud boundaries.
- Telemetry policy.
- Diagnostics.
- Browser/privacy controls.
- Retention.
- Deletion.
- Export.
- Consent and disclosure UX.
- Data-subject/user controls.
- Privacy-preserving defaults.
- Governance requirements for future features.

It is a product/engineering specification, not legal advice or a complete jurisdiction-specific privacy notice.

---

# 2. Normative Language

- **MUST** — required.
- **MUST NOT** — prohibited.
- **SHOULD** — strong default.
- **MAY** — optional.

Where this document says “user,” it refers to the person whose activity history is being recorded unless a different role is explicitly stated.

---

# 3. Privacy Position

The product should communicate a simple promise:

> Your usage history belongs to you. The app records it locally to provide the product. Nothing is sent to us by default.

That promise must be technically enforceable.

The application MUST NOT depend on a backend to perform ordinary tracking, timeline rendering, analytics, classification, or data correction.

The absence of telemetry is an architectural property, not merely a settings checkbox.

---

# 4. Privacy Principles

## 4.1 Local-first

Detailed usage history remains on the user's device unless the user explicitly enables synchronization/export.

## 4.2 Data minimization

Collect the smallest amount of information needed to provide the requested feature.

For example:

```text
Needed for application tracking:
application identity + timing

Not needed:
keyboard contents
clipboard contents
screenshots
```

## 4.3 Purpose limitation

A collected field must have a documented product purpose.

## 4.4 User control

Users can inspect, correct, export, and delete their history.

## 4.5 Privacy by default

The initial configuration should minimize external disclosure and unnecessary high-resolution collection.

## 4.6 Fail closed

When privacy-sensitive state cannot be established confidently, the system must prefer collecting less information rather than more.

## 4.7 No hidden secondary use

Usage history must not be silently reused for advertising, profiling unrelated to the product, selling data, or training external models.

## 4.8 Transparent degradation

If privacy permissions or browser capabilities prevent a signal from being collected, the product should say that the data is unavailable rather than infer it.

---

# 5. Data Classification

All collected data belongs to an explicit classification tier.

| Tier | Examples | Default storage | Default external transmission |
|---|---|---|---|
| A — Operational | app version, schema version, local state | Local | None |
| B — Usage metadata | app/process/window timing | Local | None |
| C — Sensitive usage | window titles, domains, page titles | Local | None |
| D — Security material | encryption keys, OAuth tokens | Protected local storage | Only required protocol endpoints |
| E — Diagnostics | crash metadata, sanitized stack traces | Local | Off by default |
| F — Account/sync metadata | account identity, sync state | Local/protected | Only when user enables account/sync |

The highest-risk fields in this product are generally Tier C usage data.

---

# 6. Data Inventory

The implementation must maintain a machine-readable or documented data inventory covering every persisted field.

At minimum:

| Data | Purpose | Sensitivity | Local by default | Cloud when sync enabled |
|---|---|---|---:|---:|
| Application identity | Usage analytics | Medium | Yes | Encrypted |
| Process executable/path | Identity resolution | Medium/High | Yes | Encrypted if required |
| Window title | High-resolution timeline | High | Yes | Encrypted |
| Foreground interval | Usage analytics | High | Yes | Encrypted |
| Visible interval | Usage analytics | High | Yes | Encrypted |
| Domain | Browser analytics | High | Yes | Encrypted |
| Page title | Browser detail | Very high | Yes | Encrypted if user chooses sync |
| Private-browser domain/title | Prohibited by default | Very high | No | No |
| Category | Analytics | Medium | Yes | Encrypted |
| Productivity/leisure classification | Analytics | Medium/High | Yes | Encrypted |
| Device ID | Provenance/sync | Medium | Yes | Encrypted/metadata as required |
| Crash diagnostics | Reliability | Potentially sensitive | Local | Only explicit opt-in |
| OAuth credentials | Authentication | Critical | Protected local storage | Never stored in usage dataset |

The inventory must be updated when a new persisted field is introduced.

---

# 7. Collection Boundary

## 7.1 Explicitly collected in V1

### Windows

- Foreground window identity.
- Process identity required for canonical application resolution.
- Window title when enabled by product policy.
- Window visibility/minimized/cloaked state.
- Monitor/display association.
- Session/lifecycle state.
- Timing and state transitions.

### Browser

- Browser type.
- Browser window/tab state needed for correlation.
- Domain.
- Page title when enabled.
- Private/incognito state where available.

### Product state

- User classifications.
- Configuration.
- Retention preferences.
- Sync configuration.
- Version information.

## 7.2 Explicitly out of scope

The product MUST NOT collect for normal V1 tracking:

- Keyboard contents.
- Keystroke logging.
- Clipboard contents.
- Screenshots.
- Webcam/microphone recordings.
- Passwords.
- Cookies.
- Authentication tokens.
- Form contents.
- Browser network request bodies.
- Page DOM/content.
- File contents.
- Email/message bodies.
- Personal documents.
- Location/GPS data.

A future feature requiring any of these categories requires a new privacy review and explicit product decision.

---

# 8. Window Title Policy

Window titles can contain sensitive information such as:

```text
Document names
Conversation names
Ticket titles
Repository names
Personal identifiers
```

Therefore page/window titles are a separate privacy setting from basic application tracking.

V1 default:

```text
Application tracking: ON
Window titles: ON
Page titles: ON
```

Users can independently disable high-resolution titles.

When disabled:

- New titles are not persisted.
- The tracker does not transmit them.
- In-memory cached values are cleared promptly where practical.
- Analytics remain functional using application/domain identities.

Historical deletion semantics are covered in Section 18.

---

# 9. Browser Domain Policy

Domain tracking is enabled when browser integration is enabled.

Domain data is sensitive because it can reveal interests, work activity, health research, financial activity, relationships, or other personal behavior.

Therefore:

- Domain data is local by default.
- Domain data is never sent as product telemetry.
- Sync sends domain data only inside the user's encrypted sync dataset.
- Diagnostics must not include raw domains by default.

---

# 10. Page Title Policy

Page titles are higher-resolution browser metadata.

V1:

```text
Enabled by default
User-configurable
Stored locally
Never sent as telemetry
Included in cloud sync only as encrypted user data when sync is enabled
```

The product should make the distinction clear:

```text
Domain tracking
→ broad browser usage identity

Page-title tracking
→ more detailed browser history
```

This gives users a meaningful privacy choice rather than a binary “browser tracking” switch.

---

# 11. Private / Incognito Browsing

Private browsing receives the strongest protection.

Default rule:

```text
Track browser application time: Yes
Track private domain: No
Track private page title: No
Store reconstructed private identity: No
```

If private state cannot be confidently determined:

```text
Fail closed.
```

The system MUST NOT infer a private domain from:

- Window title.
- Previous public tab state.
- Browser history.
- URL fragments retained elsewhere.
- Similar public tabs.

Private-mode rules apply equally to local storage and cloud sync.

No private browser identity may enter the sync dataset merely because a bug or fallback path bypassed the normal UI setting.

---

# 12. Data Processing Purposes

Every processing path must map to a documented purpose.

Allowed V1 purposes:

1. Usage timeline reconstruction.
2. Application/browser analytics.
3. Category/productivity classification.
4. User-configured historical corrections.
5. Reports and comparisons.
6. Local diagnostics when explicitly enabled.
7. Encrypted user-requested synchronization.
8. User-requested export.
9. Security and integrity of the application itself.

Prohibited secondary purposes without a new product/privacy decision:

- Advertising.
- Selling usage data.
- Cross-service behavioral profiling.
- Data brokerage.
- Training third-party models on user history.
- Ranking users against other users.
- Inferring sensitive personal characteristics unrelated to requested analytics.

---

# 13. Telemetry Policy

## 13.1 Default

**Zero behavioral telemetry.**

The application must not send usage analytics to the developer/company by default.

That includes:

- App usage duration.
- Domains.
- Page titles.
- Window titles.
- Productivity/leisure statistics.
- User classifications.
- Timeline contents.

## 13.2 No “anonymous analytics” loophole

The product should not silently transmit a supposedly anonymous event such as:

```text
user_spent_4h_in_chrome
```

because this still constitutes behavioral telemetry.

## 13.3 Network architecture

The tracking runtime should have no network dependency.

A normal tracking installation can operate with networking unavailable.

The product should make it technically difficult for future code to accidentally add network calls to the tracker process.

---

# 14. Diagnostics

Diagnostics are different from behavioral telemetry.

They exist to troubleshoot application failures rather than analyze user behavior.

## 14.1 Default

Crash/diagnostic reporting is **off by default** unless a future distribution/platform requirement makes a narrowly defined mechanism unavoidable.

If enabled, it must be explicit and clearly disclosed.

## 14.2 Allowed diagnostic information

A future opt-in diagnostic package may include:

- Application version.
- OS version/build.
- CPU architecture.
- Exception type.
- Sanitized stack trace.
- Module/version information.
- Tracker state machine state.
- Performance counters.
- Adapter health.
- Schema version.

## 14.3 Prohibited diagnostic payloads by default

Diagnostics MUST scrub or exclude:

- Window titles.
- Browser URLs.
- Domains.
- Page titles.
- File paths containing user names where practical.
- Usage history.
- Authentication tokens.
- OAuth credentials.
- Database contents.
- Arbitrary environment variables.

A crash dump can contain more information than the developer expects; dump collection must therefore be explicitly designed and documented rather than blindly uploaded.

## 14.4 Diagnostic preview

If practical, the UI should show the user a summary of what a diagnostic report contains before opt-in submission.

---

# 15. Product Analytics vs. Product Telemetry

These terms must remain distinct in code and documentation.

```text
Product analytics:
“What did the user do on their own PC?”
→ local-only by default.

Product telemetry:
“What did our users do?”
→ disabled by default.
```

The local analytics engine is a core product feature.

The telemetry pipeline is intentionally absent from the default architecture.

---

# 16. Account and Google Sign-In

Google account integration is optional.

Its purposes are:

- User identity for sync.
- Account recovery/migration where supported.
- Authorization to access the user's Google Drive.

Signing into Google MUST NOT automatically enable cloud synchronization of usage history.

The UI should clearly separate:

```text
Signed in

from

Usage history sync enabled
```

OAuth access tokens must be stored using an appropriate protected Windows credential/token mechanism and must never be placed in the usage SQLite tables or logs.

---

# 17. Cloud Data Boundary

When sync is enabled:

```text
Local plaintext usage data
        ↓
Client-side encryption
        ↓
Ciphertext
        ↓
User's Google Drive
```

The service/provider should not receive plaintext usage history.

Google Drive is storage, not the product's analytics authority.

The exact cryptographic architecture is defined by Document 10.

The product must disclose that encrypted sync data exists in the user's Drive while preserving the distinction between:

```text
Google identity/authentication

and

Usage-data encryption keys
```

The Google account is not itself the encryption key.

---

# 18. Retention

Retention is a privacy control as well as a storage control.

## 18.1 Default

Use sensible defaults that retain enough history to make the product valuable while avoiding indefinite high-resolution accumulation without user awareness.

Initial engineering candidate from Document 07:

```text
Raw high-resolution observations: 90 days
Detailed intervals: long-term
Daily/weekly/monthly aggregates: long-term
```

This is a provisional implementation value and must be validated through storage experiments.

## 18.2 User control

Advanced settings should allow the user to configure retention within safe implementation bounds.

The product must explain what is affected:

```text
Raw detail
Timeline detail
Aggregates
Browser page titles
```

## 18.3 No silent destructive downgrade

Changing retention settings must not silently destroy data without communicating the consequence.

---

# 19. Deletion

Deletion is a first-class privacy operation.

Supported scopes should include:

```text
Delete selected time range
Delete browser detail
Delete window/page titles
Delete all local usage history
Delete synced usage history
Disconnect account
```

## 19.1 Selected range

The user should be able to select a time range and remove its usage data.

Derived aggregates intersecting that range must be invalidated/rebuilt.

## 19.2 Delete titles only

Users can remove high-resolution titles while preserving lower-resolution application/domain analytics where appropriate.

## 19.3 Delete all history

A complete history deletion operation must remove local usage records and derived data covered by the operation.

If encrypted sync is enabled, deletion must propagate through the sync system using the deletion/tombstone mechanism specified in Documents 10 and 11.

## 19.4 Deletion must be idempotent

Repeating a deletion must not resurrect or corrupt data.

---

# 20. Retention and Deletion of Backups

Local backups can accidentally defeat deletion guarantees.

Therefore backup retention must be explicitly governed.

If the product creates automatic local backups:

- Their contents are subject to the same privacy classification.
- They must have a defined retention period.
- A “delete all history” operation must account for them.
- Backup files must not be silently excluded from user-facing deletion semantics.

The exact backup mechanism is a later implementation decision.

---

# 21. Export

Users should be able to export their own data.

Supported conceptual exports:

```text
CSV → analytical history
JSON → structured history
Encrypted archive → complete migration/sync backup
```

Exports should clearly state:

- Time range.
- Data categories included.
- Whether titles/domains are included.
- Whether classification rules are included.
- Whether private data is excluded.

Export files are sensitive and should be created in a user-visible location with appropriate warnings.

---

# 22. Privacy Settings Model

Recommended settings hierarchy:

### Tracking

```text
Application tracking        ON/OFF
Browser tracking            ON/OFF
Window titles               ON/OFF
Page titles                 ON/OFF
```

### Private browsing

```text
Track private browser application time  ON
Store private domain/title               OFF and not user-overridable in V1
```

### Data retention

```text
Raw detail retention
Title retention
Advanced retention controls
```

### Sync

```text
Google account
Usage history sync
Encrypted backup
```

### Diagnostics

```text
Crash reporting             OFF by default
Diagnostic submission      explicit action
```

### Data management

```text
View data
Export data
Delete data
Open data folder
```

---

# 23. Settings Must Reflect Actual Architecture

The UI must never imply stronger privacy than the implementation provides.

For example, a toggle labelled:

```text
Private browsing: Don't track
```

is misleading if the browser application itself is still recorded.

Prefer precise language:

```text
Private browser details
Domains and page titles are not stored.
Browser application time may still be tracked.
```

Similarly:

```text
Diagnostics: Off
```

must actually prevent diagnostic submission.

---

# 24. User Transparency

The product should provide an accessible “What is being recorded?” view.

It should show categories such as:

```text
Applications             ✓
Application timing       ✓
Window titles            ✓
Browser domains          ✓
Page titles              ✓
Private browser details  ✕
Screenshots              ✕
Keystrokes               ✕
Clipboard                ✕
```

This is more useful than a long privacy policy alone.

The user should be able to understand the system without reading technical documentation.

---

# 25. Data Provenance

User-facing analytics should be able to explain unusual data states.

Examples:

```text
Chrome: 2h 14m
Browser detail unavailable: 8m
```

rather than silently reporting a lower domain total.

For sensitive data, provenance can also help users understand:

```text
Recorded locally
Browser permission unavailable
Page title collection disabled
Private browsing detail excluded
Tracking gap
```

---

# 26. Classification and AI Privacy

The product may eventually use local or cloud-assisted ML for classification/insights.

Privacy rules:

## 26.1 Local model

Preferred default:

```text
Local data → local model → local result
```

## 26.2 Cloud model

If cloud inference is ever introduced:

- It requires a separate explicit privacy decision.
- The user must know what data is sent.
- Data minimization must be applied before transmission.
- Cloud processing must not be silently introduced merely because an AI provider is available.
- Sensitive page titles/domains should not be sent by default.

## 26.3 Model training

User usage history MUST NOT be used to train external/general-purpose models without a separate explicit consent and governance process.

---

# 27. Sensitive-Data Inference

The application should avoid turning ordinary usage records into unsupported sensitive conclusions.

For example, seeing time spent on a medical website does not establish a medical condition.

V1 insights should focus on observable usage patterns:

```text
“You spent 2h on example.com.”

not

“You have condition X.”
```

Similarly, productivity/leisure classification is an explicit user-controlled analytical label, not a claim about the user's identity or worth.

---

# 28. Data Access Within the Application

The application itself should enforce least privilege between components.

Recommended:

```text
Tracker
  → can write acquisition data

Analytics engine
  → can read required usage data

UI
  → can request data through repositories

Sync worker
  → can access only the encrypted/export representation it needs

Diagnostics
  → receives sanitized diagnostic state
```

The diagnostics component should not automatically receive the complete usage database.

---

# 29. Local IPC Privacy Boundary

The named-pipe IPC system from Document 05 is a security boundary.

Requirements:

- Restrict the pipe to the current user/security boundary.
- Authenticate the expected desktop client/runtime relationship where appropriate.
- Validate message schemas.
- Do not expose raw usage history through a broad unauthenticated local endpoint.
- Do not permit arbitrary local processes to command the tracker.

---

# 30. Logs

Application logs are a common accidental privacy leak.

Default logging MUST NOT contain:

- Full window titles.
- Full URLs.
- Domains.
- Page titles.
- Usage intervals.
- OAuth tokens.
- Encryption keys.
- User file contents.

Instead log identifiers and sanitized metadata:

```text
Browser adapter disconnected
browser=Chrome
reason=bridge_timeout
```

rather than:

```text
Tab https://private-site.example/user/123 failed
```

Development builds may have richer local diagnostics, but they must still be explicitly enabled and clearly separated from production logging.

---

# 31. Error Reporting

Errors shown to the user should avoid exposing unnecessary sensitive data.

For example:

```text
“Browser detail is temporarily unavailable.”
```

is preferable to displaying a raw URL or internal browser command line.

If an error contains sensitive fields, those fields must be redacted before persistence or display where practical.

---

# 32. Privacy and Updates

Automatic updates must not silently change collection behavior.

If an update introduces:

- A new data category.
- New browser permissions.
- New external transmission.
- New cloud processing.
- New retention behavior.

then the application must surface an appropriate disclosure and, where required, request user consent before activation.

A security update that fixes an existing privacy defect may of course be applied through normal update mechanisms, but the change should be documented.

---

# 33. Browser Extension Privacy

Browser extensions are especially sensitive because browser permissions can grant access to browsing activity.

The extension must:

- Request only necessary permissions.
- Avoid page content access unless explicitly required by a future feature.
- Avoid remote code loading.
- Avoid third-party analytics SDKs.
- Avoid external network calls for tracking.
- Avoid storing browsing data in extension storage unless required.
- Forward only normalized data required by the native application.

The extension must have a privacy disclosure consistent with the desktop application.

---

# 34. Network Egress Policy

The default tracking runtime should have no network role.

Potential network-capable components are limited to:

```text
Google OAuth/account integration
Google Drive sync
Explicit diagnostic submission
Application update mechanism
```

Each must have an explicit purpose and separate implementation boundary.

The usage tracker should not gain network access merely because another application component does.

---

# 35. Offline Behavior

When offline:

```text
Tracking           continues
SQLite persistence continues
Analytics          continues
Classification     continues
Timeline           continues
Reports            continue where data permits
Sync               queues
OAuth              waits
Diagnostics        remain local unless explicitly submitted later
```

Offline operation is therefore a privacy and reliability feature.

---

# 36. Data Residency

The default data residency is the user's local Windows device.

When Google Drive sync is enabled, encrypted user data resides in the user's selected Google Drive account/location according to Google's service behavior.

The application should not maintain a separate hidden usage-data backend.

If a future backend becomes necessary, it requires a new architecture/privacy review.

---

# 37. Access Requests and Internal Support

If the product later has human support staff, support tooling must not provide blanket access to user usage history.

Preferred support model:

```text
User chooses diagnostics
      ↓
Sanitized package
      ↓
User reviews/submits
```

Support personnel should receive only what the user intentionally submits.

There should be no hidden “admin access to customer timelines” mechanism in the normal product architecture.

---

# 38. Security Incident Handling

If a privacy/security incident occurs, the engineering process should preserve:

- Incident timestamp.
- Affected versions.
- Affected data categories.
- Whether data left the device.
- Scope of affected users where knowable.
- Remediation.
- Whether cryptographic keys/data were involved.

Because usage history is sensitive, incident severity should reflect the actual data category rather than treating all telemetry as equivalent.

Legal notification requirements depend on jurisdiction and should be handled separately from this engineering specification.

---

# 39. Governance for New Features

Every new feature that touches user data must answer:

```text
1. What new data is collected?
2. Why is it necessary?
3. Can an existing field satisfy the requirement?
4. Is it stored locally?
5. Is it ever transmitted?
6. Is it encrypted before transmission?
7. What is the retention period?
8. Can the user inspect it?
9. Can the user delete it?
10. Does it affect private browsing?
11. Does it introduce a new permission?
12. Does it change telemetry behavior?
13. Does it change the privacy disclosure?
```

No new sensitive data field should be added merely because it is “useful later.”

---

# 40. Privacy Threat Scenarios

The engineering test plan must include at least these scenarios:

### Scenario A — Malicious local process

A local process attempts to connect to the tracking pipe.

Expected:

```text
Rejected.
```

### Scenario B — Browser extension compromised/misconfigured

Unexpected messages contain malformed or excessive data.

Expected:

```text
Validated/rejected without tracker compromise.
```

### Scenario C — Private tab observed

Browser provides private state.

Expected:

```text
No private domain/title persistence.
```

### Scenario D — Private state unknown

Expected:

```text
Fail closed.
```

### Scenario E — Crash report contains a URL

Expected:

```text
Sanitized before persistence/submission.
```

### Scenario F — User deletes history while sync is enabled

Expected:

```text
Local data removed.
Sync deletion propagated.
Data does not return during reconciliation.
```

### Scenario G — Network unavailable

Expected:

```text
Tracking unaffected.
No retry storm.
```

### Scenario H — Update adds a new collection field

Expected:

```text
Privacy review + disclosure/consent as required.
```

---

# 41. Privacy Acceptance Criteria

### Default behavior

- No usage telemetry leaves the device.
- Tracking works without network access.
- Google sign-in is optional.
- Sync is separate from sign-in.
- Diagnostics are off by default.
- Private browser domains/titles are never persisted.

### User control

- User can disable page-title collection.
- User can disable window-title collection.
- User can inspect recorded data.
- User can correct classifications.
- User can export history.
- User can delete history.
- User can control retention.

### Data minimization

- No keystrokes.
- No screenshots.
- No clipboard.
- No page DOM/content.
- No cookies/passwords/tokens.
- No browser network-body capture.

### Cloud

- Sync is opt-in.
- Usage data is encrypted before cloud storage.
- Cloud sync is not required for tracking.
- Google identity is not the usage-data encryption key.

### Diagnostics

- Production logs exclude raw browser/window details by default.
- Diagnostic payloads are sanitized.
- Diagnostic submission requires explicit opt-in/action.

---

# 42. Hard Invariants

1. **Usage history is local by default.**
2. **Zero behavioral telemetry is the default.**
3. **Tracking does not require a network connection.**
4. **Google sign-in does not automatically enable usage-history sync.**
5. **Private browser domain/title data is never persisted by default.**
6. **Unknown private state fails closed.**
7. **Page-title and window-title collection are independently controllable.**
8. **No keystroke logging exists in the normal tracking architecture.**
9. **No screenshots are required for tracking.**
10. **No clipboard capture exists for tracking.**
11. **No page DOM/content capture exists for V1 browser analytics.**
12. **Passwords, cookies, tokens, and form contents are never collected.**
13. **Raw usage history is never product telemetry.**
14. **Diagnostics do not receive the full usage database by default.**
15. **Logs do not contain raw URLs/titles/domains by default.**
16. **Cloud usage data is encrypted before leaving the device when sync is enabled.**
17. **The Google account is not the encryption key.**
18. **Deletion cannot be silently defeated by backups or sync reconciliation.**
19. **New sensitive data collection requires privacy review.**
20. **Automatic updates cannot silently introduce unrelated new collection.**
21. **User-facing privacy settings must match actual implementation behavior.**
22. **The browser extension does not use remote analytics for tracking.**
23. **Local IPC is treated as a security/privacy boundary.**
24. **A feature must have a documented purpose before collecting new data.**
25. **Sensitive usage history is not used to train external models without separate explicit governance/consent.**

---

# 43. Implementation Requirements

The implementation should establish these controls before feature expansion:

1. Central data-classification metadata.
2. Central privacy settings service.
3. Centralized redaction/sanitization utilities.
4. Network-capability boundaries between tracker and sync/update components.
5. Browser private-state enforcement in the data-ingestion layer, not only the UI.
6. Data export service.
7. Deletion service with derived-data invalidation.
8. Retention/compaction service.
9. Diagnostic allowlist.
10. Privacy regression tests.
11. Automated tests asserting zero telemetry endpoints in the tracker runtime.
12. Documentation generated/updated when data inventory changes.

---

# 44. Privacy Regression Test Suite

The CI suite should contain tests that fail if prohibited behavior is introduced.

Examples:

```text
No network client referenced by Tracking.Runtime
No telemetry endpoint configured
Private BrowserPageObservation → no domain/title persisted
Diagnostic serializer → no raw title/domain/url fields
Export → excludes credentials
Delete range → affected aggregates invalidated
Sync disabled → no sync queue activity
Google authenticated + sync disabled → no usage upload
```

Static analysis or architecture tests should be used where practical to prevent forbidden dependencies from entering the tracker project.

---

# 45. Documentation Requirements

The repository should maintain:

```text
docs/
  privacy/
    data-inventory.md
    privacy-controls.md
    diagnostic-schema.md
```

These supporting documents can be introduced as implementation matures.

User-facing privacy documentation should be generated from or kept consistent with the engineering data inventory where practical.

---

# 46. Relationship to Later Documents

This document establishes privacy requirements; later documents establish implementation mechanisms.

### Document 10 — Security & Cryptography Architecture

Defines:

- Local data protection.
- Encryption at rest.
- E2EE.
- Key generation.
- Key storage.
- Key recovery.
- Device trust.
- Sync cryptography.

### Document 11 — Google Drive Sync Specification

Defines:

- Encrypted object format.
- Sync queue.
- Conflict resolution.
- Tombstones.
- Device migration.
- Drive API behavior.

### Document 12 — Performance, QA & Release Engineering

Defines:

- Privacy regression testing in CI.
- Resource budgets.
- Packaging/update behavior.
- Release verification.

---

# 47. Regulatory/Standards Note

Privacy engineering should follow broadly recognized principles such as purpose limitation, data minimization, storage limitation, security, and accountability. These concepts are reflected in major privacy frameworks, including the EU GDPR. The engineering team should obtain jurisdiction-specific legal review before making legal compliance claims.

Windows itself distinguishes required and optional diagnostic data, and Microsoft's current Windows privacy documentation includes product/service usage and browsing-related categories among optional diagnostic data. This reinforces why PC Usage Intelligence should keep its own behavioral telemetry boundary explicit rather than relying on vague “anonymous analytics” language. citeturn0search0turn0search3

---

# 48. Definition of Done for Document 09

Document 09 is implemented when:

- Every persisted data category has a documented purpose and sensitivity classification.
- Local usage history is the default source of truth.
- Behavioral telemetry is absent by default.
- Browser private-mode data is technically blocked from persistence.
- Page/window title collection is independently configurable.
- Diagnostics are separated from behavioral analytics and sanitized.
- Users can inspect, export, correct, and delete their data.
- Retention is explicit and configurable within defined limits.
- Sync is explicitly enabled and cryptographically separated from Google authentication.
- Local tracker code has no normal network dependency.
- Logs and diagnostics cannot casually leak usage history.
- Privacy regression tests protect the above guarantees.
- New sensitive collection has a documented governance path.

The next document, **Document 10 — Security & Cryptography Architecture**, should turn these privacy requirements into concrete security mechanisms: threat model, local database protection, E2EE design, key hierarchy, device keys, Google OAuth boundaries, recovery, rotation, deletion/key destruction, and cryptographic implementation requirements.