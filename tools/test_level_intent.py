#!/usr/bin/env python3
"""Regression tests for benchmark-derived level intent and board scale laws."""

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


class LevelIntentTests(unittest.TestCase):
    def test_generated_levels_have_objective_verb_skill_lesson_and_board_scale(self) -> None:
        required = {"objective_verb", "skill_lesson", "board_scale"}
        for level in range(1, 11):
            with self.subTest(level=level):
                lvl = level_tool.generate_level(level, "base")
                intent = lvl.get("level_intent")
                self.assertIsInstance(intent, dict)
                self.assertTrue(required.issubset(intent), sorted(required - set(intent or {})))
                self.assertIn(intent["objective_verb"], {"cleanse", "transport", "craft", "connect", "rescue", "mixed"})
                self.assertIn("skill", intent["skill_lesson"])
                self.assertIn("proof_signal", intent["skill_lesson"])
                self.assertIn("size", intent["board_scale"])
                self.assertIn("effective_problem_space", intent["board_scale"])

    def test_new_mechanic_reveals_use_small_problem_space(self) -> None:
        for level in (5, 9):
            with self.subTest(level=level):
                lvl = level_tool.generate_level(level, "base")
                self.assertEqual(lvl["level_intent"]["board_scale"]["effective_problem_space"], "small")
                self.assertLessEqual(lvl["map"]["width"] * lvl["map"]["height"], 49)
                self.assertLessEqual(lvl["rules"]["colors"], 4)
                self.assertGreaterEqual(lvl["meta"]["target_pass_band"][0], 0.90)
                self.assertEqual(level_tool.validate_lvl(lvl)["verdict"], "approved")

    def test_validate_exposes_intent_gate_and_rejects_missing_intent(self) -> None:
        lvl = level_tool.generate_level(9, "base")
        result = level_tool.validate_lvl(lvl)
        self.assertIn("level_intent_gate", result)
        self.assertTrue(result["level_intent_gate"]["valid"])

        missing = copy.deepcopy(lvl)
        missing.pop("level_intent")
        result = level_tool.validate_lvl(missing)
        self.assertEqual(result["verdict"], "revise_level_intent")
        self.assertFalse(result["level_intent_gate"]["valid"])
        self.assertIn("E_LEVEL_INTENT_MISSING", [e["code"] for e in result["level_intent_gate"]["errors"]])

    def test_new_mechanic_reveal_large_board_is_rejected(self) -> None:
        lvl = level_tool.generate_level(9, "base")
        lvl["map"]["width"] = 9
        lvl["map"]["height"] = 9
        lvl["board"] = ["ooooooooo" for _ in range(9)]
        for entry in lvl["overlays"]:
            if "drop_exit" in entry.get("layers", []):
                entry["cells"] = [[8, 3]]
        result = level_tool.validate_lvl(lvl)
        self.assertEqual(result["verdict"], "revise_level_intent")
        self.assertIn("E_BOARD_SCALE_NEW_REVEAL_TOO_LARGE", [e["code"] for e in result["level_intent_gate"]["errors"]])


if __name__ == "__main__":
    unittest.main()
