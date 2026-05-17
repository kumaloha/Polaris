# Hunting Plan B — Hub Shell UI (Home + bottom nav + routing)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`).

**Goal:** Replace the linear 8-screen `UIController`/`Screens` flow with the **hub IA**: a persistent Home shell (player avatar + energy/stat HUD) and a 6-tab bottom nav routing to "faces". Plan B delivers the **shell + routing + the 3 playable faces** (自我提升 / 派对 / 约会) reusing the existing engine API so a full night is walkable through the hub; the net-new face *content* (社交媒体 funnel UI, 集卡, 资产清单) are **stub faces** filled by Plan C.

**Architecture:** New `ui/UiKit.gd` (shared primitives, extracted from old `Screens.gd`), new `ui/Hub.gd` (scene root: owns `SeasonFlow`, current face, soft-daily-cycle phase; renders persistent chrome + active face), new `ui/Faces.gd` (per-face content builders). `scenes/Game.tscn` → `Hub.gd`. Old `ui/UIController.gd` + `ui/Screens.gd` deleted. `ui/Theme.gd` + `ui/Loc.gd` reused unchanged (Loc gets new keys appended only). **Engine (`core/*`, `tests/*`, `play.gd`) is NOT touched** — UI-only; the 56 engine tests stay green.

**Soft daily cycle (spec §2/§5, choice a):** free-roam hub. A "night" begins (lazily) the first time the player enters 派对 in a cycle (`flow.begin_night(self_invest, persona)` using the build chosen in 自我提升, defaults if unset); party → 约会 (`resolve_after`) → `finish_night` → if `at_week_boundary()` → `settle()` (and `at_season_boundary()` → `close_season()`), surfaced as a settlement overlay; then a fresh cycle. `Energy` (shown as the Home energy bar) is the governor.

**Design constraints carried from Plan A final review (honor in this UI):**
1. `compose_post` permanently mutates state — Plan B does NOT expose posting yet (social face is a stub); when Plan C wires it, posting must be **one per night** (engine already guards `_np_posted`; UI must not offer repeat-post). Documented here so Plan C honors it.
2. Posting raises Standing and can trip the gf-lead in the same call — intended; Plan C concern.

**Tech Stack:** Godot 4.6 GDScript, code-gen UI, portrait 1170×2532 (project.godot `[display]` already set), no art. Loc zh.

**Source:** `docs/superpowers/specs/2026-05-17-hunting-hub-ia-design.zh.md` §3/§4/§5/§8 Plan B. Engine on `main` HEAD `532136b`.

**Project-wide constraints:** test/path-extends rules as before; new commit only; **UI-only — zero `core/`/`tests/`/`play.gd` change** (verify via diff each task); Godot-4.6 typing fixes pre-applied (bracket access on Variant dicts; `UiThing.X` constants for `match` patterns; per-iteration lambda-capture locals).

---

## Engine API the faces consume (already on `main`, do NOT modify)

`SeasonFlow.new()`; `state` (GameState: `.day/.week/.season/.energy/.charm/.position/.control`, `snapshot()`, `net_worth()`, `dossier:Array`); `begin_night(self_invest_id, persona_id)`; `apply_outfit(id)`/`apply_workout(id)`; `available_parties()`→`[{id,name,tier,unlocked,men}]`; `choose_party(id)->bool`; `party_men()`→man dicts; `set_primary(id)`; `start_party()->PartyEncounter`(`.act(a)->{tell,...}`,`.read()->{round,of,...}`,`.finished`,`.total_rounds`); `record_party_action(a)`; `book_for_after()`→`[{man_id,name,message,snark,held}]`; `resolve_after(decisions)->Array` of `{man_id,result,keyframes,mirror,energy_roi}`; `finish_night()->{log,snapshot,insolvent,book_events}`; `at_week_boundary()->bool`; `settle()->{net_worth,week,keyframes,debts}`; `at_season_boundary()->bool`; `close_season()->{dossier,gf_warmth,position}`; `Content.self_investments()/personas()/outfits()/workouts()/girlfriends()`.

---

### Task 1: UiKit + Hub + Faces (shell, nav, 3 playable + 3 stub faces); swap scene; delete old UI

**Files:** Create `Godot/ui/UiKit.gd`, `Godot/ui/Hub.gd`, `Godot/ui/Faces.gd`; Modify `Godot/ui/Loc.gd` (append keys only); Modify `Godot/scenes/Game.tscn`; Delete `Godot/ui/UIController.gd`, `Godot/ui/Screens.gd`.

- [ ] **Step 1: UiKit (extract primitives)** — `Godot/ui/UiKit.gd`:
```gdscript
extends RefCounted
class_name UiKit
const T := preload("res://ui/Theme.gd")
const Loc := preload("res://ui/Loc.gd")
static func root() -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = T.BG_TOP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(bg)
	return r
static func label(p: Control, text: String, x: int, y: int, sz: int, col: Color, w := 0) -> Label:
	var l := Label.new()
	l.text = Loc.t(text)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.position = Vector2(x, y)
	if w > 0:
		l.size = Vector2(w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	return l
static func btn(p: Control, text: String, x: int, y: int, w: int, h: int, cb: Callable, sel := false) -> Button:
	var b := Button.new()
	b.text = Loc.t(text)
	b.add_theme_font_size_override("font_size", T.BODY)
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = T.PANEL_SEL if sel else T.PANEL
	sb.border_color = T.ACCENT
	sb.set_border_width_all(2 if sel else 0)
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color", T.TEXT)
	b.pressed.connect(cb)
	p.add_child(b)
	return b
```

- [ ] **Step 2: Hub controller** — `Godot/ui/Hub.gd`:
```gdscript
extends Node
const SeasonFlow := preload("res://core/SeasonFlow.gd")
const Faces := preload("res://ui/Faces.gd")
const T := preload("res://ui/Theme.gd")
const UiKit := preload("res://ui/UiKit.gd")

enum F { HOME, SELF, SOCIAL, PARTY, DATING, CARDS, ASSETS }

var flow
var face: int = F.HOME
var ui: Dictionary = {}          # transient: self_invest, persona, outfit, workout, after, settle, close
var enc = null
var party_log: Array = []
var future_payload: Array = []
var night_open: bool = false     # has begin_night run for the current cycle
var overlay: String = ""         # "", "settle", "season"
var _layer: CanvasLayer

func _ready() -> void:
	flow = SeasonFlow.new()
	_layer = CanvasLayer.new()
	add_child(_layer)
	_render()

func go_face(f: int) -> void:
	face = f
	overlay = ""
	_render()

func _render() -> void:
	for c in _layer.get_children():
		c.queue_free()
	_layer.add_child(Faces.build(self))

# --- soft daily cycle helpers ---
func ensure_night() -> void:
	if not night_open:
		flow.begin_night(ui.get("self_invest", "solo_reset"), ui.get("persona", "rare_girl"))
		if ui.has("outfit"): flow.apply_outfit(ui["outfit"])
		if ui.has("workout"): flow.apply_workout(ui["workout"])
		night_open = true

func act_choose_party(pid: String) -> void:
	ensure_night()
	if flow.choose_party(pid):
		_render()

func act_enter_party(primary_id: String) -> void:
	flow.set_primary(primary_id)
	enc = flow.start_party()
	party_log = []
	if enc == null: return
	_render()

func act_party(action: String) -> void:
	if enc == null or enc.finished: return
	var r = enc.act(action)
	flow.record_party_action(action)
	if r.has("tell") and r.tell != "": party_log.append(r.tell)
	if enc.finished:
		go_face(F.DATING)
	else:
		_render()

func act_after(decisions: Dictionary) -> void:
	future_payload = flow.resolve_after(decisions)
	var fin = flow.finish_night()
	party_log = fin.log
	night_open = false
	enc = null
	if not future_payload.is_empty():
		ui["show_future"] = true
		_render()
	else:
		_post_night()

func dismiss_future() -> void:
	ui["show_future"] = false
	_post_night()

func _post_night() -> void:
	if flow.at_week_boundary():
		ui["settle"] = flow.settle()
		if flow.at_season_boundary():
			ui["close"] = flow.close_season()
			overlay = "season"
		else:
			overlay = "settle"
	go_face(F.HOME) if overlay == "" else _render()

func dismiss_overlay() -> void:
	overlay = ""
	go_face(F.HOME)
```

- [ ] **Step 3: Faces** — `Godot/ui/Faces.gd` (persistent chrome: top HUD + Home avatar block + bottom 6-tab nav; center = active face; settlement overlays). Reuses UiKit; all strings via Loc:
```gdscript
extends RefCounted
class_name Faces
const T := preload("res://ui/Theme.gd")
const K := preload("res://ui/UiKit.gd")
const Content := preload("res://core/Content.gd")
const Hub := preload("res://ui/Hub.gd")

static func _hud(r: Control, h) -> void:
	var s = h.flow.state.snapshot()
	K.label(r, "DAY %d  ·  S%d W%d  ·  net %d" % [s.day, s.season, s.week, s.net_worth], T.PAD, T.PAD, T.SMALL, T.DIM)
	# energy bar = opportunity cost
	var bw := T.REF_W - T.PAD * 2
	var bar := ColorRect.new()
	bar.color = T.PANEL
	bar.position = Vector2(T.PAD, T.PAD + 60)
	bar.size = Vector2(bw, 28)
	r.add_child(bar)
	var fillw := int(clamp(float(s.energy) / 16.0, 0.0, 1.0) * bw)
	var fill := ColorRect.new()
	fill.color = T.ACCENT
	fill.position = Vector2(T.PAD, T.PAD + 60)
	fill.size = Vector2(fillw, 28)
	r.add_child(fill)
	K.label(r, "ENERGY %d" % s.energy, T.PAD, T.PAD + 96, T.SMALL, T.DIM)

static func _nav(r: Control, h) -> void:
	var tabs := [["SELF", Hub.F.SELF], ["SOCIAL", Hub.F.SOCIAL], ["PARTY", Hub.F.PARTY],
		["DATING", Hub.F.DATING], ["CARDS", Hub.F.CARDS], ["ASSETS", Hub.F.ASSETS]]
	var n := tabs.size()
	var gap := 12
	var bw := (T.REF_W - T.PAD * 2 - gap * (n - 1)) / n
	var y := T.REF_H - 160
	for i in range(n):
		var entry = tabs[i]
		var fid: int = entry[1]
		K.btn(r, entry[0], T.PAD + i * (bw + gap), y, bw, 130,
			func(): h.go_face(fid), h.face == fid)

static func build(h) -> Control:
	var r := K.root()
	_hud(r, h)
	var W: int = T.REF_W - T.PAD * 2
	# overlays take over the center
	if h.overlay == "settle" or h.overlay == "season":
		var d = h.ui.get("settle", {})
		K.label(r, "WEEK SETTLEMENT" if h.overlay == "settle" else "SEASON CLOSE", T.PAD, 360, T.TITLE, T.ACCENT)
		K.label(r, "net %s · keyframes %s · debts %s" % [str(d.get("net_worth",0)), str(d.get("keyframes",0)), str(d.get("debts",0))], T.PAD, 470, T.BODY, T.TEXT, W)
		K.btn(r, "CONTINUE  →", T.PAD, T.REF_H - 330, W, T.BTN_H, func(): h.dismiss_overlay())
		return r
	if h.ui.get("show_future", false):
		K.label(r, "FUTURE EYE", T.PAD, 220, T.TITLE, T.ACCENT)
		var y := 320
		for fp in h.future_payload:
			K.label(r, "%s — %s" % [str(fp["man_id"]), str(fp["result"])], T.PAD, y, T.BODY, T.ACCENT); y += 70
			for kf in fp["keyframes"]:
				K.label(r, "·  " + str(kf), T.PAD + 16, y, T.SMALL, T.TEXT, W - 16); y += 50
			if str(fp["mirror"]) != "":
				K.label(r, str(fp["mirror"]), T.PAD, y, T.SMALL, Color(0.85,0.35,0.35), W); y += 100
			y += 30
		K.btn(r, "CONTINUE  →", T.PAD, T.REF_H - 330, W, T.BTN_H, func(): h.dismiss_future())
		return r
	match h.face:
		Hub.F.HOME:
			K.label(r, "YOU", T.PAD, 240, T.TITLE, T.ACCENT)
			var sn = h.flow.state.snapshot()
			K.label(r, "Persona: %s   Charm %d   Standing %d   Control %d" % [str(h.ui.get("persona","rare_girl")), sn.charm, sn.position, sn.control], T.PAD, 340, T.BODY, T.TEXT, W)
			K.label(r, "You decide who's worth your energy.", T.PAD, 430, T.SMALL, T.DIM, W)
			K.label(r, "(Avatar / outfit visual — re-skin later)", T.PAD, 560, T.SMALL, T.DIM, W)
		Hub.F.SELF:
			K.label(r, "SELF-IMPROVEMENT", T.PAD, 240, T.TITLE, T.ACCENT)
			var y := 360
			for grp in [["self_investments","self_invest"],["personas","persona"],["outfits","outfit"],["workouts","workout"]]:
				K.label(r, grp[0].to_upper(), T.PAD, y, T.SMALL, T.DIM); y += 56
				for it in Content.call(grp[0]):
					var key: String = grp[1]
					var iid: String = it["id"]
					K.btn(r, str(it["name"]) if it.has("name") else iid, T.PAD, y, W, 110,
						func(): h.ui[key] = iid; h._render(), h.ui.get(key,"") == iid)
					y += 124
		Hub.F.PARTY:
			if h.enc != null and not h.enc.finished:
				var st = h.enc.read()
				K.label(r, "PARTY  ·  round %d / %d" % [st["round"], st["of"]], T.PAD, 240, T.TITLE, T.ACCENT)
				var ly := 360
				for line in h.party_log:
					K.label(r, "“" + str(line) + "”", T.PAD, ly, T.BODY, T.TEXT, W); ly += 120
				var by := T.REF_H - 330 - (T.BTN_H + 16) * 4
				for a in ["engage","boundary","social_proof","exit"]:
					var act: String = a
					K.btn(r, act.to_upper().replace("_"," "), T.PAD, by, W, T.BTN_H, func(): h.act_party(act))
					by += T.BTN_H + 16
			elif h.flow.party_men().size() > 0 and h.ui.get("_chose_party", false):
				K.label(r, "FIRST EYE", T.PAD, 240, T.TITLE, T.ACCENT)
				var y := 360
				for m in h.flow.party_men():
					var mid: String = m["id"]
					K.btn(r, "%s · %s\nrisk: %s" % [str(m["name"]), str(m["surface"]), str(m["risk"])], T.PAD, y, W, 220, func(): h.act_enter_party(mid))
					y += 244
			else:
				K.label(r, "PARTY MAP", T.PAD, 240, T.TITLE, T.ACCENT)
				K.label(r, "Your circle decides which rooms you get into.", T.PAD, 340, T.SMALL, T.DIM, W)
				var y := 460
				for p in h.flow.available_parties():
					var pid: String = p["id"]
					var tag := "" if p["unlocked"] else "  · LOCKED (tier %d)" % int(p["tier"])
					var btn := K.btn(r, str(p["name"]) + tag, T.PAD, y, W, T.BTN_H,
						func(): h.ui["_chose_party"] = true; h.act_choose_party(pid))
					if not p["unlocked"]: btn.disabled = true
					y += T.BTN_H + 16
		Hub.F.DATING:
			K.label(r, "DATING", T.PAD, 240, T.TITLE, T.ACCENT)
			K.label(r, "Decide where your energy goes. You can only Date one.", T.PAD, 340, T.SMALL, T.DIM, W)
			if not h.ui.has("after"): h.ui["after"] = {}
			var y := 460
			for e in h.flow.book_for_after():
				K.label(r, "%s: \"%s\" — %s" % [str(e["name"]), str(e["message"]), str(e["snark"])], T.PAD, y, T.SMALL, T.DIM, W); y += 80
				var bx := T.PAD
				var bw := (W - 36) / 4
				for ch in ["date","observe","test","cut"]:
					var mid: String = e["man_id"]
					var choice: String = ch
					K.btn(r, choice, bx, y, bw, 120, func(): h.ui["after"][mid] = choice; h._render(), h.ui["after"].get(mid,"") == choice)
					bx += bw + 12
				y += 150
			K.btn(r, "CONFIRM  →", T.PAD, T.REF_H - 330, W, T.BTN_H, func(): h.act_after(h.ui["after"]))
		Hub.F.SOCIAL:
			K.label(r, "SOCIAL MEDIA", T.PAD, 240, T.TITLE, T.ACCENT)
			K.label(r, "(Plan C: post → who slides in + girlfriend leads)", T.PAD, 360, T.BODY, T.DIM, W)
		Hub.F.CARDS:
			K.label(r, "COLLECTION", T.PAD, 240, T.TITLE, T.ACCENT)
			K.label(r, "Dossier %d · (Plan C: case files + network + keyframes)" % h.flow.state.dossier.size(), T.PAD, 360, T.BODY, T.DIM, W)
		Hub.F.ASSETS:
			K.label(r, "ASSET LIST", T.PAD, 240, T.TITLE, T.ACCENT)
			var s2 = h.flow.state.snapshot()
			K.label(r, "Net worth %d  (Plan C: equity curve)" % s2.net_worth, T.PAD, 360, T.BODY, T.TEXT, W)
		_:
			K.label(r, "…", T.PAD, 300, T.TITLE, T.TEXT)
	_nav(r, h)
	return r
```

- [ ] **Step 4: Loc keys** — append to the `ZH` dict in `Godot/ui/Loc.gd` (do NOT alter existing entries) Chinese for the new strings: `"YOU"→"你"`, `"SELF-IMPROVEMENT"→"自我提升"`, `"SOCIAL MEDIA"→"社交媒体"`, `"PARTY MAP"→"派对地图"`, `"DATING"→"约会"`, `"COLLECTION"→"集卡"`, `"ASSET LIST"→"资产清单"`, `"SELF"→"自我"`,`"SOCIAL"→"社媒"`,`"PARTY"→"派对"`,`"CARDS"→"集卡"`,`"ASSETS"→"资产"`, `"ENERGY %d"`→leave (has %d; Loc.t matches whole string — instead localize the static word: use `"ENERGY"` label separately if needed — implementer may split), `"WEEK SETTLEMENT"`,`"SEASON CLOSE"`,`"FUTURE EYE"`,`"FIRST EYE"`,`"CONTINUE  →"`,`"CONFIRM  →"`, the self-improve group headers, the subtitle sentences, action labels (reuse existing engage/boundary/... keys if present). Where a string contains `%d`/`%s`, either add the exact post-format string is NOT possible — so for those, wrap only the static-word portions (implementer: split such labels so the translatable word goes through `Loc.t` and the number is concatenated). Keep it pragmatic: every fixed UI word has a zh entry; mixed format lines may show numbers with a zh label.

- [ ] **Step 5: Swap scene + delete old UI** — `Godot/scenes/Game.tscn` `ext_resource` script path → `res://ui/Hub.gd`, node keeps name. Delete `Godot/ui/UIController.gd` and `Godot/ui/Screens.gd` (`git rm`).

- [ ] **Step 6: Verify** — `cd Godot && godot --headless --quit` → exit 0, NO parse/script errors (Hub `_ready` builds HOME face headless). `cd Godot && godot --headless --script res://tests/run_tests.gd` → `RAN 56 tests, 0 failures`, exit 0 (engine untouched). `git diff --stat 532136b..HEAD -- Godot/core Godot/tests Godot/play.gd` → EMPTY (no engine/test/play change). Fix real Godot-4.6 causes only (esp. `match h.face:` needs `Hub.F.X` constant patterns — `Hub` is preloaded; `Content.call(grp[0])` dynamic call valid in 4.6; bracket access on Variant dicts). Do not stub past errors.

- [ ] **Step 7: Commit**
```bash
git add Godot/ui/UiKit.gd Godot/ui/Hub.gd Godot/ui/Faces.gd Godot/ui/Loc.gd Godot/scenes/Game.tscn
git rm Godot/ui/UIController.gd Godot/ui/Screens.gd
git commit -m "feat(hunting-ui): hub shell — Home + 6-tab nav + faces (replaces linear flow)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Rewrite ui_smoke to drive a night THROUGH the hub

**Files:** Modify `Godot/ui_smoke.gd`.

- [ ] **Step 1: Rewrite** `Godot/ui_smoke.gd` to instantiate `res://scenes/Game.tscn` (now Hub), wait for `_ready` (deferred + `await self.process_frame` as before), then drive ONE night via Hub methods/nav: set `ui.self_invest`/`ui.persona`, `go_face(Hub.F.PARTY)`, `act_choose_party("rooftop")`, `act_enter_party("adrian")`, loop `act_party("boundary")` until `enc.finished` (auto-routes to DATING), `act_after({"adrian":"date"})`, `dismiss_future()`, then assert `flow.state.day >= 2`, print `HUB SMOKE OK day=%d face=%d` , `quit(0)`. Drive only through Hub methods (not SeasonFlow directly). Keep the deferred/await `_ready`-timing pattern.

- [ ] **Step 2: Run** — `cd Godot && godot --headless --script res://ui_smoke.gd` → prints `HUB SMOKE OK day=2 ...`, exit 0. Fix real cause if it errors (driving order vs face state machine; ensure_night lazy begin). Do not weaken the `day>=2` assert; do not bypass Hub.

- [ ] **Step 3: Re-run engine suite** — `cd Godot && godot --headless --script res://tests/run_tests.gd` → `RAN 56 tests, 0 failures`, exit 0. `godot --headless --script res://play.gd` → exit 0 coherent (engine untouched).

- [ ] **Step 4: Commit**
```bash
git add Godot/ui_smoke.gd
git commit -m "test(hunting-ui): hub walkthrough smoke (one night via hub nav)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Verification + README + push-readiness

- [ ] **Step 1: Gates** — `godot --headless --quit` exit 0; `godot --headless --script res://ui_smoke.gd` → `HUB SMOKE OK day=2`; `godot --headless --script res://tests/run_tests.gd` → `RAN 56 tests, 0 failures`; `godot --headless --script res://play.gd` exit 0. Paste all.
- [ ] **Step 2: UI-only proof** — `git diff --stat 532136b..HEAD -- Godot/core Godot/tests Godot/play.gd` is EMPTY; `git diff --stat 532136b..HEAD` lists only `Godot/ui/*`, `Godot/scenes/Game.tscn`, `Godot/ui_smoke.gd` (+ deleted UIController/Screens).
- [ ] **Step 3: README** — append a "Play with UI (hub)" section replacing/補充 the old play instructions: same `godot --path . res://scenes/Game.tscn`; describe the hub (Home + 6 tabs; soft daily cycle: SELF set build → PARTY begins the night → DATING resolves it → settlement). Note Social/Collection/Assets are Plan C stubs.
- [ ] **Step 4: Commit**
```bash
git add Godot/README.md
git commit -m "docs(hunting-ui): hub play instructions

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (plan author)

**Spec coverage (spec §3/§4/§5/§8 Plan B):** Home shell (avatar block + energy-bar HUD + stats) — Faces `_hud`/HOME; 6-tab bottom nav + routing — `_nav`/`go_face`/`F` enum; soft daily cycle (lazy `begin_night` on entering PARTY, party→DATING→`resolve_after`/`finish_night`→settle/season overlay) — Hub `ensure_night`/`act_*`/`_post_night`; 3 playable faces reuse engine API (SELF=self_invest/persona/outfit/workout; PARTY=party map→First Eye→rounds; DATING=book_for_after decisions + Future Eye overlay); 3 stub faces (SOCIAL/CARDS/ASSETS) for Plan C; settlement overlays. Loc zh appended. Old linear UIController/Screens removed. Plan-A design constraints recorded for Plan C.

**Placeholder scan:** stub faces are intentional, spec-scoped to Plan C (not TBD in Plan B's deliverable). All steps have complete code + exact commands/expected output. UI smoke asserts a real full night.

**Type consistency:** `Hub.F` enum used for nav + `match` (preloaded `Hub` const for constant patterns); `flow.*` calls match the on-`main` SeasonFlow API exactly; bracket access on Variant dicts; per-iteration capture locals (`fid`,`act`,`mid`,`choice`,`pid`,`iid`,`key`). UiKit `root/label/btn` reused by all faces; Loc.t wraps every user-facing string.

**Engine integrity:** Plan B is UI-only — every task verifies `git diff` shows zero `core/`/`tests/`/`play.gd` change and 56 engine tests stay green; `play.gd` still coherent.

**Scope:** the hub SHELL + playable spine; net-new face content deferred to Plan C per spec decomposition. One coherent UI plan.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-05-17-hunting-plan-b-hub-shell.md`. Subagent-driven execution (proven). Task 1 is the large structural piece (spec review + quality review); Tasks 2–3 lighter (combined). Proceed with Task 1 unless redirected.
