"""Deformation diff for glass (Glass Lab tool; needs numpy, pillow, scipy, scikit-image).

Deformation diff for glass: where is each pixel of the glass sampling the background from?

A background whose green and blue channels are the sine and cosine of the position (period 48 px, along x or y) carries a
code that survives blur and an additive lift: decoding the phase of a capture gives the sampled position modulo 48 px, and
unwrapping from the undistorted interior gives it exactly. Two captures (phasex, phasey) give the full sampling map
s(x, y); the displacement is s minus the pixel's own position. Comparing the maps of native glass and ours compares the
deformation alone, independent of blur and tone.
"""
import numpy as np
from PIL import Image
from skimage.restoration import unwrap_phase
from skimage.metrics import structural_similarity as ssim
P = 48.0
W = np.array([0.2126, 0.7152, 0.0722])

def load(path):
    return np.asarray(Image.open(path).convert('RGB')).astype(np.float64) / 255

def to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

def untone(img, lift=32 / 255, k=0.83, iterations=8):
    """Invert out = in + lift * (1 - k * L(in)), L the linear luminance of the input."""
    x = img.copy()
    for _ in range(iterations):
        L = (to_lin(np.clip(x, 0, 1)) * W).sum(-1, keepdims=True)
        x = img - lift * (1 - k * L)
    return x

def sampled_position(capture, axis, box, inside, far):
    """Sampling position (px, absolute) of every pixel inside the box, along `axis` (0: x, 1: y). `inside` is a mask of
    pixels belonging to the glass; `far` a mask of pixels deep inside, where the glass is undistorted."""
    y0, y1, x0, x1 = box
    img = untone(capture[y0:y1, x0:x1])
    g, b = img[..., 1] - 0.5, img[..., 2] - 0.5
    amp = np.hypot(g, b)
    phase = np.arctan2(g, b)
    valid = inside & (amp > 0.03)
    masked = np.ma.array(phase, mask=~valid)
    unwrapped = np.array(unwrap_phase(masked).filled(0.0))
    position = unwrapped / (2 * np.pi) * P - 0.5
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float64)
    own = (xs if axis == 0 else ys)
    # Anchor: a whole number of periods, so the far interior reads as undistorted.
    shift = np.round(np.median((own - position)[far & valid]) / P) * P
    return position + shift, valid

def sampling_map(capture_x, capture_y, box, inside, far):
    sx, vx = sampled_position(capture_x, 0, box, inside, far)
    sy, vy = sampled_position(capture_y, 1, box, inside, far)
    return sx, sy, vx & vy

def warp(image, sx, sy, box):
    """The background as the glass would show it with no blur and no tone: sample `image` at the sampling map."""
    from scipy.ndimage import map_coordinates
    y0, y1, x0, x1 = box
    return np.stack([map_coordinates(image[..., c], [sy - 0.0, sx - 0.0], order=1, mode='nearest') for c in range(3)], -1)

def compare(native, ours, box, inside, dist, probe):
    """native, ours: (sx, sy, valid). dist: signed distance (px, negative inside) for every pixel of the box."""
    (nx, ny, nv), (ox, oy, ov) = native, ours
    ok = nv & ov & inside
    err = np.hypot(nx - ox, ny - oy)
    out = {}
    bins = [("0-5", 0, 5), ("5-15", 5, 15), ("15-40", 15, 40), ("40-80", 40, 80), (">80", 80, 1e9)]
    for name, lo, hi in bins:
        m = ok & (-dist >= lo) & (-dist < hi)
        out[name] = (float(np.mean(err[m])) if m.any() else float('nan'), float(np.mean(err[m] < 1.0)) if m.any() else float('nan'), int(m.sum()))
    y0, y1, x0, x1 = box
    patch = probe[y0:y1, x0:x1]
    wn, wo = warp(probe, nx, ny, box), warp(probe, ox, oy, box)
    mask = ok[..., None]
    lum = lambda a: 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    # Deformation similarity: SSIM of the checker warped by each map, over the glass only.
    wn2, wo2 = np.where(mask, wn, 0.5), np.where(mask, wo, 0.5)
    score, smap = ssim(lum(wn2), lum(wo2), data_range=1.0, full=True)
    out['deformation_similarity'] = 100 * float(smap[ok].mean())
    out['mean_endpoint_error'] = float(err[ok].mean())
    out['within_1px'] = float((err[ok] < 1.0).mean())
    return out, err, ok
