# Hunting Plan A — Engine Additions: Social Funnel + Dossier Producer

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add the net-new engine pieces the hub IA needs — a deterministic social-media funnel (`compose_post`: posture → inbound men pool + girlfriend leads + Standing/Control + mirror), the long-deferred **dossier producer** (`read_signal`), and dress/exercise content — as **additions only** to the headless carry engine, with full TDD. No UI. The existing 40 tests, batch `step_night`/`play.gd`, and interactive API stay byte-behavior-unchanged.

**Architecture:** All new logic is **appended** to `SeasonFlow.gd` (new `_np_*`-style fields + new methods) and added as new `Content` static funcs + new `tuning.json` blocks — never modifying existing methods except one additive per-night reset line in `begin_night` for the new fields. Determinism preserved (no RNG): the funnel's inbound composition is a deterministic function of posture + state, reusing `ControlEngine` for the chase/earn (validation/scarce) semantics so it is the SAME B-model, not a new one.

**Tech Stack:** Godot 4.6 GDScript, headless custom test harness, JSON tuning. No UI.

**Source spec:** `docs/superpowers/specs/2026-05-17-hunting-hub-ia-design.zh.md` §4.2/§4.6/§8 Plan A; mechanics governed by `docs/superpowers/specs/2026-05-17-hunting-carry-design.zh.md`. Engine on `main` at HEAD (post `dc04b9b`).

**Project-wide constraints (carried, obey exactly):**
1. Test files use `extends "res://tests/test_base.gd"` (path), cross-refs path `preload(...)`.
2. "RAN N" indicative; gate = `0 failures` + all spec assertions; may split test methods.
3. New commit only, never `--amend`.
4. **Additions-only to engine:** do NOT modify existing `SeasonFlow` methods/fields, `Content` existing funcs, or any of the 40 existing test assertions. The ONLY permitted edit to an existing method is appending reset lines for the NEW fields inside `begin_night` (precedent: the accepted `log_lines=[]` additive reset). `step_night`/`settle`/`close_season`/`resolve_after`/`finish_night`/`party_men`/`_man`/existing tests untouched. Apply established Godot-4.6 typing fixes pre-emptively (typed local for `Tuning.num` Variant; bracket access on Variant dicts).

---

## Core API contract (added across tasks)

- `Content.outfits() -> Array` — `[{id,name,effect:{charm/position/energy}}]` (≥3). `Content.workouts() -> Array` — `[{id,name,effect}]` (≥3). (Net-new 装扮/运动 content; existing `self_investments()`/`personas()` untouched.)
- `SeasonFlow.apply_outfit(outfit_id) -> void` / `apply_workout(workout_id) -> void` — `state.apply(effect)` for the matching content; no-op if id unknown.
- `SeasonFlow.compose_post(posture: String) -> Dictionary` — `posture ∈ {"scarce","validation"}`. Returns `{inbound_men:Array, gf_leads:Array, control_delta:int, standing_delta:int, mirror:String}`. Effects: control via `ControlEngine.resolve({}, "boundary" if scarce else "engage")`; standing via `social.*_standing`; deterministic inbound set sized by `social.*_reach` (scarce → higher-tier/low-lemon ordering, validation → lemon-weighted ordering); gf lead when scarce & `state.position >= social.gf_lead_threshold` (warms a gf); mirror non-empty iff `posture=="validation"` and post-apply `state.control < 0`. Writes `_np_inbound`, applies state/Girlfriends. **Does NOT advance the day.** One post/night (guard `_np_posted`).
- `SeasonFlow.inbound_men() -> Array` — returns `_np_inbound` (the funnel-produced pool; Plan C wires the party to consume it).
- `SeasonFlow.read_signal(hidden_type: String, guess: String) -> Dictionary` — high-frequency comment/DM read. If `guess == hidden_type` → append `{type:hidden_type, result:"read_correct"}` to `state.dossier` (the dossier PRODUCER), return `{correct:true, dossier_size:int}`; else `{correct:false, dossier_size:int}` (no archive). This is the only dossier writer in Plan A (party/date archiving deferred to a later plan; noted).
- `begin_night` gains ONLY additive reset lines for the new per-night fields (`_np_inbound=[]`, `_np_posted=false`) — no other change.

`tuning.json` new blocks:
```json
"social": {"scarce_reach": 1, "validation_reach": 3, "scarce_standing": 1, "validation_standing": 0, "gf_lead_threshold": 2, "gf_lead_warmth": 1},
"dossier": {"read_correct_archives": 1}
```

---

### Task 1: Tuning + Content additions (outfits/workouts)

**Files:** Modify `Godot/data/tuning.json` (add 2 blocks), `Godot/core/Content.gd` (append 2 static funcs); Create `Godot/tests/test_content_hub.gd`; Modify `Godot/tests/run_tests.gd` (add the new test path).

- [ ] **Step 1: Failing test** — `Godot/tests/test_content_hub.gd`:
```gdscript
extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")
const Tuning := preload("res://core/Tuning.gd")
func test_outfits_exist() -> void:
	var xs = Content.outfits()
	ok(xs.size() >= 3, "≥3 outfits")
	for x in xs:
		ok(x.has("id") and x.has("name") and x.has("effect"), "outfit shape")
func test_workouts_exist() -> void:
	var ws = Content.workouts()
	ok(ws.size() >= 3, "≥3 workouts")
	for w in ws:
		ok(w.has("id") and w.has("effect"), "workout shape")
func test_existing_self_investments_unchanged() -> void:
	eq(Content.self_investments().size(), 4, "self_investments still 4 (not modified)")
func test_social_tuning_present() -> void:
	Tuning.load_data()
	eq(Tuning.num("social.validation_reach"), 3, "social tuning loaded")
	eq(Tuning.num("dossier.read_correct_archives"), 1, "dossier tuning loaded")
```
- [ ] **Step 2: Add the new test path** to the `TESTS` array in `Godot/tests/run_tests.gd` (append `"res://tests/test_content_hub.gd"`, keep all existing).
- [ ] **Step 3: Run → red** — `cd Godot && godot --headless --script res://tests/run_tests.gd`; new failures only (missing `Content.outfits`/`workouts`, missing tuning keys); prior tests still listed.
- [ ] **Step 4: Implement** — append to `Godot/core/Content.gd` (do NOT touch existing funcs):
```gdscript
static func outfits() -> Array:
	return [
		{"id": "midnight_silk", "name": "Midnight Silk", "effect": {"charm": 2}},
		{"id": "power_suit", "name": "Power Suit", "effect": {"position": 1}},
		{"id": "soft_athleisure", "name": "Soft Athleisure", "effect": {"charm": 1}},
	]
static func workouts() -> Array:
	return [
		{"id": "reset_run", "name": "Reset Run", "effect": {"energy": 2}},
		{"id": "power_lift", "name": "Power Lift", "effect": {"position": 1}},
		{"id": "calm_yoga", "name": "Calm Yoga", "effect": {"energy": 1}},
	]
```
And add to `Godot/data/tuning.json` the two new top-level keys exactly (valid JSON, keep all existing keys byte-identical):
```
"social": {"scarce_reach": 1, "validation_reach": 3, "scarce_standing": 1, "validation_standing": 0, "gf_lead_threshold": 2, "gf_lead_warmth": 1},
"dossier": {"read_correct_archives": 1}
```
- [ ] **Step 5: Run → green** — `cd Godot && godot --headless --script res://tests/run_tests.gd` → `0 failures`, exit 0 (≈`RAN 44 tests`). `godot --headless --quit` exit 0. `godot --headless --script res://play.gd` exit 0 (batch unaffected).
- [ ] **Step 6: Commit**
```bash
git add Godot/core/Content.gd Godot/data/tuning.json Godot/tests/test_content_hub.gd Godot/tests/run_tests.gd
git commit -m "feat(hunting-be): outfit/workout content + social/dossier tuning

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: apply_outfit / apply_workout (additive SeasonFlow methods)

**Files:** Modify `Godot/core/SeasonFlow.gd` (append 2 methods); Create `Godot/tests/test_seasonflow_self_improve.gd`; Modify `run_tests.gd`.

- [ ] **Step 1: Failing test** — `Godot/tests/test_seasonflow_self_improve.gd`:
```gdscript
extends "res://tests/test_base.gd"
const SF := preload("res://core/SeasonFlow.gd")
func test_apply_outfit() -> void:
	var f = SF.new()
	var c0 = f.state.charm
	f.apply_outfit("midnight_silk")
	eq(f.state.charm, c0 + 2, "midnight_silk +2 charm")
func test_apply_workout() -> void:
	var f = SF.new()
	var e0 = f.state.energy
	f.apply_workout("reset_run")
	eq(f.state.energy, e0 + 2, "reset_run +2 energy")
func test_unknown_id_noop() -> void:
	var f = SF.new()
	var s0 = f.state.snapshot()
	f.apply_outfit("nope"); f.apply_workout("nope")
	eq(f.state.snapshot(), s0, "unknown id is a no-op")
```
- [ ] **Step 2: Add test path** to `run_tests.gd` TESTS.
- [ ] **Step 3: Run → red.**
- [ ] **Step 4: Implement** — append to `Godot/core/SeasonFlow.gd` (new methods only; `Content` already preloaded in the file):
```gdscript
func apply_outfit(outfit_id: String) -> void:
	for o in Content.outfits():
		if o.id == outfit_id:
			state.apply(o.effect)
			return
func apply_workout(workout_id: String) -> void:
	for w in Content.workouts():
		if w.id == workout_id:
			state.apply(w.effect)
			return
```
- [ ] **Step 5: Run → green** (≈`RAN 47 tests, 0 failures`), `godot --headless --quit` exit 0, `play.gd` exit 0.
- [ ] **Step 6: Commit**
```bash
git add Godot/core/SeasonFlow.gd Godot/tests/test_seasonflow_self_improve.gd Godot/tests/run_tests.gd
git commit -m "feat(hunting-be): SeasonFlow apply_outfit/apply_workout (additive)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: compose_post — the social funnel

**Files:** Modify `Godot/core/SeasonFlow.gd` (append fields + methods; one additive reset line in `begin_night`); Create `Godot/tests/test_seasonflow_funnel.gd`; Modify `run_tests.gd`.

- [ ] **Step 1: Failing test** — `Godot/tests/test_seasonflow_funnel.gd`:
```gdscript
extends "res://tests/test_base.gd"
const SF := preload("res://core/SeasonFlow.gd")
func test_scarce_post_fewer_higher_control() -> void:
	var f = SF.new()
	var ctl0 = f.state.control
	var r = f.compose_post("scarce")
	ok(r.inbound_men.size() >= 1, "scarce yields some inbound")
	ok(r.control_delta > 0, "scarce gains control (earn)")
	eq(f.state.control, ctl0 + r.control_delta, "control applied to state")
	eq(r.mirror, "", "no mirror on scarce")
	ok(f.inbound_men().size() == r.inbound_men.size(), "inbound_men() exposes the pool")
func test_validation_post_more_and_lemon_weighted() -> void:
	var f = SF.new()
	var rs = f.compose_post("scarce")
	var f2 = SF.new()
	var rv = f2.compose_post("validation")
	ok(rv.inbound_men.size() >= rs.inbound_men.size(), "validation reaches more")
	ok(rv.control_delta < 0, "validation costs control (chase)")
	# lemon-weighted: first inbound under validation is the high_sugar archetype
	eq(rv.inbound_men[0]["hidden_type"], "high_sugar", "validation surfaces the lemon first")
func test_validation_low_control_fires_mirror() -> void:
	var f = SF.new()
	f.state.control = -1
	var r = f.compose_post("validation")
	ok(r.mirror != "", "validation + negative control → mirror")
func test_post_does_not_advance_day_and_one_per_night() -> void:
	var f = SF.new()
	var d0 = f.state.day
	f.compose_post("scarce")
	eq(f.state.day, d0, "compose_post does not advance the day")
	var r2 = f.compose_post("scarce")
	eq(r2.inbound_men.size(), 0, "second post same night is a no-op (one/night)")
func test_begin_night_resets_post_state() -> void:
	var f = SF.new()
	f.compose_post("scarce")
	f.begin_night("solo_reset", "rare_girl")
	var r = f.compose_post("validation")
	ok(r.inbound_men.size() > 0, "begin_night reset allows posting again next night")
func test_batch_and_interactive_intact() -> void:
	var f = SF.new()
	var r = f.step_night({"self_invest": "solo_reset", "primary": "leo",
		"party_actions": ["exit"], "after": {"leo": "observe"}})
	eq(f.state.day, 2, "batch path still advances")
	ok(r.has("log"), "batch returns log")
```
- [ ] **Step 2: Add test path** to `run_tests.gd` TESTS.
- [ ] **Step 3: Run → red.**
- [ ] **Step 4: Implement.** Append new fields next to the other `_np_*` fields in `SeasonFlow.gd`:
```gdscript
var _np_inbound: Array = []
var _np_posted: bool = false
```
Append ONE additive line inside the existing `begin_night` body, alongside the existing `_np_*` resets (do not remove/alter any existing line there):
```gdscript
	_np_inbound = []
	_np_posted = false
```
Append new methods (note `ControlEngine`, `Content`, `Tuning`, `Girlfriends` are already preloaded consts in the file):
```gdscript
func _inbound_for(posture: String) -> Array:
	# Deterministic, no RNG. scarce → higher-tier/low-lemon order; validation → lemon-first.
	var scarce_order := ["adrian", "leo", "evan"]
	var valid_order := ["evan", "adrian", "leo"]
	var ids: Array = scarce_order if posture == "scarce" else valid_order
	var reach: int = Tuning.num("social.scarce_reach", 1) if posture == "scarce" else Tuning.num("social.validation_reach", 3)
	var out := []
	for i in range(min(reach, ids.size())):
		out.append(_man(ids[i]))
	return out

func compose_post(posture: String) -> Dictionary:
	if _np_posted:
		return {"inbound_men": [], "gf_leads": [], "control_delta": 0,
			"standing_delta": 0, "mirror": ""}
	_np_posted = true
	var action := "boundary" if posture == "scarce" else "engage"
	var ce = ControlEngine.resolve({}, action)
	var control_delta: int = int(ce.control)
	var standing_delta: int = Tuning.num("social.scarce_standing", 1) if posture == "scarce" else Tuning.num("social.validation_standing", 0)
	state.apply({"control": control_delta, "position": standing_delta})
	_np_inbound = _inbound_for(posture)
	var gf_leads := []
	if posture == "scarce" and state.position >= int(Tuning.num("social.gf_lead_threshold", 2)):
		for g in Content.girlfriends():
			if g.tier == 2:
				gf.adjust(g.id, int(Tuning.num("social.gf_lead_warmth", 1)))
				gf_leads.append(g.id)
				break
	var mirror := ""
	if posture == "validation" and state.control < 0:
		mirror = "Your feed reads thirsty. To them you're the easy one — a sugar source, held cheap."
	return {"inbound_men": _np_inbound, "gf_leads": gf_leads,
		"control_delta": control_delta, "standing_delta": standing_delta,
		"mirror": mirror}

func inbound_men() -> Array:
	return _np_inbound
```
Notes: `_man()` already exists — reuse it. `Tuning.num` returns Variant → the typed locals/`int(...)` casts above absorb it. The ternary on `Tuning.num` results is assigned into typed `int` locals; if Godot 4.6 rejects ternary-with-Variant, split into `if/else` assignment (semantics identical). Keep one-post-per-night guard exact; keep "does not touch `state.day`".
- [ ] **Step 5: Run → green** (≈`RAN 53 tests, 0 failures`), `godot --headless --quit` exit 0, `play.gd` exit 0 and coherent (batch + interactive unaffected — `test_batch_and_interactive_intact` proves it; also re-run prior interactive test file).
- [ ] **Step 6: Commit**
```bash
git add Godot/core/SeasonFlow.gd Godot/tests/test_seasonflow_funnel.gd Godot/tests/run_tests.gd
git commit -m "feat(hunting-be): compose_post social funnel (posture→pool+standing+mirror)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: read_signal — the dossier producer

**Files:** Modify `Godot/core/SeasonFlow.gd` (append 1 method); Create `Godot/tests/test_seasonflow_dossier.gd`; Modify `run_tests.gd`.

- [ ] **Step 1: Failing test** — `Godot/tests/test_seasonflow_dossier.gd`:
```gdscript
extends "res://tests/test_base.gd"
const SF := preload("res://core/SeasonFlow.gd")
func test_correct_read_archives_dossier() -> void:
	var f = SF.new()
	var n0 = f.state.dossier.size()
	var r = f.read_signal("high_sugar", "high_sugar")
	ok(r.correct, "matching guess = correct read")
	eq(f.state.dossier.size(), n0 + 1, "correct read archives one dossier entry")
	eq(f.state.dossier[-1]["type"], "high_sugar", "archived the read type")
func test_wrong_read_no_archive() -> void:
	var f = SF.new()
	var n0 = f.state.dossier.size()
	var r = f.read_signal("growth", "high_sugar")
	ok(not r.correct, "mismatch = wrong")
	eq(f.state.dossier.size(), n0, "wrong read archives nothing")
func test_dossier_growth_lifts_net_worth() -> void:
	var f = SF.new()
	var nw0 = f.state.net_worth()
	f.read_signal("resource", "resource")
	ok(f.state.net_worth() > nw0, "dossier is a net-worth asset (judgment equity)")
```
- [ ] **Step 2: Add test path** to `run_tests.gd` TESTS.
- [ ] **Step 3: Run → red.**
- [ ] **Step 4: Implement** — append to `Godot/core/SeasonFlow.gd`:
```gdscript
func read_signal(hidden_type: String, guess: String) -> Dictionary:
	var correct := guess == hidden_type
	if correct:
		state.dossier.append({"type": hidden_type, "result": "read_correct"})
	return {"correct": correct, "dossier_size": state.dossier.size()}
```
(`GameState.net_worth()` counts `dossier.size()` as an asset — verified by `test_dossier_growth_lifts_net_worth`.)
- [ ] **Step 5: Run → green** (≈`RAN 56 tests, 0 failures`), `godot --headless --quit` exit 0, `play.gd` exit 0.
- [ ] **Step 6: Commit**
```bash
git add Godot/core/SeasonFlow.gd Godot/tests/test_seasonflow_dossier.gd Godot/tests/run_tests.gd
git commit -m "feat(hunting-be): read_signal dossier producer (judgment equity)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Verification

- [ ] **Step 1: Full suite green** — `cd Godot && godot --headless --script res://tests/run_tests.gd` → `0 failures`, exit 0 (≈`RAN 56 tests`; the original 40 all still present and passing).
- [ ] **Step 2: No regression on existing paths** — `godot --headless --script res://play.gd` → exit 0, coherent season (batch). `godot --headless --script res://ui_smoke.gd` → `UI SMOKE OK day=2`, exit 0 (interactive/UI loop unaffected). `godot --headless --quit` → exit 0.
- [ ] **Step 3: Additions-only proof** — `git diff <pre-Plan-A-sha>..HEAD -- Godot/core/SeasonFlow.gd | grep '^-[^-]'` shows NO removed logic lines except none (only additions); the only edit to an existing method is the two additive reset lines in `begin_night`. Confirm `step_night`/`settle`/`close_season`/`resolve_after`/`finish_night`/`party_men`/`_man` byte-unchanged. `git diff <pre>..HEAD -- Godot/data/tuning.json` shows only the 2 new keys appended (existing keys byte-identical).
- [ ] **Step 4: README note** — append to `Godot/README.md` a short "Engine: social funnel + dossier" line documenting `compose_post(posture)`, `inbound_men()`, `read_signal(hidden_type,guess)`, `apply_outfit/apply_workout`, and that numbers live in `data/tuning.json` `social`/`dossier`.
- [ ] **Step 5: Commit**
```bash
git add Godot/README.md
git commit -m "docs(hunting-be): document social funnel + dossier engine API

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (plan author)

**Spec coverage (spec §8 Plan A):** `compose_post` funnel (posture→inbound pool, Standing, Control via the SAME ControlEngine B-model, gf leads, mirror, no day advance, one/night) — Task 3; dossier PRODUCER (`read_signal`) finally wired, dossier as net-worth asset — Task 4; dress/exercise content — Tasks 1–2; numbers in `tuning.json` — Task 1. Deferred per spec §10 (noted, not built here): post-content catalog, party/date dossier archiving, party consuming `inbound_men()` (Plan C), all balancing.

**Placeholder scan:** no TBD in logic; numbers in `tuning.json` by design; every step has complete runnable GDScript + exact commands/expected output.

**Type consistency:** `compose_post`→`{inbound_men,gf_leads,control_delta,standing_delta,mirror}`, `inbound_men()`, `read_signal`→`{correct,dossier_size}`, `apply_outfit/apply_workout`, `Content.outfits/workouts` — used identically across tasks/tests. Determinism preserved (fixed inbound orderings, no RNG). ControlEngine reused (validation=engage/chase, scarce=boundary/earn) so it is the same B-model.

**Additions-only invariant:** every engine edit is an append except the two additive reset lines in `begin_night` (precedent-accepted pattern for new per-night fields); existing 40 tests + batch + interactive + play.gd + ui_smoke all asserted intact (Task 3 `test_batch_and_interactive_intact`, Task 5).

**Scope:** focused single plan (Plan A of the spec's 3-way decomposition); Plan B (hub shell) and Plan C (faces wiring) are separate.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-05-17-hunting-plan-a-engine-funnel.md`. Subagent-driven execution (proven workflow): TDD logic → full spec+quality review per task; additions-only invariant re-checked each task. Proceeding with Task 1 unless redirected.
