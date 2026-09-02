# Security & Cryptography Architecture

**Product:** PC Usage Intelligence  
**Document:** 10 — Security & Cryptography Architecture  
**Status:** Authoritative security/cryptography baseline — Pre-development  
**Parent documents:** `docs/01-product-requirements.md` through `docs/09-privacy-data-governance.md`  
**Platform:** Windows 10 and Windows 11  
**Last updated:** 2026-09-02

---

# 1. Purpose

PC Usage Intelligence stores a detailed longitudinal record of a person's computer activity. The security architecture therefore protects both the application and the history it creates.

The central security objective is:

> A local attacker or compromised cloud account must not obtain more usage history than the security boundary legitimately permits.

The architecture must provide:

- Protection of local secrets and encryption keys.
- Integrity and authenticity of local and synced data.
- End-to-end encryption for cloud-synchronized usage history.
- Separation between Google identity and usage-data encryption.
- Controlled multi-device enrollment.
- Recovery without silently weakening encryption.
- Safe key rotation and revocation.
- Deletion semantics that remain correct under encrypted sync.
- Strong local IPC controls.
- Secure OAuth token handling.
- Cryptographic agility without inventing custom cryptography.

This document defines the target architecture. Exact library/package choices should be validated in security and performance spikes before implementation.

---

# 2. Security Model

The system contains four principal trust zones:

```text
┌───────────────────────────────────────────────────────────┐
│                    USER DEVICE                            │
│                                                           │
│  Desktop UI        Tracking Runtime       SQLite          │
│       │                   │                 │             │
│       └────── local IPC ──┘                 │             │
│                           ┌──────────────────┘             │
│                           ↓                                │
│                    Crypto / Key Store                     │
│                           │                                │
│                           ↓                                │
│                    Sync / Google APIs                      │
└───────────────────────────┼───────────────────────────────┘
                            │ encrypted payloads
                            ↓
                     User's Google Drive
```

Trust assumptions:

1. The user's Windows account and device may be compromised at the host level.
2. Malware may run as the same user.
3. Another local Windows user should not access the user's protected secrets through application files or IPC.
4. The Google account may be compromised independently of the local device.
5. Google Drive storage must not be treated as a plaintext-trusted database.
6. The application source and binary may be inspected by users; secrets must not depend on obscurity.
7. A completely compromised Windows session can observe plaintext while the application is actively using it. No local cryptographic design can fully prevent an attacker who already controls the user's session from reading data presented to the process.

The architecture primarily protects against:

- Stolen/incorrectly accessed local files.
- Another local user reading protected data.
- Cloud storage/provider disclosure of plaintext usage data.
- Accidental secret leakage through logs/crash reports.
- Unauthorized sync operations.
- Malformed or replayed sync objects.
- Unauthorized local IPC clients.

It does not claim protection against a fully compromised endpoint while the application is unlocked.

---

# 3. Security Goals

## 3.1 Confidentiality

Usage history, browser domains, window/page titles, classifications, and synchronization metadata should be unreadable to unauthorized parties.

## 3.2 Integrity

Tampering with local or cloud data must be detectable.

## 3.3 Authenticity

The application must be able to determine whether encrypted sync objects were produced by an authorized device/account context.

## 3.4 Forward operational safety

A compromised or revoked device should not remain an unlimited future recipient of newly encrypted data.

## 3.5 Availability

Security mechanisms must not make the tracker dependent on the network or introduce excessive CPU/storage overhead.

## 3.6 Recoverability

Users must have a documented path to recover encrypted history when changing devices without making the Google account itself the data-encryption secret.

---

# 4. Cryptographic Design Rules

The project MUST NOT invent:

- Custom ciphers.
- Custom MAC schemes.
- Custom password hashing algorithms.
- Custom key exchange.
- Home-grown authenticated encryption formats.

Use well-reviewed platform or library primitives and keep cryptographic code behind narrow interfaces.

Microsoft's current CNG guidance supports authenticated symmetric encryption such as AES and warns against ECB; it also recommends cryptographically secure randomness such as `BCryptGenRandom` for Windows code. citeturn351231search4turn351231search0turn351231search1

Default algorithm candidates:

| Purpose | Candidate | Status |
|---|---|---|
| Symmetric authenticated encryption | AES-256-GCM | Preferred candidate |
| Hash | SHA-256 | Preferred |
| Password-based KDF | Argon2id | Preferred candidate; library validation required |
| CSPRNG | OS-backed cryptographic RNG | Required |
| Device key agreement | X25519 | Preferred candidate; library validation required |
| Device signing | Ed25519 | Preferred candidate; library validation required |
| Key wrapping at Windows boundary | DPAPI / CNG protection | Preferred Windows mechanism |
| Transport security | TLS via platform/network stack | Required |

The exact cryptographic suite becomes an ADR after dependency/license/support validation.

---

# 5. Randomness

All security-sensitive randomness must come from a cryptographically secure source.

For Windows-native code, `BCryptGenRandom` with the system-preferred RNG is the preferred platform primitive; Microsoft's guidance explicitly recommends CSPRNGs and .NET's `RandomNumberGenerator` for managed code. citeturn351231search0turn351231search1

Never use:

```text
System.Random
rand()
GetTickCount*
application timestamps
process IDs
window handles
```

as cryptographic entropy.

---

# 6. Key Hierarchy

The design separates identity, device authorization, and encrypted usage data.

Target hierarchy:

```text
                    User Encryption Root (UERK)
                              │
                  ┌───────────┴───────────┐
                  │                       │
        Dataset / Epoch Keys       Recovery Wrapping Key
                  │
             ┌────┴────┐
             │         │
        Data chunks   Metadata
        / snapshots   objects

Device Authorization Keys
        │
        └── authorize/decrypt UERK for enrolled devices

Windows Local Protection Key
        │
        └── protects device private material / local secrets
```

The exact envelope structure should permit future key rotation without rewriting the entire history.

---

# 7. User Encryption Root Key

The **User Encryption Root Key (UERK)** is a random high-entropy symmetric key and is the root encryption secret for synchronized usage data.

Properties:

- Generated locally using a CSPRNG.
- Never derived directly from the Google password.
- Never transmitted to Google in plaintext.
- Never logged.
- Never stored unprotected in ordinary SQLite tables.
- Not identical to a device key.
- Not identical to an OAuth token.

The UERK should usually encrypt or wrap intermediate dataset/epoch keys rather than encrypting an unbounded stream of records directly.

---

# 8. Dataset / Epoch Keys

The synchronization layer should use rotating **dataset/epoch keys**.

Example:

```text
UERK
 ├─ Epoch 2026-Q3 key
 ├─ Epoch 2026-Q4 key
 └─ Epoch 2027-Q1 key
```

Advantages:

- Limits the amount of data protected by a single active key.
- Simplifies rotation.
- Allows future crypto-version migration.
- Allows selective destruction of old encrypted epochs where appropriate.

Epoch boundaries are an implementation policy, not a user-visible concept.

A key must not be reused across incompatible cryptographic contexts.

Microsoft's SDL guidance recommends defining key lifetimes and replacing keys so expired keys are no longer used for new encryption. citeturn351231search1

---

# 9. Envelope Encryption

Each sync object should follow a conceptual structure such as:

```text
EncryptedObject
├── format_version
├── crypto_suite
├── object_id
├── dataset_id
├── epoch_id
├── object_type
├── schema_version
├── created_at
├── nonce
├── ciphertext
└── authentication_tag
```

Associated authenticated data should bind security-critical metadata to the ciphertext, for example:

```text
format_version
crypto_suite
object_id
dataset_id
epoch_id
object_type
schema_version
```

This prevents an attacker from safely moving ciphertext between unrelated contexts without detection.

Never trust metadata merely because it is outside the ciphertext.

---

# 10. Nonce Management

For AES-GCM, nonce/IV management must be explicit and testable.

The implementation MUST guarantee that a nonce is never reused with the same encryption key.

Preferred strategy:

- Generate a fresh cryptographically random nonce per encryption operation, or
- use a formally specified deterministic nonce construction with strict uniqueness guarantees.

The random-nonce approach is simpler for the initial implementation if the collision probability and object-volume bounds are formally analyzed.

Nonce generation must not rely on timestamps alone.

---

# 11. Local Encryption at Rest

Local usage data should have a layered protection model.

### Layer 1 — File-system access control

SQLite files and application data directories must use user-scoped Windows ACLs.

### Layer 2 — Database-level protection

High-sensitivity local data should be encrypted at rest where technically justified by the threat model and performance budget.

### Layer 3 — Key protection

Encryption keys are protected using Windows user/device-bound protection rather than being embedded in the database plaintext.

Windows DPAPI's `CryptProtectData` is designed for data protection where the same user on the same computer can normally decrypt the data; it also provides integrity protection. Microsoft explicitly notes that standard DPAPI does not solve cross-machine key management. citeturn717896search0turn351231search12

Therefore:

```text
Local-at-rest key protection
→ Windows user/device protection

Cross-device encryption
→ application-managed E2EE keys
```

These mechanisms must not be conflated.

---

# 12. DPAPI / CNG Protection Boundary

DPAPI is suitable for protecting locally persisted secrets such as:

- A device private key.
- A locally cached encrypted UERK envelope.
- OAuth refresh credentials where the chosen token library permits it.
- A local database encryption key.

The product should prefer user-scoped protection, not machine-wide protection, because the product is per-user.

Microsoft documents that `CryptProtectData` normally binds protected data to the same user credentials and computer; using the machine-wide flag changes that boundary and may allow other users on that machine to decrypt it. citeturn717896search0turn351231search1

Therefore `CRYPTPROTECT_LOCAL_MACHINE` MUST NOT be used for the product's user secrets unless a separate reviewed design explicitly requires it.

CNG/DPAPI-NG can protect secrets to defined principals and supports cross-machine scenarios, but the product's portable E2EE dataset key should remain under application-controlled key management rather than relying on Windows-only protection for cross-device synchronization. citeturn351231search3turn351231search5

---

# 13. Memory Handling

Sensitive plaintext exists in memory during normal application operation.

Requirements:

- Keep plaintext lifetime as short as practical.
- Avoid copying secret material unnecessarily.
- Use immutable/bounded buffers where appropriate.
- Clear temporary unmanaged buffers after use.
- Do not log key material or plaintext payloads.
- Avoid serializing entire history datasets solely for encryption if streaming/chunked processing can reduce exposure.

Windows provides `CryptProtectMemory` for protecting sensitive data in memory, but it is not a substitute for proper key handling and cannot eliminate plaintext during active use. citeturn717896search4

Use memory protection only where it materially reduces an identified risk; do not add it indiscriminately to hot tracking paths at the expense of performance.

---

# 14. Device Identity

Each installed device receives a persistent cryptographic device identity.

Conceptual device record:

```text
Device
├── device_id
├── key_version
├── public_identity_key
├── public_encryption_key
├── created_at
├── last_seen
├── revoked_at?
└── status
```

Private keys remain local and protected by Windows user-scoped key protection.

The device ID is an application identifier, not a secret.

Do not use:

- MAC address.
- BIOS serial number.
- CPU serial data.
- Disk serial number.

as the sole cryptographic identity.

---

# 15. Device Authorization

A new device must be explicitly enrolled into the user's encrypted dataset.

Target model:

```text
Existing trusted device
        ↓
authorizes new device
        ↓
new device receives encrypted UERK envelope
        ↓
new device decrypts locally
```

This can be implemented later through a QR/pairing code or another authenticated user-mediated ceremony.

The important invariant is that simply signing into the Google account does not automatically reveal the encryption root key.

---

# 16. Device Key Pairing

A device should maintain two conceptual key roles:

```text
Identity/signing key
Encryption/key-agreement key
```

Separating roles reduces accidental cross-use.

The preferred candidate is:

- Ed25519-like signing key for authenticity.
- X25519-like key agreement key for wrapping/enrolling the UERK.

The implementation must use mature, audited libraries that provide the selected algorithms correctly.

---

# 17. Recovery Model

Recovery is one of the most important design decisions because E2EE means the service cannot simply “reset the password” and recover the data.

V1 target:

```text
Google account
        │
        └── identity / Drive authorization

Recovery secret
        │
        └── independent recovery path to UERK
```

The recovery secret must not simply be the Google password.

Preferred user-facing options to evaluate:

### Option A — Recovery code/seed

A high-entropy recovery secret is generated locally and displayed once for the user to save offline.

### Option B — User-chosen recovery passphrase

A passphrase is processed with a memory-hard KDF such as Argon2id and used to wrap the UERK.

### Option C — Device-to-device recovery

An existing trusted device authorizes a new device.

The product should support at least device-to-device recovery and a user-held recovery mechanism before calling encrypted migration complete.

---

# 18. Recovery Secret Storage

A recovery secret must not be stored in plaintext in:

- SQLite.
- Logs.
- Google Drive metadata.
- OAuth metadata.
- Crash dumps.

For recovery-passphrase designs, store only a KDF salt and an encrypted/wrapped key envelope.

The KDF parameters must be versioned so they can evolve over time.

---

# 19. Google OAuth Security Boundary

Google OAuth is an authentication/authorization channel, not the application's key-management system.

For Windows desktop apps, Google's current OAuth guidance supports installed applications and recommends PKCE; desktop applications are treated as public clients and cannot keep a client secret confidential. Google also documents the loopback redirect flow for desktop applications. citeturn159894search0turn159894search1

Requirements:

- Use the official desktop/installed-app OAuth flow.
- Use PKCE with S256.
- Validate OAuth `state`.
- Use HTTPS for authorization endpoints.
- Store refresh/access credentials only in protected local storage.
- Never include OAuth credentials in sync objects.
- Never use OAuth tokens as encryption keys.
- Request only the minimum Drive scope required.

Google's current scope documentation distinguishes the broad `drive` scope from narrower options including `drive.file` and `drive.appdata`; the final Drive sync design must select the narrowest scope compatible with the product. citeturn159894search2

---

# 20. Google Drive Storage Model

Google Drive should hold encrypted application objects, not plaintext usage records.

The Drive API exposes `appDataFolder` as an application-specific storage space for application data not intended to be directly accessible to the user, and the API also supports narrower application-specific scopes. citeturn717896search2turn159894search2

The sync design should evaluate two layouts:

```text
Option A
appDataFolder
→ encrypted dataset objects

Option B
user-visible Drive folder
→ encrypted backup/archive
```

The default sync implementation should prefer the least-broad Drive permission compatible with desired user control and migration behavior.

Document 11 will freeze this decision.

---

# 21. Authenticated Encryption

Every encrypted sync object must provide confidentiality and integrity together.

Preferred candidate:

```text
AES-256-GCM
```

Do not implement:

```text
AES + plain SHA
AES-CBC without independent authenticated integrity
XOR-based obfuscation
compressed plaintext without authentication
```

The cryptographic wrapper should expose a narrow API such as:

```text
Encrypt(key, plaintext, associatedData)
→ nonce + ciphertext + tag

Decrypt(key, nonce, ciphertext, tag, associatedData)
→ plaintext or authentication failure
```

Authentication failure must be fatal for the object; never return partially trusted plaintext.

---

# 22. Signing and Authenticity

Encryption protects confidentiality/integrity of an object under the encryption key, but device authenticity can require a separate signature layer.

The sync protocol should support signed control-plane objects where needed:

```text
Device enrollment
Device revocation
Key rotation
Deletion tombstone
Dataset manifest
```

For ordinary encrypted data chunks, signatures may be unnecessary if authenticated encryption and authorized key distribution already establish the intended security property. Avoid adding cryptographic layers without a threat-model justification.

---

# 23. Manifest Security

The encrypted dataset should have a signed or authenticated manifest containing information such as:

```text
protocol_version
crypto_suite
current_epoch
known_devices
revoked_devices
object inventory/version
last_writer counters
```

The manifest must not contain sensitive plaintext usage content.

It should contain enough information to detect:

- Unsupported protocol versions.
- Missing epochs.
- Unexpected device IDs.
- Replay of stale manifests.
- Conflicting writes.

---

# 24. Replay Protection

An attacker able to copy an old valid encrypted object to Drive should not be able to make the application regress silently.

Each sync object should include a monotonic or otherwise uniquely identified version/context such as:

```text
object_id
sequence_number
created_at
writer_device_id
epoch_id
```

The reconciliation engine must detect stale or conflicting versions.

Time alone must not be used as the sole replay-protection primitive.

Document 11 will define the exact merge protocol.

---

# 25. Device Revocation

Users must be able to revoke a device.

Revocation means:

```text
Device is no longer authorized for future sync participation.
```

Upon revocation:

- Mark device revoked in the encrypted control state.
- Stop uploading new data under that device identity.
- Stop accepting its future writes.
- Rotate the active dataset/epoch key when necessary.
- Re-encrypt future data under a key unavailable to the revoked device.

Important limitation:

> Revocation cannot erase plaintext that a previously authorized compromised device already obtained.

This must be represented honestly in the security model.

---

# 26. Key Rotation

Key rotation should occur for at least these events:

1. Cryptographic suite migration.
2. Device revocation.
3. Recovery credential change when relevant.
4. Defined epoch expiration.
5. Suspected key compromise.

Rotation should be incremental rather than requiring a complete re-upload of history whenever possible.

Old keys may remain necessary for decrypting historical data until the user's retention policy removes the corresponding history.

---

# 27. Compromise Recovery

For a suspected device-key compromise:

```text
1. Revoke compromised device.
2. Authenticate a trusted remaining device.
3. Generate new active epoch key.
4. Publish new authorization state.
5. Re-encrypt future sync objects with the new key.
6. Preserve old history under old keys until retention/deletion permits destruction.
```

If the UERK itself is compromised, a deeper root-key rotation may be required.

The UX should distinguish:

```text
Device compromised

from

Encryption root compromised
```

because their remediation scope differs.

---

# 28. Cryptographic Versioning

Every encrypted object must carry a version.

Example:

```text
crypto_version = 1
suite = AES256_GCM_X25519_ED25519
```

Never infer crypto version from application version alone.

The crypto layer must reject unknown or unsupported suites safely.

Future cryptographic migration should be possible without rewriting the entire application storage layer.

---

# 29. Key Lifecycle

All keys have explicit lifecycle states:

```text
Generated
  ↓
Active
  ↓
Retired
  ↓
Destroyable
  ↓
Destroyed
```

A retired key may still decrypt historical data.

A destroyable key is no longer needed by the configured retention/sync policy.

Destroyed means the application has removed its managed copies/wrappers; it cannot guarantee erasure from every underlying physical medium or third-party backup outside its control.

---

# 30. Secure Deletion

Deletion has two dimensions:

```text
Logical deletion

and

Cryptographic/key destruction
```

For cloud sync, deletion should use authenticated tombstones and, where practical, destruction of encryption-key material that makes deleted historical ciphertext unrecoverable within the application's controlled key system.

However, a product MUST NOT claim that cryptographic deletion has physically erased every byte from Google infrastructure.

User-facing language should be precise:

```text
Deleted from your synced dataset
```

rather than an unverifiable physical-erasure promise.

---

# 31. Local Database Encryption Decision

Full SQLite database encryption is a separate engineering decision.

Baseline options:

### Option A — File-system + protected key + selective sensitive-field encryption

Pros:

- Lower complexity.
- Lower hot-path overhead.
- Easier SQLite compatibility.

Cons:

- Raw database may expose schema/metadata if file permissions are bypassed.

### Option B — Full database encryption

Pros:

- Stronger protection for offline database theft.

Cons:

- More integration complexity.
- Potential performance/write overhead.
- Encryption key lifecycle becomes coupled to database opening.

The final decision must be benchmarked against the tracking requirement of near-zero background overhead.

For V1, at minimum, high-sensitivity secrets MUST NOT exist as plaintext database values, and the SQLite file must use restrictive user ACLs.

---

# 32. Local File Permissions

Application data directories should be scoped to the current Windows user.

The application must not create broadly readable usage files such as:

```text
C:\Public\usage.db
```

or place plaintext exports/tokens in shared temporary directories.

Temporary crypto files should be minimized and removed after use.

---

# 33. Secret Separation

The following values must remain conceptually and physically distinct:

```text
Google access token
Google refresh credential
Device private key
Device encryption private key
UERK
Recovery secret
Database encryption key
```

Do not reuse one secret for another purpose.

Key derivation, where used, must be explicit and domain-separated.

---

# 34. Domain Separation

If one root secret is used to derive multiple subordinate keys, use a cryptographically strong KDF with explicit context labels.

Conceptually:

```text
KDF(UERK, “sync-data”, epoch_id)
KDF(UERK, “device-envelope”, device_id)
KDF(UERK, “backup”, backup_id)
```

Never derive application-purpose keys by concatenating strings into ad-hoc hashes.

---

# 35. Password / Passphrase Security

If the product supports a user-chosen recovery passphrase:

- Do not store the plaintext passphrase.
- Use a memory-hard password KDF such as Argon2id.
- Generate a unique random salt.
- Version KDF parameters.
- Use an application-specific context.
- Rate-limit recovery attempts where an online verifier exists.
- Avoid password-derived encryption keys without a KDF.

The initial parameter set must be benchmarked on supported Windows hardware and documented in a versioned crypto policy.

---

# 36. OAuth Token Storage

OAuth tokens should be treated as secrets and stored separately from usage data.

At minimum:

```text
OAuth metadata
→ ordinary configuration

OAuth refresh/access credentials
→ protected local credential store / protected blob
```

Never:

```text
log token
serialize token into usage export
sync token to Drive
store token in crash telemetry
```

---

# 37. Local IPC Authentication

The named-pipe boundary from Document 05 must be protected by Windows security descriptors appropriate to the current user/session.

Requirements:

- Explicit pipe ACL.
- Message authentication at the application boundary where appropriate.
- Protocol version negotiation.
- Request size limits.
- Schema validation.
- No arbitrary SQL or file-system commands over IPC.
- No direct exposure of cryptographic private keys through IPC.

The desktop UI should receive already-authorized application data from the tracker rather than holding privileged credentials that the tracker does not need.

---

# 38. Browser Security Boundary

Browser adapters are untrusted input boundaries from the security perspective.

They MUST NOT:

- Supply encryption keys.
- Supply OAuth tokens.
- Access the sync key hierarchy.
- Write directly into the sync store.
- Bypass private-mode filtering.

Their output should enter the normal observation/normalization pipeline and be subject to validation before persistence.

---

# 39. Input Validation

Security-sensitive parsers must validate:

- Maximum string length.
- Encoding.
- Enum values.
- Version numbers.
- IDs.
- Timestamps.
- Sequence numbers.
- Ciphertext size.
- Nonce length.
- Tag length.
- Associated-data context.

Malformed sync objects must fail closed.

Never allocate unbounded memory based solely on remote metadata.

---

# 40. Sync Object Limits

The sync protocol should define upper bounds for:

```text
object size
manifest size
batch size
number of records per object
metadata string length
number of devices
recovery envelope size
```

These limits protect against memory exhaustion and maliciously constructed Drive objects.

---

# 41. Integrity of Local Derived Data

Derived analytics should not be treated as security-authoritative.

The trusted source remains the validated local history according to Document 07.

If a local aggregate is corrupted:

```text
invalidate → rebuild from authoritative data
```

This reduces the need to protect every derived metric with an independent cryptographic record.

---

# 42. Tamper Detection

The application should detect suspicious database states such as:

- Invalid schema versions.
- Impossible interval overlaps where invariants forbid them.
- Unknown crypto versions.
- Missing sync epochs.
- Invalid authentication tags.
- Broken signed manifests.
- Impossible sequence regressions.

Tamper detection should trigger a safe recovery path, not silent repair that hides the incident.

---

# 43. Threat Model

### T1 — Stolen laptop

Attacker copies the usage database.

Protection:

```text
Windows ACLs
+ protected local keys
+ at-rest encryption strategy
```

### T2 — Another Windows user

Protection:

```text
user-scoped ACLs
user-scoped protected secrets
```

### T3 — Malicious same-user process

Protection:

```text
restricted IPC
secret isolation
short plaintext lifetimes
```

Residual risk:

```text
A fully privileged same-user malware process may observe active plaintext.
```

### T4 — Compromised Google account

Protection:

```text
Google account ≠ UERK
E2EE ciphertext only
```

### T5 — Compromised Drive contents

Protection:

```text
AEAD encryption
key separation
```

### T6 — Compromised enrolled device

Protection:

```text
device revocation
future key rotation
```

### T7 — Malicious sync object

Protection:

```text
AEAD verification
schema/version validation
size limits
replay checks
```

### T8 — Developer accidentally logs secret

Protection:

```text
structured redaction
logging allowlist
security regression tests
```

---

# 44. Security Boundaries and Least Privilege

The architecture should enforce the following direction:

```text
Tracking Runtime
  → observation + local persistence only

Desktop UI
  → user interaction + analytics reads

Sync Worker
  → encrypted sync objects + OAuth

Crypto Service
  → narrowly scoped key operations

Browser Bridge
  → normalized browser observations
```

No component should receive a broader authority merely because it is convenient.

---

# 45. Update and Supply-Chain Security

Production builds should be signed and distributed through trusted release channels.

Security-sensitive dependencies should be:

- Version pinned or tightly constrained.
- Audited for licensing and provenance.
- Monitored for vulnerabilities.
- Updated through reproducible CI.

A cryptographic library change requires security regression testing.

Do not copy cryptographic source code from unreviewed snippets into the project.

---

# 46. Key-Handling API Boundary

Application code should not pass raw byte arrays representing the UERK through arbitrary layers.

Prefer typed abstractions such as:

```text
IKeyProtector
IKeyStore
IDataEncryptor
IDataDecryptor
IDeviceKeyProvider
IRecoveryKeyProvider
ISyncAuthenticator
```

The concrete cryptographic implementation should remain behind these interfaces.

This makes it easier to test, rotate algorithms, and enforce dependency boundaries.

---

# 47. Secure API Contracts

Example conceptual contract:

```text
IKeyProtector
  Protect(secret, scope) -> protected_blob
  Unprotect(protected_blob, scope) -> secret

IDataEncryptor
  Encrypt(key, plaintext, aad) -> encrypted_object
  Decrypt(key, encrypted_object, aad) -> plaintext

IDeviceIdentity
  GetDeviceId()
  GetPublicIdentityKey()
  Sign(data)

IDeviceKeyAgreement
  GetPublicKey()
  DeriveSharedSecret(peer_public_key)
```

Contract tests must validate:

- Wrong key fails.
- Modified ciphertext fails.
- Modified AAD fails.
- Modified nonce fails.
- Modified version/context fails.
- Replay is detectable at protocol level.

---

# 48. Error Semantics

Security failures must not silently downgrade to plaintext.

Forbidden behavior:

```text
Encryption failed
→ save plaintext instead
```

Required behavior:

```text
Encryption failed
→ do not transmit
→ preserve local data safely
→ surface recoverable error
```

Likewise:

```text
Key unavailable
→ tracking continues locally where possible
→ sync pauses
```

A sync failure must never stop tracking.

---

# 49. Offline Security

Offline mode must not weaken security.

The application can continue local tracking while:

- Google is unavailable.
- Drive is unavailable.
- OAuth credentials are expired.
- Sync keys cannot currently be refreshed.

The tracker should not store an emergency plaintext copy “for later upload.”

---

# 50. Backup Security

Backups must be encrypted or otherwise protected to the same security standard as the primary data they contain.

An unencrypted export is effectively a new high-sensitivity data store.

The export UX should warn users when creating plaintext formats such as CSV/JSON.

Encrypted archive export should be the preferred full-fidelity migration format.

---

# 51. Data Export Security

Export code must apply explicit field allowlists.

Example:

```text
CSV export
→ usage intervals
→ app/domain identity
→ selected metadata

Never
→ OAuth token
→ encryption key
→ device private key
```

The exported file must not contain cryptographic secrets even when “export everything” is selected.

---

# 52. Secure Recovery Ceremony

Recovery should make the security tradeoff visible.

Example device-migration flow:

```text
New device
   ↓
Install application
   ↓
Sign into Google (optional identity step)
   ↓
Choose “Restore encrypted history”
   ↓
Use trusted-device approval OR recovery secret
   ↓
Decrypt UERK envelope locally
   ↓
Create new device keys
   ↓
Register new device
   ↓
Begin sync
```

The Google login step does not itself unlock history.

---

# 53. Device Removal Flow

When removing a device:

```text
User selects device
        ↓
Confirm device identity
        ↓
Revoke device
        ↓
Rotate future authorization state
        ↓
Continue other devices
```

The UI should show the limitation that revocation cannot erase data previously downloaded by that device.

---

# 54. Account Disconnect Flow

“Disconnect Google account” must not mean “delete local usage history.”

The user should be offered distinct actions:

```text
Disconnect Google account
Disable sync
Delete local history
Delete synced history
```

These operations have different security consequences and must not be conflated.

---

# 55. Security Logging

Security logs should contain enough information for diagnosis without leaking usage data.

Good:

```text
sync_authentication_failed
reason=invalid_grant
component=google_drive
```

Bad:

```text
sync failed for https://sensitive-site.example/account/...
```

Never log:

- Secret keys.
- Recovery secrets.
- OAuth tokens.
- Full ciphertext/plaintext payloads.
- Complete window/page titles.
- Arbitrary URLs.

---

# 56. Security Auditability

All cryptographic operations should be attributable to code paths and versioned formats.

At minimum the project should be able to answer:

```text
Which crypto suite encrypted this object?
Which schema version produced it?
Which epoch key protects it?
Which device produced it?
Can the object be safely decrypted?
Has its authorization context been revoked?
```

These metadata fields may be public within the encrypted sync envelope where necessary, but sensitive content must remain inside authenticated encryption.

---

# 57. Security Testing

Required test classes:

### Primitive tests

- AES-GCM known-answer tests.
- KDF test vectors.
- Signature/key-agreement test vectors where applicable.
- RNG failure handling.

### Envelope tests

- Encrypt/decrypt round-trip.
- Wrong key.
- Wrong AAD.
- Modified ciphertext.
- Modified nonce.
- Modified authentication tag.
- Unsupported crypto version.

### Key lifecycle tests

- Generate.
- Protect.
- Unprotect.
- Rotate.
- Revoke.
- Recover.
- Destroy.

### Sync tests

- Offline queue.
- Duplicate object.
- Replayed object.
- Conflicting object.
- Revoked device.
- Missing epoch.
- Corrupt manifest.

### Privacy tests

- No secrets in logs.
- No OAuth token in export.
- No private browser data in sync object.
- No plaintext cloud payload.

### Adversarial tests

- Oversized objects.
- Invalid lengths.
- Malformed manifests.
- Random byte fuzzing.
- Parser fuzzing.

---

# 58. Security Acceptance Criteria

The security architecture is accepted when:

- UERK is generated locally from CSPRNG output.
- UERK is never derived from Google credentials.
- OAuth tokens and encryption keys are separate secrets.
- Local key material is protected by a Windows user-scoped mechanism.
- Sync objects use authenticated encryption.
- Nonce uniqueness is guaranteed.
- Crypto objects have explicit versioning.
- Cloud storage contains ciphertext, not plaintext usage history.
- Google account authentication does not unlock the UERK by itself.
- New devices require an explicit enrollment/recovery path.
- Device revocation prevents future authorized writes from that device.
- Key rotation is defined and testable.
- Recovery secrets are not stored in plaintext.
- Private browsing exclusions survive the sync path.
- Diagnostics/logs do not contain secrets or raw usage data by default.
- Encryption failures cannot silently fall back to plaintext.
- Offline tracking does not depend on authentication or sync.
- Security-sensitive parsers have bounded inputs.

---

# 59. Hard Invariants

1. **The Google account is not the usage-data encryption key.**
2. **OAuth credentials are never usage-data keys.**
3. **Usage history is encrypted before cloud storage.**
4. **Encryption failures never fall back to plaintext transmission.**
5. **Private-browser data cannot enter the encrypted sync dataset.**
6. **Keys are never logged.**
7. **Recovery secrets are never logged.**
8. **OAuth tokens are never logged.**
9. **Device private keys are never stored in plaintext SQLite.**
10. **Machine-wide DPAPI protection is not used for ordinary user secrets.**
11. **Cryptographic randomness comes from a CSPRNG.**
12. **Nonces are never intentionally reused with the same AEAD key.**
13. **Modified authenticated ciphertext is rejected.**
14. **AAD/context changes invalidate authenticated objects.**
15. **Unknown crypto versions fail closed.**
16. **Revoked devices cannot author new synchronized data.**
17. **Tracking continues without network access.**
18. **Sync failures cannot stop local tracking.**
19. **Key material is separated by purpose.**
20. **The cryptographic implementation does not invent custom primitives.**
21. **A fully compromised endpoint is acknowledged as able to observe plaintext while unlocked.**
22. **Deletion semantics do not claim physical erasure that the system cannot verify.**
23. **Security-sensitive inputs have explicit bounds.**
24. **Cryptographic formats are versioned independently of application versions.**
25. **A new device cannot silently obtain the UERK from Google authentication alone.**

---

# 60. Required ADRs

This document should produce at least these Architecture Decision Records:

```text
ADR-008  Local data protection strategy
ADR-009  Cryptographic suite
ADR-010  UERK and key hierarchy
ADR-011  Device enrollment and recovery
ADR-012  Local secret storage
ADR-013  Google OAuth security boundary
ADR-014  Sync object/envelope format
ADR-015  Key rotation and revocation
ADR-016  Secure deletion model
```

These supersede provisional cryptographic choices when implementation benchmarks or dependency review establish a better supported design.

---

# 61. Implementation Order

Security should be implemented in dependency order:

1. Define crypto interfaces.
2. Select audited crypto implementation/library.
3. Build known-answer tests and envelope tests.
4. Implement Windows local secret protection.
5. Implement device identity.
6. Implement UERK generation/storage.
7. Implement encrypted object format.
8. Implement recovery envelopes.
9. Implement device enrollment.
10. Implement key rotation/revocation.
11. Implement encrypted Drive sync.
12. Add deletion/tombstone handling.
13. Add security fuzzing.
14. Add release/supply-chain checks.

Do not build the sync UX around an unreviewed placeholder crypto design and retrofit security later.

---

# 62. Performance Requirements

Security must preserve the product's defining resource goals.

Target constraints:

- No cryptographic work in the tracker hot path unless needed for local persistence protection.
- No network calls from the tracker runtime.
- Sync encryption runs asynchronously.
- Batch encryption should be preferred over per-observation cloud operations.
- Large-history re-encryption must be resumable.
- Recovery/key rotation must not require the tracker to stop recording activity.
- Key operations must be measured for CPU, latency, and memory.

The exact cryptographic overhead budget must be established by benchmark, but it should not materially threaten the established targets of idle CPU <1%, typical CPU <2%, idle RAM <150 MB, and batched disk writes.

---

# 63. Failure Recovery

Security failures should degrade into safe states:

```text
Local key unavailable
→ sync paused
→ tracking continues if local storage remains available

Drive object authentication fails
→ object rejected
→ rest of sync continues

Device revoked
→ uploads blocked
→ local history preserved

Recovery fails
→ no key downgrade
→ explain next valid recovery path

Crypto implementation error
→ fail closed
→ preserve source plaintext locally where already safely stored
```

Do not discard local history because a remote encrypted object cannot be processed.

---

# 64. Security UX Principles

Security controls should be comprehensible without exposing cryptographic implementation details unnecessarily.

Prefer:

```text
“This device is trusted.”
“This device was revoked.”
“Encrypted sync is enabled.”
“Recovery key saved.”
```

Rather than forcing users to reason about:

```text
X25519 ephemeral-static DH
AES-GCM nonce spaces
KDF work factors
```

Technical details belong in advanced documentation.

---

# 65. Security Transparency

An advanced “Security” page should eventually provide:

```text
Encrypted locally           ✓
Encrypted before cloud sync ✓
Google cannot decrypt history ✓*

Trusted devices              N
Last key rotation             date
Recovery configured           Yes/No
Sync status                   status

*Assumes the user's endpoint and recovery secrets remain secure.
```

Avoid absolute claims such as “completely secure” or “Google can never access your data” without appropriate qualification.

---

# 66. Definition of Done for Document 10

Document 10 is implemented when:

- A complete threat model exists.
- Local and cloud trust boundaries are explicit.
- A reviewed cryptographic suite is selected.
- UERK/device/recovery key roles are defined.
- Windows local secret protection is implemented and tested.
- OAuth and encryption key boundaries are enforced.
- Sync envelopes provide authenticated encryption and versioning.
- Nonce uniqueness is formally enforced.
- Device enrollment, revocation, and recovery are implemented.
- Key rotation and cryptographic version migration are defined.
- Deletion and key-destruction semantics are represented honestly.
- Security regression/fuzz tests exist.
- No security failure falls back to plaintext.
- Performance benchmarks demonstrate acceptable overhead.

The next document, **Document 11 — Google Drive Sync Specification**, should define the encrypted object protocol, dataset layout, sync queue, manifests, conflict resolution, tombstones, multi-device reconciliation, device migration, and Drive API integration.