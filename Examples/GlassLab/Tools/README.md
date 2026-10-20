# Glass Lab tools

Small Swift tools for comparing native Liquid Glass with the AemiSDR lens. Build each with `swiftc -O X.swift -o X`.

- `compare A.png B.png [x y w h] [--diff out.png]` — similarity (SSIM x 100), PSNR and per-channel error over a region, optionally a 4x difference image.
- `probe A.png x y ...` or `probe A.png --row y x0 x1 step` — pixel values.
- `crop IN OUT x y w h scale` — crop and enlarge (nearest neighbour).
- `stack OUT A.png B.png ...` — stack images vertically for side-by-side review.

Install a Release Glass Lab build, then run from the repository root:

    Examples/GlassLab/Tools/capture.sh UDID OUT.png --mode native --style clear --bg grid --shape capsule --w 300 --h 120

Modes: `none`, `native`, `aemi` (old physical lens), `clear` (custom clear glass). Shapes: capsule, circle, square, rrect,
triangle; pass `--radius 0` for a native square. The script requires two identical screenshots; inspect scene identity and
retain a plain-background negative control too. Stable launch-screen captures are still wrong captures.

## Deformation diff (what the glass does to the background, apart from blur and tone)

Python tools need numpy, Pillow, scipy and scikit-image. The standard geometry assumes an iPhone 18 Pro screenshot,
1206x2622 at 3x, centre (603,1311) in pixel-boundary coordinates. Use the shapes/sizes in `deformation_report.SHAPES`.

Capture `--bg phasex-low` and `--bg phasey-low` for near-complete valid coverage, or the original `phasex`/`phasey` for
higher precision but substantial clipping. Green/blue encode sine/cosine at period 48 px; flat red cancels neutral tone
AND rim light. Save `nat-SHAPE-phx.png`, `nat-SHAPE-phy.png`, `TAG-SHAPE-phx.png`, `TAG-SHAPE-phy.png` and a plain
`none-checker.png`, then:

    python3 deformation_report.py DIR OURS_TAG [shape ...]

It prints endpoint error by depth, the share within a pixel, **valid-code coverage**, and SSIM of a checker warped by each
map. Coordinates are image indices (i), while shape distances use pixel centres (i+0.5). Clipped/weak codes are not scored;
phase continuity is maintained through clipped strips, then anchored in the undistorted interior. This is an estimate, not
an exact optical oracle: clipping, quantisation, aliasing and disconnected regions limit it. Use native clear and custom
fringing OFF. Default blur/veil/light must be neutral; coloured effects invalidate flat-red cancellation.

## Edge-local appearance and visible features

Save `nat-SHAPE-BG.png` and `TAG-SHAPE-BG.png` for `dots`, `grid`, `checker`, `complex`:

    python3 Examples/GlassLab/Tools/edge_report.py DIR TAG capsule0 circle0 --local --angles 17 30 63 77 --backgrounds dots grid --panels OUT
    python3 Examples/GlassLab/Tools/feature_report.py DIR TAG capsule0 circle0
    python3 Examples/GlassLab/Tools/rim_profile.py PHASE_DIR --shape capsule0 --local

The edge report prints RGB MAE and RGB SSIM by depth, separating left/right and top/bottom sectors. It writes labelled
native/custom/4x-error crops; **open the PNGs** for visual inspection. SSIM neighbourhoods cross band boundaries; it is not
a percentage of identical pixels. Native capsules use continuous corners; `shape_field(..., circular_capsule=True)` is a
circular control, not the native field. Continuous fields are approximate SDF depth coordinates, not Euclidean distances.

Feature counts/positions depend on contrast thresholds: a brighter rim or different blur can create/merge/suppress detected
peaks. They supplement the images and phase maps; a missing detection alone does not prove missing deformation.

## Controls

    python3 -m unittest discover -s Examples/GlassLab/Tools

Tests cover the circular control, pixel-centre geometry, a known multi-period warp under neutral lighting, clipping,
phase continuity through clipped stripes, local-score dilution, off-axis end centres and gated one-to-one feature matching.
The high-contrast decoder has finer precision but much less coverage. The low-contrast probe's undistorted interior shows
about 0.15 px endpoint error between native/custom from quantisation/filter differences; do not call that a true warp.
