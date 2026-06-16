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


class ObstacleCompositionTests(unittest.TestCase):
    def test_generated_levels_include_obstacle_composition_contract(self):
        required = {
            "purpose",
            "archetype",
            "primary_blocker",
            "focus_area",
            "action_vector",
            "read_order",
            "negative_space",
            "density",
            "delete_test",
            "theme_shape",
            "beauty_rules",
        }
        for level in range(1, 11):
            with self.subTest(level=level):
                lvl = level_tool.generate_level(level)
                composition = lvl.get("obstacle_composition")
                self.assertIsInstance(composition, dict)
                self.assertTrue(required.issubset(composition), sorted(required - set(composition)))
                self.assertIsInstance(composition["read_order"], list)
                self.assertGreaterEqual(len(composition["read_order"]), 2)
                self.assertIsInstance(composition["negative_space"], dict)
                self.assertIsInstance(composition["beauty_rules"], list)
                self.assertTrue(composition["beauty_rules"])

    def test_blocker_compositions_declare_blocker_that_exists_on_board(self):
        blocker_archetypes = {"gate", "ring", "cage", "funnel", "split_lock", "bridge", "lane"}
        for level in range(1, 11):
            lvl = level_tool.generate_level(level)
            composition = lvl["obstacle_composition"]
            if composition["archetype"] not in blocker_archetypes or composition["primary_blocker"] == "none":
                continue
            with self.subTest(level=level):
                self.assertIn(composition["primary_blocker"], level_tool.active_layer_set(lvl))

    def test_validate_exposes_gate_and_rejects_missing_composition(self):
        lvl = level_tool.generate_level(5)
        result = level_tool.validate_lvl(lvl)
        self.assertEqual(result["verdict"], "approved")
        self.assertIn("obstacle_composition_gate", result)
        self.assertTrue(result["obstacle_composition_gate"]["valid"])

        missing = copy.deepcopy(lvl)
        missing.pop("obstacle_composition")
        result = level_tool.validate_lvl(missing)
        self.assertEqual(result["verdict"], "revise_obstacle_composition")
        self.assertFalse(result["obstacle_composition_gate"]["valid"])
        self.assertIn("E_OBSTACLE_COMPOSITION_MISSING", [e["code"] for e in result["obstacle_composition_gate"]["errors"]])

    def test_overwide_gate_wall_fails_composition_gate(self):
        lvl = level_tool.generate_level(5)
        lvl["overlays"] = [entry for entry in lvl["overlays"] if "crystal_gate" not in entry.get("region", "")]
        lvl["overlays"].append({
            "region": "bad_overwide_gate",
            "cells": [[3, c] for c in range(2, 7)],
            "layers": ["crystal_shell"],
        })
        result = level_tool.validate_lvl(lvl)
        self.assertEqual(result["verdict"], "revise_obstacle_composition")
        gate = result["obstacle_composition_gate"]
        self.assertFalse(gate["checks"].get("no_uniform_wall"))
        self.assertIn("E_OBSTACLE_UNIFORM_WALL", [e["code"] for e in gate["errors"]])


if __name__ == "__main__":
    unittest.main()
