# 看聊记 呈现切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the UI for the game's first hook — a standalone screen where you pick a man and see his actual texts *to you* stacked against his actual texts *to others*, same mouth two faces, with no verdict.

**Architecture:** One spec-safe backend addition (`PeekChat.peek()` also returns `to_you_chat`, a shallow copy of his to-you chat — performance, not truth; `hidden_type` still never exposed). A dedicated isolated scene `Godot/scenes/Peek.tscn` → `Godot/ui/Peek.gd`, a `Node` with a `CanvasLayer` that rebuilds on a 2-state machine (`list` ⇄ `reveal`), reusing the Plan E `UiKit`/`Theme`/`Loc` system (incl. the existing `UiKit.scroll`). The hub and engine are not touched.

**Tech Stack:** Godot 4.6 GDScript. Pure `RefCounted` core; headless test harness `tests/run_tests.gd` (path-based `extends "res://tests/test_base.gd"`); headless SceneTree smoke pattern (mirrors `Godot/ui_smoke.gd`). `godot` = `/opt/homebrew/bin/godot`. Commit on `main`, do **not** push.

**Spec:** `docs/superpowers/specs/2026-05-17-hunting-peek-chat-ui-design.zh.md` (locked). Soul: cold-premium, anti-otome, she-at-the-centre, code-gen NO art, portrait 1170×2532.

---

## File Structure

- **Modify** `Godot/core/PeekChat.gd` — add `to_you_chat` to the returned dict (shallow copy of `man.get("chat", [])`). Still no `hidden_type`/`risk`.
- **Modify** `Godot/tests/test_peek_chat.gd` — APPEND 3 tests (existing tests byte-unchanged). Already registered in `run_tests.gd` `TESTS` (no run_tests.gd change).
- **Create** `Godot/ui/Peek.gd` — `extends Node`; `CanvasLayer`; `state` machine `list`/`reveal`; reuses `UiKit`/`Theme`/`Loc`. One responsibility: present the 看聊记 hook.
- **Create** `Godot/scenes/Peek.tscn` — scene root `Node` with `Peek.gd` attached (same shape as `Game.tscn`).
- **Modify** `Godot/ui/Loc.gd` — APPEND 8 new zh keys inside the `ZH` dict, immediately before its closing `}` (after the last entry `"That's enough reading for tonight.": "今晚读够了。",`). No existing key changed, no duplicate.
- **Create** `Godot/peek_ui_smoke.gd` — `extends SceneTree` headless smoke (mirrors `Godot/ui_smoke.gd`): builds list, switches to reveal, asserts both states build nodes and the reveal is wired to `peek()` data. Dev helper, NOT added to `tests/run_tests.gd`.
- **Create** `Godot/peek_shot.gd` — `extends SceneTree` best-effort screenshot helper (mirrors Plan E `Godot/screenshot.gd`); not headless-required, dev helper.

**Out of scope — do NOT touch / build:** `Godot/ui/Hub.gd`, `Godot/ui/Faces.gd`, `Godot/play.gd`, `Godot/ui_smoke.gd`, `Godot/data/tuning.json`, `Godot/scenes/Game.tscn`; hub-shell integration; live branching dialogue; H/S axes; scarcity/energy cost; corpus mass-production; 约会 future-eye; any 糖/料 verdict/score in the UI.

---

### Task 1: Backend — `PeekChat.peek()` returns `to_you_chat`

His texts *to you* are the performance face (not the truth) — needed for the side-by-side. Including them is consistent with the locked "never reveal truth" discipline (the `chat` field is what he wants her to see; it does not contain `hidden_type`).

**Files:**
- Modify: `Godot/core/PeekChat.gd`
- Modify: `Godot/tests/test_peek_chat.gd` (append only)

- [ ] **Step 1: Append the failing tests** to the END of `Godot/tests/test_peek_chat.gd` (do not alter existing tests; `_man()` and `const PeekChat` already exist in the file — reuse them):

```gdscript

func test_peek_carries_to_you_chat() -> void:
	var r: Dictionary = PeekChat.peek(_man("evan"))
	ok(r.has("to_you_chat"), "peek carries to_you_chat (his performance face)")
	var ty: Array = r["to_you_chat"]
	ok(ty.size() >= 1, "evan to_you_chat non-empty")
	for line in ty:
		ok(line.has("from") and line.has("text"), "to_you line shape {from,text}")

func test_peek_to_you_is_a_distinct_copy() -> void:
	var m: Dictionary = _man("leo")
	var r: Dictionary = PeekChat.peek(m)
	ok(not is_same(r["to_you_chat"], m["chat"]), "to_you_chat is a copy, not a ref into Content")
	eq(str(r["to_you_chat"]), str(m["chat"]), "the copy is value-equal to the source")

func test_peek_with_to_you_still_hides_truth() -> void:
	for id in ["adrian", "evan", "leo"]:
		var r: Dictionary = PeekChat.peek(_man(id))
		ok(not r.has("hidden_type"), "still no truth for %s after adding to_you_chat" % id)
		ok(not r.has("risk"), "still no risk label for %s" % id)
	var e: Dictionary = PeekChat.peek({})
	eq((e["to_you_chat"] as Array).size(), 0, "empty man -> empty to_you_chat, no crash")
```

- [ ] **Step 2: Run, verify it FAILS**

Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -5`
Expected: `RAN <N> tests, <≥1> failures` — `to_you_chat` not present yet (`r.has("to_you_chat")` false; `r["to_you_chat"]` indexing fails).

- [ ] **Step 3: Add `to_you_chat`** to `Godot/core/PeekChat.gd`. Replace the body of `peek()` so it reads exactly:

```gdscript
static func peek(man: Dictionary) -> Dictionary:
	# Shallow copies: never hand a consumer a reference into Content's data
	# (a future UI may sort/annotate these in place). Lines are value dicts.
	var others: Array = (man.get("others_chat", []) as Array).duplicate()
	var to_you: Array = (man.get("chat", []) as Array).duplicate()
	return {
		"name": str(man.get("name", "")),
		"surface_claim": str(man.get("surface", "")),
		"to_you_chat": to_you,
		"others_chat": others,
	}
```

(Leave the file's header comment block byte-unchanged; only the function body changes.)

- [ ] **Step 4: Run, verify it PASSES**

Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `RAN <N+3> tests, 0 failures` (current total is 67 → expect `RAN 70 tests, 0 failures`).

- [ ] **Step 5: Commit** (from repo root, NOT from Godot/):

```bash
cd /Users/kuma/Projects/Polaris && git add Godot/core/PeekChat.gd Godot/tests/test_peek_chat.gd && git commit -m "$(cat <<'EOF'
feat(hunting): PeekChat.peek also returns to_you_chat (performance face)

His texts to her — needed for the side-by-side contrast. Shallow copy,
distinct ref; still never returns hidden_type/risk (the chat field is
the performance, not the truth). Empty-man safe.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `Peek.gd` + `Peek.tscn` + Loc — list ⇄ reveal

**Files:**
- Create: `Godot/ui/Peek.gd`
- Create: `Godot/scenes/Peek.tscn`
- Modify: `Godot/ui/Loc.gd` (append 8 keys)
- Create: `Godot/peek_ui_smoke.gd`

- [ ] **Step 1: Append the 8 zh keys** to `Godot/ui/Loc.gd`. Find the last entry inside the `ZH` dict — the line `	"That's enough reading for tonight.": "今晚读够了。",` immediately followed by the dict's closing `}`. Insert these 8 lines BETWEEN that entry and the closing `}` (so they are the new last entries inside `ZH`; do not modify any existing line):

```gdscript

	# ── Peek (看聊记 UI slice) ───────────────────────────────────────────────
	"PEEK_TITLE":        "开天眼",
	"PEEK_LIST_SUB":     "挑一个。看看他不演你的时候，是什么样。",
	"PEEK_ROW_LEAD":     "查聊记",
	"PEEK_REVEAL_SUB":   "同一个人。上面他对你说的，下面他对别人说的。你自己读。",
	"PEEK_TO_YOU":       "他对你说的",
	"PEEK_TO_OTHERS":    "他对别人说的",
	"PEEK_HINGE":        "—— 他不演你的时候 ——",
	"PEEK_BACK":         "返回",
```

- [ ] **Step 2: Write the failing headless smoke** — create `Godot/peek_ui_smoke.gd`:

```gdscript
extends SceneTree
const Content := preload("res://core/Content.gd")
const PeekChat := preload("res://core/PeekChat.gd")

func _initialize() -> void:
	var p = load("res://ui/Peek.gd").new()
	get_root().add_child(p)
	# list state builds nodes
	var list_nodes := p._layer.get_child_count()
	if list_nodes <= 0:
		print("PEEK UI SMOKE FAIL: list built no nodes")
		quit(1); return
	if p.state != "list":
		print("PEEK UI SMOKE FAIL: initial state not list")
		quit(1); return
	# reveal state for a known disguised man
	p.open_reveal("evan")
	if p.state != "reveal" or p.sel_id != "evan":
		print("PEEK UI SMOKE FAIL: open_reveal did not switch")
		quit(1); return
	if p._layer.get_child_count() <= 0:
		print("PEEK UI SMOKE FAIL: reveal built no nodes")
		quit(1); return
	# data wiring: reveal must be fed both faces from peek()
	var pk: Dictionary = PeekChat.peek(p._man("evan"))
	if (pk["to_you_chat"] as Array).size() < 1 or (pk["others_chat"] as Array).size() < 1:
		print("PEEK UI SMOKE FAIL: peek data not wired")
		quit(1); return
	# back returns to list
	p.back_to_list()
	if p.state != "list" or p.sel_id != "":
		print("PEEK UI SMOKE FAIL: back_to_list did not reset")
		quit(1); return
	print("PEEK UI SMOKE OK men=%d" % Content.men().size())
	quit(0)
```

- [ ] **Step 3: Run, verify it FAILS**

Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -5`
Expected: failure — `res://ui/Peek.gd` does not exist yet (load error / null), nonzero exit.

- [ ] **Step 4: Create `Godot/ui/Peek.gd`** with exactly:

```gdscript
extends Node
const Content := preload("res://core/Content.gd")
const PeekChat := preload("res://core/PeekChat.gd")
const UiKit := preload("res://ui/UiKit.gd")
const T := preload("res://ui/Theme.gd")
const Loc := preload("res://ui/Loc.gd")

var state: String = "list"      # "list" | "reveal"
var sel_id: String = ""
var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	_render()

func _man(id: String) -> Dictionary:
	for m in Content.men():
		if m["id"] == id:
			return m
	return {}

func open_reveal(id: String) -> void:
	sel_id = id
	state = "reveal"
	_render()

func back_to_list() -> void:
	state = "list"
	sel_id = ""
	_render()

func _render() -> void:
	for c in _layer.get_children():
		c.queue_free()
	var sig: String = "list" if state == "list" else "reveal:" + sel_id
	var r: Control = UiKit.screen(sig)
	if state == "list":
		_build_list(r)
	else:
		_build_reveal(r)
	_layer.add_child(r)

func _build_list(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	UiKit.label(r, "PEEK_TITLE", T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.label(r, "PEEK_LIST_SUB", T.PAD, T.PAD + 86, T.SMALL, T.DIM, W)
	var y: int = T.PAD + 220
	for m in Content.men():
		var mid: String = m["id"]
		var nm: String = str(m["name"])
		var lead: String = Loc.t("PEEK_ROW_LEAD")
		UiKit.btn(r, nm + "   ·   " + lead, T.PAD, y, W, T.BTN_H, func() -> void: open_reveal(mid))
		y += T.BTN_H + T.GAP

func _build_reveal(r: Control) -> void:
	var W: int = T.REF_W - T.PAD * 2
	var man: Dictionary = _man(sel_id)
	var p: Dictionary = PeekChat.peek(man)
	var to_you: Array = p.get("to_you_chat", [])
	var others: Array = p["others_chat"]
	UiKit.label(r, str(p["name"]), T.PAD, T.PAD, T.TITLE, T.ACCENT)
	UiKit.label(r, "PEEK_REVEAL_SUB", T.PAD, T.PAD + 86, T.SMALL, T.DIM, W)
	UiKit.btn(r, "PEEK_BACK", T.PAD, T.REF_H - 170, 300, 120, func() -> void: back_to_list())
	var top: int = T.PAD + 200
	var body: Control = UiKit.scroll(r, T.PAD, top, W, T.REF_H - top - 210)
	var y: int = 0
	y = _section(body, "PEEK_TO_YOU", to_you, y, false, W)
	y = _hinge(body, y, W)
	y = _section(body, "PEEK_TO_OTHERS", others, y, true, W)
	body.custom_minimum_size = Vector2(W, y)

# One block of bubbles. `show_to` = render the recipient tag under each bubble
# (used for the "to others" side). Never renders any 糖/料 verdict.
func _section(cv: Control, title_key: String, lines: Array, y0: int, show_to: bool, W: int) -> int:
	var y: int = y0
	UiKit.label(cv, title_key, 0, y, T.SMALL, T.DIM, W)
	y += 70
	var bw: int = int(float(W) * 0.84)
	for line in lines:
		var tx: String = str(line["text"])
		var pan: Panel = UiKit.panel(cv, 0, y, bw, 160)
		UiKit.label(pan, tx, 30, 26, T.BODY, T.TEXT, bw - 60)
		if show_to:
			var who: String = str(line.get("to", ""))
			if who != "":
				UiKit.label(cv, who, 8, y + 160 + 4, T.TINY, T.FAINT, bw)
				y += 160 + 4 + 38 + T.GAP
			else:
				y += 160 + T.GAP
		else:
			y += 160 + T.GAP
	return y + 28

func _hinge(cv: Control, y0: int, W: int) -> int:
	var y: int = y0 + 18
	var rule := ColorRect.new()
	rule.color = T.ACCENT
	rule.position = Vector2(0, y)
	rule.size = Vector2(W, 2)
	cv.add_child(rule)
	UiKit.label(cv, "PEEK_HINGE", 0, y + 18, T.SMALL, T.ACCENT, W)
	return y + 18 + 64 + 28
```

Notes baked in (GDScript 4.6 correctness): bracket Variant dict access (`m["id"]`, `line["text"]`, `p["others_chat"]`); typed locals for Variant returns (`var p: Dictionary = ...`, `var to_you: Array = ...`, never `:=` on those); the loop copies `m["id"]`/`m["name"]` into fresh per-iteration locals (`mid`/`nm`) BEFORE binding `mid` into the `func(): open_reveal(mid)` Callable (correct per-iteration capture); no `match`. Bubble height 160 fits every line in the current 3-man sample corpus (longest ≈ 60 chars wraps to ≤2 lines at BODY=40 within ~0.84·W); the scroll container makes vertical generosity harmless. Corpus mass-production (and any dynamic bubble sizing it would need) is explicitly out of this slice.

- [ ] **Step 5: Create `Godot/scenes/Peek.tscn`** with exactly (same shape as `Godot/scenes/Game.tscn`):

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/Peek.gd" id="1"]

[node name="Peek" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 6: Run the smoke, verify it PASSES**

Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -3`
Expected: `PEEK UI SMOKE OK men=3`, exit 0.

- [ ] **Step 7: Full suite still green**

Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -2`
Expected: `RAN 70 tests, 0 failures` (unchanged from Task 1 — this task adds no run_tests-registered tests).

- [ ] **Step 8: Commit** (from repo root):

```bash
cd /Users/kuma/Projects/Polaris && git add Godot/ui/Peek.gd Godot/scenes/Peek.tscn Godot/ui/Loc.gd Godot/peek_ui_smoke.gd && git commit -m "$(cat <<'EOF'
feat(hunting-ui): 看聊记 screen — list ⇄ reveal, his words to you vs others

Standalone Peek scene reusing Plan E UiKit/Theme. List = men rows (no
spoiler). Reveal = stacked chat bubbles 「他对你说的」/ hinge /「他对别人
说的」(with recipient tag), scrollable, no verdict. zh appended to Loc.
Headless peek_ui_smoke drives list⇄reveal. Hub/engine untouched.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Windowed sanity + screenshot helper + final gate

**Files:**
- Create: `Godot/peek_shot.gd`

- [ ] **Step 1: Create `Godot/peek_shot.gd`** (best-effort screenshot; mirrors Plan E `Godot/screenshot.gd`):

```gdscript
extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene := (load("res://scenes/Peek.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	# jump straight to the reveal so the screenshot shows the hook
	if scene.has_method("open_reveal"):
		scene.open_reveal("evan")
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var path := "res://peek_reveal.png"
	var err := img.save_png(path)
	if err == OK:
		print("PEEK SHOT OK ", ProjectSettings.globalize_path(path))
	else:
		print("PEEK SHOT FAIL err=", err)
	quit(0)
```

- [ ] **Step 2: Windowed sanity (best-effort)**

Run: `cd /Users/kuma/Projects/Polaris/Godot && timeout 12 /opt/homebrew/bin/godot --path . res://scenes/Peek.tscn ; echo "rc=$?"`
Pass condition: NO `SCRIPT ERROR` / parse `ERROR` lines in output; the scene initialized. `rc` may be `124` (timeout-killed healthy window) or `0` — both pass. If the box is headless-only and cannot open a window, that is acceptable — say so; the headless smoke + suite are authoritative. Quote the log tail.

- [ ] **Step 3: Screenshot (best-effort)**

Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --path . res://peek_shot.gd 2>&1 | tail -3 ; ls -la Godot/peek_reveal.png 2>/dev/null || ls -la peek_reveal.png 2>/dev/null || echo "(no PNG — no display; user runs locally)"`
If a non-trivial `peek_reveal.png` is produced, report its path/size. If no display, do NOT fail — report that visual confirmation needs `godot --path . res://scenes/Peek.tscn` locally. Do NOT `git add` any `.png` (add `peek_reveal.png` to `Godot/.gitignore` if not already ignored — `Godot/.gitignore` already ignores `reskin_home.png`; append `peek_reveal.png` on its own line).

- [ ] **Step 4: Final regression gate**

Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --quit; echo "boot=$?"; /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -2; /opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --script res://ui_smoke.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --script res://play.gd 2>&1 | tail -1`
Expected: `boot=0`; `RAN 70 tests, 0 failures`; `PEEK UI SMOKE OK men=3`; `HUB SMOKE OK day=2 dossier=3 reads=3` (Hub unaffected); play.gd ends with a `Season close.` line (engine unaffected).

- [ ] **Step 5: Commit** (from repo root):

```bash
cd /Users/kuma/Projects/Polaris && git add Godot/peek_shot.gd Godot/.gitignore && git commit -m "$(cat <<'EOF'
feat(hunting-ui): peek_shot screenshot helper + ignore generated png

Best-effort offscreen capture of the reveal (mirrors screenshot.gd).
Final gate: suite 70/0, peek/hub/play smokes green, hub & engine
unaffected. .png git-ignored.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review (plan author)

**Spec coverage:** §1 backend `to_you_chat` (shallow copy, never truth) → Task 1 (TDD, 3 tests incl. truth-still-hidden regression). §2 reveal screen (stacked 「他对你说的」/ 开天眼 hinge /「他对别人说的」 with `to` tag, chat bubbles, cold-premium reuse of UiKit/Theme, never-judge) → Task 2 `_build_reveal`/`_section`/`_hinge`. §3 minimal standalone entry (men list, no spoiler, list⇄reveal one scene) → Task 2 `_build_list` + `Peek.tscn`. §4 files/verification (Loc append-only, hub/engine/play/ui_smoke/tuning untouched, suite green, windowed + screenshot) → Tasks 2–3 + scope guard in File Structure. Deferred-by-spec (shell integration, dialogue, axes, cost, corpus, future-eye) → none built; explicitly excluded.

**Placeholder scan:** No TBD/TODO. Every code step is complete runnable GDScript incl. the full Peek.gd, the .tscn, the exact Loc lines, both helpers, and full test bodies. Expected outputs given; test count stated as 67→70 with "0 failures" as the stable contract.

**Type consistency:** `peek()` returns `{name, surface_claim, to_you_chat, others_chat}` in Task 1; consumed with those exact keys in Task 2 `_build_reveal` and the Task 2 smoke. `to_you_chat`/`others_chat` are `Array` of `{from,text}` / `{to,text}` respectively — `_section` reads `line["text"]` (both) and `line.get("to","")` (others only) consistently. `state`/`sel_id`/`_layer`/`open_reveal`/`back_to_list`/`_man` names identical across `Peek.gd`, `peek_ui_smoke.gd`, `peek_shot.gd`. `UiKit.screen(sig)`/`panel`/`label`/`btn`/`scroll` signatures match the current `Godot/ui/UiKit.gd`. Loc keys used in Peek.gd (`PEEK_TITLE/PEEK_LIST_SUB/PEEK_ROW_LEAD/PEEK_REVEAL_SUB/PEEK_TO_YOU/PEEK_TO_OTHERS/PEEK_HINGE/PEEK_BACK`) exactly match the 8 appended in Step 1; `Loc.t` returns the key itself if missing so a typo degrades gracefully (no crash), but all 8 are added.

**Scope:** One cohesive UI slice + one spec-safe backend field, 3 tasks. Produces a runnable, demoable screen on its own; hub-shell integration is a later slice (separate plan).
