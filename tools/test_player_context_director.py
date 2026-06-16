#!/usr/bin/env python3
"""Regression tests for player-context-driven next-level direction."""

from __future__ import annotations

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


class PlayerContextDirectorTests(unittest.TestCase):
    def test_failed_current_level_generates_recovery_brief_for_same_coordinate(self) -> None:
        context = {
            "player_id": "p_fail_5",
            "cold_start_prior": "female",
            "played_levels": [
                {"level_coordinate": 1, "won": True, "attempts": 1, "moves_left": 4},
                {"level_coordinate": 2, "won": True, "attempts": 2, "moves_left": 1},
                {"level_coordinate": 3, "won": True, "attempts": 1, "moves_left": 5},
                {"level_coordinate": 4, "won": True, "attempts": 2, "moves_left": 0},
                {"level_coordinate": 5, "won": False, "attempts": 3, "fail_reasons": {"out_of_moves": 3}},
                {"level_coordinate": 5, "won": False, "attempts": 2, "fail_reasons": {"out_of_moves": 2}},
            ],
        }
        normalized = level_tool.normalize_player_context(context)
        rhythm = level_tool.derive_rhythm_state(normalized)
        brief = level_tool.build_next_level_brief(normalized, rhythm)

        self.assertEqual(brief["level_coordinate"], 5, "a failed level should be regenerated for the same coordinate")
        self.assertEqual(brief["rhythm_role"], "breather_recovery")
        self.assertEqual(brief["variant"], "assisted")
        self.assertGreaterEqual(brief["target_pass_band"][0], 0.88)
        self.assertTrue(brief["reward_budget"]["required"], "recovery should add a real board reward safety valve")
        self.assertIn("avoid_new_mechanic_escalation", brief["negative_space"]["forbid"])

    def test_new_mechanic_onboarding_uses_small_problem_space_and_high_pass_band(self) -> None:
        context = {
            "player_id": "p_ready_5",
            "cold_start_prior": "female",
            "played_levels": [
                {"level_coordinate": 1, "won": True, "attempts": 1, "moves_left": 5},
                {"level_coordinate": 2, "won": True, "attempts": 1, "moves_left": 3},
                {"level_coordinate": 3, "won": True, "attempts": 1, "moves_left": 4},
                {"level_coordinate": 4, "won": True, "attempts": 2, "moves_left": 2},
            ],
        }
        normalized = level_tool.normalize_player_context(context)
        rhythm = level_tool.derive_rhythm_state(normalized)
        brief = level_tool.build_next_level_brief(normalized, rhythm)

        self.assertEqual(brief["level_coordinate"], 5)
        self.assertEqual(brief["mechanic_lifecycle_phase"], "reveal_safe")
        self.assertEqual(brief["rhythm_role"], "new_mechanic_onboarding")
        self.assertEqual(brief["board_scale"]["effective_problem_space"], "small")
        self.assertGreaterEqual(brief["target_pass_band"][0], 0.90)
        self.assertEqual(brief["target_profile"], "female_prior")

    def test_behavior_axes_can_override_cold_start_prior(self) -> None:
        context = {
            "player_id": "p_strategy",
            "cold_start_prior": "female",
            "persona_axes": {
                "novelty_bias": 0.30,
                "reward_bias": 0.30,
                "challenge_bias": 0.86,
                "strategy_bias": 0.90,
                "cuteness_bias": 0.20,
                "annoyance_tolerance": 0.56,
            },
            "played_levels": [{"level_coordinate": 1, "won": True, "attempts": 1, "moves_left": 7}],
        }
        normalized = level_tool.normalize_player_context(context)
        self.assertEqual(normalized["target_profile"], "male_prior", "observed behavior should override demographic prior")
        self.assertEqual(normalized["profile_source"], "behavior_axes")

    def test_generate_next_attaches_context_director_contract_to_selected_level(self) -> None:
        context = {"player_id": "new_player", "cold_start_prior": "unknown", "played_levels": []}
        result = level_tool.generate_next(context, candidates=2, runs=2)
        self.assertEqual(result["verdict"], "selected", result)
        selected = result["selected"]
        self.assertIsInstance(selected, dict)
        self.assertEqual(selected["meta"]["level_coordinate"], 1)
        self.assertIn("player_context_director", selected)
        self.assertEqual(selected["player_context_director"]["brief"]["level_coordinate"], 1)
        self.assertIn("rhythm_state", selected["player_context_director"])
        self.assertEqual(selected["personalization"]["context_profile"], result["brief"]["target_profile"])


if __name__ == "__main__":
    unittest.main()
