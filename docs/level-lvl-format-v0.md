# `.lvl` 中间格式 v0

> 目标：把关卡从“文档想法”变成“人能读、AI 能改、工具能编译、玩家模拟器能跑”的源文件格式。  
> 本文定义 v0 可执行子集；超出子集的机制必须显式标为 `design_only` 或编译失败。

---

## 1. 文件定位

`.lvl` 是关卡设计源文件，不是引擎最终格式。

```text
levels_src/level_001_base.lvl
  → python3 tools/level_tool.py compile
  → Godot levels.json record / Board schema
  → python3 tools/level_tool.py ascii/validate/simulate
```

原则：

1. `levels.json` 是导出物，不手写。
2. `.lvl` 保留设计语义：机制、题眼、玩家画像、破解路径。
3. 编译器负责把 Polaris 设计名映射到历史引擎字段。
4. v0 只编译引擎已支持机制；原创机关先进入 `design_only` 或 `unsupported` 队列。

---

## 2. 坐标与棋盘约定

### 2.1 坐标

`.lvl` 人类坐标统一使用：

```yaml
cell: [row, col]
```

- `row` 从 0 开始，自上而下。
- `col` 从 0 开始，自左而右。
- 编译到 Godot 时转换为 `Vector2i(col, row)`。
- 编译到二维数组时写入 `array[row][col]`。

### 2.2 board 字符宽度

v0 `board` 必须是 **单字符等宽网格**。多参数不要写进字符里，写进 `overlays`。

允许：

```text
ooooo
..ooo
```

不允许：

```text
B3oooo   # B3 是双字符，会破坏列对齐
```

炸弹倒计时、晶壳层数、生成源类型、迷路幼兽/出口等参数全部放入结构化区。

---

## 3. 根字段

v0 物理 `.lvl` 采用 **Strict JSON Profile**：扩展名仍为 `.lvl`，内容是标准 JSON object，不允许注释、尾逗号或 YAML 语法。原因是当前工具链与 Godot 侧已有 JSON 读取路径，先闭合执行，不把 YAML parser 作为新依赖。

难度节奏字段：

- `meta.target_pass_band`：该 Level Coordinate 的目标首局模拟通过率带；这是运营节奏契约。
- `personalization.target_pass_band`：该实例实际使用的目标带；v0 默认等于 `meta.target_pass_band`，未来可按画像微调。
- `level_intent.objective_verb`：目标动词；把 Candy 式清除/运输/制造/连接/解救/混合目标变成可枚举输入。
- `level_intent.skill_lesson`：玩家本关应该学会的具体技能和 proof signal，不允许只写机制名。
- `level_intent.board_scale`：棋盘大小与问题空间契约；新机制首见默认小棋盘/小问题空间。
- `progression.difficulty_rhythm.target_pass_band`：长线节奏语法中的同一目标带；必须与 `meta` 保持一致或给出 warning。
- `progression.mechanic_lifecycle`：机制生命周期位置；首见、练习、变奏、混合、压力、喘息必须显式声明。
- `progression.reward_budget`：真实棋盘奖励资源预算；若 `required=true`，必须有 overlay reward layer，并编译为非零 `fx`。
- `progression.annoyance_budget`：烦躁度预算；通过率之外还限制 dead board、no-progress、luck proxy 等。
- `obstacle_composition`：障碍构图契约；声明设计目的、构图母题、主障碍、动作方向、负空间、读序和 delete test，由 `Obstacle Composition Gate` 验证。
- 选择器必须拒绝低于下限的候选（太难）和高于上限的候选（太简单）。

可执行示例见：`levels_src/level_001_base.lvl`。最小形态如下：

```json
{
  "id": "level_001_base",
  "version": 0,
  "compile_mode": "playable",
  "meta": {
    "level_coordinate": 1,
    "variant": "base",
    "role": "teaching",
    "complexity_tier": 0,
    "theme": "forest_ruins",
    "target_pass_band": [0.92, 1.00]
  },
  "personalization": {
    "profile_band": "default_mid_skill",
    "cold_start_prior": "unknown",
    "prior_weight": 0.0,
    "target_pass_band": [0.92, 1.00],
    "target_attempts_to_first_win": [1.0, 1.5],
    "pet_skill_context": "ignored_v0"
  },
  "objective": {"type": "cleanse_marks", "target": "all"},
  "rules": {"moves": 16, "colors": 4, "refill": "random", "gravity": "down", "seed": 1001},
  "map": {
    "width": 7,
    "height": 7,
    "terrain": {"sample": "open"},
    "supply_topology": {"type": "vertical_down"}
  },
  "recipe": {
    "eye": "cleanse_direct",
    "obstacle_lane": {"focus": "target_mark", "stage": "teaching"},
    "mechanism_lane": {"focus": "none", "stage": "none"},
    "intended_control": "direct_match"
  },
  "board": [
    "ooooooo",
    "ooooooo",
    "ooooooo",
    "ooooooo",
    "ooooooo",
    "ooooooo",
    "ooooooo"
  ],
  "overlays": [
    {
      "region": "center_marks",
      "cells": [[2,2], [2,3], [2,4], [3,2], [3,3], [3,4]],
      "layers": ["target_mark"]
    }
  ],
  "mechanisms": [],
  "level_intent": {
    "objective_verb": "cleanse",
    "skill_lesson": {
      "skill": "match_on_target_cells",
      "proof_signal": "target_mark_progress_after_local_match"
    },
    "board_scale": {
      "size": "7x7",
      "effective_problem_space": "small",
      "reason": "first_target_reveal"
    }
  },
  "progression": {
    "episode": {"id": "first_spellbook_arc", "slot": 1, "arc_role": "goal_reveal"},
    "mechanic_lifecycle": [
      {"mechanic": "target_mark", "phase": "reveal_safe", "role": "primary", "is_new": true}
    ],
    "reward_budget": {"required": false, "primitives": [], "delivery": "natural_cascade_only"},
    "annoyance_budget": {
      "max_reshuffle_rate": 0.02,
      "max_dead_board_rate": 0.02,
      "max_no_progress_turn_rate": 0.28,
      "max_luck_dependency_proxy": 0.32
    },
    "difficulty_rhythm": {"shape": "tutorial_floor", "target_pass_band": [0.92, 1.00], "role": "teaching"}
  },
  "obstacle_composition": {
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
    "beauty_rules": ["single_core_question", "goal_solution_readable", "theme_shape_serves_play_shape"]
  },
  "level_design": {
    "thesis": {"key": "cleanse_first_stardust", "sentence": "擦亮中央星尘，理解净化就是通关。"},
    "roles": {"protagonist": {"mechanism": "target_mark", "as": "stardust_focus"}, "support": [], "reward": []},
    "stage": {
      "function": "open_practice",
      "dramatic_axis": "center_focus",
      "focus": "center_marks",
      "friction_zone": "center_marks",
      "payoff_zone": "center_marks",
      "operation_space": "whole_board",
      "supply_logic": "open_vertical_refill"
    },
    "objective": {"world_state_change": "center_stardust_cleansed", "player_readable_goal": "在中央星尘上做消除，把它们全部净化。"},
    "arc": {"opening": "中央星尘聚成小徽记。", "friction": "星尘不会自己消失。", "turn": "第一组星尘被净化。", "payoff": "中央徽记被擦亮。"},
    "payoff": {"signature": "中央星尘连续熄灭，像魔法书页被擦亮。"},
    "negative_space": {"forbid": ["collect", "order_color"], "preserve": ["whole_board_operation_space"]},
    "validation": {"must_have": ["one_protagonist", "causal_closure", "visual_play_alignment", "readable_world_state_goal", "arc_turn_state_change"]}
  },
  "design_claim": {
    "eye": "中心星尘印记教学。",
    "visual_focus": "中心目标区。",
    "intended_solution": ["直接在目标附近三消。"],
    "crack_path": ["read_target_marks", "access_center", "convert_matches_to_mark_progress", "finish_remaining_marks"],
    "climax": "中心连续消除后完成目标。"
  },
  "director": {
    "intent": "第一关只雕一个中心星尘焦点：玩家不是在消颜色，而是在擦亮遗迹的第一枚魔法印记。",
    "player_fantasy": "帮时兔点亮森林遗迹中央的星尘徽记。",
    "protagonist": "target_mark",
    "supporting_roles": [],
    "emotional_arc": {
      "opening": "目标都聚在中央，玩家一眼敢下手。",
      "friction": "星尘不会自动消失，必须在它身上或旁边做出有效三消。",
      "turn": "中心连消开始带走多枚印记，玩家理解净化规则。",
      "payoff": "中央徽记恢复干净，形成第一口小爽感。"
    },
    "signature_moment": "中央六枚星尘被连续净化，棋盘像被擦亮一块。",
    "negative_space": "边缘不放干扰，留白把视线和操作都推回中心。",
    "four_in_one": {
      "play": "近距离教学目标印记，不用额外障碍稀释规则。",
      "visual": "中心小花束构图，普通宝石作为背景。",
      "readability": "最亮的区域就是要净化的区域。",
      "theme": "森林遗迹第一次被魔法星尘点亮。"
    },
    "anti_slop": {
      "max_primary_mechanisms": 1,
      "forbidden": ["collect", "order_color"],
      "no_color_order_goal": true,
      "reject_if": ["generic_clear_list", "unreadable_icon_only", "mechanism_pileup"]
    }
  }
}
```

文档中的 YAML 代码块只作为字段说明/策划草稿；凡进入工具链的 `.lvl` 必须使用本 JSON Profile。

---

## 4. `compile_mode`

| compile_mode | 含义 | 允许内容 |
|---|---|---|
| `playable` | 必须能编译进现有 Godot Board | 只允许 v0 引擎支持机制 |
| `design_only` | 可作为设计草图/评审，不保证进入引擎 | 可出现未来机制，但必须标 `engine_status: unsupported_v0` |

默认是 `playable`。如果 `playable` 中出现 unsupported 机制，编译器必须失败，不允许静默忽略。

---

## 5. board token

| token | 设计含义 | 编译行为 |
|---|---|---|
| `.` | hole / 孔洞 | `init_board[row][col] = WALL(-2)` |
| `o` | random_gem / 随机宝石 | 由编译器按 seed 生成普通颜色 |
| `1`-`6` | fixed_gem_color | 固定颜色，`1 -> species 0` ... `6 -> species 5` |
| `~` | playable_hint | v0 编译同 `o`；仅作为人眼提示 |
| `m` | target_mark hint | 等价于 `o` + overlay `target_mark`，不推荐大量使用 |
| `s` | crystal_shell hint | 等价于 `o` + overlay `crystal_shell`，不推荐大量使用 |
| `v` | creep_growth hint | 等价于 `o` + overlay `creep_growth`，不推荐大量使用 |
| `n` | spawner hint | 等价于 `WALL` + overlay `spawner` |
| `b` | timed_core hint | 等价于 `o` + overlay `timed_core`，timer 写 overlays |
| `r` | drop_relic hint | 等价于 `o` + overlay `drop_relic` |
| `e` | exit hint | 等价于 `o` + exit marker |

建议：`board` 只写 `. / o / 1-6 / ~`，所有层写 `overlays`。这样可读性最高，冲突最少。

---

## 6. overlays 结构

### 6.1 cell overlay

```yaml
overlays:
  - cell: [3, 4]
    layers:
      - target_mark
      - crystal_shell
```

字符串层默认参数：

| layer | 默认参数 |
|---|---|
| `target_mark` | `hp: 1` |
| `crystal_shell` | `hp: 1` |
| `creep_growth` | `hp: 1` |
| `drop_relic` | `count: 1` |
| `timed_core` | `timer: rules.moves / 2`，不推荐省略 |
| `spawner` | `spawn: gem` |

### 6.2 参数化 layer

```yaml
overlays:
  - cell: [2, 3]
    layers:
      - target_mark
      - crystal_shell: { hp: 2 }
      - timed_core: { timer: 9 }
```

### 6.3 region overlay

```yaml
overlays:
  - region: downstream_marks
    cells: [[5,2], [5,3], [5,4], [6,2], [6,3], [6,4]]
    layers:
      - target_mark
```

### 6.4 exits

运输目标出口不写进 `objective`，写进 overlays 或 map：

```yaml
overlays:
  - region: bottom_exits
    cells: [[8,3], [8,4]]
    layers: [drop_exit]
```

编译为 `exits: [3,4]`。v0 只支持底行出口；非底行出口编译失败。

---

## 7. objective 映射

`.lvl` 使用 Polaris 设计名，编译器输出 Godot `objectives`。

| 设计 objective | 可执行状态 | Godot objective | 需要的层/字段 |
|---|---|---|---|
| `cleanse_marks` | playable | `CLEAR_JELLY` | `target_mark -> jelly` |
| `collect` | engine-supported / generator-forbidden-v0 | `COLLECT` | `species`, `target` |
| `drop_relic` | playable | `COLLECT_INGREDIENT` | `drop_relic -> ing`, `drop_exit -> exits` |
| `clear_shells` | playable | `CLEAR_BLOCKER` | `crystal_shell -> coat` |
| `clear_creep` | playable | `CLEAR_CHOCO` | `creep_growth -> choco` |
| `defuse_cores` | playable | `DEFUSE_BOMB` | `timed_core -> bomb` |
| `score` | playable | `SCORE` | `target_score` |
| `order_color` | engine-supported / generator-forbidden-v0 | `COLLECT` | color/species orders only |
| `order_special` | unsupported_v0 | — | 需要新增特殊宝石收集计数 |
| `activate_mechanism` | unsupported_v0 | — | 需要机制事件系统 |

### 7.1 `cleanse_marks`

```yaml
objective:
  type: cleanse_marks
  target: all
```

编译规则：

- 统计 `target_mark` 总 hp 作为 target。
- 输出：`{type:"CLEAR_JELLY", target:<sum>}`。
- 生成 `jelly[row][col] = hp`。

### 7.2 `drop_relic`

```yaml
objective:
  type: drop_relic
  target: 2
```

编译规则：

- 统计 `drop_relic` 个数，若 `target` 缺省则等于总数。
- 输出：`{type:"COLLECT_INGREDIENT", target:<n>}`。
- `drop_exit` 必须在底行，编译为 `exits`。

### 7.3 多目标

支持：

```yaml
objectives:
  - type: cleanse_marks
    target: all
  - type: clear_shells
    target: 6
```

如果同时出现 `objective` 和 `objectives`，编译器报错。

---

## 8. 机制支持矩阵

| 设计机制 | engine mapping | playable v0 | 说明 |
|---|---|---:|---|
| `target_mark` | `jelly` | ✅ | 目标印记 |
| `crystal_shell` | `coat` | ✅ | 晶壳/锁 |
| `creep_growth` | `choco` | ✅ | 蔓生动态障碍 |
| `spawner` | `cannon` | ✅ | 生成源；v0 只支持向下生成 |
| `timed_core` | `bomb` | ✅ | 倒计时核心 |
| `drop_relic` | `ing + exits` | ✅ | 迷路幼兽 |
| `line_h_gem` / `line_v_gem` / `burst_gem` / `color_bomb_gem` | `fx` | ✅/预置 | 作为 `reward_budget` 的真实棋盘资源；compiler 输出 `fx`，Godot `LevelLibrary` 保留 |
| `special_gems` | `fx` | 部分 | v0 支持预置奖励特效；完整生成/组合策略仍由后续求解器和引擎扩展 |
| `starlight_cub` | — | ❌ | 设计可写，playable 编译失败 |
| `star_circuit` | — | ❌ | 需要跨格机制事件系统 |
| `route_companion` | — | ❌ | 需要 actor state / movement |
| `resonance_core` | — | ❌ | 需要充能事件系统 |
| `star_nest` | — | ❌ | 需要奖励生成系统 |

---

## 9. supply_topology 支持矩阵

| topology | playable v0 | 编译行为 |
|---|---:|---|
| `vertical_down` | ✅ | 默认重力与 refill |
| `split_columns` | ✅/受限 | 通过 wall/hole 切分列；没有跨区补给 |
| `cascade_chamber` | ⚠️ | 仅可用普通垂直下落近似；必须 lint warning |
| `side_feed` | ❌ | 需要侧向补给规则 |
| `one_way_gate` | ❌ | 需要闸门开启后补给规则 |
| `loop_feed` | ❌ | 需要路径补给规则 |
| `teleport_feed` | ❌ | 需要传送补给规则 |

`playable` 模式下，除 `vertical_down` 和受限 `split_columns` 外，其余 topology 默认编译失败。若 `compile_mode: design_only`，允许保留在设计稿。

---

## 10. Compiler 输出 JSON

v0 编译到单关 JSON record：

```json
{
  "id": "level_001_base",
  "w": 7,
  "h": 7,
  "species": [0,1,2,3,4],
  "seed": 1001,
  "move_limit": 16,
  "target_score": 0,
  "objectives": [
    {"type":"CLEAR_JELLY", "species":-1, "target":6}
  ],
  "init_board": [[0,1,2,3,4,0,1]],
  "jelly": [],
  "coat": [],
  "choco": [],
  "ing": [],
  "exits": [],
  "fx": [],
  "bomb": [],
  "cannon": [],
  "popcorn": [],
  "cake": [],
  "mystery": []
}
```

空 layer 可以省略或输出 `[]`；推荐输出 `[]` 以方便 diff。

---

## 11. Lint 规则

编译前必须执行 lint：

1. `id`、`version`、`meta`、`rules`、`map`、`board` 必填；`meta.target_pass_band` 必填。
2. board 行数必须等于 `map.height`；每行列数必须等于 `map.width`。
3. cell 坐标必须在 board 范围内，不能落在 hole 上，除非 layer 是 `drop_exit`。
4. `playable` 模式禁止 unsupported 机制。
5. `objective` 与 `objectives` 不能同时出现。
6. objective 必须能映射到 Godot objective。
7. `cleanse_marks` 必须至少有一个 `target_mark`。
8. `drop_relic` 必须有至少一个 `drop_relic` 和一个底行 `drop_exit`。
9. `timed_core.timer` 必须大于 0 且小于等于 `rules.moves`。
10. `rules.gravity` v0 playable 只允许 `down`。
11. `rules.colors` 必须在 `[4,6]`；早期教学建议 4-5。
12. `design_claim.crack_path` 必填。
13. `level_intent` 必填，是外部原则进入关卡的语言源；必须声明 objective_verb、skill_lesson、board_scale。
14. `progression` 必填，是长期关卡节奏语言源；必须声明 episode、mechanic_lifecycle、reward_budget、annoyance_budget、difficulty_rhythm。
15. `obstacle_composition` 必填，是障碍构图语言源；必须声明 purpose、archetype、primary_blocker、action_vector、read_order、negative_space、delete_test、beauty_rules。
16. `level_design` 必填，是单关原则语言源；必须声明命题、主角机制、舞台、世界状态目标、情绪弧和负空间。
17. `director` 必填，并且要声明：主角机制、情绪弧、记忆点、负空间、四位一体、反堆料约束。

---

## 12. 编译失败示例

### 12.1 playable 中使用未来机关

```yaml
compile_mode: playable
mechanisms:
  - type: star_circuit
```

错误：

```text
E_UNSUPPORTED_MECHANISM: star_circuit is design_only in v0 engine.
```

### 12.2 侧向补给

```yaml
map:
  supply_topology:
    type: side_feed
```

错误：

```text
E_UNSUPPORTED_SUPPLY_TOPOLOGY: side_feed requires engine support.
```

---

## 13. 需要实现的工具接口

### 13.1 `tools/level_tool.py generate`

```text
python3 tools/level_tool.py generate --through 10 --out-dir levels_src
python3 tools/level_tool.py generate --level 5 --variant advanced --output levels_src/level_005_advanced.lvl
```

输出：

- strict JSON `.lvl` source
- 来自内置 Level Coordinate 数据表、地形模板和 placement preset

### 13.2 `tools/level_tool.py generate-select`

```text
python3 tools/level_tool.py generate-select \
  --level 5 \
  --profile female_prior \
  --candidates 8 \
  --runs 10 \
  --output levels_src/selected/level_005_female_prior_selected.lvl \
  --report reports/selection/level_005_female_prior.selection.json
```

流程：生成候选 `.lvl` → compile/validate → profile simulate → 不达标打回 → 选择最贴近目标难度带的候选。

### 13.3 `tools/level_tool.py compile`

```text
python3 tools/level_tool.py compile levels_src/level_001_base.lvl \
  --output out/level_001_base.json
```

输出：

- compiled JSON record
- lint diagnostics

### 13.4 `tools/level_tool.py ascii`

打印：

- 行列号
- board
- overlays summary
- objectives summary
- unsupported warnings

### 13.5 `tools/level_tool.py validate`

输入 `.lvl`，执行 lint/compile/structural v0 + `semantic` gate + `taste` gate，输出 validation JSON。`approved` 必须同时满足结构可玩、原则语言成立和导演品味契约。

### 13.6 `tools/level_tool.py simulate`

输入 `.lvl`，运行 v0 启发式 Player Simulator，输出 persona pass-rate / activation / fail-reason 指标。

### 13.7 Godot preview / future render wrapper

输入 compiled JSON，复用现有 `LevelLibrary` 与截图脚本输出 PNG；这一步依赖 Godot 渲染环境，不阻塞 `.lvl` 编译、结构验证与模拟验证。

---

## 14. 当前需你确认

无强制阻塞。默认采用：

- 坐标 `[row, col]`。
- v0 board 单字符等宽。
- v0 物理 `.lvl` 是 strict JSON；YAML 只作为文档说明。
- 未来原创机关在 `playable` 模式下编译失败，不做静默近似。
- 性别先验只作为 Player Profile 冷启动字段，不改变 `.lvl` 核心格式。
