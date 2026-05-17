# 鉴渣休闲小游戏 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the existing Peek screen into a casual round-based "spot the 渣男" game: see his chats-to-others first, hear his sweet line, judge 好/渣 + pick an attitude, get a cold one-line ending, tally.

**Architecture:** One new tiny pure truth-helper (`hidden_type` → 好/渣, never exposed in UI) + one new pure ending-matrix function (truth×choice → Loc key). Rework `Godot/ui/Peek.gd` in place into a round state machine (`intel → face → judged → ending`), reusing `PeekChat.peek()` (unchanged — still never returns truth), `UiKit`/`Theme`, `Content.men()`. zh strings appended to `Loc.gd`. Hub/engine/play untouched.

**Tech Stack:** Godot 4.6 GDScript. Pure `RefCounted` helper + UI Node. Headless harness `tests/run_tests.gd` (path-based `extends "res://tests/test_base.gd"`). `godot` = `/opt/homebrew/bin/godot`. Commit on `main`, do NOT push.

**Spec:** `docs/superpowers/specs/2026-05-18-hunting-casual-spotter-design.zh.md` (locked). Soul: cold-premium, anti-otome, she-on-top, code-gen NO art, portrait 1170×2532.

---

## File Structure

- **Create** `Godot/core/Spotter.gd` — `class_name Spotter`, pure: `is_scumbag(man)` (`hidden_type=="high_sugar"`), `ending_key(is_scum, choice)` → a Loc key string. No UI, no RNG, never returns `hidden_type`.
- **Create** `Godot/tests/test_spotter.gd` — `extends "res://tests/test_base.gd"`; truth mapping over all 12 men + ending-matrix coverage. Registered in `run_tests.gd`.
- **Modify** `Godot/tests/run_tests.gd` — append `"res://tests/test_spotter.gd",` to `TESTS`.
- **Modify** `Godot/ui/Peek.gd` — replace its `list/reveal` body with the round state machine. Public API for the smoke: `state`, `idx`, `judged_scum`, `seen`, `correct`, `_man_now()`, `judge(is_scum_guess: bool, choice: String)`, `next_round()`.
- **Modify** `Godot/ui/Loc.gd` — APPEND keys (round labels + 6 ending templates) before the `ZH` closing `}`; no existing line changed, no dup.
- **Rework** `Godot/peek_ui_smoke.gd` — drive a full round; assert state machine + truth helper consistency + UI never renders `hidden_type`.
- **Untouched:** `Godot/scenes/Peek.tscn` (still → `res://ui/Peek.gd`), `Godot/core/PeekChat.gd` (unchanged), `Godot/core/Content.gd`, Hub/Faces/play/ui_smoke/tuning/Game.tscn/engine.

**Out of scope (do NOT build):** two-axis, Control, dialogue trees, assets/balance-sheet, season, hub-shell, 开天眼 cost, corpus expansion.

---

### Task 1: `Spotter` pure helper (truth map + ending matrix)

**Files:** Create `Godot/core/Spotter.gd`, `Godot/tests/test_spotter.gd`; modify `Godot/tests/run_tests.gd`.

- [ ] **Step 1: Register test.** In `Godot/tests/run_tests.gd`, add `	"res://tests/test_spotter.gd",` immediately after the line `	"res://tests/test_peek_chat.gd",` (keep everything else):
```gdscript
	"res://tests/test_peek_chat.gd",
	"res://tests/test_spotter.gd",
]
```

- [ ] **Step 2: Write the failing test.** Create `Godot/tests/test_spotter.gd`:
```gdscript
extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")
const Spotter := preload("res://core/Spotter.gd")

func test_truth_map_matches_hidden_type() -> void:
	for m in Content.men():
		var scum: bool = Spotter.is_scumbag(m)
		if m["hidden_type"] == "high_sugar":
			ok(scum, "%s (high_sugar) is 渣" % str(m["id"]))
		else:
			ok(not scum, "%s (%s) is 好" % [str(m["id"]), str(m["hidden_type"])])

func test_is_scumbag_empty_man_safe() -> void:
	ok(not Spotter.is_scumbag({}), "empty man -> not 渣, no crash")

func test_ending_matrix_full_coverage() -> void:
	var keys := {}
	for scum in [true, false]:
		for ch in ["expose", "probe", "leave"]:
			var k: String = Spotter.ending_key(scum, ch)
			ok(k != "", "ending key non-empty for scum=%s %s" % [str(scum), ch])
			keys[k] = true
	eq(keys.size(), 6, "6 distinct ending keys (2 truths × 3 choices)")

func test_ending_key_unknown_choice_safe() -> void:
	var k: String = Spotter.ending_key(true, "garbage")
	ok(k != "", "unknown choice still returns a non-empty key, no crash")
```

- [ ] **Step 3: Run, verify FAIL.** `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -5` — expect ≥1 failures (`Spotter` missing).

- [ ] **Step 4: Implement.** Create `Godot/core/Spotter.gd`:
```gdscript
extends RefCounted
class_name Spotter

# 鉴渣纯逻辑。high_sugar=渣;resource/growth=好。绝不向 UI 暴露 hidden_type。
static func is_scumbag(man: Dictionary) -> bool:
	return str(man.get("hidden_type", "")) == "high_sugar"

# (真相 × 选择) → Loc key。choice ∈ {"expose"(拆穿),"probe"(试探),"leave"(走开)}。
# 未知 choice 退化为 "leave" 行,绝不返回空。
static func ending_key(is_scum: bool, choice: String) -> String:
	var c := choice
	if c != "expose" and c != "probe" and c != "leave":
		c = "leave"
	var who := "SCUM" if is_scum else "GOOD"
	return "END_%s_%s" % [who, c.to_upper()]
```

- [ ] **Step 5: Run, verify PASS.** `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -3` — expect `RAN 76 tests, 0 failures` (72 + 4 new).

- [ ] **Step 6: Commit** (repo root):
```bash
cd /Users/kuma/Projects/Polaris && git add Godot/core/Spotter.gd Godot/tests/test_spotter.gd Godot/tests/run_tests.gd && git commit -m "$(cat <<'EOF'
feat(hunting): Spotter pure logic — 好/渣 map + (truth×choice) ending keys

high_sugar→渣, resource/growth→好 (never exposes hidden_type). ending_key
maps (is_scum × expose/probe/leave) → 1 of 6 Loc keys; unknown choice
degrades safely. Empty-man safe.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Loc strings (round labels + 6 ending templates)

**Files:** Modify `Godot/ui/Loc.gd` (append only).

- [ ] **Step 1: Append keys.** In `Godot/ui/Loc.gd`, insert these lines BETWEEN the current last `ZH` entry (the line `	"PEEK_BACK":         "返回",` — it is the last entry before the dict's closing `}`) and that closing `}`. (If `PEEK_BACK` is not the last line, insert immediately before the `}` that closes `const ZH := {`. Do not modify any existing line; no duplicate keys.)
```gdscript

	# ── 鉴渣休闲小游戏 (casual spotter) ──────────────────────────────────────
	"SPOT_INTEL":        "开天眼 · 他对别人说的",
	"SPOT_FACE":         "他正对你说",
	"SPOT_ASK":          "他是？",
	"SPOT_GOOD":         "好男人",
	"SPOT_SCUM":         "渣男",
	"SPOT_EXPOSE":       "当面拆穿",
	"SPOT_PROBE":        "饭局试探",
	"SPOT_LEAVE":        "直接走开",
	"SPOT_NEXT":         "下一个",
	"SPOT_TALLY":        "看穿 %d / %d",
	"END_SCUM_EXPOSE":   "%s 当场破功，话都接不上。你拿起包，没回头。",
	"END_SCUM_PROBE":    "你不动声色多问一句，%s 自己把谎接圆不上了。看清了。",
	"END_SCUM_LEAVE":    "你没解释，直接走。%s 还在想哪句说错了。",
	"END_GOOD_EXPOSE":   "%s 沉默了一下，没辩解，走了。你拆穿了一个没装的人。",
	"END_GOOD_PROBE":    "%s 经得起问，答得很实。你看到的是真的。",
	"END_GOOD_LEAVE":    "你走了。%s 没追。有些人不会演，也不会求。",
```

- [ ] **Step 2: Verify parse + Loc intact.** `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --quit; echo "boot=$?"` — expect `boot=0`, no parse error. Then `/opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -2` — expect `RAN 76 tests, 0 failures` (Loc append doesn't change counts; existing tests unaffected).

- [ ] **Step 3: Commit** (repo root):
```bash
cd /Users/kuma/Projects/Polaris && git add Godot/ui/Loc.gd && git commit -m "$(cat <<'EOF'
feat(hunting-ui): zh strings for 鉴渣 round (labels + 6 ending templates)

Append-only: intel/face/ask/judge/choice/next/tally labels + the 6
(好/渣 × 拆穿/试探/走开) cold ending templates (name-slotted via %s).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Rework `Peek.gd` into the round game + smoke

**Files:** Modify `Godot/ui/Peek.gd`; rework `Godot/peek_ui_smoke.gd`.

- [ ] **Step 1: Rework the failing smoke.** Replace the ENTIRE contents of `Godot/peek_ui_smoke.gd` with:
```gdscript
extends SceneTree
const Content := preload("res://core/Content.gd")
const Spotter := preload("res://core/Spotter.gd")

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
		print("SPOT SMOKE FAIL: round built no nodes"); quit(1); return
	if p.state != "intel":
		print("SPOT SMOKE FAIL: did not open on intel"); quit(1); return
	var total: int = Content.men().size()
	# Drive one full round on man 0.
	var m0: Dictionary = p._man_now()
	var truth0: bool = Spotter.is_scumbag(m0)
	p.reveal_face()
	await self.process_frame
	if p.state != "face":
		print("SPOT SMOKE FAIL: intel->face failed"); quit(1); return
	p.judge(truth0, "expose")
	await self.process_frame
	if p.state != "ending":
		print("SPOT SMOKE FAIL: judge->ending failed"); quit(1); return
	if p.correct != 1:
		print("SPOT SMOKE FAIL: correct guess not tallied"); quit(1); return
	if _walk_has_hidden_type(p._layer):
		print("SPOT SMOKE FAIL: UI leaked hidden_type/high_sugar"); quit(1); return
	p.next_round()
	await self.process_frame
	if p.state != "intel" or p.idx != 1 or p.seen != 1:
		print("SPOT SMOKE FAIL: next_round did not advance"); quit(1); return
	print("SPOT SMOKE OK men=%d" % total)
	quit(0)
```

- [ ] **Step 2: Run, verify FAIL.** `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -5` — expect failure (old `Peek.gd` has no `state=="intel"`, no `_man_now`/`reveal_face`/`judge`/`next_round`).

- [ ] **Step 3: Rework `Peek.gd`.** Replace the ENTIRE contents of `Godot/ui/Peek.gd` with:
```gdscript
extends Node
const Content := preload("res://core/Content.gd")
const PeekChat := preload("res://core/PeekChat.gd")
const Spotter := preload("res://core/Spotter.gd")
const UiKit := preload("res://ui/UiKit.gd")
const T := preload("res://ui/Theme.gd")
const Loc := preload("res://ui/Loc.gd")

var state: String = "intel"        # intel -> face -> ending -> (next) intel
var idx: int = 0                   # current man index into Content.men()
var seen: int = 0                  # rounds completed
var correct: int = 0               # correct judgements
var judged_scum: bool = false      # last guess
var _choice: String = ""           # last attitude choice
var _was_right: bool = false
var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	_render()

func _man_now() -> Dictionary:
	var men: Array = Content.men()
	if men.is_empty():
		return {}
	return men[idx % men.size()]

func reveal_face() -> void:
	if state == "intel":
		state = "face"
		_render()

func judge(is_scum_guess: bool, choice: String) -> void:
	if state != "face":
		return
	judged_scum = is_scum_guess
	_choice = choice
	var truth: bool = Spotter.is_scumbag(_man_now())
	_was_right = (is_scum_guess == truth)
	if _was_right:
		correct += 1
	state = "ending"
	_render()

func next_round() -> void:
	if state != "ending":
		return
	seen += 1
	idx += 1
	state = "intel"
	_render()

func _render() -> void:
	for c in _layer.get_children():
		c.queue_free()
	var r: Control = UiKit.screen("spot:%d:%s" % [idx, state])
	match state:
		"intel": _build_intel(r)
		"face": _build_face(r)
		"ending": _build_ending(r)
		_: _build_intel(r)
	_layer.add_child(r)

func _sharp_line(others: Array) -> String:
	# Deterministic: the first chat-to-others entry is the sharpest tell. No RNG.
	if others.is_empty():
		return ""
	var ln: Dictionary = others[0]
	return "（对%s）%s" % [str(ln.get("to", "")), str(ln.get("text", ""))]

func _build_intel(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var p: Dictionary = PeekChat.peek(_man_now())
	UiKit.label(r, "SPOT_INTEL", T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.label(r, Loc.t("SPOT_TALLY") % [correct, seen], T.PAD, T.PAD + 90, T.SMALL, T.DIM, W)
	var others: Array = p.get("others_chat", [])
	UiKit.panel(r, T.PAD, 360, W, 360)
	UiKit.label(r, _sharp_line(others), T.PAD + 40, 410, T.BODY, T.TEXT, W - 80)
	UiKit.btn(r, "SPOT_FACE", T.PAD, T.REF_H - 320, W, T.BTN_H, reveal_face)

func _build_face(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var p: Dictionary = PeekChat.peek(_man_now())
	var to_you: Array = p.get("to_you_chat", [])
	var line := ""
	if not to_you.is_empty():
		line = str((to_you[0] as Dictionary).get("text", ""))
	UiKit.label(r, str(p.get("name", "")) + " · " + Loc.t("SPOT_FACE"), T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.panel(r, T.PAD, 320, W, 300)
	UiKit.label(r, line, T.PAD + 40, 370, T.BODY, T.TEXT, W - 80)
	UiKit.label(r, "SPOT_ASK", T.PAD, 700, T.SMALL, T.DIM, W)
	# 2 truth buttons; each then needs an attitude. Keep it flat: tapping a
	# truth opens the 3 attitudes inline.
	var y := 780
	UiKit.btn(r, "SPOT_SCUM", T.PAD, y, W, T.BTN_H, func() -> void: _ask_choice(true))
	y += T.BTN_H + T.GAP
	UiKit.btn(r, "SPOT_GOOD", T.PAD, y, W, T.BTN_H, func() -> void: _ask_choice(false))
	if _pending_guess != -1:
		y += T.BTN_H + T.GAP * 2
		UiKit.label(r, "SPOT_ASK", T.PAD, y, T.SMALL, T.DIM, W); y += 64
		var guess_scum: bool = _pending_guess == 1
		for ch in [["expose", "SPOT_EXPOSE"], ["probe", "SPOT_PROBE"], ["leave", "SPOT_LEAVE"]]:
			var cid: String = ch[0]
			var clbl: String = ch[1]
			UiKit.btn(r, clbl, T.PAD, y, W, T.BTN_H, func() -> void: judge(guess_scum, cid))
			y += T.BTN_H + T.GAP

var _pending_guess: int = -1   # -1 none, 1 scum, 0 good (face sub-step)

func _ask_choice(is_scum_guess: bool) -> void:
	if state != "face":
		return
	_pending_guess = 1 if is_scum_guess else 0
	_render()

func _build_ending(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var m: Dictionary = _man_now()
	var truth: bool = Spotter.is_scumbag(m)
	var key: String = Spotter.ending_key(truth, _choice)
	var nm: String = str(m.get("name", ""))
	UiKit.label(r, nm, T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.panel(r, T.PAD, 340, W, 360)
	UiKit.label(r, Loc.t(key) % nm, T.PAD + 40, 390, T.BODY, T.TEXT, W - 80)
	var verdict := "你看穿了。" if _was_right else "你被他骗了。"
	UiKit.label(r, verdict, T.PAD, 760, T.TITLE, (T.ACCENT if _was_right else T.DANGER), W)
	UiKit.btn(r, "SPOT_NEXT", T.PAD, T.REF_H - 320, W, T.BTN_H, next_round)
```
Reset `_pending_guess` on round/state change: ensure `reveal_face()` and `next_round()` set `_pending_guess = -1`. Add `_pending_guess = -1` as the first line inside BOTH `reveal_face()` (before `state = "face"`) and `next_round()` (before `state = "intel"`), and inside `judge()` (before `state = "ending"`).

(GDScript 4.6: bracket Variant dict access; typed locals for Variant returns; per-iteration `cid`/`clbl`/`ch` copied to fresh locals before the `func(): judge(guess_scum, cid)` capture; `match` uses constant string patterns; `Loc.t(key) % nm` formats the `%s` template. `UiKit.label`/`btn`/`panel`/`screen` signatures are as in the current `Godot/ui/UiKit.gd`; `screen(sig)` gates the fade per `idx:state`.)

- [ ] **Step 4: Run smoke, verify PASS.** `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -3` — expect `SPOT SMOKE OK men=12`, exit 0, no `SCRIPT ERROR`.

- [ ] **Step 5: Full regression + unaffected checks.** `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --quit; echo "boot=$?"; /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --script res://ui_smoke.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --script res://play.gd 2>&1 | tail -1` — expect `boot=0`; `RAN 76 tests, 0 failures`; `HUB SMOKE OK day=2 dossier=3 reads=3`; play ends `Season close.`.

- [ ] **Step 6: Windowed sanity (best-effort).** `cd /Users/kuma/Projects/Polaris/Godot && timeout 12 /opt/homebrew/bin/godot --path . res://scenes/Peek.tscn 2>&1 | tail -6 ; echo "rc=$?"` — pass: no `SCRIPT ERROR`/parse ERROR; rc 124 or 0 both fine; headless-only no-window acceptable (say so). Quote tail.

- [ ] **Step 7: Commit** (repo root):
```bash
cd /Users/kuma/Projects/Polaris && git add Godot/ui/Peek.gd Godot/peek_ui_smoke.gd && git commit -m "$(cat <<'EOF'
feat(hunting-ui): rework Peek into the casual 鉴渣 round game

intel(他对别人最狠一句) → face(他对你的甜话) → 辨好/渣 + 拆穿/试探/走开
→ (truth×choice) cold ending + 看穿X/Y tally → next. Reuses PeekChat
(unchanged, never leaks truth) + Spotter + UiKit. Smoke drives a full
round and asserts the UI never renders hidden_type. Hub/engine untouched.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review (plan author)

**Spec coverage:** §一回合 1 intel-first sharpest 1-2 lines deterministic → `_build_intel` + `_sharp_line` (first `others_chat` entry, `others.is_empty()` safe, no RNG). §2 当面 to-you bait → `_build_face` (first `to_you_chat` text). §3 辨+选 fixed 3 (拆穿/试探/走开) → `_ask_choice` then 3 attitude btns (`expose/probe/leave`). §4 ending (truth×choice) template name-slotted → `Spotter.ending_key` + `Loc.t(key) % nm` + 6 `END_*` templates. §5 tally + no economy/axes → `SPOT_TALLY`/`correct`/`seen`, nothing else. §好/渣 map = `hidden_type` pure, never in UI → `Spotter.is_scumbag` + smoke `_walk_has_hidden_type` asserts no leak. §复用/改造 → reuses `PeekChat.peek` (untouched), reworks `Peek.gd` in place, `Peek.tscn` untouched. §明确不做 → no two-axis/Control/dialogue/assets/season/hub-shell; Hub/play/ui_smoke/tuning/Game.tscn/PeekChat/Content untouched (Task files list is exhaustive).

**Placeholder scan:** No TBD/TODO. Full `Spotter.gd`, full reworked `Peek.gd`, full reworked smoke, exact Loc lines, full test bodies, exact commands + expected output. Counts: 72→76 (Task1 +4 tests; Loc/Peek add none). One explicit instruction (the `_pending_guess = -1` reset) is spelled out with exact placement, not a vague "handle state".

**Type consistency:** `Spotter.is_scumbag(man)->bool` / `ending_key(bool,String)->String` used identically in test, smoke, `Peek._build_ending`. `Peek` public surface (`state`,`idx`,`seen`,`correct`,`_man_now`,`reveal_face`,`judge`,`next_round`,`_layer`,`_pending_guess`) matches exactly what the smoke drives. `state` values `intel/face/ending` consistent across `_render` match, transitions, and smoke asserts. Loc keys used in `Peek.gd` (`SPOT_*`, `END_*`) are exactly those appended in Task 2; `END_*` keys are exactly what `Spotter.ending_key` produces (`END_{SCUM|GOOD}_{EXPOSE|PROBE|LEAVE}`). `PeekChat.peek` 4-key contract (`name`,`surface_claim`,`to_you_chat`,`others_chat`, no `hidden_type`) consumed via `.get(...)` — safe, unchanged.

**Scope:** 3 small tasks, casual, lean. Each commit independently sound (Task 1 pure logic+tests green; Task 2 Loc+green; Task 3 the screen+smoke+full regression). Produces a runnable casual game (`godot --path . res://scenes/Peek.tscn`).
