# 三消游戏开发规格（Godot 4.x / GDScript）

> 给 Claude Code 的执行文档。请**严格分阶段**实现，每阶段完成后可运行验证，再进入下一阶段。不要一次性生成所有代码。

## 项目概况

- 引擎：Godot 4.x，语言 GDScript
- 平台：竖屏手机（设计分辨率建议 1080×1920，stretch mode = canvas_items，aspect = keep_width）
- 玩法：Candy Crush 式三消，交换相邻两个棋子，3 个及以上同色连线消除
- 棋盘：**数据驱动，尺寸可变**（需支持 8×8、9×9、8×9、9×10 等）。棋盘行列数作为关卡参数传入，严禁硬编码尺寸。

## 素材位置

素材在桌面 7 个文件夹，导入时复制到 `res://assets/` 下对应子目录：

| 文件夹 | 内容 | res:// 目标 | 节点类型 | 混合模式 |
|---|---|---|---|---|
| `gem` | 6 种基础棋子 | `art/gems/base/` | Sprite2D | 普通 Alpha |
| `gem_shader` | 棋子高光/特殊棋子标记 | `match3/*.gdshader` | ShaderMaterial | 普通 Alpha |
| `barrier` | 障碍机关 | `assets/obstacles/` | Sprite2D | 普通 Alpha |
| `cell` | 棋盘格底 | `assets/board/` | TileMap 或循环 Sprite2D | 普通 Alpha |
| `ui_element` | UI 面板/按钮/图标 | `assets/ui/` | NinePatchRect（面板/框）/ TextureRect（图标） | 普通 Alpha |
| `avatar` | 萌宠技能头像 | `assets/avatars/` | TextureButton | 普通 Alpha |
| `boom` | 所有特效（白光/碎片/火花/烟雾/拖尾/光斑/冲击波） | `assets/fx/` | GPUParticles2D / Sprite2D | **Additive (BLEND_MODE_ADD)** |

**关键混合模式规则：**
- `boom` 里所有发光特效（白色图）→ 必须用 `CanvasItemMaterial.BLEND_MODE_ADD`，并用 `modulate` 染成对应棋子颜色。黑底已去背为透明。
- 碎片类（白色实体碎块）→ 普通 alpha，`modulate` 染色。
- 其余所有素材 → 普通 alpha 混合。

## 节点层级（场景结构）

主场景 `Level.tscn`，用 CanvasLayer 分层（layer 越大越靠上）：

```
Level (Node2D)
├── BackgroundLayer (CanvasLayer, layer=0)   全屏背景
├── BoardLayer (CanvasLayer, layer=1)        棋盘格底 + 金色外框(NinePatchRect)
├── GemLayer (CanvasLayer, layer=2)          棋子 + 障碍(Sprite2D 网格摆放)
├── FXLayer (CanvasLayer, layer=3)           特效(粒子/Sprite,播完销毁)
├── CharacterLayer (CanvasLayer, layer=4)    主角 + Boss + 血条
├── UILayer (CanvasLayer, layer=5)           顶部UI(标题/目标/金币/步数/星级)
└── SkillBar (CanvasLayer, layer=6)          底部4个技能头像
```

## 颜色染色表（全局常量）

```gdscript
const GEM_COLORS = {
    "red": Color(1.0, 0.24, 0.24), "blue": Color(0.31, 0.63, 1.0),
    "green": Color(0.3, 1.0, 0.4), "gold": Color(1.0, 0.78, 0.2),
    "purple": Color(0.7, 0.3, 1.0), "pink": Color(1.0, 0.4, 0.7),
}
```

---

## 分阶段实现（务必按顺序）

### 阶段 1：棋盘数据与渲染
- `Board` 类：二维数组存棋子类型，行列数构造时传入（数据驱动）。
- 渲染棋盘格底（cell 平铺）+ 棋子（6 色随机填充，无初始三连）。
- 棋子坐标：`pos = board_origin + Vector2(col, row) * CELL_SIZE`。
- **验证**：能显示一个无初始消除的随机棋盘，换关卡尺寸不报错。

### 阶段 2：交换与匹配检测
- 点击/拖拽交换相邻两格。
- 匹配检测：横向、纵向扫描 3+ 同色。
- 非法交换（交换后无消除）自动换回。
- **验证**：能交换、能检测三连。

### 阶段 3：消除与下落
- 消除匹配的棋子（缩放淡出 0.15s + Tween）。
- 上方棋子下落填空，顶部生成新棋子补满。
- 连锁检测（下落后产生的新匹配继续消除）。
- **验证**：完整消除-下落-补充-连锁循环跑通。

### 阶段 4：特效接入（用 boom 素材）
- 建 `EffectManager` 单例（autoload），暴露方法：
  - `spawn_shatter(pos, color)` — 碎片粒子（重力下落+旋转，染色）
  - `spawn_explosion(pos, color, power)` — 火花扩散（无重力，Additive）
  - `spawn_beam(dir, pos, color)` — 白光行列/十字光束（Additive，modulate）
  - `shake(intensity)` — 屏幕震动
- 消除时调用对应特效。普通三连用碎片，特殊棋子触发用火花+光束。
- **验证**：消除有碎裂、震动；行列消除有光束。

### 阶段 5：特殊棋子
- 4连→行/列消除棋子；5连/L/T→更强特殊棋子。
- 特殊棋子触发时用 boom 里的光束/爆炸特效。
- **验证**：能合成并触发特殊棋子。

### 阶段 6：UI 与关卡目标
- 顶部：关卡号、目标卡、步数、金币、星级（容器用 NinePatchRect，数字用 Label）。
- Boss 血条（NinePatchRect 框 + ProgressBar 填充）。
- 步数耗尽/达成目标 → 结算。
- **验证**：完整一关可玩：有目标、有步数、能通关/失败。

### 阶段 7：技能头像（底部栏）
- 4 个 avatar 做 TextureButton，点击放技能（提示/破障/大招/祝福）。
- 冷却条用 ProgressBar 叠在头像上。
- **验证**：点头像能触发对应技能效果。

---

## 通用要求

- 棋盘尺寸、目标、步数等全部走**关卡配置数据**（用 Resource 或字典），不硬编码。
- 特效逻辑集中在 EffectManager，不要散落在棋子脚本里。
- 容器型 UI 一律 NinePatchRect 并设 patch_margin；图标用 TextureRect；数字用 Label 叠加。
- 发光特效一律 Additive 混合 + modulate 染色。
- 每阶段产出可运行版本，不要跳阶段。
