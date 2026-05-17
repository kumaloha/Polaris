# Hunting Godot UI Layer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A playable Godot 4 UI layer on top of the existing headless `SeasonFlow` carry engine — a place to actually click through the full mainline loop (Ready Room → Girlfriend Night/Map → First Eye → Party read-loop → After-Party → Future Eye → next night → week settle → season close) and test the design. Baseline cold-premium styling, code-generated, **no art assets** (visuals will be re-skinned later from a reference app).

**Architecture:** Keep the engine core untouched and its batch `step_night()` + tests/play.gd intact. Add an **interactive sub-step API** on `SeasonFlow` so a UI can drive a night phase-by-phase (the batch path stays for headless tests). The UI is one `UIController` Node owning a `SeasonFlow`, a screen state machine, and code-generated `Control` screens — one screen at a time, portrait, vertical-mobile layout. UI is not unit-tested (it's presentation); verification = headless scene-load smoke + a scripted UI walkthrough + the existing 36-test suite staying green + manual play.

**Tech Stack:** Godot 4.6 GDScript, code-generated UGUI/`Control` nodes, no addons, no art. Reference resolution portrait 1170×2532.

**Source:** `docs/superpowers/specs/2026-05-17-hunting-carry-design.zh.md` (acceptability spine §1, visual direction). Engine on `main` at HEAD (post `47489b1`).

**Project-wide constraints (carried from the engine build, obey exactly):**
1. Test files use `extends "res://tests/test_base.gd"` (path, not `extends TestBase`); cross-refs path-based `preload(...)`.
2. "RAN N" counts are indicative; gate = `0 failures` + all spec assertions; may split test methods.
3. New commits only, never `--amend`. All balance numbers stay in `data/tuning.json` (none hardcoded in logic).
4. Pure engine core stays UI-free; UI code lives only under `Godot/ui/` + `Godot/scenes/`. Apply established Godot-4.6 typing fixes pre-emptively (typed local for `Tuning.num` Variant; bracket access on Variant-typed dicts).

---

## File Structure

```
Godot/
  core/SeasonFlow.gd          # MODIFY: add interactive sub-step API (batch step_night untouched)
  ui/
    Theme.gd                  # cold-premium palette + size constants
    Screens.gd                # pure builder funcs: one Control tree per screen
    UIController.gd           # Node: owns SeasonFlow, screen state machine, input → engine
  scenes/
    Game.tscn                 # root: UIController attached (the playable entry)
  tests/
    test_season_flow_interactive.gd   # TDD for the new sub-step API
  project.godot               # MODIFY: main scene → res://scenes/Game.tscn (Boot kept runnable)
  README.md                   # MODIFY: add "Play with UI" section
```

**Interactive API contract (Task 1 adds these to `SeasonFlow`, batch path unchanged):**

- `begin_night(self_invest_id: String, persona_id: String) -> void` — applies self-invest effect + persona effect to state; resets per-night transient (selected party/primary/backup/encounter/after-decisions); idempotent guard if already begun this night.
- `available_parties() -> Array` — Content.parties() filtered to `party.tier <= gf.available_tier()`, each `{id,name,tier,unlocked:bool, men:Array}` (locked ones included with `unlocked=false` for display).
- `choose_party(party_id: String) -> bool` — must be unlocked; stores it; false if invalid.
- `party_men() -> Array` — Content men for the chosen party (full man dicts).
- `set_primary(man_id) -> void`, `set_backup(man_id) -> void`.
- `start_party() -> PartyEncounter` — requires primary set; returns a fresh `PartyEncounter` for the primary man that the UI drives via `enc.act()` round-by-round; SeasonFlow records the actions taken (for control delta) as the UI reports them via `record_party_action(action)`.
- `record_party_action(action: String) -> void` — accumulates `int(ControlEngine.resolve({},action).control)` into the night's control delta (UI calls this each time it calls `enc.act`).
- `book_for_after() -> Array` — list of `{man_id, name, message, snark, held:bool}` = tonight's primary/backup + currently held positions, for the After-Party screen.
- `resolve_after(decisions: Dictionary) -> Array` — `{man_id: "date"|"observe"|"test"|"cut"}`; applies the same logic the batch path uses (book.open, Future Eye on date → keyframe/position/mirror/debt then cut, etc.); returns an Array of result dicts `{man_id, result, keyframes, mirror, energy_roi}` for any `date` (for the Future Eye screen), `[]` otherwise.
- `finish_night() -> Dictionary` — applies control delta, `book.advance_night()` events, energy regen, day+1, `_nights_this_week+1`; returns `{log, snapshot, insolvent, book_events}`.
- Existing `at_week_boundary()`, `settle()`, `at_season_boundary()`, `close_season()` reused as-is.

The batch `step_night(choices)` MUST remain and keep passing its existing test + play.gd.

---

### Task 1: SeasonFlow Interactive Sub-Step API

**Files:** Modify `Godot/core/SeasonFlow.gd`; Create `Godot/tests/test_season_flow_interactive.gd`; Modify `Godot/tests/run_tests.gd` (add the new test path to TESTS).

- [ ] **Step 1: Failing test** — `Godot/tests/test_season_flow_interactive.gd`:

```gdscript
extends "res://tests/test_base.gd"
const SF := preload("res://core/SeasonFlow.gd")

func test_begin_night_applies_self_invest_and_persona() -> void:
	var f = SF.new()
	var c0 = f.state.charm
	f.begin_night("beauty_care", "soft_sun")
	eq(f.state.charm, c0 + 2 + 1, "beauty_care +2 charm, soft_sun +1 charm")

func test_available_parties_gated_by_tier() -> void:
	var f = SF.new()
	f.begin_night("solo_reset", "rare_girl")
	var ps = f.available_parties()
	var rooftop = null
	for p in ps:
		if p.id == "rooftop": rooftop = p
	ok(rooftop != null and rooftop.unlocked, "rooftop tier1 unlocked at start")
	var founders = null
	for p in ps:
		if p.id == "founders": founders = p
	ok(founders != null and not founders.unlocked, "founders locked at start")

func test_party_drive_and_after_date_returns_future_eye() -> void:
	var f = SF.new()
	f.begin_night("solo_reset", "rare_girl")
	ok(f.choose_party("rooftop"), "choose unlocked rooftop")
	f.set_primary("adrian")
	var enc = f.start_party()
	ok(enc != null, "start_party returns an encounter")
	for i in range(enc.total_rounds):
		var r = enc.act("boundary")
		f.record_party_action("boundary")
	var results = f.resolve_after({"adrian": "date"})
	eq(results.size(), 1, "one date result for future eye")
	ok(results[0].has("result") and results[0].has("keyframes"), "future eye payload present")
	var fin = f.finish_night()
	eq(f.state.day, 2, "night finished, day advanced")
	ok(fin.has("snapshot"), "finish returns snapshot")

func test_batch_step_night_still_works() -> void:
	var f = SF.new()
	var r = f.step_night({"self_invest": "solo_reset", "primary": "leo",
		"party_actions": ["exit"], "after": {"leo": "observe"}})
	eq(f.state.day, 2, "batch path intact")
	ok(r.has("log"), "batch returns log")
```

- [ ] **Step 2: Run, verify red** — `cd Godot && godot --headless --script res://tests/run_tests.gd`; expect new failures (methods missing) AND the existing 35 still listed.

- [ ] **Step 3: Implement** — append to `Godot/core/SeasonFlow.gd` (do NOT modify `step_night`/`settle`/`close_season`/`at_*`; add fields + methods). Add near the other `var` declarations:

```gdscript
var _np_self_invest: String = ""
var _np_persona: String = ""
var _np_party: String = ""
var _np_primary: String = ""
var _np_backup: String = ""
var _np_control_delta: int = 0
var _np_begun: bool = false
```

Add these methods (Content has `personas()` with `{id,effect,...}`):

```gdscript
func _persona(id: String) -> Dictionary:
	for p in Content.personas():
		if p.id == id: return p
	return {}

func begin_night(self_invest_id: String, persona_id: String) -> void:
	if _np_begun: return
	_np_begun = true
	_np_self_invest = self_invest_id
	_np_persona = persona_id
	_np_party = ""
	_np_primary = ""
	_np_backup = ""
	_np_control_delta = 0
	for c in Content.self_investments():
		if c.id == self_invest_id:
			state.apply(c.effect)
	var p = _persona(persona_id)
	if p.has("effect"):
		state.apply(p.effect)

func available_parties() -> Array:
	var tier: int = gf.available_tier()
	var out := []
	for p in Content.parties():
		var pt: int = p.tier
		out.append({"id": p.id, "name": p.name, "tier": pt,
			"unlocked": pt <= tier, "men": p.men})
	return out

func choose_party(party_id: String) -> bool:
	for p in available_parties():
		if p.id == party_id and p.unlocked:
			_np_party = party_id
			return true
	return false

func party_men() -> Array:
	var ids := []
	for p in Content.parties():
		if p.id == _np_party: ids = p.men
	var out := []
	for m in Content.men():
		if m.id in ids: out.append(m)
	return out

func set_primary(man_id: String) -> void:
	_np_primary = man_id

func set_backup(man_id: String) -> void:
	_np_backup = man_id

func start_party() -> PartyEncounter:
	if _np_primary == "": return null
	return PartyEncounter.new(_man(_np_primary))

func record_party_action(action: String) -> void:
	var ce = ControlEngine.resolve({}, action)
	_np_control_delta += int(ce.control)

func book_for_after() -> Array:
	var out := []
	var seen := {}
	for mid in [_np_primary, _np_backup]:
		if mid != "" and not seen.has(mid):
			seen[mid] = true
			var m = _man(mid)
			out.append({"man_id": mid, "name": m.get("name", mid),
				"message": m.get("chat", [{}])[0].get("text", ""),
				"snark": "Watch what he does, not what he says.",
				"held": false})
	for pos in book.positions():
		if not seen.has(pos.man):
			seen[pos.man] = true
			var hm = _man(pos.man)
			out.append({"man_id": pos.man, "name": hm.get("name", pos.man),
				"message": "(still on your book: %s)" % pos.decision,
				"snark": "Still carrying this one.", "held": true})
	return out

func resolve_after(decisions: Dictionary) -> Array:
	var results := []
	for man_id in decisions.keys():
		var decision: String = decisions[man_id]
		var ht: String = _man(man_id)["hidden_type"]
		book.open(man_id, decision, ht)
		if decision == "date":
			var fe = FutureEye.resolve(ht, "date", state.control, "any")
			state.keyframes.append({"man": man_id, "result": fe.result})
			if fe.result == "Correct Read":
				state.apply({"position": 1})
			if str(fe.mirror) != "":
				log_lines.append("[MIRROR] " + str(fe.mirror))
			if fe.fantasy_debt > 0:
				state.debts.append({"man": man_id, "amount": fe.fantasy_debt})
			book.decide(man_id, "cut")
			results.append({"man_id": man_id, "result": fe.result,
				"keyframes": fe.keyframes, "mirror": str(fe.mirror),
				"energy_roi": fe.energy_roi})
	return results

func finish_night() -> Dictionary:
	state.apply({"control": _np_control_delta})
	var events := book.advance_night()
	for ev in events:
		log_lines.append("[BOOK] %s: %s" % [ev.man, ev.event])
	var regen: int = Tuning.num("energy.regen_per_night", 2)
	state.apply({"energy": regen})
	state.day += 1
	_nights_this_week += 1
	_np_begun = false
	return {"log": log_lines, "snapshot": state.snapshot(),
		"insolvent": SoftRuin.is_insolvent(state), "book_events": events}
```

Also add `"res://tests/test_season_flow_interactive.gd"` to the `TESTS` array in `Godot/tests/run_tests.gd`.

- [ ] **Step 4: Run, verify green** — `cd Godot && godot --headless --script res://tests/run_tests.gd` → `0 failures`, exit 0 (≈`RAN 39 tests`). Also `cd Godot && godot --headless --script res://play.gd` → still exits 0 and coherent (batch path unbroken).

- [ ] **Step 5: Commit**

```bash
git add Godot/core/SeasonFlow.gd Godot/tests/test_season_flow_interactive.gd Godot/tests/run_tests.gd
git commit -m "feat(hunting-be): SeasonFlow interactive sub-step API for UI

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: UI Theme + Controller Scaffold

**Files:** Create `Godot/ui/Theme.gd`, `Godot/ui/UIController.gd`, `Godot/scenes/Game.tscn`; Modify `Godot/project.godot` (main scene → Game.tscn).

- [ ] **Step 1: Theme** — `Godot/ui/Theme.gd`:

```gdscript
extends RefCounted
class_name UiTheme
const BG_TOP := Color(0.05, 0.05, 0.08)
const BG_BOT := Color(0.02, 0.02, 0.03)
const PANEL := Color(0.10, 0.10, 0.14, 0.92)
const PANEL_SEL := Color(0.20, 0.17, 0.12, 0.96)
const TEXT := Color(0.93, 0.93, 0.96)
const DIM := Color(0.60, 0.60, 0.66)
const ACCENT := Color(0.79, 0.64, 0.42)
const REF_W := 1170
const REF_H := 2532
const PAD := 56
const GAP := 28
const BTN_H := 150
const CARD_H := 200
const TITLE := 66
const BODY := 42
const SMALL := 34
```

- [ ] **Step 2: Controller** — `Godot/ui/UIController.gd`:

```gdscript
extends Node
const SeasonFlow := preload("res://core/SeasonFlow.gd")
const Screens := preload("res://ui/Screens.gd")

enum S { READY, MAP, FIRST_EYE, PARTY, AFTER, FUTURE, WEEK, SEASON_END }

var flow
var screen: int = S.READY
var ui: Dictionary = {}          # transient per-screen selections
var enc = null                   # active PartyEncounter
var party_log: Array = []
var future_payload: Array = []
var _layer: CanvasLayer

func _ready() -> void:
	flow = SeasonFlow.new()
	_layer = CanvasLayer.new()
	add_child(_layer)
	_render()

func go(next_screen: int) -> void:
	screen = next_screen
	_render()

func _render() -> void:
	for c in _layer.get_children():
		c.queue_free()
	_layer.add_child(Screens.build(self))

# --- transitions invoked by Screens button callbacks ---
func act_begin_night() -> void:
	flow.begin_night(ui.get("self_invest", "solo_reset"), ui.get("persona", "rare_girl"))
	go(S.MAP)

func act_choose_party(pid: String) -> void:
	if flow.choose_party(pid):
		go(S.FIRST_EYE)

func act_enter_party(primary_id: String) -> void:
	flow.set_primary(primary_id)
	enc = flow.start_party()
	party_log = []
	if enc == null:
		return
	go(S.PARTY)

func act_party(action: String) -> void:
	if enc == null or enc.finished:
		return
	var r = enc.act(action)
	flow.record_party_action(action)
	if r.has("tell") and r.tell != "":
		party_log.append(r.tell)
	if enc.finished:
		go(S.AFTER)
	else:
		_render()

func act_after(decisions: Dictionary) -> void:
	future_payload = flow.resolve_after(decisions)
	var fin = flow.finish_night()
	party_log = fin.log
	if not future_payload.is_empty():
		go(S.FUTURE)
	else:
		_after_future()

func _after_future() -> void:
	if flow.at_week_boundary():
		ui["settle"] = flow.settle()
		if flow.at_season_boundary():
			ui["close"] = flow.close_season()
			go(S.SEASON_END)
		else:
			go(S.WEEK)
	else:
		go(S.READY)

func act_continue_from_future() -> void:
	_after_future()

func act_next_night() -> void:
	go(S.READY)
```

- [ ] **Step 3: Scene** — `Godot/scenes/Game.tscn`:

```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://ui/UIController.gd" id="1"]
[node name="Game" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 4: project.godot main scene** — set `run/main_scene="res://scenes/Game.tscn"` (Boot.tscn stays in repo and still runnable via `--script`; only the default scene changes).

- [ ] **Step 5: Verify scene loads headless** — `cd Godot && godot --headless --quit` → exit 0, no parse errors (UIController `_ready` runs; Screens.build will exist after Task 3 — if Task 3 not yet done this errors, so this step's full pass is gated on Task 3; for now confirm Theme.gd + UIController.gd + scene parse with no syntax error via `godot --headless --check-only` style: run `godot --headless --quit` and confirm the only error, if any, is the missing `Screens.gd`). Tests must still pass: `cd Godot && godot --headless --script res://tests/run_tests.gd` → `0 failures`.

- [ ] **Step 6: Commit**

```bash
git add Godot/ui/Theme.gd Godot/ui/UIController.gd Godot/scenes/Game.tscn Godot/project.godot
git commit -m "feat(hunting-ui): theme + controller scaffold + game scene

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Screen Renderers (6 screens + week/season cards)

**Files:** Create `Godot/ui/Screens.gd`.

`Screens.build(ctrl)` returns one root `Control` for `ctrl.screen`. All screens: full-rect gradient bg, ambient HUD strip, big bottom CTA(s); no tables/meters; one decision per screen.

- [ ] **Step 1: Implement** — `Godot/ui/Screens.gd`:

```gdscript
extends RefCounted
class_name Screens
const T := preload("res://ui/Theme.gd")
const Content := preload("res://core/Content.gd")

static func _root() -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = T.BG_TOP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(bg)
	return r

static func _label(parent: Control, text: String, x: int, y: int, size: int, col: Color, w := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.position = Vector2(x, y)
	if w > 0:
		l.size = Vector2(w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

static func _btn(parent: Control, text: String, x: int, y: int, w: int, h: int, cb: Callable, selected := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", T.BODY)
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = T.PANEL_SEL if selected else T.PANEL
	sb.border_color = T.ACCENT
	sb.set_border_width_all(2 if selected else 0)
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color", T.TEXT)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

static func _hud(parent: Control, ctrl) -> void:
	var s = ctrl.flow.state.snapshot()
	var txt := "DAY %d   ·   S%d W%d   ·   ⚡%d   ✦%d   ▲%d   ◆%d   ₪ net %d" % [
		s.day, s.season, s.week, s.energy, s.charm, s.position, s.control, s.net_worth]
	_label(parent, txt, T.PAD, T.PAD, T.SMALL, T.DIM)

static func build(ctrl) -> Control:
	var r := _root()
	_hud(r, ctrl)
	var W: int = T.REF_W - T.PAD * 2
	match ctrl.screen:
		ctrl.S.READY:
			_label(r, "READY ROOM", T.PAD, 200, T.TITLE, T.ACCENT)
			_label(r, "Invest in yourself before you walk in. You decide who's worth your energy.", T.PAD, 290, T.SMALL, T.DIM, W)
			var y := 430
			_label(r, "TONIGHT'S BUILD", T.PAD, y, T.SMALL, T.DIM); y += 60
			for c in Content.self_investments():
				var sel: bool = ctrl.ui.get("self_invest", "") == c.id
				_btn(r, "%s" % c.name, T.PAD, y, W, T.BTN_H,
					func(): ctrl.ui["self_invest"] = c.id; ctrl._render(), sel)
				y += T.BTN_H + 18
			y += 20
			_label(r, "PERSONA", T.PAD, y, T.SMALL, T.DIM); y += 60
			for p in Content.personas():
				var ps: bool = ctrl.ui.get("persona", "") == p.id
				_btn(r, p.name, T.PAD, y, W, T.BTN_H,
					func(): ctrl.ui["persona"] = p.id; ctrl._render(), ps)
				y += T.BTN_H + 18
			_btn(r, "GO TO GIRLFRIEND NIGHT  →", T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
				func(): ctrl.act_begin_night())
		ctrl.S.MAP:
			_label(r, "GIRLFRIEND NIGHT", T.PAD, 200, T.TITLE, T.ACCENT)
			_label(r, "Your circle decides which rooms you get into.", T.PAD, 290, T.SMALL, T.DIM, W)
			var y := 420
			for gfx in Content.girlfriends():
				_label(r, "%s — %s" % [gfx.name, gfx.role], T.PAD, y, T.BODY, T.TEXT); y += 70
			y += 30
			_label(r, "PARTY MAP", T.PAD, y, T.SMALL, T.DIM); y += 60
			for p in ctrl.flow.available_parties():
				var tag: String = "" if p.unlocked else "  · LOCKED (tier %d)" % p.tier
				if p.unlocked:
					_btn(r, p.name + tag, T.PAD, y, W, T.BTN_H,
						func(): ctrl.act_choose_party(p.id))
				else:
					var lb := _btn(r, p.name + tag, T.PAD, y, W, T.BTN_H, func(): pass)
					lb.disabled = true
				y += T.BTN_H + 18
		ctrl.S.FIRST_EYE:
			_label(r, "FIRST EYE", T.PAD, 200, T.TITLE, T.ACCENT)
			_label(r, "Surface only. The truth is in the signs, not the words.", T.PAD, 290, T.SMALL, T.DIM, W)
			var y := 420
			for m in ctrl.flow.party_men():
				var line := "%s   ·   %s\nrisk: %s\n\"%s\"" % [m.name, m.surface, m.risk, m.chat[0].text]
				_btn(r, line, T.PAD, y, W, T.CARD_H + 60,
					func(): ctrl.act_enter_party(m.id))
				y += T.CARD_H + 80
		ctrl.S.PARTY:
			var st = ctrl.enc.read()
			_label(r, "PARTY  ·  round %d / %d" % [st.round, st.of], T.PAD, 200, T.TITLE, T.ACCENT)
			var ly := 330
			for line in ctrl.party_log:
				_label(r, "“" + line + "”", T.PAD, ly, T.BODY, T.TEXT, W); ly += 130
			var by := T.REF_H - (T.BTN_H + 18) * 4 - T.PAD
			for a in ["engage", "boundary", "social_proof", "exit"]:
				var act := a
				_btn(r, act.to_upper().replace("_", " "), T.PAD, by, W, T.BTN_H,
					func(): ctrl.act_party(act))
				by += T.BTN_H + 18
		ctrl.S.AFTER:
			_label(r, "AFTER PARTY", T.PAD, 200, T.TITLE, T.ACCENT)
			_label(r, "Decide where your energy goes. You can only Date one.", T.PAD, 290, T.SMALL, T.DIM, W)
			if not ctrl.ui.has("after"): ctrl.ui["after"] = {}
			var y := 420
			for entry in ctrl.flow.book_for_after():
				_label(r, "%s: \"%s\"  — %s" % [entry.name, entry.message, entry.snark], T.PAD, y, T.SMALL, T.DIM, W)
				y += 90
				var bx := T.PAD
				var bw := (W - T.GAP * 3) / 4
				for ch in ["date", "observe", "test", "cut"]:
					var mid := entry.man_id
					var choice := ch
					var seld: bool = ctrl.ui["after"].get(mid, "") == choice
					_btn(r, choice, bx, y, bw, T.BTN_H,
						func(): ctrl.ui["after"][mid] = choice; ctrl._render(), seld)
					bx += bw + T.GAP
				y += T.BTN_H + 40
			_btn(r, "CONFIRM  →", T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
				func(): ctrl.act_after(ctrl.ui["after"]))
		ctrl.S.FUTURE:
			_label(r, "FUTURE EYE", T.PAD, 200, T.TITLE, T.ACCENT)
			var y := 320
			for fp in ctrl.future_payload:
				_label(r, "%s — %s" % [fp.man_id, fp.result], T.PAD, y, T.BODY, T.ACCENT); y += 80
				for kf in fp.keyframes:
					_label(r, "·  " + str(kf), T.PAD + 20, y, T.SMALL, T.TEXT, W - 20); y += 56
				if str(fp.mirror) != "":
					y += 20
					_label(r, fp.mirror, T.PAD, y, T.SMALL, Color(0.85, 0.35, 0.35), W); y += 110
				y += 40
			_btn(r, "CONTINUE  →", T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
				func(): ctrl.act_continue_from_future())
		ctrl.S.WEEK:
			var stl = ctrl.ui.get("settle", {})
			_label(r, "WEEK SETTLEMENT", T.PAD, 260, T.TITLE, T.ACCENT)
			_label(r, "Net worth %s  ·  keyframes %s  ·  debts %s" % [
				str(stl.get("net_worth", 0)), str(stl.get("keyframes", 0)), str(stl.get("debts", 0))],
				T.PAD, 380, T.BODY, T.TEXT, W)
			_btn(r, "NEXT WEEK  →", T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
				func(): ctrl.act_next_night())
		ctrl.S.SEASON_END:
			var cl = ctrl.ui.get("close", {})
			_label(r, "SEASON CLOSE", T.PAD, 260, T.TITLE, T.ACCENT)
			_label(r, "Your year, your call.", T.PAD, 360, T.BODY, T.DIM, W)
			_label(r, "Carried — dossier %s  ·  standing %s" % [
				str((cl.get("dossier", []) as Array).size()), str(cl.get("position", 0))],
				T.PAD, 460, T.BODY, T.TEXT, W)
			_btn(r, "NEW SEASON  →", T.PAD, T.REF_H - T.BTN_H - T.PAD, W, T.BTN_H,
				func(): ctrl.act_next_night())
		_:
			_label(r, "…", T.PAD, 300, T.TITLE, T.TEXT)
	return r
```

- [ ] **Step 2: Verify scene loads + tests green** — `cd Godot && godot --headless --quit` → exit 0, log shows no parse errors and the scene instantiates (UIController `_ready` builds the READY screen without error). `cd Godot && godot --headless --script res://tests/run_tests.gd` → `0 failures`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add Godot/ui/Screens.gd
git commit -m "feat(hunting-ui): 6 code-generated screens + settlement cards

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Walkthrough Smoke + Docs

**Files:** Create `Godot/ui_smoke.gd`; Modify `Godot/README.md`.

- [ ] **Step 1: Headless UI smoke** — `Godot/ui_smoke.gd` instantiates the scene, drives one full night programmatically via the controller's `act_*` methods (begin → choose rooftop → primary adrian → 5×party boundary → after {adrian:date} → continue), asserts no error and `flow.state.day == 2`, prints `UI SMOKE OK`, `quit(0)`:

```gdscript
extends SceneTree
func _initialize() -> void:
	var scene = load("res://scenes/Game.tscn").instantiate()
	get_root().add_child(scene)
	var c = scene
	c.ui["self_invest"] = "solo_reset"
	c.ui["persona"] = "rare_girl"
	c.act_begin_night()
	c.act_choose_party("rooftop")
	c.act_enter_party("adrian")
	while c.enc != null and not c.enc.finished:
		c.act_party("boundary")
	c.ui["after"] = {"adrian": "date"}
	c.act_after(c.ui["after"])
	c.act_continue_from_future()
	assert(c.flow.state.day >= 2, "a full night completed")
	print("UI SMOKE OK day=%d screen=%d" % [c.flow.state.day, c.screen])
	quit(0)
```

- [ ] **Step 2: Run smoke** — `cd Godot && godot --headless --script res://ui_smoke.gd` → prints `UI SMOKE OK day=2 ...`, exit 0. If it errors, fix the real cause (UI callback wiring / screen state) — do not weaken the assert. Re-run the full suite `cd Godot && godot --headless --script res://tests/run_tests.gd` → `0 failures`.

- [ ] **Step 3: README** — add to `Godot/README.md`:

```markdown
## Play with UI (interactive)

Open the project in Godot 4.6 and press Play, or:
`godot --path . res://scenes/Game.tscn`

Click through: Ready Room → Girlfriend Night → First Eye → Party (5 rounds) → After Party → Future Eye → repeat. Headless UI smoke: `godot --headless --script res://ui_smoke.gd`.
Visuals are a code-generated baseline (cold-premium, no art); to be re-skinned from a reference app later.
```

- [ ] **Step 4: Commit**

```bash
git add Godot/ui_smoke.gd Godot/README.md
git commit -m "feat(hunting-ui): headless UI walkthrough smoke + docs

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (plan author)

**Spec coverage:** the 6 mainline screens (Ready/Map/FirstEye/Party/After/Future) + week/season cards, all wired to the real engine via a new interactive sub-step API that leaves the batch `step_night` + 35 tests + play.gd intact. Acceptability spine honored at the UI-copy level (defensive framing strings, no meters, "you decide who's worth your energy"). Visual = code-gen cold-premium baseline, explicitly stated as re-skin-later (matches user's "find an app to copy UI from").

**Placeholder scan:** no TBD; every step has complete code/commands. Visual polish intentionally minimal (user-directed).

**Type consistency:** UIController enum `S`, `flow`/`enc`/`ui`/`screen`/`party_log`/`future_payload` used identically across Screens + smoke; SeasonFlow interactive methods match the contract and the Task-1 test; established Godot-4.6 typing fixes pre-applied.

**Scope:** one cohesive UI layer; appropriately 4 tasks (engine API is the only TDD part; UI verified by smoke + manual).

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-05-17-hunting-godot-ui-layer.md`. Subagent-driven execution (per the established workflow). Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review (spec then quality) between tasks. Task 1 is TDD logic (full review); Tasks 2–4 are UI (spec review + a lighter quality pass since presentation is re-skin-later).
2. **Inline** — execute here with checkpoints.
