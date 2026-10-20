# Glass Lab tools

Small Swift tools for comparing native Liquid Glass with the AemiSDR lens. Build each with `swiftc -O X.swift -o X`.

- `compare A.png B.png [x y w h] [--diff out.png]` — similarity (SSIM x 100), PSNR and per-channel error over a region, optionally a 4x difference image.
- `probe A.png x y ...` or `probe A.png --row y x0 x1 step` — pixel values.
- `crop IN OUT x y w h scale` — crop and enlarge (nearest neighbour).
- `stack OUT A.png B.png ...` — stack images vertically for side-by-side review.

The captures come from the Glass Lab app: `xcrun simctl launch <udid> studio.aemi.GlassLab --mode none|native|aemi --bg <name> --shape capsule|circle|rrect --w 300 --h 120 [--style regular|clear] [--dark 1]`, then `xcrun simctl io <udid> screenshot out.png`.

## Deformation diff (what the glass does to the background, apart from blur and tone)

`deformation.py` and `deformation_report.py` (need numpy, pillow, scipy and scikit-image) compare how native glass and ours
displace the background. Capture the lab with `--bg phasex` and `--bg phasey` (the background is a sinusoid along x or y whose
phase survives blur and an additive lift), then:

    python3 deformation_report.py DIR OURS_TAG [shape ...]

It prints, per shape, the endpoint error of the two sampling maps by depth below the edge, the share of pixels within a pixel,
and a deformation similarity: the SSIM of a checker warped by each map (geometry only). The same decode gives the exact native
profile of the rim. Chromatic aberration is not compared: native clear glass has none.
