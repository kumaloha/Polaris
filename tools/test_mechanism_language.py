#!/usr/bin/env python3
"""Regression tests for the executable mechanism-spec foundation."""

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


class MechanismLanguageTests(unittest.TestCase):
    def test_generated_levels_have_specs_for_every_active_atom(self) -> None:
        required = {
            "mechanic_id",
            "category",
            "state_dynamics",
            "player_action",
            "board_effect",
            "reward_effect",
            "compatible_objective_verbs",
            "compatible_terrain",
            "intro_rule",
            "mixing_rule",
            "simulator_hook",
            "godot_support",
        }
        for level in range(1, 11):
            with self.subTest(level=level):
                lvl = level_tool.generate_level(level, "base")
                specs = lvl.get("mechanism_specs")
                self.assertIsInstance(specs, dict)
                active = level_tool.mechanism_atoms_for_lvl(lvl)
                self.assertTrue(active.issubset(set(specs)), sorted(active - set(specs or {})))
                for mechanic_id in active:
                    spec = specs[mechanic_id]
                    self.assertTrue(required.issubset(spec), sorted(required - set(spec)))
                    self.assertEqual(spec["mechanic_id"], mechanic_id)
                    self.assertIn(spec["state_dynamics"], {"static", "self_evolving", "actor_moving"})

                result = level_tool.validate_lvl(lvl)
                self.assertEqual(result["verdict"], "approved")
                self.assertTrue(result["mechanism_spec_gate"]["valid"])

    def test_missing_active_mechanism_spec_is_rejected(self) -> None:
        lvl = level_tool.generate_level(5, "base")
        lvl["mechanism_specs"].pop("crystal_shell")
        result = level_tool.validate_lvl(lvl)
        self.assertEqual(result["verdict"], "revise_mechanism_spec")
        self.assertIn("E_MECHANISM_SPEC_MISSING_ACTIVE", [e["code"] for e in result["mechanism_spec_gate"]["errors"]])

    def test_incompatible_mechanism_spec_is_rejected(self) -> None:
        lvl = level_tool.generate_level(5, "base")
        lvl["mechanism_specs"]["crystal_shell"]["compatible_objective_verbs"] = ["transport"]
        result = level_tool.validate_lvl(lvl)
        self.assertEqual(result["verdict"], "revise_mechanism_spec")
        self.assertIn("E_MECHANISM_SPEC_OBJECTIVE_INCOMPATIBLE", [e["code"] for e in result["mechanism_spec_gate"]["errors"]])

    def test_playable_active_mechanism_requires_simulator_and_godot_support(self) -> None:
        lvl = level_tool.generate_level(9, "base")
        lvl["mechanism_specs"]["drop_relic"]["simulator_hook"]["supported"] = False
        result = level_tool.validate_lvl(lvl)
        self.assertEqual(result["verdict"], "revise_mechanism_spec")
        self.assertIn("E_MECHANISM_SPEC_SIM_UNSUPPORTED", [e["code"] for e in result["mechanism_spec_gate"]["errors"]])

        lvl = level_tool.generate_level(9, "base")
        lvl["mechanism_specs"]["drop_relic"]["godot_support"]["playable_v0"] = False
        result = level_tool.validate_lvl(lvl)
        self.assertEqual(result["verdict"], "revise_mechanism_spec")
        self.assertIn("E_MECHANISM_SPEC_GODOT_UNSUPPORTED", [e["code"] for e in result["mechanism_spec_gate"]["errors"]])


if __name__ == "__main__":
    unittest.main()
