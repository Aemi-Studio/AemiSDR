---
status: done
blocked-by: 
date: 2026-10-22
---

# 0001 — A private-API registry with verified owners and signatures

Private runtime APIs are resolved through Abysm's `RuntimeClass` and `RuntimeObject`, verifying
method signatures and catching Objective-C exceptions.

## Changes

- Introduced public `PrivateAPIPolicy` thread-safe kill-switch (`PrivateAPIPolicy.isEnabled`).
- When disabled, private layer classes (`CABackdropLayer`), private CAFilters, and private blur effect
  configurations degrade gracefully to safe public fallbacks.
- Added live runtime canary test verifying private symbol resolution.

Regression: `disabling PrivateAPIPolicy suppresses private classes and filters`,
`canary: all expected private symbols resolve or are recorded`.
