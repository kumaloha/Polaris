#!/usr/bin/env python3
"""Regression tests for dragon asset cleanup and foot-baseline layout."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("dragon_asset_tool", ROOT / "tools" / "dragon_asset_tool.py")
assert SPEC and SPEC.loader
module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = module
SPEC.loader.exec_module(module)


class DragonAssetLayoutTests(unittest.TestCase):
    def test_visible_bbox_is_placed_by_foot_baseline_not_texture_center(self) -> None:
        bbox = module.Rect(279, 434, 1162, 1005)
        placement = module.place_bbox_on_baseline(bbox, visible_width=440, x=430, baseline_y=284)
        expected_scale = 440 / bbox.width
        self.assertAlmostEqual(placement.scale, expected_scale, places=6)
        self.assertAlmostEqual(placement.y + bbox.bottom * placement.scale, 284, places=4)
        centered_baseline = 284 + (bbox.bottom - 720) * placement.scale
        self.assertGreater(abs(centered_baseline - 284), 100, "center anchoring would visibly miss the shared foot line")

    def test_youth_clean_filter_removes_vidu_watermark_before_chromakey(self) -> None:
        chain = module.youth_clean_filter()
        self.assertIn("drawbox", chain)
        self.assertIn("x=1190", chain)
        self.assertIn("y=1300", chain)
        self.assertLess(chain.find("drawbox"), chain.find("colorkey"), "watermark must be covered with green before chromakey")
        self.assertIn("format=rgba", chain)

    def test_baby_and_youth_preview_share_one_foot_baseline(self) -> None:
        baby = module.Rect(44, 41, 431, 459)
        youth = module.Rect(279, 434, 1162, 1005)
        baseline = 284
        baby_place = module.place_bbox_on_baseline(baby, visible_width=190, x=62, baseline_y=baseline)
        youth_place = module.place_bbox_on_baseline(youth, visible_width=420, x=450, baseline_y=baseline)
        self.assertAlmostEqual(baby_place.y + baby.bottom * baby_place.scale, baseline, places=4)
        self.assertAlmostEqual(youth_place.y + youth.bottom * youth_place.scale, baseline, places=4)

    def test_baby_frames_install_from_clean_png_sequence_not_watermarked_video(self) -> None:
        self.assertTrue(str(module.DEFAULT_BABY_SRC).endswith("resources/dragon_baby/dragon_frames"))
        self.assertTrue(str(module.DEFAULT_BABY_FRAME).endswith("godot/assets/pets/dragon_baby/frames/dragon_00.png"))
        self.assertTrue(str(module.DEFAULT_YOUTH_FRAME).endswith("godot/assets/pets/dragon_youth/frames/frame_001.png"))
        self.assertNotIn("mp4", str(module.DEFAULT_BABY_SRC).lower())
        self.assertTrue(module.has_no_bottom_right_watermark(module.DEFAULT_BABY_FRAME), "canonical baby PNG frames are already watermark-free")


if __name__ == "__main__":
    unittest.main()
