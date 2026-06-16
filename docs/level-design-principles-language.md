# 单关设计原则语言 v0

> 目标：把“单关有品味”从散文判断，压缩成一套可程序化的设计语言。
> 本文不是 `.lvl` schema，也不是求解器算法；它是更上游的 **Level Design Language**。后续生成器应先生成/验证这套语言，再编译成 `.lvl`、`director`、board、overlays 和模拟指标。

---

## 0. 定位：先有原则语言，再有生成器

当前工具链已经能做：

```text
Level Coordinate → .lvl → validate → simulate → generated levels
```

但这还不能保证品味。它只能保证“结构可玩”和“通过率像样”。真正的顺序应该是：

```text
设计原则
  ↓
设计语义语言（本文）
  ↓
关卡生成约束
  ↓
.lvl / director / board / overlays
  ↓
结构验证 + 玩家模拟器
```

`director` 是这套语言编译后的一个字段，不是语言本身。语言必须能回答：

1. 这关为什么存在？
2. 谁是主角机制？
3. 地图如何服务主角？
4. 玩家如何从困惑走到转折？
5. 哪些内容必须禁止，防止生成器堆料？

---

## 1. 核心公理

### Axiom 1 · 单关是一句命题

一关不是“若干目标 + 若干障碍 + 若干步数”，而是一句玩家能感受到的命题。

```text
Level = Thesis + Stage + Friction + Turn + Payoff
```

好命题：

- “打开晶壳门，水文才恢复。”
- “清开脚下道路，就是护送迷路幼兽回家。”
- “先破壳环，才能拿到中心星尘宝库。”

坏命题：

- “清 9 个目标。”
- “这里有晶壳和星尘。”
- “这一关比上一关难一点。”

如果 `thesis` 不能一句话说清，生成器不应继续生成 board。

---

### Axiom 2 · 一关只能有一个主角机制

机制在单关内必须被类型化：

| role | 含义 | 规则 |
|---|---|---|
| `protagonist` | 主角机制，玩家本关主要理解/处理的对象 | 必须且只能有一个 |
| `support` | 配角机制，服务主角制造阻力或收益 | 必须有因果关系 |
| `reward` | 爽点/奖励，主角被破解后的反馈 | 不能抢主角 |
| `stage` | 舞台条件，如地形、掉落方向、出口 | 不应自称目标 |
| `noise` | 与命题无因果关系的内容 | 直接拒绝 |

关键规则：

```text
if mechanism does not support thesis:
    reject as noise
if more than one protagonist:
    reject as unfocused
```

---

### Axiom 3 · 地图是舞台，不是内容

地图不能先画完再塞目标。地图必须服务主角机制的表演。

地图语言应回答：

```yaml
stage:
  dramatic_axis: top_to_bottom_rescue
  focus_cell_group: center_gate
  friction_zone: gate_row
  payoff_zone: downstream_pool
  operation_space: upper_left_and_upper_right
```

而不是只写：

```yaml
terrain: bottleneck
```

`bottleneck` 只是形状名；真正有设计意义的是它在本关扮演什么舞台功能。

---

### Axiom 4 · 通关条件是世界状态变化，不是数量清单

玩家应该理解“我改变了这个世界”，而不是“我把计数器凑满了”。

优先使用：

```text
lost_cub reaches nest
crystal_gate opens
stardust pool cleansed
creep field contained
star circuit connected
```

禁止作为生成关主目标：

```text
collect N red gems
order N color gems
score only
```

数量可以是实现细节，但不能成为玩家感知到的主命题。

---

### Axiom 5 · 阻力必须逼出意图动作

障碍不是血量。阻力的职责是让玩家不能用无脑乱消绕过命题。

```text
Friction = blocks naive action + points toward intended action
```

例如第 5 关：

```text
naive action: 直接清下游星尘
friction: 晶壳门让下游补给不活
intended action: 先在门附近打开通路
```

如果阻力只是在拖时间，它是 HP wall，不是设计。

---

### Axiom 6 · 每关必须有一个转折点

没有转折点的关卡是流水账。

标准情绪弧：

```yaml
arc:
  opening: 玩家一眼看见问题
  friction: 直接做不顺
  turn: 玩家发现正确用力点，局面发生状态变化
  payoff: 状态变化产生可见爽点，并推进通关
```

`turn` 不是普通进度，而是局面语义改变：

- 门开了。
- 幼兽第一次下落了。
- 壳环破口了。
- 下游开始连锁了。

---

### Axiom 7 · 负空间是设计的一部分

生成器天然会堆料，所以语言必须显式声明“不放什么”。

```yaml
negative_space:
  no_second_primary_mechanism: true
  no_color_order_goal: true
  no_extra_dynamic_obstacle: true
  keep_operation_space: upper_board
```

不写负空间，等价于允许生成器把所有“看起来有趣”的东西都塞进来。

---

### Axiom 8 · 可读性必须三点对齐

玩家不该靠解释文字理解关卡。可读性来自三点对齐：

```text
HUD 目标 icon = 棋盘视觉焦点 = 玩法优先级
```

例子：

- 迷路幼兽目标：HUD icon 是幼兽，棋盘上也有幼兽，玩家行动是清幼兽下方。
- 晶壳门目标：视觉中心是门，玩家行动是破门，收益在门后。
- 星尘池目标：HUD 是星尘，棋盘焦点是星尘池，玩家行动围绕净化。

如果 HUD 只显示一个抽象头像，但棋盘上的对象不像它，玩家会觉得“看不懂条件”。

---

## 2. 设计语言语法草案

这是人和机器都能读的中间语言。它比 `.lvl` 更抽象，比普通文档更严格。

```yaml
level_design:
  id: level_005
  thesis: open_gate_restores_flow
  sentence: "打开晶壳门，水文才恢复。"

  roles:
    protagonist:
      mechanism: crystal_shell
      as: gate
    support:
      - mechanism: target_mark
        as: payoff
    reward:
      - cascade

  stage:
    shape: bottleneck
    dramatic_axis: top_to_bottom
    focus: center_gate
    friction_zone: center_gate
    payoff_zone: downstream_pool
    operation_space: upper_board
    supply_logic: gate_blocks_downstream_flow

  objective:
    world_state_change: stardust_pool_cleansed_after_gate_opens
    player_readable_goal: "先开门，再净化门后的星尘池。"

  arc:
    opening: see_gate_blocks_pool
    friction: direct_cleanup_is_inefficient
    turn: gate_breaks_and_flow_recovers
    payoff: downstream_cascade_cleanses_marks

  negative_space:
    forbid:
      - color_order_goal
      - second_primary_mechanism
      - unrelated_dynamic_obstacle
    preserve:
      - side_operation_space

  validation:
    must_have:
      - one_protagonist
      - causal_closure
      - visual_play_alignment
      - readable_world_state_goal
      - arc_turn_state_change
    reject_if:
      - generic_counter_goal
      - mechanism_without_role
      - payoff_disconnected_from_objective
      - full_supply_seal_without_topology_lesson
```

---

## 3. 类型系统

### 3.1 机制类型

```text
Mechanism =
  target_mark
  crystal_shell
  drop_relic
  creep_growth
  spawner
  timed_core
  route_actor
  reward_device
  special_gem
```

### 3.2 机制角色

```text
MechanismRole =
  protagonist
  support
  reward
  stage_modifier
  forbidden
```

约束：

```text
count(protagonist) == 1
support must have causal edge to protagonist or objective
reward must be downstream of turn
forbidden must not appear in generated .lvl
```

### 3.3 阻力类型

```text
Friction =
  distance        # 目标在远端/死水区
  gate            # 门/壳/锁改变通路
  enclosure       # 围城/壳环
  route_block     # 运输路径被挡
  spread_pressure # 自演化压力
  timer_pressure  # 时间压力
```

阻力必须声明：

```yaml
friction:
  blocks: naive_action
  invites: intended_action
  releases: payoff
```

### 3.4 舞台类型

```text
StageFunction =
  open_practice
  downstream_expedition
  gate_release
  vault_siege
  rescue_route
  split_supply
  side_feed
```

地形名不等于舞台功能。同一个 `bottleneck` 可以服务：

- 下游远征
- 晶壳门教学
- 幼兽护送

所以生成器应选择 `StageFunction`，再选择地形采样点。

---

## 4. 因果图：让机器判断“配套”

每关必须能形成一张闭合因果图：

```text
thesis
  → protagonist
  → friction
  → intended_action
  → turn_state_change
  → payoff
  → objective_progress
```

例：第 10 关。

```text
先开门再护送
  → protagonist: drop_relic 幼兽
  → support: crystal_shell 门
  → friction: 门挡住幼兽下落路线
  → intended_action: 先破门，再清幼兽下方
  → turn: 门开，路线连通
  → payoff: 幼兽连续下落
  → objective_progress: reaches nest
```

任何节点如果没有进入这条链，就是噪音。

机器可检规则：

```text
for each active mechanism:
    assert exists path(mechanism → objective_progress)

for each objective:
    assert caused_by(turn_state_change or protagonist_action)

for each payoff:
    assert visible and downstream_of(turn)
```

---

## 5. 生成器拒绝规则

这些不是建议，是硬拒绝。

| code | 拒绝原因 |
|---|---|
| `E_NO_THESIS` | 没有一句明确命题 |
| `E_MULTI_PROTAGONIST` | 多个主角机制 |
| `E_UNROLE_MECHANISM` | 有机制没角色 |
| `E_NO_CAUSAL_CLOSURE` | 机制/地图/目标之间没有因果闭环 |
| `E_COUNTER_OBJECTIVE` | 主目标是颜色/分数/数量清单 |
| `E_NO_TURN` | 没有状态转折点 |
| `E_PAYOFF_DISCONNECTED` | 爽点不推动目标 |
| `E_VISUAL_PLAY_MISMATCH` | 视觉焦点不是玩法焦点 |
| `E_UI_BOARD_MISMATCH` | HUD 目标和棋盘对象不一致 |
| `E_UNDECLARED_NOISE` | 出现负空间禁止的内容 |
| `E_SUPPLY_DEAD_ZONE` | 障碍/地形造成不可读断供或空白区 |

---

## 6. 第 5 / 9 / 10 关的原则语言示例

### Level 5 · 晶壳门

```yaml
thesis: open_gate_restores_flow
sentence: "打开晶壳门，水文才恢复。"
protagonist: crystal_shell as gate
support: target_mark as downstream_payoff
stage: gate_release on bottleneck
friction: gate_blocks_downstream_flow
turn: gate_breaks
payoff: downstream_cascade_cleanses_stardust
forbid: [drop_relic, creep_growth, spawner, color_order_goal]
```

判断：这关的主角不是星尘，而是晶壳门；星尘是门后的收益。

### Level 9 · 迷路幼兽教学

```yaml
thesis: clear_path_rescues_lost_cub
sentence: "清开脚下道路，就是护送迷路幼兽回家。"
protagonist: drop_relic as lost_cub
support: []
stage: rescue_route on vertical_axis
friction: cub_occupies_cell_and_needs_path_below
turn: cub_falls_first_step
payoff: cub_reaches_bottom_nest
forbid: [crystal_shell, target_mark, side_feed, color_order_goal]
```

判断：首次出现幼兽时，不要让玩家同时学晶壳/侧向掉落/星尘目标。

### Level 10 · 先开门再护送

```yaml
thesis: open_gate_then_rescue_cub
sentence: "先开门，再护送幼兽回家。"
protagonist: drop_relic as lost_cub
support:
  - crystal_shell as route_gate
stage: rescue_route_with_gate on vertical_axis
friction: gate_blocks_cub_route
turn: gate_breaks_and_route_connects
payoff: cub_falls_through_gate_to_nest
forbid: [target_mark, creep_growth, spawner, color_order_goal]
```

判断：晶壳是配角，因为它只服务幼兽路线；如果晶壳本身也变成目标，这关会分裂成双主角。

---

## 7. 从原则语言到程序

后续工程应分两层：

### 7.1 Semantic Validator

输入本文 DSL，输出语义诊断：

```json
{
  "valid": false,
  "errors": [
    {
      "code": "E_MULTI_PROTAGONIST",
      "message": "drop_relic and crystal_shell are both declared as protagonist"
    }
  ]
}
```

它不看棋盘格子，只看“设计是否成立”。

### 7.2 Level Compiler

语义通过后再编译到 `.lvl`：

```text
Level Design Language
  → director
  → recipe
  → map constraints
  → objective
  → overlays
  → .lvl
```

然后才进入已有：

```text
.lvl → lint/compile/validate → simulate → accept/retry
```

---

## 8. 和现有 `director` 的关系

`director` 是当前 `.lvl` 的机器可读品味字段。它应该由本文语言编译出来，而不是由生成器临时写散文。

映射关系：

| 本文语言 | `.lvl.director` |
|---|---|
| `thesis.sentence` | `intent` |
| `roles.protagonist` | `protagonist` |
| `roles.support` | `supporting_roles` |
| `arc` | `emotional_arc` |
| `payoff` | `signature_moment` |
| `negative_space` | `negative_space` + `anti_slop` |
| `stage` | `four_in_one.play/visual/readability/theme` |

原则：不要手写漂亮 `director` 来掩盖坏设计。先让原则语言通过，再生成 `director`。

---

## 9. 下一步

1. 把本文 DSL 固化成 JSON/YAML schema。
2. 为现有 1-10 关补一层 `level_design` 源，而不是只在 `.lvl` 里写 `director`。
3. 写 `semantic validate`：先检查命题/角色/因果图/负空间，再生成 `.lvl`。
4. 让 `generate-select` 的流程变成：

```text
generate semantic candidates
  → semantic validate
  → compile to .lvl
  → structural validate
  → player simulate
  → select
```

这才是“程序化地产生品味”，而不是让 AI 每次用脑子补散文。
