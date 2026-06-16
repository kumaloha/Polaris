# 玩家上下文驱动的下一关导演流程 v0

> 目的：把当前“静态 Level Coordinate + cold-start persona”的生成方式，闭合为“读取玩家游玩上下文 → 推导节奏状态 → 产出下一关 Brief → 多候选验证/模拟/选择 → 记录已分配实例”的可执行流程。
>
> 范围：本文是设计与数据契约，不改引擎实现。字段命名必须和现有 `tools/level_tool.py generate-select`、`.lvl.progression`、`.lvl.personalization.persona_axes`、`.lvl.mechanism_specs` 对齐。

---

## 0. 核心规则

1. **同一关号不是同一棋盘**：`level_coordinate` 是学习/运营坐标；`assigned_level_instance` 才是玩家实际拿到的棋盘。
2. **玩家上下文覆盖冷启动先验**：`female_prior` / `male_prior` / `unknown` 只用于没有行为证据时的初始权重；一旦有 `PlayerContext`，下一关由行为上下文主导。
3. **下一关先出 Brief，再生成棋盘**：导演层只产出 `NextLevelBrief`；候选棋盘由 generator 按 Brief/coordinate 生成并经过验证。
4. **每次分配都要落库**：选中候选后必须记录 `assigned_instance`，避免同一玩家重复抽到未追踪的变体。
5. **通过率不是唯一目标**：候选必须同时检查通过率、剩余步、失败原因、机制触发率、烦躁预算和最近节奏。

---

## 1. 端到端流程

```text
输入：player_id + next_level_coordinate

1. load PlayerContext(player_id)
2. load LevelCoordinate(next_level_coordinate)
3. derive RhythmState(PlayerContext, LevelCoordinate)
4. build NextLevelBrief(LevelCoordinate, PlayerContext, RhythmState)
5. generate N candidates with profile/variant knobs
6. validate each candidate
7. simulate(candidate, persona mix + context profile)
8. select best candidate inside brief budgets
9. record assigned instance
10. return assigned .lvl / compiled Godot record
```

当前工具链对应关系：

```text
LevelCoordinate              -> tools/level_tool.py 内置 LEVEL_COORDINATES
candidate/profile knobs      -> --variant + --profile + candidate_tuning
validate                     -> tools/level_tool.py validate
simulate persona mix         -> tools/level_tool.py simulate --profile
select                       -> tools/level_tool.py generate-select
assigned instance record     -> 待代码化；本文定义字段
```

可执行命令形态：

```bash
python3 tools/level_tool.py generate-select \
  --level 5 \
  --variant female_prior \
  --profile female_prior \
  --candidates 16 \
  --runs 20 \
  --output levels_src/selected/level_005_p_anon_42.lvl \
  --report reports/selection/level_005_p_anon_42.selection.json
```

线上版本不得直接用性别作为长期 `--profile`；应由 `PlayerContext.context_profile` 映射为 `balanced` / `female_prior` / `male_prior` 或后续新增的行为 profile。

---

## 2. `PlayerContext` schema

`PlayerContext` 是下一关导演的唯一玩家输入。它不是人口标签表，而是“最近玩得怎么样、懂哪些机制、需要什么节奏”的状态快照。

### 2.0 Godot 本地 playtest 记录

本地测试阶段先不需要后端。Godot 结算时会写两个本地文件：

```text
user://playtest_sessions.jsonl   # 每局一行，保留完整测试事件流
user://player_context.json       # generate-next 可直接消费的最近上下文快照
```

记录时机：

```text
Level 结算
  → session_ended(result)
  → Session.bank(...)
  → PlaytestRecorder.record(...)
  → append playtest_sessions.jsonl
  → update player_context.json
```

最小用途：

```bash
python3 tools/level_tool.py generate-next \
  --context <Godot user://player_context.json 的实际路径> \
  --candidates 10 \
  --runs 20 \
  --output levels_src/selected/next.lvl \
  --report reports/selection/next.selection.json
```

`playtest_sessions.jsonl` 是审计账本；`player_context.json` 是下一关导演输入。

```json
{
  "player_id": "p_anon_42",
  "generated_at": "2026-06-16T00:00:00Z",
  "next_level_coordinate": 37,
  "cold_start_prior": {
    "prior": "female",
    "prior_weight": 0.08,
    "evidence_count": 12,
    "rule": "behavior_overrides_prior"
  },
  "played_levels": [
    {
      "level_coordinate": 34,
      "assigned_instance_id": "level_034_p_anon_42_c03",
      "variant": "base",
      "attempts": 1,
      "result": "pass",
      "moves_left_on_pass": 7,
      "fail_reasons": [],
      "mechanism_activation_rate": {
        "target_mark": 1.0,
        "crystal_shell": 0.0,
        "drop_relic": 0.0
      },
      "reward_payoff_rate": 0.62,
      "annoyance_score": 0.18,
      "rhythm_tag": "breather"
    },
    {
      "level_coordinate": 35,
      "assigned_instance_id": "level_035_p_anon_42_c05",
      "variant": "base",
      "attempts": 4,
      "result": "pass",
      "moves_left_on_pass": 1,
      "fail_reasons": ["low_target_progress", "mechanism_not_triggered"],
      "mechanism_activation_rate": {
        "target_mark": 0.72,
        "crystal_shell": 0.31,
        "drop_relic": 0.0
      },
      "reward_payoff_rate": 0.22,
      "annoyance_score": 0.57,
      "rhythm_tag": "pressure"
    }
  ],
  "recent_window": {
    "n": 5,
    "attempts_to_win": [1, 4, 2, 3, 1],
    "pass_fail": ["pass", "pass", "pass", "fail", "pass"],
    "avg_moves_left_on_pass": 2.4,
    "fail_reason_distribution": {
      "low_target_progress": 0.40,
      "mechanism_not_triggered": 0.25,
      "no_legal_move_loop": 0.05,
      "ran_out_of_moves_after_activation": 0.30
    },
    "mechanism_activation_rate": {
      "target_mark": 0.84,
      "crystal_shell": 0.44,
      "drop_relic": 0.18
    },
    "rhythm_tags": ["breather", "pressure", "variation", "pressure", "practice"],
    "satisfaction_proxy": {
      "reward_payoff_rate": 0.38,
      "cascade_score": 1.7,
      "quit_before_loss_rate": 0.0
    }
  },
  "persona_axes": {
    "novelty_bias": 0.58,
    "reward_bias": 0.63,
    "challenge_bias": 0.47,
    "strategy_bias": 0.51,
    "cuteness_bias": 0.70,
    "annoyance_tolerance": 0.36
  },
  "mechanism_literacy": {
    "target_mark": 0.86,
    "crystal_shell": 0.52,
    "drop_relic": 0.20,
    "creep_growth": 0.00,
    "spawner": 0.00,
    "timed_core": 0.00
  },
  "context_profile": {
    "tool_profile": "female_prior",
    "reason": "reward_bias high + annoyance_tolerance low; cold_start no longer decisive"
  }
}
```

### 2.1 必填字段

| 字段 | 必填 | 用途 | 当前对齐点 |
|---|---:|---|---|
| `played_levels[].level_coordinate` | 是 | 知道玩家实际经过哪些学习坐标 | `.lvl.meta.level_coordinate` |
| `played_levels[].assigned_instance_id` | 是 | 追踪真实发放棋盘 | 待代码化 |
| `attempts` | 是 | 判断卡关/过快 | `simulate` 的 pass rate 目标代理 |
| `result` | 是 | pass/fail 节奏判断 | selection report 待扩展 |
| `moves_left_on_pass` | pass 时必填 | 判断过松/压线 | `aggregate_avg_remaining_moves` |
| `fail_reasons` | fail 时必填 | 区分坏难原因 | `aggregate_fail_reason_distribution` |
| `mechanism_activation_rate` | 是 | 判断机制是否被理解/触发 | `aggregate_mechanism_activation_rate` |
| `recent_window.n` | 是 | 节奏推导窗口，默认 5 | 待代码化 |
| `recent_window.rhythm_tags` | 是 | 避免连续新机制/卡关/无爽点 | `.progression.difficulty_rhythm.shape` 映射 |
| `persona_axes` | 是 | 个性化偏好轴 | `.personalization.persona_axes` |
| `mechanism_literacy` | 是 | 机制掌握度 | `.mechanism_specs` + telemetry 待扩展 |

### 2.2 `persona_axes` 与当前工具字段

当前 `.lvl.personalization.persona_axes` 已有字段：

| axis | 取值 | 下一关导演用途 |
|---|---:|---|
| `novelty_bias` | 0..1 | 高：优先 variation；低：优先 practice/breather |
| `reward_bias` | 0..1 | 高：提高 `reward_budget`，要求可见安全阀 |
| `challenge_bias` | 0..1 | 高：允许 target band 下移，但不能越过烦躁预算 |
| `strategy_bias` | 0..1 | 高：允许更强路径/门/运输题眼 |
| `cuteness_bias` | 0..1 | 高：优先 drop_relic/萌宠反馈，但不能跳过学习顺序 |
| `annoyance_tolerance` | 0..1 | 低：压低 no-progress/死局/连续失败预算 |

规则：如果 `recent_window.evidence_count >= 3`，`persona_axes` 必须由行为更新；`cold_start_prior.prior_weight` 应下降到 `<= 0.10`。

---

## 3. `RhythmState` 推导

`RhythmState` 决定下一关应该是教学、练习、变奏、压力、喘息还是 finale。它由 `LevelCoordinate` 的运营意图和 `PlayerContext` 的近期体验共同决定。

### 3.1 状态枚举

| `RhythmState.kind` | 作用 | 典型 `.progression` 对齐 |
|---|---|---|
| `tutorial` | 新机制首见；必须安全、单变量 | `mechanic_lifecycle.phase=reveal_safe` |
| `practice` | 新机制后练习；允许轻奖励 | `practice_with_reward` / `cleanup_breather` |
| `variation` | 已知机制换空间/水文/目标位置 | `spatial_variation` / `terrain_variation` |
| `pressure` | 已知机制施压；可压线但必须公平 | `enclosure_pressure` / `combine_with_gate` |
| `breather` | 降烦躁、给爽点、恢复信心 | `difficulty_rhythm.shape=breather_drop` |
| `finale` | 一段机制组合小结；允许峰值但要有奖励预算 | `arc_role=episode_finale_mix` |

### 3.2 推导输入

```text
recent_attempts_avg        = avg(recent_window.attempts_to_win)
recent_fail_streak         = consecutive fail count
recent_hard_pass_count     = pass 且 moves_left_on_pass <= 1 的连续次数
recent_new_mechanic_count  = last N 中 is_new=true 的数量
recent_pressure_count      = rhythm_tags 中 pressure/finale 数量
recent_breather_count      = rhythm_tags 中 breather 数量
reward_drought_count       = 连续 reward_payoff_rate < 0.25 的关数
mechanism_gap[m]           = coordinate 需要 m，但 literacy[m] 低或 activation[m] 低
annoyance_over_budget      = recent annoyance_score > persona_axes.annoyance_tolerance
coordinate_arc_role        = LevelCoordinate/progression 计划角色
```

### 3.3 推导规则

按顺序执行，第一条命中即返回；所有规则必须写入 `RhythmState.reason_codes`。

| 优先级 | 条件 | 输出 | 强制调整 |
|---:|---|---|---|
| 1 | `coordinate_arc_role` 是新机制首见，且该机制未学过 | `tutorial` | 只允许 1 个新机制；`target_pass_band >= 0.90` |
| 2 | `recent_fail_streak >= 2` 或 `recent_hard_pass_count >= 2` | `breather` | 禁新机制；加奖励/步数；降低目标量/HP |
| 3 | `mechanism_gap[primary]` 高 | `practice` | 保持主机制；降低副机制；要求机制触发率目标 |
| 4 | `reward_drought_count >= 2` | `breather` | `reward_budget.required=true`，给可见 payoff |
| 5 | `recent_pressure_count >= 2` | `breather` 或 `variation` | 低烦躁玩家可 variation；否则 breather |
| 6 | coordinate 是 episode 终点，且最近无连续卡关 | `finale` | 允许混合，但必须有奖励预算 |
| 7 | 最近太顺：`attempts_avg <= 1.2` 且 `moves_left_avg >= 5` | `pressure` | 缩步数/目标上调；不得加未学新机制 |
| 8 | 默认 | `variation` | 复用已学机制换空间或水文 |

### 3.4 三条节奏红线

#### 避免连续新机制

```text
if last_2_levels contains is_new=true:
  NextLevelBrief.forbidden += ["new_primary_mechanism", "new_dynamic_system"]
  RhythmState.kind cannot be tutorial unless live-ops override
```

执行口径：`mechanic_lifecycle[].is_new=true` 不能连续两关出现，除非后续产品明确开活动特例。

#### 避免连续卡关

```text
if recent_fail_streak >= 2 or avg_attempts_to_win(last_3) >= 3:
  next kind = breather or practice
  target_pass_band.low >= 0.82
  annoyance_budget.max_no_progress_turn_rate <= 0.30
  forbidden += ["hard_by_moves_only", "extra_shell_hp", "new_support_mechanism"]
```

执行口径：玩家连续卡关后，下一关不能继续用 `pressure`/`finale` 施压，即使全局坐标表原本安排了压力。

#### 避免连续无爽点

```text
if reward_drought_count >= 2 or avg_cascade_score(last_3) < threshold:
  reward_budget.required = true
  reward_budget.primitives includes line_h_gem or line_v_gem or burst_gem
  signature_moment must mention visible payoff
```

执行口径：如果玩家最近没有明显奖励回报，下一关必须给真实棋盘奖励，不允许只在文案里写“爽”。

---

## 4. `NextLevelBrief` 输出

`NextLevelBrief` 是导演层给生成器/候选选择器的合同。它不直接描述每个格子，但必须足够约束候选。

```json
{
  "brief_id": "next_level_037_p_anon_42_20260616",
  "player_id": "p_anon_42",
  "source_level_coordinate": 37,
  "rhythm_state": {
    "kind": "practice",
    "reason_codes": ["mechanism_gap:crystal_shell", "recent_hard_pass_count:2"],
    "recent_window_n": 5
  },
  "protagonist_mechanism": "crystal_shell",
  "mechanism_lifecycle_phase": "practice_with_reward",
  "support_mechanisms": ["target_mark", "line_v_gem"],
  "target_pass_band": [0.82, 0.94],
  "target_attempts_to_first_win": [1.0, 2.0],
  "reward_budget": {
    "required": true,
    "primitives": ["line_v_gem"],
    "delivery": "preseeded_fx_overlay",
    "purpose": "ensure_crystal_gate_activation"
  },
  "annoyance_budget": {
    "max_reshuffle_rate": 0.03,
    "max_dead_board_rate": 0.03,
    "max_no_progress_turn_rate": 0.30,
    "max_luck_dependency_proxy": 0.35
  },
  "board_size": {
    "allowed": ["7x7", "9x9"],
    "preferred": "7x7",
    "reason": "practice_after_hard_pass"
  },
  "generation_knobs": {
    "variant_preference": "assisted",
    "tool_profile": "female_prior",
    "moves_delta_band": [1, 4],
    "target_multiplier_band": [0.80, 0.95],
    "shell_hp_delta_band": [-1, 0],
    "colors_delta_band": [0, 0]
  },
  "forbidden": [
    "new_primary_mechanism",
    "creep_growth",
    "spawner",
    "timed_core",
    "pure_color_collection",
    "hard_by_moves_only",
    "unreachable_supply_region"
  ],
  "selection_policy": {
    "min_mechanism_activation_rate": 0.70,
    "min_reward_payoff_rate": 0.35,
    "prefer_score_terms": ["inside_pass_band", "low_annoyance", "mechanism_activation", "cascade_payoff"],
    "reject_if": ["validation_not_approved", "pass_rate_outside_band", "annoyance_over_budget", "forbidden_mechanism_present"]
  }
}
```

### 4.1 字段定义

| 字段 | 必填 | 约束 |
|---|---:|---|
| `protagonist_mechanism` | 是 | 必须出现在 `.level_design.roles.protagonist.mechanism` 和 `.progression.mechanic_lifecycle[role=primary]` |
| `mechanism_lifecycle_phase` | 是 | 必须映射到 `.progression.mechanic_lifecycle[].phase` |
| `target_pass_band` | 是 | 必须覆盖 `.meta.target_pass_band` / `.personalization.target_pass_band` 的最终选择口径 |
| `reward_budget` | 是 | 对齐 `.progression.reward_budget`；required=true 时 `.overlays` 必须有对应 reward layer |
| `annoyance_budget` | 是 | 对齐 `.progression.annoyance_budget` 与 `simulate` aggregate 指标 |
| `board_size` | 是 | 约束 `TERRAIN_TEMPLATES`：当前 `7x7` / `9x9` |
| `forbidden` | 是 | 必须合并到 `.recipe.obstacle_lane.forbidden` / validator 禁令 |
| `generation_knobs` | 是 | 当前落到 `--variant`、`--profile`、`candidate_tuning`；细粒度 band 待代码化 |
| `selection_policy` | 是 | 约束 `generate-select` 的 reject/score 逻辑 |

### 4.2 `target_pass_band` 调整表

| RhythmState | 默认通过率区间 | 使用场景 |
|---|---:|---|
| `tutorial` | 0.90-1.00 | 新机制首见 |
| `practice` | 0.82-0.94 | 机制未理解、刚卡过 |
| `variation` | 0.68-0.88 | 换位置/水文但不强压 |
| `pressure` | 0.52-0.76 | 已知机制施压 |
| `breather` | 0.88-0.98 | 卡关后/无爽点后 |
| `finale` | 0.55-0.78 | 小结混合关 |

个人化修正：

```text
if annoyance_tolerance < 0.40: raise low/high by +0.04, cap high at 0.98
if challenge_bias > 0.70 and recent not stuck: lower low/high by -0.04, floor low at 0.45
if mechanism_literacy[primary] < 0.45: force tutorial/practice band
```

---

## 5. Candidate loop

### 5.1 生成 N 个候选

当前命令使用 `--candidates N` 触发 `candidate_tuning(candidate)`：

```text
candidate 0: baseline
candidate 1..N: moves_delta / target_multiplier / shell_hp_delta / colors_delta 外扩
```

下一步代码化后，`NextLevelBrief.generation_knobs` 应直接约束 candidate tuning，而不是只靠固定数组。

### 5.2 验证

每个候选必须先过：

```text
lint
compile
validate:
  structural
  semantic
  taste/director
  progression
  personalization
  mechanism_specs
```

拒绝条件：

```text
validation.verdict != approved
forbidden mechanism present
protagonist mismatch
reward_budget required but no reward overlay
mechanism_specs missing active atom
supply unreachable without declared exception
```

### 5.3 模拟：persona mix + context profile

当前 `simulate` 支持：

```text
--profile balanced
--profile female_prior
--profile male_prior
```

`PlayerContext.context_profile.tool_profile` 先映射到以上三种之一。后续应新增行为 profile，例如：

```text
reward_sensitive_low_annoyance
mechanism_learning
strategy_high_challenge
casual_recovery
```

模拟必须读取并输出：

| 指标 | 用途 | 当前字段 |
|---|---|---|
| 通过率 | 是否落在 Brief 难度带 | `aggregate_pass_rate_at_1` |
| 平均剩余步 | 是否太松/压线 | `aggregate_avg_remaining_moves` |
| 机制触发率 | 玩家是否真正用到主角机制 | `aggregate_mechanism_activation_rate` |
| cascade/爽点 | 是否有 payoff | `aggregate_cascade_score` |
| dead/reshuffle | 是否坏难 | `aggregate_dead_board_rate` / `aggregate_reshuffle_rate` |
| no-progress | 是否磨 | `aggregate_no_progress_turn_rate` |
| luck proxy | 是否靠运气 | `aggregate_luck_dependency_proxy` |
| fail reason | 用于下一次 PlayerContext | `aggregate_fail_reason_distribution` |

### 5.4 选择

选择逻辑：

```text
eligible = candidates where:
  validation approved
  pass_rate in target_pass_band
  aggregate_annoyance metrics within annoyance_budget
  aggregate_mechanism_activation_rate >= min_mechanism_activation_rate
  forbidden not present

score =
  closeness_to_target_band
  + mechanism_activation_bonus
  + reward/cascade_bonus
  - annoyance_penalty
  - over_easy_penalty

select max(score)
```

如果没有候选合格：

```text
if too_hard majority:
  widen assisted knobs: +moves, -target quantity, -shell hp, stronger reward
elif too_easy majority:
  tighten knobs: -moves, +target quantity, remove extra reward
elif validation failures:
  revise recipe / terrain / forbidden list
else:
  regenerate with larger N
```

### 5.5 记录 assigned instance

选中后写入不可丢失的分配记录：

```json
{
  "assignment_id": "assign_p_anon_42_level_037_20260616T000000Z",
  "player_id": "p_anon_42",
  "level_coordinate": 37,
  "assigned_instance_id": "level_037_assisted_c06",
  "selected_file": "levels_src/selected/level_037_p_anon_42.lvl",
  "variant": "assisted",
  "profile_used": "female_prior",
  "brief_id": "next_level_037_p_anon_42_20260616",
  "selection_report": "reports/selection/level_037_p_anon_42.selection.json",
  "selected_score": 94.2,
  "target_pass_band": [0.82, 0.94],
  "simulation_summary": {
    "aggregate_pass_rate_at_1": 0.88,
    "aggregate_avg_remaining_moves": 3.1,
    "aggregate_mechanism_activation_rate": 0.76,
    "aggregate_annoyance_score": 0.22
  },
  "locked_at": "2026-06-16T00:00:00Z",
  "status": "assigned"
}
```

规则：

- 玩家进入关卡前必须已有 assignment。
- 同一 `player_id + level_coordinate` 默认只能有一个 active assignment。
- 如果关卡热修，创建新 assignment version，不覆盖旧记录。
- 游玩结果回写到 `PlayerContext.played_levels[]`，作为下一关输入。

---

## 6. 与现有 `.lvl` 字段对齐

### 6.1 `progression`

`NextLevelBrief` 必须能落到：

```json
"progression": {
  "mechanic_lifecycle": [
    {"mechanic": "crystal_shell", "phase": "practice_with_reward", "role": "primary", "is_new": false}
  ],
  "reward_budget": {...},
  "annoyance_budget": {...},
  "difficulty_rhythm": {
    "shape": "practice_after_hard_pass",
    "target_pass_band": [0.82, 0.94],
    "role": "practice"
  }
}
```

### 6.2 `personalization.persona_axes`

`PlayerContext.persona_axes` 是 `.lvl.personalization.persona_axes` 的行为后验版本。当前生成器仍从 `VARIANT_RULES` 和 `PERSONA_AXES_BY_PRIOR` 写入；后续应允许 Brief 覆盖这些轴。

### 6.3 `mechanism_specs`

`mechanism_specs` 决定机制是否可用、能否混合、是否支持模拟/Godot：

- `protagonist_mechanism` 必须存在于 `mechanism_specs`。
- `support_mechanisms` 必须不在彼此 `forbidden_with` 中。
- `simulator_hook.supported` 必须为 true，才能进入自动选择。
- `godot_support.playable_v0` 必须为 true，才能发给玩家。

### 6.4 `generate-select`

当前 `generate-select` 已完成最小闭环：

```text
generate N
→ validate
→ simulate(profile mix)
→ reject outside pass band
→ score by pass band + activation + cascade - annoyance
→ output selected .lvl + selection report
```

缺口：它还没有直接读取 `PlayerContext` / `NextLevelBrief`，也没有写 `assigned_instance`。

---

## 7. 最小代码化任务清单

必须补的字段/模块：

1. `PlayerContext` 读写：保存 `played_levels`、`recent_window`、`persona_axes`、`mechanism_literacy`。
2. `RhythmState` 推导器：按本文 3.3 规则输出 `kind` 和 `reason_codes`。
3. `NextLevelBrief` schema：可 JSON 序列化，可被 generator/selector 读取。
4. Brief → generator knobs：把 `moves_delta_band`、`target_multiplier_band`、`shell_hp_delta_band`、`colors_delta_band` 接入候选生成。
5. Brief → `progression` 覆盖：允许 `target_pass_band`、`reward_budget`、`annoyance_budget`、`mechanic_lifecycle.phase` 由 Brief 写入 `.lvl`。
6. Context profile：新增行为 profile，替代长期使用 `female_prior` / `male_prior`。
7. Candidate report 扩展：在 selection report 中写入 Brief、RhythmState、reject reason 细分和预算违规字段。
8. Assigned instance store：记录 `player_id + level_coordinate -> selected instance`。
9. Telemetry 回写：将真实 attempts/pass/fail/moves_left/fail_reason/mechanism_activation/reward_payoff 写回 PlayerContext。
10. Validator 扩展：检查连续新机制、连续卡关后仍 pressure、连续无爽点后 reward_budget 缺失。

---

## 8. v0 验收标准

完成代码化后，以下链路必须可跑通：

```text
给定 player_id=p_anon_42 和 next_level_coordinate=5
→ 读 PlayerContext
→ 推导 RhythmState=practice/breather/tutorial 之一
→ 输出 NextLevelBrief
→ generate-select 生成并筛选 N 个候选
→ selection report 说明为什么选中
→ assigned_instance 记录落库
→ 玩家结果回写 PlayerContext
```

验收用例：

| 场景 | 输入信号 | 期望下一关 |
|---|---|---|
| 冷启动 | 无 played_levels | 用 cold-start prior 初始化，但 `prior_weight <= 0.20` |
| 连续卡关 | 最近 2 关 fail 或压线 | `breather` / `practice`，禁新机制，pass band 上调 |
| 机制未理解 | 主机制触发率低 | `practice_with_reward`，要求机制触发率达标 |
| 最近太顺 | 1 次过且剩余步多 | `pressure` / `variation`，不引入未学新机制 |
| 连续无爽点 | reward/cascade 低 | `reward_budget.required=true` |
| episode 终点 | 坐标为 finale 且未卡关 | `finale`，允许已学机制混合 |
