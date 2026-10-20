"""Controls for the geometry and edge-local measurements; run with `python3 -m unittest discover -s Examples/GlassLab/Tools`."""
import unittest
import numpy as np
from deformation_report import CX, CY, shape_field
from deformation import sampled_position
from edge_report import scores, local_regions
from feature_report import match


class ReportTests(unittest.TestCase):
    def test_circular_capsule_control_has_exact_circular_ends(self):
        box, distance = shape_field('capsule0', circular_capsule=True)
        y, x = np.mgrid[box[0]:box[1], box[2]:box[3]].astype(float) + 0.5
        expected = np.hypot(np.maximum(np.abs(x - CX) - 270, 0), y - CY) - 180
        np.testing.assert_allclose(distance, expected, atol=1e-9)

    def test_circle_band_distance_is_radial_off_axis(self):
        box, distance = shape_field('circle0')
        y, x = np.mgrid[box[0]:box[1], box[2]:box[3]].astype(float) + 0.5
        expected = np.hypot(x - CX, y - CY) - 240
        np.testing.assert_allclose(distance, expected, atol=1e-9)

    def test_phase_decode_cancels_neutral_rim_light_for_a_known_warp(self):
        side = 384
        y, x = np.mgrid[:side, :side].astype(float)
        depth = np.minimum.reduce([x + 0.5, y + 0.5, side - x - 0.5, side - y - 0.5])
        # An asymmetric displacement crossing two periods near the left edge; undistorted well inside.
        source_x = x + 110 * np.exp(-(x + 0.5) / 12)
        phase = 2 * np.pi * (source_x + 0.5) / 48
        rgb = np.stack([np.full(x.shape, 128 / 255), 0.5 + 0.25 * np.sin(phase), 0.5 + 0.25 * np.cos(phase)], -1)
        light = 0.18 * np.exp(-depth / 18)
        rgb = np.round((rgb + light[..., None]) * 255) / 255
        inside, far = depth > 1.5, depth > 110
        decoded, valid = sampled_position(rgb, 0, (0, side, 0, side), inside, far)
        error = np.abs(decoded - source_x)
        # Two rounded 8-bit channels are subtracted: their phase error at amplitude .25 is bounded by about .17 px.
        self.assertLess(error[valid].max(), 0.18)
        self.assertGreater((valid & (depth < 5)).sum(), 1000)

    def test_phase_decode_rejects_clipped_pixels(self):
        side = 320
        y, x = np.mgrid[:side, :side].astype(float)
        phase = 2 * np.pi * (x + 0.5) / 48
        rgb = np.stack([np.full(x.shape, 128 / 255), 0.5 + 0.4 * np.sin(phase), 0.5 + 0.4 * np.cos(phase)], -1)
        rgb[:, :30] += 0.3
        rgb = np.clip(np.round(rgb * 255) / 255, 0, 1)
        inside = np.ones(x.shape, bool)
        far = (x > 110) & (x < 210) & (y > 110) & (y < 210)
        _, valid = sampled_position(rgb, 0, (0, side, 0, side), inside, far)
        clipped = (rgb == 1).any(-1)
        self.assertGreater(clipped.sum(), 100)
        self.assertFalse(valid[clipped].any())
        self.assertGreater(valid[:, 30:].mean(), 0.95)

    def test_clipped_stripes_do_not_introduce_whole_period_offsets(self):
        side = 320
        y, x = np.mgrid[:side, :side].astype(float)
        phase = 2 * np.pi * (x + 0.5) / 48
        rgb = np.stack([np.full(x.shape, 128 / 255), 0.5 + 0.5 * np.sin(phase), 0.5 + 0.5 * np.cos(phase)], -1)
        rgb = np.clip(np.round((rgb + 0.13) * 255) / 255, 0, 1)
        far = (x > 110) & (x < 210) & (y > 110) & (y < 210)
        decoded, valid = sampled_position(rgb, 0, (0, side, 0, side), np.ones(x.shape, bool), far)
        self.assertLess(np.abs(decoded[valid] - x[valid]).max(), 0.09)
        self.assertGreater(valid.mean(), 0.4)

    def test_local_colour_error_is_not_diluted_by_the_interior(self):
        native = np.zeros((128, 128, 3))
        ours = native.copy()
        ours[:, :5] = 0.2
        edge = np.zeros((128, 128), bool)
        edge[:, :5] = True
        local = scores(native, ours, edge)
        whole = scores(native, ours, np.ones(edge.shape, bool))
        self.assertAlmostEqual(local['mae'], 51)
        self.assertLess(whole['mae'], 2)
        identity = scores(native, native, edge)
        self.assertEqual(identity['mae'], 0)
        self.assertEqual(identity['ssim'], 100)

    def test_capsule_local_regions_use_the_end_centres_not_the_shape_centre(self):
        box, _ = shape_field('capsule0')
        regions = dict(local_regions('capsule0', box, angles=[30], half_window=5))
        # A location just inside the right circular end at +30 degrees, measured from (CX + 270, CY).
        x, y = CX + 270 + 170 * np.cos(np.pi / 6), CY + 170 * np.sin(np.pi / 6)
        row, col = int(y) - box[0], int(x) - box[2]
        self.assertTrue(regions['R+30'][row, col])
        self.assertFalse(regions['R-30'][row, col])
        self.assertFalse(regions['L+30'][row, col])
        self.assertFalse(regions['straight-top'][row, col])

    def test_feature_matching_maximises_matches_inside_the_gate(self):
        # Unconstrained Hungarian assignment chooses distances 0 and sqrt(32) (one valid pair) rather than 4 and 4.
        # A gated match must choose two valid pairs before minimising their total distance.
        n = np.array([[0., 0.], [4., 0.]])
        o = np.array([[0., 0.], [0., 4.]])
        pairs, count = match(n, o, radius=4)
        self.assertEqual(count, 2)
        self.assertTrue(all(e <= 4 for _, _, e in pairs))


if __name__ == '__main__':
    unittest.main()
