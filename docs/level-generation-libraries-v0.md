# 关卡生成设计资产库 v0

> 目标：把“机制先于地图”的架构落成可选条目。  
> 本文只定义 v0 库；能直接编译的条目标 `playable_v0`，未来机制标 `design_only_v0`。

---

## 1. 总原则

1. 机制是主菜，地图服务机制。
2. 每个障碍/奖励机关必须说明：玩家读法、交互、空间语法、验证指标、反模式。
3. v0 先用现有引擎可执行机制做 20 关；原创机关先进入设计库，不进入 playable 编译。
4. 千人千面通过实例层参数调整，不改变同一关号的学习目标。

---

## 2. 支持状态

| status | 含义 |
|---|---|
| `playable_v0` | 可通过 `.lvl` 编译到现有 Board |
| `playable_proxy_v0` | 可用现有机制近似，但必须在报告中说明近似损失 |
| `design_only_v0` | 只可设计评审，不可导出可玩关 |
| `future_engine` | 需要新增引擎规则 |

---

## 3. 主题命名层：魔法世界 + 萌宠

引擎机制和设计表现分层：

```text
engine-backed mechanic = 规则能力
theme wrapper = 玩家看到、记住、愿意追的表达
```

默认命名原则：

1. 机制名可以保持稳定英文 id，便于工程。
2. 中文/玩家可见名必须服务魔法世界 + 萌宠。
3. 目标物、奖励机关、失败反馈优先人格化/宠物化，让玩家觉得“我在救它/护送它/帮它回家”，不是在处理抽象图标。
4. 不继承外部竞品名字。

### 3.1 v0 主题包装映射

| design id | 玩家可见名 | 玩家感受 | 引擎映射 |
|---|---|---|---|
| `target_mark` | 星尘印记 | 净化被污染的星光痕迹 | `jelly` |
| `crystal_shell` | 晶壳 | 打碎封住魔法的外壳 | `coat` |
| `creep_growth` | 暗藤蔓生 | 不处理会蔓延的暗藤/雾影 | `choco` |
| `spawner` | 星泉 / 暗泉 | 持续吐出宝石或压力源 | `cannon` |
| `timed_core` | 倒计时星核 | 必须及时稳定的魔法核心 | `bomb` |
| `drop_relic` | 迷路幼兽 | 护送迷路幼兽回到底部巢门 | `ing + exits` |
| `drop_exit` | 巢门 / 星门 | 幼兽回家的出口 | `exits` |
| `starlight_cub` | 星光幼兽 | 救出来后帮你清场 | future mechanism |
| `star_circuit` | 星轨回路 | 点亮两端，星光连线 | future mechanism |
| `route_companion` | 星路旅伴 | 陪伴/引导角色抵达终点 | future mechanism |
| `resonance_core` | 共鸣星核 | 喂能量后爆发 | future mechanism |

### 3.2 `drop_relic` 默认包装：迷路幼兽

```yaml
id: drop_relic
player_facing_name: 迷路幼兽
fantasy: "幼兽迷失在棋盘上，玩家通过清路让它一路掉到下方巢门。"
engine_mapping: ing + exits
visual_rule:
  start: 幼兽在上方/中部，必须一眼看出它会往下走
  path: 下方路径要可读，不能让玩家误以为要直接消掉幼兽
  exit: 底部巢门/星门要明显
emotional_payoff: "幼兽回家"
```

设计含义：这不是“收集材料”，而是“护送一个可爱的生命”。它天然契合萌宠主题，也能和未来宠物系统连接。

---

## 4. Eye Matrix v0

| id | objective | obstacle_mode | 核心问题 | 推荐地形 | v0 状态 |
|---|---|---|---|---|---|
| `cleanse_direct` | cleanse_marks | direct | 直接清目标 | open | playable_v0 |
| `cleanse_edge` | cleanse_marks | precision | 边角目标难触达 | edge_deadzone | playable_v0 |
| `cleanse_expedition` | cleanse_marks | expedition | 目标在下游/远端 | hourglass/bottleneck | playable_v0 |
| `cleanse_siege` | cleanse_marks | siege | 先破壳再清目标 | island/vault | playable_v0 |
| `collect_harvest` | collect | harvest | 大面积收集指定色 | open | playable_v0 |
| `drop_direct` | drop_relic | expedition | 护送迷路幼兽回到底部巢门 | open + exits | playable_v0 |
| `drop_bottleneck` | drop_relic | expedition | 迷路幼兽路径被瓶颈影响 | bottleneck | playable_v0 |
| `order_key_color` | order_color | key | 指定颜色收集/控制 | open/vault | playable_v0 subset |
| `cleanse_reveal` | cleanse_marks | reveal | 目标被晶壳覆盖 | fault/vault | playable_v0 |
| `cleanse_dynamic_light` | cleanse_marks | pressure | 蔓生给轻动态压力 | vault/open | playable_v0 but late |
| `reward_release` | cleanse_marks | reward | 先救奖励再清场 | open/vault | design_only_v0 |
| `relay_link` | cleanse_marks | chain | 激活端点连线 | fault/fork | design_only_v0 |

---

## 5. 障碍库 v0

### 5.1 `target_mark` / 目标印记

```yaml
id: target_mark
status: playable_v0
engine_layer: jelly
state_dynamics: static
category: objective_layer
player_read:
  first_reaction: "这些格子是我要净化的目标。"
interaction:
  cleared_by: [match_on_cell, special_hit]
  stacks: true
spatial_grammar:
  best_positions: [center_cluster, downstream_pool, edge_cluster]
  avoid: [uniform_full_board_spam]
metrics:
  - target_touch_timeline
  - target_progress_rate
  - leftover_targets_on_fail
anti_patterns:
  - "目标撒满全图，玩家不知道重点。"
  - "目标藏在不可触达死区。"
```

配套：

- 教学：open + center cluster。
- 变奏：edge_deadzone。
- 施压：bottleneck 下游池。

### 5.2 `crystal_shell` / 晶壳

```yaml
id: crystal_shell
status: playable_v0
engine_layer: coat
state_dynamics: static
category: blocker
player_read:
  first_reaction: "这是一层壳，先打掉才能继续。"
interaction:
  cleared_by: [adjacent_match, special_hit]
  blocks_supply: partial
  blocks_target_access: true
  hp_range_v0: [1, 2]
spatial_grammar:
  best_positions: [bottleneck_gate, island_wall, vault_ring, downstream_lid]
  avoid: [full_board_wall, no_access_ring]
metrics:
  - blocker_damage_timeline
  - activation/access_turn
  - difficulty_delta_when_removed
anti_patterns:
  - "纯堆血。"
  - "堵住唯一通路但不给制造特殊宝石空间。"
```

配套：

- 与 `target_mark`：目标覆盖/门控。
- 与 `drop_relic`：运输路径门。
- 与未来奖励机关：释放/激活成本。

### 5.3 `creep_growth` / 蔓生

```yaml
id: creep_growth
status: playable_v0
engine_layer: choco
state_dynamics: self_evolving
category: dynamic_pressure
player_read:
  first_reaction: "不处理会蔓延。"
interaction:
  grows_when: no_creep_cleared_this_move
  cleared_by: adjacent_match_or_special
spatial_grammar:
  best_positions: [side_patch, vault_corner, near_but_not_on_objective]
  avoid: [early_full_center, teaching_first_time_with_other_new_mechanic]
metrics:
  - creep_cells_over_time
  - creep_cleared_per_move
  - fail_reason_low_target_progress
anti_patterns:
  - "前 5 关使用。"
  - "与窄小地图叠加导致不可玩。"
```

引入建议：20 关验证包后半段轻测，不作为早期主机制。

### 5.4 `spawner` / 生成源

```yaml
id: spawner
status: playable_v0
engine_layer: cannon
state_dynamics: self_evolving
category: source_pressure
player_read:
  first_reaction: "这里会持续吐东西。"
interaction:
  spawn_timing: after_valid_move
  spawn_direction_v0: down
  spawn_type_v0: [gem, drop_relic]
spatial_grammar:
  best_positions: [top_gate, controlled_lane]
  avoid: [blocking_only_exit, too_many_sources]
metrics:
  - spawned_count
  - source_dependency_rate
  - dead_zone_duration
```

v0 谨慎使用；生成源容易把关卡从“题眼”变成“混乱”。

### 5.5 `timed_core` / 倒计时核心

```yaml
id: timed_core
status: playable_v0
engine_layer: bomb
state_dynamics: self_evolving
category: timer_pressure
player_read:
  first_reaction: "倒计时前必须拆掉。"
interaction:
  tick: after_valid_move
  fail_on_zero: true
  cleared_by: match_or_special
spatial_grammar:
  best_positions: [near_control_space, secondary_pressure]
  avoid: [first_time_with_complex_map, unreachable_corner]
metrics:
  - bomb_defused_rate
  - bomb_exploded_rate
  - turns_before_defuse
```

v0 只用于后段压力，不用于前 10 关核心教学。

### 5.6 `drop_relic` / 迷路幼兽

```yaml
id: drop_relic
status: playable_v0
engine_layer: ing + exits
state_dynamics: static
category: path_objective
player_read:
  first_reaction: "我要帮迷路幼兽回到巢门。"
interaction:
  moves_with_gravity: true
  collected_at: bottom_exit_cols
spatial_grammar:
  best_positions: [top_mid, above_bottleneck, split_paths]
  avoid: [no_exit_path, offscreen_exit_unclear]
metrics:
  - relic_drop_progress
  - exit_path_reachability
  - collected_count
  - stuck_turns
```

配套：

- open + exits：教学。
- bottleneck：路径规划。
- fork/split：后续分区变奏。

---

## 6. 奖励机关库 v0

### 6.1 v0 立场

奖励机关很重要，但当前引擎没有通用 `mechanisms` 执行系统。因此 v0 分两层：

1. **设计库先定义清楚**：用于 20 关纸面设计、未来开发。
2. **playable_v0 不直接使用**：除非用现有特殊宝石/障碍近似，并标 `playable_proxy_v0`。

### 6.2 `starlight_cub` / 星光幼兽

```yaml
id: starlight_cub
status: design_only_v0
family: release_helper
state_dynamics: static
activation:
  trigger: clear_surrounding_shell
payoff:
  type: clear_radius
  shape: radius_1_or_2
player_value: "先救它，后清场。"
spatial_grammar:
  best_positions: [center_cluster, behind_shell, near_target_pack]
metrics:
  - activation_rate
  - average_turn_to_activation
  - payoff_targets_cleared
engine_need:
  - mechanism_state_layer
  - activation_event
  - payoff_clear_effect
```

可玩近似：用预置特殊宝石或降低目标量模拟“救它后更爽”，但不能宣称已实现幼兽机制。

### 6.3 `star_circuit` / 星轨回路

```yaml
id: star_circuit
status: design_only_v0
family: relay_link
state_dynamics: static
activation:
  trigger: activate_two_endpoints
payoff:
  type: beam_clear
  shape: line_between_nodes
spatial_grammar:
  best_positions: [fault, fork, bottleneck, vault]
metrics:
  - endpoint_activation_rate
  - beam_value
  - player_path_confusion_rate
engine_need:
  - endpoint_state
  - path_between_nodes
  - beam_clear_resolution
```

### 6.4 `route_companion` / 星路旅伴

```yaml
id: route_companion
status: design_only_v0
family: path_actor
variants:
  lit_track:
    state_dynamics: static
  force_push:
    state_dynamics: actor_moving
  gate_release:
    state_dynamics: static
payoff:
  on_arrive: objective_progress_or_small_burst
spatial_grammar:
  best_positions: [fork, split_paths, gated_route]
metrics:
  - route_progress
  - arrival_rate
  - confusion_rate
engine_need:
  - actor_state
  - movement_rule
  - route_tiles
```

### 6.5 `resonance_core` / 共鸣核心

```yaml
id: resonance_core
status: design_only_v0
family: charge_burst
state_dynamics: static
activation:
  trigger: adjacent_match_or_special_hit
  charge_required: 3
payoff:
  type: burst_or_beam
spatial_grammar:
  best_positions: [target_ring, vault_center]
metrics:
  - charge_rate
  - burst_value
  - overpowered_rate
engine_need:
  - charge_counter
  - hit_event
  - payoff_effect
```

---

## 7. 特殊宝石库 v0

| id | engine fx | 生成方式 | 作用 | v0 状态 |
|---|---|---|---|---|
| `line_h` | `SP_LINE_H` | 4 连横/竖 | 清整行 | playable_v0 |
| `line_v` | `SP_LINE_V` | 4 连横/竖 | 清整列 | playable_v0 |
| `burst_gem` | `SP_BOMB` | T/L 形 | 清 3x3 | playable_v0 |
| `color_clear` | `SP_COLORBOMB` | 5 连 | 清某色/组合 | playable_v0 |

注意：当前 `level_library.gd` 读库后会重置 `fx`，所以“初盘预置特殊宝石”需要工具链或引擎补一层 `fx` 导入。自然生成/对局内生成是可玩的。

---

## 8. 地形库 v0

| sample | axes | 适合机制 | playable v0 |
|---|---|---|---|
| `open` | split 0.0 / path 0.2 / center | teaching, harvest, combo | ✅ |
| `edge_deadzone` | split 0.25 / path 0.65 / edge | edge target, precision | ✅ |
| `hourglass` | split 0.5 / path 0.7 / center | expedition, bottleneck gate | ✅ |
| `bottleneck` | split 0.6 / path 0.8 / center | shell gate, relic path | ✅ |
| `island` | split 0.7 / path 0.6 / center | siege | ✅ if reachable |
| `fault` | split 0.8 / path 0.5 / dual | relay/future, split | ⚠️ playable only as wall layout |
| `fork` | split 0.45 / path 0.5 / dual | split decisions | ✅ limited |
| `vault` | split 0.55 / path 0.55 / center | center shell/target/core | ✅ for shell/target |

地形红线：

- 不能只有好看形状，必须服务机制。
- 所有目标必须可触达或明确声明依赖特殊宝石。
- 新手/教学不使用高 split + 高 path 的组合。

---

## 9. Supply Topology v0

| topology | status | 用法 |
|---|---|---|
| `vertical_down` | playable_v0 | 默认 |
| `split_columns` | playable_v0_limited | 用 wall/hole 形成分列，但不跨区补给 |
| `cascade_chamber` | playable_proxy_v0 | 用垂直大房间近似 |
| `side_feed` | future_engine | 需要侧向补给 |
| `one_way_gate` | future_engine | 需要闸门补给 |
| `loop_feed` | future_engine | 需要路径补给 |
| `teleport_feed` | future_engine | 需要传送补给 |

---

## 10. 角色配方表 v0

### 10.1 role budgets

| role | new_mechanics | max_obstacle_types | colors | move_slack | reward_safety_valve |
|---|---:|---:|---:|---:|---|
| teaching | 1 | 1 | 4-5 | high | early/strong |
| variation | 0 | 1-2 | 5 | medium_high | optional |
| breather | 0 | 1 | 5 | high | strong |
| pressure | 0-1 | 2 | 5 | medium | optional/none |
| peak | 0 | 2-3 | 5-6 | low_medium | controlled |

### 10.2 profile variant knobs

| variant | moves | target_quantity | obstacle_layers | reward_safety_valve | mechanism_density |
|---|---:|---:|---:|---|---:|
| `base` | 0 | 0 | 0 | optional | normal |
| `assisted` | +2 to +4 | -10% to -20% | -1 where possible | early/strong | lower |
| `advanced` | -1 to -2 | +5% to +15% | +0 to +1 | none/controlled | higher |
| `female_prior` | +1 to +3 | -0% to -15% | -0 to -1 | early/clear | normal, high novelty |
| `male_prior` | -0 to -2 | +0% to +10% | +0 to +1 | none/controlled | higher strategy |

这些不是永久性别规则，只是无行为数据时的冷启动候选生成方向。

---

## 11. 20 关验证包 v0 库使用

| level | role | eye | playable mechanisms | variants |
|---:|---|---|---|---|
| 1 | teaching | cleanse_direct | target_mark | base, assisted |
| 2 | variation | cleanse_edge | target_mark | base, female_prior |
| 3 | teaching/breather | collect_harvest | collect | base |
| 4 | variation | cleanse_expedition_weak | target_mark | base, assisted |
| 5 | pressure_lite | crystal_shell_gate_practice | target_mark + crystal_shell | base, assisted, advanced |
| 6 | breather | collect_harvest | collect + open cascade | base, female_prior, male_prior |
| 7 | pressure | cleanse_expedition | target_mark | base, assisted, advanced |
| 8 | variation | cleanse_siege | target_mark + crystal_shell | base |
| 9 | teaching | drop_direct | drop_relic | base, assisted |
| 10 | pressure | drop_bottleneck | drop_relic + crystal_shell | base, advanced |
| 11 | pressure | split | target_mark | base, male_prior |
| 12 | variation | cleanse_reveal | target_mark + crystal_shell | base |
| 13 | teaching | timed/key light | timed_core or order_color | base |
| 14 | pressure | order_key_color | order_color + crystal_shell | base, male_prior |
| 15 | peak | cleanse_chain | target_mark + crystal_shell | base, assisted, advanced |
| 16 | breather | harvest | collect | base |
| 17 | pressure | dynamic_light | target_mark + creep_growth | base |
| 18 | variation | drop_split | drop_relic | base, advanced |
| 19 | pressure | precision | target_mark edge | base, assisted |
| 20 | peak | mixed_playable | target_mark + shell + relic/creep | base, assisted, advanced |

当前已落地的程序生成样本：

```text
python3 tools/level_tool.py generate --through 10 --out-dir levels_src

levels_src/level_001_base.lvl  cleanse_direct
levels_src/level_002_base.lvl  cleanse_edge
levels_src/level_003_base.lvl  collect_harvest
levels_src/level_004_base.lvl  cleanse_expedition_weak
levels_src/level_005_base.lvl  crystal_shell_gate_practice
levels_src/level_006_base.lvl  collect_harvest
levels_src/level_007_base.lvl  cleanse_expedition
levels_src/level_008_base.lvl  cleanse_siege
levels_src/level_009_base.lvl  drop_direct
levels_src/level_010_base.lvl  drop_bottleneck
```

---

## 12. 未来机制引入顺序

| range | mechanism | status now | unlock condition |
|---|---|---|---|
| 1-6 | target_mark / crystal_shell | playable_v0 | 20 关验证立即用 |
| 7-10 | drop_relic | playable_v0 | 工具链已支持底行 exits；20 关从第 9 关引入 |
| 11-15 | creep_growth / timed_core | playable_v0 but risky | Player Simulator 能解释失败原因后 |
| 16-20 | spawner | playable_v0 but risky | 结构验证能识别断供后 |
| 21+ | starlight_cub | design_only_v0 | 机制事件系统 |
| 30+ | star_circuit | design_only_v0 | endpoint + beam 系统 |
| 40+ | route_companion | design_only_v0 | actor movement 系统 |
| 50+ | resonance_core | design_only_v0 | charge/payoff 系统 |

---

## 13. 当前需你确认

无强制阻塞。默认采用：

- 20 关 playable 只用 engine-backed 机制。
- 原创奖励机关先作为设计库，不进入可玩编译。
- 至少 5 个代表关做 female_prior / male_prior 对照。
- 宠物技能只作为反馈/上下文字段，不参与 v0 机制库。
