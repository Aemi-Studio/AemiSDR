---
status: pending
blocked-by: 0002
date: 2026-10-20
---

# 0016 — Per-corner masks, rotation, and the Duo's inner display

`DisplayCornerRadii` is per corner, but `MaskType`'s shape kernels, `VariableBlurUIView` and `AlphaMaskUIView` take one `cornerRadius`.

## Probes

- A rounded-rect SDF with four radii (the shader already computes a signed distance): visual and numeric tests of 8/59/8/59.
- Rotation: which corners the configuration reports in landscape. Needs a way to rotate the simulator, or a device.
- The inner display (2007×2853, 55 on all four per the device profile): whether a scene can be shown on it in the simulator.
- Whether `UIScreen._exclusionArea` (the camera cutout) should feed the safe-area logic.

## Invariant to keep

The corner wedges stay fully covered (0017). The per-corner kernels must pass the same "every pixel outside the shape" scan with different radii per corner, including a zero-radius corner that stays pointy.

## What lands

Four-radius kernels, mask-cache keys that carry four radii, and the rotation mapping with its probe in the diary.
