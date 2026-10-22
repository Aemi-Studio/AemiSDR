---
status: done
blocked-by: 
date: 2026-10-22
---

# 0003 — Private KVC reads cannot crash the host

`UIScreen.displayCornerRadius` and `NSObject.requestedValues` previously used raw Objective-C KVC,
where missing or renamed keys raised `NSUnknownKeyException` and crashed the host process.

## Changes

- Routed all `VisualEffectUIView` and `_VisualEffectInternals` KVC reads and writes (`requestedValues`,
  `colorTint`, `blurEffectValue`, `setBlurEffectValue`, `scaleHintKey`) through Abysm `RuntimeObject`,
  handling unknown keys gracefully without crashing.
- Preserved `DisplayCornerSources` typed reads and priority ladder.

Regression: `requestedValues get and set on plain NSObject returns nil without raising`,
`a getter of a different type than a scalar gives nil, not a reinterpreted number`,
`reading a getter an object lacks gives nil, where key-value coding would raise`.
