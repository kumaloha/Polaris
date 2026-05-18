# 猎场 · 派对 → iOS 收件箱下钻 → 判 → 结局 设计（结构重定向 · 含结局文案打磨）

日期：2026-05-18
定位：**休闲鉴渣小游戏的取证前段重做**。本 spec 是 `2026-05-18-hunting-casual-spotter-design.zh.md` 的**取证前段重定向 + 结局文案打磨**，与之并存（鉴渣回合/好渣判定/明确不做清单继续生效），只替换"开天眼只甩一句"这段，并把结局裁定从 2 档生硬改成 4 档自洽。

soul 不变：冷高级、反乙女、她在上位、纯代码无美术、竖屏 1170×2532。

---

## 一句话

点开派对 → 一横排男人（手指移上去变亮）→ 点一个 → 他的 **iOS 短信式收件箱**（他对你的那段 + 他对每个别人那条，一条条 thread）→ 点进任意 thread 看气泡对话 → `鉴定他`：判 好/渣 + 选态度（拆穿/试探/走开）→ 一句冷台词正文 + 一行读准度裁定 → 回派对，那人标记 ✓/✗，`看穿 X / N` 计数（N = `Content.men().size()`，**不写死 36**，语料底线 ≥36 可涨）。

## 为什么改

现状鉴渣回合的取证段只甩 `others_chat[0]` 一句——"只有一条聊天记录"，单薄、不像在翻人手机。把它换成"派对里挑人 → 翻他整个手机"的三级下钻，取证厚度上来，鉴渣的"读"才立得住。判定/结局回合保留（鉴渣需要有输赢的结算），顺手把结局裁定行从生硬 2 档（"你看穿了/你被他骗了"，误伤好人时语义打架）改成自洽 4 档。

## 三个已敲定的边界

1. **数据深度**：先上结构、用现有数据，**不重写 36 人语料**。`chat`（他对你，2–3 来回）是真 thread；`others_chat` 每条发给不同的人、各一句 → 各成一个单气泡 thread（已知取舍，加厚以后再说）。
2. **男女**：只有男人可点；"男女"是随口，排里全是可偏可判的男人，无女性语料。
3. **判定保留**：翻完仍判 好/渣 + 选态度 → 结局 + 计数。

---

## 状态机（再次重写 `Godot/ui/Peek.gd`，`Peek.tscn` 不动）

```
party ──tap man──▶ inbox ──tap thread──▶ thread
  ▲                   │ ──"鉴定他"──▶ judge ──▶ ending ──next──▶ party
  └───────────────────┴──── back ──────────────┘
```

状态：`party | inbox | thread | judge | ending`。

- **party**：横排全部男人卡（`Content.men()`，现 ≥36；`UiKit.btn`，自带 hover/pressed 描边即"变亮"；触屏上等价于按下高亮，无真 hover 是平台事实，照实说）。顶部 `派对` 标题 + `看穿 X / N`（N=`Content.men().size()`）。已判过的卡带 ✓（读对）/✗（读错）角标，仍可重进重读；计数每人只记一次（重判不重复计）。tap → `inbox`。
- **inbox**：选中男人的 iOS 短信收件箱（竖向 `UiKit.scroll`）。**第 0 行 =「你」**（他演你的，`chat`，预览=最后一句截断）→ 一条 `PEEK_HINGE` 味的细分割线 → 其后每个 `others_chat` 收件人各一行（联系人名 = `to` 串，预览 = 该句截断，行右 `›`）。底部常驻 `鉴定他`。返回 → `party`。
- **thread**：iOS 气泡对话页（竖向 `UiKit.scroll`）。「你」thread：`chat` 渲成左右交替气泡（`from=="him"` 左/灰 `PANEL_2`，`from=="you"` 右/金 `ACCENT_SOFT`）；别人 thread：那一句一个他方（左）气泡。顶部联系人名。返回 → `inbox`。
- **judge**：复用现有 `好/渣` 二选 → `_ask_choice` → `拆穿/试探/走开` 三选 → `judge(guess, choice)`（沿用现 `Peek.gd` 逻辑，`_was_right=(guess==truth)`，对则 `correct` +1，但同一人重判不重复 +1）。
- **ending**：正文 = `Spotter.ending_key(真相,选择)` 取 6 模板之一套名字；裁定 = `Spotter.verdict_key(_was_right,真相)` 取 4 档之一。`next` → `party`。

## 数据映射（零语料改动，不碰刚锁的 36 人）

新增纯函数 `PeekChat.threads(man) -> Array`（PeekChat 是"玩家可见"边界，天然归它；**绝不含 `hidden_type`**，沿用 `peek` 的防御式 `man.get`）：

```
[ {contact:"你", kind:"you",   msgs: chat 的浅拷贝} ]
+ others_chat 顺序映射:
  {contact: 该条 "to", kind:"other", msgs:[{from:"him", text: 该条 "text"}]}
```

`others_chat[0]` 仍是最狠一句 → 它就是收件箱别人区第一行，语料"最狠一句在前"的不变量天然保留。空/缺字段安全（空 `chat` → 「你」thread `msgs` 为空但行仍在；空 `others_chat` → 只有「你」一行）。

## 结局文案（打磨锁定 · 两层模型）

正文走 `(真相 × 选择)`，裁定走 `(读对? × 真相)`，两层各说各的，不再打架。

**6 套正文模板**（key 不变，值重写；`%s` = 名字）：

| key | 矩阵格 | 文案 |
|---|---|---|
| `END_SCUM_EXPOSE` | 渣+拆穿·最爽 | `你把他对别人那句话念出来。%s 笑没了，话也接不上。你拿包，没等他想好怎么接。` |
| `END_SCUM_PROBE` | 渣+试探·看更清 | `你不动声色多问一句。%s 补的谎比原来那个还松。够了，看清了。` |
| `END_SCUM_LEAVE` | 渣+走开·干净的胜 | `你没解释，直接走。%s 还在拼哪一句露了底——你已经不在了。` |
| `END_GOOD_EXPOSE` | 好+拆穿·回旋镖 | `%s 没辩解，看了你一眼，走了。你赢了这场没人输的架，输的是他。` |
| `END_GOOD_PROBE` | 好+试探·中性偏好 | `你问得很细。%s 答得更细，没有一处要找补。是真的。` |
| `END_GOOD_LEAVE` | 好+走开·淡淡可惜 | `你走了。%s 没追，也没演。有些人，你回头才知道是真的。` |

**4 档裁定**（新增 key，无 `%s`，冷收）：

| key | 触发（`verdict_key(was_right,is_scum)`） | 文案 |
|---|---|---|
| `VERDICT_RIGHT_SCUM` | 读对 · 真渣 | `你看穿了他。` |
| `VERDICT_RIGHT_GOOD` | 读对 · 真好 | `你没看错人。` |
| `VERDICT_WRONG_SCUM` | 以为好 · 真渣 | `他在你眼皮底下过关了。` |
| `VERDICT_WRONG_GOOD` | 以为渣 · 真好 | `你错杀了一个真的。` |

`Spotter.verdict_key(was_right: bool, is_scum: bool) -> String`：`right&scum→RIGHT_SCUM`，`right&good→RIGHT_GOOD`，`!right&scum→WRONG_SCUM`，`!right&good→WRONG_GOOD`；绝不空，4 档互异，纯函数，绝不向 UI 暴露真相。结局屏颜色沿用 `T.ACCENT`(读对)/`T.DANGER`(读错)。

## UiKit 新增（极小、可复用）

- `hscroll(parent,x,y,w,h) -> Control`：`scroll()` 的横向孪生（横向 AUTO、纵向禁用、clip、同款冷高级细条）。派对横排需要它，现 UiKit 只有竖 `scroll`。
- `bubble(parent,x,y,w,text,mine: bool) -> Panel`：把 pivot 前 `Peek._section`（commit `c6d8cce~1`）里已验证的确定性气泡高度估算（按 `inner_w/BODY*1.6` 估行、行高 `BODY*1.4`、下限 120）抽成复用件；`mine` 决定底色/留白侧。

## Loc 新增 / 复用

新增：`PARTY_TITLE`(派对)、`PARTY_SUB`(点谁，翻谁的手机。)、`INBOX_JUDGE`(鉴定他)、`THREAD_YOU`(你)、`THREAD_BACK`(返回)、`MARK_RIGHT`(✓)、`MARK_WRONG`(✗) + 上表 4 个 `VERDICT_*`；6 个 `END_*` 就地改值（key 不变）。复用：`PEEK_HINGE`、`SPOT_GOOD/SPOT_SCUM/SPOT_EXPOSE/SPOT_PROBE/SPOT_LEAVE/SPOT_NEXT/SPOT_TALLY`。Loc 仅追加 + 6 处改值，不删不改其他行，无重复 key。

## 测试 / 冒烟

- `PeekChat.threads` 纯函数单测（`test_peek_chat.gd` 追加）：thread 数 = `others_chat.size()+1`；`threads[0].contact=="你"` 且 `msgs==chat`；别人 thread 单条且 `from=="him"`；返回任何层级 dict 都无 `hidden_type` 键；空 man 安全。
- `Spotter.verdict_key` 单测（`test_spotter.gd` 追加）：4 档全覆盖非空、映射精确、4 档互异；外加 Loc 键存在锁（Spotter 能吐的每个 `END_*`/`VERDICT_*` 必在 `Loc.ZH`，防改文案时 key 写歪静默回退英文）。
- `peek_ui_smoke.gd` 重写：开屏 `state=="party"` 且 `men>=36`（沿用底线，不写死）→ 点 0 号 → `inbox`，行数 = `others+1` → 点一个 thread → `thread`，气泡建出，`_walk_has_hidden_type(_layer)` 仍 0 → 返回 inbox → `鉴定他` → judge(读对) → `ending`，屏上含新正文+裁定串 → next → `party`，该人 ✓、`correct==1`。
- 全回归 `run_tests`（预期净增：threads + verdict + 锁，数随实现定，0 failures）；`play.gd` 末行 `Season close.`、`ui_smoke.gd` `HUB SMOKE OK ...` 不变（未受影响）；windowed `res://scenes/Peek.tscn` 跑一局，无 `SCRIPT ERROR`/parse ERROR。

## 明确不做（范围外）

语料加厚 / `others_chat` 改 schema（Q1 推迟，看到实物再议）、女性语料与女性判定（Q2）、每场只来若干人的子集策展 / 任何 RNG 抽人（**派对 = 全部男人确定性横排**）、复活 `PartyEncounter`/`SeasonFlow`/hub 外壳/两轴/Control/资产负债表/赛季。`Content.gd`、`Hub`/`play`/`ui_smoke`/`tuning`/`PartyEncounter`/`SeasonFlow`/`Peek.tscn`/`run_tests` 注册一律不碰。

本 spec 只锁"派对挑人 → 翻整个手机 → 判 → 自洽冷结局"这一段怎么走。结构先到位，踩在已锁的 36 人语料和现有零件上。
