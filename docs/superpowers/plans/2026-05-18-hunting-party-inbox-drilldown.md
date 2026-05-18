# 派对 → iOS 收件箱下钻 → 判 → 自洽冷结局 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把鉴渣取证前段从"开天眼只甩一句"重做成"派对横排挑人 → 翻他整个 iOS 短信式收件箱（他对你 thread + 他对每个别人单气泡 thread）→ 点进任意 thread 看气泡 → 鉴定他 → 判好/渣+态度 → 6 套正文 + 4 档读准度裁定 → 回派对计数"。

**Architecture:** 纯逻辑/数据先行，UI 最后。Task 1 加 `Spotter.verdict_key` + 重写 6 套结局文案 + 4 档裁定（纯+Loc，独立绿）。Task 2 加 `PeekChat.threads` 纯派生视图（独立绿）。Task 3 加 `UiKit.hscroll`/`UiKit.bubble` 两个可复用 UI 原件（不改行为，回归绿）。Task 4 把 `Peek.gd` 原地重写成 `party|inbox|thread|judge|ending` 五态机并重写冒烟。零语料改动，`Peek.tscn`/`Content.gd`/Hub/play/engine 不碰。

**Tech Stack:** Godot 4.6 GDScript。纯 `RefCounted`（Spotter/PeekChat/UiKit）+ UI `Node`（Peek）。Headless 测试 `tests/run_tests.gd`（`extends "res://tests/test_base.gd"`，断言 `eq/ok/ge`）。`godot` = `/opt/homebrew/bin/godot`。仓库根提交，在 `main`，**不 push**。

**Spec:** `docs/superpowers/specs/2026-05-18-hunting-party-inbox-drilldown-design.zh.md`（已锁）+ 并存的 `2026-05-18-hunting-casual-spotter-design.zh.md`。soul：冷高级、反乙女、她在上位、纯代码无美术、竖屏 1170×2532。`hidden_type` 绝不入 UI / 不入 PeekChat 返回。

**Baseline:** 当前 `RAN 77 tests, 0 failures`，`peek_ui_smoke` → `SPOT SMOKE OK men=36`。工作树净（仅未跟踪 `.claude/`）。

---

## File Structure

- **Modify** `Godot/core/Spotter.gd` — 追加纯函数 `verdict_key(was_right, is_scum) -> String`（镜像现有 `ending_key`；4 档互异、绝不空、绝不暴露真相）。
- **Modify** `Godot/ui/Loc.gd` — 就地改写 6 个 `END_*` 值（key 不变），追加 4 个 `VERDICT_*` + `PARTY_TITLE/PARTY_SUB/INBOX_JUDGE/THREAD_BACK/MARK_RIGHT/MARK_WRONG`。append-only + 6 处改值，不删不动其他行。
- **Modify** `Godot/core/PeekChat.gd` — 追加纯函数 `threads(man) -> Array`：`[{contact:"你",kind:"you",msgs:chat 深拷贝}]` + `others_chat` 顺序映射成 `{contact:to,kind:"other",msgs:[{from:"him",text}]}`。绝不含 `hidden_type`。
- **Modify** `Godot/ui/UiKit.gd` — 追加 `hscroll`（横向 `scroll` 孪生）+ `bubble`（复用 pivot 前 `Peek._section` 已验证的确定性气泡高度估算）。
- **Rewrite** `Godot/ui/Peek.gd` — 整文件替换为五态机。公开面（冒烟驱动）：`state`、`sel`、`thread_i`、`correct`、`judged`、`_layer`、`_man_now()`、`open_inbox(i)`、`open_thread(ti)`、`begin_judge()`、`back()`、`judge(is_scum_guess,choice)`、`next_round()`。
- **Rewrite** `Godot/peek_ui_smoke.gd` — 驱动 party→inbox→thread→back→judge→ending→next 全程，断言 thread 数、计数、`_layer` 永不渲染 `hidden_type/high_sugar`。
- **Modify** `Godot/tests/test_spotter.gd` — 追加 3 测试（verdict 覆盖 / verdict 映射 / Loc 键存在锁）。
- **Modify** `Godot/tests/test_peek_chat.gd` — 追加 5 测试（threads 形状/你优先/别人单气泡/不泄真相/空安全）。
- **Untouched:** `Godot/scenes/Peek.tscn`（仍 → `res://ui/Peek.gd`）、`Godot/core/Content.gd`（**零语料改写**）、`Godot/tests/run_tests.gd`（`test_spotter`/`test_peek_chat` 已注册）、`Hub/Faces/play/ui_smoke/tuning/Game.tscn/PartyEncounter/SeasonFlow/engine`。

**Out of scope（不做）：** `others_chat` 改 schema / 语料加厚、女性语料与判定、子集策展 / 任何 RNG 抽人（派对=全部男人确定性横排）、复活搁置系统。

---

### Task 1: `Spotter.verdict_key` + 重写 6 套结局 + 4 档裁定 Loc + 测试

**Files:**
- Modify: `Godot/core/Spotter.gd`
- Modify: `Godot/ui/Loc.gd`
- Test: `Godot/tests/test_spotter.gd`

- [ ] **Step 1: 跑基线。** Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -1`
Expected: `RAN 77 tests, 0 failures`

- [ ] **Step 2: 写失败测试。** 在 `Godot/tests/test_spotter.gd` 顶部把 const 段从

```gdscript
extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")
const Spotter := preload("res://core/Spotter.gd")
```

替换为

```gdscript
extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")
const Spotter := preload("res://core/Spotter.gd")
const Loc := preload("res://ui/Loc.gd")
```

再把文件末尾的

```gdscript
func test_ending_key_unknown_choice_safe() -> void:
	var k: String = Spotter.ending_key(true, "garbage")
	ok(k != "", "unknown choice still returns a non-empty key, no crash")
```

替换为（保留原函数，在其后追加 3 个）

```gdscript
func test_ending_key_unknown_choice_safe() -> void:
	var k: String = Spotter.ending_key(true, "garbage")
	ok(k != "", "unknown choice still returns a non-empty key, no crash")

func test_verdict_matrix_full_coverage() -> void:
	var keys := {}
	for was_right in [true, false]:
		for is_scum in [true, false]:
			var k: String = Spotter.verdict_key(was_right, is_scum)
			ok(k != "", "verdict key non-empty right=%s scum=%s" % [str(was_right), str(is_scum)])
			keys[k] = true
	eq(keys.size(), 4, "4 distinct verdict keys (读对? × 真相)")

func test_verdict_key_mapping() -> void:
	eq(Spotter.verdict_key(true, true), "VERDICT_RIGHT_SCUM", "读对·真渣")
	eq(Spotter.verdict_key(true, false), "VERDICT_RIGHT_GOOD", "读对·真好")
	eq(Spotter.verdict_key(false, true), "VERDICT_WRONG_SCUM", "以为好·真渣")
	eq(Spotter.verdict_key(false, false), "VERDICT_WRONG_GOOD", "以为渣·真好")

func test_every_spotter_key_has_zh() -> void:
	for is_scum in [true, false]:
		for ch in ["expose", "probe", "leave"]:
			var ek: String = Spotter.ending_key(is_scum, ch)
			ok(Loc.ZH.has(ek), "Loc.ZH has ending key %s" % ek)
	for was_right in [true, false]:
		for s2 in [true, false]:
			var vk: String = Spotter.verdict_key(was_right, s2)
			ok(Loc.ZH.has(vk), "Loc.ZH has verdict key %s" % vk)
```

- [ ] **Step 3: 跑测试，确认失败。** Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -8`
Expected: 有失败（`Spotter.verdict_key` 未定义导致解析/调用失败；且 `VERDICT_*` 尚不在 `Loc.ZH`）。

- [ ] **Step 4: 实现 `verdict_key`。** 在 `Godot/core/Spotter.gd`，把结尾两行

```gdscript
	var who := "SCUM" if is_scum else "GOOD"
	return "END_%s_%s" % [who, c.to_upper()]
```

替换为

```gdscript
	var who := "SCUM" if is_scum else "GOOD"
	return "END_%s_%s" % [who, c.to_upper()]

# (读对? × 真相) → 裁定 Loc key。绝不空,4 档互异,纯,绝不向 UI 暴露真相。
static func verdict_key(was_right: bool, is_scum: bool) -> String:
	var r := "RIGHT" if was_right else "WRONG"
	var who := "SCUM" if is_scum else "GOOD"
	return "VERDICT_%s_%s" % [r, who]
```

- [ ] **Step 5: 改写 Loc 文案 + 追加裁定/派对键。** 在 `Godot/ui/Loc.gd`，把这一整块（从 `"END_SCUM_EXPOSE":` 到收尾的 `}`，注意 TAB 缩进）

```gdscript
	"END_SCUM_EXPOSE":   "%s 当场破功，话都接不上。你拿起包，没回头。",
	"END_SCUM_PROBE":    "你不动声色多问一句，%s 自己把谎接圆不上了。看清了。",
	"END_SCUM_LEAVE":    "你没解释，直接走。%s 还在想哪句说错了。",
	"END_GOOD_EXPOSE":   "%s 沉默了一下，没辩解，走了。你拆穿了一个没装的人。",
	"END_GOOD_PROBE":    "%s 经得起问，答得很实。你看到的是真的。",
	"END_GOOD_LEAVE":    "你走了。%s 没追。有些人不会演，也不会求。",
}
```

替换为

```gdscript
	"END_SCUM_EXPOSE":   "你把他对别人那句话念出来。%s 笑没了，话也接不上。你拿包，没等他想好怎么接。",
	"END_SCUM_PROBE":    "你不动声色多问一句。%s 补的谎比原来那个还松。够了，看清了。",
	"END_SCUM_LEAVE":    "你没解释，直接走。%s 还在拼哪一句露了底——你已经不在了。",
	"END_GOOD_EXPOSE":   "%s 没辩解，看了你一眼，走了。你赢了这场没人输的架，输的是他。",
	"END_GOOD_PROBE":    "你问得很细。%s 答得更细，没有一处要找补。是真的。",
	"END_GOOD_LEAVE":    "你走了。%s 没追，也没演。有些人，你回头才知道是真的。",

	# ── 读准度裁定 (verdict · 4 档) ──────────────────────────────────────────
	"VERDICT_RIGHT_SCUM": "你看穿了他。",
	"VERDICT_RIGHT_GOOD": "你没看错人。",
	"VERDICT_WRONG_SCUM": "他在你眼皮底下过关了。",
	"VERDICT_WRONG_GOOD": "你错杀了一个真的。",

	# ── 派对 / 收件箱 / thread ───────────────────────────────────────────────
	"PARTY_TITLE":       "派对",
	"PARTY_SUB":         "点谁，翻谁的手机。",
	"INBOX_JUDGE":       "鉴定他",
	"THREAD_BACK":       "返回",
	"MARK_RIGHT":        "✓",
	"MARK_WRONG":        "✗",
}
```

- [ ] **Step 6: 跑测试，确认通过。** Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -2`
Expected: `RAN 80 tests, 0 failures`（77 + 3 新）。

- [ ] **Step 7: 提交。**

```bash
cd /Users/kuma/Projects/Polaris && git add Godot/core/Spotter.gd Godot/ui/Loc.gd Godot/tests/test_spotter.gd && git commit -m "$(cat <<'EOF'
feat(hunting): Spotter.verdict_key + 重写 6 套结局 + 4 档读准度裁定

正文走(真相×选择)6 模板,裁定走(读对?×真相)4 档,两层不再打架
(误伤好人→"你错杀了一个真的",不再生硬"你被他骗了")。Loc 键存在
锁防改文案时 key 写歪静默回退英文。77→80 tests green。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `PeekChat.threads` 纯派生视图 + 测试

**Files:**
- Modify: `Godot/core/PeekChat.gd`
- Test: `Godot/tests/test_peek_chat.gd`

- [ ] **Step 1: 写失败测试。** 在 `Godot/tests/test_peek_chat.gd` 末尾（最后一个函数 `test_corpus_size_locked` 之后）追加：

```gdscript

func test_threads_you_first_and_count() -> void:
	var m: Dictionary = _man("marcus")
	var th: Array = PeekChat.threads(m)
	eq(th.size(), (m["others_chat"] as Array).size() + 1, "threads = others_chat + 你 thread")
	eq(th[0]["contact"], "你", "thread[0] 是 你 thread")
	eq(th[0]["kind"], "you", "thread[0] kind = you")
	eq(str(th[0]["msgs"]), str(m["chat"]), "你 thread 携带他对你的 chat")

func test_threads_others_are_single_him_bubbles() -> void:
	var m: Dictionary = _man("evan")
	var th: Array = PeekChat.threads(m)
	ok(th.size() >= 2, "evan 有别人 thread")
	for i in range(1, th.size()):
		var t: Dictionary = th[i]
		eq(t["kind"], "other", "非 0 号是别人 thread")
		eq((t["msgs"] as Array).size(), 1, "别人 thread 现状单气泡")
		eq((t["msgs"][0] as Dictionary)["from"], "him", "别人气泡来自 him")

func test_threads_never_reveal_truth() -> void:
	for id in ["adrian", "evan", "marcus", "owen", "caleb"]:
		var th: Array = PeekChat.threads(_man(id))
		for t in th:
			ok(not (t as Dictionary).has("hidden_type"), "thread 无 hidden_type (%s)" % id)
			for msg in ((t as Dictionary)["msgs"] as Array):
				ok(not (msg as Dictionary).has("hidden_type"), "msg 无 hidden_type (%s)" % id)

func test_threads_copy_not_ref() -> void:
	var m: Dictionary = _man("leo")
	var th: Array = PeekChat.threads(m)
	ok(not is_same(th[0]["msgs"], m["chat"]), "你 thread msgs 是拷贝,不是 Content 引用")

func test_threads_empty_man_safe() -> void:
	var th: Array = PeekChat.threads({})
	eq(th.size(), 1, "空 man → 只剩 你 thread")
	eq((th[0]["msgs"] as Array).size(), 0, "空 man → 你 msgs 空,不崩")
```

- [ ] **Step 2: 跑测试，确认失败。** Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -8`
Expected: 有失败（`PeekChat.threads` 未定义）。

- [ ] **Step 3: 实现 `threads`。** 在 `Godot/core/PeekChat.gd`，把结尾

```gdscript
		"others_chat": others,
	}
```

替换为

```gdscript
		"others_chat": others,
	}

# 派对收件箱视图：他对你那段(chat)成第 0 个「你」thread,他对每个别人
# 那条各成一个单气泡 thread。仍绝不含 hidden_type。确定性,纯。
# others_chat[0] 是最狠一句 → 它天然落在别人区第一行。空/缺字段安全。
static func threads(man: Dictionary) -> Array:
	var out: Array = []
	var to_you: Array = (man.get("chat", []) as Array).duplicate(true)
	out.append({"contact": "你", "kind": "you", "msgs": to_you})
	for ln in (man.get("others_chat", []) as Array):
		var d: Dictionary = ln
		out.append({
			"contact": str(d.get("to", "")),
			"kind": "other",
			"msgs": [{"from": "him", "text": str(d.get("text", ""))}],
		})
	return out
```

- [ ] **Step 4: 跑测试，确认通过。** Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -2`
Expected: `RAN 85 tests, 0 failures`（80 + 5 新）。

- [ ] **Step 5: 提交。**

```bash
cd /Users/kuma/Projects/Polaris && git add Godot/core/PeekChat.gd Godot/tests/test_peek_chat.gd && git commit -m "$(cat <<'EOF'
feat(hunting): PeekChat.threads — 收件箱派生视图 (他对你 + 他对每个别人)

纯派生:第 0 个=「你」thread(=chat 深拷贝),其后每个 others_chat
收件人各一单气泡 thread。仍绝不含 hidden_type。空 man 安全。
零语料改动。80→85 tests green。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `UiKit.hscroll` + `UiKit.bubble` 可复用原件

**Files:**
- Modify: `Godot/ui/UiKit.gd`

- [ ] **Step 1: 追加两个原件。** 在 `Godot/ui/UiKit.gd`，把现有 `scroll` 函数结尾

```gdscript
	var cv := Control.new()
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(cv)
	return cv
```

替换为

```gdscript
	var cv := Control.new()
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(cv)
	return cv
# Horizontal twin of scroll(). Same cold-premium slim bar. Returns a
# transparent content Control; set custom_minimum_size.x to total width.
static func hscroll(parent: Control, x: int, y: int, w: int, h: int) -> Control:
	var sc := ScrollContainer.new()
	sc.position = Vector2(x, y)
	sc.size = Vector2(w, h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.clip_contents = true
	var hb := sc.get_h_scroll_bar()
	if hb != null:
		hb.custom_minimum_size = Vector2(0, 10)
		hb.add_theme_stylebox_override("scroll", _stylebox(T.PANEL, T.STROKE, 0, T.RADIUS))
		hb.add_theme_stylebox_override("grabber", _stylebox(T.ACCENT_SOFT, T.ACCENT_SOFT, 0, T.RADIUS))
		hb.add_theme_stylebox_override("grabber_highlight", _stylebox(T.ACCENT, T.ACCENT, 0, T.RADIUS))
		hb.add_theme_stylebox_override("grabber_pressed", _stylebox(T.ACCENT, T.ACCENT, 0, T.RADIUS))
	parent.add_child(sc)
	var cv := Control.new()
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(cv)
	return cv
# iOS-style chat bubble. Deterministic height (reused from pre-pivot
# Peek._section): estimate wrapped rows at BODY in inner_w, over-provision.
# mine=true → warm (her side); else cold panel (his side). Returns the Panel
# so the caller can read .size.y for stacking.
static func bubble(parent: Control, x: int, y: int, w: int, text: String, mine: bool) -> Panel:
	var inner_w: int = w - 60
	var per_line: int = max(1, int(float(inner_w) / float(T.BODY) * 1.6))
	var rows: int = int(ceil(float(text.length()) / float(per_line)))
	if rows < 1:
		rows = 1
	var bh: int = rows * int(float(T.BODY) * 1.4) + 60
	if bh < 120:
		bh = 120
	var p := Panel.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, bh)
	p.add_theme_stylebox_override("panel", _stylebox(T.ACCENT_SOFT if mine else T.PANEL_2, T.STROKE, 1, T.RADIUS))
	parent.add_child(p)
	label(p, text, 30, 26, T.BODY, T.TEXT, inner_w)
	return p
```

- [ ] **Step 2: 验证解析 + 回归绿（行为未变）。** Run:
`cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --quit; echo "boot=$?"; /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -1`
Expected: `boot=0`；`RAN 85 tests, 0 failures`（新原件无单测，计数不变）；`SPOT SMOKE OK men=36`（`Peek.gd` 本任务未改，旧鉴渣冒烟仍过）。

- [ ] **Step 3: 提交。**

```bash
cd /Users/kuma/Projects/Polaris && git add Godot/ui/UiKit.gd && git commit -m "$(cat <<'EOF'
feat(hunting-ui): UiKit.hscroll + UiKit.bubble 可复用原件

hscroll = scroll() 横向孪生(同款冷高级细条)。bubble = pivot 前
Peek._section 已验证的确定性气泡高度估算抽件,mine 决定暖/冷底。
不改行为,85 tests green,旧冒烟仍过。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `Peek.gd` 重写成五态机 + 重写冒烟 + 全回归

**Files:**
- Rewrite: `Godot/ui/Peek.gd`
- Rewrite: `Godot/peek_ui_smoke.gd`

- [ ] **Step 1: 重写失败冒烟。** 用以下内容**整文件替换** `Godot/peek_ui_smoke.gd`：

```gdscript
extends SceneTree
const Content := preload("res://core/Content.gd")
const Spotter := preload("res://core/Spotter.gd")
const PeekChat := preload("res://core/PeekChat.gd")

func _initialize() -> void:
	var scene = load("res://scenes/Peek.tscn").instantiate()
	get_root().add_child(scene)
	_run.call_deferred(scene)

func _walk_has_hidden_type(n) -> bool:
	if n is Label and ("hidden_type" in n.text or "high_sugar" in n.text):
		return true
	for c in n.get_children():
		if _walk_has_hidden_type(c):
			return true
	return false

func _run(p) -> void:
	await self.process_frame
	if p._layer == null or p._layer.get_child_count() <= 0:
		print("SPOT SMOKE FAIL: built no nodes"); quit(1); return
	if p.state != "party":
		print("SPOT SMOKE FAIL: did not open on party"); quit(1); return
	var total: int = Content.men().size()
	if total < 36:
		print("SPOT SMOKE FAIL: corpus floor <36"); quit(1); return
	var m0: Dictionary = Content.men()[0]
	var truth0: bool = Spotter.is_scumbag(m0)
	var nthreads: int = PeekChat.threads(m0).size()
	if nthreads != (m0["others_chat"] as Array).size() + 1:
		print("SPOT SMOKE FAIL: threads != others+1"); quit(1); return
	p.open_inbox(0)
	await self.process_frame
	if p.state != "inbox":
		print("SPOT SMOKE FAIL: party->inbox failed"); quit(1); return
	p.open_thread(0)
	await self.process_frame
	if p.state != "thread":
		print("SPOT SMOKE FAIL: inbox->thread failed"); quit(1); return
	if _walk_has_hidden_type(p._layer):
		print("SPOT SMOKE FAIL: thread leaked hidden_type/high_sugar"); quit(1); return
	p.back()
	await self.process_frame
	if p.state != "inbox":
		print("SPOT SMOKE FAIL: thread->inbox back failed"); quit(1); return
	p.begin_judge()
	await self.process_frame
	if p.state != "judge":
		print("SPOT SMOKE FAIL: inbox->judge failed"); quit(1); return
	p.judge(truth0, "expose")
	await self.process_frame
	if p.state != "ending":
		print("SPOT SMOKE FAIL: judge->ending failed"); quit(1); return
	if p.correct != 1:
		print("SPOT SMOKE FAIL: correct not tallied"); quit(1); return
	if _walk_has_hidden_type(p._layer):
		print("SPOT SMOKE FAIL: ending leaked truth"); quit(1); return
	p.next_round()
	await self.process_frame
	if p.state != "party":
		print("SPOT SMOKE FAIL: next_round did not return to party"); quit(1); return
	var id0: String = str(m0.get("id", ""))
	if not p.judged.has(id0) or p.judged[id0] != true:
		print("SPOT SMOKE FAIL: man not marked judged-correct"); quit(1); return
	print("SPOT SMOKE OK men=%d threads0=%d" % [total, nthreads])
	quit(0)
```

- [ ] **Step 2: 跑冒烟，确认失败。** Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -4`
Expected: 失败（旧 `Peek.gd` 无 `state=="party"`、无 `open_inbox/open_thread/begin_judge/back/judged`）。

- [ ] **Step 3: 重写 `Peek.gd`。** 用以下内容**整文件替换** `Godot/ui/Peek.gd`：

```gdscript
extends Node
const Content := preload("res://core/Content.gd")
const PeekChat := preload("res://core/PeekChat.gd")
const Spotter := preload("res://core/Spotter.gd")
const UiKit := preload("res://ui/UiKit.gd")
const T := preload("res://ui/Theme.gd")
const Loc := preload("res://ui/Loc.gd")

var state: String = "party"        # party -> inbox -> thread / judge -> ending
var sel: int = 0                   # 选中男人 index → Content.men()
var thread_i: int = 0              # 选中 thread index → PeekChat.threads()
var correct: int = 0               # 首判读对的人数 (重判不重复计)
var judged: Dictionary = {}        # man id -> bool(首判是否读对)
var _pending_guess: int = -1       # -1 无, 1 渣, 0 好 (judge 子步)
var _choice: String = ""
var _was_right: bool = false
var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	_render()

func _man_now() -> Dictionary:
	var men: Array = Content.men()
	if men.is_empty() or sel < 0 or sel >= men.size():
		return {}
	return men[sel]

func open_inbox(i: int) -> void:
	if state != "party":
		return
	sel = i
	thread_i = 0
	state = "inbox"
	_render()

func open_thread(ti: int) -> void:
	if state != "inbox":
		return
	thread_i = ti
	state = "thread"
	_render()

func begin_judge() -> void:
	if state != "inbox":
		return
	_pending_guess = -1
	state = "judge"
	_render()

func back() -> void:
	match state:
		"thread":
			state = "inbox"
		"inbox":
			state = "party"
		"judge":
			_pending_guess = -1
			state = "inbox"
		_:
			return
	_render()

func _ask_choice(is_scum_guess: bool) -> void:
	if state != "judge":
		return
	_pending_guess = 1 if is_scum_guess else 0
	_render()

func judge(is_scum_guess: bool, choice: String) -> void:
	if state != "judge":
		return
	_choice = choice
	var m: Dictionary = _man_now()
	var truth: bool = Spotter.is_scumbag(m)
	_was_right = (is_scum_guess == truth)
	var id: String = str(m.get("id", ""))
	if not judged.has(id):
		judged[id] = _was_right
		if _was_right:
			correct += 1          # 首判才计;重判只更新角标,不重复计
	else:
		judged[id] = _was_right
	_pending_guess = -1
	state = "ending"
	_render()

func next_round() -> void:
	if state != "ending":
		return
	state = "party"
	_render()

func _render() -> void:
	for c in _layer.get_children():
		c.queue_free()
	var r: Control = UiKit.screen("peek:%d:%d:%s" % [sel, thread_i, state])
	match state:
		"party": _build_party(r)
		"inbox": _build_inbox(r)
		"thread": _build_thread(r)
		"judge": _build_judge(r)
		"ending": _build_ending(r)
		_: _build_party(r)
	_layer.add_child(r)

func _preview(msgs: Array) -> String:
	if msgs.is_empty():
		return ""
	var t: String = str((msgs[msgs.size() - 1] as Dictionary).get("text", ""))
	if t.length() > 26:
		t = t.substr(0, 26) + "…"
	return t

func _build_party(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	UiKit.label(r, "PARTY_TITLE", T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.label(r, "PARTY_SUB", T.PAD, T.PAD + 86, T.SMALL, T.DIM, W)
	UiKit.label(r, Loc.t("SPOT_TALLY") % [correct, Content.men().size()], T.PAD, T.PAD + 150, T.SMALL, T.DIM, W)
	var men: Array = Content.men()
	var cv: Control = UiKit.hscroll(r, 0, 440, T.REF_W, T.CARD_H + 100)
	var CW: int = 300
	var x: int = T.PAD
	for i in men.size():
		var mi: int = i
		var m: Dictionary = men[i]
		var id: String = str(m.get("id", ""))
		UiKit.btn(cv, str(m.get("name", "")), x, 0, CW, T.CARD_H, func() -> void: open_inbox(mi))
		if judged.has(id):
			var won: bool = judged[id]
			UiKit.label(cv, Loc.t("MARK_RIGHT") if won else Loc.t("MARK_WRONG"), x + CW - 52, T.CARD_H + 12, T.SMALL, (T.ACCENT if won else T.DANGER))
		x += CW + T.GAP
	cv.custom_minimum_size = Vector2(x, T.CARD_H + 100)

func _build_inbox(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var m: Dictionary = _man_now()
	UiKit.label(r, str(m.get("name", "")), T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.btn(r, "THREAD_BACK", T.PAD, T.PAD + 96, 240, 96, back)
	UiKit.btn(r, "INBOX_JUDGE", T.PAD, T.REF_H - 300, W, T.BTN_H, begin_judge)
	var threads: Array = PeekChat.threads(m)
	var top: int = T.PAD + 230
	var cv: Control = UiKit.scroll(r, T.PAD, top, W, T.REF_H - top - 360)
	var y: int = 0
	for ti in threads.size():
		var idx_t: int = ti
		var th: Dictionary = threads[ti]
		var contact: String = str(th.get("contact", ""))
		var prev: String = _preview(th.get("msgs", []))
		UiKit.btn(cv, contact + "   ·   " + prev + "   ›", 0, y, W, T.BTN_H, func() -> void: open_thread(idx_t))
		y += T.BTN_H + T.GAP
		if ti == 0:
			var rule := ColorRect.new()
			rule.color = T.ACCENT
			rule.position = Vector2(0, y + 6)
			rule.size = Vector2(W, 2)
			cv.add_child(rule)
			UiKit.label(cv, "PEEK_HINGE", 0, y + 18, T.SMALL, T.ACCENT, W)
			y += 18 + 64 + T.GAP
	cv.custom_minimum_size = Vector2(W, y)

func _build_thread(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var m: Dictionary = _man_now()
	var threads: Array = PeekChat.threads(m)
	var th: Dictionary = threads[thread_i] if thread_i >= 0 and thread_i < threads.size() else {}
	UiKit.label(r, str(th.get("contact", "")), T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.btn(r, "THREAD_BACK", T.PAD, T.PAD + 96, 240, 96, back)
	var msgs: Array = th.get("msgs", [])
	var top: int = T.PAD + 230
	var cv: Control = UiKit.scroll(r, T.PAD, top, W, T.REF_H - top - 120)
	var y: int = 0
	var bw: int = int(float(W) * 0.78)
	for line in msgs:
		var d: Dictionary = line
		var mine: bool = str(d.get("from", "")) == "you"
		var bx: int = (W - bw) if mine else 0
		var pan: Panel = UiKit.bubble(cv, bx, y, bw, str(d.get("text", "")), mine)
		y += int(pan.size.y) + T.GAP
	cv.custom_minimum_size = Vector2(W, y)

func _build_judge(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var m: Dictionary = _man_now()
	UiKit.label(r, str(m.get("name", "")) + " · " + Loc.t("SPOT_ASK"), T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.btn(r, "THREAD_BACK", T.PAD, T.PAD + 96, 240, 96, back)
	var y: int = 380
	UiKit.btn(r, "SPOT_SCUM", T.PAD, y, W, T.BTN_H, func() -> void: _ask_choice(true))
	y += T.BTN_H + T.GAP
	UiKit.btn(r, "SPOT_GOOD", T.PAD, y, W, T.BTN_H, func() -> void: _ask_choice(false))
	if _pending_guess != -1:
		y += T.BTN_H + T.GAP * 2
		UiKit.label(r, "SPOT_ASK", T.PAD, y, T.SMALL, T.DIM, W)
		y += 64
		var guess_scum: bool = _pending_guess == 1
		for ch in [["expose", "SPOT_EXPOSE"], ["probe", "SPOT_PROBE"], ["leave", "SPOT_LEAVE"]]:
			var cid: String = ch[0]
			var clbl: String = ch[1]
			UiKit.btn(r, clbl, T.PAD, y, W, T.BTN_H, func() -> void: judge(guess_scum, cid))
			y += T.BTN_H + T.GAP

func _build_ending(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var m: Dictionary = _man_now()
	var truth: bool = Spotter.is_scumbag(m)
	var nm: String = str(m.get("name", ""))
	var ekey: String = Spotter.ending_key(truth, _choice)
	var vkey: String = Spotter.verdict_key(_was_right, truth)
	UiKit.label(r, nm, T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.panel(r, T.PAD, 340, W, 360)
	UiKit.label(r, Loc.t(ekey) % nm, T.PAD + 40, 390, T.BODY, T.TEXT, W - 80)
	UiKit.label(r, Loc.t(vkey), T.PAD, 760, T.TITLE, (T.ACCENT if _was_right else T.DANGER), W)
	UiKit.btn(r, "SPOT_NEXT", T.PAD, T.REF_H - 320, W, T.BTN_H, next_round)
```

- [ ] **Step 4: 跑冒烟，确认通过。** Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -3`
Expected: `SPOT SMOKE OK men=36 threads0=N`（N = adrian 的 `others_chat` 条数 + 1；当前 adrian 为 3 → `threads0=4`），exit 0，无 `SCRIPT ERROR`。

- [ ] **Step 5: 全回归 + 未受影响检查。** Run:
`cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --quit; echo "boot=$?"; /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --script res://ui_smoke.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --script res://play.gd 2>&1 | tail -1`
Expected: `boot=0`；`RAN 85 tests, 0 failures`；`HUB SMOKE OK day=2 dossier=3 reads=3`；play 末行 `Season close.`。

- [ ] **Step 6: 窗口化 sanity（尽力）。** Run: `cd /Users/kuma/Projects/Polaris/Godot && timeout 12 /opt/homebrew/bin/godot --path . res://scenes/Peek.tscn 2>&1 | tail -6 ; echo "rc=$?"`
Expected: 无 `SCRIPT ERROR`/parse `ERROR`；rc `124`（超时被 kill，正常）或 `0` 均可；若环境纯 headless 无窗口，照实说明并以 Step 4/5 为准。引用 tail 输出。

- [ ] **Step 7: 提交。**

```bash
cd /Users/kuma/Projects/Polaris && git add Godot/ui/Peek.gd Godot/peek_ui_smoke.gd && git commit -m "$(cat <<'EOF'
feat(hunting-ui): Peek 重写为 派对→收件箱→thread→判→自洽结局 五态机

party(全员横排,judged ✓/✗) → inbox(你 thread + hinge + 每个别人
一行,iOS 短信式) → thread(气泡:你右暖/他左冷) → 鉴定他 → 判+态度
→ 6 正文 + 4 档裁定 → next 回 party。复用 PeekChat.threads(永不
泄真相)+Spotter+UiKit.hscroll/bubble。冒烟驱动全程并断言 _layer
零泄露。Content/Hub/play/engine 不碰。85 tests green。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review (plan author)

**Spec coverage（逐节对照）：**
- §状态机 `party|inbox|thread|judge|ending` + 闭环 → Task 4 `Peek.gd` 五态 `match` + `open_inbox/open_thread/begin_judge/back/judge/next_round`，冒烟驱动全路径。
- §party 全员横排 + hover 变亮 + ✓/✗ 角标 + `看穿 X/N`(N=`Content.men().size()`) + 每人只记一次 → `_build_party`（`UiKit.hscroll` + `UiKit.btn` 自带 hover/pressed 描边即变亮；`judged` 角标；tally 用 `Content.men().size()`）；`judge()` 首判才 `correct+=1`，重判只更新 `judged[id]`。
- §inbox 第 0 行「你」→ hinge → 每个 others 一行 + 鉴定他 + 返回 → `_build_inbox`（`PeekChat.threads`，`ti==0` 后插 `PEEK_HINGE` 分割线，`INBOX_JUDGE`/`THREAD_BACK` 按钮）。
- §thread 气泡(你右暖/他左冷) → `_build_thread` + `UiKit.bubble(mine)`；别人 thread 单气泡（Q1 已知取舍）。
- §结局两层(6 正文×名字 + 4 档裁定) → Task 1 `Spotter.ending_key`+`verdict_key`+Loc 6 改值+4 新值；`_build_ending` 双 label，颜色 `ACCENT/DANGER`。
- §数据映射 `PeekChat.threads` 不含 `hidden_type`、第 0「你」、others 单气泡、空安全、`others_chat[0]` 在别人区第一行 → Task 2 实现 + 5 测试覆盖全部断言。
- §UiKit 新增 hscroll/bubble → Task 3。
- §Loc 新增/复用 → Task 1 Step 5 全部键；复用 `PEEK_HINGE/SPOT_*` 在 Task 4 引用。
- §测试/冒烟/全回归/窗口 sanity → Task 1/2 单测，Task 4 冒烟重写 + Step 5 全回归 + Step 6 窗口。
- §不做（零语料、无女性、无 RNG 子集、不复活搁置）→ File Structure「Untouched/Out of scope」明列，无任务触碰 `Content.gd` 等。

**Placeholder scan：** 无 TBD/TODO；每个改动给出完整 GDScript 与精确 Edit 锚点（整文件替换的 Peek/smoke 给全文）；命令与期望输出具体（计数 77→80→85→85；冒烟 `SPOT SMOKE OK men=36 threads0=4`，4=adrian others_chat 3 条 +1）。Step 6 的 rc 124/0 与 headless 回退已写明判定。

**Type consistency：** `Spotter.verdict_key(bool,bool)->String` 在 Task1 测试、Task4 `_build_ending` 同签名；`PeekChat.threads(Dictionary)->Array`、元素 `{contact,kind,msgs}`、`msgs` 元素 `{from,text}` 在 Task2 实现/测试与 Task4 `_build_inbox/_build_thread`/冒烟一致；`Peek` 公开面 `state/sel/thread_i/correct/judged/_layer/_man_now/open_inbox/open_thread/begin_judge/back/judge/next_round` 与冒烟逐一对应；`state` 取值 `party/inbox/thread/judge/ending` 在 `match`、转移、冒烟断言三处一致；`UiKit.hscroll`→`Control`、`UiKit.bubble`→`Panel`（`_build_thread` 读 `pan.size.y`）签名一致；Loc 键 `END_*`/`VERDICT_*` 恰为 `ending_key`/`verdict_key` 产出（`END_{SCUM|GOOD}_{EXPOSE|PROBE|LEAVE}`、`VERDICT_{RIGHT|WRONG}_{SCUM|GOOD}`），Task1 Loc-存在锁强制其存在；`Loc.ZH` 为 `class_name Loc` 的 `const`，`preload(...).ZH` 可访问（Task1 测试用）。`test_base` 仅 `eq/ok/ge`，新测试只用这三者。`run_tests` 已注册 `test_spotter`/`test_peek_chat`，无需改注册。
