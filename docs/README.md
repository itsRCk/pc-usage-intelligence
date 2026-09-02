# Project Documentation

This directory contains the authoritative product, UX, architecture, security, data, synchronization, performance, QA, and release specifications for PC Usage Intelligence.

## Document order

### Product
1. `01-product-requirements.md` — Product Requirements Document
2. `02-scope-feature-specification.md` — Scope & Feature Specification
3. `03-information-architecture-ux.md` — Information Architecture & UX
4. `04-visual-design-system.md` — Visual Design System

### Engineering
5. `05-system-architecture.md` — System Architecture & Technical Design
6. `06-windows-tracking-engine.md` — Windows Tracking Engine
7. `07-data-architecture-storage.md` — Data Architecture & Storage
8. `08-browser-activity-acquisition.md` — Browser Activity Acquisition

### Security & sync
9. `09-privacy-data-governance.md` — Privacy & Data Governance
10. `10-security-cryptography-architecture.md` — Security & Cryptography
11. `11-google-drive-sync-specification.md` — Google Drive Sync

### Execution
12. `12-performance-qa-release-engineering.md` — Performance, QA & Release Engineering

## Supporting artifacts

- `adr/` — Architecture Decision Records
- `schemas/` — Data, IPC, and protocol schemas
- `testing/` — Test matrices and benchmark plans
- `roadmap/` — Milestones and implementation planning

## Schema catalog

The machine-readable schema set is maintained under `schemas/` and currently includes:

- `domain-model.md` — canonical entities, IDs, enums, time, provenance, and invariants.
- `sqlite-schema.sql` — logical SQLite schema baseline and indexes.
- `tracking-observation.schema.json` — normalized Windows/tracker observation contract.
- `browser-events.schema.json` — browser adapter event contract.
- `ipc-messages.schema.json` — versioned UI ↔ tracker IPC contract.
- `classification-rule.schema.json` — deterministic/user classification rules.
- `analytics-query.schema.json` — time-range and analytics query contract.
- `sync-envelope.schema.json` — encrypted sync object envelope.
- `sync-mutations.schema.json` — logical sync mutations and deletion/tombstone semantics.

## Authority

Requirements flow downward through the document order. Later technical documents must not silently change product scope established by the PRD and scope specification. Any material architectural decision that changes an established constraint should receive an ADR.

Schemas translate the authoritative specifications into implementation contracts; they do not independently redefine product semantics.
