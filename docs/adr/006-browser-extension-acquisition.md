# ADR-006: Prefer Browser Extensions with a Local Native Bridge

- **Status:** Accepted
- **Date:** 2026-09-02

## Context

Browser-level analytics require reliable active-tab/domain information that cannot be derived safely from process names and window titles alone. Scraping browser history databases is fragile and can expose substantially more information than the product needs.

The launch browser set is Chrome, Edge, Firefox, Brave, and Arc.

## Decision

Use a **browser extension + local native bridge** as the preferred acquisition mechanism, behind a common browser adapter contract.

The acquisition layer should capture the minimum required browser state: browser/window/tab identity, active-tab state, domain, optional page title, and private/incognito state. It must not capture passwords, cookies, tokens, form contents, network bodies, or arbitrary page content.

Private/incognito browsing is fail-closed: browser application usage may be tracked, but private domain/title data must not be persisted. Arc receives independent compatibility validation rather than being assumed to behave exactly like another Chromium browser.

## Alternatives rejected

- **Browser history database scraping:** brittle across versions/profiles and unnecessarily broad access.
- **Process/window-title inference alone:** insufficient for reliable domain and active-tab identity.
- **Content/DOM scraping:** unnecessary for the product and creates avoidable privacy risk.

## Consequences

- Each supported browser needs extension packaging/permission handling and integration tests.
- A local bridge is another component to secure and version.
- Browser analytics can degrade independently without disabling core Windows app tracking.

## Validation

Run contract, privacy, private-browsing, active-tab, multi-window, browser-update, profile, crash/reconnect, and Windows-window-correlation tests across all launch browsers.
