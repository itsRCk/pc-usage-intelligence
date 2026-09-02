# ADR-001: Use WinUI 3 for the Desktop UI

- **Status:** Accepted
- **Date:** 2026-09-02
- **Decision owners:** Project architecture

## Context

The product is Windows-only and needs a polished, modern desktop UI while keeping the background tracking runtime lightweight. The UI must integrate cleanly with Windows 10/11 and remain separate from the tracking engine.

Candidate approaches included WinUI 3, WPF, Avalonia, Electron, and Tauri.

## Decision

Use **C#/.NET with WinUI 3 and the Windows App SDK** for the primary desktop UI.

The UI is a presentation/application layer only. It must not call low-level Win32 tracking APIs directly; platform interaction belongs behind Windows/domain services.

## Rationale

- Native Windows alignment is the strongest fit for a Windows-only product.
- The stack supports modern Windows UI patterns without introducing a browser runtime solely for the desktop shell.
- C#/.NET provides strong shared-language reuse with the tracking and domain layers.
- The architecture permits the UI to remain a separate process from the lightweight tracker.

## Alternatives rejected

- **WPF:** mature and viable, but not preferred for a new modern Windows-first UI.
- **Avalonia:** attractive for cross-platform reach, which is not a current product requirement.
- **Electron:** powerful web UI stack but introduces a comparatively heavy runtime that conflicts with the product's low-overhead goals.
- **Tauri:** lighter than Electron, but adds a web UI/runtime boundary without a current product need.

## Consequences

Positive:
- Native Windows integration and a coherent C#/.NET architecture.
- No requirement to ship a full Chromium runtime for the desktop UI.

Negative:
- Windows-only UI technology is an intentional constraint.
- WinUI 3/Desktop behavior must be validated on the supported Windows 10/11 matrix.

## Validation

A technical spike must verify startup time, steady-state resource use, chart/timeline rendering performance, accessibility, packaging, and Windows 10/11 compatibility before substantial UI implementation.
