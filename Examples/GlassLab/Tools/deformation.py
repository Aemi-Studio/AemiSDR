"""Deformation diff for glass (Glass Lab tool; needs numpy, pillow, scipy, scikit-image).

Deformation diff for glass: where is each pixel of the glass sampling the background from?

A background whose green and blue channels are the sine and cosine of the position (period 48 px, along x or y) carries a
code that survives symmetric blur and a neutral additive lift. The flat red channel cancels the lift AND the neutral rim
light. Unwrapping the phase, anchored in the undistorted interior, estimates the sampled position. Two captures (phasex,
phasey) give a sampling map s(x, y), in image-index coordinates (pixel i is at i, not i + 0.5). Clipped or low-amplitude
pixels are excluded. This is a probe, not an exact oracle: coloured lighting, asymmetric filtering, aliasing, disconnected
valid regions and phase changes over pi per pixel can bias it. Cross-check with dot and line backgrounds.
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
    img = capture[y0:y1, x0:x1]
    # R is 128/255, while G/B oscillate about 0.5. Any neutral additive tone or rim light affects all three equally,
    # even when its amount depends on luminance: subtracting R removes it without fitting the light's profile.
    dc = 128 / 255 - 0.5
    g, b = img[..., 1] - img[..., 0] + dc, img[..., 2] - img[..., 0] + dc
    amp = np.hypot(g, b)
    phase = np.arctan2(g, b)
    unclipped = ((img > 0.5 / 255) & (img < 254.5 / 255)).all(-1)
    connected = inside & np.isfinite(img).all(-1) & (amp > 0.03)
    valid = connected & unclipped
    if not (far & valid).any():
        raise ValueError('no valid undistorted interior to anchor the phase')
    # Use the biased phase through clipped strips only to maintain branch continuity. Masking those strips splits the
    # interior into disconnected islands, each with an arbitrary whole-period offset. Never score the clipped phase.
    masked = np.ma.array(phase, mask=~connected)
    unwrapped = np.array(unwrap_phase(masked, rng=0).filled(0.0))
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
    return np.stack([map_coordinates(image[..., c], [sy, sx], order=1, mode='nearest') for c in range(3)], -1)

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
    out['valid_fraction'] = float(ok.sum() / max(inside.sum(), 1))
    return out, err, ok
