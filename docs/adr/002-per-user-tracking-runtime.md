# ADR-002: Run Tracking as a Per-User Background Runtime

- **Status:** Accepted
- **Date:** 2026-09-02

## Context

Tracking must continue independently of the desktop UI, survive UI crashes/restarts, and observe the interactive user's desktop session. A traditional Windows Service runs in Session 0 and is not the correct default boundary for direct interactive-desktop observation.

## Decision

Implement tracking as a **lightweight per-user background runtime/daemon** with service-like lifecycle behavior, started with the user's interactive session.

The Desktop UI and Tracking Runtime are separate processes. A privileged Windows Service is not part of the initial architecture. It may be introduced later only if a concrete privileged requirement cannot be satisfied from the user-session runtime.

## Rationale

- The runtime operates in the correct interactive user session.
- UI failures cannot stop tracking.
- The runtime can remain computationally small and independently restartable.
- Avoids unnecessary privileges and Session 0 complications.

## Consequences

- Startup, shutdown, logon/logoff, lock/unlock, sleep/resume, and crash recovery must be explicitly handled.
- Installer/update behavior must preserve reliable runtime startup.
- Any future privileged functionality requires a separate architectural decision.

## Validation

Test logon/logoff, lock/unlock, sleep/resume, UI crash, tracker crash, multiple sessions, startup ordering, and runtime resource budgets.
