# PC Usage Intelligence

Privacy-first Windows usage tracking and analytics.

## Vision

PC Usage Intelligence continuously records how a user interacts with Windows—applications, windows, foreground activity, visibility, browser domains, sessions, and device state—while keeping the always-on tracking footprint extremely small.

The product is intentionally **tracking-first**, not a productivity coach. Its purpose is to provide an accurate, beautiful, and deeply explorable history of computer usage.

## Core principles

- **Local-first:** tracking and analytics work fully offline.
- **Privacy-first:** no behavioral telemetry by default.
- **Tracking/UI separation:** the tracking runtime operates independently of the dashboard.
- **Performance is a hard requirement:** background resource usage is measured and budgeted.
- **Accuracy over convenience:** tracking gaps are represented rather than fabricated.
- **User-controlled interpretation:** categorization and productivity/leisure classification are transparent and overrideable.
- **Encrypted sync:** optional Google-account-backed Google Drive backup/synchronization uses end-to-end encryption.

## Initial platform

- Windows 10
- Windows 11

## Initial audience

Developers, students, gamers, and power users.

## Product scope

The initial release focuses on:

- foreground application tracking
- visible window tracking
- application identity resolution
- application switching and session tracking
- multi-monitor environments
- browser tracking for Chrome, Edge, Firefox, Brave, and Arc
- domain-based browser analytics
- optional local page-title metadata
- automatic local categorization with user overrides
- daily, weekly, monthly, and custom historical analytics
- zoomable timelines and calendar views
- trends, comparisons, anomalies, and statistical insights
- local data retention, compaction, export, and deletion
- optional encrypted Google Drive synchronization and device migration

The following are deliberately out of scope for the initial product: app/site blocking, focus timers, reminders, notification suppression, gamification, and productivity interventions.

## Documentation

The project is being specified before implementation. Authoritative project documentation will live under `docs/` and will be developed in dependency order.

Planned primary documents:

1. Product Requirements Document
2. Scope & Feature Specification
3. Information Architecture & UX Specification
4. Visual Design System Specification
5. System Architecture & Technical Design
6. Windows Tracking Engine Specification
7. Data Architecture & Storage Specification
8. Browser Activity Acquisition Specification
9. Privacy & Data Governance Specification
10. Security & Cryptography Architecture
11. Google Drive Sync Specification
12. Performance, QA & Release Engineering Specification

Supporting architectural decisions will be maintained under `docs/adr/`.

## Development philosophy

Implementation will be AI-agent-friendly: requirements, interfaces, invariants, acceptance criteria, performance budgets, and architectural boundaries should be explicit enough that individual workstreams can be implemented and reviewed independently.

## Status

**Pre-development / requirements and architecture phase.**
