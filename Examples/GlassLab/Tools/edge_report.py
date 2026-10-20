"""Edge-local colour and SSIM measurements; never use a whole-image score as evidence of edge parity.

    python3 edge_report.py DIR OURS_TAG [shape ...] [--local] [--angles 17 30 63] [--backgrounds dots grid]

Captures: `nat-<shape>-<bg>.png` and `<OURS_TAG>-<shape>-<bg>.png`, at the standard 3x lab size/position. Bands are in
pixels. --local separates capsule straights and off-axis sectors on BOTH ends (or both halves of a circle), without
folding top/bottom or left/right together. Angles run from the outward horizontal towards the bottom (+) or top (-).
SSIM uses a 7x7 neighbourhood, including neighbours outside the selected band; RGB MAE uses only selected pixels.
--panels DIR writes labelled native/ours/4x-error crops at those angles, enlarged with nearest-neighbour sampling.
"""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from skimage.metrics import structural_similarity as ssim
from deformation import load
from deformation_report import SHAPES, shape_field, CX, CY

BANDS = [('out 0-4', -4, 0), ('in 0-5', 0, 5), ('in 5-15', 5, 15), ('in 15-40', 15, 40), ('in >40', 40, np.inf)]


def scores(native, ours, mask, similarity=None):
    count = int(mask.sum())
    if not count:
        return dict(count=0, mae=float('nan'), ssim=float('nan'))
    if similarity is None:
        _, similarity = ssim(native, ours, data_range=1.0, channel_axis=-1, full=True)
        similarity = similarity.mean(-1)
    error = np.abs(native - ours).mean(-1) * 255
    return dict(count=count, mae=float(error[mask].mean()), ssim=100 * float(similarity[mask].mean()))


def local_regions(key, box, angles=(17, 30, 63), half_window=5):
    y, x = np.mgrid[box[0]:box[1], box[2]:box[3]].astype(float) + 0.5
    kind, hx, hy, radius = SHAPES[key]
    if kind == 'capsule':
        offset = (hx - radius) * 3
        for side, sign in [('L', -1), ('R', 1)]:
            dx = sign * (x - CX) - offset
            end = dx >= 0
            angle = np.degrees(np.arctan2(y - CY, dx))
            for a in angles:
                for direction in [-1, 1]:
                    value = direction * a
                    yield f'{side}{value:+g}', end & (np.abs(angle - value) < half_window)
        if offset > 0:
            yield 'straight-top', (np.abs(x - CX) < offset) & (y < CY)
            yield 'straight-bottom', (np.abs(x - CX) < offset) & (y >= CY)
    elif kind == 'tri':
        p = np.stack([x, y], -1)
        a, b, c = np.array([CX, CY - hy * 3]), np.array([CX + hx * 3, CY + hy * 3]), np.array([CX - hx * 3, CY + hy * 3])
        distances = []
        for start, end in [(a, b), (b, c), (c, a)]:
            ab = end - start
            t = np.clip(((p - start) @ ab) / (ab @ ab), 0, 1)
            distances.append(np.linalg.norm(p - (start + t[..., None] * ab), axis=-1))
        nearest = np.argmin(distances, axis=0)
        for index, label in enumerate(['right-slope', 'base', 'left-slope']):
            yield label, nearest == index
    else:
        # Split sides and corner neighbourhoods, rather than letting the long straight edges hide corner errors.
        extent = radius * 3 * 1.52866495
        corner = (np.abs(x - CX) > hx * 3 - extent) & (np.abs(y - CY) > hy * 3 - extent) if radius else np.zeros(x.shape, bool)
        for sx, sy, label in [(-1, -1, 'corner-TL'), (1, -1, 'corner-TR'), (-1, 1, 'corner-BL'), (1, 1, 'corner-BR')]:
            if radius:
                yield label, corner & (sx * (x - CX) >= 0) & (sy * (y - CY) >= 0)
        horizontal = hy * 3 - np.abs(y - CY) < hx * 3 - np.abs(x - CX)
        for label, mask in [('top', horizontal & (y < CY)), ('bottom', horizontal & (y >= CY)),
                            ('left', ~horizontal & (x < CX)), ('right', ~horizontal & (x >= CX))]:
            yield label, mask & ~corner


def panels(native, ours, key, background, tag, angles, directory):
    kind, hx, hy, radius = SHAPES[key]
    if kind != 'capsule':
        return
    directory.mkdir(parents=True, exist_ok=True)
    for side, sign in [('L', -1), ('R', 1)]:
        for angle in angles:
            for direction in [-1, 1]:
                a = np.deg2rad(direction * angle)
                x = CX + sign * ((hx - radius) * 3 + (radius * 3 - 8) * np.cos(a))
                y = CY + (radius * 3 - 8) * np.sin(a)
                x0, y0 = int(round(x)) - 32, int(round(y)) - 32
                patches = [native[y0:y0+64, x0:x0+64], ours[y0:y0+64, x0:x0+64],
                           np.minimum(np.abs(native - ours)[y0:y0+64, x0:x0+64] * 4, 1)]
                canvas = Image.new('RGB', (3 * 256, 280), '#202020')
                draw = ImageDraw.Draw(canvas)
                for column, (label, patch) in enumerate(zip(['native clear', tag, 'absolute RGB error x4'], patches)):
                    canvas.paste(Image.fromarray(np.round(patch * 255).astype('uint8')).resize((256, 256), Image.Resampling.NEAREST), (column * 256, 24))
                    draw.text((column * 256 + 8, 5), label, fill='white')
                canvas.save(directory / f'{key}-{side}{direction * angle:+g}-{background}.png')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('tag')
    parser.add_argument('shapes', nargs='*', default=['square0', 'capsule0', 'circle0', 'rrect32', 'triangle0'])
    parser.add_argument('--local', action='store_true')
    parser.add_argument('--angles', type=float, nargs='+', default=[17, 30, 63])
    parser.add_argument('--backgrounds', nargs='+', default=['dots', 'grid', 'checker', 'complex'])
    parser.add_argument('--panels', type=Path)
    args = parser.parse_args()
    print('Each cell: RGB MAE / RGB SSIM x100 (not a percentage of matching pixels). Units: pixels at 3x.')
    print(f"{'shape/bg/region':40s}" + ''.join(f'{b[0]:>15s}' for b in BANDS) + f"{'shape + ring':>15s}")
    for key in args.shapes:
        box, d = shape_field(key, pad=60)
        y0, y1, x0, x1 = box
        regions = [('all', np.ones(d.shape, bool))]
        if args.local:
            regions += list(local_regions(key, box, args.angles))
        for bg in args.backgrounds:
            full_n = load(args.directory / f'nat-{key}-{bg}.png')
            full_o = load(args.directory / f'{args.tag}-{key}-{bg}.png')
            native, ours = full_n[y0:y1, x0:x1], full_o[y0:y1, x0:x1]
            _, similarity = ssim(native, ours, data_range=1.0, channel_axis=-1, full=True)
            similarity = similarity.mean(-1)
            for label, region in regions:
                row = f'{key}/{bg}/{label:20s}'.ljust(40)
                masks = [(-d >= lo) & (-d < hi) for _, lo, hi in BANDS] + [d < 4]
                for band in masks:
                    result = scores(native, ours, region & band, similarity)
                    row += f"{result['mae']:7.1f}/{result['ssim']:5.1f}  " if result['count'] else '      --       '
                print(row)
            if args.panels:
                panels(full_n, full_o, key, bg, args.tag, args.angles, args.panels)


if __name__ == '__main__':
    main()
