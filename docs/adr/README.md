# Architecture Decision Records

Architecture Decision Records (ADRs) capture material technical decisions that should remain explicit and reviewable across implementation work.

## Index

| ADR | Decision | Status |
|---|---|---|
| [001](001-winui-3-desktop-ui.md) | WinUI 3 for the desktop UI | Accepted |
| [002](002-per-user-tracking-runtime.md) | Per-user background tracking runtime | Accepted |
| [003](003-foreground-visible-tracking.md) | Separate foreground and visible time | Accepted |
| [004](004-sqlite-write-ownership.md) | SQLite write ownership | Proposed — benchmark required |
| [005](005-named-pipe-ipc.md) | Named-pipe local IPC | Accepted |
| [006](006-browser-extension-acquisition.md) | Browser extension + local native bridge | Accepted |
| [007](007-local-data-protection.md) | Local data protection | Proposed — threat model/benchmark required |
| [008](008-e2ee-key-management.md) | Separate sync encryption keys from Google identity | Proposed — key-management design required |
| [009](009-google-drive-as-encrypted-replication.md) | Google Drive as encrypted replication destination | Accepted |
| [010](010-packaging-and-distribution.md) | Store + standalone distribution | Accepted |

## How to use ADRs

- Read relevant ADRs before implementing an affected subsystem.
- Do not silently reverse an accepted decision in code.
- If implementation evidence invalidates an accepted decision, update or supersede the ADR explicitly.
- Proposed ADRs identify decisions that require a benchmark, threat model, spike, or other evidence before becoming accepted.
- ADRs record architectural intent; detailed behavior remains in the numbered specifications and schemas.

## Decision status

- **Proposed:** direction identified, but evidence or design work is still required.
- **Accepted:** decision is the current architectural constraint.
- **Superseded:** replaced by a later ADR; retain the historical record.
- **Deprecated:** no longer relevant, but retained for historical context.
