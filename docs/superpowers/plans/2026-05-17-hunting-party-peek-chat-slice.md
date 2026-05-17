# 派对首要钩子 · 看聊记切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the backend of the game's first hook — "选中一个男人 → 看他跟别人的聊记 → 从他对别人怎么说里读出糖/料" — as a deterministic, headless-testable core, with a small but genuinely evocative sample corpus.

**Architecture:** Reuse the existing truth model (`Content.men()` already carries `hidden_type` = the料/糖 truth and `surface` = his performance to her). Add a per-man `others_chat` corpus: a short transcript of him talking to OTHER people, authored so his true `hidden_type` leaks through *how he talks to others* even when his `surface` to her differs. Add a thin pure module `PeekChat` that returns the viewable record **without ever exposing the hidden truth** (clue-not-answer, exactly like `FirstEye` never returns `hidden_type`). No UI, no scarcity/cost numerics, no live dialogue — those are explicitly out of this slice (spec §"明确不在本 spec 内"; user scoped this as "先只做看聊记这一击").

**Tech Stack:** Godot 4.6 GDScript, pure `RefCounted` core, custom headless test harness (`tests/run_tests.gd` SceneTree runner, `tests/test_base.gd` soft-assert base, path-based `extends "res://tests/test_base.gd"`). Determinism: no RNG. Soul: cold-premium, anti-otome, she-at-the-centre, code-gen (no art, text only).

**Spec:** `docs/superpowers/specs/2026-05-17-hunting-party-concept-design.zh.md` (locked). Relevant: §"派对前的开天眼：看他跟别人的聊记", §"首要钩子（设计原则）", §"核心内容依赖"(赛前聊记语料).

---

## File Structure

- **Modify** `Godot/core/Content.gd` — add an `others_chat` array field to each of the 3 men in `men()`. No other function touched. Existing `hidden_type`/`surface` semantics unchanged.
- **Create** `Godot/core/PeekChat.gd` — `class_name PeekChat`, one static func `peek(man: Dictionary) -> Dictionary`. Pure, deterministic, never returns the truth.
- **Create** `Godot/tests/test_peek_chat.gd` — `extends "res://tests/test_base.gd"`; covers content integrity + the truth-stays-hidden contract + determinism.
- **Modify** `Godot/tests/run_tests.gd` — register the new test in the `TESTS` const array (every test in this project is registered there; this is the standard pattern).
- **Create** `Godot/peek_smoke.gd` — `extends SceneTree` headless demonstrator (mirrors `play.gd`/`ui_smoke.gd`): prints one disguised man's peek so the reveal is visible without a UI. Committed dev helper, NOT added to `TESTS`.

**Out of scope (do NOT add):** any UI/scene, any `hidden_type`-revealing API, scarcity/energy cost, live branching dialogue, axis (H/S) logic, hub-shell changes, `tuning.json` changes, `Loc.gd` changes.

---

### Task 1: `others_chat` corpus on `Content.men()`

The reveal content. Each man gets a short transcript of him talking to OTHER people. The corpus must be authored so his true `hidden_type` is legible from *how he talks to others*, regardless of his `surface` (performance to her). Two of the three men are "disguised" (`surface != hidden_type`) — those are the emotional payoff (one 爽: the cold one is actually real; one 痛: the sweet one is hollow).

**Files:**
- Modify: `Godot/core/Content.gd:3-20` (the `men()` function — add `others_chat` to each of the 3 entries)
- Create: `Godot/tests/test_peek_chat.gd`
- Modify: `Godot/tests/run_tests.gd` (append the new test path to `TESTS`)

- [ ] **Step 1: Register the new test file in the runner**

In `Godot/tests/run_tests.gd`, add `"res://tests/test_peek_chat.gd",` to the `TESTS` array, right after `"res://tests/test_dm_signals.gd",` (last entry). The array becomes:

```gdscript
	"res://tests/test_seasonflow_dossier.gd",
	"res://tests/test_dm_signals.gd",
	"res://tests/test_peek_chat.gd",
]
```

- [ ] **Step 2: Write the failing content-integrity test**

Create `Godot/tests/test_peek_chat.gd`:

```gdscript
extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")

func _man(id: String) -> Dictionary:
	for m in Content.men():
		if m["id"] == id:
			return m
	return {}

func test_every_man_has_others_chat() -> void:
	var men: Array = Content.men()
	ok(men.size() >= 3, "≥3 men")
	for m in men:
		ok(m.has("others_chat"), "man %s has others_chat" % str(m.get("id", "?")))
		var oc: Array = m["others_chat"]
		ok(oc.size() >= 2, "others_chat for %s has ≥2 lines" % str(m["id"]))
		for line in oc:
			ok(line.has("to") and line.has("text"), "line shape {to,text} for %s" % str(m["id"]))
			ok(str(line["to"]) != "you" and str(line["to"]) != "him", "line is to OTHERS, not her/him echo (%s)" % str(m["id"]))
			ok(str(line["text"]).strip_edges() != "", "non-empty line text for %s" % str(m["id"]))

func test_disguised_men_have_revealing_chat() -> void:
	# At least two men where his performance to her (surface) != his truth (hidden_type):
	# those are the emotional reveal cases and MUST carry an others_chat.
	var disguised := 0
	for m in Content.men():
		if m["surface"] != m["hidden_type"]:
			disguised += 1
			ok((m["others_chat"] as Array).size() >= 2, "disguised man %s has a real others_chat" % str(m["id"]))
	ok(disguised >= 2, "≥2 disguised men exist (surface != hidden_type)")

func test_known_reveal_cases_present() -> void:
	# evan: sweet/sugar truth, performs 'growth' to her -> 痛 reveal.
	# leo: real/growth truth, postures 'false_alpha' to her -> 爽 reveal.
	var evan := _man("evan")
	var leo := _man("leo")
	eq(evan["hidden_type"], "high_sugar", "evan truth = high_sugar")
	eq(evan["surface"], "growth", "evan performs growth to her (disguised)")
	ok((evan["others_chat"] as Array).size() >= 2, "evan others_chat exists")
	eq(leo["hidden_type"], "growth", "leo truth = growth")
	eq(leo["surface"], "false_alpha", "leo postures false_alpha to her (disguised)")
	ok((leo["others_chat"] as Array).size() >= 2, "leo others_chat exists")
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -5`
Expected: `RAN <N> tests, <≥1> failures` with `FAIL res://tests/test_peek_chat.gd::test_every_man_has_others_chat -> man adrian has others_chat` (and the others) — because `others_chat` does not exist yet.

- [ ] **Step 4: Add the `others_chat` corpus to the 3 men**

In `Godot/core/Content.gd`, the `men()` function (lines 3-20), add an `others_chat` field to each entry. Replace the entire `men()` function body with (keep every existing field exactly; only ADD `others_chat`):

```gdscript
static func men() -> Array:
	return [
		{"id": "adrian", "name": "Adrian", "hidden_type": "resource",
			"surface": "resource", "energy_cost": 3,
			"risk": "Control tendency", "opportunity": "Concrete action if you make him earn it",
			"chat": [{"from": "him", "text": "Saturday night?"},
					 {"from": "you", "text": "Tell me when and where."}],
			"others_chat": [
				{"to": "a colleague", "text": "Can't do Thursday. I'll have the numbers to you Friday 9am — you'll have them."},
				{"to": "his sister", "text": "Booked Mum's flights. Aisle seat like she likes. Don't tell her, let her find out."},
				{"to": "an ex", "text": "I'm not doing the late-night thing. If you want to talk, it's a call, daytime."}]},
		{"id": "evan", "name": "Evan", "hidden_type": "high_sugar",
			"surface": "growth", "energy_cost": 2,
			"risk": "Midnight sugar, no action", "opportunity": "Short spike only",
			"chat": [{"from": "him", "text": "Still awake? Thinking of you."},
					 {"from": "you", "text": "It's late."}],
			"others_chat": [
				{"to": "another girl, 1:14am", "text": "you're not like the others. you actually get me 🌙"},
				{"to": "a third girl, last Tuesday", "text": "you're different. nobody's ever understood me like you do"},
				{"to": "the group chat", "text": "lmaooo I just say what they wanna hear, who's actually showing up tho"}]},
		{"id": "leo", "name": "Leo", "hidden_type": "growth",
			"surface": "false_alpha", "energy_cost": 1,
			"risk": "Ego-sensitive, low spike", "opportunity": "Cheap to observe, long upside",
			"chat": [{"from": "him", "text": "I kept thinking about what you said."},
					 {"from": "you", "text": "Go on."}],
			"others_chat": [
				{"to": "his best friend", "text": "I was loud at the table, I know. Overdid it. Working on it, genuinely."},
				{"to": "a mentor", "text": "You said one line three months ago about compounding patience. I still think about it."},
				{"to": "his brother", "text": "Didn't get the round. It's fair. Going back in better, not louder."}]},
	]
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `RAN <N> tests, 0 failures` (N is the prior count + 3 new tests).

- [ ] **Step 6: Commit**

```bash
git add Godot/core/Content.gd Godot/tests/test_peek_chat.gd Godot/tests/run_tests.gd
git commit -m "$(cat <<'EOF'
feat(hunting): others_chat corpus — how he talks to OTHERS leaks his truth

Per-man chat-with-others transcript on Content.men(); authored so the
hidden 料/糖 truth reads through regardless of his surface to her. Two
disguised reveal cases (evan: sweet→hollow 痛; leo: posturing→real 爽).
Backend only; no truth-exposing API, no UI, no cost.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `PeekChat.peek(man)` — view it, truth stays hidden

The accessor the future UI calls. It returns the viewable record: his name, the *surface* he performs to her, and his chats-with-others. It MUST NOT return `hidden_type` — the reveal is the player's to read (clue not answer), exactly as `FirstEye.intel` never returns `hidden_type` (see `tests/test_first_eye.gd:12`). Deterministic: same man in → identical record out (no RNG).

**Files:**
- Create: `Godot/core/PeekChat.gd`
- Modify: `Godot/tests/test_peek_chat.gd` (append the contract tests)

- [ ] **Step 1: Write the failing contract test**

Append to `Godot/tests/test_peek_chat.gd`:

```gdscript
const PeekChat := preload("res://core/PeekChat.gd")

func test_peek_shape_and_surface() -> void:
	var r: Dictionary = PeekChat.peek(_man("evan"))
	ok(r.has("name") and r.has("surface_claim") and r.has("others_chat"), "peek shape {name,surface_claim,others_chat}")
	eq(r["name"], "Evan", "peek carries the name")
	eq(r["surface_claim"], "growth", "peek shows the surface he performs to her, for contrast")
	ok((r["others_chat"] as Array).size() >= 2, "peek carries the chats-with-others")

func test_peek_never_reveals_truth() -> void:
	for id in ["adrian", "evan", "leo"]:
		var r: Dictionary = PeekChat.peek(_man(id))
		ok(not r.has("hidden_type"), "peek never exposes the truth for %s (clue, not answer)" % id)
		ok(not r.has("risk"), "peek does not leak the engine risk label for %s" % id)

func test_peek_is_deterministic() -> void:
	var a: Dictionary = PeekChat.peek(_man("leo"))
	var b: Dictionary = PeekChat.peek(_man("leo"))
	eq(str(a), str(b), "peek is deterministic — same man, identical record")

func test_peek_handles_empty_man() -> void:
	var r: Dictionary = PeekChat.peek({})
	ok(r.has("others_chat"), "empty man still returns a well-formed record")
	eq((r["others_chat"] as Array).size(), 0, "empty man -> empty others_chat, no crash")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -5`
Expected: `RAN <N> tests, <≥1> failures` — fails to parse/resolve `PeekChat` (file does not exist) or the new tests fail.

- [ ] **Step 3: Implement `PeekChat`**

Create `Godot/core/PeekChat.gd`:

```gdscript
extends RefCounted
class_name PeekChat

# 派对前开天眼 · 看他跟别人的聊记。
# Returns ONLY what the player is allowed to see: who he is by name,
# the surface he performs to her (for the gut-punch contrast), and his
# chats with OTHER people. The truth (hidden_type) is deliberately NOT
# returned — the reveal is the player's to read. Deterministic, pure.
static func peek(man: Dictionary) -> Dictionary:
	var others: Array = man.get("others_chat", [])
	return {
		"name": str(man.get("name", "")),
		"surface_claim": str(man.get("surface", "")),
		"others_chat": others,
	}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `RAN <N> tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Godot/core/PeekChat.gd Godot/tests/test_peek_chat.gd
git commit -m "$(cat <<'EOF'
feat(hunting): PeekChat.peek — view his chats-with-others, truth stays hidden

Pure deterministic accessor: returns name + surface he performs + his
chats with others; never returns hidden_type (clue, not answer — same
discipline as FirstEye). Empty-man safe.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Headless demonstrator + full-suite green

A tiny headless artifact so the user can *feel* the hook without a UI (mirrors `play.gd`/`ui_smoke.gd`), and a final full-suite gate.

**Files:**
- Create: `Godot/peek_smoke.gd`

- [ ] **Step 1: Create the headless demonstrator**

Create `Godot/peek_smoke.gd`:

```gdscript
extends SceneTree
const Content := preload("res://core/Content.gd")
const PeekChat := preload("res://core/PeekChat.gd")

func _man(id: String) -> Dictionary:
	for m in Content.men():
		if m["id"] == id:
			return m
	return {}

func _show(id: String) -> void:
	var r: Dictionary = PeekChat.peek(_man(id))
	print("── 开天眼 · %s ──" % str(r["name"]))
	print("   他对你演的样子: %s" % str(r["surface_claim"]))
	print("   他跟别人怎么说:")
	for line in r["others_chat"]:
		print("     → (%s) %s" % [str(line["to"]), str(line["text"])])
	print("")

func _initialize() -> void:
	# evan: sweet to her, hollow to everyone (痛). leo: posturing to her, real offstage (爽).
	_show("evan")
	_show("leo")
	_show("adrian")
	print("PEEK SMOKE OK men=%d" % Content.men().size())
	quit(0)
```

- [ ] **Step 2: Run the demonstrator**

Run: `cd Godot && /opt/homebrew/bin/godot --headless --script res://peek_smoke.gd 2>&1 | tail -20`
Expected: prints the three men's peek blocks and a final line `PEEK SMOKE OK men=3`, exit 0. Visually confirm evan's chats-with-others read hollow/copy-paste while his surface is "growth", and leo's read real/quiet while his surface is "false_alpha" — the reveal lands.

- [ ] **Step 3: Full regression gate**

Run: `cd Godot && /opt/homebrew/bin/godot --headless --quit; echo "boot=$?"; /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -2`
Expected: `boot=0`; `RAN <N> tests, 0 failures` (N = original 59 + 7 new). No FAIL lines.

- [ ] **Step 4: Commit**

```bash
git add Godot/peek_smoke.gd
git commit -m "$(cat <<'EOF'
feat(hunting): peek_smoke — headless demonstrator of the 看聊记 hook

Prints evan/leo/adrian peek so the surface-vs-others contrast is
visible without a UI (mirrors play.gd/ui_smoke.gd). Not in TESTS.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review (plan author)

**Spec coverage:** §"派对前的开天眼：看他跟别人的聊记" → Task 1 corpus (his chats with OTHERS, not his performance to her) + Task 2 accessor. "人设其次，聊记才是最重要的" → `peek()` returns chats-with-others as the payload; profile/risk deliberately excluded. "它是线索不是答案" → Task 2 `test_peek_never_reveals_truth` enforces `hidden_type` never returned (matches FirstEye discipline). §"首要钩子" "为情感冲击而做、读出来心里咯噔一下" → Task 1 corpus is authored evocative (copy-paste sugar to multiple girls 1:14am vs. quiet real follow-ups), both directions (痛: evan; 爽: leo); Task 3 smoke makes the gut-punch observable. §"核心内容依赖 · 赛前聊记语料" → modeled as the `others_chat` field shape; this is the locked model, sample-sized (量产 deferred per spec). Deferred-by-spec (scarcity/cost, UI, live dialogue, H/S axes, "看十年后") → explicitly excluded in File Structure; no task touches them.

**Placeholder scan:** No TBD/TODO. Every code step contains complete, runnable GDScript including the actual corpus text and full test bodies. Expected command outputs given; test count written as `<N>`/“0 failures” deliberately (registering a new test legitimately changes the count — asserting "0 failures" is the stable contract, not a brittle hardcoded total).

**Type consistency:** `others_chat` is `Array` of `{to: String, text: String}` in Task 1 and consumed identically in Task 2/3. `PeekChat.peek()` returns `{name, surface_claim, others_chat}` in Task 2 and consumed with those exact keys in Task 3. `_man()` helper signature identical across the test and smoke. `man["id"]`/`man["surface"]`/`man["hidden_type"]` use bracket Variant access throughout (GDScript 4.6 correctness). `extends "res://tests/test_base.gd"` path-based matches every existing test; new test registered in `run_tests.gd` `TESTS` per the established pattern.

**Scope:** One cohesive backend vertical slice (content + accessor + demonstrator), 3 tasks, ~9 commits-worth of bite-sized steps. Produces working, testable software on its own; the UI reveal is the next slice (separate plan).
