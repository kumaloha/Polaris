#!/usr/bin/env python3
"""Regression tests for the executable level progression grammar."""

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


class LevelProgressionGrammarTests(unittest.TestCase):
    def test_generated_first_ten_levels_have_progression_contract(self) -> None:
        required_fields = {
            "episode",
            "mechanic_lifecycle",
            "reward_budget",
            "annoyance_budget",
            "difficulty_rhythm",
        }
        for level in range(1, 11):
            with self.subTest(level=level):
                lvl = level_tool.generate_level(level, "base")
                progression = lvl.get("progression")
                self.assertIsInstance(progression, dict)
                self.assertTrue(required_fields.issubset(progression.keys()))

                protagonist = lvl["level_design"]["roles"]["protagonist"]["mechanism"]
                lifecycle = progression["mechanic_lifecycle"]
                self.assertIsInstance(lifecycle, list)
                self.assertTrue(
                    any(
                        item.get("mechanic") == protagonist and item.get("role") == "primary"
                        for item in lifecycle
                    ),
                    f"{lvl['id']} lifecycle must include primary protagonist {protagonist}",
                )

                self.assertIn("slot", progression["episode"])
                self.assertIn("arc_role", progression["episode"])
                self.assertIn("target_pass_band", progression["difficulty_rhythm"])
                self.assertIn("max_reshuffle_rate", progression["annoyance_budget"])
                self.assertIn("max_no_progress_turn_rate", progression["annoyance_budget"])
                self.assertIn("primitives", progression["reward_budget"])

    def test_reward_primitives_are_machine_readable_and_compile_to_fx(self) -> None:
        reward_levels = [2, 5, 10]
        for level in reward_levels:
            with self.subTest(level=level):
                lvl = level_tool.generate_level(level, "base")
                primitives = lvl["progression"]["reward_budget"]["primitives"]
                self.assertTrue(primitives, f"{lvl['id']} should have at least one reward primitive")
                compiled, diag = level_tool.compile_lvl(lvl)
                self.assertTrue(diag.ok, diag.to_json())
                self.assertIsNotNone(compiled)
                fx_cells = sum(1 for row in compiled["fx"] for value in row if value > 0)
                self.assertGreater(fx_cells, 0, f"{lvl['id']} reward primitives must compile into fx")

    def test_validate_reports_progression_gate_and_rejects_missing_lifecycle(self) -> None:
        lvl = level_tool.generate_level(5, "base")
        valid_result = level_tool.validate_lvl(lvl)
        self.assertIn("progression", valid_result)
        self.assertTrue(valid_result["progression"]["valid"], valid_result["progression"])

        broken = copy.deepcopy(lvl)
        broken["progression"]["mechanic_lifecycle"] = []
        broken_result = level_tool.validate_lvl(broken)
        self.assertEqual("revise_progression", broken_result["verdict"])
        self.assertFalse(broken_result["progression"]["valid"])

    def test_simulator_reports_annoyance_proxies(self) -> None:
        lvl = level_tool.generate_level(5, "base")
        sim = level_tool.simulate_lvl(lvl, runs=3, profile="balanced")
        self.assertTrue(sim["valid"], sim)
        for key in (
            "aggregate_reshuffle_rate",
            "aggregate_dead_board_rate",
            "aggregate_no_progress_turn_rate",
            "aggregate_luck_dependency_proxy",
            "aggregate_annoyance_score",
        ):
            self.assertIn(key, sim)
            self.assertGreaterEqual(sim[key], 0.0)
            self.assertLessEqual(sim[key], 1.0)


if __name__ == "__main__":
    unittest.main()
