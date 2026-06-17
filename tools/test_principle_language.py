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

    def test_first_ten_rhythm_curve_has_no_size_hp_or_move_cliff(self) -> None:
        levels = [level_tool.generate_level(level, "base") for level in range(1, 11)]
        moves = [lvl["rules"]["moves"] for lvl in levels]
        areas = [lvl["map"]["width"] * lvl["map"]["height"] for lvl in levels]
        self.assertLessEqual(areas[3], 49, "level 4 should not jump to a 9x9 long board before the blocker reveal")
        self.assertLessEqual(moves[9], 34, "level 10 finale should be a compact route puzzle, not a 58-move drag")
        for prev, curr in zip(moves, moves[1:]):
            self.assertLessEqual(abs(curr - prev), 14, f"move budget cliff is too large: {moves}")

        for level in (5, 6):
            lvl = level_tool.generate_level(level, "base", candidate=5)
            compiled, diag = level_tool.compile_lvl(lvl)
            self.assertTrue(diag.ok, diag.to_json())
            max_hp = max((value for row in compiled["coat"] for value in row), default=0)
            self.assertLessEqual(max_hp, 1, f"level {level} intro/breather shells must stay one-hit even under hard candidate tuning")
            self.assertLessEqual(lvl["rules"]["colors"], 4, f"level {level} should keep the first blocker loop readable")

    def test_generate_select_can_start_a_fresh_candidate_batch(self) -> None:
        result = level_tool.generate_select(1, "base", "balanced", candidates=1, runs=1, candidate_start=18)
        self.assertEqual(result["candidate_start"], 18)
        self.assertEqual(result["attempts"][0]["candidate"], 18)
        self.assertEqual(result["attempts"][0]["level_id"], "level_001_base_c18")

    def test_crystal_shell_after_reveal_has_visible_stage_density(self) -> None:
        minimum_shell_cells = {
            5: 6,
            6: 8,
            8: 12,
            10: 8,
        }
        for level, minimum in minimum_shell_cells.items():
            with self.subTest(level=level):
                lvl = level_tool.generate_level(level, "base", candidate=10)
                shell_cells = level_tool.crystal_shell_cells(lvl)
                self.assertGreaterEqual(
                    len(shell_cells),
                    minimum,
                    f"level {level} needs enough ice blocks to read as a designed stage, not sparse decoration",
                )


if __name__ == "__main__":
    unittest.main()
