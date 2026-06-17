# 龙幼崽技能动画 — Godot 接入说明（散帧版）

> 这份文档给 Claude Code 看。素材是 **64 张独立透明 PNG**（已抠图、已去水印），目标是在 Godot 里做成可播放的技能动画。

## 素材

- 文件夹 `dragon_frames/`，内含 **dragon_00.png ~ dragon_63.png**，共 **64 帧**。
- 每帧 **512×512**，**透明背景**（PNG alpha，已抠掉白底），**无水印**。
- 文件名编号即播放顺序（00 → 63）。
- 播放帧率：**8 fps**（整套技能约 8 秒）。

## 动画段落（帧索引，对应 dragon_XX.png 的 XX）

整套是一个连续技能动画。可整段播放，也可按段拆成多个动画：

| 段落 | 帧范围 | 含义 |
|------|--------|------|
| idle | 00–04 | 待命（可单独循环当待机） |
| blow | 05–11 | 自信张嘴大喷 |
| smoke | 12–16 | 冒出小缕烟 |
| ring | 17–24 | 烟圈成形 → 失败 |
| dazed | 25–33 | 呆滞尴尬定格 |
| refuse | 34–42 | 不服、龇牙 |
| charge | 43–52 | 鼓肚子蓄力 |
| success | 53–63 | 成功喷出（火焰特效在此段叠加，见下） |

## 接入方式：AnimatedSprite2D + SpriteFrames

### 编辑器手动（最简单）

1. 把 `dragon_frames/` 整个文件夹放进项目，如 `res://assets/dragon/dragon_frames/`。
2. 导入设置：每张 PNG 的 import 里建议关掉 **Filter**（像素清晰）或保留默认。
3. 新建场景，根节点 `AnimatedSprite2D`。
4. Inspector 新建 `SpriteFrames`：
   - 建动画 `skill`，把 dragon_00 ~ dragon_63 **按顺序全部拖进去**（一次多选拖入会按文件名排序）。
   - Speed = **8 FPS**，Loop = **关**。
   - （可选）再建 `idle` 动画，只放 dragon_00 ~ dragon_04，Speed = 6，Loop = **开**。

### 代码生成 SpriteFrames（适合让脚本自动加载）

```gdscript
extends AnimatedSprite2D

const FRAME_COUNT := 64
const FPS := 8.0
const PATH := "res://assets/dragon/dragon_frames/"

func _ready() -> void:
    var frames := SpriteFrames.new()

    # 完整技能动画
    frames.add_animation("skill")
    frames.set_animation_speed("skill", FPS)
    frames.set_animation_loop("skill", false)
    for i in FRAME_COUNT:
        var tex: Texture2D = load(PATH + "dragon_%02d.png" % i)
        frames.add_frame("skill", tex)

    # 待命循环（前5帧）
    frames.add_animation("idle")
    frames.set_animation_speed("idle", 6.0)
    frames.set_animation_loop("idle", true)
    for i in range(0, 5):
        frames.add_frame("idle", load(PATH + "dragon_%02d.png" % i))

    sprite_frames = frames
    play("idle")

func play_skill() -> void:
    play("skill")
    await animation_finished
    play("idle")
```

### 只播某一段（用帧范围）

如果想单独触发某段（比如只播 success），可以建对应区间的动画：

```gdscript
func add_segment(frames: SpriteFrames, name: String, start: int, end: int, loop: bool) -> void:
    frames.add_animation(name)
    frames.set_animation_speed(name, 8.0)
    frames.set_animation_loop(name, loop)
    for i in range(start, end + 1):
        frames.add_frame(name, load(PATH + "dragon_%02d.png" % i))

# 用法: add_segment(frames, "success", 53, 63, false)
```

## 火焰特效（重要）

success 段（帧 53–63）龙是**张嘴但没有火**的——火故意留空，作为独立特效层叠加，方便调大小/颜色/方向，且让幼崽（小火）→ 成年龙（大火）复用同一套龙动画。

接入建议：
- 在 success 段开始时（帧 53 附近）触发一个火焰特效（`GPUParticles2D` 或单独的火焰 SpriteFrames）。
- 位置：龙嘴在 512px 帧内约 (370, 200)（偏右上），方向朝 **右上 45°**。
- 幼崽是"只喷一点小火"，所以火焰特效做**小**；后续青年龙/大龙换大火特效即可。

## 缩放与定位

- 每帧 512×512，龙脚底（着地点）在帧内约 y=460。
- 在棋盘上定位时，以**脚底**为锚对齐格子，龙才会"站"在格子上（不要用图中心）。
- 龙脸朝右、技能朝右上释放，建议放在**棋盘左下区域**，火朝棋盘中心打。

## 文件清单

- `dragon_frames/` — 64 张透明 PNG（dragon_00 ~ dragon_63），核心素材
- `dragon_segments.json` — 各段落帧范围（供脚本读取）
- `dragon_final_v10.mp4` — 定稿视频，预览/留档用（非游戏素材）

> 备注：如果 Claude Code 那边更想要单张雪碧图而非散帧，也有 `dragon_sheet.png`（4096×4096，8×8 网格，同样已抠图去水印），二选一即可。
