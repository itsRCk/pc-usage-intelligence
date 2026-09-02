# ADR-005: Use Named Pipes for Local IPC

- **Status:** Accepted
- **Date:** 2026-09-02

## Context

The Desktop UI and Tracking Runtime are separate processes but must exchange lifecycle status, health information, configuration commands, and user actions. The IPC mechanism must remain local, versionable, lightweight, and access-controlled.

## Decision

Use **Windows named pipes** for local UI ↔ tracker IPC.

Messages must use explicit versioned contracts. The pipe endpoint must be restricted to the intended local user/session and must reject unauthorized clients. IPC carries commands and status, not large analytical datasets.

## Rationale

- Native Windows primitive suited to local process communication.
- Avoids network sockets and unnecessary network exposure.
- Supports a clear process boundary.
- Compatible with request/response and streaming status patterns.

## Consequences

- IPC contracts become versioned compatibility surfaces.
- Connection loss and tracker restart must be normal states, not fatal UI errors.
- Authentication/authorization must be enforced at the pipe boundary.
- Heavy analytics remain in SQLite/read services rather than crossing IPC.

## Validation

Test unauthorized access, malformed messages, protocol-version mismatch, disconnect/reconnect, tracker restart, UI restart, message ordering, timeouts, cancellation, and resource exhaustion.
