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
10. `10-security-cryptography.md` — Security & Cryptography
11. `11-google-drive-sync.md` — Google Drive Sync

### Execution
12. `12-performance-qa-release.md` — Performance, QA & Release Engineering

## Supporting artifacts

- `adr/` — Architecture Decision Records
- `schemas/` — Data, IPC, and protocol schemas
- `testing/` — Test matrices and benchmark plans
- `roadmap/` — Milestones and implementation planning

## Authority

Requirements flow downward through the document order. Later technical documents must not silently change product scope established by the PRD and scope specification. Any material architectural decision that changes an established constraint should receive an ADR.
