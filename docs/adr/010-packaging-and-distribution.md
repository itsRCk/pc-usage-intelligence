# ADR-010: Support Microsoft Store and Standalone Distribution

- **Status:** Accepted
- **Date:** 2026-09-02

## Context

The product needs a low-friction installation path for ordinary users while also supporting direct distribution. Updates must be reliable and must preserve local data and tracker continuity.

## Decision

Support both:

1. **Microsoft Store distribution** for trusted mainstream installation and update delivery.
2. **Standalone installer distribution** for direct downloads and users who prefer it.

The application architecture must not depend on one packaging mode. The installer/update system must preserve the user's local data and ensure that the per-user Tracking Runtime is registered and launched correctly after installation and updates.

## Rationale

- Store distribution improves discoverability and trust.
- Standalone distribution provides flexibility and avoids making the Store the only release channel.
- Separating packaging concerns from runtime architecture reduces deployment coupling.

## Consequences

- Two distribution paths require compatibility and upgrade testing.
- Installation, update, rollback, uninstall, and data-preservation semantics must be documented.
- Release artifacts need reproducible provenance and signing.

## Validation

Test clean install, upgrade from representative versions, failed update, rollback, uninstall/reinstall, per-user runtime startup, local-data preservation, Store packaging, standalone packaging, and Windows 10/11 support.
