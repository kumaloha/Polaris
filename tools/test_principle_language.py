#!/usr/bin/env python3
"""Regression tests for executable taste/principle language beyond intent."""

from __future__ import annotations

import copy
import importlib.util
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("level_tool", ROOT / "tools" / "level_tool.py")
assert SPEC and SPEC.loader
level_tool = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = level_tool
SPEC.loader.exec_module(level_tool)


class PrincipleLanguageTests(unittest.TestCase):
    def test_generated_levels_have_visual_grammar_and_persona_axes(self) -> None:
        visual_required = {"focal_alignment", "symmetry", "density_band", "silhouette", "anchor_layers"}
        axis_required = {
            "novelty_bias",
            "reward_bias",
            "challenge_bias",
            "strategy_bias",
            "cuteness_bias",
            "annoyance_tolerance",
        }
        for level in range(1, 11):
            with self.subTest(level=level):
                lvl = level_tool.generate_level(level, "base")
                visual = lvl["obstacle_composition"].get("visual_grammar")
                self.assertIsInstance(visual, dict)
                self.assertTrue(visual_required.issubset(visual), sorted(visual_required - set(visual or {})))
                axes = lvl["personalization"].get("persona_axes")
                self.assertIsInstance(axes, dict)
                self.assertTrue(axis_required.issubset(axes), sorted(axis_required - set(axes or {})))
                result = level_tool.validate_lvl(lvl)
                self.assertEqual(result["verdict"], "approved")
                self.assertTrue(result["visual_grammar_gate"]["valid"])
                self.assertTrue(result["personalization_gate"]["valid"])

    def test_visual_grammar_rejects_corner_gate_when_contract_says_center_column(self) -> None:
        lvl = level_tool.generate_level(5, "base")
        lvl["overlays"] = [
            entry for entry in lvl["overlays"]
            if "crystal_shell" not in level_tool.layer_names(entry.get("layers", []))
        ]
        lvl["overlays"].append(
            {
                "region": "bad_corner_gate",
                "cells": [[0, 0], [0, 1], [1, 0]],
                "layers": ["crystal_shell"],
            }
        )
        result = level_tool.validate_lvl(lvl)
        self.assertEqual(result["verdict"], "revise_visual_grammar")
        gate = result["visual_grammar_gate"]
        self.assertFalse(gate["checks"].get("focal_alignment_ok"))
        self.assertIn("E_VISUAL_FOCAL_ALIGNMENT", [e["code"] for e in gate["errors"]])

    def test_persona_axes_reject_mismatched_gender_prior(self) -> None:
        lvl = level_tool.generate_level(5, "female_prior")
        lvl["personalization"]["persona_axes"]["strategy_bias"] = 0.90
        lvl["personalization"]["persona_axes"]["challenge_bias"] = 0.85
        result = level_tool.validate_lvl(lvl)
        self.assertEqual(result["verdict"], "revise_personalization")
        self.assertIn("E_PERSONA_FEMALE_PRIOR_MISMATCH", [e["code"] for e in result["personalization_gate"]["errors"]])

    def test_episode_rhythm_rejects_consecutive_new_mechanic_reveals(self) -> None:
        levels = [level_tool.generate_level(level, "base") for level in range(1, 11)]
        rhythm = level_tool.episode_rhythm_validate_levels(levels)
        self.assertTrue(rhythm["valid"], rhythm)

        broken = copy.deepcopy(levels)
        broken[5]["progression"]["mechanic_lifecycle"] = [
            {"mechanic": "spawner", "phase": "reveal_safe", "role": "primary", "is_new": True}
        ]
        rhythm = level_tool.episode_rhythm_validate_levels(broken)
        self.assertFalse(rhythm["valid"])
        self.assertIn("E_EPISODE_NEW_REVEAL_TOO_CLOSE", [e["code"] for e in rhythm["errors"]])


if __name__ == "__main__":
    unittest.main()
