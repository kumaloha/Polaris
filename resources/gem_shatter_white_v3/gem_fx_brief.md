# 宝石基础消除特效接入说明 (Godot 4.x)

> 交付对象:Claude Code。配套素材:`gem_shatter_white_v3/`(shatter_01–06,烟花式)。
> 仅覆盖**基础三消**的碎裂特效;特殊宝石消除已另行实现,本文档不涉及。
> 贴图为 512×512 透明 PNG,纯白 RGB + 亮度 alpha,已按爆心质心对齐,直接 modulate 染色,六色宝石通用。帧序列轮廓无关,水滴/心形/星形/方块/三叶草全部适用。

## 1. 播放序列(总时长 ~0.42s)

| t | 动作 | 实现 |
|---|---|---|
| 0.00 | 膨胀 | 宝石本体 `scale` 1.0→1.25,0.08s,TRANS_BACK EASE_OUT;同时 `self_modulate` 向白推(lerp 至 #FFFFFF 约 70%) |
| 0.08 | **崩(关键拍)** | 播 `shatter_01`(自带大闪光+裂纹)叠于本体之上;**下一渲染帧本体 `visible=false`**——切换藏在闪光底下,无需额外程序闪光 |
| 0.08–0.42 | 烟花飞散 | `shatter_02→06` 依次播完(15fps),不循环;**同步外扩**:FX 节点 `scale` 1.0→1.5,与播放等长,TRANS_QUAD EASE_OUT——碎片被连续推出,径向爆开感由此而来 |
| 0.42 | 结束 | 释放特效节点 |

## 2. 实现模板

```gdscript
# GemShatterFX.gd — 挂 AnimatedSprite2D
# SpriteFrames 资源建动画 "shatter"(6帧),fps=15,loop=false
func play(gem_color: Color, at: Vector2) -> void:
    global_position = at
    modulate = gem_color            # 白贴图 × 颜色 = 该宝石色碎片
    material = preload("res://fx/add_blend.material")  # blend_mode = ADD
    play("shatter")
    await animation_finished
    queue_free()
```

要点:
- **染色用 `modulate`,不改贴图**——一套白图服务全部 6 色
- **ADD 混合必开**,否则碎片发灰
- 颜色取宝石**主色饱和款**,不要取深色描边色(ADD 下深色没存在感)
- 连消并发:每次消除实例化独立 FX 节点,SpriteFrames 资源共享

## 3. 层级与时序约束

- FX 节点 z 序:棋子之上、UI 之下
- **棋盘下落补位在 t=0.08(崩那拍)即触发**,不等碎片播完——碎片飞散与棋子下落并行,跟手感全在这半拍
- 多连消时闪光**不叠加**:同 0.1s 窗口内只生效一次,否则连消糊屏

## 4. 验收清单

- [ ] 6 色宝石各消一次:碎片颜色正确、无灰边
- [ ] 水滴形宝石消除无轮廓突变(本体在 shatter_01 闪光下隐藏)
- [ ] 外扩 ramp 生效:碎片有持续向外的烟花感,而非原地播放
- [ ] 10+ 连消并发不掉帧、闪光不叠爆
- [ ] 碎片播放期间棋子已开始下落补位
