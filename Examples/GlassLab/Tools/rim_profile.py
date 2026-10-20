"""Reproduce the measured circular/capsule rim profile (pixel units at 3x).

    python3 rim_profile.py DIR [--tag nat] [--shape circle0|capsule0] [--local]

Inputs: TAG-SHAPE-phx.png and TAG-SHAPE-phy.png. The report excludes clipped/weak phase codes and prints sample counts.
Circle/capsule normals are radial about each end's centre, not the numerical derivative of the continuous-corner field.
The arc's functional form comes from QuartzCore AIR's inner_refraction_amount / inner_refraction_inv_height chain;
60 pt amplitude and 20 pt height are inferred from captures, not observed CPU-populated uniforms. No fitting occurs here.
"""
import argparse
from pathlib import Path
import numpy as np
from deformation import load, sampling_map
from deformation_report import shape_field, CX, CY
from edge_report import local_regions

DEPTHS = [0.5, 1.5, 2.5, 3.5, 4.5, 8.5, 12.5, 20.5, 30.5, 40.5, 50.5, 60.5]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--tag', default='nat')
    parser.add_argument('--shape', choices=['circle0', 'capsule0'], default='circle0')
    parser.add_argument('--local', action='store_true')
    args = parser.parse_args()
    box, distance = shape_field(args.shape)
    y, x = np.mgrid[box[0]:box[1], box[2]:box[3]].astype(float)
    gx, gy = x + 0.5 - CX, y + 0.5 - CY
    if args.shape == 'capsule0':
        gx = np.sign(gx) * np.maximum(np.abs(gx) - 270, 0)
    magnitude = np.hypot(gx, gy)
    gx, gy = gx / np.maximum(magnitude, 1e-9), gy / np.maximum(magnitude, 1e-9)
    sx, sy, valid = sampling_map(
        load(args.directory / f'{args.tag}-{args.shape}-phx.png'),
        load(args.directory / f'{args.tag}-{args.shape}-phy.png'), box, distance < -0.45, distance < -110)
    pull = -(sx - x) * gx - (sy - y) * gy
    regions = [('all', np.ones(distance.shape, bool))]
    if args.local:
        regions += list(local_regions(args.shape, box, angles=[17, 30, 63, 77]))
    print('depth: native median pull / circular-arc prediction, valid count (no fit; pixels at 3x)')
    for label, region in regions:
        print(f'\n{args.shape}/{label}')
        for depth in DEPTHS:
            mask = valid & region & (np.abs(-distance - depth) < 0.06)
            t = np.clip(depth / 60, 0, 1)
            predicted = 180 * (1 - np.sqrt(t * (2 - t)))
            if mask.any():
                print(f'{depth:5.1f}: {np.median(pull[mask]):8.2f} / {predicted:8.2f}, n={mask.sum()}')
            else:
                print(f'{depth:5.1f}: -- (no valid samples)')


if __name__ == '__main__':
    main()
