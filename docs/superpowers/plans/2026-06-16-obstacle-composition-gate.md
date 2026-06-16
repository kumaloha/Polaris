# Obstacle Composition Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the obstacle composition design spec into executable `.lvl` generation and validation for the first ten generated levels.

**Architecture:** Extend `tools/level_tool.py` with a small v0 composition catalog, generated root `obstacle_composition`, and a validator gate that checks required fields, primary blocker presence, archetype/purpose/action alignment, negative space, no-uniform-wall, and read-order plausibility. Add focused Python unit tests, regenerate `.lvl`/compiled JSON/reports, and keep Godot runtime unchanged except for existing generated data.

**Tech Stack:** Python stdlib `unittest` and JSON tooling, existing `.lvl` generator/validator, existing Godot generated level JSON.

---

### Task 1: RED tests for composition generation and validation

**Files:**
- Create: `tools/test_obstacle_composition.py`

- [ ] Add tests that generated levels 1-10 include `obstacle_composition` with required fields.
- [ ] Add tests that blocker levels declare a primary blocker and that the blocker is present in overlays.
- [ ] Add tests that `validate_lvl()` exposes `obstacle_composition_gate` and rejects missing composition with `revise_obstacle_composition`.
- [ ] Add tests for a bad uniform gate wall returning an obstacle-composition failure.
- [ ] Run `python3 -m unittest tools/test_obstacle_composition.py` and confirm failure before implementation.

### Task 2: Generate root obstacle composition

**Files:**
- Modify: `tools/level_tool.py`

- [ ] Add `EARLY_LEVEL_OBSTACLE_COMPOSITION` for levels 1-10.
- [ ] Add `generated_obstacle_composition(level, coord)`.
- [ ] Add root `obstacle_composition` in `generate_level()`.
- [ ] Ensure no-blocker levels use `archetype=no_blocker_focus` and `primary_blocker=none` so the contract remains explicit.

### Task 3: Validator gate

**Files:**
- Modify: `tools/level_tool.py`

- [ ] Add `obstacle_composition_validate_lvl(lvl, compiled=None)`.
- [ ] Check required fields: purpose/archetype/focus_area/action_vector/read_order/negative_space/density/delete_test/beauty_rules.
- [ ] Check primary blocker presence for blocker archetypes.
- [ ] Check purpose/archetype/action alignment using a v0 static mapping.
- [ ] Check negative-space min ratio against board playable cells not occupied by primary blockers.
- [ ] Check no-uniform-wall by rejecting full-row or full-column blocker seals for non-gate compositions and over-wide gate walls.
- [ ] Check read-order plausibility using blocker and objective layer centroids.
- [ ] Return score/errors/warnings/checks.

### Task 4: Wire verdict and reports

**Files:**
- Modify: `tools/level_tool.py`

- [ ] Include `obstacle_composition_gate` in `validate_lvl()` output.
- [ ] Add verdict `revise_obstacle_composition` after semantic/progression but before taste.
- [ ] Add recommendations from gate errors/warnings.
- [ ] Keep existing valid levels approved once composition is present.

### Task 5: Regenerate and verify

**Files:**
- Modify generated artifacts under `levels_src`, `out/levels`, `reports`, `godot/levels.generated.json`.

- [ ] Regenerate levels 1-10.
- [ ] Rebuild compiled Godot generated JSON and validation/simulation reports.
- [ ] Run `python3 -m unittest tools/test_obstacle_composition.py tools/test_level_progression.py`.
- [ ] Run validation loop for `levels_src/level_0*_base.lvl` and `levels_src/selected/*.lvl`.
- [ ] Run `godot --headless --path godot -s res://tests/runner.gd -- --only test_board`.
