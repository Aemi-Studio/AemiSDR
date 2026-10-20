---
status: done
blocked-by:
date: 2026-10-20
---

# 0017 — A rounded mask covers its corner wedges, out to the pointy corners

Regression: `every pixel outside the rounded shape is fully masked, wedges and pointy corners included`, `the outermost pixel row is fully masked whatever the fade width`, `inverted, the corner wedges are clear and the middle is covered`

A rounded-shape mask is a hole with a covered frame around it. The frame must reach all the way into the pointy corners of the rectangle: the wedge between each arc and the square corner lies outside the shape, so it is fully masked (fully clear when inverted). **Every change to a mask kernel, including per-corner radii (0016), must keep this.**

## Why it needs a test and not a look

A device's own rounded corners hide the wedges, and a simulator screenshot of a rounded device looks the same whether they are filled or not. The tests render the real Core Image kernels and compare every pixel with an independent CPU signed-distance function.

## What it found (2026-10-20)

The wedges were already filled for any radius above zero. The outermost pixel row was not: a pixel centre sits half a pixel inside the shape's edge, and the masks reached full strength only at the edge. With the eased kernels the outer row was about 88% masked at a 8 px fade and about 84% at 2 px, and with a hard edge (fade 0) it was empty. `kPixelCenterBias` (+0.5 px on the signed distance) fixes all four kernels.

Mutating the rounded-rectangle SDF and the superellipse SDF so the wedge is not filled each fail 26 assertions (corner pixel 0.0 masked); both were restored.

## Open

The superellipse masks are called with exponent 2, so they are circular arcs, not squircles (diary 2026-10-20-08). A screenshot check that samples these wedge pixels on the simulator framebuffer is still to be written.
