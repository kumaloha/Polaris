#!/usr/bin/env python3
"""Minimal v0 level tooling for Polaris `.lvl` JSON Profile.

The v0 executable profile deliberately uses strict JSON with a `.lvl`
extension, so the compiler can run with Python's standard library and the
Godot side can keep consuming ordinary level JSON records.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import random
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


PLAYABLE_TOKENS = set("o~msvnbre123456")
SUPPORTED_OBJECTIVES = {
    "cleanse_marks",
    "collect",
    "drop_relic",
    "clear_shells",
    "clear_creep",
    "defuse_cores",
    "score",
    "order_color",
}
UNSUPPORTED_MECHANISMS = {
    "starlight_cub",
    "star_circuit",
    "route_companion",
    "resonance_core",
    "star_nest",
}
SUPPORTED_TOPOLOGY = {"vertical_down", "split_columns"}
FORBIDDEN_GENERATED_OBJECTIVES = {"collect", "order_color"}
REWARD_LAYER_TO_FX = {
    "line_h_gem": 1,
    "line_v_gem": 2,
    "burst_gem": 3,
    "color_bomb_gem": 4,
}
NON_MECHANISM_LAYERS = {"drop_exit", *REWARD_LAYER_TO_FX.keys()}


TERRAIN_TEMPLATES: dict[str, list[str]] = {
    "open_7x7": [
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "ooooooo",
    ],
    "open_9x9": [
        "ooooooooo",
        "ooooooooo",
        "ooooooooo",
        "ooooooooo",
        "ooooooooo",
        "ooooooooo",
        "ooooooooo",
        "ooooooooo",
        "ooooooooo",
    ],
    "open_7x9": [
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "ooooooo",
    ],
    "funnel_7x7": [
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "ooooooo",
        ".ooooo.",
        ".ooooo.",
        "..ooo..",
    ],
    "bottleneck_7x9": [
        "ooooooo",
        "ooooooo",
        "ooooooo",
        ".ooooo.",
        ".ooooo.",
        "..ooo..",
        "..ooo..",
        "..ooo..",
        "..ooo..",
    ],
    "bottleneck_9x9": [
        "ooooooooo",
        "ooooooooo",
        ".ooooooo.",
        ".ooooooo.",
        "..ooooo..",
        "..ooooo..",
        "...ooo...",
        "...ooo...",
        "...ooo...",
    ],
    "island_9x9": [
        "ooooooooo",
        "ooooooooo",
        "ooo...ooo",
        "oo.....oo",
        "oo.....oo",
        "oo.....oo",
        "ooo...ooo",
        "ooooooooo",
        "ooooooooo",
    ],
    "fork_9x9": [
        "ooooooooo",
        "ooooooooo",
        "oooo.oooo",
        "oooo.oooo",
        "ooooooooo",
        "oo..o..oo",
        "oo..o..oo",
        "ooooooooo",
        "ooooooooo",
    ],
    "split_columns_9x9": [
        "oooo.oooo",
        "oooo.oooo",
        "oooo.oooo",
        "oooo.oooo",
        "oooo.oooo",
        "oooo.oooo",
        "oooo.oooo",
        "oooo.oooo",
        "oooo.oooo",
    ],
}


ROLE_DEFAULTS: dict[str, dict[str, Any]] = {
    "teaching": {"colors": 4, "moves": 16},
    "teaching_breather": {"colors": 4, "moves": 18},
    "variation": {"colors": 5, "moves": 20},
    "pressure_lite": {"colors": 5, "moves": 24},
    "pressure": {"colors": 5, "moves": 26},
    "breather": {"colors": 5, "moves": 20},
}


LEVEL_COORDINATES: dict[int, dict[str, Any]] = {
    1: {
        "role": "teaching",
        "complexity_tier": 0,
        "theme": "forest_ruins",
        "terrain": "open_7x7",
        "target_pass_band": [0.92, 1.00],
        "eye": "cleanse_direct",
        "objective": {"type": "cleanse_marks", "target": "all"},
        "placements": ["center_marks_7x7"],
        "intent": "教玩家“星尘印记=要净化的目标”。",
        "control": "direct_match",
    },
    2: {
        "role": "variation",
        "complexity_tier": 1,
        "theme": "forest_ruins",
        "terrain": "open_7x7",
        "colors": 4,
        "moves": 22,
        "target_pass_band": [0.78, 0.92],
        "eye": "cleanse_edge",
        "objective": {"type": "cleanse_marks", "target": "all"},
        "placements": ["edge_marks_7x7"],
        "reward_placements": ["edge_line_reward_7x7"],
        "intent": "同目标换到边缘，训练目标位置变化。",
        "control": "edge_targeting",
    },
    3: {
        "role": "teaching_breather",
        "complexity_tier": 1,
        "theme": "crystal_workshop",
        "terrain": "open_7x7",
        "target_pass_band": [0.90, 1.00],
        "eye": "cleanse_trail",
        "objective": {"type": "cleanse_marks", "target": "all"},
        "placements": ["trail_marks_7x7"],
        "intent": "换一种星尘印记分布，不再用指定颜色收集当目标。",
        "control": "target_path_reading",
    },
    4: {
        "role": "variation",
        "complexity_tier": 1,
        "theme": "hourglass_ruins",
        "terrain": "funnel_7x7",
        "colors": 4,
        "moves": 20,
        "min_moves": 18,
        "target_pass_band": [0.82, 0.95],
        "eye": "cleanse_expedition_weak",
        "objective": {"type": "cleanse_marks", "target": "all"},
        "placements": ["downstream_marks_7x7", "gate_hint_marks_7x7"],
        "intent": "先让玩家读懂下游目标池和轻漏斗，不急着把棋盘放大。",
        "control": "vertical_line_gem",
    },
    5: {
        "role": "teaching",
        "complexity_tier": 1,
        "theme": "crystal_workshop",
        "terrain": "open_7x7",
        "moves": 22,
        "min_moves": 18,
        "max_colors": 4,
        "max_shell_hp": 1,
        "target_pass_band": [0.90, 1.00],
        "eye": "crystal_shell_gate_practice",
        "objective": {"type": "cleanse_marks", "target": "all"},
        "placements": ["downstream_marks_7x7", "crystal_gate_7x7"],
        "reward_placements": ["gate_line_reward_7x7"],
        "intent": "晶壳门首次出现：小棋盘里用竖线打开门，再净化门后的星尘。",
        "control": "vertical_line_gem",
        "forbidden": ["creep_growth", "spawner", "timed_core", "drop_relic"],
    },
    6: {
        "role": "breather",
        "complexity_tier": 1,
        "theme": "forest_ruins",
        "terrain": "open_7x7",
        "colors": 4,
        "moves": 18,
        "min_moves": 16,
        "max_colors": 4,
        "max_shell_hp": 1,
        "target_pass_band": [0.94, 1.00],
        "eye": "shell_cleanup_breather",
        "objective": {"type": "clear_shells", "target": "all"},
        "placements": ["soft_shell_clusters_7x7"],
        "reward_placements": ["cleanup_line_reward_7x7"],
        "intent": "晶壳后喘息爽关：在开阔盘面清掉少量散落晶壳。",
        "control": "adjacent_shell_cleanup",
    },
    7: {
        "role": "variation",
        "complexity_tier": 2,
        "theme": "hourglass_ruins",
        "terrain": "split_columns_9x9",
        "topology": "split_columns",
        "colors": 4,
        "moves": 24,
        "min_moves": 20,
        "max_colors": 4,
        "target_pass_band": [0.86, 1.00],
        "eye": "split_supply_duet",
        "objective": {"type": "cleanse_marks", "target": "all"},
        "placements": ["split_duet_marks_9x9"],
        "intent": "裂页双区：左右两边各自补给，玩家要分别点亮两页星尘。",
        "control": "split_area_targeting",
    },
    8: {
        "role": "variation",
        "complexity_tier": 2,
        "theme": "crystal_mine",
        "terrain": "open_9x9",
        "colors": 5,
        "moves": 16,
        "min_moves": 14,
        "max_colors": 5,
        "max_shell_hp": 2,
        "target_pass_band": [0.80, 0.94],
        "eye": "cleanse_siege",
        "objective": {"type": "cleanse_marks", "target": "all"},
        "placements": ["vault_marks_9x9", "vault_shell_ring_9x9"],
        "reward_placements": ["vault_burst_reward_9x9"],
        "intent": "孤岛围城：先破外圈晶壳，再净化中心。",
        "control": "burst_gem",
    },
    9: {
        "role": "teaching",
        "complexity_tier": 1,
        "theme": "forest_ruins",
        "terrain": "open_7x7",
        "moves": 24,
        "target_pass_band": [0.92, 1.00],
        "eye": "drop_direct",
        "objective": {"type": "drop_relic", "target": 1},
        "placements": ["relic_direct_7x7"],
        "intent": "迷路幼兽首见：小棋盘中让玩家看懂消幼兽下方会让它回巢。",
        "control": "clear_below_relic",
    },
    10: {
        "role": "pressure",
        "complexity_tier": 2,
        "theme": "crystal_workshop",
        "terrain": "open_7x9",
        "colors": 5,
        "moves": 34,
        "min_moves": 30,
        "max_moves": 36,
        "max_shell_hp": 2,
        "target_pass_band": [0.58, 0.78],
        "eye": "drop_bottleneck",
        "objective": {"type": "drop_relic", "target": 1},
        "placements": ["relic_bottleneck_7x9", "crystal_gate_7x9_route"],
        "reward_placements": ["finale_burst_reward_7x9", "finale_line_reward_7x9"],
        "intent": "幼兽路径与晶壳门：先开路，再护送幼兽回巢。",
        "control": "vertical_line_gem",
    },
}


EARLY_LEVEL_PROGRESSION: dict[int, dict[str, Any]] = {
    1: {
        "arc_role": "goal_reveal",
        "rhythm": "tutorial_floor",
        "lifecycle": [{"mechanic": "target_mark", "phase": "reveal_safe", "role": "primary", "is_new": True}],
        "rewards": [],
    },
    2: {
        "arc_role": "reward_tool_intro",
        "rhythm": "safe_reward_lift",
        "lifecycle": [{"mechanic": "target_mark", "phase": "practice_with_reward", "role": "primary", "is_new": False}],
        "rewards": ["line_h_gem"],
    },
    3: {
        "arc_role": "spatial_reading",
        "rhythm": "low_variation",
        "lifecycle": [{"mechanic": "target_mark", "phase": "spatial_variation", "role": "primary", "is_new": False}],
        "rewards": [],
    },
    4: {
        "arc_role": "terrain_first_pressure",
        "rhythm": "gentle_rise",
        "lifecycle": [{"mechanic": "target_mark", "phase": "terrain_variation", "role": "primary", "is_new": False}],
        "rewards": [],
    },
    5: {
        "arc_role": "blocker_reveal_with_tool",
        "rhythm": "new_mechanic_safe_test",
        "lifecycle": [
            {"mechanic": "crystal_shell", "phase": "reveal_safe", "role": "primary", "is_new": True},
            {"mechanic": "target_mark", "phase": "known_goal_as_payoff", "role": "support", "is_new": False},
        ],
        "rewards": ["line_v_gem"],
    },
    6: {
        "arc_role": "post_blocker_breather",
        "rhythm": "breather_drop",
        "lifecycle": [{"mechanic": "crystal_shell", "phase": "cleanup_breather", "role": "primary", "is_new": False}],
        "rewards": ["line_h_gem"],
    },
    7: {
        "arc_role": "supply_topology_variation",
        "rhythm": "medium_reading_rise",
        "lifecycle": [{"mechanic": "target_mark", "phase": "split_supply_variation", "role": "primary", "is_new": False}],
        "rewards": [],
    },
    8: {
        "arc_role": "blocker_pressure_variation",
        "rhythm": "short_pressure_peak",
        "lifecycle": [
            {"mechanic": "crystal_shell", "phase": "enclosure_pressure", "role": "primary", "is_new": False},
            {"mechanic": "target_mark", "phase": "known_goal_as_vault", "role": "support", "is_new": False},
        ],
        "rewards": [],
    },
    9: {
        "arc_role": "transport_reveal",
        "rhythm": "tutorial_floor",
        "lifecycle": [{"mechanic": "drop_relic", "phase": "reveal_safe", "role": "primary", "is_new": True}],
        "rewards": [],
    },
    10: {
        "arc_role": "episode_finale_mix",
        "rhythm": "first_act_finale",
        "lifecycle": [
            {"mechanic": "drop_relic", "phase": "combine_with_gate", "role": "primary", "is_new": False},
            {"mechanic": "crystal_shell", "phase": "known_blocker_as_route_gate", "role": "support", "is_new": False},
        ],
        "rewards": ["burst_gem", "line_v_gem"],
    },
}


EARLY_LEVEL_OBSTACLE_COMPOSITION: dict[int, dict[str, Any]] = {
    1: {
        "purpose": "teach_target_mark_clear",
        "archetype": "no_blocker_focus",
        "primary_blocker": "none",
        "focus_area": "center_marks",
        "action_vector": "local_match",
        "read_order": ["goal", "solution"],
        "negative_space": {"kind": "whole_board_operation_space", "min_ratio": 0.70},
        "density": "none",
        "delete_test": "removing_target_marks_removes_level_thesis",
        "theme_shape": "stardust_cluster",
        "beauty_rules": ["single_core_question", "goal_solution_readable", "theme_shape_serves_play_shape"],
    },
    2: {
        "purpose": "teach_horizontal_line_reaches_edges",
        "archetype": "no_blocker_focus",
        "primary_blocker": "none",
        "focus_area": "edge_marks",
        "action_vector": "horizontal",
        "read_order": ["edge_goal", "horizontal_solution"],
        "negative_space": {"kind": "center_play_area", "min_ratio": 0.68},
        "density": "none",
        "delete_test": "removing_edge_targets_removes_sweep_lesson",
        "theme_shape": "edge_stardust",
        "beauty_rules": ["shape_implies_action_direction", "single_core_question", "theme_shape_serves_play_shape"],
    },
    3: {
        "purpose": "teach_target_path_reading",
        "archetype": "key_path",
        "primary_blocker": "none",
        "focus_area": "trail_marks",
        "action_vector": "path",
        "read_order": ["goal_path", "solution_sequence"],
        "negative_space": {"kind": "open_path_play_area", "min_ratio": 0.65},
        "density": "none",
        "delete_test": "removing_trail_removes_path_reading_lesson",
        "theme_shape": "paw_stardust_trail",
        "beauty_rules": ["single_core_question", "goal_solution_readable", "theme_shape_serves_play_shape"],
    },
    4: {
        "purpose": "teach_downstream_funnel_reading",
        "archetype": "funnel",
        "primary_blocker": "none",
        "focus_area": "downstream_pool",
        "action_vector": "vertical",
        "read_order": ["upper_supply", "funnel_throat", "goal_basin"],
        "negative_space": {"kind": "upper_play_area", "min_ratio": 0.55},
        "density": "low",
        "delete_test": "removing_bottleneck_removes_downstream_lesson",
        "theme_shape": "book_page_funnel",
        "beauty_rules": ["shape_implies_action_direction", "single_core_question", "goal_blocker_solution_readable"],
    },
    5: {
        "purpose": "teach_vertical_line_opens_gate",
        "archetype": "gate",
        "primary_blocker": "crystal_shell",
        "focus_area": "center_column",
        "action_vector": "vertical",
        "read_order": ["goal", "blocker", "solution"],
        "negative_space": {"kind": "upper_play_area", "min_ratio": 0.50},
        "density": "low",
        "delete_test": "removing_crystal_gate_removes_level_thesis",
        "theme_shape": "crystal_door",
        "beauty_rules": ["shape_implies_action_direction", "single_core_question", "no_uniform_wall", "goal_blocker_solution_readable", "theme_shape_serves_play_shape"],
    },
    6: {
        "purpose": "teach_shell_cleanup_expands_space",
        "archetype": "cage",
        "primary_blocker": "crystal_shell",
        "focus_area": "soft_shell_clusters",
        "action_vector": "adjacent_clear",
        "read_order": ["blocker", "solution", "space_payoff"],
        "negative_space": {"kind": "open_board_around_clusters", "min_ratio": 0.72},
        "density": "low",
        "delete_test": "removing_shell_clusters_removes_cleanup_lesson",
        "theme_shape": "loose_crystal_knots",
        "beauty_rules": ["single_core_question", "no_uniform_wall", "theme_shape_serves_play_shape"],
    },
    7: {
        "purpose": "teach_split_area_control",
        "archetype": "split_lock",
        "primary_blocker": "none",
        "focus_area": "left_right_pages",
        "action_vector": "dual_area",
        "read_order": ["left_goal", "divider", "right_goal"],
        "negative_space": {"kind": "paired_play_areas", "min_ratio": 0.55},
        "density": "low",
        "delete_test": "removing_split_columns_removes_dual_page_lesson",
        "theme_shape": "split_spellbook_pages",
        "beauty_rules": ["shape_implies_action_direction", "single_core_question", "theme_shape_serves_play_shape"],
    },
    8: {
        "purpose": "teach_burst_cracks_crystal_ring",
        "archetype": "ring",
        "primary_blocker": "crystal_shell",
        "focus_area": "vault_center",
        "action_vector": "burst",
        "read_order": ["center_goal", "blocker_ring", "burst_solution"],
        "negative_space": {"kind": "outer_play_area", "min_ratio": 0.55},
        "density": "medium",
        "delete_test": "removing_shell_ring_removes_vault_lesson",
        "theme_shape": "crystal_vault_ring",
        "beauty_rules": ["shape_implies_action_direction", "single_core_question", "no_uniform_wall", "goal_blocker_solution_readable", "theme_shape_serves_play_shape"],
    },
    9: {
        "purpose": "teach_lost_cub_column_drop",
        "archetype": "lane",
        "primary_blocker": "none",
        "focus_area": "center_lane",
        "action_vector": "transport_down",
        "read_order": ["actor", "lane", "exit"],
        "negative_space": {"kind": "lane_play_area", "min_ratio": 0.70},
        "density": "none",
        "delete_test": "removing_cub_and_exit_removes_transport_lesson",
        "theme_shape": "cub_path_to_nest",
        "beauty_rules": ["shape_implies_action_direction", "single_core_question", "theme_shape_serves_play_shape"],
    },
    10: {
        "purpose": "teach_open_route_gate_then_transport_cub",
        "archetype": "lane",
        "primary_blocker": "crystal_shell",
        "focus_area": "center_route_gate",
        "action_vector": "transport_down",
        "read_order": ["actor", "blocker", "exit"],
        "negative_space": {"kind": "upper_play_area", "min_ratio": 0.48},
        "density": "low",
        "delete_test": "removing_route_gate_removes_finale_priority",
        "theme_shape": "crystal_route_gate",
        "beauty_rules": ["shape_implies_action_direction", "single_core_question", "no_uniform_wall", "goal_blocker_solution_readable", "theme_shape_serves_play_shape"],
    },
}


EARLY_LEVEL_INTENT: dict[int, dict[str, Any]] = {
    1: {
        "objective_verb": "cleanse",
        "skill_lesson": {"skill": "match_on_target_cells", "proof_signal": "target_mark_progress_after_local_match"},
        "board_scale": {"size": "7x7", "effective_problem_space": "small", "reason": "first_target_reveal"},
    },
    2: {
        "objective_verb": "cleanse",
        "skill_lesson": {"skill": "use_horizontal_line_for_edge_targets", "proof_signal": "line_reward_hits_edge_target"},
        "board_scale": {"size": "7x7", "effective_problem_space": "small", "reason": "edge_sweep_lesson"},
    },
    3: {
        "objective_verb": "cleanse",
        "skill_lesson": {"skill": "read_target_path", "proof_signal": "multiple_target_regions_cleared_in_sequence"},
        "board_scale": {"size": "7x7", "effective_problem_space": "small", "reason": "path_reading_without_new_blocker"},
    },
    4: {
        "objective_verb": "cleanse",
        "skill_lesson": {"skill": "read_downstream_goal_basin", "proof_signal": "lower_targets_cleared_after_upper_moves"},
        "board_scale": {"size": "7x7", "effective_problem_space": "small", "reason": "first_terrain_variation_should_not_compete_with_later_blocker_reveal"},
    },
    5: {
        "objective_verb": "cleanse",
        "skill_lesson": {"skill": "use_vertical_line_to_open_gate", "proof_signal": "crystal_gate_damaged_before_downstream_targets_finish"},
        "board_scale": {"size": "7x7", "effective_problem_space": "small", "reason": "new_blocker_reveal_small_problem_space"},
    },
    6: {
        "objective_verb": "cleanse",
        "skill_lesson": {"skill": "adjacent_clear_blocker_clusters", "proof_signal": "crystal_shell_count_decreases"},
        "board_scale": {"size": "7x7", "effective_problem_space": "small", "reason": "post_reveal_cleanup_breather"},
    },
    7: {
        "objective_verb": "cleanse",
        "skill_lesson": {"skill": "solve_split_areas_independently", "proof_signal": "left_and_right_target_progress"},
        "board_scale": {"size": "9x9", "effective_problem_space": "medium", "reason": "split_regions_need_width"},
    },
    8: {
        "objective_verb": "cleanse",
        "skill_lesson": {"skill": "use_burst_to_crack_ring", "proof_signal": "shell_ring_damage_before_center_targets_finish"},
        "board_scale": {"size": "9x9", "effective_problem_space": "medium", "reason": "mini_peak_after_split_topology_uses_rewarded_outer_play_area"},
    },
    9: {
        "objective_verb": "transport",
        "skill_lesson": {"skill": "clear_below_actor_to_move_down", "proof_signal": "lost_cub_moves_down_at_least_three_rows"},
        "board_scale": {"size": "7x7", "effective_problem_space": "small", "reason": "new_transport_mechanic_reveal_small_problem_space"},
    },
    10: {
        "objective_verb": "transport",
        "skill_lesson": {"skill": "open_route_gate_then_transport_actor", "proof_signal": "crystal_gate_damaged_before_lost_cub_exits"},
        "board_scale": {"size": "7x9", "effective_problem_space": "medium", "reason": "finale_needs_route_depth_without_58_move_drag"},
    },
}


ANNOYANCE_BUDGET_BY_ROLE: dict[str, dict[str, float]] = {
    "teaching": {"max_reshuffle_rate": 0.02, "max_dead_board_rate": 0.02, "max_no_progress_turn_rate": 0.28, "max_luck_dependency_proxy": 0.32},
    "teaching_breather": {"max_reshuffle_rate": 0.03, "max_dead_board_rate": 0.03, "max_no_progress_turn_rate": 0.30, "max_luck_dependency_proxy": 0.35},
    "variation": {"max_reshuffle_rate": 0.05, "max_dead_board_rate": 0.05, "max_no_progress_turn_rate": 0.36, "max_luck_dependency_proxy": 0.42},
    "breather": {"max_reshuffle_rate": 0.03, "max_dead_board_rate": 0.03, "max_no_progress_turn_rate": 0.30, "max_luck_dependency_proxy": 0.35},
    "pressure_lite": {"max_reshuffle_rate": 0.06, "max_dead_board_rate": 0.06, "max_no_progress_turn_rate": 0.40, "max_luck_dependency_proxy": 0.45},
    "pressure": {"max_reshuffle_rate": 0.08, "max_dead_board_rate": 0.08, "max_no_progress_turn_rate": 0.45, "max_luck_dependency_proxy": 0.50},
    "peak": {"max_reshuffle_rate": 0.10, "max_dead_board_rate": 0.10, "max_no_progress_turn_rate": 0.50, "max_luck_dependency_proxy": 0.55},
}


VARIANT_RULES: dict[str, dict[str, Any]] = {
    "base": {"moves_delta": 0, "target_multiplier": 1.0, "shell_hp_delta": 0, "prior": "unknown", "prior_weight": 0.0},
    "assisted": {"moves_delta": 3, "target_multiplier": 0.85, "shell_hp_delta": 0, "prior": "unknown", "prior_weight": 0.0},
    "advanced": {"moves_delta": -2, "target_multiplier": 1.10, "shell_hp_delta": 1, "prior": "unknown", "prior_weight": 0.0},
    "female_prior": {"moves_delta": 2, "target_multiplier": 0.90, "shell_hp_delta": 0, "prior": "female", "prior_weight": 0.20},
    "male_prior": {"moves_delta": -1, "target_multiplier": 1.05, "shell_hp_delta": 1, "prior": "male", "prior_weight": 0.20},
}


PERSONA_AXES_BY_PRIOR: dict[str, dict[str, float]] = {
    # Cold-start defaults are deliberately explicit.  They are not demographic
    # truth claims; they are tunable generator priors until telemetry replaces
    # them.
    "unknown": {
        "novelty_bias": 0.50,
        "reward_bias": 0.50,
        "challenge_bias": 0.50,
        "strategy_bias": 0.50,
        "cuteness_bias": 0.50,
        "annoyance_tolerance": 0.45,
    },
    "female": {
        "novelty_bias": 0.70,
        "reward_bias": 0.68,
        "challenge_bias": 0.42,
        "strategy_bias": 0.46,
        "cuteness_bias": 0.74,
        "annoyance_tolerance": 0.35,
    },
    "male": {
        "novelty_bias": 0.46,
        "reward_bias": 0.48,
        "challenge_bias": 0.70,
        "strategy_bias": 0.74,
        "cuteness_bias": 0.45,
        "annoyance_tolerance": 0.52,
    },
}


VISUAL_DENSITY_BANDS: dict[str, list[float]] = {
    "none": [0.02, 0.20],
    "low": [0.03, 0.26],
    "medium": [0.08, 0.32],
    "high": [0.18, 0.42],
}


MECHANISM_SPEC_REQUIRED_FIELDS = {
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
MECHANISM_STATE_DYNAMICS = {"static", "self_evolving", "actor_moving"}
MECHANISM_CATEGORIES = {"objective", "blocker", "actor", "routing", "reward"}
MECHANISM_COMPATIBLE_TERRAIN = ["open", "funnel", "bottleneck", "island", "fork", "split_columns"]


def mechanism_spec_record(
    mechanic_id: str,
    *,
    category: str,
    state_dynamics: str,
    player_action: str,
    board_effect: str,
    reward_effect: str,
    compatible_objective_verbs: list[str],
    first_reveal_level: int | None,
    first_reveal_phase: str,
    can_pair_with: list[str],
    simulator_kind: str,
    godot_layer: str,
) -> dict[str, Any]:
    return {
        "mechanic_id": mechanic_id,
        "category": category,
        "state_dynamics": state_dynamics,
        "player_action": player_action,
        "board_effect": board_effect,
        "reward_effect": reward_effect,
        "compatible_objective_verbs": compatible_objective_verbs,
        "compatible_terrain": list(MECHANISM_COMPATIBLE_TERRAIN),
        "intro_rule": {
            "first_reveal_level": first_reveal_level,
            "first_reveal_phase": first_reveal_phase,
            "new_reveal_problem_space": "small" if first_reveal_level is not None else "n/a",
        },
        "mixing_rule": {
            "can_pair_with": can_pair_with,
            "forbidden_with": [],
            "max_support_mechanisms_early": 1,
        },
        "simulator_hook": {
            "kind": simulator_kind,
            "supported": True,
        },
        "godot_support": {
            "playable_v0": True,
            "compile_layer": godot_layer,
        },
    }


BASE_MECHANISM_SPECS: dict[str, dict[str, Any]] = {
    "target_mark": mechanism_spec_record(
        "target_mark",
        category="objective",
        state_dynamics="static",
        player_action="match_on_target_cell",
        board_effect="clears_target_mark_layer",
        reward_effect="objective_progress_feedback",
        compatible_objective_verbs=["cleanse", "craft", "mixed"],
        first_reveal_level=1,
        first_reveal_phase="reveal_safe",
        can_pair_with=["crystal_shell", "line_h_gem", "line_v_gem", "burst_gem", "color_bomb_gem"],
        simulator_kind="jelly_layer",
        godot_layer="jelly",
    ),
    "crystal_shell": mechanism_spec_record(
        "crystal_shell",
        category="blocker",
        state_dynamics="static",
        player_action="clear_adjacent_or_hit_with_special",
        board_effect="occupies_space_and_blocks_until_hp_zero",
        reward_effect="opens_route_or_reveals_target_space",
        compatible_objective_verbs=["cleanse", "transport", "craft", "rescue", "mixed"],
        first_reveal_level=5,
        first_reveal_phase="reveal_safe",
        can_pair_with=["target_mark", "drop_relic", "line_h_gem", "line_v_gem", "burst_gem", "color_bomb_gem", "drop_exit"],
        simulator_kind="coat_layer",
        godot_layer="coat",
    ),
    "drop_relic": mechanism_spec_record(
        "drop_relic",
        category="actor",
        state_dynamics="actor_moving",
        player_action="clear_below_actor_to_move_down",
        board_effect="actor_travels_toward_exit_after_supported_clears",
        reward_effect="rescue_completion_feedback",
        compatible_objective_verbs=["transport", "rescue", "mixed"],
        first_reveal_level=9,
        first_reveal_phase="reveal_safe",
        can_pair_with=["drop_exit", "crystal_shell", "line_v_gem", "burst_gem", "color_bomb_gem"],
        simulator_kind="ingredient_actor",
        godot_layer="ingredient",
    ),
    "drop_exit": mechanism_spec_record(
        "drop_exit",
        category="routing",
        state_dynamics="static",
        player_action="route_actor_to_exit_column",
        board_effect="collects_actor_when_it_reaches_bottom_exit",
        reward_effect="transport_objective_completion",
        compatible_objective_verbs=["transport", "rescue", "mixed"],
        first_reveal_level=9,
        first_reveal_phase="paired_with_actor_reveal",
        can_pair_with=["drop_relic", "crystal_shell"],
        simulator_kind="exit_columns",
        godot_layer="exits",
    ),
    "line_h_gem": mechanism_spec_record(
        "line_h_gem",
        category="reward",
        state_dynamics="static",
        player_action="trigger_or_swap_special_reward",
        board_effect="clears_horizontal_line",
        reward_effect="edge_or_row_sweep",
        compatible_objective_verbs=["cleanse", "transport", "craft", "connect", "rescue", "mixed"],
        first_reveal_level=None,
        first_reveal_phase="reward_tool",
        can_pair_with=["target_mark", "crystal_shell", "drop_relic", "drop_exit"],
        simulator_kind="fx_line_h",
        godot_layer="fx",
    ),
    "line_v_gem": mechanism_spec_record(
        "line_v_gem",
        category="reward",
        state_dynamics="static",
        player_action="trigger_or_swap_special_reward",
        board_effect="clears_vertical_line",
        reward_effect="gate_or_route_sweep",
        compatible_objective_verbs=["cleanse", "transport", "craft", "connect", "rescue", "mixed"],
        first_reveal_level=None,
        first_reveal_phase="reward_tool",
        can_pair_with=["target_mark", "crystal_shell", "drop_relic", "drop_exit"],
        simulator_kind="fx_line_v",
        godot_layer="fx",
    ),
    "burst_gem": mechanism_spec_record(
        "burst_gem",
        category="reward",
        state_dynamics="static",
        player_action="trigger_or_swap_special_reward",
        board_effect="clears_local_radius",
        reward_effect="cracks_cluster_or_ring",
        compatible_objective_verbs=["cleanse", "transport", "craft", "connect", "rescue", "mixed"],
        first_reveal_level=None,
        first_reveal_phase="reward_tool",
        can_pair_with=["target_mark", "crystal_shell", "drop_relic", "drop_exit"],
        simulator_kind="fx_burst",
        godot_layer="fx",
    ),
    "color_bomb_gem": mechanism_spec_record(
        "color_bomb_gem",
        category="reward",
        state_dynamics="static",
        player_action="swap_with_color_to_clear_species",
        board_effect="clears_one_species",
        reward_effect="large_board_sweep",
        compatible_objective_verbs=["cleanse", "transport", "craft", "connect", "rescue", "mixed"],
        first_reveal_level=None,
        first_reveal_phase="reward_tool",
        can_pair_with=["target_mark", "crystal_shell", "drop_relic", "drop_exit"],
        simulator_kind="fx_color_bomb",
        godot_layer="fx",
    ),
}


CANDIDATE_TUNINGS: list[dict[str, Any]] = [
    {"moves_delta": 0, "target_multiplier": 1.00, "shell_hp_delta": 0, "colors_delta": 0},
    {"moves_delta": -1, "target_multiplier": 1.00, "shell_hp_delta": 0, "colors_delta": 0},
    {"moves_delta": -2, "target_multiplier": 1.05, "shell_hp_delta": 0, "colors_delta": 0},
    {"moves_delta": -3, "target_multiplier": 1.10, "shell_hp_delta": 1, "colors_delta": 0},
    {"moves_delta": -4, "target_multiplier": 1.15, "shell_hp_delta": 1, "colors_delta": 1},
    {"moves_delta": -5, "target_multiplier": 1.20, "shell_hp_delta": 2, "colors_delta": 1},
    {"moves_delta": 1, "target_multiplier": 0.95, "shell_hp_delta": 0, "colors_delta": 0},
    {"moves_delta": 2, "target_multiplier": 0.90, "shell_hp_delta": -1, "colors_delta": 0},
]


def candidate_tuning(candidate: int | None) -> dict[str, Any]:
    if candidate is None:
        return {"moves_delta": 0, "target_multiplier": 1.00, "shell_hp_delta": 0, "colors_delta": 0}
    base = dict(CANDIDATE_TUNINGS[candidate % len(CANDIDATE_TUNINGS)])
    cycle = candidate // len(CANDIDATE_TUNINGS)
    if cycle:
        # Later retries keep moving outward instead of resampling only the RNG.
        base["moves_delta"] = int(base["moves_delta"]) - cycle * 2
        base["target_multiplier"] = float(base["target_multiplier"]) + cycle * 0.08
        base["shell_hp_delta"] = int(base["shell_hp_delta"]) + cycle
    return base


ROLE_PASS_BANDS: dict[str, tuple[float, float]] = {
    "teaching": (0.75, 0.98),
    "teaching_breather": (0.70, 0.98),
    "variation": (0.55, 0.92),
    "breather": (0.65, 0.98),
    "pressure_lite": (0.45, 0.88),
    "pressure": (0.35, 0.82),
    "peak": (0.25, 0.70),
}


DIRECTOR_REQUIRED_FIELDS = (
    "intent",
    "player_fantasy",
    "protagonist",
    "supporting_roles",
    "emotional_arc",
    "signature_moment",
    "negative_space",
    "four_in_one",
    "anti_slop",
)
DIRECTOR_ARC_FIELDS = ("opening", "friction", "turn", "payoff")
DIRECTOR_FOUR_IN_ONE_FIELDS = ("play", "visual", "readability", "theme")
DIRECTOR_GENERIC_PHRASES = {"目标完成", "目标区", "读取目标", "制造可用消除", "完成目标", "中心目标区"}
DIRECTOR_LAYER_KEYWORDS: dict[str, tuple[str, ...]] = {
    "target_mark": ("星尘", "印记", "净化"),
    "crystal_shell": ("晶壳", "门", "壳", "封"),
    "drop_relic": ("幼兽", "巢", "回家", "护送"),
    "creep_growth": ("蔓", "生长", "侵蚀"),
    "spawner": ("生成", "源", "吐出"),
    "timed_core": ("倒计时", "核心", "爆"),
}
OBJECTIVE_TO_LAYER: dict[str, str] = {
    "cleanse_marks": "target_mark",
    "clear_shells": "crystal_shell",
    "drop_relic": "drop_relic",
    "clear_creep": "creep_growth",
    "defuse_cores": "timed_core",
}


@dataclass
class Diagnostics:
    errors: list[dict[str, Any]] = field(default_factory=list)
    warnings: list[dict[str, Any]] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors

    def error(self, code: str, path: str, message: str) -> None:
        self.errors.append({"code": code, "path": path, "message": message})

    def warn(self, code: str, path: str, message: str) -> None:
        self.warnings.append({"code": code, "path": path, "message": message})

    def to_json(self) -> dict[str, Any]:
        return {"valid": self.ok, "errors": self.errors, "warnings": self.warnings}


def board_size(rows: list[str]) -> tuple[int, int]:
    return len(rows[0]) if rows else 0, len(rows)


def overlay(region: str, cells: list[list[int]], layers: list[Any]) -> dict[str, Any]:
    return {"region": region, "cells": cells, "layers": layers}


def placement_overlays(preset: str, shell_hp_delta: int = 0) -> list[dict[str, Any]]:
    shell_hp = max(1, 1 + shell_hp_delta)
    shell_layer: Any = "crystal_shell" if shell_hp == 1 else {"crystal_shell": {"hp": shell_hp}}
    presets: dict[str, list[dict[str, Any]]] = {
        "center_marks_7x7": [
            overlay("center_marks", [[2, 2], [2, 3], [2, 4], [3, 2], [3, 3], [3, 4]], ["target_mark"])
        ],
        "edge_marks_7x7": [
            overlay("edge_marks", [[0, 1], [0, 5], [1, 0], [1, 6], [5, 0], [5, 6], [6, 1], [6, 5]], ["target_mark"])
        ],
        "edge_line_reward_7x7": [
            overlay("edge_line_reward", [[3, 3]], ["line_h_gem"])
        ],
        "trail_marks_7x7": [
            overlay("trail_marks", [[1, 2], [1, 3], [2, 4], [3, 2], [3, 3], [3, 4], [4, 2], [5, 3]], ["target_mark"])
        ],
        "soft_shell_clusters_7x7": [
            overlay("soft_shell_clusters", [[2, 2], [2, 4], [3, 3], [4, 2], [4, 4]], [shell_layer])
        ],
        "downstream_marks_7x7": [
            overlay("downstream_marks", [[5, 2], [5, 3], [5, 4], [6, 2], [6, 3], [6, 4]], ["target_mark"])
        ],
        "crystal_gate_7x7": [
            overlay("crystal_gate", [[4, 2], [4, 3], [4, 4]], [shell_layer])
        ],
        "gate_line_reward_7x7": [
            overlay("gate_line_reward", [[3, 3]], ["line_v_gem"])
        ],
        "gate_hint_marks_7x7": [
            overlay("gate_hint_marks", [[4, 2], [4, 3], [4, 4]], ["target_mark"])
        ],
        "cleanup_line_reward_7x7": [
            overlay("cleanup_line_reward", [[3, 1]], ["line_h_gem"])
        ],
        "downstream_marks_9x9": [
            overlay("downstream_marks", [[6, 3], [6, 4], [6, 5], [7, 3], [7, 4], [7, 5], [8, 3], [8, 4], [8, 5]], ["target_mark"])
        ],
        "gate_hint_marks_9x9": [
            overlay("gate_hint_marks", [[4, 3], [4, 4], [4, 5]], ["target_mark"])
        ],
        "split_duet_marks_9x9": [
            overlay("left_page_marks", [[2, 1], [3, 2], [4, 1], [5, 2]], ["target_mark"]),
            overlay("right_page_marks", [[2, 7], [3, 6], [4, 7], [5, 6]], ["target_mark"]),
        ],
        "crystal_gate_9x9": [
            overlay("crystal_gate", [[4, 3], [4, 4], [4, 5], [5, 3], [5, 4], [5, 5]], [shell_layer])
        ],
        "gate_line_reward_9x9": [
            overlay("gate_line_reward", [[3, 4]], ["line_v_gem"])
        ],
        "vault_marks_9x9": [
            overlay("vault_marks", [[3, 3], [3, 4], [3, 5], [4, 3], [4, 4], [4, 5], [5, 3], [5, 4], [5, 5]], ["target_mark"])
        ],
        "vault_shell_ring_9x9": [
            overlay("vault_shell_ring", [[2, 3], [2, 4], [2, 5], [3, 2], [4, 2], [5, 2], [6, 3], [6, 4], [6, 5], [3, 6], [4, 6], [5, 6]], [shell_layer])
        ],
        "vault_burst_reward_9x9": [
            overlay("vault_burst_reward", [[1, 4]], ["burst_gem"])
        ],
        "relic_direct_9x9": [
            overlay("lost_cub_start", [[1, 4]], ["drop_relic"]),
            overlay("nest_exit", [[8, 4]], ["drop_exit"]),
        ],
        "relic_direct_7x7": [
            overlay("lost_cub_start", [[1, 3]], ["drop_relic"]),
            overlay("nest_exit", [[6, 3]], ["drop_exit"]),
        ],
        "relic_bottleneck_9x9": [
            overlay("lost_cub_start", [[1, 4]], ["drop_relic"]),
            overlay("nest_exit", [[8, 4]], ["drop_exit"]),
        ],
        "relic_bottleneck_7x9": [
            overlay("lost_cub_start", [[1, 3]], ["drop_relic"]),
            overlay("nest_exit", [[8, 3]], ["drop_exit"]),
        ],
        "crystal_gate_7x9_route": [
            overlay("crystal_route_gate", [[4, 2], [4, 3], [4, 4], [5, 2], [5, 4]], [shell_layer])
        ],
        "finale_burst_reward_7x9": [
            overlay("finale_burst_reward", [[2, 2]], ["burst_gem"])
        ],
        "finale_line_reward_7x9": [
            overlay("finale_line_reward", [[2, 4]], ["line_v_gem"])
        ],
        "finale_burst_reward_9x9": [
            overlay("finale_burst_reward", [[2, 3]], ["burst_gem"])
        ],
        "finale_line_reward_9x9": [
            overlay("finale_line_reward", [[2, 5]], ["line_v_gem"])
        ],
    }
    return [dict(item) for item in presets.get(preset, [])]


def build_overlays(placements: list[str], shell_hp_delta: int = 0) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for preset in placements:
        out.extend(placement_overlays(preset, shell_hp_delta))
    return out


def generated_progression(level: int, coord: dict[str, Any]) -> dict[str, Any]:
    spec = EARLY_LEVEL_PROGRESSION.get(level)
    if not spec:
        raise ValueError(f"no progression grammar for level {level}")
    role = str(coord["role"])
    primitives = list(spec.get("rewards", []))
    return {
        "episode": {
            "id": "first_spellbook_arc",
            "slot": level,
            "arc_role": spec["arc_role"],
        },
        "mechanic_lifecycle": [dict(item) for item in spec["lifecycle"]],
        "reward_budget": {
            "required": bool(primitives),
            "primitives": primitives,
            "delivery": "preseeded_fx_overlay" if primitives else "natural_cascade_only",
            "purpose": "give_the_player_a_real_board_resource_not_just_payoff_text" if primitives else "keep_attention_on_new_rule",
        },
        "annoyance_budget": dict(ANNOYANCE_BUDGET_BY_ROLE.get(role, ANNOYANCE_BUDGET_BY_ROLE["variation"])),
        "difficulty_rhythm": {
            "shape": spec["rhythm"],
            "target_pass_band": list(coord["target_pass_band"]),
            "role": role,
        },
    }


def generated_obstacle_composition(level: int, coord: dict[str, Any]) -> dict[str, Any]:
    spec = EARLY_LEVEL_OBSTACLE_COMPOSITION.get(level)
    if not spec:
        raise ValueError(f"no obstacle composition grammar for level {level}")
    out = copy.deepcopy(spec)
    out["level_role"] = coord["role"]
    out["linked_eye"] = coord["eye"]
    out["visual_grammar"] = generated_visual_grammar(out, coord)
    return out


def generated_visual_grammar(composition: dict[str, Any], coord: dict[str, Any]) -> dict[str, Any]:
    """Compile obstacle taste prose into measurable composition constraints."""
    archetype = str(composition.get("archetype", ""))
    focus_area = str(composition.get("focus_area", ""))
    density = str(composition.get("density", "low"))
    primary = str(composition.get("primary_blocker", "none"))
    objective_layer = OBJECTIVE_TO_LAYER.get(str(coord.get("objective", {}).get("type")), "target_mark")

    if primary != "none":
        anchor_layers = [primary]
    else:
        anchor_layers = [objective_layer]

    if archetype == "split_lock":
        focal_alignment = "split_dual"
        symmetry = "bilateral"
    elif archetype == "lane":
        focal_alignment = "vertical_lane"
        symmetry = "center_axis"
    elif archetype == "gate" or "center_column" in focus_area or "route_gate" in focus_area:
        focal_alignment = "center_column"
        symmetry = "center_axis"
    elif archetype == "ring":
        focal_alignment = "center_ring"
        symmetry = "radial_hint"
    elif archetype == "funnel":
        focal_alignment = "vertical_funnel"
        symmetry = "center_axis"
    elif "edge" in focus_area:
        focal_alignment = "edge_pairs"
        symmetry = "bilateral"
    elif archetype == "key_path" or "trail" in focus_area:
        focal_alignment = "path"
        symmetry = "none"
    else:
        focal_alignment = "center_cluster"
        symmetry = "center_axis"

    return {
        "focal_alignment": focal_alignment,
        "symmetry": symmetry,
        "density_band": VISUAL_DENSITY_BANDS.get(density, VISUAL_DENSITY_BANDS["low"]),
        "silhouette": str(composition.get("theme_shape", "play_shape")),
        "anchor_layers": anchor_layers,
        "max_centroid_offset": 1.25,
    }


def generated_mechanism_specs(level: int, coord: dict[str, Any], draft_lvl: dict[str, Any]) -> dict[str, Any]:
    """Return the per-level subset of the mechanism library used by a level."""
    specs: dict[str, dict[str, Any]] = {}
    for atom in sorted(mechanism_atoms_for_lvl(draft_lvl)):
        if atom not in BASE_MECHANISM_SPECS:
            continue
        spec = copy.deepcopy(BASE_MECHANISM_SPECS[atom])
        spec["level_role"] = coord["role"]
        spec["linked_eye"] = coord["eye"]
        specs[atom] = spec
    return specs


def generated_level_intent(level: int, coord: dict[str, Any]) -> dict[str, Any]:
    spec = EARLY_LEVEL_INTENT.get(level)
    if not spec:
        raise ValueError(f"no level intent grammar for level {level}")
    out = copy.deepcopy(spec)
    out["source_principles"] = [
        "new_mechanic_reveal_small_problem_space",
        "objective_verb_drives_layout",
        "skill_lesson_must_have_proof_signal",
    ]
    out["linked_eye"] = coord["eye"]
    return out


def objective_with_variant(objective: dict[str, Any], target_multiplier: float) -> dict[str, Any]:
    out = dict(objective)
    if isinstance(out.get("target"), int):
        out["target"] = max(1, int(round(int(out["target"]) * target_multiplier)))
    return out


def generated_level_design(level: int, coord: dict[str, Any]) -> dict[str, Any]:
    """Principles-language source for generated early levels.

    This sits above `.lvl`: one thesis, one protagonist, a stage function,
    an arc, negative-space bans, and validation claims. `.lvl.director` and
    `design_claim` are compiled from this semantic source.
    """

    def design(
        *,
        thesis: str,
        sentence: str,
        fantasy: str,
        protagonist: str,
        protagonist_as: str,
        support: list[dict[str, str]] | None,
        reward: list[dict[str, str]] | None,
        stage_function: str,
        shape: str,
        dramatic_axis: str,
        focus: str,
        friction_zone: str,
        payoff_zone: str,
        operation_space: str,
        supply_logic: str,
        world_state_change: str,
        readable_goal: str,
        opening: str,
        friction: str,
        turn: str,
        payoff: str,
        signature: str,
        negative_statement: str,
        forbid: list[str],
        preserve: list[str],
        play: str,
        visual: str,
        readability: str,
        theme: str,
        intended_solution: list[str],
        crack_path: list[str],
        max_primary_mechanisms: int = 1,
    ) -> dict[str, Any]:
        return {
            "id": f"level_{level:03d}",
            "thesis": {"key": thesis, "sentence": sentence},
            "fantasy": fantasy,
            "roles": {
                "protagonist": {"mechanism": protagonist, "as": protagonist_as},
                "support": support or [],
                "reward": reward or [],
            },
            "stage": {
                "function": stage_function,
                "shape": shape,
                "dramatic_axis": dramatic_axis,
                "focus": focus,
                "friction_zone": friction_zone,
                "payoff_zone": payoff_zone,
                "operation_space": operation_space,
                "supply_logic": supply_logic,
            },
            "objective": {"world_state_change": world_state_change, "player_readable_goal": readable_goal},
            "arc": {"opening": opening, "friction": friction, "turn": turn, "payoff": payoff},
            "payoff": {"signature": signature},
            "negative_space": {"statement": negative_statement, "forbid": sorted(set(forbid + list(FORBIDDEN_GENERATED_OBJECTIVES))), "preserve": preserve},
            "four_in_one": {"play": play, "visual": visual, "readability": readability, "theme": theme},
            "solution": {"intended_solution": intended_solution, "crack_path": crack_path},
            "validation": {
                "must_have": ["one_protagonist", "causal_closure", "visual_play_alignment", "readable_world_state_goal", "arc_turn_state_change"],
                "reject_if": ["generic_counter_goal", "mechanism_without_role", "payoff_disconnected_from_objective", "visual_play_mismatch", "undeclared_noise"],
                "max_primary_mechanisms": max_primary_mechanisms,
            },
        }

    eye = coord["eye"]
    if eye == "cleanse_direct":
        return design(
            thesis="cleanse_first_stardust",
            sentence="擦亮中央星尘，理解净化就是通关。",
            fantasy="帮时兔点亮森林遗迹中央的第一枚星尘徽记。",
            protagonist="target_mark",
            protagonist_as="stardust_focus",
            support=[],
            reward=[{"kind": "small_cascade", "as": "first_sparkle"}],
            stage_function="open_practice",
            shape="open_7x7_center",
            dramatic_axis="center_focus",
            focus="center_marks",
            friction_zone="center_marks",
            payoff_zone="center_marks",
            operation_space="whole_board",
            supply_logic="open_vertical_refill",
            world_state_change="center_stardust_cleansed",
            readable_goal="在中央星尘上做消除，把它们全部净化。",
            opening="中央星尘聚成小徽记，玩家一眼知道看哪里。",
            friction="星尘不会自己消失，必须在目标格上形成消除。",
            turn="第一组星尘被净化，玩家理解目标层规则。",
            payoff="中央徽记被擦亮，棋盘给出第一口小爽感。",
            signature="中央星尘连续熄灭，像魔法书页被擦亮。",
            negative_statement="边缘不放任何次目标，所有注意力留给中央星尘。",
            forbid=["crystal_shell", "drop_relic", "creep_growth", "spawner", "timed_core"],
            preserve=["whole_board_operation_space"],
            play="只教目标印记，不引入障碍。",
            visual="中心小花束构图，周围宝石做安静背景。",
            readability="最亮的中央就是玩法优先级。",
            theme="森林遗迹第一次被星尘点亮。",
            intended_solution=["在中央目标附近找三消", "让消除覆盖星尘格", "收掉剩余中央印记"],
            crack_path=["read_center_stardust", "access_open_board", "convert_matches_to_mark_progress", "finish_remaining_marks"],
        )
    if eye == "cleanse_edge":
        return design(
            thesis="reach_the_glowing_border",
            sentence="边框星尘也需要主动够到。",
            fantasy="沿魔法书页边框拾起散落的星尘碎片。",
            protagonist="target_mark",
            protagonist_as="edge_stardust",
            support=[],
            reward=[{"kind": "line_clear", "as": "border_sweep"}],
            stage_function="edge_reach",
            shape="open_7x7_border",
            dramatic_axis="center_to_edge",
            focus="edge_marks",
            friction_zone="board_edges",
            payoff_zone="edge_marks",
            operation_space="center_open_space",
            supply_logic="open_vertical_refill",
            world_state_change="border_stardust_cleansed",
            readable_goal="把机会送到四周边框，净化边缘星尘。",
            opening="中心很宽松，但星尘都在四周发光。",
            friction="边缘交换方向少，普通乱消容易停在中心。",
            turn="玩家把一次横向或纵向消除送到边缘。",
            payoff="一侧边框被扫亮，玩家理解边缘可达性。",
            signature="整条边缘星尘被一次线性机会带走。",
            negative_statement="中央保持干净，不放中心目标抢走视线。",
            forbid=["crystal_shell", "drop_relic", "creep_growth", "spawner", "timed_core"],
            preserve=["center_operation_space"],
            play="同一星尘目标改成位置挑战。",
            visual="发光边框像书页边饰。",
            readability="HUD 星尘、边框星尘、玩法优先级三点一致。",
            theme="修复魔法书页破损边框。",
            intended_solution=["从中心制造边缘可达机会", "优先清四角和边缘", "用横竖消除扫边"],
            crack_path=["read_edge_stardust", "access_edge_from_center", "convert_edge_matches_to_progress", "finish_corner_marks"],
        )
    if eye == "cleanse_trail":
        return design(
            thesis="follow_the_stardust_tracks",
            sentence="星尘不是清单，而是一条能追踪的脚印路线。",
            fantasy="跟着迷路小兽留下的星尘脚印穿过林地。",
            protagonist="target_mark",
            protagonist_as="stardust_trail",
            support=[],
            reward=[{"kind": "trail_cascade", "as": "footprints_fade"}],
            stage_function="trail_reading",
            shape="open_7x7_diagonal_trail",
            dramatic_axis="upper_left_to_lower_center",
            focus="trail_marks",
            friction_zone="trail_turns",
            payoff_zone="trail_marks",
            operation_space="both_sides_of_trail",
            supply_logic="open_vertical_refill",
            world_state_change="stardust_trail_cleansed",
            readable_goal="沿脚印路线逐段净化星尘。",
            opening="星尘排成路径而不是一坨目标。",
            friction="路线拐点分散，玩家需要切换清理段落。",
            turn="中段脚印被连锁净化，整条路线方向变清楚。",
            payoff="最后几枚脚印熄灭，像把路线追到终点。",
            signature="拐弯处星尘一段段熄灭。",
            negative_statement="路径外不放第二机制，保留追踪感。",
            forbid=["crystal_shell", "drop_relic", "creep_growth", "spawner", "timed_core"],
            preserve=["trail_side_operation_space"],
            play="训练玩家读形状而非读数量。",
            visual="斜向脚印构图让棋盘有方向。",
            readability="玩家顺着星尘排列自然知道下一处。",
            theme="森林里迷路小兽留下的星尘脚印。",
            intended_solution=["沿路径附近找消除", "优先处理拐点", "用自然连锁收掉末端"],
            crack_path=["read_mark_trail", "access_trail_segments", "convert_matches_to_mark_progress", "finish_path_tail"],
        )
    if eye == "cleanse_expedition_weak":
        return design(
            thesis="send_magic_downstream",
            sentence="上游的控制力要穿过窄口，才能照亮下游星尘池。",
            fantasy="把上游魔力送过遗迹窄口，唤醒下游星尘池。",
            protagonist="target_mark",
            protagonist_as="downstream_pool",
            support=[],
            reward=[{"kind": "downstream_cascade", "as": "pool_lights_up"}],
            stage_function="downstream_expedition_intro",
            shape="safe_bottleneck",
            dramatic_axis="top_to_bottom",
            focus="downstream_marks",
            friction_zone="narrow_waist",
            payoff_zone="downstream_pool",
            operation_space="upper_board",
            supply_logic="narrow_vertical_flow_without_full_seal",
            world_state_change="downstream_stardust_pool_cleansed",
            readable_goal="从上游把消除机会送到下游星尘池。",
            opening="上方空间宽，下方星尘池明显更远。",
            friction="窄口让下游补给慢，乱消会在上游空转。",
            turn="一次纵向机会穿过窄口，下游开始活起来。",
            payoff="下游星尘池被连锁洗亮。",
            signature="魔力穿过窄腰后，底部三枚星尘连续净化。",
            negative_statement="不用晶壳封门，避免第一次水文关出现空白断供。",
            forbid=["crystal_shell", "drop_relic", "creep_growth", "spawner", "timed_core"],
            preserve=["upper_operation_space", "readable_supply_path"],
            play="地形距离本身成为题眼。",
            visual="上宽下收的安全瓶颈，焦点落在下游池。",
            readability="窄腰自然提示力量要往下送。",
            theme="遗迹河道把星尘带往低处。",
            intended_solution=["在上游制造纵向机会", "让消除穿过窄口", "收尾净化下游池"],
            crack_path=["read_downstream_pool", "access_bottleneck", "send_control_downstream", "payoff_downstream_cascade", "finish_remaining_marks"],
        )
    if eye == "crystal_shell_gate_practice":
        return design(
            thesis="open_gate_restores_flow",
            sentence="打开晶壳门，水文才恢复。",
            fantasy="敲开晶壳闸门，把魔法水流放进下游星尘池。",
            protagonist="crystal_shell",
            protagonist_as="gate",
            support=[{"mechanism": "target_mark", "as": "downstream_payoff"}],
            reward=[{"kind": "cascade", "as": "released_flow"}],
            stage_function="gate_release",
            shape="bottleneck_gate",
            dramatic_axis="top_to_bottom",
            focus="crystal_gate",
            friction_zone="center_gate",
            payoff_zone="downstream_pool",
            operation_space="upper_and_side_board",
            supply_logic="gate_blocks_downstream_flow_but_not_full_row",
            world_state_change="stardust_pool_cleansed_after_gate_opens",
            readable_goal="先开门，再净化门后的星尘池。",
            opening="中央晶壳门压住下游星尘池。",
            friction="直接清下游效率低，必须先破门。",
            turn="晶壳门破出缺口，补给穿过门洞。",
            payoff="门后星尘被一波连锁净化。",
            signature="中央晶壳门裂开，宝石瀑布落入下游星尘池。",
            negative_statement="门外保留两侧操作空地，不堆第二种障碍。",
            forbid=["drop_relic", "creep_growth", "spawner", "timed_core"],
            preserve=["side_operation_space", "readable_gate_path"],
            play="晶壳是主角，星尘是门后的收益。",
            visual="晶壳门像横向闸坝压住下方目标区。",
            readability="最硬最亮的门就是先处理点。",
            theme="晶能工坊封印门被魔法敲开。",
            intended_solution=["在门附近制造消除", "优先破中央晶壳", "门开后让下游连锁净化星尘"],
            crack_path=["read_bottleneck_gate", "access_gate_by_match_or_line", "activate_gate_break", "payoff_downstream_cascade", "convert_to_target_mark_progress", "finish_remaining_marks"],
            max_primary_mechanisms=2,
        )
    if eye == "shell_cleanup_breather":
        return design(
            thesis="clean_up_loose_crystals",
            sentence="晶壳也可以是轻爽清理，而不总是硬门。",
            fantasy="帮宠物清理散落在工坊里的小晶壳。",
            protagonist="crystal_shell",
            protagonist_as="loose_shells",
            support=[],
            reward=[{"kind": "shell_pop_chain", "as": "clean_workshop"}],
            stage_function="breather_cleanup",
            shape="open_7x7_scatter",
            dramatic_axis="scatter_to_clear",
            focus="soft_shell_clusters",
            friction_zone="shell_neighbors",
            payoff_zone="whole_board",
            operation_space="whole_board",
            supply_logic="open_vertical_refill",
            world_state_change="all_loose_crystals_cleared",
            readable_goal="敲碎散落晶壳，清空工坊。",
            opening="少量晶壳散在开阔棋盘，压力低。",
            friction="晶壳分散，需要在各处找相邻消除。",
            turn="一次连锁敲掉两三块晶壳。",
            payoff="最后一块晶壳碎掉，棋盘完全打开。",
            signature="散落晶壳叮叮敲碎，像打扫完工坊。",
            negative_statement="不放星尘目标，不让喘息关变成双目标清单。",
            forbid=["target_mark", "drop_relic", "creep_growth", "spawner", "timed_core"],
            preserve=["whole_board_operation_space"],
            play="复习晶壳处理，降低认知负荷。",
            visual="五点散落像待清理小石子。",
            readability="每个晶壳都是直接目标。",
            theme="晶能工坊碎壳清扫。",
            intended_solution=["找晶壳旁边的普通消除", "利用开阔盘面制造连锁", "清完剩余晶壳"],
            crack_path=["read_shell_targets", "access_adjacent_matches", "convert_matches_to_shell_breaks", "finish_remaining_shells"],
        )
    if eye == "split_supply_duet":
        return design(
            thesis="two_pages_need_two_plans",
            sentence="裂开的两页各自补给，左右星尘要分别照顾。",
            fantasy="修复被裂缝分成左右两页的魔法书。",
            protagonist="target_mark",
            protagonist_as="split_page_stardust",
            support=[],
            reward=[{"kind": "side_by_side_cascade", "as": "both_pages_light"}],
            stage_function="split_supply_duet",
            shape="split_columns",
            dramatic_axis="left_right_duet",
            focus="left_and_right_page_marks",
            friction_zone="center_crack",
            payoff_zone="two_page_marks",
            operation_space="left_area_and_right_area",
            supply_logic="two_independent_vertical_refill_areas",
            world_state_change="both_pages_stardust_cleansed",
            readable_goal="分别在左右两页净化星尘，不能指望中间裂缝互相帮忙。",
            opening="中间裂缝把棋盘切成左右两页，星尘在两侧对称发光。",
            friction="左右不互通，一边的好运不会自动救另一边。",
            turn="玩家开始分别经营左右两边，而不是只盯一个区域。",
            payoff="左右两页先后被点亮，像合上一本修好的魔法书。",
            signature="左页连锁后转到右页收尾，两边星尘依次亮灭。",
            negative_statement="不加入晶壳或幼兽，让双区补给本身成为题眼。",
            forbid=["crystal_shell", "drop_relic", "creep_growth", "spawner", "timed_core"],
            preserve=["left_area_operation_space", "right_area_operation_space", "center_crack_readability"],
            play="地图舞台第一次成为主角级问题：左右补给独立。",
            visual="中间裂缝把书页切开，星尘在两侧呼应。",
            readability="HUD 星尘与两侧目标一致，中缝明确告诉玩家不能跨区。",
            theme="魔法书被裂缝分成两页，需要分别修复。",
            intended_solution=["先读出左右两区独立", "在左区处理左页星尘", "切换到右区处理右页星尘", "避免只在一侧空转"],
            crack_path=["read_split_pages", "access_left_area", "convert_left_matches", "access_right_area", "convert_right_matches", "finish_remaining_marks"],
        )
    if eye == "cleanse_siege":
        return design(
            thesis="break_the_ring_to_open_the_vault",
            sentence="先破壳环，才能拿到中心星尘宝库。",
            fantasy="破解晶壳环，打开矿洞中心的星尘宝库。",
            protagonist="crystal_shell",
            protagonist_as="vault_ring",
            support=[{"mechanism": "target_mark", "as": "center_treasure"}],
            reward=[{"kind": "burst_clear", "as": "vault_opens"}],
            stage_function="vault_siege",
            shape="open_9x9_center_vault",
            dramatic_axis="outside_to_center",
            focus="vault_shell_ring",
            friction_zone="shell_ring",
            payoff_zone="center_vault_marks",
            operation_space="outer_board",
            supply_logic="open_refill_around_enclosure",
            world_state_change="center_stardust_vault_cleansed_after_ring_breaks",
            readable_goal="先破外圈晶壳，再净化中心星尘宝库。",
            opening="中心星尘很诱人，但外圈晶壳挡住入口。",
            friction="玩家能看见收益，却必须先拆外围。",
            turn="晶壳环破开一侧，中心目标变得可触达。",
            payoff="中心星尘被爆破或线消一口气收掉。",
            signature="晶壳环打开缺口，中心宝库被一次爆破点亮。",
            negative_statement="环外保留开阔操作区，让围城不是窒息。",
            forbid=["drop_relic", "creep_growth", "spawner", "timed_core"],
            preserve=["outer_operation_space"],
            play="围城题眼：先破壳环，再拿中心收益。",
            visual="中心宝库和外圈护盾构图稳定。",
            readability="壳环包住目标，天然说明先破外围。",
            theme="水晶矿洞里的封存宝库。",
            intended_solution=["先破外圈晶壳", "打开中心目标区", "用爆破或线消收尾"],
            crack_path=["read_vault_shell", "access_vault_ring", "activate_shell_break", "payoff_center_opens", "convert_to_target_mark_progress", "finish_remaining_marks"],
            max_primary_mechanisms=2,
        )
    if eye == "drop_direct":
        return design(
            thesis="clear_path_rescues_lost_cub",
            sentence="清开脚下道路，就是护送迷路幼兽回家。",
            fantasy="清开脚下道路，把迷路幼兽送回底部巢门。",
            protagonist="drop_relic",
            protagonist_as="lost_cub",
            support=[],
            reward=[{"kind": "arrival", "as": "cub_reaches_nest"}],
            stage_function="rescue_route",
            shape="open_9x9_vertical_axis",
            dramatic_axis="top_to_bottom_rescue",
            focus="lost_cub_start_to_nest_exit",
            friction_zone="cells_below_cub",
            payoff_zone="bottom_nest",
            operation_space="around_cub_column",
            supply_logic="actor_falls_with_vertical_refill",
            world_state_change="lost_cub_reaches_nest",
            readable_goal="清掉幼兽脚下路线，让它落到底部巢门。",
            opening="幼兽在上、巢门在下，同列关系清楚。",
            friction="幼兽占格，玩家要清它下方而不是消它。",
            turn="幼兽第一次下落一格，护送规则成立。",
            payoff="幼兽落入巢门，目标立刻完成。",
            signature="幼兽沿直线掉进巢门，顶部目标同步完成。",
            negative_statement="不放晶壳和侧向路线，避免首见运输目标被噪音淹没。",
            forbid=["crystal_shell", "target_mark", "creep_growth", "spawner", "timed_core"],
            preserve=["straight_route_readability"],
            play="运输目标教学，只考清下方路径。",
            visual="幼兽与巢门垂直对齐，像救援绳。",
            readability="上幼兽、下巢门，一眼说明通关条件。",
            theme="森林小兽迷路回家。",
            intended_solution=["看清幼兽所在列和巢门", "优先清幼兽下方路径", "让幼兽落到底部巢门"],
            crack_path=["read_lost_cub_and_exit", "access_drop_path", "clear_below_cub", "payoff_cub_falls", "finish_drop_objective"],
        )
    if eye == "drop_bottleneck":
        return design(
            thesis="open_gate_then_rescue_cub",
            sentence="先开门，再护送幼兽回家。",
            fantasy="打开晶壳门，护送迷路幼兽穿过工坊回到巢门。",
            protagonist="drop_relic",
            protagonist_as="lost_cub",
            support=[{"mechanism": "crystal_shell", "as": "route_gate"}],
            reward=[{"kind": "arrival", "as": "cub_falls_through_gate"}],
            stage_function="rescue_route_with_gate",
            shape="bottleneck_gate_route",
            dramatic_axis="top_to_bottom_rescue",
            focus="cub_gate_nest_axis",
            friction_zone="crystal_gate_on_route",
            payoff_zone="bottom_nest",
            operation_space="upper_and_side_board",
            supply_logic="route_gate_blocks_actor_path_without_full_supply_seal",
            world_state_change="lost_cub_reaches_nest_after_gate_opens",
            readable_goal="先打开挡路晶壳门，再清路让幼兽回巢。",
            opening="幼兽、晶壳门、巢门在同一视觉轴上。",
            friction="幼兽下方路线被晶壳门卡住。",
            turn="门被打开后，幼兽路线连通。",
            payoff="幼兽穿过门洞落入巢门。",
            signature="晶壳门裂开后，幼兽连续下落穿过门洞回家。",
            negative_statement="只保留晶壳作为配角，不叠星尘目标。",
            forbid=["target_mark", "creep_growth", "spawner", "timed_core"],
            preserve=["cub_gate_nest_readability", "side_operation_space"],
            play="运输目标是主角，晶壳只服务幼兽路线。",
            visual="竖向救援轴穿过中央门，像一条升降井。",
            readability="阻挡幼兽的门就是玩家必须先处理的点。",
            theme="晶能工坊里的小兽救援。",
            intended_solution=["看清幼兽-门-巢门轴线", "先破挡路晶壳", "清幼兽下方路径", "让幼兽穿过门洞回家"],
            crack_path=["read_cub_gate_nest_axis", "access_gate", "activate_gate_break", "access_drop_path", "payoff_cub_falls", "finish_drop_objective"],
            max_primary_mechanisms=2,
        )
    raise ValueError(f"no level_design principles for eye {eye!r}")


def design_claim_from_level_design(level_design: dict[str, Any]) -> dict[str, Any]:
    solution = level_design.get("solution", {})
    return {
        "eye": level_design.get("thesis", {}).get("sentence", ""),
        "visual_focus": level_design.get("stage", {}).get("focus", ""),
        "intended_solution": solution.get("intended_solution", []),
        "crack_path": solution.get("crack_path", []),
        "climax": level_design.get("payoff", {}).get("signature", level_design.get("arc", {}).get("payoff", "")),
    }


def director_from_level_design(level_design: dict[str, Any]) -> dict[str, Any]:
    roles = level_design.get("roles", {})
    protagonist = roles.get("protagonist", {}) if isinstance(roles.get("protagonist"), dict) else {}
    support = roles.get("support", []) if isinstance(roles.get("support"), list) else []
    support_mechanisms = [str(item.get("mechanism")) for item in support if isinstance(item, dict) and item.get("mechanism")]
    negative = level_design.get("negative_space", {}) if isinstance(level_design.get("negative_space"), dict) else {}
    validation = level_design.get("validation", {}) if isinstance(level_design.get("validation"), dict) else {}
    return {
        "intent": level_design.get("thesis", {}).get("sentence", ""),
        "player_fantasy": level_design.get("fantasy", ""),
        "protagonist": protagonist.get("mechanism", ""),
        "supporting_roles": support_mechanisms,
        "emotional_arc": level_design.get("arc", {}),
        "signature_moment": level_design.get("payoff", {}).get("signature", ""),
        "negative_space": negative.get("statement", ""),
        "four_in_one": level_design.get("four_in_one", {}),
        "anti_slop": {
            "max_primary_mechanisms": int(validation.get("max_primary_mechanisms", 1) or 1),
            "forbidden": sorted(set(str(x) for x in negative.get("forbid", [])) | FORBIDDEN_GENERATED_OBJECTIVES),
            "no_color_order_goal": True,
            "reject_if": validation.get("reject_if", []),
        },
    }


def generated_design_claim(level: int, coord: dict[str, Any]) -> dict[str, Any]:
    eye = coord["eye"]
    if eye == "crystal_shell_gate_practice":
        return {
            "eye": "晶壳门卡住下游星尘池，玩家必须先开门再净化。",
            "visual_focus": "中央 2x3 晶壳门压住下方星尘池。",
            "intended_solution": ["在上游找纵向线消机会", "优先破中央晶壳门", "门开后让下游 cascade 净化星尘印记"],
            "crack_path": ["read_bottleneck_gate", "access_gate_by_match_or_line", "activate_supply_recovery", "payoff_downstream_cascade", "convert_to_target_mark_progress", "finish_remaining_marks"],
            "climax": "晶壳门破后，下游星尘池连续净化。",
        }
    if eye.startswith("drop"):
        return {
            "eye": coord["intent"],
            "visual_focus": "迷路幼兽起点、下方路径和底部巢门。",
            "intended_solution": ["看清幼兽所在列和巢门", "优先清掉幼兽下方路径", "必要时先打开晶壳门", "让幼兽落到底部巢门"],
            "crack_path": ["read_lost_cub_and_exit", "access_drop_path", "activate_path_opening", "payoff_cub_falls", "convert_to_drop_relic_progress", "finish_remaining_objectives"],
            "climax": "迷路幼兽落入巢门回家。",
        }
    if eye == "shell_cleanup_breather":
        return {
            "eye": coord["intent"],
            "visual_focus": "开阔棋盘中少量散落晶壳。",
            "intended_solution": ["找晶壳旁边的普通消除", "利用开阔盘面制造连锁", "清完剩余晶壳"],
            "crack_path": ["read_shell_targets", "access_adjacent_matches", "convert_matches_to_shell_breaks", "finish_remaining_shells"],
            "climax": "一次连锁连续敲碎多块晶壳。",
        }
    if eye == "cleanse_trail":
        return {
            "eye": coord["intent"],
            "visual_focus": "开阔棋盘里的星尘路径。",
            "intended_solution": ["沿星尘路径附近找消除", "用自然连锁净化中段", "收掉路径末端印记"],
            "crack_path": ["read_mark_trail", "access_open_board", "convert_matches_to_mark_progress", "finish_remaining_marks"],
            "climax": "星尘路径被连续净化。",
        }
    if "edge" in eye:
        return {
            "eye": coord["intent"],
            "visual_focus": "四周边缘星尘印记。",
            "intended_solution": ["优先找边缘附近的消除", "用横竖线消补掉边角"],
            "crack_path": ["read_edge_targets", "access_edge", "convert_matches_to_mark_progress", "finish_remaining_marks"],
            "climax": "边缘连续被清掉后盘面打开。",
        }
    if "expedition" in eye:
        return {
            "eye": coord["intent"],
            "visual_focus": "中央窄口和下方星尘池。",
            "intended_solution": ["在上游制造纵向清除", "通过窄口让下游产生连锁", "收尾净化下游印记"],
            "crack_path": ["read_downstream_pool", "access_bottleneck", "payoff_downstream_cascade", "convert_to_target_mark_progress", "finish_remaining_marks"],
            "climax": "窄口被打通后下游连续净化。",
        }
    if "siege" in eye:
        return {
            "eye": coord["intent"],
            "visual_focus": "中心星尘池和外圈晶壳。",
            "intended_solution": ["先破外圈晶壳", "打开中心目标区", "用爆破或线消收尾"],
            "crack_path": ["read_vault_shell", "access_vault", "activate_shell_break", "payoff_center_opens", "convert_to_target_mark_progress", "finish_remaining_marks"],
            "climax": "中心金库打开后一次爆破清掉多枚印记。",
        }
    return {
        "eye": coord["intent"],
        "visual_focus": "目标区。",
        "intended_solution": ["读取目标", "制造可用消除", "完成目标"],
        "crack_path": ["read_objective", "access_target", "convert_progress", "finish"],
        "climax": "目标完成。",
    }



def generated_director_claim(level: int, coord: dict[str, Any]) -> dict[str, Any]:
    """Machine-readable taste contract for a generated level.

    `design_claim` explains how to solve the level. `director` explains why the
    level deserves to exist: the intended feeling, the one protagonist mechanism,
    the memorable moment, and what the generator deliberately leaves out.
    """
    eye = coord["eye"]
    protagonist = OBJECTIVE_TO_LAYER.get(coord["objective"]["type"], "target_mark")
    supporting_roles: list[str] = []

    def claim(
        *,
        intent: str,
        player_fantasy: str,
        protagonist: str = protagonist,
        supporting_roles: list[str] | None = None,
        opening: str,
        friction: str,
        turn: str,
        payoff: str,
        signature_moment: str,
        negative_space: str,
        play: str,
        visual: str,
        readability: str,
        theme: str,
        max_primary_mechanisms: int = 2,
    ) -> dict[str, Any]:
        return {
            "intent": intent,
            "player_fantasy": player_fantasy,
            "protagonist": protagonist,
            "supporting_roles": supporting_roles or [],
            "emotional_arc": {"opening": opening, "friction": friction, "turn": turn, "payoff": payoff},
            "signature_moment": signature_moment,
            "negative_space": negative_space,
            "four_in_one": {"play": play, "visual": visual, "readability": readability, "theme": theme},
            "anti_slop": {
                "max_primary_mechanisms": max_primary_mechanisms,
                "forbidden": sorted(set(coord.get("forbidden", []) + list(FORBIDDEN_GENERATED_OBJECTIVES))),
                "no_color_order_goal": True,
                "reject_if": ["generic_clear_list", "unreadable_icon_only", "mechanism_pileup"],
            },
        }

    if eye == "cleanse_direct":
        return claim(
            intent="第一关只雕一个中心星尘焦点：玩家不是在消颜色，而是在擦亮遗迹的第一枚魔法印记。",
            player_fantasy="帮时兔点亮森林遗迹中央的星尘徽记。",
            protagonist="target_mark",
            opening="目标都聚在中央，玩家一眼敢下手。",
            friction="星尘不会自动消失，必须在它身上或旁边做出有效三消。",
            turn="中心连消开始带走多枚印记，玩家理解净化规则。",
            payoff="中央徽记恢复干净，形成第一口小爽感。",
            signature_moment="中央六枚星尘被连续净化，棋盘像被擦亮一块。",
            negative_space="边缘不放干扰，留白把视线和操作都推回中心。",
            play="近距离教学目标印记，不用额外障碍稀释规则。",
            visual="中心小花束构图，普通宝石作为背景。",
            readability="最亮的区域就是要净化的区域。",
            theme="森林遗迹第一次被魔法星尘点亮。",
            max_primary_mechanisms=1,
        )
    if eye == "cleanse_edge":
        return claim(
            intent="把同一种星尘目标推到边缘，让玩家学会边角不是装饰，而是需要主动够到的边界。",
            player_fantasy="沿书页边框拾起散落的星尘碎片。",
            protagonist="target_mark",
            opening="棋盘中间很宽松，但目标在四周发光。",
            friction="边缘可交换方向少，玩家要把机会送到边上。",
            turn="一条横线或竖线擦过边缘，几个边角同时被救回来。",
            payoff="四周星尘逐圈消失，画面从边框开始变干净。",
            signature_moment="一侧边缘被整排净化，玩家第一次感到线消的价值。",
            negative_space="中央保持开阔，避免玩家误以为中心才是题眼。",
            play="目标位置变化带来执行难度，不新增规则。",
            visual="边缘花环构图，留出中庭作操作区。",
            readability="发光边框直接告诉玩家要向外侧发力。",
            theme="像修复一本魔法书破损的边框。",
            max_primary_mechanisms=1,
        )
    if eye == "cleanse_trail":
        return claim(
            intent="把星尘做成一条路径，让玩家沿着形状追踪，而不是扫清一堆无序点。",
            player_fantasy="跟着小兽留下的星尘脚印穿过林地。",
            protagonist="target_mark",
            opening="星尘不是一团，而是一条能读出来的路。",
            friction="路径拐点分散，玩家要在不同小段之间切换注意力。",
            turn="中段被连锁净化后，整条路径的方向突然清楚。",
            payoff="最后几枚脚印被抹去，像把路线追到了终点。",
            signature_moment="拐弯处连续净化，星尘脚印一段段熄灭。",
            negative_space="路径外不塞第二机制，保留追踪感。",
            play="同一目标改成阅读路线，训练目标分布理解。",
            visual="斜向步道构图，比方块堆更有方向。",
            readability="玩家顺着星尘排列自然知道下一处该清哪里。",
            theme="森林里迷路脚印的轻叙事。",
            max_primary_mechanisms=1,
        )
    if eye == "cleanse_expedition_weak":
        return claim(
            intent="第 4 关只展示上游到下游的水文距离，不再用硬障碍把棋子堵空。",
            player_fantasy="把上游魔力送过窄口，唤醒下游星尘池。",
            protagonist="target_mark",
            opening="上半区好下手，下方星尘池明显更远。",
            friction="窄口让下游补给慢，乱消会在上游空转。",
            turn="一次纵向控制穿过窄口，下游开始自己连锁。",
            payoff="下游星尘池被连锁洗亮。",
            signature_moment="魔力穿过窄腰落到下游，连续净化三枚星尘。",
            negative_space="不用晶壳封门，避免玩家看到空白断供区。",
            play="地形距离本身成为题眼，障碍不抢戏。",
            visual="弱沙漏构图，上宽下聚。",
            readability="窄腰自然提示力量要往下送。",
            theme="遗迹河道把星尘带往低处。",
            max_primary_mechanisms=1,
        )
    if eye == "crystal_shell_gate_practice":
        return claim(
            intent="第 5 关是第一道真正的晶壳门：玩家的记忆点应是‘先开门，水才会活’。",
            player_fantasy="敲开晶壳闸门，把魔法水流放进下游星尘池。",
            protagonist="crystal_shell",
            supporting_roles=["target_mark"],
            opening="中央晶壳门横在视线正中，下方星尘池像被压住。",
            friction="直接清下游效率低，必须先在门附近找突破口。",
            turn="晶壳门破出缺口后，补给穿过门洞，下游开始活起来。",
            payoff="门后星尘被一波连锁净化，玩家感到自己打开了水闸。",
            signature_moment="中央 2x3 晶壳门裂开，宝石瀑布落入下游星尘池。",
            negative_space="门外保留两侧操作空地，不堆第二种障碍。",
            play="晶壳改变补给水文，是主角；星尘只是门后的收益。",
            visual="晶壳门像横向闸坝，压住下方目标区。",
            readability="最硬、最亮的门就是先处理的地方。",
            theme="晶能工坊的封印门被魔法敲开。",
        )
    if eye == "shell_cleanup_breather":
        return claim(
            intent="晶壳教学后给一关清脆喘息：不考水文，只让玩家享受敲壳反馈。",
            player_fantasy="帮宠物清理散落在工坊里的小晶壳。",
            protagonist="crystal_shell",
            opening="少量晶壳散在开阔棋盘，压力低。",
            friction="晶壳分散，玩家要在各处找相邻消除。",
            turn="一次连锁敲掉两三块晶壳，节奏变轻。",
            payoff="最后一块晶壳碎掉，棋盘完全打开。",
            signature_moment="散落晶壳被连锁叮叮敲碎，像打扫完工坊。",
            negative_space="不放星尘目标，不让喘息关变成双目标清单。",
            play="单机制复习，降低认知负荷。",
            visual="五点散落构图，像待清理的小石子。",
            readability="每个晶壳都是直接目标，没有隐藏优先级。",
            theme="晶能工坊的碎壳清扫。",
            max_primary_mechanisms=1,
        )
    if eye == "cleanse_expedition":
        return claim(
            intent="把第 4 关的弱水文升级为正式远征：玩家要主动把控制力送进下游死水区。",
            player_fantasy="从遗迹上游引导星光，穿过窄腰照亮下层星池。",
            protagonist="target_mark",
            opening="上游机会多，下游目标集中，距离感明确。",
            friction="窄腰让自然连锁不稳定，乱消很难碰到下游。",
            turn="玩家制造纵向清除或连锁穿过窄腰，下游开始松动。",
            payoff="下游星尘池连续净化，像水被终于引到低处。",
            signature_moment="一束纵向控制穿过窄腰，底部星尘连锁亮灭。",
            negative_space="不加新障碍，把压力留给地形和目标距离。",
            play="同机制做压力版，考控制力传递。",
            visual="更明确的沙漏形，焦点在窄腰与下游池。",
            readability="窄腰与目标池同线，暗示向下打通。",
            theme="时间沙漏里的星尘流向底部。",
            max_primary_mechanisms=1,
        )
    if eye == "cleanse_siege":
        return claim(
            intent="第 8 关做围城感：晶壳外圈不是硬凑数量，而是把中心星尘变成一座需要打开的金库。",
            player_fantasy="破解晶壳环，打开矿洞中心的星尘宝库。",
            protagonist="crystal_shell",
            supporting_roles=["target_mark"],
            opening="中心目标很诱人，但外圈晶壳清楚地挡住入口。",
            friction="玩家能看见收益，却必须先拆外圈。",
            turn="晶壳环破开一侧后，中心目标变得可触达。",
            payoff="中心星尘被爆破或线消一口气收掉。",
            signature_moment="晶壳环打开缺口，中心宝库被一次爆破点亮。",
            negative_space="环外保留开阔操作区，让围城不是窒息。",
            play="围城题眼：先破壳环，再拿中心收益。",
            visual="中心宝库 + 外圈护盾，构图稳定。",
            readability="壳环包住目标，天然说明先破外围。",
            theme="水晶矿洞里的封存宝库。",
        )
    if eye == "drop_direct":
        return claim(
            intent="迷路幼兽第一次出现必须像一个会移动的角色，而不是一个看不懂的目标头像。",
            player_fantasy="清开脚下道路，把迷路幼兽送回底部巢门。",
            protagonist="drop_relic",
            opening="幼兽在同一列上方，巢门在正下方，救援路线直观。",
            friction="幼兽自己占格，玩家要清它下方而不是把它当普通宝石消掉。",
            turn="幼兽第一次下落一格，玩家理解‘清路=护送’。",
            payoff="幼兽落入底部巢门，目标数字立刻完成。",
            signature_moment="幼兽沿直线掉进巢门，顶部目标图标同步消失。",
            negative_space="不放晶壳和侧向路线，避免首见运输目标被噪音淹没。",
            play="运输目标教学，只考清下方路径。",
            visual="幼兽与巢门垂直对齐，像一条救援绳。",
            readability="上幼兽、下巢门，同列关系一眼说明通关条件。",
            theme="森林小兽迷路回家。",
            max_primary_mechanisms=1,
        )
    if eye == "drop_bottleneck":
        return claim(
            intent="把幼兽护送和晶壳门配对：不是多塞机制，而是先开门再护送的两段式小戏剧。",
            player_fantasy="打开晶壳门，护送迷路幼兽穿过工坊回到巢门。",
            protagonist="drop_relic",
            supporting_roles=["crystal_shell"],
            opening="幼兽、晶壳门、巢门在同一视觉轴上。",
            friction="幼兽下方路线被晶壳门卡住，不能只在幼兽周围乱消。",
            turn="门被打开后，幼兽的下降路线突然连通。",
            payoff="幼兽穿过门洞落入巢门，形成明确救援结局。",
            signature_moment="晶壳门裂开后，幼兽连续下落穿过门洞回家。",
            negative_space="只保留晶壳作为配角，不叠星尘目标。",
            play="运输目标 + 门控水文，二者共用同一条竖向路径。",
            visual="竖向救援轴穿过中央门，构图像一条升降井。",
            readability="阻挡幼兽的门就是玩家必须先处理的点。",
            theme="晶能工坊里的小兽救援。",
        )
    return claim(
        intent=f"第 {level} 关必须围绕一个明确题眼成立，而不是模板换数字。",
        player_fantasy="用魔法宝石解决一个清楚可读的小麻烦。",
        protagonist=protagonist,
        supporting_roles=supporting_roles,
        opening="玩家能在开局读出主要目标。",
        friction="主角机制制造唯一主要阻力。",
        turn="玩家按破局路径让主角机制发生状态变化。",
        payoff="主角机制释放收益并完成目标。",
        signature_moment="主角机制被破解后产生一次可见爽点。",
        negative_space="不加入与题眼无关的第二套噪音。",
        play="单题眼驱动玩法。",
        visual="视觉焦点跟玩法焦点重合。",
        readability="玩家能从形状读出优先级。",
        theme="魔法世界主题给机制提供风味。",
    )

def generate_level(level: int, variant: str = "base", candidate: int | None = None) -> dict[str, Any]:
    if level not in LEVEL_COORDINATES:
        raise ValueError(f"no programmatic coordinate for level {level}")
    if variant not in VARIANT_RULES:
        raise ValueError(f"unknown variant {variant}")
    coord = LEVEL_COORDINATES[level]
    variant_rule = VARIANT_RULES[variant]
    tuning = candidate_tuning(candidate)
    role = coord["role"]
    role_defaults = ROLE_DEFAULTS[role]
    rows = TERRAIN_TEMPLATES[coord["terrain"]]
    width, height = board_size(rows)
    moves = max(8, int(coord.get("moves", role_defaults["moves"])) + int(variant_rule["moves_delta"]) + int(tuning["moves_delta"]))
    if "min_moves" in coord:
        moves = max(int(coord["min_moves"]), moves)
    if "max_moves" in coord:
        moves = min(int(coord["max_moves"]), moves)
    colors = max(4, min(6, int(coord.get("colors", role_defaults["colors"])) + int(tuning["colors_delta"])))
    if "min_colors" in coord:
        colors = max(int(coord["min_colors"]), colors)
    if "max_colors" in coord:
        colors = min(int(coord["max_colors"]), colors)
    target_multiplier = float(variant_rule["target_multiplier"]) * float(tuning["target_multiplier"])
    shell_hp_delta = int(variant_rule["shell_hp_delta"]) + int(tuning["shell_hp_delta"])
    if "max_shell_hp" in coord:
        shell_hp_delta = min(shell_hp_delta, max(0, int(coord["max_shell_hp"]) - 1))
    if "min_shell_hp" in coord:
        shell_hp_delta = max(shell_hp_delta, max(0, int(coord["min_shell_hp"]) - 1))
    seed = 1000 + level * 17 + list(VARIANT_RULES).index(variant) + (0 if candidate is None else candidate * 997)
    level_id = f"level_{level:03d}_{variant}" if candidate is None else f"level_{level:03d}_{variant}_c{candidate:02d}"
    level_design = generated_level_design(level, coord)
    progression = generated_progression(level, coord)
    obstacle_composition = generated_obstacle_composition(level, coord)
    level_intent = generated_level_intent(level, coord)
    placements = list(coord["placements"]) + list(coord.get("reward_placements", []))
    overlays = build_overlays(placements, shell_hp_delta)
    objective = objective_with_variant(coord["objective"], target_multiplier)
    draft_for_mechanisms = {
        "objective": objective,
        "overlays": overlays,
        "mechanisms": [],
    }
    mechanism_specs = generated_mechanism_specs(level, coord, draft_for_mechanisms)

    return {
        "id": level_id,
        "version": 0,
        "compile_mode": "playable",
        "meta": {
            "level_coordinate": level,
            "variant": variant,
            "role": role,
            "complexity_tier": coord["complexity_tier"],
            "theme": coord["theme"],
            "target_pass_band": coord["target_pass_band"],
            "generated_by": "tools/level_tool.py generate",
            "candidate_index": candidate,
            "candidate_tuning": tuning if candidate is not None else None,
        },
        "personalization": {
            "profile_band": "default_mid_skill",
            "cold_start_prior": variant_rule["prior"],
            "prior_weight": variant_rule["prior_weight"],
            "persona_axes": copy.deepcopy(PERSONA_AXES_BY_PRIOR[str(variant_rule["prior"])]),
            "target_pass_band": coord["target_pass_band"],
            "target_attempts_to_first_win": [1.0, 2.0] if role in {"teaching", "teaching_breather"} else [1.5, 3.0],
            "pet_skill_context": "ignored_v0",
        },
        "objective": objective,
        "rules": {"moves": moves, "colors": colors, "refill": "random", "gravity": "down", "seed": seed},
        "map": {
            "width": width,
            "height": height,
            "terrain": {"sample": coord["terrain"].replace("_7x7", "").replace("_7x9", "").replace("_9x9", "")},
            "supply_topology": {"type": coord.get("topology", "vertical_down")},
        },
        "recipe": {
            "eye": coord["eye"],
            "obstacle_lane": {
                "focus": "crystal_shell" if "crystal_gate" in coord["placements"] or "shell" in coord["eye"] else ("target_mark" if coord["objective"]["type"] == "cleanse_marks" else "none"),
                "stage": role,
                "active": sorted({name for entry in build_overlays(coord["placements"]) for name in layer_names(entry.get("layers", []))}),
                "forbidden": coord.get("forbidden", []),
            },
            "mechanism_lane": {"focus": "none", "stage": "none"},
            "intended_control": coord["control"],
        },
        "board": rows,
        "overlays": overlays,
        "mechanisms": [],
        "mechanism_specs": mechanism_specs,
        "level_intent": level_intent,
        "progression": progression,
        "obstacle_composition": obstacle_composition,
        "level_design": level_design,
        "design_claim": design_claim_from_level_design(level_design),
        "director": director_from_level_design(level_design),
    }


def write_generated_levels(levels: list[int], variant: str, out_dir: Path) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for level in levels:
        lvl = generate_level(level, variant)
        path = out_dir / f"level_{level:03d}_{variant}.lvl"
        path.write_text(json.dumps(lvl, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        written.append(path)
    return written


def load_lvl(path: Path) -> tuple[dict[str, Any] | None, Diagnostics]:
    d = Diagnostics()
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        d.error("E_READ_FILE", str(path), str(exc))
        return None, d
    try:
        obj = json.loads(text)
    except json.JSONDecodeError as exc:
        d.error("E_PARSE_JSON", str(path), f"{exc.msg} at line {exc.lineno}, col {exc.colno}")
        return None, d
    if not isinstance(obj, dict):
        d.error("E_ROOT_TYPE", "$", "root must be a JSON object")
        return None, d
    return obj, d


def board_rows(lvl: dict[str, Any], d: Diagnostics) -> list[str]:
    board = lvl.get("board")
    if isinstance(board, list) and all(isinstance(x, str) for x in board):
        return board
    if isinstance(board, str):
        return [line.rstrip("\n") for line in board.splitlines() if line.strip()]
    d.error("E_BOARD_TYPE", "board", "board must be a list of equal-width strings")
    return []


def lint_lvl(lvl: dict[str, Any]) -> Diagnostics:
    d = Diagnostics()
    required = ["id", "version", "compile_mode", "meta", "personalization", "rules", "map", "recipe", "board", "overlays", "level_design", "design_claim", "director"]
    for key in required:
        if key not in lvl:
            d.error("E_MISSING_FIELD", key, f"missing required root field: {key}")

    if "objective" in lvl and "objectives" in lvl:
        d.error("E_OBJECTIVE_CONFLICT", "objective/objectives", "use either objective or objectives, not both")
    if "objective" not in lvl and "objectives" not in lvl:
        d.error("E_MISSING_FIELD", "objective", "one of objective/objectives is required")

    compile_mode = lvl.get("compile_mode", "playable")
    if compile_mode not in {"playable", "design_only"}:
        d.error("E_COMPILE_MODE", "compile_mode", "compile_mode must be playable or design_only")

    pass_band = lvl.get("meta", {}).get("target_pass_band")
    if not (isinstance(pass_band, list) and len(pass_band) == 2 and all(isinstance(x, (int, float)) for x in pass_band) and 0.0 <= float(pass_band[0]) <= float(pass_band[1]) <= 1.0):
        d.error("E_TARGET_PASS_BAND", "meta.target_pass_band", "target_pass_band must be [low, high] within 0..1")

    rows = board_rows(lvl, d)
    width = int(lvl.get("map", {}).get("width", 0) or 0)
    height = int(lvl.get("map", {}).get("height", 0) or 0)
    if rows:
        if height and len(rows) != height:
            d.error("E_BOARD_SIZE", "board", f"board height {len(rows)} != map.height {height}")
        if width:
            bad = [i for i, row in enumerate(rows) if len(row) != width]
            if bad:
                d.error("E_BOARD_SIZE", "board", f"rows {bad} do not match map.width {width}")
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                if ch != "." and ch not in PLAYABLE_TOKENS:
                    d.error("E_UNKNOWN_TOKEN", f"board[{r}][{c}]", f"unknown board token {ch!r}")

    rules = lvl.get("rules", {})
    colors = int(rules.get("colors", 0) or 0)
    if colors < 4 or colors > 6:
        d.error("E_COLOR_COUNT", "rules.colors", "rules.colors must be in [4, 6]")
    if rules.get("gravity", "down") != "down":
        d.error("E_UNSUPPORTED_GRAVITY", "rules.gravity", "v0 playable only supports gravity=down")

    topology = lvl.get("map", {}).get("supply_topology", {}).get("type", "vertical_down")
    if compile_mode == "playable" and topology not in SUPPORTED_TOPOLOGY:
        d.error("E_UNSUPPORTED_SUPPLY_TOPOLOGY", "map.supply_topology.type", f"{topology} is not playable_v0")

    for i, m in enumerate(lvl.get("mechanisms", []) or []):
        mtype = m.get("type")
        if compile_mode == "playable" and mtype in UNSUPPORTED_MECHANISMS:
            d.error("E_UNSUPPORTED_MECHANISM", f"mechanisms[{i}].type", f"{mtype} is design_only in v0")

    objectives = normalize_objectives(lvl)
    for i, obj in enumerate(objectives):
        typ = obj.get("type")
        if typ not in SUPPORTED_OBJECTIVES:
            d.error("E_UNSUPPORTED_OBJECTIVE", f"objectives[{i}].type", f"{typ} is not supported in playable_v0")
        if typ in FORBIDDEN_GENERATED_OBJECTIVES:
            d.error("E_FORBIDDEN_COLOR_TARGET_OBJECTIVE", f"objectives[{i}].type", f"{typ} uses a specific gem color as the goal; generated v0 levels must use board/mechanism goals")

    if "crack_path" not in lvl.get("design_claim", {}):
        d.error("E_MISSING_CRACK_PATH", "design_claim.crack_path", "design_claim.crack_path is required")

    # Overlay coordinate checks.
    for i, entry in enumerate(lvl.get("overlays", []) or []):
        cells = overlay_cells(entry)
        for cell in cells:
            if not valid_cell(cell, height, width):
                d.error("E_CELL_OUT_OF_RANGE", f"overlays[{i}]", f"cell {cell} out of range")
                continue
            if rows and rows[cell[0]][cell[1]] == "." and "drop_exit" not in layer_names(entry.get("layers", [])):
                d.error("E_LAYER_ON_HOLE", f"overlays[{i}]", f"cell {cell} is a hole")

    dead_zones = vertical_supply_dead_zones(rows)
    if dead_zones:
        d.error("E_GRAVITY_DEAD_ZONE", "board", f"playable cells below holes cannot be supplied in v0: {dead_zones[:12]}")
    sealed_rows = full_supply_seal_rows(rows, lvl)
    if sealed_rows:
        d.error("E_FULL_SUPPLY_SEAL", "overlays", f"crystal_shell seals every playable cell on row(s) {sealed_rows}")

    return d


def normalize_objectives(lvl: dict[str, Any]) -> list[dict[str, Any]]:
    if "objectives" in lvl:
        return list(lvl.get("objectives") or [])
    return [dict(lvl.get("objective") or {})]


def valid_cell(cell: Any, height: int, width: int) -> bool:
    return isinstance(cell, list) and len(cell) == 2 and isinstance(cell[0], int) and isinstance(cell[1], int) and 0 <= cell[0] < height and 0 <= cell[1] < width


def overlay_cells(entry: dict[str, Any]) -> list[list[int]]:
    if "cell" in entry:
        return [entry["cell"]]
    return list(entry.get("cells") or [])


def layer_names(layers: list[Any]) -> list[str]:
    out: list[str] = []
    for layer in layers or []:
        if isinstance(layer, str):
            out.append(layer)
        elif isinstance(layer, dict):
            out.extend(str(k) for k in layer.keys())
    return out


def vertical_supply_dead_zones(rows: list[str]) -> list[list[int]]:
    """Cells that cannot be supplied by straight top-down refill in v0.

    Godot supports some wall-slide behavior, but the early generated pack uses
    a stricter contract: no playable cell may sit below a hole in the same
    column. That prevents "pretty hourglass" maps from creating lower pockets
    that can become empty or visually confusing.
    """
    if not rows:
        return []
    h = len(rows)
    w = len(rows[0])
    dead: list[list[int]] = []
    for c in range(w):
        gap_above = False
        for r in range(h):
            if rows[r][c] == ".":
                gap_above = True
            elif gap_above:
                dead.append([r, c])
    return dead


def crystal_shell_cells(lvl: dict[str, Any]) -> set[tuple[int, int]]:
    cells: set[tuple[int, int]] = set()
    for entry in lvl.get("overlays", []) or []:
        if "crystal_shell" not in layer_names(entry.get("layers", [])):
            continue
        for r, c in overlay_cells(entry):
            cells.add((r, c))
    return cells


def full_supply_seal_rows(rows: list[str], lvl: dict[str, Any]) -> list[int]:
    """Rows where every playable cell is occupied by gravity-blocking shells."""
    if not rows:
        return []
    shells = crystal_shell_cells(lvl)
    sealed: list[int] = []
    for r, row in enumerate(rows):
        playable_cols = [c for c, ch in enumerate(row) if ch != "."]
        if not playable_cols:
            continue
        if not all((r, c) in shells for c in playable_cols):
            continue
        has_playable_below = any(rows[rr][c] != "." for c in playable_cols for rr in range(r + 1, len(rows)))
        if has_playable_below:
            sealed.append(r)
    return sealed


def layer_item(layer: Any) -> tuple[str, dict[str, Any]]:
    if isinstance(layer, str):
        return layer, {}
    if isinstance(layer, dict) and len(layer) == 1:
        key = next(iter(layer))
        val = layer[key]
        return str(key), dict(val or {})
    return str(layer), {}


def blank(h: int, w: int, value: int = 0) -> list[list[int]]:
    return [[value for _ in range(w)] for _ in range(h)]


def build_grid(rows: list[str], colors: int, seed: int) -> list[list[int]]:
    rng = random.Random(seed)
    grid: list[list[int]] = []
    for r, row in enumerate(rows):
        out_row: list[int] = []
        for c, ch in enumerate(row):
            if ch == ".":
                out_row.append(-2)
            elif ch in "123456":
                out_row.append(int(ch) - 1)
            else:
                choices = list(range(colors))
                rng.shuffle(choices)
                chosen = choices[0]
                for candidate in choices:
                    if not would_make_initial_match(grid, out_row, r, c, candidate):
                        chosen = candidate
                        break
                out_row.append(chosen)
        grid.append(out_row)
    return grid


def would_make_initial_match(grid: list[list[int]], row: list[int], r: int, c: int, val: int) -> bool:
    if val < 0:
        return False
    if c >= 2 and row[c - 1] == val and row[c - 2] == val:
        return True
    if r >= 2 and grid[r - 1][c] == val and grid[r - 2][c] == val:
        return True
    return False


def compile_lvl(lvl: dict[str, Any]) -> tuple[dict[str, Any] | None, Diagnostics]:
    d = lint_lvl(lvl)
    if not d.ok:
        return None, d

    rows = board_rows(lvl, d)
    h = int(lvl["map"]["height"])
    w = int(lvl["map"]["width"])
    rules = lvl["rules"]
    colors = int(rules["colors"])
    seed = int(rules.get("seed", 0))

    jelly = blank(h, w)
    coat = blank(h, w)
    choco = blank(h, w)
    ing = blank(h, w)
    bomb = blank(h, w)
    cannon = blank(h, w)
    popcorn = blank(h, w)
    cake = blank(h, w)
    mystery = blank(h, w)
    fx = blank(h, w)
    exits: list[int] = []

    for entry in lvl.get("overlays", []) or []:
        for cell in overlay_cells(entry):
            r, c = cell
            for raw_layer in entry.get("layers", []) or []:
                name, params = layer_item(raw_layer)
                hp = int(params.get("hp", 1) or 1)
                if name == "target_mark":
                    jelly[r][c] = hp
                elif name == "crystal_shell":
                    coat[r][c] = hp
                elif name == "creep_growth":
                    choco[r][c] = hp
                elif name == "drop_relic":
                    ing[r][c] = int(params.get("count", 1) or 1)
                elif name == "drop_exit":
                    if r != h - 1:
                        d.error("E_DROP_EXIT_ROW", "overlays", f"drop_exit must be on bottom row, got {cell}")
                    elif c not in exits:
                        exits.append(c)
                elif name == "timed_core":
                    bomb[r][c] = int(params.get("timer", max(1, int(rules["moves"]) // 2)))
                elif name == "spawner":
                    cannon[r][c] = int(params.get("kind", 1) or 1)
                elif name in {"popcorn", "cake", "mystery"}:
                    {"popcorn": popcorn, "cake": cake, "mystery": mystery}[name][r][c] = hp
                elif name in REWARD_LAYER_TO_FX:
                    fx[r][c] = REWARD_LAYER_TO_FX[name]
                else:
                    d.warn("W_IGNORED_LAYER", "overlays", f"ignored non-engine layer {name}")

    if not d.ok:
        return None, d

    objectives = [compile_objective(obj, jelly, coat, choco, ing, bomb, lvl, d) for obj in normalize_objectives(lvl)]
    objectives = [o for o in objectives if o]
    if not d.ok:
        return None, d

    init_board = build_grid(rows, colors, seed)
    for r in range(h):
        for c in range(w):
            if ing[r][c] > 0:
                init_board[r][c] = -1

    record = {
        "level_id": lvl["id"],
        "w": w,
        "h": h,
        "species": list(range(colors)),
        "init_board": init_board,
        "target_score": int(first_objective(lvl).get("target_score", 0) or 0),
        "move_limit": int(rules["moves"]),
        "seed": seed,
        "objectives": objectives,
        "jelly": jelly,
        "coat": coat,
        "choco": choco,
        "ing": ing,
        "exits": sorted(exits),
        "bomb": bomb,
        "cannon": cannon,
        "popcorn": popcorn,
        "cake": cake,
        "mystery": mystery,
        "fx": fx,
        "difficulty": difficulty_for_role(lvl.get("meta", {}).get("role", "")),
    }
    return record, d


def first_objective(lvl: dict[str, Any]) -> dict[str, Any]:
    return normalize_objectives(lvl)[0] if normalize_objectives(lvl) else {}


def layer_sum(layer: list[list[int]]) -> int:
    return sum(sum(max(0, int(x)) for x in row) for row in layer)


def compile_objective(obj: dict[str, Any], jelly: list[list[int]], coat: list[list[int]], choco: list[list[int]], ing: list[list[int]], bomb: list[list[int]], lvl: dict[str, Any], d: Diagnostics) -> dict[str, Any] | None:
    typ = obj.get("type")
    if typ == "cleanse_marks":
        target = layer_sum(jelly) if obj.get("target", "all") == "all" else int(obj.get("target", 0))
        if target <= 0:
            d.error("E_EMPTY_OBJECTIVE", "objective", "cleanse_marks requires at least one target_mark")
        return {"type": "CLEAR_JELLY", "species": -1, "target": target}
    if typ in {"collect", "order_color"}:
        if "species" not in obj:
            d.error("E_MISSING_OBJECTIVE_FIELD", "objective.species", f"{typ} requires species")
            return None
        return {"type": "COLLECT", "species": int(obj["species"]), "target": int(obj.get("target", 1))}
    if typ == "drop_relic":
        target = int(obj.get("target", layer_sum(ing)))
        if target <= 0:
            d.error("E_EMPTY_OBJECTIVE", "objective", "drop_relic requires at least one drop_relic")
        return {"type": "COLLECT_INGREDIENT", "species": -1, "target": target}
    if typ == "clear_shells":
        raw_target = obj.get("target", layer_sum(coat))
        target = layer_sum(coat) if raw_target == "all" else int(raw_target)
        if target <= 0:
            d.error("E_EMPTY_OBJECTIVE", "objective", "clear_shells requires at least one crystal_shell")
        return {"type": "CLEAR_BLOCKER", "species": -1, "target": target}
    if typ == "clear_creep":
        return {"type": "CLEAR_CHOCO", "species": -1, "target": int(obj.get("target", layer_sum(choco)))}
    if typ == "defuse_cores":
        return {"type": "DEFUSE_BOMB", "species": -1, "target": int(obj.get("target", layer_sum(bomb)))}
    if typ == "score":
        return {"type": "SCORE", "species": -1, "target": int(obj.get("target_score", 0))}
    d.error("E_UNSUPPORTED_OBJECTIVE", "objective.type", f"{typ} unsupported")
    return None


def difficulty_for_role(role: str) -> str:
    if role in {"teaching", "breather"}:
        return "EASY"
    if role in {"pressure", "pressure_lite", "variation"}:
        return "MEDIUM"
    if role == "peak":
        return "HARD"
    return "MEDIUM"


def find_matches(grid: list[list[int]]) -> set[tuple[int, int]]:
    h = len(grid)
    w = len(grid[0]) if h else 0
    found: set[tuple[int, int]] = set()
    for r in range(h):
        c = 0
        while c < w:
            val = grid[r][c]
            start = c
            while c < w and grid[r][c] == val:
                c += 1
            if val >= 0 and c - start >= 3:
                for x in range(start, c):
                    found.add((r, x))
    for c in range(w):
        r = 0
        while r < h:
            val = grid[r][c]
            start = r
            while r < h and grid[r][c] == val:
                r += 1
            if val >= 0 and r - start >= 3:
                for y in range(start, r):
                    found.add((y, c))
    return found


def find_match_runs(grid: list[list[int]]) -> list[list[tuple[int, int]]]:
    h = len(grid)
    w = len(grid[0]) if h else 0
    runs: list[list[tuple[int, int]]] = []
    for r in range(h):
        c = 0
        while c < w:
            val = grid[r][c]
            start = c
            while c < w and grid[r][c] == val:
                c += 1
            if val >= 0 and c - start >= 3:
                runs.append([(r, x) for x in range(start, c)])
    for c in range(w):
        r = 0
        while r < h:
            val = grid[r][c]
            start = r
            while r < h and grid[r][c] == val:
                r += 1
            if val >= 0 and r - start >= 3:
                runs.append([(y, c) for y in range(start, r)])
    return runs


def has_legal_move(grid: list[list[int]]) -> bool:
    h = len(grid)
    w = len(grid[0]) if h else 0
    for r in range(h):
        for c in range(w):
            if grid[r][c] < 0:
                continue
            for dr, dc in ((1, 0), (0, 1)):
                rr, cc = r + dr, c + dc
                if rr >= h or cc >= w or grid[rr][cc] < 0:
                    continue
                grid[r][c], grid[rr][cc] = grid[rr][cc], grid[r][c]
                ok = bool(find_matches(grid))
                grid[r][c], grid[rr][cc] = grid[rr][cc], grid[r][c]
                if ok:
                    return True
    return False



def active_layer_set(lvl: dict[str, Any]) -> set[str]:
    active: set[str] = set()
    for entry in lvl.get("overlays", []) or []:
        active.update(name for name in layer_names(entry.get("layers", [])) if name not in NON_MECHANISM_LAYERS)
    for mech in lvl.get("mechanisms", []) or []:
        mtype = mech.get("type")
        if isinstance(mtype, str):
            active.add(mtype)
    return active


def objective_layer_set(lvl: dict[str, Any]) -> set[str]:
    out: set[str] = set()
    for obj in normalize_objectives(lvl):
        layer = OBJECTIVE_TO_LAYER.get(str(obj.get("type")))
        if layer:
            out.add(layer)
    return out


def reward_layer_set(lvl: dict[str, Any]) -> set[str]:
    out: set[str] = set()
    for entry in lvl.get("overlays", []) or []:
        out.update(name for name in layer_names(entry.get("layers", [])) if name in REWARD_LAYER_TO_FX)
    return out


def mechanism_atoms_for_lvl(lvl: dict[str, Any]) -> set[str]:
    """All design atoms that need a mechanism spec in this level."""
    atoms = set(active_layer_set(lvl)) | set(reward_layer_set(lvl))
    for layer in objective_layer_set(lvl):
        atoms.add(layer)
    if cells_for_layer(lvl, "drop_exit"):
        atoms.add("drop_exit")
    for mech in lvl.get("mechanisms", []) or []:
        mtype = mech.get("type")
        if isinstance(mtype, str):
            atoms.add(mtype)
    return atoms


def cells_for_layer(lvl: dict[str, Any], layer_name: str) -> set[tuple[int, int]]:
    cells: set[tuple[int, int]] = set()
    for entry in lvl.get("overlays", []) or []:
        if layer_name not in layer_names(entry.get("layers", [])):
            continue
        for r, c in overlay_cells(entry):
            cells.add((r, c))
    return cells


def objective_cells(lvl: dict[str, Any]) -> set[tuple[int, int]]:
    cells: set[tuple[int, int]] = set()
    for layer in objective_layer_set(lvl):
        cells.update(cells_for_layer(lvl, layer))
    return cells


def playable_cell_set(rows: list[str]) -> set[tuple[int, int]]:
    return {(r, c) for r, row in enumerate(rows) for c, ch in enumerate(row) if ch != "."}


def centroid(cells: set[tuple[int, int]]) -> tuple[float, float] | None:
    if not cells:
        return None
    return (
        sum(r for r, _ in cells) / len(cells),
        sum(c for _, c in cells) / len(cells),
    )


def meaningful_director_text(value: Any, min_len: int = 8) -> bool:
    if not isinstance(value, str):
        return False
    text = value.strip()
    if len(text) < min_len:
        return False
    return text not in DIRECTOR_GENERIC_PHRASES


def director_text_blob(lvl: dict[str, Any]) -> str:
    director = lvl.get("director", {}) if isinstance(lvl.get("director"), dict) else {}
    design = lvl.get("design_claim", {}) if isinstance(lvl.get("design_claim"), dict) else {}
    parts: list[str] = []
    for obj in (director, director.get("emotional_arc", {}), director.get("four_in_one", {}), design):
        if isinstance(obj, dict):
            for val in obj.values():
                if isinstance(val, str):
                    parts.append(val)
                elif isinstance(val, list):
                    parts.extend(str(x) for x in val)
    return " ".join(parts)


def meaningful_semantic_text(value: Any, min_len: int = 4) -> bool:
    return isinstance(value, str) and len(value.strip()) >= min_len and value.strip() not in DIRECTOR_GENERIC_PHRASES


def semantic_validate_level_design(lvl: dict[str, Any]) -> dict[str, Any]:
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    checks: dict[str, Any] = {}
    score = 100

    def fail(code: str, path: str, message: str, penalty: int = 15) -> None:
        nonlocal score
        errors.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    def warn(code: str, path: str, message: str, penalty: int = 5) -> None:
        nonlocal score
        warnings.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    design = lvl.get("level_design")
    if not isinstance(design, dict):
        fail("E_NO_LEVEL_DESIGN", "level_design", "level_design semantic source is required", 40)
        return {"valid": False, "score": score, "checks": checks, "errors": errors, "warnings": warnings}

    thesis = design.get("thesis") if isinstance(design.get("thesis"), dict) else {}
    sentence_ok = meaningful_semantic_text(thesis.get("sentence"), 8)
    checks["thesis_sentence_specific"] = sentence_ok
    if not sentence_ok:
        fail("E_NO_THESIS", "level_design.thesis.sentence", "single-level thesis must be a specific sentence", 20)

    roles = design.get("roles") if isinstance(design.get("roles"), dict) else {}
    protagonist = roles.get("protagonist") if isinstance(roles.get("protagonist"), dict) else {}
    protagonist_mechanism = protagonist.get("mechanism")
    active = active_layer_set(lvl) - {"drop_exit"}
    objective_layers = objective_layer_set(lvl)
    protagonist_ok = isinstance(protagonist_mechanism, str) and protagonist_mechanism in (active | objective_layers)
    checks["one_protagonist_present"] = protagonist_ok
    if not protagonist_ok:
        fail("E_NO_PROTAGONIST", "level_design.roles.protagonist.mechanism", f"protagonist {protagonist_mechanism!r} must appear in overlays/objectives", 25)

    support = roles.get("support", [])
    if not isinstance(support, list):
        fail("E_SUPPORT_TYPE", "level_design.roles.support", "support must be a list", 10)
        support = []
    support_mechanisms = {str(item.get("mechanism")) for item in support if isinstance(item, dict) and item.get("mechanism")}
    declared = ({str(protagonist_mechanism)} if isinstance(protagonist_mechanism, str) else set()) | support_mechanisms
    undeclared = sorted(active - declared)
    checks["mechanisms_have_roles"] = not undeclared
    if undeclared:
        fail("E_UNROLE_MECHANISM", "level_design.roles", f"active mechanism(s) without semantic role: {undeclared}", 20)

    objective_covered = not objective_layers or bool(objective_layers & declared)
    checks["objective_has_semantic_role"] = objective_covered
    if not objective_covered:
        fail("E_NO_CAUSAL_CLOSURE", "level_design.roles", f"objective layer(s) {sorted(objective_layers)} must be protagonist or support", 20)

    stage = design.get("stage") if isinstance(design.get("stage"), dict) else {}
    required_stage = ["function", "dramatic_axis", "focus", "friction_zone", "payoff_zone", "operation_space", "supply_logic"]
    missing_stage = [key for key in required_stage if not meaningful_semantic_text(stage.get(key), 3)]
    checks["stage_function_complete"] = not missing_stage
    if missing_stage:
        fail("E_STAGE_INCOMPLETE", "level_design.stage", f"missing stage semantic fields: {missing_stage}", 15)

    arc = design.get("arc") if isinstance(design.get("arc"), dict) else {}
    missing_arc = [key for key in DIRECTOR_ARC_FIELDS if not meaningful_semantic_text(arc.get(key), 6)]
    checks["arc_turn_state_change"] = "turn" not in missing_arc and not missing_arc
    if missing_arc:
        fail("E_NO_TURN", "level_design.arc", f"missing or generic arc beats: {missing_arc}", 20)

    objective = design.get("objective") if isinstance(design.get("objective"), dict) else {}
    objective_ok = meaningful_semantic_text(objective.get("world_state_change"), 6) and meaningful_semantic_text(objective.get("player_readable_goal"), 8)
    checks["readable_world_state_goal"] = objective_ok
    if not objective_ok:
        fail("E_COUNTER_OBJECTIVE", "level_design.objective", "objective must be a readable world-state change, not a counter-only goal", 20)

    negative = design.get("negative_space") if isinstance(design.get("negative_space"), dict) else {}
    forbidden = set(str(x) for x in negative.get("forbid", []) if isinstance(x, str))
    objective_types = {str(obj.get("type")) for obj in normalize_objectives(lvl)}
    forbidden_hits = sorted((active | objective_types) & forbidden)
    checks["negative_space_enforced"] = not forbidden_hits
    if forbidden_hits:
        fail("E_UNDECLARED_NOISE", "level_design.negative_space.forbid", f"forbidden atom(s) present: {forbidden_hits}", 25)

    validation = design.get("validation") if isinstance(design.get("validation"), dict) else {}
    must_have = set(str(x) for x in validation.get("must_have", []) if isinstance(x, str))
    expected_must = {"one_protagonist", "causal_closure", "visual_play_alignment", "readable_world_state_goal", "arc_turn_state_change"}
    missing_must = sorted(expected_must - must_have)
    checks["validation_claims_complete"] = not missing_must
    if missing_must:
        warn("W_SEMANTIC_VALIDATION_CLAIMS", "level_design.validation.must_have", f"missing recommended semantic claims: {missing_must}", 5)

    director = lvl.get("director") if isinstance(lvl.get("director"), dict) else {}
    director_match = director.get("protagonist") == protagonist_mechanism
    checks["director_compiled_from_semantics"] = director_match
    if not director_match:
        fail("E_DIRECTOR_SEMANTIC_MISMATCH", "director.protagonist", "director protagonist must match level_design protagonist", 20)

    payoff = design.get("payoff") if isinstance(design.get("payoff"), dict) else {}
    payoff_ok = meaningful_semantic_text(payoff.get("signature"), 8)
    checks["payoff_visible"] = payoff_ok
    if not payoff_ok:
        fail("E_PAYOFF_DISCONNECTED", "level_design.payoff.signature", "payoff must be a visible signature moment", 15)

    return {"valid": not errors and score >= 80, "score": score, "checks": checks, "errors": errors, "warnings": warnings}


def taste_audit_lvl(lvl: dict[str, Any], compiled: dict[str, Any] | None = None) -> dict[str, Any]:
    """Executable taste gate.

    This is intentionally not a replacement for human taste. It catches the
    class of failure the user called out: rote levels that satisfy structure and
    solver metrics but do not declare a protagonist, emotional arc, memorable
    moment, or anti-pileup choice.
    """
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    checks: dict[str, Any] = {}
    score = 100

    def fail(code: str, path: str, message: str, penalty: int = 15) -> None:
        nonlocal score
        errors.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    def warn(code: str, path: str, message: str, penalty: int = 5) -> None:
        nonlocal score
        warnings.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    director = lvl.get("director")
    if not isinstance(director, dict):
        fail("E_DIRECTOR_MISSING", "director", "director taste contract is required", 30)
        return {"valid": False, "score": score, "checks": checks, "errors": errors, "warnings": warnings}

    missing = [field for field in DIRECTOR_REQUIRED_FIELDS if field not in director]
    checks["required_fields_present"] = not missing
    if missing:
        fail("E_DIRECTOR_FIELDS", "director", f"missing director fields: {missing}", 20)

    for field in ("intent", "player_fantasy", "signature_moment", "negative_space"):
        ok = meaningful_director_text(director.get(field), 10)
        checks[f"{field}_specific"] = ok
        if not ok:
            fail("E_DIRECTOR_GENERIC_TEXT", f"director.{field}", f"{field} must be a specific taste/design sentence", 10)

    arc = director.get("emotional_arc")
    if not isinstance(arc, dict):
        fail("E_DIRECTOR_ARC", "director.emotional_arc", "emotional_arc must be an object", 15)
        arc = {}
    arc_missing = [field for field in DIRECTOR_ARC_FIELDS if not meaningful_director_text(arc.get(field), 6)]
    checks["emotional_arc_complete"] = not arc_missing
    if arc_missing:
        fail("E_DIRECTOR_ARC", "director.emotional_arc", f"missing or generic arc beats: {arc_missing}", 15)

    four = director.get("four_in_one")
    if not isinstance(four, dict):
        fail("E_DIRECTOR_FOUR_IN_ONE", "director.four_in_one", "four_in_one must be an object", 15)
        four = {}
    four_missing = [field for field in DIRECTOR_FOUR_IN_ONE_FIELDS if not meaningful_director_text(four.get(field), 6)]
    checks["four_in_one_complete"] = not four_missing
    if four_missing:
        fail("E_DIRECTOR_FOUR_IN_ONE", "director.four_in_one", f"missing or generic four-in-one dimensions: {four_missing}", 15)

    protagonist = director.get("protagonist")
    active = active_layer_set(lvl)
    objective_layers = objective_layer_set(lvl)
    budget_layers = active - {"drop_exit"}
    declared = {str(protagonist)} if isinstance(protagonist, str) and protagonist else set()
    supporting = director.get("supporting_roles", [])
    if isinstance(supporting, list):
        declared.update(str(x) for x in supporting if isinstance(x, str))
    else:
        fail("E_DIRECTOR_SUPPORTING_ROLES", "director.supporting_roles", "supporting_roles must be a list", 10)
        supporting = []

    protagonist_ok = isinstance(protagonist, str) and protagonist in (active | objective_layers)
    checks["protagonist_present_on_board_or_objective"] = protagonist_ok
    if not protagonist_ok:
        fail("E_DIRECTOR_PROTAGONIST", "director.protagonist", f"protagonist {protagonist!r} is not present in overlays/objectives", 20)

    objective_covered = not objective_layers or bool(objective_layers & declared)
    checks["objective_covered_by_director_roles"] = objective_covered
    if not objective_covered:
        fail("E_DIRECTOR_OBJECTIVE_UNCOVERED", "director.supporting_roles", f"objective layer(s) {sorted(objective_layers)} must be protagonist or supporting_roles", 15)

    undeclared = sorted(budget_layers - declared)
    checks["active_layers_declared"] = not undeclared
    if undeclared:
        fail("E_DIRECTOR_UNDECLARED_LAYER", "director.supporting_roles", f"active layer(s) not accounted for by director: {undeclared}", 10)

    anti_slop = director.get("anti_slop") if isinstance(director.get("anti_slop"), dict) else {}
    max_primary = int(anti_slop.get("max_primary_mechanisms", 2) or 2)
    within_budget = len(budget_layers) <= max_primary
    checks["mechanism_budget_ok"] = {"valid": within_budget, "active": sorted(budget_layers), "max": max_primary}
    if not within_budget:
        fail("E_DIRECTOR_MECHANISM_PILEUP", "director.anti_slop.max_primary_mechanisms", f"{len(budget_layers)} active mechanisms exceed max {max_primary}", 20)

    forbidden = set(str(x) for x in anti_slop.get("forbidden", []) if isinstance(x, str))
    objective_types = set(str(obj.get("type")) for obj in normalize_objectives(lvl))
    forbidden_hits = sorted((budget_layers | active | objective_types) & forbidden)
    checks["forbidden_atoms_absent"] = not forbidden_hits
    if forbidden_hits:
        fail("E_DIRECTOR_FORBIDDEN_ATOM", "director.anti_slop.forbidden", f"forbidden atom(s) present: {forbidden_hits}", 20)

    color_goal = bool(objective_types & FORBIDDEN_GENERATED_OBJECTIVES)
    checks["no_color_order_goal"] = not color_goal
    if color_goal:
        fail("E_DIRECTOR_COLOR_GOAL", "objective", "generated levels may not use color collection/order as the primary goal", 25)

    blob = director_text_blob(lvl)
    keywords = DIRECTOR_LAYER_KEYWORDS.get(str(protagonist), ()) if isinstance(protagonist, str) else ()
    aligned = not keywords or any(keyword in blob for keyword in keywords)
    checks["protagonist_language_aligned"] = aligned
    if not aligned:
        warn("W_DIRECTOR_LANGUAGE_ALIGNMENT", "director", f"director text does not mention protagonist keywords for {protagonist}", 5)

    if compiled is not None:
        move_limit = int(compiled.get("move_limit", 0) or 0)
        target_count = sum(int(o.get("target", 0) or 0) for o in compiled.get("objectives", []))
        checks["pacing_context"] = {"move_limit": move_limit, "objective_target_total": target_count}
        if target_count > 0 and move_limit > 0 and target_count / max(1, move_limit) > 1.0:
            warn("W_DIRECTOR_TAIL_GRIND_RISK", "rules.moves", "target density may create cleanup grind; verify with simulator", 5)

    valid = not errors and score >= 80
    return {"valid": valid, "score": score, "checks": checks, "errors": errors, "warnings": warnings}


def progression_validate_lvl(lvl: dict[str, Any], compiled: dict[str, Any] | None = None) -> dict[str, Any]:
    """Validate long-run progression grammar separately from single-level taste."""
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    checks: dict[str, Any] = {}
    score = 100

    def fail(code: str, path: str, message: str, penalty: int = 15) -> None:
        nonlocal score
        errors.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    def warn(code: str, path: str, message: str, penalty: int = 5) -> None:
        nonlocal score
        warnings.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    progression = lvl.get("progression")
    if not isinstance(progression, dict):
        fail("E_PROGRESSION_MISSING", "progression", "progression grammar is required", 40)
        return {"valid": False, "score": score, "checks": checks, "errors": errors, "warnings": warnings}

    required = ["episode", "mechanic_lifecycle", "reward_budget", "annoyance_budget", "difficulty_rhythm"]
    missing = [key for key in required if key not in progression]
    checks["required_fields_present"] = not missing
    if missing:
        fail("E_PROGRESSION_FIELDS", "progression", f"missing progression fields: {missing}", 25)

    episode = progression.get("episode") if isinstance(progression.get("episode"), dict) else {}
    episode_ok = isinstance(episode.get("slot"), int) and meaningful_semantic_text(episode.get("arc_role"), 3)
    checks["episode_slot_and_role_present"] = episode_ok
    if not episode_ok:
        fail("E_PROGRESSION_EPISODE", "progression.episode", "episode must declare numeric slot and arc_role", 15)

    design = lvl.get("level_design") if isinstance(lvl.get("level_design"), dict) else {}
    roles = design.get("roles") if isinstance(design.get("roles"), dict) else {}
    protagonist = roles.get("protagonist") if isinstance(roles.get("protagonist"), dict) else {}
    protagonist_mechanism = protagonist.get("mechanism")
    support = roles.get("support", []) if isinstance(roles.get("support"), list) else []
    declared_design_mechanics = ({str(protagonist_mechanism)} if isinstance(protagonist_mechanism, str) else set()) | {
        str(item.get("mechanism")) for item in support if isinstance(item, dict) and item.get("mechanism")
    }

    lifecycle = progression.get("mechanic_lifecycle")
    if not isinstance(lifecycle, list):
        fail("E_PROGRESSION_LIFECYCLE_TYPE", "progression.mechanic_lifecycle", "mechanic_lifecycle must be a list", 20)
        lifecycle = []
    lifecycle_mechanics = {str(item.get("mechanic")) for item in lifecycle if isinstance(item, dict) and item.get("mechanic")}
    primary_entries = [
        item for item in lifecycle
        if isinstance(item, dict) and item.get("role") == "primary" and item.get("mechanic") == protagonist_mechanism
    ]
    checks["primary_lifecycle_matches_protagonist"] = bool(primary_entries)
    if not primary_entries:
        fail("E_PROGRESSION_PRIMARY_MISSING", "progression.mechanic_lifecycle", f"primary lifecycle entry must match protagonist {protagonist_mechanism!r}", 25)
    missing_mechanics = sorted(declared_design_mechanics - lifecycle_mechanics)
    checks["design_mechanics_in_lifecycle"] = not missing_mechanics
    if missing_mechanics:
        fail("E_PROGRESSION_LIFECYCLE_GAP", "progression.mechanic_lifecycle", f"design mechanic(s) missing lifecycle entries: {missing_mechanics}", 20)
    generic_phase = [item for item in lifecycle if isinstance(item, dict) and not meaningful_semantic_text(item.get("phase"), 4)]
    checks["lifecycle_phases_specific"] = not generic_phase
    if generic_phase:
        fail("E_PROGRESSION_PHASE_GENERIC", "progression.mechanic_lifecycle", "each lifecycle entry needs a specific phase", 10)

    reward_budget = progression.get("reward_budget") if isinstance(progression.get("reward_budget"), dict) else {}
    primitives = [str(x) for x in reward_budget.get("primitives", []) if isinstance(x, str)]
    unknown_primitives = sorted(set(primitives) - set(REWARD_LAYER_TO_FX))
    checks["reward_primitives_known"] = not unknown_primitives
    if unknown_primitives:
        fail("E_REWARD_UNKNOWN", "progression.reward_budget.primitives", f"unknown reward primitives: {unknown_primitives}", 15)
    reward_layers = reward_layer_set(lvl)
    missing_reward_layers = sorted(set(primitives) - reward_layers)
    checks["reward_primitives_present_on_board"] = not missing_reward_layers
    if missing_reward_layers:
        fail("E_REWARD_NOT_PLACED", "overlays", f"reward primitive(s) missing from overlays: {missing_reward_layers}", 20)
    if bool(reward_budget.get("required")) and not primitives:
        fail("E_REWARD_REQUIRED_EMPTY", "progression.reward_budget", "required reward budget needs at least one primitive", 15)
    if compiled is not None and primitives:
        fx_cells = sum(1 for row in compiled.get("fx", []) for value in row if int(value) > 0)
        checks["reward_primitives_compile_to_fx"] = fx_cells > 0
        if fx_cells <= 0:
            fail("E_REWARD_NO_FX", "compile.fx", "reward primitives must compile into non-zero fx cells", 25)

    annoyance = progression.get("annoyance_budget") if isinstance(progression.get("annoyance_budget"), dict) else {}
    for key in ("max_reshuffle_rate", "max_dead_board_rate", "max_no_progress_turn_rate", "max_luck_dependency_proxy"):
        value = annoyance.get(key)
        ok = isinstance(value, (int, float)) and 0.0 <= float(value) <= 1.0
        checks[f"{key}_valid"] = ok
        if not ok:
            fail("E_ANNOYANCE_BUDGET", f"progression.annoyance_budget.{key}", f"{key} must be a 0..1 number", 10)

    rhythm = progression.get("difficulty_rhythm") if isinstance(progression.get("difficulty_rhythm"), dict) else {}
    band = rhythm.get("target_pass_band")
    band_ok = isinstance(band, list) and len(band) == 2 and all(isinstance(x, (int, float)) for x in band)
    rhythm_ok = band_ok and meaningful_semantic_text(rhythm.get("shape"), 3)
    checks["difficulty_rhythm_has_pass_band"] = rhythm_ok
    if not rhythm_ok:
        fail("E_DIFFICULTY_RHYTHM", "progression.difficulty_rhythm", "difficulty_rhythm must declare shape and target_pass_band", 15)
    meta_band = lvl.get("meta", {}).get("target_pass_band")
    if band_ok and isinstance(meta_band, list) and [float(x) for x in band] != [float(x) for x in meta_band]:
        warn("W_DIFFICULTY_BAND_MISMATCH", "progression.difficulty_rhythm.target_pass_band", "progression band differs from meta target_pass_band", 5)

    return {"valid": not errors and score >= 80, "score": score, "checks": checks, "errors": errors, "warnings": warnings}


def level_intent_validate_lvl(lvl: dict[str, Any], compiled: dict[str, Any] | None = None) -> dict[str, Any]:
    """Validate benchmark-derived objective verb, skill lesson, and board scale laws."""
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    checks: dict[str, Any] = {}
    score = 100

    def fail(code: str, path: str, message: str, penalty: int = 15) -> None:
        nonlocal score
        errors.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    def warn(code: str, path: str, message: str, penalty: int = 5) -> None:
        nonlocal score
        warnings.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    intent = lvl.get("level_intent")
    if not isinstance(intent, dict):
        fail("E_LEVEL_INTENT_MISSING", "level_intent", "level_intent contract is required", 40)
        return {"valid": False, "score": score, "checks": checks, "errors": errors, "warnings": warnings}

    required = {"objective_verb", "skill_lesson", "board_scale"}
    missing = sorted(required - set(intent))
    checks["required_fields_present"] = not missing
    if missing:
        fail("E_LEVEL_INTENT_FIELDS", "level_intent", f"missing level intent fields: {missing}", 25)

    objective_verb = str(intent.get("objective_verb", ""))
    objective_type = str(first_objective(lvl).get("type", ""))
    objective_to_verb = {
        "cleanse_marks": "cleanse",
        "clear_shells": "cleanse",
        "clear_creep": "cleanse",
        "defuse_cores": "cleanse",
        "drop_relic": "transport",
        "collect": "craft",
        "order_color": "craft",
    }
    expected_verb = objective_to_verb.get(objective_type)
    verb_ok = objective_verb in {"cleanse", "transport", "craft", "connect", "rescue", "mixed"}
    checks["objective_verb_known"] = verb_ok
    if not verb_ok:
        fail("E_OBJECTIVE_VERB_UNKNOWN", "level_intent.objective_verb", f"unknown objective verb {objective_verb!r}", 15)
    checks["objective_verb_matches_objective"] = expected_verb is None or objective_verb == expected_verb
    if expected_verb is not None and objective_verb != expected_verb:
        fail("E_OBJECTIVE_VERB_MISMATCH", "level_intent.objective_verb", f"{objective_type} should use objective verb {expected_verb}", 20)

    skill = intent.get("skill_lesson") if isinstance(intent.get("skill_lesson"), dict) else {}
    skill_ok = meaningful_semantic_text(skill.get("skill"), 4) and meaningful_semantic_text(skill.get("proof_signal"), 6)
    checks["skill_lesson_has_proof_signal"] = skill_ok
    if not skill_ok:
        fail("E_SKILL_LESSON_INCOMPLETE", "level_intent.skill_lesson", "skill_lesson must declare skill and proof_signal", 15)

    board_scale = intent.get("board_scale") if isinstance(intent.get("board_scale"), dict) else {}
    scale_size = str(board_scale.get("size", ""))
    problem_space = str(board_scale.get("effective_problem_space", ""))
    reason_ok = meaningful_semantic_text(board_scale.get("reason"), 6)
    checks["board_scale_declared"] = scale_size in {"7x7", "7x9", "9x9"} and problem_space in {"small", "medium", "large"} and reason_ok
    if not checks["board_scale_declared"]:
        fail("E_BOARD_SCALE_INCOMPLETE", "level_intent.board_scale", "board_scale must declare size, effective_problem_space, and reason", 15)

    width = int(lvl.get("map", {}).get("width", 0) or 0)
    height = int(lvl.get("map", {}).get("height", 0) or 0)
    actual_size = f"{width}x{height}" if width and height else ""
    checks["board_scale_matches_map"] = not scale_size or scale_size == actual_size
    if scale_size and scale_size != actual_size:
        fail("E_BOARD_SCALE_SIZE_MISMATCH", "level_intent.board_scale.size", f"declared board scale {scale_size} != map size {actual_size}", 15)

    progression = lvl.get("progression") if isinstance(lvl.get("progression"), dict) else {}
    lifecycle = progression.get("mechanic_lifecycle") if isinstance(progression.get("mechanic_lifecycle"), list) else []
    new_reveal = any(
        isinstance(item, dict) and bool(item.get("is_new")) and item.get("phase") == "reveal_safe"
        for item in lifecycle
    )
    checks["new_mechanic_reveal"] = new_reveal
    if new_reveal:
        area = width * height
        colors = int(lvl.get("rules", {}).get("colors", 0) or 0)
        band = lvl.get("meta", {}).get("target_pass_band", [])
        band_low = float(band[0]) if isinstance(band, list) and band else 0.0
        objective_count = len(normalize_objectives(lvl))
        checks["new_reveal_small_problem_space"] = problem_space == "small"
        checks["new_reveal_board_cells"] = area
        checks["new_reveal_colors"] = colors
        checks["new_reveal_target_band_low"] = band_low
        if problem_space != "small":
            fail("E_BOARD_SCALE_NEW_REVEAL_NOT_SMALL", "level_intent.board_scale.effective_problem_space", "new mechanism reveal must use small problem space", 20)
        if area > 49:
            fail("E_BOARD_SCALE_NEW_REVEAL_TOO_LARGE", "map", f"new mechanism reveal board has {area} cells; expected <= 49", 25)
        if colors > 4:
            fail("E_BOARD_SCALE_NEW_REVEAL_TOO_MANY_COLORS", "rules.colors", "new mechanism reveal should use at most 4 colors", 20)
        if band_low < 0.90:
            fail("E_BOARD_SCALE_NEW_REVEAL_TOO_HARD", "meta.target_pass_band", "new mechanism reveal target pass band should start at >= 0.90", 20)
        if objective_count > 1:
            fail("E_LEVEL_INTENT_NEW_REVEAL_MIXED_OBJECTIVE", "objectives", "new mechanism reveal should not mix objectives", 20)

    composition = lvl.get("obstacle_composition") if isinstance(lvl.get("obstacle_composition"), dict) else {}
    archetype = str(composition.get("archetype", ""))
    compatible_archetypes = {
        "cleanse": {"no_blocker_focus", "gate", "ring", "key_path", "cage", "funnel", "split_lock"},
        "transport": {"lane", "gate", "funnel"},
        "craft": {"no_blocker_focus", "gate", "ring", "key_path"},
        "connect": {"bridge", "key_path"},
        "rescue": {"cage", "ring"},
        "mixed": {"gate", "lane", "ring", "split_lock", "bridge"},
    }
    archetype_ok = not archetype or archetype in compatible_archetypes.get(objective_verb, set())
    checks["objective_verb_matches_archetype"] = archetype_ok
    if not archetype_ok:
        warn("W_OBJECTIVE_VERB_ARCHETYPE_MISMATCH", "obstacle_composition.archetype", f"{objective_verb} rarely pairs with archetype {archetype}", 5)

    return {"valid": not errors and score >= 80, "score": score, "checks": checks, "errors": errors, "warnings": warnings}


def mechanism_spec_validate_lvl(lvl: dict[str, Any], compiled: dict[str, Any] | None = None) -> dict[str, Any]:
    """Validate the per-level mechanism library contract."""
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    checks: dict[str, Any] = {}
    score = 100

    def fail(code: str, path: str, message: str, penalty: int = 15) -> None:
        nonlocal score
        errors.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    def warn(code: str, path: str, message: str, penalty: int = 5) -> None:
        nonlocal score
        warnings.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    specs = lvl.get("mechanism_specs")
    if not isinstance(specs, dict):
        fail("E_MECHANISM_SPECS_MISSING", "mechanism_specs", "mechanism_specs contract is required", 40)
        return {"valid": False, "score": score, "checks": checks, "errors": errors, "warnings": warnings}

    active_atoms = mechanism_atoms_for_lvl(lvl)
    checks["active_atoms"] = sorted(active_atoms)
    missing_active = sorted(active_atoms - set(specs))
    checks["active_atoms_have_specs"] = not missing_active
    if missing_active:
        fail("E_MECHANISM_SPEC_MISSING_ACTIVE", "mechanism_specs", f"active atom(s) missing specs: {missing_active}", 35)

    unused_specs = sorted(set(specs) - active_atoms)
    checks["unused_specs"] = unused_specs
    if unused_specs:
        warn("W_MECHANISM_SPEC_UNUSED", "mechanism_specs", f"unused mechanism spec(s): {unused_specs}", 5)

    intent = lvl.get("level_intent") if isinstance(lvl.get("level_intent"), dict) else {}
    objective_verb = str(intent.get("objective_verb", ""))
    terrain = str(lvl.get("map", {}).get("terrain", {}).get("sample", ""))
    compile_mode = str(lvl.get("compile_mode", "playable"))
    slot = int(lvl.get("meta", {}).get("level_coordinate", 0) or 0)
    progression = lvl.get("progression") if isinstance(lvl.get("progression"), dict) else {}
    lifecycle = progression.get("mechanic_lifecycle") if isinstance(progression.get("mechanic_lifecycle"), list) else []
    new_reveals = {
        str(item.get("mechanic"))
        for item in lifecycle
        if isinstance(item, dict) and bool(item.get("is_new")) and item.get("phase") == "reveal_safe"
    }

    for key, raw_spec in specs.items():
        if not isinstance(raw_spec, dict):
            fail("E_MECHANISM_SPEC_TYPE", f"mechanism_specs.{key}", "mechanism spec must be an object", 20)
            continue
        missing_fields = sorted(MECHANISM_SPEC_REQUIRED_FIELDS - set(raw_spec))
        if missing_fields:
            fail("E_MECHANISM_SPEC_FIELDS", f"mechanism_specs.{key}", f"missing mechanism spec fields: {missing_fields}", 25)
            continue

        mechanic_id = str(raw_spec.get("mechanic_id", ""))
        id_ok = mechanic_id == str(key)
        checks[f"{key}.id_matches_key"] = id_ok
        if not id_ok:
            fail("E_MECHANISM_SPEC_ID_MISMATCH", f"mechanism_specs.{key}.mechanic_id", f"mechanic_id {mechanic_id!r} must match key {key!r}", 15)

        category = str(raw_spec.get("category", ""))
        category_ok = category in MECHANISM_CATEGORIES
        checks[f"{key}.category_known"] = category_ok
        if not category_ok:
            fail("E_MECHANISM_SPEC_CATEGORY", f"mechanism_specs.{key}.category", f"unknown mechanism category {category!r}", 15)

        dynamics = str(raw_spec.get("state_dynamics", ""))
        dynamics_ok = dynamics in MECHANISM_STATE_DYNAMICS
        checks[f"{key}.state_dynamics_known"] = dynamics_ok
        if not dynamics_ok:
            fail("E_MECHANISM_SPEC_STATE_DYNAMICS", f"mechanism_specs.{key}.state_dynamics", f"unknown state_dynamics {dynamics!r}", 15)

        text_fields_ok = all(isinstance(raw_spec.get(field), str) and bool(str(raw_spec.get(field))) for field in ("player_action", "board_effect", "reward_effect"))
        checks[f"{key}.effect_text_present"] = text_fields_ok
        if not text_fields_ok:
            fail("E_MECHANISM_SPEC_EFFECT_TEXT", f"mechanism_specs.{key}", "player_action, board_effect, and reward_effect must be concrete strings", 15)

        compat_verbs = [str(x) for x in raw_spec.get("compatible_objective_verbs", []) if isinstance(x, str)]
        compat_ok = bool(compat_verbs)
        checks[f"{key}.compatible_objective_verbs_declared"] = compat_ok
        if not compat_ok:
            fail("E_MECHANISM_SPEC_OBJECTIVE_COMPAT", f"mechanism_specs.{key}.compatible_objective_verbs", "compatible_objective_verbs must be a non-empty list", 15)
        elif key in active_atoms and objective_verb and objective_verb not in compat_verbs:
            fail(
                "E_MECHANISM_SPEC_OBJECTIVE_INCOMPATIBLE",
                f"mechanism_specs.{key}.compatible_objective_verbs",
                f"active mechanism {key!r} is not compatible with objective verb {objective_verb!r}",
                25,
            )

        compat_terrain = [str(x) for x in raw_spec.get("compatible_terrain", []) if isinstance(x, str)]
        terrain_ok = bool(compat_terrain)
        checks[f"{key}.compatible_terrain_declared"] = terrain_ok
        if not terrain_ok:
            fail("E_MECHANISM_SPEC_TERRAIN_COMPAT", f"mechanism_specs.{key}.compatible_terrain", "compatible_terrain must be a non-empty list", 15)
        elif key in active_atoms and terrain and terrain not in compat_terrain:
            fail("E_MECHANISM_SPEC_TERRAIN_INCOMPATIBLE", f"mechanism_specs.{key}.compatible_terrain", f"active mechanism {key!r} is not compatible with terrain {terrain!r}", 20)

        intro = raw_spec.get("intro_rule") if isinstance(raw_spec.get("intro_rule"), dict) else {}
        intro_ok = bool(intro) and "first_reveal_phase" in intro and "new_reveal_problem_space" in intro
        checks[f"{key}.intro_rule_declared"] = intro_ok
        if not intro_ok:
            fail("E_MECHANISM_SPEC_INTRO_RULE", f"mechanism_specs.{key}.intro_rule", "intro_rule must declare first_reveal_phase and new_reveal_problem_space", 15)
        if key in new_reveals:
            first_level = intro.get("first_reveal_level")
            first_level_ok = isinstance(first_level, int) and first_level == slot
            checks[f"{key}.new_reveal_matches_intro_level"] = first_level_ok
            if not first_level_ok:
                fail("E_MECHANISM_SPEC_INTRO_LEVEL", f"mechanism_specs.{key}.intro_rule.first_reveal_level", f"new reveal at level {slot} must match intro first_reveal_level", 20)

        mixing = raw_spec.get("mixing_rule") if isinstance(raw_spec.get("mixing_rule"), dict) else {}
        can_pair = [str(x) for x in mixing.get("can_pair_with", []) if isinstance(x, str)]
        forbidden = {str(x) for x in mixing.get("forbidden_with", []) if isinstance(x, str)}
        mixing_ok = isinstance(mixing, dict) and "can_pair_with" in mixing and "forbidden_with" in mixing
        checks[f"{key}.mixing_rule_declared"] = mixing_ok
        if not mixing_ok:
            fail("E_MECHANISM_SPEC_MIXING_RULE", f"mechanism_specs.{key}.mixing_rule", "mixing_rule must declare can_pair_with and forbidden_with", 15)
        if key in active_atoms:
            forbidden_hits = sorted((active_atoms - {key}) & forbidden)
            if forbidden_hits:
                fail("E_MECHANISM_SPEC_FORBIDDEN_MIX", f"mechanism_specs.{key}.mixing_rule.forbidden_with", f"active forbidden pairing(s): {forbidden_hits}", 25)
            soft_unlisted = sorted((active_atoms - {key}) - set(can_pair))
            if soft_unlisted and category not in {"reward", "routing"}:
                warn("W_MECHANISM_SPEC_UNLISTED_PAIRING", f"mechanism_specs.{key}.mixing_rule.can_pair_with", f"active pairing(s) not explicitly listed: {soft_unlisted}", 5)

        simulator = raw_spec.get("simulator_hook") if isinstance(raw_spec.get("simulator_hook"), dict) else {}
        sim_ok = bool(simulator) and isinstance(simulator.get("kind"), str)
        checks[f"{key}.simulator_hook_declared"] = sim_ok
        if not sim_ok:
            fail("E_MECHANISM_SPEC_SIM_HOOK", f"mechanism_specs.{key}.simulator_hook", "simulator_hook must declare kind", 15)
        elif key in active_atoms and not bool(simulator.get("supported")):
            fail("E_MECHANISM_SPEC_SIM_UNSUPPORTED", f"mechanism_specs.{key}.simulator_hook.supported", f"active mechanism {key!r} is not supported by the player simulator", 25)

        godot = raw_spec.get("godot_support") if isinstance(raw_spec.get("godot_support"), dict) else {}
        godot_ok = bool(godot) and isinstance(godot.get("compile_layer"), str)
        checks[f"{key}.godot_support_declared"] = godot_ok
        if not godot_ok:
            fail("E_MECHANISM_SPEC_GODOT_HOOK", f"mechanism_specs.{key}.godot_support", "godot_support must declare compile_layer", 15)
        elif compile_mode == "playable" and key in active_atoms and not bool(godot.get("playable_v0")):
            fail("E_MECHANISM_SPEC_GODOT_UNSUPPORTED", f"mechanism_specs.{key}.godot_support.playable_v0", f"active mechanism {key!r} is not playable in Godot v0", 25)

    return {"valid": not errors and score >= 80, "score": score, "checks": checks, "errors": errors, "warnings": warnings}


def obstacle_composition_validate_lvl(lvl: dict[str, Any], compiled: dict[str, Any] | None = None) -> dict[str, Any]:
    """Validate whether blocker geometry serves the declared design purpose."""
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    checks: dict[str, Any] = {}
    score = 100

    def fail(code: str, path: str, message: str, penalty: int = 15) -> None:
        nonlocal score
        errors.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    def warn(code: str, path: str, message: str, penalty: int = 5) -> None:
        nonlocal score
        warnings.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    composition = lvl.get("obstacle_composition")
    if not isinstance(composition, dict):
        fail("E_OBSTACLE_COMPOSITION_MISSING", "obstacle_composition", "obstacle composition contract is required", 40)
        return {"valid": False, "score": score, "checks": checks, "errors": errors, "warnings": warnings}

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
    missing = sorted(required - set(composition))
    checks["required_fields_present"] = not missing
    if missing:
        fail("E_OBSTACLE_FIELDS", "obstacle_composition", f"missing obstacle composition fields: {missing}", 25)

    purpose = str(composition.get("purpose", ""))
    archetype = str(composition.get("archetype", ""))
    primary = str(composition.get("primary_blocker", "none"))
    action = str(composition.get("action_vector", ""))
    read_order = composition.get("read_order", [])
    beauty_rules = composition.get("beauty_rules", [])
    negative_space = composition.get("negative_space", {}) if isinstance(composition.get("negative_space"), dict) else {}

    known_archetypes = {
        "no_blocker_focus",
        "gate",
        "ring",
        "lane",
        "key_path",
        "cage",
        "funnel",
        "split_lock",
        "bridge",
    }
    archetype_ok = archetype in known_archetypes
    checks["archetype_known"] = archetype_ok
    if not archetype_ok:
        fail("E_OBSTACLE_ARCHETYPE", "obstacle_composition.archetype", f"unknown obstacle archetype {archetype!r}", 15)

    allowed_actions = {
        "no_blocker_focus": {"local_match", "horizontal", "path"},
        "gate": {"vertical", "horizontal"},
        "ring": {"burst"},
        "lane": {"transport_down", "vertical"},
        "key_path": {"path", "connect"},
        "cage": {"adjacent_clear", "burst"},
        "funnel": {"vertical", "transport_down"},
        "split_lock": {"dual_area"},
        "bridge": {"connect"},
    }
    alignment_ok = action in allowed_actions.get(archetype, set())
    checks["archetype_matches_purpose"] = bool(purpose) and alignment_ok
    if not purpose:
        fail("E_OBSTACLE_PURPOSE", "obstacle_composition.purpose", "purpose must be a concrete design intent", 10)
    if not alignment_ok:
        fail("E_OBSTACLE_ACTION_ALIGNMENT", "obstacle_composition.action_vector", f"action {action!r} does not match archetype {archetype!r}", 15)

    primary_cells = set() if primary == "none" else cells_for_layer(lvl, primary)
    primary_needed = archetype in {"gate", "ring", "cage", "bridge"} or (archetype == "lane" and primary != "none")
    primary_ok = bool(primary_cells) if primary_needed else True
    checks["primary_blocker_present"] = primary_ok
    if primary_needed and not primary_ok:
        fail("E_OBSTACLE_PRIMARY_ABSENT", "obstacle_composition.primary_blocker", f"primary blocker {primary!r} is not present on the board", 25)

    rows = board_rows(lvl, Diagnostics())
    playable = playable_cell_set(rows)
    min_ratio = negative_space.get("min_ratio")
    ratio_ok = isinstance(min_ratio, (int, float)) and 0.0 <= float(min_ratio) <= 1.0
    checks["negative_space_declared"] = ratio_ok
    if not ratio_ok:
        fail("E_OBSTACLE_NEGATIVE_SPACE", "obstacle_composition.negative_space.min_ratio", "negative-space min_ratio must be a 0..1 number", 10)
    else:
        open_ratio = 1.0
        if playable:
            open_ratio = (len(playable - primary_cells) / len(playable))
        checks["negative_space_ratio"] = round(open_ratio, 3)
        checks["negative_space_ok"] = open_ratio >= float(min_ratio)
        if open_ratio < float(min_ratio):
            fail("E_OBSTACLE_NEGATIVE_SPACE_LOW", "overlays", f"negative space ratio {open_ratio:.2f} below required {float(min_ratio):.2f}", 20)

    no_uniform_wall = True
    if primary_cells and rows:
        row_counts: dict[int, int] = {}
        col_counts: dict[int, int] = {}
        for r, c in primary_cells:
            row_counts[r] = row_counts.get(r, 0) + 1
            col_counts[c] = col_counts.get(c, 0) + 1
        for r, count in row_counts.items():
            playable_in_row = sum(1 for c, ch in enumerate(rows[r]) if ch != ".")
            if playable_in_row and count >= playable_in_row:
                no_uniform_wall = False
        for c, count in col_counts.items():
            playable_in_col = sum(1 for row in rows if c < len(row) and row[c] != ".")
            if playable_in_col and count >= playable_in_col:
                no_uniform_wall = False
        if archetype == "gate" and max(row_counts.values() or [0]) > 4:
            no_uniform_wall = False
        if archetype == "ring" and (max(row_counts.values() or [0]) > 5 or max(col_counts.values() or [0]) > 5):
            no_uniform_wall = False
    checks["no_uniform_wall"] = no_uniform_wall
    if not no_uniform_wall:
        fail("E_OBSTACLE_UNIFORM_WALL", "overlays", "primary blocker forms an over-wide or fully sealing wall", 25)

    read_order_ok = isinstance(read_order, list) and len(read_order) >= 2 and all(isinstance(x, str) and x for x in read_order)
    checks["read_order_declared"] = read_order_ok
    if not read_order_ok:
        fail("E_OBSTACLE_READ_ORDER", "obstacle_composition.read_order", "read_order must contain at least two readable stages", 10)

    objective = objective_cells(lvl)
    exit_cells = cells_for_layer(lvl, "drop_exit")
    read_spatial_ok = read_order_ok
    if primary != "none" and "blocker" in read_order:
        read_spatial_ok = read_spatial_ok and bool(primary_cells)
    if any(token in read_order for token in ("goal", "center_goal", "edge_goal", "actor")):
        read_spatial_ok = read_spatial_ok and bool(objective)
    if "exit" in read_order:
        read_spatial_ok = read_spatial_ok and bool(exit_cells)

    primary_center = centroid(primary_cells)
    objective_center = centroid(objective)
    exit_center = centroid(exit_cells)
    if archetype == "gate" and action == "vertical" and primary_center and objective_center and "goal" in read_order:
        read_spatial_ok = read_spatial_ok and objective_center[0] > primary_center[0]
    if archetype == "lane" and action == "transport_down" and objective_center and exit_center:
        read_spatial_ok = read_spatial_ok and objective_center[0] < exit_center[0]
        if primary_center:
            read_spatial_ok = read_spatial_ok and objective_center[0] < primary_center[0] < exit_center[0]

    checks["read_order_spatially_plausible"] = bool(read_spatial_ok)
    if not read_spatial_ok:
        fail("E_OBSTACLE_READ_ORDER_SPATIAL", "obstacle_composition.read_order", "goal/blocker/solution read order is not spatially plausible", 20)

    rules_ok = isinstance(beauty_rules, list) and bool(beauty_rules) and all(isinstance(x, str) and x for x in beauty_rules)
    checks["beauty_rules_declared"] = rules_ok
    if not rules_ok:
        fail("E_OBSTACLE_BEAUTY_RULES", "obstacle_composition.beauty_rules", "beauty_rules must be a non-empty list", 10)
    if primary != "none" and "no_uniform_wall" not in beauty_rules:
        warn("W_OBSTACLE_NO_UNIFORM_RULE_MISSING", "obstacle_composition.beauty_rules", "blocker compositions should explicitly guard against uniform walls", 5)

    delete_test_ok = meaningful_semantic_text(composition.get("delete_test"), 8)
    checks["delete_test_declared"] = delete_test_ok
    if not delete_test_ok:
        fail("E_OBSTACLE_DELETE_TEST", "obstacle_composition.delete_test", "delete_test must explain why removing the obstacle destroys the thesis", 10)

    return {"valid": not errors and score >= 80, "score": score, "checks": checks, "errors": errors, "warnings": warnings}


def visual_grammar_validate_lvl(lvl: dict[str, Any], compiled: dict[str, Any] | None = None) -> dict[str, Any]:
    """Validate measurable composition grammar: focus, symmetry, and density."""
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    checks: dict[str, Any] = {}
    score = 100

    def fail(code: str, path: str, message: str, penalty: int = 15) -> None:
        nonlocal score
        errors.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    def warn(code: str, path: str, message: str, penalty: int = 5) -> None:
        nonlocal score
        warnings.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    composition = lvl.get("obstacle_composition") if isinstance(lvl.get("obstacle_composition"), dict) else {}
    visual = composition.get("visual_grammar") if isinstance(composition.get("visual_grammar"), dict) else None
    if not isinstance(visual, dict):
        fail("E_VISUAL_GRAMMAR_MISSING", "obstacle_composition.visual_grammar", "visual_grammar contract is required", 40)
        return {"valid": False, "score": score, "checks": checks, "errors": errors, "warnings": warnings}

    required = {"focal_alignment", "symmetry", "density_band", "silhouette", "anchor_layers"}
    missing = sorted(required - set(visual))
    checks["required_fields_present"] = not missing
    if missing:
        fail("E_VISUAL_GRAMMAR_FIELDS", "obstacle_composition.visual_grammar", f"missing visual grammar fields: {missing}", 25)

    rows = board_rows(lvl, Diagnostics())
    playable = playable_cell_set(rows)
    height = len(rows)
    width = len(rows[0]) if rows else 0
    mid_r = (height - 1) / 2.0 if height else 0.0
    mid_c = (width - 1) / 2.0 if width else 0.0

    anchor_layers = [str(x) for x in visual.get("anchor_layers", []) if isinstance(x, str)]
    anchor_cells: set[tuple[int, int]] = set()
    for layer in anchor_layers:
        anchor_cells.update(cells_for_layer(lvl, layer))
    checks["anchor_layers_present"] = bool(anchor_layers) and bool(anchor_cells)
    if not anchor_layers or not anchor_cells:
        fail("E_VISUAL_ANCHOR_ABSENT", "obstacle_composition.visual_grammar.anchor_layers", "visual grammar anchor layers must exist on the board", 25)

    density_band = visual.get("density_band")
    density_ok = (
        isinstance(density_band, list)
        and len(density_band) == 2
        and all(isinstance(x, (int, float)) for x in density_band)
        and 0.0 <= float(density_band[0]) <= float(density_band[1]) <= 1.0
    )
    checks["density_band_declared"] = density_ok
    density = len(anchor_cells) / max(1, len(playable))
    checks["anchor_density"] = round(density, 3)
    if not density_ok:
        fail("E_VISUAL_DENSITY_BAND", "obstacle_composition.visual_grammar.density_band", "density_band must be [min,max] within 0..1", 15)
    else:
        low, high = float(density_band[0]), float(density_band[1])
        checks["anchor_density_in_band"] = low <= density <= high
        if not (low <= density <= high):
            fail("E_VISUAL_DENSITY_OUT_OF_BAND", "overlays", f"anchor density {density:.2f} outside visual band [{low:.2f}, {high:.2f}]", 20)

    center = centroid(anchor_cells)
    row_span = (max((r for r, _ in anchor_cells), default=0) - min((r for r, _ in anchor_cells), default=0)) if anchor_cells else 0
    col_span = (max((c for _, c in anchor_cells), default=0) - min((c for _, c in anchor_cells), default=0)) if anchor_cells else 0
    alignment = str(visual.get("focal_alignment", ""))
    max_offset = float(visual.get("max_centroid_offset", 1.25) or 1.25)
    focus_ok = bool(center)
    if center:
        cr, cc = center
        if alignment == "center_column":
            focus_ok = abs(cc - mid_c) <= max_offset and cr >= mid_r - 1.0
        elif alignment == "center_cluster":
            focus_ok = abs(cc - mid_c) <= max_offset and abs(cr - mid_r) <= max_offset
        elif alignment == "center_ring":
            focus_ok = abs(cc - mid_c) <= max_offset and abs(cr - mid_r) <= max_offset and row_span >= 3 and col_span >= 3
        elif alignment == "vertical_lane":
            exits = cells_for_layer(lvl, "drop_exit")
            exit_cols = {c for _, c in exits}
            focus_ok = abs(cc - mid_c) <= max_offset and (not exit_cols or any(abs(c - cc) <= 0.5 for c in exit_cols))
        elif alignment == "vertical_funnel":
            focus_ok = abs(cc - mid_c) <= max_offset and cr >= mid_r
        elif alignment == "edge_pairs":
            edge_hits = sum(1 for r, c in anchor_cells if r in {0, height - 1} or c in {0, width - 1})
            focus_ok = edge_hits >= max(2, len(anchor_cells) // 2)
        elif alignment == "split_dual":
            focus_ok = any(c < mid_c - 1 for _, c in anchor_cells) and any(c > mid_c + 1 for _, c in anchor_cells)
        elif alignment == "path":
            focus_ok = row_span + col_span >= 3
        else:
            focus_ok = False
    checks["focal_alignment_ok"] = bool(focus_ok)
    if not focus_ok:
        fail("E_VISUAL_FOCAL_ALIGNMENT", "overlays", f"anchor cells do not satisfy focal_alignment {alignment!r}", 25)

    symmetry = str(visual.get("symmetry", ""))
    symmetry_ok = symmetry in {"none", "center_axis", "bilateral", "radial_hint"}
    if symmetry_ok and anchor_cells:
        if symmetry == "center_axis":
            symmetry_ok = bool(center) and abs(center[1] - mid_c) <= max_offset
        elif symmetry == "bilateral":
            left = sum(1 for _, c in anchor_cells if c < mid_c)
            right = sum(1 for _, c in anchor_cells if c > mid_c)
            symmetry_ok = abs(left - right) <= max(1, len(anchor_cells) * 0.25)
        elif symmetry == "radial_hint":
            symmetry_ok = row_span >= 3 and col_span >= 3 and bool(center) and abs(center[0] - mid_r) <= max_offset and abs(center[1] - mid_c) <= max_offset
    checks["symmetry_ok"] = bool(symmetry_ok)
    if not symmetry_ok:
        warn("W_VISUAL_SYMMETRY_WEAK", "obstacle_composition.visual_grammar.symmetry", f"anchor cells weakly satisfy symmetry {symmetry!r}", 5)

    silhouette_ok = meaningful_semantic_text(visual.get("silhouette"), 4)
    checks["silhouette_declared"] = silhouette_ok
    if not silhouette_ok:
        fail("E_VISUAL_SILHOUETTE", "obstacle_composition.visual_grammar.silhouette", "silhouette must name the intended visible shape", 10)

    return {"valid": not errors and score >= 80, "score": score, "checks": checks, "errors": errors, "warnings": warnings}


def personalization_validate_lvl(lvl: dict[str, Any], compiled: dict[str, Any] | None = None) -> dict[str, Any]:
    """Validate cold-start persona priors as explicit generator language."""
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    checks: dict[str, Any] = {}
    score = 100

    def fail(code: str, path: str, message: str, penalty: int = 15) -> None:
        nonlocal score
        errors.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    def warn(code: str, path: str, message: str, penalty: int = 5) -> None:
        nonlocal score
        warnings.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    personalization = lvl.get("personalization")
    if not isinstance(personalization, dict):
        fail("E_PERSONALIZATION_MISSING", "personalization", "personalization contract is required", 35)
        return {"valid": False, "score": score, "checks": checks, "errors": errors, "warnings": warnings}

    prior = str(personalization.get("cold_start_prior", "unknown"))
    checks["prior_known"] = prior in PERSONA_AXES_BY_PRIOR
    if prior not in PERSONA_AXES_BY_PRIOR:
        fail("E_PERSONA_PRIOR_UNKNOWN", "personalization.cold_start_prior", f"unknown cold_start_prior {prior!r}", 15)

    axes = personalization.get("persona_axes") if isinstance(personalization.get("persona_axes"), dict) else {}
    required_axes = set(next(iter(PERSONA_AXES_BY_PRIOR.values())).keys())
    missing = sorted(required_axes - set(axes))
    checks["persona_axes_present"] = not missing
    if missing:
        fail("E_PERSONA_AXES_MISSING", "personalization.persona_axes", f"missing persona axes: {missing}", 25)

    numeric_axes: dict[str, float] = {}
    for key in sorted(required_axes & set(axes)):
        value = axes.get(key)
        ok = isinstance(value, (int, float)) and 0.0 <= float(value) <= 1.0
        checks[f"{key}_valid"] = ok
        if ok:
            numeric_axes[key] = float(value)
        else:
            fail("E_PERSONA_AXIS_RANGE", f"personalization.persona_axes.{key}", f"{key} must be a 0..1 number", 10)

    prior_weight = personalization.get("prior_weight")
    prior_weight_ok = isinstance(prior_weight, (int, float)) and 0.0 <= float(prior_weight) <= 1.0
    checks["prior_weight_valid"] = prior_weight_ok
    if not prior_weight_ok:
        fail("E_PERSONA_PRIOR_WEIGHT", "personalization.prior_weight", "prior_weight must be a 0..1 number", 10)
    elif prior == "unknown" and float(prior_weight) != 0.0:
        warn("W_PERSONA_UNKNOWN_PRIOR_WEIGHT", "personalization.prior_weight", "unknown prior should not bias generation", 5)
    elif prior in {"female", "male"} and float(prior_weight) <= 0.0:
        fail("E_PERSONA_PRIOR_WEIGHT_ZERO", "personalization.prior_weight", "gender prior variants need a positive prior_weight", 10)

    if required_axes.issubset(numeric_axes):
        if prior == "female":
            ok = (
                numeric_axes["novelty_bias"] >= numeric_axes["strategy_bias"]
                and numeric_axes["reward_bias"] >= numeric_axes["challenge_bias"]
                and numeric_axes["cuteness_bias"] >= numeric_axes["strategy_bias"]
                and numeric_axes["annoyance_tolerance"] <= 0.45
            )
            checks["female_prior_shape"] = ok
            if not ok:
                fail("E_PERSONA_FEMALE_PRIOR_MISMATCH", "personalization.persona_axes", "female prior should lean novelty/reward/cuteness and lower annoyance tolerance", 25)
        elif prior == "male":
            ok = (
                numeric_axes["strategy_bias"] >= numeric_axes["novelty_bias"]
                and numeric_axes["challenge_bias"] >= numeric_axes["reward_bias"]
                and numeric_axes["annoyance_tolerance"] <= 0.65
            )
            checks["male_prior_shape"] = ok
            if not ok:
                fail("E_PERSONA_MALE_PRIOR_MISMATCH", "personalization.persona_axes", "male prior should lean strategy/challenge without unlimited annoyance tolerance", 25)
        else:
            spread = max(numeric_axes.values()) - min(numeric_axes.values())
            checks["unknown_prior_balanced"] = spread <= 0.20
            if spread > 0.20:
                warn("W_PERSONA_UNKNOWN_PRIOR_SKEWED", "personalization.persona_axes", "unknown prior axes are unexpectedly skewed", 5)

    return {"valid": not errors and score >= 80, "score": score, "checks": checks, "errors": errors, "warnings": warnings}


def episode_rhythm_validate_levels(levels: list[dict[str, Any]]) -> dict[str, Any]:
    """Validate long-run new-mechanic cadence across an ordered level slice."""
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    checks: dict[str, Any] = {}
    score = 100

    def fail(code: str, path: str, message: str, penalty: int = 15) -> None:
        nonlocal score
        errors.append({"code": code, "path": path, "message": message})
        score = max(0, score - penalty)

    ordered = sorted(levels, key=lambda lvl: int(lvl.get("meta", {}).get("level_coordinate", 0) or 0))
    reveal_slots: list[tuple[int, str, str]] = []
    for lvl in ordered:
        slot = int(lvl.get("meta", {}).get("level_coordinate", 0) or 0)
        lifecycle = lvl.get("progression", {}).get("mechanic_lifecycle", []) if isinstance(lvl.get("progression"), dict) else []
        reveals = [
            str(item.get("mechanic"))
            for item in lifecycle
            if isinstance(item, dict) and bool(item.get("is_new")) and item.get("phase") == "reveal_safe"
        ]
        if len(reveals) > 1:
            fail("E_EPISODE_MULTIPLE_NEW_REVEALS", f"level[{slot}].progression.mechanic_lifecycle", "a level may reveal at most one new mechanic", 20)
        for mechanic in reveals:
            reveal_slots.append((slot, mechanic, str(lvl.get("id", ""))))

    checks["new_reveal_slots"] = [{"slot": slot, "mechanic": mechanic, "level_id": level_id} for slot, mechanic, level_id in reveal_slots]
    min_gap_ok = True
    for prev, curr in zip(reveal_slots, reveal_slots[1:]):
        gap = curr[0] - prev[0]
        if gap < 3:
            min_gap_ok = False
            fail(
                "E_EPISODE_NEW_REVEAL_TOO_CLOSE",
                "progression.mechanic_lifecycle",
                f"new mechanic reveals {prev[1]!r} at level {prev[0]} and {curr[1]!r} at level {curr[0]} are only {gap} level(s) apart",
                25,
            )
    checks["new_reveal_min_gap_at_least_3"] = min_gap_ok

    roles = [str(lvl.get("meta", {}).get("role", "")) for lvl in ordered]
    pressure_count = sum(1 for role in roles if role in {"pressure", "pressure_lite", "peak"})
    checks["pressure_count"] = pressure_count
    if ordered and pressure_count > max(1, math.ceil(len(ordered) * 0.35)):
        warnings.append({"code": "W_EPISODE_TOO_PRESSURE_HEAVY", "path": "meta.role", "message": "early episode may be too pressure-heavy"})
        score = max(0, score - 5)

    return {"valid": not errors and score >= 80, "score": score, "checks": checks, "errors": errors, "warnings": warnings}


def validate_lvl(lvl: dict[str, Any]) -> dict[str, Any]:
    compiled, diag = compile_lvl(lvl)
    out: dict[str, Any] = {
        "level_id": lvl.get("id", "<unknown>"),
        "lint": diag.to_json(),
        "compile": {"valid": compiled is not None, "errors": diag.errors, "warnings": diag.warnings},
        "structural": {},
        "verdict": "reject",
        "recommendations": [],
    }
    if compiled is None:
        return out

    grid = compiled["init_board"]
    playable = sum(1 for row in grid for val in row if val >= 0)
    initial_matches = len(find_matches(grid))
    legal = has_legal_move([row[:] for row in grid])
    objectives = compiled.get("objectives", [])
    objective_ok = all(int(o.get("target", 0)) > 0 for o in objectives)

    drop_path_ok = True
    if any(o.get("type") == "COLLECT_INGREDIENT" for o in objectives):
        exits = set(compiled.get("exits", []))
        if not exits:
            drop_path_ok = False
        else:
            for r, row in enumerate(compiled["ing"]):
                for c, val in enumerate(row):
                    if val > 0 and c not in exits:
                        # v0 route check is intentionally conservative: a direct
                        # vertical path to some exit column is required.
                        drop_path_ok = False

    structural_valid = playable >= 20 and legal and objective_ok and drop_path_ok
    semantic = semantic_validate_level_design(lvl)
    taste = taste_audit_lvl(lvl, compiled)
    level_intent = level_intent_validate_lvl(lvl, compiled)
    mechanism_spec = mechanism_spec_validate_lvl(lvl, compiled)
    personalization = personalization_validate_lvl(lvl, compiled)
    progression = progression_validate_lvl(lvl, compiled)
    obstacle_composition = obstacle_composition_validate_lvl(lvl, compiled)
    visual_grammar = visual_grammar_validate_lvl(lvl, compiled)
    out["structural"] = {
        "valid": structural_valid,
        "playable_cell_count": playable,
        "initial_match_count": initial_matches,
        "legal_move_exists": legal,
        "objective_ok": objective_ok,
        "drop_path_ok": drop_path_ok,
    }
    out["semantic"] = semantic
    out["level_intent_gate"] = level_intent
    out["mechanism_spec_gate"] = mechanism_spec
    out["personalization_gate"] = personalization
    out["taste"] = taste
    out["progression"] = progression
    out["obstacle_composition_gate"] = obstacle_composition
    out["visual_grammar_gate"] = visual_grammar
    if (
        structural_valid
        and semantic.get("valid")
        and level_intent.get("valid")
        and mechanism_spec.get("valid")
        and personalization.get("valid")
        and progression.get("valid")
        and obstacle_composition.get("valid")
        and visual_grammar.get("valid")
        and taste.get("valid")
    ):
        out["verdict"] = "approved"
    elif not structural_valid:
        out["verdict"] = "revise_major"
    elif not semantic.get("valid"):
        out["verdict"] = "revise_semantic"
    elif not level_intent.get("valid"):
        out["verdict"] = "revise_level_intent"
    elif not mechanism_spec.get("valid"):
        out["verdict"] = "revise_mechanism_spec"
    elif not personalization.get("valid"):
        out["verdict"] = "revise_personalization"
    elif not progression.get("valid"):
        out["verdict"] = "revise_progression"
    elif not obstacle_composition.get("valid"):
        out["verdict"] = "revise_obstacle_composition"
    elif not visual_grammar.get("valid"):
        out["verdict"] = "revise_visual_grammar"
    else:
        out["verdict"] = "revise_taste"
    if initial_matches:
        out["recommendations"].append("initial board contains auto matches; acceptable for preview only, avoid for final tuning")
    if not legal:
        out["recommendations"].append("seed/fixed board has no legal opening move")
    if not drop_path_ok:
        out["recommendations"].append("drop_relic must start above a bottom exit column in executable v0")
    for err in semantic.get("errors", []):
        out["recommendations"].append(f"semantic gate: {err.get('message')}")
    for warn_item in semantic.get("warnings", []):
        out["recommendations"].append(f"semantic warning: {warn_item.get('message')}")
    for err in level_intent.get("errors", []):
        out["recommendations"].append(f"level intent gate: {err.get('message')}")
    for warn_item in level_intent.get("warnings", []):
        out["recommendations"].append(f"level intent warning: {warn_item.get('message')}")
    for err in mechanism_spec.get("errors", []):
        out["recommendations"].append(f"mechanism spec gate: {err.get('message')}")
    for warn_item in mechanism_spec.get("warnings", []):
        out["recommendations"].append(f"mechanism spec warning: {warn_item.get('message')}")
    for err in personalization.get("errors", []):
        out["recommendations"].append(f"personalization gate: {err.get('message')}")
    for warn_item in personalization.get("warnings", []):
        out["recommendations"].append(f"personalization warning: {warn_item.get('message')}")
    for err in taste.get("errors", []):
        out["recommendations"].append(f"taste gate: {err.get('message')}")
    for warn_item in taste.get("warnings", []):
        out["recommendations"].append(f"taste warning: {warn_item.get('message')}")
    for err in progression.get("errors", []):
        out["recommendations"].append(f"progression gate: {err.get('message')}")
    for warn_item in progression.get("warnings", []):
        out["recommendations"].append(f"progression warning: {warn_item.get('message')}")
    for err in obstacle_composition.get("errors", []):
        out["recommendations"].append(f"obstacle composition gate: {err.get('message')}")
    for warn_item in obstacle_composition.get("warnings", []):
        out["recommendations"].append(f"obstacle composition warning: {warn_item.get('message')}")
    for err in visual_grammar.get("errors", []):
        out["recommendations"].append(f"visual grammar gate: {err.get('message')}")
    for warn_item in visual_grammar.get("warnings", []):
        out["recommendations"].append(f"visual grammar warning: {warn_item.get('message')}")
    return out


PERSONA_WEIGHTS: dict[str, dict[str, float]] = {
    "random_baseline": {"immediate": 0.10, "target": 0.05, "blocker": 0.05, "special": 0.00, "mechanism": 0.00, "bottom": 0.05, "cascade": 0.05, "risk": 0.00, "noise": 0.70},
    "visual_casual": {"immediate": 0.30, "target": 0.22, "blocker": 0.12, "special": 0.06, "mechanism": 0.08, "bottom": 0.12, "cascade": 0.10, "risk": 0.05, "noise": 0.25},
    "bottom_cascade": {"immediate": 0.22, "target": 0.12, "blocker": 0.08, "special": 0.08, "mechanism": 0.05, "bottom": 0.25, "cascade": 0.20, "risk": 0.04, "noise": 0.22},
    "goal_focused": {"immediate": 0.18, "target": 0.34, "blocker": 0.18, "special": 0.07, "mechanism": 0.13, "bottom": 0.04, "cascade": 0.06, "risk": 0.06, "noise": 0.16},
    "special_builder": {"immediate": 0.14, "target": 0.16, "blocker": 0.10, "special": 0.32, "mechanism": 0.08, "bottom": 0.05, "cascade": 0.15, "risk": 0.07, "noise": 0.18},
    "mechanism_aware": {"immediate": 0.12, "target": 0.20, "blocker": 0.16, "special": 0.12, "mechanism": 0.30, "bottom": 0.03, "cascade": 0.07, "risk": 0.08, "noise": 0.12},
    "frustrated_retry": {"immediate": 0.34, "target": 0.25, "blocker": 0.12, "special": 0.04, "mechanism": 0.08, "bottom": 0.07, "cascade": 0.05, "risk": 0.12, "noise": 0.30},
}


PROFILE_MIXES: dict[str, dict[str, float]] = {
    "balanced": {
        "visual_casual": 0.20,
        "goal_focused": 0.20,
        "bottom_cascade": 0.15,
        "special_builder": 0.15,
        "mechanism_aware": 0.15,
        "frustrated_retry": 0.10,
        "random_baseline": 0.05,
    },
    "female_prior": {
        "visual_casual": 0.25,
        "goal_focused": 0.20,
        "bottom_cascade": 0.15,
        "special_builder": 0.12,
        "mechanism_aware": 0.10,
        "frustrated_retry": 0.13,
        "random_baseline": 0.05,
    },
    "male_prior": {
        "visual_casual": 0.12,
        "goal_focused": 0.18,
        "bottom_cascade": 0.12,
        "special_builder": 0.20,
        "mechanism_aware": 0.25,
        "frustrated_retry": 0.08,
        "random_baseline": 0.05,
    },
}


def normalized_profile_mix(profile: str) -> dict[str, float]:
    if profile not in PROFILE_MIXES:
        raise ValueError(f"unknown simulation profile {profile}")
    mix = PROFILE_MIXES[profile]
    total = sum(float(v) for v in mix.values())
    return {k: float(v) / total for k, v in mix.items()}


def objective_remaining(state: dict[str, Any], objectives: list[dict[str, Any]]) -> int:
    total = 0
    for obj in objectives:
        typ = obj.get("type")
        target = int(obj.get("target", 0))
        if typ == "CLEAR_JELLY":
            total += max(0, layer_sum(state["jelly"]))
        elif typ == "CLEAR_BLOCKER":
            total += max(0, layer_sum(state["coat"]))
        elif typ == "COLLECT":
            key = f"collect_{int(obj.get('species', -1))}"
            total += max(0, target - int(state["progress"].get(key, 0)))
        elif typ == "COLLECT_INGREDIENT":
            total += max(0, target - int(state["progress"].get("ingredient_collected", 0)))
    return total


def is_sim_won(state: dict[str, Any], objectives: list[dict[str, Any]]) -> bool:
    return objective_remaining(state, objectives) <= 0


def copy_state(compiled: dict[str, Any]) -> dict[str, Any]:
    return {
        "grid": [row[:] for row in compiled["init_board"]],
        "jelly": [row[:] for row in compiled["jelly"]],
        "coat": [row[:] for row in compiled["coat"]],
        "choco": [row[:] for row in compiled["choco"]],
        "ing": [row[:] for row in compiled["ing"]],
        "exits": set(int(x) for x in compiled.get("exits", [])),
        "progress": {},
    }


def legal_moves_for_grid(grid: list[list[int]]) -> list[tuple[tuple[int, int], tuple[int, int]]]:
    h = len(grid)
    w = len(grid[0]) if h else 0
    out: list[tuple[tuple[int, int], tuple[int, int]]] = []
    for r in range(h):
        for c in range(w):
            if grid[r][c] < 0:
                continue
            for dr, dc in ((1, 0), (0, 1)):
                rr, cc = r + dr, c + dc
                if rr >= h or cc >= w or grid[rr][cc] < 0:
                    continue
                grid[r][c], grid[rr][cc] = grid[rr][cc], grid[r][c]
                if find_matches(grid):
                    out.append(((r, c), (rr, cc)))
                grid[r][c], grid[rr][cc] = grid[rr][cc], grid[r][c]
    return out


def apply_gravity_simple(grid: list[list[int]], colors: int, rng: random.Random) -> None:
    h = len(grid)
    w = len(grid[0]) if h else 0
    for c in range(w):
        r = h - 1
        while r >= 0:
            if grid[r][c] == -2:
                r -= 1
                continue
            end = r
            while r >= 0 and grid[r][c] != -2:
                r -= 1
            start = r + 1
            vals = [grid[y][c] for y in range(start, end + 1) if grid[y][c] >= 0]
            missing = (end - start + 1) - len(vals)
            new_vals = [rng.randrange(colors) for _ in range(missing)] + vals
            for idx, y in enumerate(range(start, end + 1)):
                grid[y][c] = new_vals[idx]


def advance_ingredients_simple(state: dict[str, Any], cleared_cells: set[tuple[int, int]] | None = None) -> None:
    """Advance drop_relic one row per cascade in the v0 persona simulator.

    This is not a full engine recreation. It gives the simulator a readable
    approximation of "clear below the lost cub so it travels toward the nest"
    without introducing deep physics into the planning loop.  When
    ``cleared_cells`` is provided, the cub only advances if the cell directly
    below it participated in the current cascade; otherwise drop objectives are
    unrealistically easy because the actor would drift downward every cascade.
    """
    ing = state["ing"]
    grid = state["grid"]
    exits = state.get("exits", set())
    h = len(ing)
    w = len(ing[0]) if h else 0
    for r in range(h - 1, -1, -1):
        for c in range(w):
            if ing[r][c] <= 0:
                continue
            if r == h - 1:
                if c in exits:
                    state["progress"]["ingredient_collected"] = int(state["progress"].get("ingredient_collected", 0)) + ing[r][c]
                    ing[r][c] = 0
                continue
            if cleared_cells is not None and (r + 1, c) not in cleared_cells:
                continue
            if grid[r + 1][c] != -2 and ing[r + 1][c] == 0:
                count = ing[r][c]
                ing[r][c] = 0
                if r + 1 == h - 1 and c in exits:
                    state["progress"]["ingredient_collected"] = int(state["progress"].get("ingredient_collected", 0)) + count
                else:
                    ing[r + 1][c] = count


def simulate_apply_move(state: dict[str, Any], move: tuple[tuple[int, int], tuple[int, int]], colors: int, rng: random.Random, objectives: list[dict[str, Any]]) -> dict[str, float]:
    before_remaining = objective_remaining(state, objectives)
    before_coat = layer_sum(state["coat"])
    grid = state["grid"]
    (r1, c1), (r2, c2) = move
    grid[r1][c1], grid[r2][c2] = grid[r2][c2], grid[r1][c1]
    total_cleared = 0
    cascade_count = 0
    special_created = 0
    touched_rows: list[int] = []

    for _ in range(12):
        runs = find_match_runs(grid)
        if not runs:
            break
        cascade_count += 1
        cells = {cell for run in runs for cell in run}
        special_created += sum(1 for run in runs if len(run) >= 4)
        total_cleared += len(cells)
        for r, c in cells:
            touched_rows.append(r)
            val = grid[r][c]
            if val >= 0:
                key = f"collect_{val}"
                state["progress"][key] = int(state["progress"].get(key, 0)) + 1
            if state["jelly"][r][c] > 0:
                state["jelly"][r][c] = 0
            grid[r][c] = -1
        # Adjacent/simple blocker damage.
        damaged: set[tuple[int, int]] = set()
        for r, c in cells:
            for rr, cc in ((r, c), (r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                if 0 <= rr < len(grid) and 0 <= cc < len(grid[0]) and state["coat"][rr][cc] > 0:
                    damaged.add((rr, cc))
        for r, c in damaged:
            state["coat"][r][c] = max(0, state["coat"][r][c] - 1)
        apply_gravity_simple(grid, colors, rng)
        advance_ingredients_simple(state, cells)

    after_remaining = objective_remaining(state, objectives)
    after_coat = layer_sum(state["coat"])
    h = len(grid)
    return {
        "immediate": min(1.0, total_cleared / 9.0),
        "target": min(1.0, max(0, before_remaining - after_remaining) / max(1, before_remaining)),
        "blocker": min(1.0, max(0, before_coat - after_coat) / max(1, before_coat)),
        "special": min(1.0, special_created / 2.0),
        "mechanism": min(1.0, (max(0, before_coat - after_coat) + max(0, before_remaining - after_remaining)) / 4.0),
        "bottom": (sum(touched_rows) / len(touched_rows) / max(1, h - 1)) if touched_rows else 0.0,
        "cascade": min(1.0, max(0, cascade_count - 1) / 3.0),
        "risk": 0.0,
    }


def score_move(compiled: dict[str, Any], base_state: dict[str, Any], move: tuple[tuple[int, int], tuple[int, int]], persona: str, rng: random.Random) -> tuple[float, dict[str, float]]:
    trial = {
        "grid": [row[:] for row in base_state["grid"]],
        "jelly": [row[:] for row in base_state["jelly"]],
        "coat": [row[:] for row in base_state["coat"]],
        "choco": [row[:] for row in base_state["choco"]],
        "ing": [row[:] for row in base_state["ing"]],
        "exits": set(base_state.get("exits", set())),
        "progress": dict(base_state["progress"]),
    }
    features = simulate_apply_move(trial, move, len(compiled["species"]), rng, compiled["objectives"])
    weights = PERSONA_WEIGHTS[persona]
    total = 0.0
    for key, val in features.items():
        if key == "risk":
            total -= weights.get("risk", 0.0) * val
        else:
            total += weights.get(key, 0.0) * val
    total += rng.uniform(-weights["noise"], weights["noise"])
    return total, features


def run_one_attempt(compiled: dict[str, Any], persona: str, seed: int) -> dict[str, Any]:
    rng = random.Random(seed)
    state = copy_state(compiled)
    moves = int(compiled["move_limit"])
    activation_turn = None
    cascade_score = 0.0
    no_progress_turns = 0
    for turn in range(1, moves + 1):
        if is_sim_won(state, compiled["objectives"]):
            return {"won": True, "turns": turn - 1, "moves_left": moves - turn + 1, "activation_turn": activation_turn, "cascade_score": cascade_score, "no_progress_turns": no_progress_turns}
        moves_list = legal_moves_for_grid(state["grid"])
        if not moves_list:
            return {"won": False, "turns": turn - 1, "moves_left": moves - turn + 1, "fail_reason": "no_legal_move_loop", "activation_turn": activation_turn, "cascade_score": cascade_score, "no_progress_turns": no_progress_turns}
        scored = [score_move(compiled, state, mv, persona, rng) + (mv,) for mv in moves_list]
        scored.sort(key=lambda x: x[0], reverse=True)
        if rng.random() < 0.80 or len(scored) == 1:
            chosen = scored[0]
        else:
            top = scored[: min(3, len(scored))]
            weights = [math.exp(x[0] / 0.15) for x in top]
            chosen = rng.choices(top, weights=weights, k=1)[0]
        _, features, move = chosen
        before_coat = layer_sum(state["coat"])
        simulate_apply_move(state, move, len(compiled["species"]), rng, compiled["objectives"])
        cascade_score += features.get("cascade", 0.0)
        if features.get("target", 0.0) + features.get("blocker", 0.0) + features.get("mechanism", 0.0) <= 0.0:
            no_progress_turns += 1
        if activation_turn is None and before_coat > layer_sum(state["coat"]):
            activation_turn = turn
    won = is_sim_won(state, compiled["objectives"])
    fail_reason = "too_many_leftovers" if objective_remaining(state, compiled["objectives"]) <= 3 else "low_target_progress"
    return {"won": won, "turns": moves, "moves_left": 0, "fail_reason": None if won else fail_reason, "activation_turn": activation_turn, "cascade_score": cascade_score, "no_progress_turns": no_progress_turns}


def simulate_lvl(lvl: dict[str, Any], runs: int = 30, profile: str = "balanced") -> dict[str, Any]:
    compiled, diag = compile_lvl(lvl)
    if compiled is None:
        return {"level_id": lvl.get("id", "<unknown>"), "valid": False, "lint": diag.to_json()}
    try:
        profile_mix = normalized_profile_mix(profile)
    except ValueError as exc:
        return {"level_id": lvl.get("id", "<unknown>"), "valid": False, "error": str(exc)}
    summary: dict[str, Any] = {
        "level_id": lvl.get("id"),
        "valid": True,
        "metric_mode": "stochastic",
        "target_profile": profile,
        "profile_mix": profile_mix,
        "runs_per_persona": runs,
        "personas": {},
    }
    weighted_pass = 0.0
    weighted_remaining = 0.0
    weighted_activation = 0.0
    weighted_cascade = 0.0
    weighted_dead_board = 0.0
    weighted_reshuffle = 0.0
    weighted_no_progress = 0.0
    weighted_luck = 0.0
    weighted_annoyance = 0.0
    weighted_fail_counts: dict[str, float] = {}
    for persona, profile_weight in profile_mix.items():
        persona_offset = sum(ord(ch) for ch in persona)
        results = [run_one_attempt(compiled, persona, int(compiled["seed"]) + i + persona_offset) for i in range(runs)]
        wins = [r for r in results if r["won"]]
        pass_rate = len(wins) / max(1, runs)
        fail_counts: dict[str, int] = {}
        for r in results:
            if not r["won"]:
                fail_counts[str(r.get("fail_reason", "unknown"))] = fail_counts.get(str(r.get("fail_reason", "unknown")), 0) + 1
        avg_remaining = sum(r["moves_left"] for r in wins) / max(1, len(wins))
        activation_rate = sum(1 for r in results if r.get("activation_turn") is not None) / max(1, runs)
        avg_cascade = sum(float(r.get("cascade_score", 0.0)) for r in results) / max(1, runs)
        dead_board_rate = sum(1 for r in results if r.get("fail_reason") == "no_legal_move_loop") / max(1, runs)
        reshuffle_rate = dead_board_rate
        no_progress_rate = sum(float(r.get("no_progress_turns", 0)) / max(1, int(r.get("turns", 1) or 1)) for r in results) / max(1, runs)
        luck_dependency = min(1.0, max(0.0, 4.0 * pass_rate * (1.0 - pass_rate)))
        annoyance_score = min(1.0, dead_board_rate * 0.35 + reshuffle_rate * 0.20 + no_progress_rate * 0.30 + luck_dependency * 0.15)
        fail_dist = {k: v / max(1, runs) for k, v in fail_counts.items()}
        summary["personas"][persona] = {
            "simulated_pass_rate_at_1": round(pass_rate, 3),
            "avg_remaining_moves": round(avg_remaining, 2),
            "mechanism_activation_rate": round(activation_rate, 3),
            "avg_cascade_score": round(avg_cascade, 3),
            "reshuffle_rate": round(reshuffle_rate, 3),
            "dead_board_rate": round(dead_board_rate, 3),
            "no_progress_turn_rate": round(no_progress_rate, 3),
            "luck_dependency_proxy": round(luck_dependency, 3),
            "annoyance_score": round(annoyance_score, 3),
            "fail_reason_distribution": {k: round(v, 3) for k, v in fail_dist.items()},
        }
        weighted_pass += profile_weight * pass_rate
        weighted_remaining += profile_weight * avg_remaining
        weighted_activation += profile_weight * activation_rate
        weighted_cascade += profile_weight * avg_cascade
        weighted_dead_board += profile_weight * dead_board_rate
        weighted_reshuffle += profile_weight * reshuffle_rate
        weighted_no_progress += profile_weight * no_progress_rate
        weighted_luck += profile_weight * luck_dependency
        weighted_annoyance += profile_weight * annoyance_score
        for reason, value in fail_dist.items():
            weighted_fail_counts[reason] = weighted_fail_counts.get(reason, 0.0) + profile_weight * value
    summary["aggregate_pass_rate_at_1"] = round(weighted_pass, 3)
    summary["aggregate_avg_remaining_moves"] = round(weighted_remaining, 2)
    summary["aggregate_mechanism_activation_rate"] = round(weighted_activation, 3)
    summary["aggregate_cascade_score"] = round(weighted_cascade, 3)
    summary["aggregate_reshuffle_rate"] = round(weighted_reshuffle, 3)
    summary["aggregate_dead_board_rate"] = round(weighted_dead_board, 3)
    summary["aggregate_no_progress_turn_rate"] = round(weighted_no_progress, 3)
    summary["aggregate_luck_dependency_proxy"] = round(weighted_luck, 3)
    summary["aggregate_annoyance_score"] = round(weighted_annoyance, 3)
    summary["aggregate_fail_reason_distribution"] = {k: round(v, 3) for k, v in sorted(weighted_fail_counts.items())}
    return summary


def pass_band_for_level(lvl: dict[str, Any]) -> tuple[float, float]:
    band = lvl.get("meta", {}).get("target_pass_band") or lvl.get("personalization", {}).get("target_pass_band")
    if isinstance(band, list) and len(band) == 2:
        return float(band[0]), float(band[1])
    role = str(lvl.get("meta", {}).get("role", "variation"))
    return ROLE_PASS_BANDS.get(role, ROLE_PASS_BANDS["variation"])


PLAYER_CONTEXT_WINDOW = 5


def _record_won(record: dict[str, Any]) -> bool:
    if "won" in record:
        return bool(record.get("won"))
    status = str(record.get("status", record.get("result", ""))).lower()
    return status in {"won", "win", "passed", "complete", "completed", "cleared"}


def _record_coordinate(record: dict[str, Any]) -> int:
    return int(record.get("level_coordinate", record.get("level", record.get("coordinate", 0))) or 0)


def _level_has_new_mechanic(level: int) -> bool:
    spec = EARLY_LEVEL_PROGRESSION.get(level, {})
    lifecycle = spec.get("lifecycle", []) if isinstance(spec, dict) else []
    return any(isinstance(item, dict) and bool(item.get("is_new")) for item in lifecycle)


def _level_primary_lifecycle(level: int) -> dict[str, Any]:
    spec = EARLY_LEVEL_PROGRESSION.get(level, {})
    lifecycle = spec.get("lifecycle", []) if isinstance(spec, dict) else []
    for item in lifecycle:
        if isinstance(item, dict) and item.get("role") == "primary":
            return dict(item)
    for item in lifecycle:
        if isinstance(item, dict):
            return dict(item)
    return {"mechanic": "target_mark", "phase": "practice", "role": "primary", "is_new": False}


def _derive_profile_from_axes(axes: dict[str, Any], prior: str) -> tuple[str, str]:
    challenge = float(axes.get("challenge_bias", 0.5) or 0.5)
    strategy = float(axes.get("strategy_bias", 0.5) or 0.5)
    reward = float(axes.get("reward_bias", 0.5) or 0.5)
    cuteness = float(axes.get("cuteness_bias", 0.5) or 0.5)
    annoyance = float(axes.get("annoyance_tolerance", 0.45) or 0.45)
    # Once behavior exists, it beats demographic prior.  The thresholds are
    # deliberately simple and auditable; real telemetry can replace them later.
    if challenge >= 0.65 and strategy >= 0.65 and (challenge + strategy) >= (reward + cuteness + 0.35):
        return "male_prior", "behavior_axes"
    if (reward >= 0.62 or cuteness >= 0.65) and annoyance <= 0.48:
        return "female_prior", "behavior_axes"
    if prior == "female":
        return "female_prior", "cold_start_prior"
    if prior == "male":
        return "male_prior", "cold_start_prior"
    return "balanced", "balanced_default"


def normalize_player_context(raw: dict[str, Any]) -> dict[str, Any]:
    """Normalize telemetry/cold-start input for next-level generation.

    The schema is intentionally permissive because v0 has no production
    telemetry yet.  A context may contain only cold-start prior, or richer
    records with attempts, fail reasons, remaining moves, and mechanism hints.
    """
    if not isinstance(raw, dict):
        raise ValueError("player context must be a JSON object")
    prior = str(raw.get("cold_start_prior", raw.get("gender_prior", "unknown")) or "unknown")
    if prior not in PERSONA_AXES_BY_PRIOR:
        prior = "unknown"
    axes_raw = raw.get("persona_axes")
    axes_from_behavior = isinstance(axes_raw, dict)
    if axes_from_behavior:
        axes = copy.deepcopy(PERSONA_AXES_BY_PRIOR["unknown"])
        for key in axes:
            if key in axes_raw:
                axes[key] = max(0.0, min(1.0, float(axes_raw[key])))
    else:
        axes = copy.deepcopy(PERSONA_AXES_BY_PRIOR[prior])

    explicit_profile = str(raw.get("simulation_profile", raw.get("target_profile", "")) or "")
    if explicit_profile in PROFILE_MIXES:
        target_profile = explicit_profile
        profile_source = "explicit"
    elif axes_from_behavior:
        target_profile, profile_source = _derive_profile_from_axes(axes, prior)
    elif prior == "female":
        target_profile = "female_prior"
        profile_source = "cold_start_prior"
    elif prior == "male":
        target_profile = "male_prior"
        profile_source = "cold_start_prior"
    else:
        target_profile = "balanced"
        profile_source = "balanced_default"

    played: list[dict[str, Any]] = []
    history = raw.get("played_levels", raw.get("history", []))
    if not isinstance(history, list):
        history = []
    for idx, record in enumerate(history):
        if not isinstance(record, dict):
            continue
        level = _record_coordinate(record)
        if level <= 0:
            continue
        attempts = max(1, int(record.get("attempts", record.get("attempt_count", 1)) or 1))
        won = _record_won(record)
        moves_left_raw = record.get("moves_left", record.get("remaining_moves"))
        moves_left = int(moves_left_raw) if isinstance(moves_left_raw, (int, float)) else None
        fail_reasons = record.get("fail_reasons", record.get("fail_reason_distribution", {}))
        if not isinstance(fail_reasons, dict):
            fail_reasons = {str(fail_reasons): 1} if fail_reasons else {}
        mechanics = record.get("mechanisms", record.get("active_mechanisms", []))
        if not isinstance(mechanics, list):
            mechanics = []
        played.append({
            "index": idx,
            "level_coordinate": level,
            "won": won,
            "attempts": attempts,
            "moves_left": moves_left,
            "fail_reasons": {str(k): float(v) for k, v in fail_reasons.items()},
            "mechanism_activation_rate": float(record.get("mechanism_activation_rate", 0.0) or 0.0),
            "trouble_mechanisms": [str(x) for x in record.get("trouble_mechanisms", [])] if isinstance(record.get("trouble_mechanisms", []), list) else [],
            "active_mechanisms": [str(x) for x in mechanics],
            "had_new_mechanic": bool(record.get("had_new_mechanic", _level_has_new_mechanic(level))),
            "had_reward": bool(record.get("had_reward", bool(EARLY_LEVEL_PROGRESSION.get(level, {}).get("rewards", [])))),
        })

    explicit_next = raw.get("next_level_coordinate", raw.get("next_coordinate"))
    if isinstance(explicit_next, (int, float)) and int(explicit_next) > 0:
        next_coordinate = int(explicit_next)
    elif not played:
        next_coordinate = 1
    else:
        latest = played[-1]
        if not bool(latest["won"]):
            next_coordinate = int(latest["level_coordinate"])
        else:
            won_levels = [int(item["level_coordinate"]) for item in played if bool(item["won"])]
            next_coordinate = max(won_levels or [int(latest["level_coordinate"])]) + 1

    return {
        "player_id": str(raw.get("player_id", raw.get("id", "anonymous"))),
        "cold_start_prior": prior,
        "persona_axes": axes,
        "target_profile": target_profile,
        "profile_source": profile_source,
        "played_levels": played,
        "recent_levels": played[-PLAYER_CONTEXT_WINDOW:],
        "next_level_coordinate": next_coordinate,
        "raw_context_version": int(raw.get("version", 0) or 0),
    }


def derive_rhythm_state(context: dict[str, Any]) -> dict[str, Any]:
    recent = list(context.get("recent_levels", []))
    trailing_failures = 0
    for item in reversed(recent):
        if bool(item.get("won")):
            break
        trailing_failures += 1
    wins = [item for item in recent if bool(item.get("won"))]
    avg_attempts = sum(float(item.get("attempts", 1)) for item in recent) / max(1, len(recent))
    win_rate = len(wins) / max(1, len(recent))
    moves_values = [float(item["moves_left"]) for item in wins if item.get("moves_left") is not None]
    avg_moves_left = sum(moves_values) / max(1, len(moves_values))
    no_reward_streak = 0
    for item in reversed(recent):
        if bool(item.get("had_reward")):
            break
        no_reward_streak += 1
    recent_new_mechanic_count = sum(1 for item in recent if bool(item.get("had_new_mechanic")))
    next_coordinate = int(context.get("next_level_coordinate", 1))
    next_primary = _level_primary_lifecycle(next_coordinate)
    next_has_new = bool(next_primary.get("is_new"))

    trouble: dict[str, float] = {}
    for item in recent:
        level_primary = str(_level_primary_lifecycle(int(item.get("level_coordinate", 0))).get("mechanic", "unknown"))
        if not bool(item.get("won")):
            trouble[level_primary] = trouble.get(level_primary, 0.0) + float(item.get("attempts", 1))
        for mech in item.get("trouble_mechanisms", []):
            trouble[str(mech)] = trouble.get(str(mech), 0.0) + 1.0
        reasons = item.get("fail_reasons", {})
        if isinstance(reasons, dict):
            blob = " ".join(str(k) for k in reasons)
            if "shell" in blob or "crystal" in blob:
                trouble["crystal_shell"] = trouble.get("crystal_shell", 0.0) + 1.0
            if "relic" in blob or "ingredient" in blob or "cub" in blob:
                trouble["drop_relic"] = trouble.get("drop_relic", 0.0) + 1.0

    profile = str(context.get("target_profile", "balanced"))
    axes = context.get("persona_axes", {}) if isinstance(context.get("persona_axes"), dict) else {}
    challenge = float(axes.get("challenge_bias", 0.5) or 0.5)
    strategy = float(axes.get("strategy_bias", 0.5) or 0.5)

    if trailing_failures >= 2 or avg_attempts >= 3.0:
        rhythm_role = "breather_recovery"
        reason = "recent_failures_or_many_attempts"
    elif next_has_new:
        rhythm_role = "new_mechanic_onboarding"
        reason = "next_coordinate_reveals_new_mechanic"
    elif no_reward_streak >= 2:
        rhythm_role = "reward_lift"
        reason = "recent_levels_lacked_board_rewards"
    elif win_rate >= 0.80 and avg_moves_left >= 3.0 and (profile == "male_prior" or (challenge + strategy) >= 1.25):
        rhythm_role = "pressure_step"
        reason = "player_is_clearing_with_margin"
    else:
        rhythm_role = "canonical_progression"
        reason = "follow_sequence_plan"

    return {
        "window": PLAYER_CONTEXT_WINDOW,
        "recent_count": len(recent),
        "trailing_failures": trailing_failures,
        "recent_win_rate": round(win_rate, 3),
        "recent_avg_attempts": round(avg_attempts, 2),
        "recent_avg_moves_left": round(avg_moves_left, 2),
        "recent_new_mechanic_count": recent_new_mechanic_count,
        "no_reward_streak": no_reward_streak,
        "next_coordinate_has_new_mechanic": next_has_new,
        "next_primary_mechanic": str(next_primary.get("mechanic", "target_mark")),
        "rhythm_role": rhythm_role,
        "reason": reason,
        "trouble_mechanisms": {k: round(v, 2) for k, v in sorted(trouble.items(), key=lambda item: (-item[1], item[0]))},
    }


def _adjust_pass_band(base: list[float], rhythm_role: str) -> list[float]:
    low = float(base[0])
    high = float(base[1])
    if rhythm_role == "breather_recovery":
        return [round(max(0.88, low), 2), 1.00]
    if rhythm_role == "new_mechanic_onboarding":
        return [round(max(0.90, low), 2), 1.00]
    if rhythm_role == "reward_lift":
        return [round(max(0.78, low), 2), round(max(high, 0.95), 2)]
    if rhythm_role == "pressure_step":
        return [round(max(0.35, low - 0.08), 2), round(min(0.90, max(low + 0.12, high - 0.04)), 2)]
    return [round(low, 2), round(high, 2)]


def build_next_level_brief(context: dict[str, Any], rhythm_state: dict[str, Any] | None = None) -> dict[str, Any]:
    rhythm_state = rhythm_state or derive_rhythm_state(context)
    level = int(context.get("next_level_coordinate", 1))
    if level not in LEVEL_COORDINATES:
        raise ValueError(f"no programmatic coordinate for next level {level}")
    coord = LEVEL_COORDINATES[level]
    progression = generated_progression(level, coord)
    intent = generated_level_intent(level, coord)
    primary = _level_primary_lifecycle(level)
    rhythm_role = str(rhythm_state.get("rhythm_role", "canonical_progression"))
    target_profile = str(context.get("target_profile", "balanced"))

    if rhythm_role == "breather_recovery":
        variant = "assisted"
    elif rhythm_role == "pressure_step":
        variant = "advanced" if target_profile != "female_prior" else "base"
    elif target_profile == "female_prior":
        variant = "female_prior"
    elif target_profile == "male_prior":
        variant = "male_prior"
    else:
        variant = "base"

    base_band = list(coord["target_pass_band"])
    target_band = _adjust_pass_band(base_band, rhythm_role)
    rewards = list(progression["reward_budget"].get("primitives", []))
    if rhythm_role in {"breather_recovery", "reward_lift"} and not rewards:
        rewards = ["line_h_gem"]
    reward_required = bool(rewards) or rhythm_role in {"breather_recovery", "reward_lift"}
    annoyance = dict(progression["annoyance_budget"])
    if rhythm_role in {"breather_recovery", "new_mechanic_onboarding", "reward_lift"}:
        annoyance["max_no_progress_turn_rate"] = min(float(annoyance.get("max_no_progress_turn_rate", 0.35)), 0.30)
        annoyance["max_luck_dependency_proxy"] = min(float(annoyance.get("max_luck_dependency_proxy", 0.40)), 0.35)
    elif rhythm_role == "pressure_step":
        annoyance["max_no_progress_turn_rate"] = min(0.50, float(annoyance.get("max_no_progress_turn_rate", 0.40)) + 0.05)

    forbid = ["color_order_goal", "second_primary_mechanism"]
    if rhythm_role == "breather_recovery":
        forbid.extend(["avoid_new_mechanic_escalation", "extra_dynamic_obstacle"])
    elif rhythm_role == "new_mechanic_onboarding":
        forbid.extend(["second_new_mechanic", "large_problem_space"])

    return {
        "level_coordinate": level,
        "source": "player_context_director_v0",
        "target_profile": target_profile if target_profile in PROFILE_MIXES else "balanced",
        "profile_source": context.get("profile_source", "unknown"),
        "variant": variant,
        "rhythm_role": rhythm_role,
        "rhythm_reason": rhythm_state.get("reason", ""),
        "canonical_arc_role": progression["episode"]["arc_role"],
        "primary_mechanic": str(primary.get("mechanic", "target_mark")),
        "mechanic_lifecycle_phase": str(primary.get("phase", "practice")),
        "target_pass_band": target_band,
        "reward_budget": {
            "required": reward_required,
            "primitives": rewards,
            "purpose": "context_safety_valve_or_sequence_reward" if reward_required else progression["reward_budget"].get("purpose", "keep_focus"),
        },
        "annoyance_budget": annoyance,
        "board_scale": copy.deepcopy(intent["board_scale"]),
        "objective_verb": intent["objective_verb"],
        "negative_space": {"forbid": forbid},
        "context_summary": {
            "recent_win_rate": rhythm_state.get("recent_win_rate"),
            "trailing_failures": rhythm_state.get("trailing_failures"),
            "recent_avg_attempts": rhythm_state.get("recent_avg_attempts"),
            "no_reward_streak": rhythm_state.get("no_reward_streak"),
            "trouble_mechanisms": rhythm_state.get("trouble_mechanisms", {}),
        },
    }


def _all_overlay_cells(lvl: dict[str, Any]) -> set[tuple[int, int]]:
    cells: set[tuple[int, int]] = set()
    for entry in lvl.get("overlays", []) or []:
        for r, c in overlay_cells(entry):
            cells.add((r, c))
    return cells


def _best_reward_cell(lvl: dict[str, Any]) -> list[int]:
    rows = board_rows(lvl, Diagnostics())
    occupied = _all_overlay_cells(lvl)
    h = len(rows)
    w = len(rows[0]) if h else 0
    candidates: list[tuple[int, int, int]] = []
    center_r = h // 2
    center_c = w // 2
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch == "." or (r, c) in occupied:
                continue
            candidates.append((abs(r - center_r) + abs(c - center_c), r, c))
    if not candidates:
        return [0, 0]
    _, r, c = sorted(candidates)[0]
    return [r, c]


def refresh_mechanism_specs_for_lvl(lvl: dict[str, Any]) -> None:
    level = int(lvl.get("meta", {}).get("level_coordinate", 0) or 0)
    coord = LEVEL_COORDINATES.get(level, {"role": lvl.get("meta", {}).get("role", "variation"), "eye": lvl.get("recipe", {}).get("eye", "unknown")})
    specs: dict[str, dict[str, Any]] = {}
    for atom in sorted(mechanism_atoms_for_lvl(lvl)):
        if atom not in BASE_MECHANISM_SPECS:
            continue
        spec = copy.deepcopy(BASE_MECHANISM_SPECS[atom])
        spec["level_role"] = coord.get("role", "variation")
        spec["linked_eye"] = coord.get("eye", "unknown")
        specs[atom] = spec
    lvl["mechanism_specs"] = specs


def apply_next_level_brief(lvl: dict[str, Any], context: dict[str, Any], rhythm_state: dict[str, Any], brief: dict[str, Any]) -> dict[str, Any]:
    out = copy.deepcopy(lvl)
    band = list(brief["target_pass_band"])
    out.setdefault("meta", {})["target_pass_band"] = band
    out["meta"]["generated_by"] = "tools/level_tool.py generate-next"
    out["meta"]["context_rhythm_role"] = brief["rhythm_role"]
    out.setdefault("personalization", {})["context_profile"] = brief["target_profile"]
    out["personalization"]["profile_source"] = brief.get("profile_source", "unknown")
    out["personalization"]["persona_axes"] = copy.deepcopy(context.get("persona_axes", out["personalization"].get("persona_axes", {})))
    out["personalization"]["target_pass_band"] = band
    out["personalization"]["player_context_id"] = context.get("player_id", "anonymous")
    out["personalization"]["context_window_size"] = len(context.get("recent_levels", []))
    progression = out.setdefault("progression", {})
    progression.setdefault("difficulty_rhythm", {})["target_pass_band"] = band
    progression["difficulty_rhythm"]["context_shape"] = brief["rhythm_role"]
    progression["annoyance_budget"] = copy.deepcopy(brief["annoyance_budget"])
    progression["reward_budget"] = {
        "required": bool(brief["reward_budget"]["required"]),
        "primitives": list(brief["reward_budget"]["primitives"]),
        "delivery": "preseeded_fx_overlay" if brief["reward_budget"]["primitives"] else "natural_cascade_only",
        "purpose": brief["reward_budget"].get("purpose", "context_directed_reward"),
    }
    existing_rewards = reward_layer_set(out)
    for primitive in brief["reward_budget"]["primitives"]:
        if primitive not in existing_rewards and primitive in REWARD_LAYER_TO_FX:
            out.setdefault("overlays", []).append(overlay("context_reward_safety_valve", [_best_reward_cell(out)], [primitive]))
            existing_rewards.add(primitive)
    out["player_context_director"] = {
        "context_summary": brief["context_summary"],
        "rhythm_state": copy.deepcopy(rhythm_state),
        "brief": copy.deepcopy(brief),
        "assignment_policy": "same_coordinate_if_unwon_else_next_coordinate; behavior_axes_override_cold_start_prior",
    }
    refresh_mechanism_specs_for_lvl(out)
    return out


def candidate_score(sim: dict[str, Any], band: tuple[float, float]) -> float:
    if not sim.get("valid"):
        return -999.0
    pass_rate = float(sim.get("aggregate_pass_rate_at_1", 0.0))
    activation = float(sim.get("aggregate_mechanism_activation_rate", 0.0))
    cascade = float(sim.get("aggregate_cascade_score", 0.0))
    annoyance = float(sim.get("aggregate_annoyance_score", 0.0))
    low, high = band
    if pass_rate < low:
        return -100.0 - (low - pass_rate) * 100.0
    # Within or above band: prefer inside the band, but mildly reward
    # activation/cascade because a pass that ignores the mechanism is weak.
    center = (low + high) / 2.0
    distance = abs(pass_rate - center)
    over_easy_penalty = max(0.0, pass_rate - high) * 20.0
    return 100.0 - distance * 20.0 - over_easy_penalty + activation * 5.0 + min(5.0, cascade) - annoyance * 12.0


def generate_select(level: int, variant: str, profile: str, candidates: int, runs: int) -> dict[str, Any]:
    attempts: list[dict[str, Any]] = []
    selected: dict[str, Any] | None = None
    selected_sim: dict[str, Any] | None = None
    selected_score = -9999.0
    selected_band: tuple[float, float] | None = None
    for idx in range(candidates):
        lvl = generate_level(level, variant, candidate=idx)
        validation = validate_lvl(lvl)
        band = pass_band_for_level(lvl)
        if validation.get("verdict") == "approved":
            sim = simulate_lvl(lvl, runs=runs, profile=profile)
            score = candidate_score(sim, band)
            pass_rate = float(sim.get("aggregate_pass_rate_at_1", 0.0)) if sim.get("valid") else 0.0
            if not sim.get("valid"):
                solve_pass = False
                regenerate_reason = "solver_invalid"
            elif pass_rate < band[0]:
                solve_pass = False
                regenerate_reason = "solver_below_band"
            elif pass_rate > band[1]:
                solve_pass = False
                regenerate_reason = "solver_above_band"
            else:
                solve_pass = True
                regenerate_reason = None
        else:
            sim = {"valid": False, "error": "validation failed"}
            score = -9999.0
            pass_rate = 0.0
            solve_pass = False
            regenerate_reason = "semantic_invalid" if validation.get("verdict") == "revise_semantic" else ("taste_invalid" if validation.get("verdict") == "revise_taste" else "structural_invalid")
        attempts.append({
            "candidate": idx,
            "level_id": lvl["id"],
            "seed": lvl["rules"]["seed"],
            "validation_verdict": validation.get("verdict"),
            "semantic_score": validation.get("semantic", {}).get("score"),
            "taste_score": validation.get("taste", {}).get("score"),
            "target_pass_band": list(band),
            "profile": profile,
            "pass_rate": round(pass_rate, 3),
            "annoyance_score": sim.get("aggregate_annoyance_score") if sim.get("valid") else None,
            "solve_pass": bool(solve_pass),
            "score": round(score, 3),
            "regenerate_reason": regenerate_reason,
        })
        if solve_pass and score > selected_score:
            selected = lvl
            selected_sim = sim
            selected_score = score
            selected_band = band
    return {
        "level_coordinate": level,
        "variant": variant,
        "profile": profile,
        "candidates_requested": candidates,
        "selected": selected,
        "selected_sim": selected_sim,
        "selected_score": round(selected_score, 3) if selected else None,
        "target_pass_band": list(selected_band) if selected_band else None,
        "attempts": attempts,
        "verdict": "selected" if selected else "regenerate_failed",
    }


def generate_next(raw_context: dict[str, Any], candidates: int = 10, runs: int = 20) -> dict[str, Any]:
    context = normalize_player_context(raw_context)
    rhythm_state = derive_rhythm_state(context)
    try:
        brief = build_next_level_brief(context, rhythm_state)
    except ValueError as exc:
        return {
            "valid": False,
            "verdict": "no_coordinate",
            "error": str(exc),
            "context": context,
            "rhythm_state": rhythm_state,
        }

    attempts: list[dict[str, Any]] = []
    selected: dict[str, Any] | None = None
    selected_sim: dict[str, Any] | None = None
    selected_score = -9999.0
    band = (float(brief["target_pass_band"][0]), float(brief["target_pass_band"][1]))
    profile = str(brief["target_profile"]) if str(brief["target_profile"]) in PROFILE_MIXES else "balanced"
    for idx in range(max(1, candidates)):
        lvl = generate_level(int(brief["level_coordinate"]), str(brief["variant"]), candidate=idx)
        lvl = apply_next_level_brief(lvl, context, rhythm_state, brief)
        validation = validate_lvl(lvl)
        if validation.get("verdict") == "approved":
            sim = simulate_lvl(lvl, runs=runs, profile=profile)
            score = candidate_score(sim, band)
            pass_rate = float(sim.get("aggregate_pass_rate_at_1", 0.0)) if sim.get("valid") else 0.0
            if not sim.get("valid"):
                solve_pass = False
                regenerate_reason = "solver_invalid"
            elif pass_rate < band[0]:
                solve_pass = False
                regenerate_reason = "solver_below_context_band"
            elif pass_rate > band[1]:
                solve_pass = False
                regenerate_reason = "solver_above_context_band"
            else:
                solve_pass = True
                regenerate_reason = None
        else:
            sim = {"valid": False, "error": "validation failed"}
            score = -9999.0
            pass_rate = 0.0
            solve_pass = False
            regenerate_reason = str(validation.get("verdict", "validation_failed"))
        attempts.append({
            "candidate": idx,
            "level_id": lvl["id"],
            "seed": lvl["rules"]["seed"],
            "validation_verdict": validation.get("verdict"),
            "context_rhythm_role": brief["rhythm_role"],
            "target_pass_band": list(band),
            "profile": profile,
            "pass_rate": round(pass_rate, 3),
            "annoyance_score": sim.get("aggregate_annoyance_score") if sim.get("valid") else None,
            "solve_pass": bool(solve_pass),
            "score": round(score, 3),
            "regenerate_reason": regenerate_reason,
        })
        if solve_pass and score > selected_score:
            selected = lvl
            selected_sim = sim
            selected_score = score

    return {
        "valid": selected is not None,
        "verdict": "selected" if selected else "regenerate_failed",
        "context": {
            "player_id": context["player_id"],
            "next_level_coordinate": context["next_level_coordinate"],
            "target_profile": context["target_profile"],
            "profile_source": context["profile_source"],
        },
        "rhythm_state": rhythm_state,
        "brief": brief,
        "selected": selected,
        "selected_sim": selected_sim,
        "selected_score": round(selected_score, 3) if selected else None,
        "attempts": attempts,
    }


def ascii_view(lvl: dict[str, Any]) -> str:
    rows = board_rows(lvl, Diagnostics())
    lines = [f"id: {lvl.get('id')}", f"objective: {normalize_objectives(lvl)}", "board:"]
    for i, row in enumerate(rows):
        lines.append(f"{i:02d} {row}")
    overlays = lvl.get("overlays", []) or []
    lines.append("overlays:")
    for entry in overlays:
        cells = overlay_cells(entry)
        lines.append(f"  {layer_names(entry.get('layers', []))}: {cells}")
    return "\n".join(lines)


def emit_json(data: Any, path: Path | None) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    else:
        print(text, end="")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Polaris v0 .lvl JSON Profile tool")
    sub = parser.add_subparsers(dest="cmd", required=True)
    for name in ("lint", "compile", "validate", "ascii", "simulate"):
        p = sub.add_parser(name)
        p.add_argument("input", type=Path)
        p.add_argument("-o", "--output", type=Path)
        if name == "simulate":
            p.add_argument("--runs", type=int, default=30)
            p.add_argument("--profile", default="balanced", choices=sorted(PROFILE_MIXES.keys()))
    gen = sub.add_parser("generate")
    gen.add_argument("--level", type=int, help="single level coordinate to generate")
    gen.add_argument("--through", type=int, help="generate levels 1..N")
    gen.add_argument("--variant", default="base", choices=sorted(VARIANT_RULES.keys()))
    gen.add_argument("-o", "--output", type=Path, help="single output .lvl path")
    gen.add_argument("--out-dir", type=Path, default=Path("levels_src"), help="output directory for --through")
    sel = sub.add_parser("generate-select")
    sel.add_argument("--level", type=int, required=True)
    sel.add_argument("--variant", default="base", choices=sorted(VARIANT_RULES.keys()))
    sel.add_argument("--profile", default="balanced", choices=sorted(PROFILE_MIXES.keys()))
    sel.add_argument("--candidates", type=int, default=10)
    sel.add_argument("--runs", type=int, default=20)
    sel.add_argument("--output", type=Path, required=True, help="selected .lvl output path")
    sel.add_argument("--report", type=Path, help="selection report JSON path")
    nxt = sub.add_parser("generate-next")
    nxt.add_argument("--context", type=Path, required=True, help="player context JSON path")
    nxt.add_argument("--candidates", type=int, default=10)
    nxt.add_argument("--runs", type=int, default=20)
    nxt.add_argument("--output", type=Path, required=True, help="selected personalized .lvl output path")
    nxt.add_argument("--report", type=Path, help="selection report JSON path")
    args = parser.parse_args(argv)

    if args.cmd == "generate":
        try:
            if args.through is not None:
                levels = list(range(1, int(args.through) + 1))
                written = write_generated_levels(levels, args.variant, args.out_dir)
                emit_json({"generated": [str(p) for p in written]}, None)
                return 0
            if args.level is None:
                parser.error("generate requires --level or --through")
            lvl = generate_level(int(args.level), args.variant)
        except ValueError as exc:
            emit_json({"valid": False, "error": str(exc)}, args.output)
            return 1
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(lvl, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        else:
            emit_json(lvl, None)
        return 0

    if args.cmd == "generate-select":
        result = generate_select(args.level, args.variant, args.profile, args.candidates, args.runs)
        selected = result.pop("selected")
        if selected is None:
            if args.report:
                emit_json(result, args.report)
            else:
                emit_json(result, None)
            return 1
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(selected, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if args.report:
            emit_json(result, args.report)
        else:
            emit_json(result, None)
        return 0

    if args.cmd == "generate-next":
        try:
            raw_context = json.loads(args.context.read_text(encoding="utf-8"))
            result = generate_next(raw_context, args.candidates, args.runs)
        except (OSError, json.JSONDecodeError, ValueError) as exc:
            emit_json({"valid": False, "verdict": "context_invalid", "error": str(exc)}, args.report)
            return 1
        selected = result.pop("selected")
        if selected is None:
            if args.report:
                emit_json(result, args.report)
            else:
                emit_json(result, None)
            return 1
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(selected, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if args.report:
            emit_json(result, args.report)
        else:
            emit_json(result, None)
        return 0

    lvl, load_diag = load_lvl(args.input)
    if lvl is None:
        emit_json(load_diag.to_json(), args.output)
        return 1

    if args.cmd == "lint":
        diag = lint_lvl(lvl)
        emit_json(diag.to_json(), args.output)
        return 0 if diag.ok else 1
    if args.cmd == "compile":
        compiled, diag = compile_lvl(lvl)
        if compiled is None:
            emit_json(diag.to_json(), args.output)
            return 1
        emit_json(compiled, args.output)
        return 0
    if args.cmd == "validate":
        result = validate_lvl(lvl)
        emit_json(result, args.output)
        return 0 if result.get("verdict") == "approved" else 1
    if args.cmd == "simulate":
        result = simulate_lvl(lvl, args.runs, args.profile)
        emit_json(result, args.output)
        return 0 if result.get("valid") else 1
    if args.cmd == "ascii":
        text = ascii_view(lvl) + "\n"
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(text, encoding="utf-8")
        else:
            print(text, end="")
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
