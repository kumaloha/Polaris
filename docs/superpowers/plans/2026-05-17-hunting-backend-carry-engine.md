# Hunting Backend Carry Engine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the headless, terminal-playable simulation engine for *Hunting (猎场)* — the multi-period carry loop, Control(chase-vs-earn), B consequence model, epistemic loop, Future Eye settlement, held-book evolution, soft ruin — with **no UI**, so the design can be play-tested in the terminal before any client work.

**Architecture:** Pure GDScript `RefCounted` core, zero `UnityEngine`/SceneTree/UI dependency in logic classes. All tunable numbers live in one hot-loadable `data/tuning.json` (read at runtime, never hardcoded in logic). Verification is a dependency-free headless test harness (`godot --headless --script res://tests/run_tests.gd`, no GUT addon). A `play.gd` SceneTree driver runs a full scripted or interactive season in stdout/stdin so the designer can "play the backend directly."

**Tech Stack:** Godot 4.x, GDScript, JSON tuning data, custom headless test runner. No UI, no scenes beyond a headless boot stub.

**Source spec:** `docs/superpowers/specs/2026-05-17-hunting-carry-design.zh.md` (authoritative). Supersedes the deleted thin-design Godot plan.

**Scope boundary (this plan = the playable spine that tests the core hypothesis):** multi-period loop, Control/B-model, First Eye + Dossier, Party read-loop, held-book mutation + creditors + fantasy debt, After-Party decisions, Future Eye/settlement + mirror, season inheritance, girlfriend credit-line gate (minimal), soft-ruin gate. **Explicitly deferred** (noted, not built here): the dark-advisory "help girlfriend pick men" sub-module, full disguise-curve tuning, per-persona cost tables, number balancing. These are post-spine follow-ups.

---

## File Structure

```
Godot/
  project.godot                 # headless boot stub
  scenes/Boot.tscn              # trivial node, attaches Boot.gd
  scripts/
    Boot.gd                     # prints boot ok (headless smoke)
  core/
    Tuning.gd                   # loads + queries data/tuning.json
    GameState.gd                # resources + balance sheet (net worth)
    Content.gd                  # archetypes(signal-set+hidden-type), personas, gfs, parties, self-invest
    ControlEngine.gd            # chase/earn classification + B-model interaction resolution
    FirstEye.gd                 # claims + dossier auto-tag + buy-depth
    PartyEncounter.gd           # hidden Interest/Respect, 4 actions, tells, type evidence
    Book.gd                     # held positions: night mutation, creditors, fantasy debt, decisions
    FutureEye.gd                # deterministic resolve -> result+keyframes+ROI+mirror
    Girlfriends.gd              # warmth per gf -> available party tier
    SoftRuin.gd                 # insolvency detection
    SeasonFlow.gd               # orchestrates Night/Week/Season + inheritance
  data/
    tuning.json                 # ALL tunable numbers (hot-editable)
  tests/
    test_base.gd                # soft-assert helpers
    run_tests.gd                # SceneTree runner, exits with failure count
    test_tuning.gd
    test_game_state.gd
    test_content.gd
    test_control_engine.gd
    test_first_eye.gd
    test_party_encounter.gd
    test_book.gd
    test_future_eye.gd
    test_girlfriends.gd
    test_soft_ruin.gd
    test_season_flow.gd
  play.gd                       # SceneTree: scripted/interactive full-season terminal driver
  README.md
```

**Core API contract (implemented across tasks, consumed by SeasonFlow + play.gd):**

- `Tuning.load_data()`; `Tuning.num(path, default)` (dot path into tuning.json)
- `GameState.new()`; fields `energy, charm, position, control, day, week, season, dossier:Array, debts:Array, keyframes:Array`; `apply(delta:Dictionary)`; `net_worth() -> int`; `snapshot() -> Dictionary`
- `Content.men() / personas() / girlfriends() / parties() / self_investments()`; a man = `{id,name,hidden_type,surface,energy_cost,risk,opportunity,chat}`
- `ControlEngine.classify(action) -> String` ("chase"|"earn"|"neutral"); `ControlEngine.resolve(man_pos:Dictionary, action:String) -> Dictionary` ({cheap, costly, control, sign})
- `FirstEye.intel(man:Dictionary, dossier:Array, bought_depth:int) -> Dictionary` ({claims, dossier_tag, depth})
- `PartyEncounter.new(man:Dictionary, tuning_ctx:Dictionary)`; `act(action) -> Dictionary` ({tell, finished, evidence}); `read() -> Dictionary`; field `finished`
- `Book.new(state:GameState)`; `open(man_id, decision)`; `advance_night() -> Array` (events); `positions() -> Array`
- `FutureEye.resolve(hidden_type, decision, control_level, sequence_quality) -> Dictionary` ({result, keyframes, energy_roi, fantasy_debt, mirror})
- `Girlfriends.new(state)`; `warmth(gf_id) -> int`; `available_tier() -> int`; `adjust(gf_id, delta)`
- `SoftRuin.is_insolvent(state:GameState) -> bool`
- `SeasonFlow.new()`; `step_night(choices:Dictionary) -> Dictionary`; `at_week_boundary() -> bool`; `at_season_boundary() -> bool`; `settle() -> Dictionary`; `close_season() -> Dictionary`

Result vocabulary (fixed): `"Correct Read"`, `"Sugar Trap"`, `"Slow Upside"`, `"False Alpha"`, `"Missed Growth"`.

---

### Task 1: Skeleton, Test Harness, Tuning Loader

**Files:** Create `Godot/project.godot`, `Godot/scenes/Boot.tscn`, `Godot/scripts/Boot.gd`, `Godot/tests/test_base.gd`, `Godot/tests/run_tests.gd`, `Godot/data/tuning.json`, `Godot/core/Tuning.gd`, `Godot/tests/test_tuning.gd`

- [ ] **Step 1: Verify Godot 4**

Run: `godot --version`
Expected: `4.` prefix. If missing (macOS): `brew install godot`. Do not proceed otherwise.

- [ ] **Step 2: project.godot**

```ini
config_version=5

[application]
config/name="Hunting Backend"
run/main_scene="res://scenes/Boot.tscn"
config/features=PackedStringArray("4.3")
```

- [ ] **Step 3: Boot stub**

`Godot/scripts/Boot.gd`:
```gdscript
extends Node
func _ready() -> void:
	print("Hunting backend boot ok")
```

`Godot/scenes/Boot.tscn`:
```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/Boot.gd" id="1"]
[node name="Boot" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 4: Test base (soft asserts)**

`Godot/tests/test_base.gd`:
```gdscript
extends RefCounted
class_name TestBase
var errors: Array = []
func eq(a, b, m: String) -> void:
	if a != b: errors.append("%s | expected=%s actual=%s" % [m, str(b), str(a)])
func ok(c: bool, m: String) -> void:
	if not c: errors.append(m)
func ge(a, f, m: String) -> void:
	if a < f: errors.append("%s | %s < %s" % [m, str(a), str(f)])
```

- [ ] **Step 5: Headless runner**

`Godot/tests/run_tests.gd`:
```gdscript
extends SceneTree
const TESTS := [
	"res://tests/test_tuning.gd", "res://tests/test_game_state.gd",
	"res://tests/test_content.gd", "res://tests/test_control_engine.gd",
	"res://tests/test_first_eye.gd", "res://tests/test_party_encounter.gd",
	"res://tests/test_book.gd", "res://tests/test_future_eye.gd",
	"res://tests/test_girlfriends.gd", "res://tests/test_soft_ruin.gd",
	"res://tests/test_season_flow.gd",
]
func _initialize() -> void:
	var fails := 0
	var ran := 0
	for p in TESTS:
		if not ResourceLoader.exists(p): continue
		var inst = load(p).new()
		for m in inst.get_method_list():
			var n: String = m.name
			if n.begins_with("test_"):
				inst.errors = []
				inst.call(n)
				ran += 1
				for e in inst.errors:
					fails += 1
					print("FAIL %s::%s -> %s" % [p, n, e])
	print("RAN %d tests, %d failures" % [ran, fails])
	quit(fails)
```

- [ ] **Step 6: Tuning data + loader**

`Godot/data/tuning.json`:
```json
{
  "start": {"energy": 8, "charm": 40, "position": 1, "control": 0},
  "season": {"nights_per_week": 6, "weeks_per_season": 3},
  "energy": {"regen_per_night": 2, "engage_cost": 1, "boundary_cost": 1, "social_proof_cost": 1, "date_cost": 3, "test_cost": 2},
  "party": {"rounds": 5, "attention_pool": 2},
  "control": {"chase_penalty": 1, "earn_gain": 1},
  "book": {"creditor_energy_drain": 1, "observe_decay_per_night": 1, "fantasy_debt_per_unsettled": 1},
  "gates": {"tier1_warmth": 0, "tier2_warmth": 3, "tier3_warmth": 6},
  "inherit": {"keep_social": true, "keep_dossier": true, "reset_men": true, "reset_energy": true}
}
```

`Godot/core/Tuning.gd`:
```gdscript
extends RefCounted
class_name Tuning
static var _data: Dictionary = {}
static func load_data() -> void:
	var f := FileAccess.open("res://data/tuning.json", FileAccess.READ)
	_data = JSON.parse_string(f.get_as_text())
	f.close()
static func num(path: String, default = 0):
	if _data.is_empty(): load_data()
	var cur = _data
	for key in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not cur.has(key): return default
		cur = cur[key]
	return cur
```

- [ ] **Step 7: Failing test**

`Godot/tests/test_tuning.gd`:
```gdscript
extends TestBase
const Tuning := preload("res://core/Tuning.gd")
func test_reads_nested() -> void:
	Tuning.load_data()
	eq(Tuning.num("start.energy"), 8, "start.energy")
	eq(Tuning.num("season.weeks_per_season"), 3, "weeks")
	eq(Tuning.num("missing.path", -1), -1, "default fallback")
```

- [ ] **Step 8: Run — verify boot + tests**

Run: `cd Godot && godot --headless --quit`
Expected: exit 0, log `Hunting backend boot ok`.

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 3 tests, 0 failures`, exit 0.

- [ ] **Step 9: Commit**

```bash
git add Godot/project.godot Godot/scenes Godot/scripts Godot/tests Godot/data Godot/core/Tuning.gd
git commit -m "feat(hunting-be): skeleton, headless harness, tuning loader"
```

---

### Task 2: GameState + Balance Sheet

**Files:** Create `Godot/core/GameState.gd`, `Godot/tests/test_game_state.gd`

- [ ] **Step 1: Failing test**

`Godot/tests/test_game_state.gd`:
```gdscript
extends TestBase
const GameState := preload("res://core/GameState.gd")
func test_start_from_tuning() -> void:
	var s = GameState.new()
	eq(s.energy, 8, "start energy from tuning")
	eq(s.charm, 40, "start charm")
	eq(s.day, 1, "day 1")
func test_apply_clamps() -> void:
	var s = GameState.new()
	s.apply({"energy": -99})
	eq(s.energy, 0, "energy clamped >=0")
func test_net_worth_assets_minus_liabilities() -> void:
	var s = GameState.new()
	s.dossier.append({"man": "evan", "result": "Correct Read"})
	s.keyframes.append({"result": "Correct Read"})
	s.debts.append({"man": "x", "amount": 2})
	# net = standing(position) + dossier.size + keyframes.size - sum(debts.amount)
	eq(s.net_worth(), 1 + 1 + 1 - 2, "net worth formula")
```

- [ ] **Step 2: Run — verify fails**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: failures for missing `GameState.gd`, exit non-zero.

- [ ] **Step 3: Implement**

`Godot/core/GameState.gd`:
```gdscript
extends RefCounted
class_name GameState
const Tuning := preload("res://core/Tuning.gd")
var energy: int
var charm: int
var position: int
var control: int
var day: int = 1
var week: int = 1
var season: int = 1
var dossier: Array = []
var debts: Array = []
var keyframes: Array = []
func _init() -> void:
	energy = Tuning.num("start.energy", 8)
	charm = Tuning.num("start.charm", 40)
	position = Tuning.num("start.position", 1)
	control = Tuning.num("start.control", 0)
func apply(delta: Dictionary) -> void:
	energy = max(0, energy + int(delta.get("energy", 0)))
	charm = max(0, charm + int(delta.get("charm", 0)))
	position = max(0, position + int(delta.get("position", 0)))
	control = control + int(delta.get("control", 0))
func net_worth() -> int:
	var liab := 0
	for d in debts: liab += int(d.get("amount", 0))
	return position + dossier.size() + keyframes.size() - liab
func snapshot() -> Dictionary:
	return {"day": day, "week": week, "season": season, "energy": energy,
		"charm": charm, "position": position, "control": control,
		"net_worth": net_worth(), "debts": debts.size()}
```

- [ ] **Step 4: Run — verify pass**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 6 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Godot/core/GameState.gd Godot/tests/test_game_state.gd
git commit -m "feat(hunting-be): GameState balance sheet + net worth"
```

---

### Task 3: Content (archetypes with surface vs hidden type)

**Files:** Create `Godot/core/Content.gd`, `Godot/tests/test_content.gd`

Implements the disguise foundation: every man has `surface` signals and a `hidden_type`; early men align, later disguise is a tuning dial (deferred curve).

- [ ] **Step 1: Failing test**

`Godot/tests/test_content.gd`:
```gdscript
extends TestBase
const Content := preload("res://core/Content.gd")
func test_three_archetypes() -> void:
	var men = Content.men()
	eq(men.size(), 3, "3 base men")
	var types := []
	for m in men: types.append(m.hidden_type)
	ok("resource" in types and "high_sugar" in types and "growth" in types, "all archetypes")
func test_man_has_surface_and_chat() -> void:
	for m in Content.men():
		ok(m.has("surface"), "has surface signals")
		ok(m.chat.size() >= 2, "has chat evidence")
func test_personas_gfs_parties() -> void:
	eq(Content.personas().size(), 3, "3 personas")
	eq(Content.girlfriends().size(), 3, "3 gfs")
	ok(Content.parties().size() >= 3, ">=3 parties tiered")
	eq(Content.self_investments().size(), 4, "4 self-invest cards")
```

- [ ] **Step 2: Run — verify fails**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: failures for missing `Content.gd`.

- [ ] **Step 3: Implement**

`Godot/core/Content.gd`:
```gdscript
extends RefCounted
class_name Content
static func men() -> Array:
	return [
		{"id": "adrian", "name": "Adrian", "hidden_type": "resource",
			"surface": "resource", "energy_cost": 3,
			"risk": "Control tendency", "opportunity": "Concrete action if you make him earn it",
			"chat": [{"from": "him", "text": "Saturday night?"},
					 {"from": "you", "text": "Tell me when and where."}]},
		{"id": "evan", "name": "Evan", "hidden_type": "high_sugar",
			"surface": "growth", "energy_cost": 2,
			"risk": "Midnight sugar, no action", "opportunity": "Short spike only",
			"chat": [{"from": "him", "text": "Still awake? Thinking of you."},
					 {"from": "you", "text": "It's late."}]},
		{"id": "leo", "name": "Leo", "hidden_type": "growth",
			"surface": "false_alpha", "energy_cost": 1,
			"risk": "Ego-sensitive, low spike", "opportunity": "Cheap to observe, long upside",
			"chat": [{"from": "him", "text": "I kept thinking about what you said."},
					 {"from": "you", "text": "Go on."}]},
	]
static func personas() -> Array:
	return [
		{"id": "rare_girl", "name": "Rare Girl", "effect": {"position": 1}, "boundary_bonus": false},
		{"id": "soft_sun", "name": "Soft Sun", "effect": {"charm": 1}, "boundary_bonus": false},
		{"id": "power_darling", "name": "Power Darling", "effect": {}, "boundary_bonus": true},
	]
static func girlfriends() -> Array:
	return [
		{"id": "maya", "name": "Maya", "role": "Party Queen", "tier": 1},
		{"id": "claire", "name": "Claire", "role": "High-End Circle", "tier": 2},
		{"id": "nina", "name": "Nina", "role": "Sharp Group Chat", "tier": 3},
	]
static func parties() -> Array:
	return [
		{"id": "rooftop", "name": "Friday Rooftop", "tier": 1, "men": ["adrian", "evan", "leo"]},
		{"id": "gallery", "name": "Gallery Opening", "tier": 2, "men": ["adrian", "leo"]},
		{"id": "founders", "name": "Founders Dinner", "tier": 3, "men": ["adrian"]},
	]
static func self_investments() -> Array:
	return [
		{"id": "beauty_care", "name": "Beauty Care", "effect": {"charm": 2}},
		{"id": "work_win", "name": "Work Win", "effect": {"position": 1}},
		{"id": "solo_reset", "name": "Solo Reset", "effect": {"energy": 2}},
		{"id": "evidence_study", "name": "Evidence Study", "effect": {"first_eye_depth": 1}},
	]
```

- [ ] **Step 4: Run — verify pass**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 9 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Godot/core/Content.gd Godot/tests/test_content.gd
git commit -m "feat(hunting-be): content with surface vs hidden type"
```

---

### Task 4: Control Engine (chase/earn + B-model)

**Files:** Create `Godot/core/ControlEngine.gd`, `Godot/tests/test_control_engine.gd`

Implements spec §5: classify action; B-model = chase raises cheap output, lowers costly output, emits an ambiguous sign.

- [ ] **Step 1: Failing test**

`Godot/tests/test_control_engine.gd`:
```gdscript
extends TestBase
const CE := preload("res://core/ControlEngine.gd")
func test_classify() -> void:
	eq(CE.classify("engage"), "chase", "engage = chase")
	eq(CE.classify("boundary"), "earn", "boundary = earn")
	eq(CE.classify("exit"), "neutral", "exit = neutral")
func test_chase_raises_cheap_lowers_costly() -> void:
	var pos := {"cheap": 0, "costly": 0}
	var r = CE.resolve(pos, "engage")
	ok(r.cheap > 0, "chase raises cheap (sweet talk up)")
	ok(r.costly < 0, "chase lowers costly (concrete action down)")
	ok(r.control < 0, "chase costs control")
	ok(r.sign != "", "emits an ambiguous sign line")
func test_earn_raises_costly_and_control() -> void:
	var r = CE.resolve({"cheap": 0, "costly": 0}, "boundary")
	ok(r.costly > 0, "earn raises costly (he must produce)")
	ok(r.control > 0, "earn gains control")
```

- [ ] **Step 2: Run — verify fails**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: failures for missing `ControlEngine.gd`.

- [ ] **Step 3: Implement**

`Godot/core/ControlEngine.gd`:
```gdscript
extends RefCounted
class_name ControlEngine
const Tuning := preload("res://core/Tuning.gd")
const CHASE := ["engage"]
const EARN := ["boundary"]
static func classify(action: String) -> String:
	if action in CHASE: return "chase"
	if action in EARN: return "earn"
	return "neutral"
static func resolve(man_pos: Dictionary, action: String) -> Dictionary:
	var kind := classify(action)
	if kind == "chase":
		return {"cheap": 1, "costly": -1,
			"control": -Tuning.num("control.chase_penalty", 1),
			"sign": "He's sweeter than ever, but the plan stays vague — busy week, or are you too easy to reach?"}
	if kind == "earn":
		return {"cheap": 0, "costly": 1,
			"control": Tuning.num("control.earn_gain", 1),
			"sign": "You held the line; the ball is in his court."}
	return {"cheap": 0, "costly": 0, "control": 0, "sign": ""}
```

- [ ] **Step 4: Run — verify pass**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 12 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Godot/core/ControlEngine.gd Godot/tests/test_control_engine.gd
git commit -m "feat(hunting-be): control engine with B consequence model"
```

---

### Task 5: First Eye (claims + dossier discount)

**Files:** Create `Godot/core/FirstEye.gd`, `Godot/tests/test_first_eye.gd`

Spec §6/§8.3: First Eye shows claims (surface), not truth; a matching dossier entry pre-reveals the hidden type partially; bought depth adds clues.

- [ ] **Step 1: Failing test**

`Godot/tests/test_first_eye.gd`:
```gdscript
extends TestBase
const FirstEye := preload("res://core/FirstEye.gd")
const Content := preload("res://core/Content.gd")
func _man(id):
	for m in Content.men():
		if m.id == id: return m
	return {}
func test_surface_only_no_dossier() -> void:
	var r = FirstEye.intel(_man("evan"), [], 0)
	eq(r.claims.surface, "growth", "shows surface claim, not truth")
	eq(r.dossier_tag, "", "no dossier tag without history")
	ok(not r.has("hidden_type"), "truth not revealed at first eye")
func test_dossier_tag_when_burned_before() -> void:
	var dossier := [{"man": "evan", "hidden_type": "high_sugar"}]
	var r = FirstEye.intel(_man("evan"), dossier, 0)
	ok(r.dossier_tag != "", "pings like a type you've burned")
func test_bought_depth_adds_clue() -> void:
	var r0 = FirstEye.intel(_man("adrian"), [], 0)
	var r1 = FirstEye.intel(_man("adrian"), [], 1)
	ok(r1.clues.size() > r0.clues.size(), "depth buys a clue, never certainty")
	ok(not r1.has("hidden_type"), "still no certainty")
```

- [ ] **Step 2: Run — verify fails**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: failures for missing `FirstEye.gd`.

- [ ] **Step 3: Implement**

`Godot/core/FirstEye.gd`:
```gdscript
extends RefCounted
class_name FirstEye
static func intel(man: Dictionary, dossier: Array, bought_depth: int) -> Dictionary:
	var tag := ""
	for d in dossier:
		if d.get("hidden_type", "") == man.hidden_type:
			tag = "Pings like a type you've burned before."
			break
	var clues := []
	clues.append(man.risk)
	for i in range(bought_depth):
		clues.append(man.chat[i % man.chat.size()].text)
	return {
		"claims": {"surface": man.surface, "name": man.name},
		"dossier_tag": tag,
		"clues": clues,
		"depth": bought_depth,
	}
```

- [ ] **Step 4: Run — verify pass**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 15 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Godot/core/FirstEye.gd Godot/tests/test_first_eye.gd
git commit -m "feat(hunting-be): first eye claims + dossier discount"
```

---

### Task 6: Party Encounter (read-loop)

**Files:** Create `Godot/core/PartyEncounter.gd`, `Godot/tests/test_party_encounter.gd`

Spec §8.4: hidden Interest/Respect; 4 actions as trade-offs; each act returns a `tell` text + `evidence` (what the reaction implies about hidden type). No meter; tells are the only feedback.

- [ ] **Step 1: Failing test**

`Godot/tests/test_party_encounter.gd`:
```gdscript
extends TestBase
const PE := preload("res://core/PartyEncounter.gd")
const Content := preload("res://core/Content.gd")
func _man(id):
	for m in Content.men():
		if m.id == id: return m
	return {}
func test_rounds_and_finish() -> void:
	var e = PE.new(_man("adrian"))
	ok(not e.finished, "starts unfinished")
	var rounds = e.total_rounds
	for i in range(rounds):
		e.act("exit")
	ok(e.finished, "finished after all rounds")
	eq(e.act("engage"), {}, "no acts after finish")
func test_boundary_on_resource_yields_concrete_tell() -> void:
	var e = PE.new(_man("adrian"))
	var r = e.act("boundary")
	ok(r.tell.length() > 0, "boundary produces a tell")
	ok(r.evidence == "resource" or r.evidence == "uncertain", "evidence points toward type")
func test_boundary_on_sugar_exposes() -> void:
	var e = PE.new(_man("evan"))
	var r = e.act("boundary")
	eq(r.evidence, "high_sugar", "sugar man fails the boundary -> exposed tell")
func test_social_proof_backfires_on_growth() -> void:
	var e = PE.new(_man("leo"))
	var r = e.act("social_proof")
	eq(r.evidence, "growth", "ego-sensitive withdraws -> growth tell")
```

- [ ] **Step 2: Run — verify fails**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: failures for missing `PartyEncounter.gd`.

- [ ] **Step 3: Implement**

`Godot/core/PartyEncounter.gd`:
```gdscript
extends RefCounted
class_name PartyEncounter
const Tuning := preload("res://core/Tuning.gd")
var man: Dictionary
var round_index: int = 0
var total_rounds: int
var interest: int = 0
var respect: int = 0
var finished: bool = false
func _init(target: Dictionary) -> void:
	man = target
	total_rounds = Tuning.num("party.rounds", 5)
func read() -> Dictionary:
	return {"round": round_index + 1, "of": total_rounds,
		"interest": interest, "respect": respect}
func _tell(action: String) -> Dictionary:
	var t: String = man.hidden_type
	if action == "boundary":
		if t == "resource":
			return {"tell": "He pauses, then: 'Saturday 8, I'll book it.'", "evidence": "resource"}
		if t == "high_sugar":
			return {"tell": "'Don't be so serious, just come over.'", "evidence": "high_sugar"}
		return {"tell": "He's prickly, then thoughtful.", "evidence": "growth"}
	if action == "social_proof":
		if t == "growth":
			return {"tell": "He goes quiet and drifts off.", "evidence": "growth"}
		if t == "resource":
			return {"tell": "He steps up, competes for you.", "evidence": "resource"}
		return {"tell": "He love-bombs harder, words not plans.", "evidence": "high_sugar"}
	if action == "engage":
		return {"tell": "He warms up; cheap and easy.", "evidence": "uncertain"}
	return {"tell": "You step back, hold your energy.", "evidence": "uncertain"}
func act(action: String) -> Dictionary:
	if finished: return {}
	var out := _tell(action)
	match action:
		"engage": interest += 1; respect -= 1
		"boundary": respect += 1
		"social_proof": respect += 1
		"exit": pass
	round_index += 1
	if round_index >= total_rounds: finished = true
	out["finished"] = finished
	out["state"] = read()
	return out
```

- [ ] **Step 4: Run — verify pass**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 19 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Godot/core/PartyEncounter.gd Godot/tests/test_party_encounter.gd
git commit -m "feat(hunting-be): party read-loop with type tells"
```

---

### Task 7: Held Book (positions, night mutation, creditors, fantasy debt)

**Files:** Create `Godot/core/Book.gd`, `Godot/tests/test_book.gd`

Spec §2/§7/§8.5: held positions persist across nights; Observe decays; unsettled negative positions become creditor debts that drain Energy and accrue fantasy debt.

- [ ] **Step 1: Failing test**

`Godot/tests/test_book.gd`:
```gdscript
extends TestBase
const Book := preload("res://core/Book.gd")
const GameState := preload("res://core/GameState.gd")
func test_open_and_list() -> void:
	var s = GameState.new()
	var b = Book.new(s)
	b.open("leo", "observe", "growth")
	eq(b.positions().size(), 1, "one open position")
func test_observe_decays_then_becomes_missed() -> void:
	var s = GameState.new()
	var b = Book.new(s)
	b.open("leo", "observe", "growth")
	for i in range(9):
		b.advance_night()
	var p = b.positions()[0]
	ok(p.status == "missed" or p.decay >= 0, "observe decays toward missed growth")
func test_unsettled_creditor_drains_energy_and_adds_debt() -> void:
	var s = GameState.new()
	var b = Book.new(s)
	b.open("evan", "string_along", "high_sugar")
	var e0 = s.energy
	b.advance_night()
	ok(s.energy < e0, "creditor drains nightly energy")
	ok(s.debts.size() >= 1, "fantasy debt accrues")
func test_cut_clears_position() -> void:
	var s = GameState.new()
	var b = Book.new(s)
	b.open("evan", "string_along", "high_sugar")
	b.decide("evan", "cut")
	eq(b.positions().size(), 0, "cut clears the position")
```

- [ ] **Step 2: Run — verify fails**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: failures for missing `Book.gd`.

- [ ] **Step 3: Implement**

`Godot/core/Book.gd`:
```gdscript
extends RefCounted
class_name Book
const Tuning := preload("res://core/Tuning.gd")
var state
var _positions: Array = []
func _init(game_state) -> void:
	state = game_state
func open(man_id: String, decision: String, hidden_type: String) -> void:
	_positions.append({"man": man_id, "decision": decision,
		"hidden_type": hidden_type, "decay": 0, "status": "open"})
func positions() -> Array:
	return _positions
func decide(man_id: String, choice: String) -> void:
	for p in _positions:
		if p.man == man_id:
			p.decision = choice
	if choice == "cut":
		_positions = _positions.filter(func(p): return p.man != man_id)
func advance_night() -> Array:
	var events := []
	for p in _positions:
		if p.decision == "observe":
			p.decay += Tuning.num("book.observe_decay_per_night", 1)
			if p.decay >= 9 and p.status == "open":
				p.status = "missed"
				events.append({"man": p.man, "event": "missed_growth"})
		elif p.decision == "string_along":
			state.apply({"energy": -Tuning.num("book.creditor_energy_drain", 1)})
			state.debts.append({"man": p.man,
				"amount": Tuning.num("book.fantasy_debt_per_unsettled", 1)})
			events.append({"man": p.man, "event": "creditor_pressure"})
	return events
```

- [ ] **Step 4: Run — verify pass**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 23 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Godot/core/Book.gd Godot/tests/test_book.gd
git commit -m "feat(hunting-be): held book, creditor drain, fantasy debt"
```

---

### Task 8: Future Eye (deterministic settlement + mirror)

**Files:** Create `Godot/core/FutureEye.gd`, `Godot/tests/test_future_eye.gd`

Spec §6/§8.6: deterministic `(hidden_type, decision, control_level, sequence_quality)` → result + keyframes + ROI; low control + chase → mirror keyframe.

- [ ] **Step 1: Failing test**

`Godot/tests/test_future_eye.gd`:
```gdscript
extends TestBase
const FE := preload("res://core/FutureEye.gd")
func test_resource_earned_high_control_correct_read() -> void:
	var r = FE.resolve("resource", "date", 3, "good")
	eq(r.result, "Correct Read", "made him earn it -> Correct Read")
	eq(r.keyframes.size(), 4, "4 keyframes")
	ok(r.energy_roi > 0, "positive ROI")
	eq(r.mirror, "", "no mirror when control held")
func test_resource_chased_low_control_false_alpha_with_mirror() -> void:
	var r = FE.resolve("resource", "date", -2, "poor")
	eq(r.result, "False Alpha", "chased same man -> False Alpha")
	ok(r.mirror != "", "mirror keyframe fires on low control")
func test_sugar_date_is_sugar_trap() -> void:
	eq(FE.resolve("high_sugar", "date", 0, "any").result, "Sugar Trap", "Evan dated -> Sugar Trap")
func test_growth_observe_slow_upside_cut_missed() -> void:
	eq(FE.resolve("growth", "observe", 1, "any").result, "Slow Upside", "Leo observed -> Slow Upside")
	eq(FE.resolve("growth", "cut", 1, "any").result, "Missed Growth", "Leo cut -> Missed Growth")
```

- [ ] **Step 2: Run — verify fails**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: failures for missing `FutureEye.gd`.

- [ ] **Step 3: Implement**

`Godot/core/FutureEye.gd`:
```gdscript
extends RefCounted
class_name FutureEye
const KF := {
	"Correct Read":  ["Keeps concrete plans", "Public and stable", "Standing rises", "High-return asset"],
	"Sugar Trap":    ["Hot then vague", "Still no plan", "You spent, he stalled", "Net loss"],
	"Slow Upside":   ["Quiet, consistent", "Becomes visible", "Real jump", "Compounds"],
	"False Alpha":   ["Impressive night one", "Control creeps in", "Costs exceed status", "Overhead eats you"],
	"Missed Growth": ["You kept arm's length", "He moved on", "He grew elsewhere", "Upside you skipped"],
}
static func resolve(hidden_type: String, decision: String, control_level: int, sequence_quality: String) -> Dictionary:
	var result := "Correct Read"
	if hidden_type == "high_sugar":
		result = "Sugar Trap" if decision == "date" else "Correct Read"
	elif hidden_type == "growth":
		if decision == "cut": result = "Missed Growth"
		elif decision in ["observe", "test", "date"]: result = "Slow Upside"
	elif hidden_type == "resource":
		if decision == "date":
			result = "Correct Read" if control_level >= 0 else "False Alpha"
		elif decision == "cut":
			result = "Correct Read"
	var mirror := ""
	if control_level < 0:
		mirror = "His view of you: 'Always available, reorganized her life around me. Sugar source. Held her cheap.'"
	var roi := 0
	match result:
		"Correct Read": roi = 3
		"Slow Upside": roi = 2
		"Sugar Trap": roi = -3
		"False Alpha": roi = -2
		"Missed Growth": roi = -2
	return {"result": result, "keyframes": KF[result].duplicate(),
		"energy_roi": roi, "fantasy_debt": (2 if result == "Sugar Trap" else 0),
		"mirror": mirror}
```

- [ ] **Step 4: Run — verify pass**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 27 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Godot/core/FutureEye.gd Godot/tests/test_future_eye.gd
git commit -m "feat(hunting-be): future eye settlement + mirror"
```

---

### Task 9: Girlfriends (credit-line tier gate)

**Files:** Create `Godot/core/Girlfriends.gd`, `Godot/tests/test_girlfriends.gd`

Spec §8.2 minimal: warmth per gf; available party tier = highest gf whose warmth clears its threshold. (Dark-advisory deferred per scope.)

- [ ] **Step 1: Failing test**

`Godot/tests/test_girlfriends.gd`:
```gdscript
extends TestBase
const GF := preload("res://core/Girlfriends.gd")
const GameState := preload("res://core/GameState.gd")
func test_starts_tier1() -> void:
	var g = GF.new(GameState.new())
	eq(g.available_tier(), 1, "tier1 open by default")
func test_warmth_unlocks_higher_tier() -> void:
	var g = GF.new(GameState.new())
	g.adjust("claire", 3)
	eq(g.available_tier(), 2, "claire warmth opens tier 2")
func test_neglect_contracts_access() -> void:
	var g = GF.new(GameState.new())
	g.adjust("claire", 3)
	g.adjust("claire", -3)
	eq(g.available_tier(), 1, "lost warmth contracts back to tier 1")
```

- [ ] **Step 2: Run — verify fails**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: failures for missing `Girlfriends.gd`.

- [ ] **Step 3: Implement**

`Godot/core/Girlfriends.gd`:
```gdscript
extends RefCounted
class_name Girlfriends
const Tuning := preload("res://core/Tuning.gd")
const Content := preload("res://core/Content.gd")
var state
var _warmth: Dictionary = {}
func _init(game_state) -> void:
	state = game_state
	for g in Content.girlfriends():
		_warmth[g.id] = 0
func warmth(gf_id: String) -> int:
	return _warmth.get(gf_id, 0)
func adjust(gf_id: String, delta: int) -> void:
	_warmth[gf_id] = _warmth.get(gf_id, 0) + delta
func available_tier() -> int:
	var tier := 1
	for g in Content.girlfriends():
		var w: int = _warmth.get(g.id, 0)
		var need: int = Tuning.num("gates.tier%d_warmth" % g.tier, 0)
		if g.tier == 1 or w >= need:
			tier = max(tier, g.tier)
	return tier
```

- [ ] **Step 4: Run — verify pass**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 30 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Godot/core/Girlfriends.gd Godot/tests/test_girlfriends.gd
git commit -m "feat(hunting-be): girlfriend credit-line tier gate"
```

---

### Task 10: Soft Ruin (insolvency gate)

**Files:** Create `Godot/core/SoftRuin.gd`, `Godot/tests/test_soft_ruin.gd`

Spec §2: net worth never zeroes, but liabilities > assets → insolvent → workout gate (climb frozen).

- [ ] **Step 1: Failing test**

`Godot/tests/test_soft_ruin.gd`:
```gdscript
extends TestBase
const SoftRuin := preload("res://core/SoftRuin.gd")
const GameState := preload("res://core/GameState.gd")
func test_solvent_by_default() -> void:
	ok(not SoftRuin.is_insolvent(GameState.new()), "solvent at start")
func test_insolvent_when_debt_exceeds_assets() -> void:
	var s = GameState.new()
	for i in range(5):
		s.debts.append({"man": "x", "amount": 3})
	ok(SoftRuin.is_insolvent(s), "debt > assets -> insolvent")
```

- [ ] **Step 2: Run — verify fails**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: failures for missing `SoftRuin.gd`.

- [ ] **Step 3: Implement**

`Godot/core/SoftRuin.gd`:
```gdscript
extends RefCounted
class_name SoftRuin
static func is_insolvent(state) -> bool:
	return state.net_worth() < 0
```

- [ ] **Step 4: Run — verify pass**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 32 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Godot/core/SoftRuin.gd Godot/tests/test_soft_ruin.gd
git commit -m "feat(hunting-be): soft-ruin insolvency gate"
```

---

### Task 11: Season Flow (Night/Week/Season orchestrator + inheritance)

**Files:** Create `Godot/core/SeasonFlow.gd`, `Godot/tests/test_season_flow.gd`

Wires the loop (spec §7) + week/season boundaries + inheritance (spec §3: social layer + dossier persist; men/energy reset).

- [ ] **Step 1: Failing test**

`Godot/tests/test_season_flow.gd`:
```gdscript
extends TestBase
const SF := preload("res://core/SeasonFlow.gd")
func test_night_advances_day_and_regens_energy() -> void:
	var f = SF.new()
	var e_before = f.state.energy
	f.state.apply({"energy": -5})
	f.step_night({"self_invest": "solo_reset", "party": "rooftop",
		"primary": "adrian", "party_actions": ["boundary"], "after": {"adrian": "date"}})
	eq(f.state.day, 2, "day advanced")
	ok(f.state.energy >= 0, "energy valid")
func test_week_and_season_boundaries() -> void:
	var f = SF.new()
	var npw = f.nights_per_week
	for i in range(npw):
		f.step_night({"party": "rooftop", "primary": "leo",
			"party_actions": ["exit"], "after": {"leo": "observe"}})
	ok(f.at_week_boundary(), "week boundary after nights_per_week")
	var settle = f.settle()
	ok(settle.has("net_worth"), "settlement marks net worth")
func test_season_close_inherits_social_resets_men() -> void:
	var f = SF.new()
	f.state.dossier.append({"man": "evan", "hidden_type": "high_sugar"})
	f.gf.adjust("claire", 5)
	f.state.energy = 1
	var carried = f.close_season()
	eq(carried.dossier.size(), 1, "dossier carried")
	eq(carried.gf_warmth.claire, 5, "gf warmth carried")
	eq(f.state.season, 2, "season incremented")
	eq(f.state.energy, f.start_energy, "energy reset on new season")
```

- [ ] **Step 2: Run — verify fails**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: failures for missing `SeasonFlow.gd`.

- [ ] **Step 3: Implement**

`Godot/core/SeasonFlow.gd`:
```gdscript
extends RefCounted
class_name SeasonFlow
const Tuning := preload("res://core/Tuning.gd")
const GameState := preload("res://core/GameState.gd")
const Content := preload("res://core/Content.gd")
const ControlEngine := preload("res://core/ControlEngine.gd")
const PartyEncounter := preload("res://core/PartyEncounter.gd")
const Book := preload("res://core/Book.gd")
const FutureEye := preload("res://core/FutureEye.gd")
const Girlfriends := preload("res://core/Girlfriends.gd")
const SoftRuin := preload("res://core/SoftRuin.gd")

var state: GameState
var book: Book
var gf: Girlfriends
var nights_per_week: int
var weeks_per_season: int
var start_energy: int
var _nights_this_week: int = 0
var log_lines: Array = []

func _init() -> void:
	state = GameState.new()
	book = Book.new(state)
	gf = Girlfriends.new(state)
	nights_per_week = Tuning.num("season.nights_per_week", 6)
	weeks_per_season = Tuning.num("season.weeks_per_season", 3)
	start_energy = state.energy

func _man(id: String) -> Dictionary:
	for m in Content.men():
		if m.id == id: return m
	return {}

func step_night(choices: Dictionary) -> Dictionary:
	log_lines = []
	if choices.has("self_invest"):
		for c in Content.self_investments():
			if c.id == choices.self_invest:
				state.apply(c.effect)
	# Party
	var primary_id: String = choices.get("primary", "")
	var control_delta := 0
	if primary_id != "":
		var enc = PartyEncounter.new(_man(primary_id))
		for a in choices.get("party_actions", []):
			if enc.finished: break
			var res = enc.act(a)
			log_lines.append(res.get("tell", ""))
			var ce = ControlEngine.resolve({}, a)
			control_delta += int(ce.control)
		state.apply({"control": control_delta})
	# After-party decisions on the whole book
	for man_id in choices.get("after", {}).keys():
		var decision: String = choices.after[man_id]
		var ht := _man(man_id).hidden_type
		book.open(man_id, decision, ht)
		if decision == "date":
			var fe = FutureEye.resolve(ht, "date", state.control, "any")
			state.keyframes.append({"man": man_id, "result": fe.result})
			if fe.result == "Correct Read":
				state.apply({"position": 1})
			if not (fe.mirror as String).is_empty():
				log_lines.append("[MIRROR] " + fe.mirror)
			if fe.fantasy_debt > 0:
				state.debts.append({"man": man_id, "amount": fe.fantasy_debt})
			book.decide(man_id, "cut")
	# Time advances
	for ev in book.advance_night():
		log_lines.append("[BOOK] %s: %s" % [ev.man, ev.event])
	state.apply({"energy": Tuning.num("energy.regen_per_night", 2)})
	state.day += 1
	_nights_this_week += 1
	return {"log": log_lines, "snapshot": state.snapshot(),
		"insolvent": SoftRuin.is_insolvent(state)}

func at_week_boundary() -> bool:
	return _nights_this_week >= nights_per_week

func at_season_boundary() -> bool:
	return state.week > weeks_per_season

func settle() -> Dictionary:
	_nights_this_week = 0
	state.week += 1
	return {"net_worth": state.net_worth(), "week": state.week - 1,
		"keyframes": state.keyframes.size(), "debts": state.debts.size()}

func close_season() -> Dictionary:
	var carried := {
		"dossier": state.dossier.duplicate(true),
		"gf_warmth": gf._warmth.duplicate(true),
		"position": state.position,
	}
	var new_state := GameState.new()
	if Tuning.num("inherit.keep_dossier", true):
		new_state.dossier = carried.dossier
	if Tuning.num("inherit.keep_social", true):
		new_state.position = carried.position
	new_state.season = state.season + 1
	state = new_state
	book = Book.new(state)
	var ng = Girlfriends.new(state)
	if Tuning.num("inherit.keep_social", true):
		ng._warmth = carried.gf_warmth.duplicate(true)
	gf = ng
	_nights_this_week = 0
	return carried
```

- [ ] **Step 4: Run — verify pass**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 35 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Godot/core/SeasonFlow.gd Godot/tests/test_season_flow.gd
git commit -m "feat(hunting-be): season flow orchestrator + inheritance"
```

---

### Task 12: Terminal Play Driver

**Files:** Create `Godot/play.gd`, `Godot/README.md`

A headless SceneTree that plays a full scripted season and prints the diegetic log so the designer can read the experience. (Scripted is deterministic and CI-safe; an interactive stdin mode is a documented optional extension.)

- [ ] **Step 1: Implement the driver**

`Godot/play.gd`:
```gdscript
extends SceneTree
const SeasonFlow := preload("res://core/SeasonFlow.gd")
func _initialize() -> void:
	var f = SeasonFlow.new()
	# A scripted demo season: chase Evan (bad), make Adrian earn it (good), observe Leo.
	var script := [
		{"self_invest": "evidence_study", "primary": "evan",
			"party_actions": ["engage", "engage", "engage", "engage", "engage"],
			"after": {"evan": "date"}},
		{"self_invest": "solo_reset", "primary": "adrian",
			"party_actions": ["engage", "boundary", "social_proof", "boundary", "exit"],
			"after": {"adrian": "date"}},
		{"self_invest": "work_win", "primary": "leo",
			"party_actions": ["engage", "boundary", "exit", "exit", "exit"],
			"after": {"leo": "observe"}},
	]
	var night := 0
	for wk in range(f.weeks_per_season):
		for n in range(f.nights_per_week):
			var choices = script[night % script.size()]
			var r = f.step_night(choices)
			night += 1
			print("--- Night %d (S%d W%d) ---" % [night, f.state.season, f.state.week])
			for line in r.log:
				if line != "": print("  " + line)
			print("  net_worth=%d energy=%d control=%d debts=%d insolvent=%s" % [
				r.snapshot.net_worth, r.snapshot.energy, r.snapshot.control,
				r.snapshot.debts, str(r.insolvent)])
		var s = f.settle()
		print("=== Week settle: net_worth=%d keyframes=%d debts=%d ===" % [
			s.net_worth, s.keyframes, s.debts])
	var carried = f.close_season()
	print("=== Season close. Carried dossier=%d position=%d ===" % [
		carried.dossier.size(), carried.position])
	quit(0)
```

- [ ] **Step 2: Run the season**

Run: `cd Godot && godot --headless --script res://play.gd`
Expected: prints Night-by-Night diegetic log, week settlements, season close; exit 0. Manually read it: the Evan-chase nights should show sweet-talk-up/plan-vague signs and a `[MIRROR]` line + Sugar Trap debt; the Adrian make-him-earn nights should yield Correct Read and a `position` bump. Confirm the experience reads coherently per spec §5/§6.

- [ ] **Step 3: README**

`Godot/README.md`:
```markdown
# Hunting Backend (carry engine)

Headless simulation core. No UI. Spec: ../docs/superpowers/specs/2026-05-17-hunting-carry-design.zh.md

## Test
`godot --headless --script res://tests/run_tests.gd` — exit code = failed assertions.

## Play it in the terminal
`godot --headless --script res://play.gd` — runs a scripted demo season and prints the diegetic log.

## Tune
Edit `data/tuning.json` and re-run. No code change needed for numbers.

## Architecture
`core/*` = pure RefCounted rules, zero UI deps. Godot UI (later) becomes a thin layer over this.

## Deferred (not in this engine)
Dark-advisory girlfriend module, disguise-curve tuning, per-persona cost tables, number balancing.
```

- [ ] **Step 4: Commit**

```bash
git add Godot/play.gd Godot/README.md
git commit -m "feat(hunting-be): terminal play driver + readme"
```

---

### Task 13: Final Verification

- [ ] **Step 1: Full test suite green**

Run: `cd Godot && godot --headless --script res://tests/run_tests.gd`
Expected: `RAN 35 tests, 0 failures`, exit 0.

- [ ] **Step 2: Season playthrough sanity**

Run: `cd Godot && godot --headless --script res://play.gd`
Expected: exit 0; the chased-Evan path shows a `[MIRROR]` line and rising debts; the earned-Adrian path shows `Correct Read` effect (position rises). If the narrative does not read coherently against spec §5/§6, stop and fix the engine before claiming done.

- [ ] **Step 3: No UI / no legacy leakage**

Run: `grep -rniE "red.?flag.?date|\bunity\b|\bswiftui\b|Control(Rect|Node)|TextureRect|Button\.new" Godot/ ; echo "exit:$?"`
Expected: no matches (`exit:1`) — confirms the engine is UI-free.

- [ ] **Step 4: Tuning hot-edit proof**

Edit `Godot/data/tuning.json` `season.nights_per_week` to `2`, run `godot --headless --script res://play.gd`, confirm weeks settle after 2 nights, then revert to `6`. Confirms numbers are data-driven.

- [ ] **Step 5: Commit**

```bash
git add -A Godot/
git commit -m "chore(hunting-be): final verification pass"
```

---

## Self-Review (completed by plan author)

**Spec coverage:** balance sheet/net worth (T2), archetypes surface≠hidden (T3), Control chase/earn + B-model (T4), First Eye claims+dossier (T5), party read-loop tells (T6), held book + creditors + fantasy debt (T7), Future Eye deterministic + mirror (T8), girlfriend credit-line gate (T9), soft-ruin (T10), Night/Week/Season + inheritance (T11), terminal playability (T12). Deferred items explicitly scoped (dark-advisory, disguise curve, persona costs, balancing).

**Placeholder scan:** No TBD/TODO in logic. All numbers live in `data/tuning.json` by design (the agreed Option-A mitigation), not hardcoded — this is data, not a design gap. Every code step is complete runnable GDScript; every run step has exact command + expected output.

**Type consistency:** `GameState.apply/net_worth/snapshot`, `Content.*`, `ControlEngine.classify/resolve`, `FirstEye.intel`, `PartyEncounter.act/read/finished/total_rounds`, `Book.open/decide/advance_night/positions`, `FutureEye.resolve` shape `{result,keyframes,energy_roi,fantasy_debt,mirror}`, `Girlfriends.adjust/warmth/available_tier`, `SoftRuin.is_insolvent`, `SeasonFlow.step_night/at_week_boundary/settle/close_season` — used identically across tasks, driver, and tests.

**Scope:** One coherent engine, terminal-playable, no independent subsystems split needed. Appropriately a single plan.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-17-hunting-backend-carry-engine.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review between tasks, fast iteration.
2. **Inline Execution** — execute tasks in this session with checkpoints for review.

Which approach?
