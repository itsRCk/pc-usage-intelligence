# ADR-003: Model Foreground and Visible Time Separately

- **Status:** Accepted
- **Date:** 2026-09-02

## Context

A window can remain visible while another window is active. Treating all visible windows as active usage would overstate application use, while tracking only the foreground window would lose useful multi-window context.

## Decision

Track two distinct interval dimensions:

1. **Foreground time** — authoritative active-use metric for the foreground window/application.
2. **Visible time** — time during which a qualifying window is present/visible according to the defined Windows visibility semantics, including simultaneous windows.

Foreground intervals must be non-overlapping for a user session. Visible intervals may overlap.

## Rationale

This preserves an accurate active-use metric while supporting multi-monitor and multi-window analytics without conflating presence with attention.

## Consequences

- Every consumer must state whether it uses foreground or visible time.
- Analytics must never silently substitute visible time for foreground time.
- Multi-monitor visibility and minimized/cloaked state require explicit semantics.
- Tracking gaps remain gaps; they are not converted to zero usage.

## Validation

Use deterministic replay fixtures covering overlapping windows, minimized/cloaked windows, multiple monitors, rapid switching, lock/sleep, and display topology changes. Verify interval invariants and duration totals independently.
