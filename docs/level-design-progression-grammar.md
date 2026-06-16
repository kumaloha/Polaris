# 关卡进程语法 v0

> 目的：把从 Candy Crush 学到的长期关卡运营原则落成程序化契约。`level_design` 负责单关是否有题眼；`progression` 负责这关在 10/15/1000 关长跑里扮演什么角色。

---

## 1. 新流水线

### 1.1 竞品原则抽象

从 Candy Crush/开心消消乐拆出来的不是“果冻/巧克力/蜗牛这些名字”，而是以下可执行原则：

1. **目标要空间化**：玩家应该看见自己在改变哪些格子、哪条路径或哪个实体；不要回到“收某色/刷分”的抽象目标。
2. **机制要有生命周期**：首见要安全，随后练习、变奏、混合、压力、喘息；不能每关都像随机背流程。
3. **障碍必须制造选择**：好的障碍不是单纯堵路/堆 HP，而是改变路径、视线、补给或优先级，并能和奖励资源配套破解。
4. **奖励资源必须上棋盘**：线消、爆炸、连通机关、救援清屏等必须是真实 board resource，不是文案里的“爽点”。
5. **难度是通过率 + 烦躁度**：同样 60% 通过率，若 no-progress 太高、死局多、靠运气，就是坏难。
6. **长线靠节奏，不靠单关堆料**：新机制、旧机制复用、混合关、喘息关、finale 需要有运营节奏。

所以 v0 不直接照搬 Candy 的素材名，而是把这些原则编译进 `progression`、`reward_budget`、`annoyance_budget` 和 validator。

```text
progression grammar
  → level_design principles
  → .lvl board/overlays
  → compile fx/layers
  → structural + semantic + taste + progression validation
  → persona simulator(pass rate + annoyance)
  → generate-select 打回/接受
```

核心变化：不再只问“这一关能不能过、有没有一句命题”，还要问：

1. 这个机制处在生命周期哪一段？
2. 新机制首见是否安全、可读、能触发？
3. 玩家有没有真实棋盘资源来破解，而不是只有文案爽点？
4. 通过率以外，这关烦不烦、卡不卡、是否靠运气？
5. 它和前后关是否形成上升、回落、变奏、finale 的节奏？

---

## 2. `progression` 根字段

每个生成关必须带：

```json
"progression": {
  "episode": {
    "id": "first_spellbook_arc",
    "slot": 5,
    "arc_role": "blocker_reveal_with_tool"
  },
  "mechanic_lifecycle": [
    {"mechanic": "crystal_shell", "phase": "reveal_safe", "role": "primary", "is_new": true},
    {"mechanic": "target_mark", "phase": "known_goal_as_payoff", "role": "support", "is_new": false}
  ],
  "reward_budget": {
    "required": true,
    "primitives": ["line_v_gem"],
    "delivery": "preseeded_fx_overlay",
    "purpose": "give_the_player_a_real_board_resource_not_just_payoff_text"
  },
  "annoyance_budget": {
    "max_reshuffle_rate": 0.06,
    "max_dead_board_rate": 0.06,
    "max_no_progress_turn_rate": 0.40,
    "max_luck_dependency_proxy": 0.45
  },
  "difficulty_rhythm": {
    "shape": "new_mechanic_safe_test",
    "target_pass_band": [0.58, 0.80],
    "role": "pressure_lite"
  }
}
```

---

## 3. 机制生命周期

同一机制不能只出现一次。它要经历：

| phase | 用途 | 典型要求 |
|---|---|---|
| `reveal_safe` | 首见教学 | 单变量、低烦躁、几乎必能触发 |
| `practice_with_reward` | 安全练习 | 给线/炸/生成点等真实资源 |
| `spatial_variation` | 位置变奏 | 同机制换目标地理，不加新主机制 |
| `terrain_variation` | 水文变奏 | 用地图改变控制力路径 |
| `known_goal_as_payoff` | 已知目标当收益 | 配角目标不能抢主角 |
| `cleanup_breather` | 喘息爽关 | 低压力、减少尾盘磨 |
| `enclosure_pressure` | 压力变奏 | 难在配套，不靠 HP 堆叠 |
| `combine_with_gate` | 混合题 | 已教学机制之间形成因果链 |

硬规则：`level_design.roles.protagonist.mechanism` 必须有 `role=primary` 的 lifecycle 条目；所有配角机制也要出现在 lifecycle 里。

---

## 4. 奖励资源不是文案

Candy 的早期关卡会给条纹/包装/炮台等破局资源。Polaris v0 先支持最小 `fx` 奖励原语：

| primitive | Godot fx | 设计用途 |
|---|---:|---|
| `line_h_gem` | `SP_LINE_H` | 扫边、横向打开空间 |
| `line_v_gem` | `SP_LINE_V` | 打门、贯通上下游 |
| `burst_gem` | `SP_BOMB` | 破壳环、finale 爆点 |
| `color_bomb_gem` | `SP_COLORBOMB` | 后续高爽点/安全阀 |

如果 `reward_budget.required=true`，则 `.lvl.overlays` 必须放置对应 reward layer，compiler 必须输出非零 `fx`，Godot `LevelLibrary` 必须保留该 `fx`。

---

## 5. 烦躁度预算

通过率不是唯一难度。v0 模拟器输出以下代理指标：

| metric | 含义 |
|---|---|
| `aggregate_reshuffle_rate` | v0 先等于 dead-board 代理；后续接真实 reshuffle |
| `aggregate_dead_board_rate` | 无合法步/死局率 |
| `aggregate_no_progress_turn_rate` | 已走步数中没有目标/障碍/机制进展的比例 |
| `aggregate_luck_dependency_proxy` | `4p(1-p)`，通过率越接近 50% 随机波动越强 |
| `aggregate_annoyance_score` | 上述指标加权后的烦躁分，用于候选评分惩罚 |

原则：候选可以难，但不应“烦”。`generate-select` 评分会惩罚 annoyance。

---

## 6. 1-10 当前节奏骨架

| level | arc_role | rhythm | 机制重点 | 奖励资源 |
|---:|---|---|---|---|
| 1 | `goal_reveal` | `tutorial_floor` | 星尘首见 | 无 |
| 2 | `reward_tool_intro` | `safe_reward_lift` | 星尘边缘练习 | 横线宝石 |
| 3 | `spatial_reading` | `low_variation` | 星尘路径阅读 | 无 |
| 4 | `terrain_first_pressure` | `gentle_rise` | 下游水文 | 无 |
| 5 | `blocker_reveal_with_tool` | `new_mechanic_safe_test` | 晶壳门首见 | 竖线宝石 |
| 6 | `post_blocker_breather` | `breather_drop` | 晶壳清理喘息 | 无 |
| 7 | `supply_topology_variation` | `medium_reading_rise` | 分区补给 | 无 |
| 8 | `blocker_pressure_variation` | `short_pressure_peak` | 壳环围城 | 无 |
| 9 | `transport_reveal` | `tutorial_floor` | 迷路幼兽首见 | 无 |
| 10 | `episode_finale_mix` | `first_act_finale` | 幼兽 + 晶壳门 | 炸宝石 + 竖线宝石 |

这张表是生成器的输入，不是文案总结。
