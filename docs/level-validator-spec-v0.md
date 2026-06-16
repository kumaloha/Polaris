# 关卡验证器与玩家模拟器规格 v0

> 目标：把“关卡是否成立”从口头判断变成可运行报告。  
> v0 先服务 `.lvl` 可执行子集，不追求完美智能，只追求稳定暴露坏关、坏格式和明显错配。

---

## 1. Validator Stack

每个候选关卡输出一份 `reports/<level_id>.validation.json`。

```text
.lvl
  → Lint Validator
  → Compile Validator
  → Semantic Design Language Gate
  → Progression Rhythm Gate
  → Obstacle Composition Gate
  → Structural Validator
  → Taste Director Gate
  → Player Simulator Validator
  → Design Checklist Validator
  → Validation Report
```

六类 verdict：

| verdict | 含义 |
|---|---|
| `approved` | 可以进入人工手感评审 |
| `revise_minor` | 小改后可重跑 |
| `revise_semantic` | 原则语言不成立；命题/主角/因果/负空间需要重写 |
| `revise_progression` | 长期节奏契约不成立；机制生命周期/奖励资源/烦躁预算/难度带需要重写 |
| `revise_obstacle_composition` | 障碍构图不成立；母题/主障碍/动作方向/负空间/读序需要重写 |
| `revise_taste` | 结构可玩，但导演品味契约不成立；重写题眼/主角/情绪弧 |
| `revise_major` | 配方或布局错配，需要重做候选 |
| `reject` | 不应继续投入 |

---

## 2. 输入与输出

### 2.1 输入

```yaml
input:
  lvl_source: levels_src/level_001_base.lvl
  compiled_level: out/level_001_base.json
  profile_band: default_mid_skill
  run_config:
    metric_mode: stochastic
    runs_per_persona: 200
    attempts_cap: 10
    seed_start: 100000
```

### 2.2 输出骨架

```json
{
  "level_id": "level_001_base",
  "verdict": "revise_minor",
  "lint": {},
  "compile": {},
  "semantic": {},
  "progression": {},
  "obstacle_composition_gate": {},
  "structural": {},
  "taste": {},
  "player_simulator": {},
  "design_checklist": {},
  "recommendations": []
}
```

---

## 3. Lint Validator

检查 `.lvl` 本身是否可读、无歧义。

### 3.1 必检项

| check | fail code |
|---|---|
| JSON 可解析 | `E_PARSE_JSON` |
| 必填根字段存在 | `E_MISSING_FIELD` |
| board 尺寸等于 map.width/height | `E_BOARD_SIZE` |
| board token 合法 | `E_UNKNOWN_TOKEN` |
| 坐标在范围内 | `E_CELL_OUT_OF_RANGE` |
| overlay 不落在 hole 上 | `E_LAYER_ON_HOLE` |
| objective/objectives 不冲突 | `E_OBJECTIVE_CONFLICT` |
| design_claim.crack_path 存在 | `E_MISSING_CRACK_PATH` |
| level_design 根字段存在 | `E_MISSING_FIELD` |
| progression 根字段存在 | `E_MISSING_FIELD` |
| obstacle_composition 根字段存在 | `E_MISSING_FIELD` |
| director 根字段存在 | `E_MISSING_FIELD` |
| playable 模式无 unsupported 机制 | `E_UNSUPPORTED_*` |

### 3.2 输出

```json
{
  "valid": false,
  "errors": [
    {"code":"E_UNSUPPORTED_MECHANISM", "path":"mechanisms[0].type", "message":"star_circuit is design_only in v0"}
  ],
  "warnings": []
}
```

---

## 4. Compile Validator

检查 `.lvl` 是否能编译成 Godot Board schema。

### 4.1 Objective 映射检查

| design objective | required compiled state |
|---|---|
| `cleanse_marks` | `objectives[].type == CLEAR_JELLY` 且 `jelly` 非空 |
| `collect` | `COLLECT`，`species >= 0`，`target > 0` |
| `drop_relic` | `COLLECT_INGREDIENT`，`ing` 非空，`exits` 非空 |
| `clear_shells` | `CLEAR_BLOCKER`，`coat` 非空 |
| `clear_creep` | `CLEAR_CHOCO`，`choco` 非空 |
| `defuse_cores` | `DEFUSE_BOMB`，`bomb` 非空 |

### 4.2 Layer 维度检查

所有非空 layer 必须与 board 同尺寸：

- `jelly`
- `coat`
- `choco`
- `ing`
- `fx`
- `bomb`
- `cannon`
- `popcorn`
- `cake`
- `mystery`

### 4.3 输出

```json
{
  "valid": true,
  "compiled_fields": ["init_board", "jelly", "coat", "objectives"],
  "warnings": ["W_BOARD_HINT_EXPANDED: token m expanded to target_mark overlay"]
}
```

---

## 5. Structural Validator

目的：排除“不用模拟也明显坏”的关。

### 5.1 基础结构

| check | 意义 |
|---|---|
| playable cell count > 0 | 不是空关 |
| playable cell count >= 20 | 太小会不可控；教学例外 |
| legal move exists at start | 开局可玩 |
| no auto-win at start | 不进关即胜 |
| no impossible objective | 目标量不超过可达上限 |
| no unsupported topology | playable 模式必须可执行 |

### 5.2 Reachability 近似

v0 不做完整证明，做保守近似：

- 从非 hole、非永久 wall 的可玩格建立连通图。
- `target_mark` 必须至少邻接一个可玩格，或可被特殊宝石触达声明覆盖。
- `crystal_shell` 若完全包围目标，必须有至少一个可攻击边。
- `drop_relic` 必须存在到任一出口的垂直/近似路径。
- `spawner` 不能开局堵死唯一补给路径。
- 生成关主目标禁止 `collect/order_color`：不要把“某色棋子数量”当通关条件。

### 5.3 Supply 检查

| check | v0 判定 |
|---|---|
| `vertical_down` | 每个目标区上方或同区应有可补给路径 |
| `split_columns` | 每个目标列至少有独立可玩区 |
| permanent dead zone | 若目标在永久断供区，fail；若 design_claim 明确依赖特殊宝石，warning |
| early vertical dead zone | 前 20 关 playable_v0 中，任何可玩格若同列上方被 hole/wall 断开，fail |
| full supply seal | 晶壳/障碍不能整行封死下方补给，除非该关有明确的可读补给拓扑与教学 |

### 5.4 输出

```json
{
  "structural_valid": true,
  "move_exists": true,
  "auto_win": false,
  "target_reachability": "ok",
  "supply_flow": {
    "status": "ok",
    "warnings": []
  },
  "unsupported": []
}
```

---

## 6. Player Simulator Validator

目的：模拟“某类玩家多少次能过”，不是寻找最优解。

### 6.1 v0 personas

| persona | 说明 | 默认权重重点 |
|---|---|---|
| `random_baseline` | 随机合法步 | random |
| `visual_casual` | 选明显、近处、即时收益 | immediate_match, visual_target |
| `bottom_cascade` | 偏底部制造连锁 | bottom_bias, cascade_potential |
| `goal_focused` | 优先目标/障碍 | target_delta, blocker_delta |
| `special_builder` | 主动造特殊宝石 | special_creation, combo_potential |
| `mechanism_aware` | 理解本关机制 | mechanism_progress, crack_path |
| `frustrated_retry` | 失败后短视安全 | immediate_progress, low_risk |

### 6.2 冷启动 cohort prior

无行为数据时，用弱性别先验初始化 persona 权重。

```yaml
female_prior:
  visual_casual: 0.25
  goal_focused: 0.20
  bottom_cascade: 0.15
  special_builder: 0.12
  mechanism_aware: 0.10
  frustrated_retry: 0.13
  random_baseline: 0.05
  preferences:
    reward_feedback: high
    novelty: high
    frustration_tolerance: medium_low

male_prior:
  visual_casual: 0.12
  goal_focused: 0.18
  bottom_cascade: 0.12
  special_builder: 0.20
  mechanism_aware: 0.25
  frustrated_retry: 0.08
  random_baseline: 0.05
  preferences:
    challenge: high
    strategy_depth: high
    reward_feedback: medium
```

边界：

```text
gender_prior_weight <= 0.20
行为数据达到阈值后，真实行为权重覆盖 gender prior。
```

### 6.3 单步决策

每一步：

```text
Observe → Generate legal moves → Score moves → Choose with noise → Apply → Update local memory
```

候选 move 分数：

```text
score(move) =
  w_immediate_score       * immediate_score_delta
+ w_target                * target_progress_delta
+ w_blocker               * blocker_damage_delta
+ w_special               * special_creation_delta
+ w_mechanism             * mechanism_progress_delta
+ w_bottom                * bottom_position_bonus
+ w_cascade               * cascade_estimate
+ w_risk                  * risk_penalty
+ noise(persona)
```

v0 可以先不精确预测 cascade，只用简单近似：

- move 后直接消除数量。
- 是否在下半区。
- 是否产生 4/5 连。
- 是否破目标/障碍。
- 是否靠近 crack_path 当前阶段。

#### 6.3.1 v0 persona 权重表

所有分项先归一化到 `[0, 1]`，再按下表加权。`noise` 是每步加入的均匀噪声范围 `[-noise, +noise]`。

| persona | immediate | target | blocker | special | mechanism | bottom | cascade | risk_penalty | noise | lookahead |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| random_baseline | 0.10 | 0.05 | 0.05 | 0.00 | 0.00 | 0.05 | 0.05 | 0.00 | 0.70 | 1 |
| visual_casual | 0.30 | 0.22 | 0.12 | 0.06 | 0.08 | 0.12 | 0.10 | 0.05 | 0.25 | 1 |
| bottom_cascade | 0.22 | 0.12 | 0.08 | 0.08 | 0.05 | 0.25 | 0.20 | 0.04 | 0.22 | 1 |
| goal_focused | 0.18 | 0.34 | 0.18 | 0.07 | 0.13 | 0.04 | 0.06 | 0.06 | 0.16 | 1 |
| special_builder | 0.14 | 0.16 | 0.10 | 0.32 | 0.08 | 0.05 | 0.15 | 0.07 | 0.18 | 1 |
| mechanism_aware | 0.12 | 0.20 | 0.16 | 0.12 | 0.30 | 0.03 | 0.07 | 0.08 | 0.12 | 2 |
| frustrated_retry | 0.34 | 0.25 | 0.12 | 0.04 | 0.08 | 0.07 | 0.05 | 0.12 | 0.30 | 1 |

选择规则闭合为：

```text
1. 枚举所有合法 swap。
2. 对每个 swap 做 1-step 结算估计；mechanism_aware 可额外看一步最高后继收益。
3. total = weighted_sum + uniform_noise。
4. 80% 选择最高 total；20% 在 top-3 中按 softmax(total / 0.15) 抽样。
5. 如果连续失败重试，frustrated_retry 权重提高，mechanism_aware 权重降低，直到玩家真实数据覆盖。
```

这套规则不声称是聪明解法；它只负责稳定模拟“会犯错、会短视、但会被目标和机制吸引”的玩家。

### 6.4 尝试模型

一次“尝试”是一局完整模拟。`attempts_to_first_win` 不是单局通过率，而是：

```text
同一 persona / profile 对同一候选，以不同 seed 或 refill 随机性连续尝试，第一次胜利出现在第几局。
```

配置：

```yaml
attempts_cap: 10
runs_per_persona: 200
seed_policy: deterministic_sequence
```

输出：

- `attempts_to_first_win_p50`
- `attempts_to_first_win_p90`
- `simulated_pass_rate_at_1`
- `simulated_pass_rate_at_3`
- `simulated_pass_rate_at_5`

### 6.5 fail_reason 分类

失败时按优先级归因：

| fail_reason | 判定 |
|---|---|
| `bomb_exploded` | 倒计时失败 |
| `no_legal_move_loop` | 多次洗牌/无步异常 |
| `unreachable_target` | 结构验证已警告且目标未触达 |
| `missed_mechanism` | 关键机制未触发且目标进度低 |
| `low_target_progress` | 目标完成率低于 50% |
| `ran_out_after_activation` | 机制已触发但剩余目标多 |
| `too_many_leftovers` | 接近完成但尾盘磨 |
| `random_bad_luck` | 其他指标正常但失败 |

### 6.6 mechanism / crack path 事件

即使机制未进引擎，v0 对 engine-backed 机制也要记录近似事件：

| crack stage | v0 事件 |
|---|---|
| `read` | 开局目标/障碍是否在视觉焦点区；设计校验为主 |
| `access` | 首次破坏关键 `crystal_shell` / 首次触达目标区 |
| `activate` | 对 engine-backed 机制：首次清 gate、首次收 relic、首次拆 bomb；未来机制先 design_only |
| `payoff` | activation 后 3 步内目标进度/cascade 是否显著提高 |
| `convert` | payoff 后 objective progress 是否增长 |
| `finish` | 胜利 |

### 6.7 输出示例

```json
{
  "player_simulator_valid": true,
  "metric_mode": "stochastic",
  "target_profile": "female_prior_default_mid_skill",
  "runs_per_persona": 200,
  "attempts_to_first_win": {"p50": 2, "p90": 5},
  "simulated_pass_rate_at_1": 0.38,
  "simulated_pass_rate_at_3": 0.71,
  "avg_remaining_moves": 2.1,
  "mechanism_activation_rate": 0.74,
  "crack_path_completion_rate": 0.58,
  "aggregate_reshuffle_rate": 0.02,
  "aggregate_dead_board_rate": 0.01,
  "aggregate_no_progress_turn_rate": 0.31,
  "aggregate_luck_dependency_proxy": 0.94,
  "aggregate_annoyance_score": 0.28,
  "fail_reason_distribution": {
    "low_target_progress": 0.22,
    "missed_mechanism": 0.18,
    "too_many_leftovers": 0.09
  },
  "profile_fit_score": 0.82,
  "verdict": "approved"
}
```

---

## 7. Semantic Design Language Gate

`level_design` 是 `.lvl` 的上游原则语言源，先检查“这关是否成立”，再检查棋盘结构和求解指标。

| check | pass 条件 |
|---|---|
| `thesis_sentence_specific` | 单关命题是一句具体设计句，不是“目标完成/更难一点” |
| `one_protagonist_present` | 唯一主角机制存在于目标或棋盘层 |
| `mechanisms_have_roles` | 每个活跃机制都被声明为主角或配角 |
| `objective_has_semantic_role` | 通关目标对应机制进入主角/配角因果链 |
| `stage_function_complete` | 地图声明舞台功能、戏剧轴、焦点、阻力区、收益区、操作空间和补给逻辑 |
| `arc_turn_state_change` | 情绪弧有明确 turn，且 turn 是状态变化 |
| `readable_world_state_goal` | 目标是玩家可读的世界状态变化 |
| `negative_space_enforced` | 禁止项没有出现在实际目标/机制里 |
| `director_compiled_from_semantics` | `director` 主角与 `level_design` 主角一致 |
| `payoff_visible` | 爽点是可见的 signature moment |

`semantic.valid=false` 时，候选只能得到 `revise_semantic`，不进入玩家模拟选择。

---

## 8. Progression Rhythm Gate

`progression` 是“这关在长线运营里为什么存在”的机器契约。它不替代 `level_design`，而是检查：机制有没有生命周期位置、玩家有没有真实奖励资源、通过率之外是否控制烦躁、难度带是否服务前后节奏。

### 8.1 机器必检 progression gate

| check | pass 条件 |
|---|---|
| `required_fields_present` | `episode/mechanic_lifecycle/reward_budget/annoyance_budget/difficulty_rhythm` 全存在 |
| `episode_slot_and_role_present` | 关卡在 episode 中有明确 slot 和 arc_role |
| `primary_lifecycle_matches_protagonist` | `level_design.roles.protagonist.mechanism` 有对应 `role=primary` lifecycle 条目 |
| `design_mechanics_in_lifecycle` | 所有主角/配角机制都被纳入 lifecycle，不允许只在棋盘上暗中出现 |
| `lifecycle_phases_specific` | phase 是 `reveal_safe/practice_with_reward/spatial_variation/...` 这类具体设计阶段，不是泛泛而谈 |
| `reward_primitives_known` | reward_budget 只使用 v0 已知奖励原语：`line_h_gem/line_v_gem/burst_gem/color_bomb_gem` |
| `reward_primitives_present_on_board` | 要求的奖励原语真实出现在 `.lvl.overlays` |
| `reward_primitives_compile_to_fx` | 要求的奖励原语编译为非零 `compile.fx`，Godot 读取后保留 |
| `max_*_valid` | annoyance_budget 中 reshuffle/dead_board/no_progress/luck proxy 都是 `[0,1]` 数值 |
| `difficulty_rhythm_has_pass_band` | difficulty_rhythm 同时声明 rhythm shape 和目标首局通过率带 |

`progression.valid=false` 时，候选只能得到 `revise_progression`，不进入候选选择。

### 8.2 Progression 输出示例

```json
{
  "valid": false,
  "score": 75,
  "checks": {
    "primary_lifecycle_matches_protagonist": true,
    "reward_primitives_present_on_board": false,
    "reward_primitives_compile_to_fx": false,
    "difficulty_rhythm_has_pass_band": true
  },
  "errors": [
    {"code": "E_REWARD_NOT_PLACED", "path": "overlays", "message": "reward primitive(s) missing from overlays: ['line_v_gem']"}
  ],
  "warnings": []
}
```

---

## 9. Obstacle Composition Gate

`obstacle_composition` 把“障碍摆得美不美”收敛成可运行检查。它不判断截图审美，而是验证障碍是否服务设计目的：目标、障碍、解法能否形成清晰读序。

### 9.1 机器必检 obstacle gate

| check | pass 条件 |
|---|---|
| `required_fields_present` | `purpose/archetype/primary_blocker/focus_area/action_vector/read_order/negative_space/density/delete_test/theme_shape/beauty_rules` 全存在 |
| `archetype_known` | archetype 属于 v0 构图母题：`no_blocker_focus/gate/ring/lane/key_path/cage/funnel/split_lock/bridge` |
| `archetype_matches_purpose` | action_vector 与 archetype 匹配，例如 `gate + vertical`、`ring + burst`、`lane + transport_down` |
| `primary_blocker_present` | 需要主障碍的母题必须在 overlays 中真实放置 `primary_blocker` |
| `negative_space_ok` | playable 区减去主障碍后的比例不低于 `negative_space.min_ratio` |
| `no_uniform_wall` | 主障碍不能形成过宽/整行/整列封死的墙；gate 必须是短门而不是满屏墙 |
| `read_order_spatially_plausible` | `goal/blocker/solution` 或 `actor/blocker/exit` 的空间关系大致成立 |
| `beauty_rules_declared` | beauty_rules 非空，且阻挡型母题显式声明 `no_uniform_wall` |
| `delete_test_declared` | delete_test 说明删除障碍后为什么题眼消失 |

`obstacle_composition_gate.valid=false` 时，候选只能得到 `revise_obstacle_composition`。

### 9.2 Obstacle 输出示例

```json
{
  "valid": false,
  "score": 75,
  "checks": {
    "archetype_known": true,
    "primary_blocker_present": true,
    "negative_space_ok": true,
    "no_uniform_wall": false,
    "read_order_spatially_plausible": true
  },
  "errors": [
    {"code": "E_OBSTACLE_UNIFORM_WALL", "path": "overlays", "message": "primary blocker forms an over-wide or fully sealing wall"}
  ],
  "warnings": []
}
```

---

## 10. Taste Director / Design Checklist Validator

`director` 是机器可读的品味契约，用来拦住“流程背熟但没有主角/记忆点/留白”的关卡。AI/人仍可执行 checklist，但 v0 的 `validate` 已经会输出 `taste` gate。

### 10.1 机器必检 taste gate

| check | pass 条件 |
|---|---|
| `required_fields_present` | `intent/player_fantasy/protagonist/supporting_roles/emotional_arc/signature_moment/negative_space/four_in_one/anti_slop` 全存在 |
| `protagonist_present_on_board_or_objective` | 主角机制必须真的出现在 overlays/objective 里 |
| `objective_covered_by_director_roles` | 通关目标对应机制必须是 protagonist 或 supporting_roles |
| `active_layers_declared` | 所有活跃机制都被 director 解释，不允许暗中堆料 |
| `mechanism_budget_ok` | 活跃机制数不超过 `anti_slop.max_primary_mechanisms` |
| `forbidden_atoms_absent` | 不出现 director 禁用的目标/机制 |
| `no_color_order_goal` | 生成关不以某色棋子收集/订单作为主目标 |
| `emotional_arc_complete` | opening/friction/turn/payoff 四段都具体 |
| `four_in_one_complete` | play/visual/readability/theme 四位一体都具体 |
| `protagonist_language_aligned` | 文案与主角机制关键词对齐 |

`taste.valid=false` 时，结构再正确也只能得到 `revise_taste`。

### 10.2 人/AI checklist

| check | pass 条件 |
|---|---|
| `has_eye` | 能一句话说明题眼 |
| `eye_removal_effect` | 移除题眼后难度/体验明显变化 |
| `visual_play_alignment` | 视觉焦点就是玩法焦点 |
| `crack_path_exists` | Read/Access/Activate/Payoff/Convert/Finish 至少 4 阶段明确 |
| `not_pure_hp_wall` | 障碍不是纯堆血 |
| `role_match` | teaching/pressure/breather 等体验符合 role |
| `theme_supports_shape` | 魔法世界/萌宠表达服务形状，不只是贴皮 |
| `profile_variant_clear` | base/assisted/advanced 或 gender prior 变体差异明确 |

输出：

```json
{
  "design_checklist_valid": true,
  "checks": {
    "has_eye": "pass",
    "visual_play_alignment": "pass",
    "theme_supports_shape": "weak"
  },
  "issues": ["theme decoration too generic"],
  "verdict": "revise_minor"
}
```

---

## 11. Telemetry / Feedback Spec

上线后反馈系统最小事件。

### 11.1 Level attempt event

```json
{
  "event": "level_attempt_end",
  "player_id": "anon",
  "level_coordinate": 37,
  "level_instance_id": "level_037_female_prior_c02",
  "variant": "female_prior",
  "cohort": {
    "gender": "female",
    "age_band": "middle_age",
    "market": "US"
  },
  "result": "fail",
  "attempt_index": 3,
  "moves_used": 24,
  "moves_left": 0,
  "objective_progress_pct": 0.72,
  "target_touch_turn": 5,
  "mechanism_activation": {
    "crystal_shell_gate_opened": true,
    "activation_turn": 12
  },
  "pet_skill_used": false,
  "fail_reason": "too_many_leftovers",
  "quit_before_loss": false
}
```

### 11.2 Feedback diagnosis

| signal | diagnosis | action |
|---|---|---|
| high attempts + low target_touch | unreadable / too remote | improve focus, reduce first blocker |
| high attempts + low mechanism_activation | activation cost too high | reduce shell layers, add hint, add reward safety valve |
| high activation + low win | payoff too weak / tail grind | strengthen payoff, reduce leftovers |
| female cohort worse only | cold-start female variant under-serving freshness/feedback | more reward, clearer pet/magic feedback, lower frustration |
| male cohort worse only | cold-start male variant under-serving challenge/strategy | more strategy hooks, tighter but fair constraints |
| all cohorts worse | bad level, not cohort issue | revise recipe |

---

## 12. Validation thresholds v0

默认阈值；20 关验证后再校准。

通过率指标必须使用 **目标带**，不是只设最低线：低于目标带是太难，高于目标带是太简单。具体目标带优先读取 `.lvl` 的 `meta.target_pass_band` / `personalization.target_pass_band`；如果缺失，才回退到 role 默认带。

| metric | teaching | variation/breather | pressure | peak |
|---|---:|---:|---:|---:|
| `simulated_pass_rate_at_1` default band | 0.90-1.00 | 0.65-0.95 | 0.55-0.80 | 0.35-0.70 |
| `simulated_pass_rate_at_3` minimum | >= 0.95 | >= 0.80 | >= 0.60 | >= 0.50 |
| `attempts_to_first_win_p90` | <= 2 | <= 4 | <= 6 | <= 8 |
| `reshuffle_rate` | <= 0.05 | <= 0.08 | <= 0.10 | <= 0.12 |
| `aggregate_annoyance_score` | <= 0.22 | <= 0.35 | <= 0.45 | <= 0.55 |
| `mechanism_activation_rate` | >= 0.70 | >= 0.60 | >= 0.65 | >= 0.70 |
| `crack_path_completion_rate` | >= 0.50 | >= 0.45 | >= 0.55 | >= 0.60 |

---

## 13. 需要实现的工具

| tool | 输入 | 输出 |
|---|---|---|
| `tools/level_tool.py generate` | Level Coordinate 数据表 | `.lvl` strict JSON |
| `tools/level_tool.py generate-select` | Level Coordinate + profile | selected `.lvl` + selection report |
| `tools/level_tool.py lint` | `.lvl` strict JSON | lint JSON |
| `tools/level_tool.py compile` | `.lvl` strict JSON | compiled Godot level JSON |
| `tools/level_tool.py validate` | `.lvl` strict JSON | lint + compile + structural validation JSON |
| `tools/level_tool.py simulate` | `.lvl` strict JSON | v0 persona player-sim metrics |
| `tools/level_tool.py ascii` | `.lvl` strict JSON | human-readable board summary |
| future Godot renderer | compiled JSON | preview PNG |
| `telemetry_schema.json` | event | schema validation |

---

## 14. 当前需你确认

无强制阻塞。默认采用：

- 失败原因按规则归因，不先做 ML。
- 性别先验参与冷启动权重，但上限 0.20。
- v0 Player Simulator 用上表 1-step heuristic + noise；`mechanism_aware` 只允许 2-step，不做深搜索。
- 20 关阶段先用模拟指标对齐人工手感，再考虑线上反馈系统。
