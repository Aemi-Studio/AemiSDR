"""Deformation report: how closely does a glass deform the background like native clear glass does?

    python3 deformation_report.py DIR OURS_TAG [shape ...]

DIR holds captures named `nat-<shape>-phx.png`, `nat-<shape>-phy.png` (native clear glass over the position-coded
backgrounds `phasex` and `phasey`), `<OURS_TAG>-<shape>-phx.png` and `-phy.png` (the package's glass), and
`none-checker.png` (the plain checker, used to show the deformation). Shapes are those of the standard Glass Lab set.

For each shape it prints the endpoint error between the two sampling maps (px, at 3x) by depth below the edge, the share
of pixels within one pixel, and a deformation similarity: the SSIM of the checker warped by each map, which has no blur
and no tone in it, only geometry. Chromatic aberration is not compared: native clear glass has none.
"""
import sys
import numpy as np
from deformation import load, sampling_map, compare

CX, CY = 603, 1311
SHAPES = {  # key: (kind, half width pt, half height pt, radius pt)
    'square0': ('rrect', 100, 100, 0), 'capsule0': ('capsule', 150, 60, 60), 'circle0': ('capsule', 80, 80, 80),
    'rrect8': ('rrect', 150, 100, 8), 'rrect16': ('rrect', 150, 100, 16),
    'rrect32': ('rrect', 150, 100, 32), 'rrect60': ('rrect', 150, 100, 60), 'triangle0': ('tri', 110, 100, 0),
}
EXT = 1.52866495

def corner(p, b, r, m):
    R = r * EXT
    inner = R + (r - R) * max(m)
    q = p - b
    cc = q + inner
    w = np.abs(np.maximum(0, (q + R) / R))
    ln = np.sqrt((w ** 2).sum(-1)); hi = w.max(-1); lo = w.min(-1)
    t = np.where(hi == 0, 0, np.clip(lo / np.where(hi == 0, 1, hi), 0, 1))
    fit = (((-0.926054 * t + 3.15600991) * t - 3.64122009) * t + 1.26803005) * t + 0.268530995
    sq = (ln + 1) - 1 / (1 - t * t * np.clip(ln, 0, 1) * fit)
    wc = np.maximum(0, w * EXT - 0.528665)
    circ = np.sqrt((wc ** 2).sum(-1)) * 0.654165566 + 0.345834434
    ea = sq + (circ - sq) * m[0]; eb = sq + (circ - sq) * m[1]
    s = np.where(w[..., 1] > w[..., 0], 1.0, -1.0)
    f = ea + (eb - ea) * np.clip(0.5 - s + s * t, 0, 1) - 1
    return np.minimum(np.maximum(cc[..., 0], cc[..., 1]), 0) + R * f

def rrect_distance(X, Y, hx, hy, r):
    if r == 0:
        q = np.stack([np.abs(X - CX) - hx, np.abs(Y - CY) - hy], -1)
        return np.sqrt((np.maximum(q, 0) ** 2).sum(-1)) + np.minimum(np.maximum(q[..., 0], q[..., 1]), 0)
    ratio = np.array([hx / -r, hy / -r]); mm = np.clip((EXT + ratio) * 1.89155722, 0, 1)
    return corner(np.abs(np.stack([X - CX, Y - CY], -1)), np.array([hx, hy]), r, (mm[0], mm[1]))

def triangle_distance(X, Y, hx, hy):
    A = np.array([CX, CY - hy], float); B = np.array([CX + hx, CY + hy], float); C = np.array([CX - hx, CY + hy], float)
    P = np.stack([X, Y], -1); best = np.full(X.shape, 1e9)
    for a, b in [(A, B), (B, C), (C, A)]:
        ab = b - a; t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
        best = np.minimum(best, np.linalg.norm(P - (a + t[..., None] * ab), axis=-1))
    side = lambda a, b: (b[0] - a[0]) * (P[..., 1] - a[1]) - (b[1] - a[1]) * (P[..., 0] - a[0])
    inside = ((side(A, B) >= 0) & (side(B, C) >= 0) & (side(C, A) >= 0)) | ((side(A, B) <= 0) & (side(B, C) <= 0) & (side(C, A) <= 0))
    return np.where(inside, -best, best)

def shape_field(key, pad=40, circular_capsule=False):
    kind, hx, hy, r = SHAPES[key]; hx *= 3; hy *= 3; r *= 3
    box = (CY - hy - pad, CY + hy + pad, CX - hx - pad, CX + hx + pad)
    # Pixel centres: pixel i covers [i, i + 1), so its centre is at i + 0.5. Using the index instead puts opposite edges half a
    # pixel off in opposite directions, which matters where the displacement changes by several pixels per pixel.
    Y, X = np.mgrid[box[0]:box[1], box[2]:box[3]].astype(np.float64) + 0.5
    if kind == 'capsule' and (key == 'circle0' or circular_capsule):
        d = np.hypot(np.maximum(np.abs(X - CX) - (hx - r), 0), np.maximum(np.abs(Y - CY) - (hy - r), 0)) - r
    elif kind in ('rrect', 'capsule'):
        # Native capsules use the continuous field (not a circular capsule). This is the shader's depth coordinate,
        # approximately a signed distance, not an exact Euclidean distance near continuous corners.
        d = rrect_distance(X, Y, hx, hy, r)
    else:
        d = triangle_distance(X, Y, hx, hy)
    return box, d

def main():
    directory, tag = sys.argv[1], sys.argv[2]
    keys = sys.argv[3:] or ['square0', 'capsule0', 'circle0', 'rrect32', 'triangle0']
    probe = load(f'{directory}/none-checker.png')
    print('Scores use valid, unclipped codes only, at least 1.5 px inside the native field. valid = share of this interior.')
    print(f"{'shape':10s} {'deformation':>12s} {'mean EPE':>9s} {'<1px':>6s} {'valid':>6s}   endpoint error (px) by depth below the edge")
    print(f"{'':10s} {'similarity':>12s} {'(px)':>9s} {'':>6s} {'':>6s}   " + "  ".join(f"{b:>7s}" for b in ['0-5', '5-15', '15-40', '40-80', '>80']))
    for key in keys:
        box, d = shape_field(key)
        inside, far = d < -1.5, d < -110
        nat = sampling_map(load(f'{directory}/nat-{key}-phx.png'), load(f'{directory}/nat-{key}-phy.png'), box, inside, far)
        our = sampling_map(load(f'{directory}/{tag}-{key}-phx.png'), load(f'{directory}/{tag}-{key}-phy.png'), box, inside, far)
        res, _, _ = compare(nat, our, box, inside, d, probe)
        cells = "  ".join(f"{res[b][0]:7.2f}" for b in ['0-5', '5-15', '15-40', '40-80', '>80'])
        print(f"{key:10s} {res['deformation_similarity']:12.1f} {res['mean_endpoint_error']:9.2f} {100 * res['within_1px']:5.0f}% {100 * res['valid_fraction']:5.0f}%   {cells}")

if __name__ == '__main__':
    main()
