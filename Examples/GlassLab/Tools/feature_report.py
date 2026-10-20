"""Feature tracking report: are the points and lines of the background deformed the same way as in native glass?

    python3 feature_report.py DIR OURS_TAG [shape ...]

DIR holds `nat-<shape>-dots.png`, `nat-<shape>-grid.png` (native clear glass over the dot and grid backgrounds) and the same
with `<OURS_TAG>` for the package's glass. The dots are 4 px squares every 24 px, the grid is 2 px lines every 32 px.

Points: blobs are found in both captures (local maxima of the image minus its own blur) and matched one to one within 4 px.
Recall is the share of detected native peaks we reproduce, precision the share of ours detected in native, and the error
is how far the matched ones are apart. These are threshold-dependent diagnostics, not proof of a missing optical feature:
blur, highlights and a repeated lattice can create, merge or suppress peaks. Inspect labelled edge crops as well. Lines: ridges are skeletonised; recall is the share of native line pixels that have one of
ours within 2 px, precision the reverse. Everything is by depth below the edge, because the edge is where the glass folds the
background and a missing point or line shows. Chromatic aberration is not compared: native clear glass has none.
"""
import sys
import numpy as np
from scipy.ndimage import gaussian_filter, distance_transform_edt
from scipy.optimize import linear_sum_assignment
from skimage.feature import peak_local_max
from skimage.morphology import skeletonize
from deformation import load
from deformation_report import SHAPES, shape_field

BINS = [("0-5", 0, 5), ("5-15", 5, 15), ("15-40", 15, 40), ("40-80", 40, 80)]

def luma(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]

def points(image, box, depth, fraction=0.4):
    """Blobs brighter than `fraction` of the typical interior dot of the same image, so both captures are held to the same
    standard whatever their absolute contrast (a fixed threshold flips dots that sit near it)."""
    y0, y1, x0, x1 = box
    sub = luma(image[y0:y1, x0:x1])
    top = sub - gaussian_filter(sub, 6)
    found = peak_local_max(top, min_distance=2, threshold_abs=0.004, exclude_border=False)
    if not len(found):
        return np.empty((0, 2))
    heights = np.array([top[y, x] for y, x in found])
    deep = np.array([-depth[y, x] > 80 for y, x in found])
    reference = np.median(heights[deep]) if deep.any() else np.median(heights)
    keep = [(y, x) for (y, x), h in zip(found, heights) if h >= fraction * reference and -depth[y, x] > 1.5]
    return np.array(keep, dtype=float).reshape(-1, 2)

def lines(image, box):
    y0, y1, x0, x1 = box
    sub = luma(image[y0:y1, x0:x1])
    ridge = (sub - gaussian_filter(sub, 5)) > 0.03
    return skeletonize(ridge)

def match(native, ours, radius=4.0):
    if len(native) == 0 or len(ours) == 0:
        return [], 0
    distance = np.linalg.norm(native[:, None, :] - ours[None, :, :], axis=-1)
    # An ungated assignment can sacrifice several in-radius matches to reduce long, invalid distances. Prioritise the
    # maximum count of valid pairs, then their total distance; even all valid distances together cost less than one miss.
    penalty = (min(len(native), len(ours)) + 1) * max(radius, 1)
    cost = np.where(distance <= radius, distance, penalty)
    rows, cols = linear_sum_assignment(cost)
    pairs = [(r, c, distance[r, c]) for r, c in zip(rows, cols) if distance[r, c] <= radius]
    return pairs, len(pairs)

def main():
    directory, tag = sys.argv[1], sys.argv[2]
    keys = sys.argv[3:] or ['square0', 'capsule0', 'circle0', 'rrect32', 'triangle0']
    print("POINTS (dots background): native count, our count, recall / precision, mean position error (px), by depth below the edge")
    print(f"{'shape':10s}" + "".join(f"{b[0]:>26s}" for b in BINS))
    for key in keys:
        box, d = shape_field(key)
        nat, our = load(f'{directory}/nat-{key}-dots.png'), load(f'{directory}/{tag}-{key}-dots.png')
        pn, po = points(nat, box, d), points(our, box, d)
        pairs, _ = match(pn, po)
        matched_n = {r for r, c, e in pairs}; matched_o = {c for r, c, e in pairs}
        row = f"{key:10s}"
        for name, lo, hi in BINS:
            inbin = lambda p: np.array([lo <= -d[int(y), int(x)] < hi for y, x in p]) if len(p) else np.array([], bool)
            bn, bo = inbin(pn), inbin(po)
            nn, no = int(bn.sum()), int(bo.sum())
            rec = sum(1 for i in matched_n if bn[i]) / max(nn, 1)
            pre = sum(1 for j in matched_o if bo[j]) / max(no, 1)
            err = np.mean([e for r, c, e in pairs if bn[r]]) if any(bn[r] for r, c, e in pairs) else float('nan')
            row += f"   {nn:3d}/{no:3d} {100 * rec:3.0f}%/{100 * pre:3.0f}% {err:4.1f}"
        print(row)
    print()
    print("LINES (grid background): line pixels native / ours, recall / precision within 2 px, by depth below the edge")
    print(f"{'shape':10s}" + "".join(f"{b[0]:>26s}" for b in BINS))
    for key in keys:
        box, d = shape_field(key)
        nat, our = load(f'{directory}/nat-{key}-grid.png'), load(f'{directory}/{tag}-{key}-grid.png')
        sn, so = lines(nat, box), lines(our, box)
        dn, do = distance_transform_edt(~sn), distance_transform_edt(~so)
        row = f"{key:10s}"
        for name, lo, hi in BINS:
            region = (-d >= lo) & (-d < hi)
            n, o = sn & region, so & region
            rec = float((do[n] <= 2).mean()) if n.any() else float('nan')
            pre = float((dn[o] <= 2).mean()) if o.any() else float('nan')
            row += f"   {int(n.sum()):4d}/{int(o.sum()):4d}    {100 * rec:3.0f}%/{100 * pre:3.0f}%  "
        print(row)

if __name__ == '__main__':
    main()
