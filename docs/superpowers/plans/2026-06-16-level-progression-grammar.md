# Level Progression Grammar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Candy-style design principles executable by adding mechanism lifecycle, reward primitives, annoyance budgets, and rhythm validation to the level generator.

**Architecture:** Keep the change inside the existing `.lvl` pipeline. `tools/level_tool.py` generates a new `progression` contract and compiles simple reward primitives into the existing Godot `fx` layer. Validation adds a progression gate before simulator selection; Godot level loading preserves compiled `fx` so rewards are actually playable.

**Tech Stack:** Python stdlib (`unittest`, JSON tooling), existing Godot level runtime, generated `.lvl` JSON profile.

---

### Task 1: Progression Contract Tests

**Files:**
- Create: `tools/test_level_progression.py`

- [ ] Write tests that require every generated level 1-10 to contain `progression.episode`, `progression.mechanic_lifecycle`, `progression.reward_budget`, `progression.annoyance_budget`, and `progression.difficulty_rhythm`.
- [ ] Require the primary protagonist from `level_design.roles.protagonist.mechanism` to appear as a primary lifecycle entry.
- [ ] Require reward-bearing levels to compile non-zero `fx` cells.
- [ ] Require `validate_lvl()` to expose a `progression` gate and reject missing lifecycle metadata.
- [ ] Run `python3 -m unittest tools/test_level_progression.py` and observe failure before implementation.

### Task 2: Generator and Compiler Support

**Files:**
- Modify: `tools/level_tool.py`

- [ ] Add lifecycle/rhythm constants for early levels.
- [ ] Generate root `progression` metadata from level coordinate.
- [ ] Add reward overlay presets for `line_h_gem`, `line_v_gem`, `burst_gem`, and `color_bomb_gem`.
- [ ] Compile those layers into `fx` values matching Godot `MatchEngine` constants.
- [ ] Include `fx` in compiled JSON.

### Task 3: Progression Gate and Annoyance Metrics

**Files:**
- Modify: `tools/level_tool.py`

- [ ] Add `progression_validate_lvl()` with checks for lifecycle closure, reward resources, annoyance thresholds, and rhythm fields.
- [ ] Include the gate in `validate_lvl()` and use `revise_progression` when it fails.
- [ ] Extend simulator output with minimal annoyance proxies: `reshuffle_rate`, `dead_board_rate`, `no_progress_turn_rate`, `luck_dependency_proxy`, and `annoyance_score`.
- [ ] Adjust candidate score to penalize annoyance.

### Task 4: Godot Runtime Reads Reward FX

**Files:**
- Modify: `godot/core/level_library.gd`

- [ ] Read optional compiled `fx` grid from generated level JSON.
- [ ] Preserve blocker and ingredient occupancy after applying `fx`.

### Task 5: Docs and Regeneration

**Files:**
- Modify/Create docs for the executable contract.
- Regenerate: `levels_src/level_001_base.lvl` through `levels_src/level_010_base.lvl`, `levels_src/selected/*`, `godot/levels.generated.json`, and reports.

- [ ] Document that the new flow is `progression grammar -> level_design -> .lvl -> validation -> simulation`.
- [ ] Generate 1-10 base levels.
- [ ] Run unit tests, validation, simulator smoke, and Godot board smoke.
- [ ] Commit with Lore protocol and push the branch.
