# Hunting Plan D — Social Read-Practice Content (DM/comment samples + per-night cap)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`).

**Goal:** Turn the SOCIAL face's comment/DM read from a single fixed high_sugar sample into a real **high-frequency read-practice mini-loop** (hub-IA spec §4.2): a deterministic, varied sample set across the three archetypes plus a few **disguised** ones (surface tell points the wrong way — trains the carry-spec's "mispricing" judgment), each correct read archiving the dossier (judgment equity → net worth). Capped per night so dossier/net-worth cannot be farmed (mirrors the one-post-per-night discipline).

**Architecture:** Engine gets ONE additive content provider `Content.dm_signals()` (data, like `outfits()`/`workouts()` from Plan A; TDD; no other engine change — `read_signal` is already generic and stays untouched). The hub (UI) renders the current sample, cycles deterministically on each read, and enforces a per-night read cap UI-side (`ui["reads_tonight"]` counter reset in `_post_night`). `read_signal(hidden_type, guess)` is reused exactly as-is.

**Design decisions (locked unless user vetoes):**
- **Per-night read cap = `social.read_cap` (default 3)** in `tuning.json`. Dossier is a net-worth asset; uncapped reads = unbounded net-worth farm. Cap is UI-enforced (engine `read_signal` stays pure/generic). After the cap, the read block shows a "no more reads tonight" note (visible, like the build-lock / one-post patterns); resets each night via the existing `_post_night` per-night-reset block.
- **Deterministic cycling, no RNG** (engine determinism principle): the shown sample index = `flow.state.dossier.size()` modulo the sample count (or a UI read counter) — stable, reproducible, testable.
- **Sample set**: ≥6 samples — at least 2 per archetype (`resource`/`high_sugar`/`growth`) where the text tell matches the type, PLUS ≥2 **disguised** where `surface` (the visible vibe) ≠ `hidden_type` (the right answer) so the player must read past the obvious. Guess buttons = the 3 archetype ids (localized via existing Loc keys `高糖型/资源型/成长型`). Correct guess = the sample's `hidden_type`.

**Tech Stack:** Godot 4.6 GDScript, JSON tuning, headless tests, code-gen UI, Loc zh. **Source:** hub-IA spec §4.2; carry-spec (dossier=judgment equity, mispricing skill); reuses Plan-A `read_signal`. Engine on `main` HEAD `85e468c`.

**Project-wide constraints:** new commit only; Task 1 = engine (Content + tuning) ADDITIONS-ONLY + TDD; Tasks 2–3 = UI-ONLY (zero `core/`/`tests/`/`play.gd`/`project.godot` change, verified by diff); `Loc.gd` append-only (no existing-key change, no duplicate — boot parse-error is the check); 56→58 tests stay green (Task 1 adds tests, never weakens existing); established Godot-4.6 fixes (typed locals for Variant `Tuning.num`; bracket Variant dict access; per-iteration lambda-capture; `match` via preloaded const).

---

### Task 1: Engine content — `Content.dm_signals()` + tuning `social.read_cap`

**Files:** Modify `Godot/core/Content.gd` (append 1 static func), `Godot/data/tuning.json` (add 1 key to existing `social` block), `Godot/tests/run_tests.gd` (append test path); Create `Godot/tests/test_dm_signals.gd`.

- [ ] **Step 1: Failing test** — `Godot/tests/test_dm_signals.gd`:
```gdscript
extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")
const Tuning := preload("res://core/Tuning.gd")
func test_dm_signals_shape_and_size() -> void:
	var xs = Content.dm_signals()
	ok(xs.size() >= 6, "≥6 dm samples")
	for x in xs:
		ok(x.has("text") and x.has("hidden_type") and x.has("surface"), "sample shape {text,hidden_type,surface}")
		ok(x["hidden_type"] in ["resource", "high_sugar", "growth"], "hidden_type is a known archetype")
func test_has_each_archetype_and_disguised() -> void:
	var xs = Content.dm_signals()
	var types := {}
	var disguised := 0
	for x in xs:
		types[x["hidden_type"]] = true
		if x["surface"] != x["hidden_type"]:
			disguised += 1
	ok(types.has("resource") and types.has("high_sugar") and types.has("growth"), "all 3 archetypes present")
	ok(disguised >= 2, "≥2 disguised (surface != hidden_type)")
func test_read_cap_tuning() -> void:
	Tuning.load_data()
	eq(Tuning.num("social.read_cap"), 3, "read_cap default 3")
```
- [ ] **Step 2:** Append `"res://tests/test_dm_signals.gd"` to the `TESTS` array in `run_tests.gd` (keep all existing entries).
- [ ] **Step 3:** Run `cd Godot && godot --headless --script res://tests/run_tests.gd` → confirm NEW failures only (missing `Content.dm_signals`, missing `social.read_cap`); prior 56 still listed.
- [ ] **Step 4: Implement.** Append to `Godot/core/Content.gd` (do NOT touch existing funcs):
```gdscript
static func dm_signals() -> Array:
	return [
		{"text": "still up? can't stop thinking about you 😉", "hidden_type": "high_sugar", "surface": "high_sugar"},
		{"text": "you're different. you actually listen.", "hidden_type": "high_sugar", "surface": "growth"},
		{"text": "dinner Thursday 8 — I booked the corner table.", "hidden_type": "resource", "surface": "resource"},
		{"text": "flying back Sunday, let's lock a real date this week.", "hidden_type": "resource", "surface": "resource"},
		{"text": "loud party guy energy, but asked what you're building.", "hidden_type": "growth", "surface": "false_alpha"},
		{"text": "quiet, kept following up on what you said last time.", "hidden_type": "growth", "surface": "growth"},
		{"text": "VIP table, bottles, 'come thru' — no plan, no time.", "hidden_type": "high_sugar", "surface": "resource"},
		{"text": "humble, almost shy — runs two clinics, never led with it.", "hidden_type": "resource", "surface": "growth"},
	]
```
And in `Godot/data/tuning.json`, add `"read_cap": 3` INTO the existing `"social": {...}` object (alongside its existing keys; do NOT alter any existing key or any other block; keep valid JSON).
- [ ] **Step 5:** Run `cd Godot && godot --headless --script res://tests/run_tests.gd` → `0 failures`, exit 0 (≈`RAN 59 tests`). `godot --headless --quit` exit 0. `godot --headless --script res://play.gd` exit 0 (batch unaffected). `godot --headless --script res://ui_smoke.gd` → `HUB SMOKE OK day=2 dossier=1` exit 0 (read_signal still generic; SOCIAL not yet using dm_signals — fine). TDD: fix real Godot-4.6/JSON causes only; never weaken assertions; never touch existing content/tuning keys.
- [ ] **Step 6: Commit**
```bash
git add Godot/core/Content.gd Godot/data/tuning.json Godot/tests/test_dm_signals.gd Godot/tests/run_tests.gd
git commit -m "feat(hunting-be): dm_signals content + social.read_cap (read-practice)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: SOCIAL face — varied read loop + per-night cap (UI-only)

**Files:** Modify `Godot/ui/Hub.gd`, `Godot/ui/Faces.gd`, `Godot/ui/Loc.gd` (append).

- [ ] **Step 1: Hub** — modify `act_read_signal` and extend `_post_night`. Replace the existing `act_read_signal` body so it (a) respects the cap, (b) advances the sample cursor. Append/replace in `Godot/ui/Hub.gd`:
```gdscript
func _read_cap() -> int:
	return int(flow.Tuning.num("social.read_cap", 3)) if false else int(_tuning_read_cap())
func _tuning_read_cap() -> int:
	var Tuning = load("res://core/Tuning.gd")
	return int(Tuning.num("social.read_cap", 3))
func act_read_signal(hidden_type: String, guess: String) -> void:
	var done: int = int(ui.get("reads_tonight", 0))
	if done >= _tuning_read_cap():
		return
	var r = flow.read_signal(hidden_type, guess)
	ui["reads_tonight"] = done + 1
	ui["read_feedback"] = "correct" if r.correct else "wrong"
	_render()
```
(Keep it simple: use the `_tuning_read_cap()` helper that `load()`s Tuning; do NOT add a new preload const if Hub.gd has none — match the file's existing style; if Hub already preloads SeasonFlow which preloads Tuning, prefer reading the cap via a tiny `load("res://core/Tuning.gd")` helper as above. If the file already has a cleaner accessor pattern, use that instead — keep semantics: cap from `social.read_cap` default 3.) Then in `_post_night()`, in the SAME existing erase-block that already does `ui.erase("post_result")`/`ui.erase("read_feedback")`/etc., ADD `ui.erase("reads_tonight")` (so the cap resets each night). Do not alter the existing erases.

- [ ] **Step 2: Faces SOCIAL read block** — in `Godot/ui/Faces.gd` `Hub.F.SOCIAL:` arm, replace the fixed-DM portion (currently a single hardcoded `"A DM: \"hey gorgeous...\""` line + 3 guess buttons) with a cycled sample + cap-aware UI:
```gdscript
			y += 20
			UiKit.label(r, "READ THE COMMENTS", T.PAD, y, T.SMALL, T.DIM); y += 56
			if h.ui.has("read_feedback"):
				var fb: String = h.ui["read_feedback"]
				UiKit.label(r, "Filed — you read him right." if fb == "correct" else "Off. Look again.", T.PAD, y, T.SMALL, (T.ACCENT if fb == "correct" else T.DIM), W)
				y += 80
			var samples := Content.dm_signals()
			var cap: int = h._tuning_read_cap()
			var done: int = int(h.ui.get("reads_tonight", 0))
			if done >= cap:
				UiKit.label(r, "That's enough reading for tonight.", T.PAD, y, T.SMALL, T.DIM, W)
			elif samples.size() > 0:
				var idx: int = int(h.flow.state.dossier.size()) % samples.size()
				var sample = samples[idx]
				var truth: String = sample["hidden_type"]
				UiKit.label(r, "DM: \"%s\"" % str(sample["text"]), T.PAD, y, T.SMALL, T.TEXT, W); y += 90
				UiKit.label(r, "reads tonight %d / %d" % [done, cap], T.PAD, y, T.SMALL, T.DIM); y += 50
				for g in ["high_sugar", "resource", "growth"]:
					var gg: String = g
					UiKit.btn(r, gg, T.PAD, y, W, 100, func(): h.act_read_signal(truth, gg))
					y += 116
```
(Replace ONLY the old read-the-comments fixed-DM block; keep the title/subtitle/post sections of the SOCIAL arm intact. `truth` is captured per-render from the current sample so the lambda passes the correct hidden_type as the answer and `gg` as the guess. `Content` is already preloaded in Faces.gd. Reuse the `W` local. `"%s"`/`"%d"` lines stay literal per the established rule; the DM `text` itself is content (English copy now — a localized DM corpus is a separate later increment, note it). The fixed UI words go through Loc.)

- [ ] **Step 3: Loc append** — append (absent keys only; no dup; no existing-key change): `"That's enough reading for tonight."→"今晚读够了。"`. (`"READ THE COMMENTS"`, `"Filed — you read him right."`, `"Off. Look again."`, `"high_sugar"`, `"resource"`, `"growth"` already exist from Plan C Task 1 — reuse, do NOT re-add. The `"reads tonight %d / %d"` and `DM: "%s"` lines have format args — leave literal, not Loc keys.)

- [ ] **Step 4: Verify** — `cd Godot && godot --headless --quit` exit 0 NO parse error (no dup Loc key). `... res://tests/run_tests.gd` → `RAN 59 tests, 0 failures` exit 0. `... res://play.gd` exit 0 coherent. `... res://ui_smoke.gd` → still `HUB SMOKE OK day=2 dossier=1` exit 0 (the smoke does 1 read; cap 3 ≥ 1, unaffected). `git diff --stat 85e468c..HEAD -- Godot/core Godot/tests Godot/play.gd Godot/project.godot Godot/scenes Godot/ui/Theme.gd Godot/ui/UiKit.gd Godot/ui_smoke.gd` → EMPTY (Task 1's engine changes are below `85e468c`-relative? NOTE: Task 2 baseline is Task-1's commit; use `git diff <task1-sha>..HEAD` for the UI-only guard). `git diff <task1-sha>..HEAD -- Godot/ui/Loc.gd | grep -E '^-[^-]' | wc -l` → 0.

- [ ] **Step 5: Commit**
```bash
git add Godot/ui/Hub.gd Godot/ui/Faces.gd Godot/ui/Loc.gd
git commit -m "feat(hunting-ui): varied DM read loop + per-night read cap

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Smoke (multi-read + cap) + verify + README + push-ready

**Files:** Modify `Godot/ui_smoke.gd`, `Godot/README.md`.

- [ ] **Step 1: Extend `ui_smoke.gd`** — before the post/party drive, in the SOCIAL face do MULTIPLE reads to exercise variety + the cap: replace the single `h.act_read_signal("high_sugar","high_sugar")` with a loop that reads `cap + 1` times against the *current sample's* truth (drive via the hub: read the current displayed sample's `hidden_type` by indexing `Content.dm_signals()` the same way Faces does — `idx = flow.state.dossier.size() % samples.size()` — guess correctly each allowed read), asserting: dossier grows by exactly `cap` (not `cap+1` — the over-cap read is a no-op), and `ui["reads_tonight"]` never exceeds `cap`. Keep the rest of the full-night drive (post → party → date → settle) and the existing `day>=2` assert. Print `HUB SMOKE OK day=%d dossier=%d reads=%d`. Drive only via Hub methods (`act_read_signal`), reading Content/state for assert math only.
- [ ] **Step 2: Run** — `cd Godot && godot --headless --script res://ui_smoke.gd` → prints `HUB SMOKE OK day=2 dossier=3 reads=3` (cap=3; over-cap read no-op), exit 0. Fix real cause if it errors; do NOT weaken asserts (esp. "dossier grew by exactly cap, the cap+1 read was a no-op").
- [ ] **Step 3: Gates + guards** — `... run_tests.gd` `RAN 59 tests, 0 failures` exit 0; `godot --headless --quit` exit 0; `... play.gd` exit 0. `git diff --stat <task2-sha>..HEAD -- Godot/core Godot/tests Godot/play.gd Godot/project.godot Godot/scenes Godot/ui` → EMPTY (Task 3 only touches ui_smoke.gd + README).
- [ ] **Step 4: README** — append: comment/DM read is now a varied deterministic sample set (incl. disguised tells), capped at `social.read_cap` (default 3) reads/night; correct reads archive the dossier (judgment equity).
- [ ] **Step 5: Commit**
```bash
git add Godot/ui_smoke.gd Godot/README.md
git commit -m "test(hunting-ui): multi-read + cap smoke; docs

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (plan author)

**Spec coverage (hub-IA §4.2 high-frequency read; carry-spec dossier=judgment equity + mispricing):** varied deterministic DM corpus incl. disguised (surface≠hidden) — Task 1; SOCIAL face cycles samples + per-night cap (anti-farm, mirrors one-post discipline) feeding `read_signal`→dossier — Task 2; multi-read+cap smoke proving cap is enforced (dossier grows by exactly cap) — Task 3. Engine `read_signal` reused untouched; only additive `dm_signals()` + 1 tuning key.

**Placeholder scan:** no TBD; complete code/commands each step; numbers in tuning; DM English copy is content (localized DM corpus explicitly noted as a separate later increment, not a gap in this plan's scope).

**Type consistency:** `Content.dm_signals()`→`[{text,hidden_type,surface}]`; `_tuning_read_cap()` int; `ui["reads_tonight"]` counter reset in the existing `_post_night` block; per-iteration `gg` capture + `truth` captured per-render; bracket Variant access. `read_signal(hidden_type,guess)` signature unchanged.

**Engine vs UI split:** Task 1 additive-engine+TDD (existing 56 tests untouched, +3 new); Tasks 2–3 UI-only (diff-verified). Loc append-only.

**Scope:** small bounded content increment on the existing built+spec'd read surface; not new product design. One coherent plan.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-05-17-hunting-plan-d-read-content.md`. Subagent-driven: Task 1 (engine content, TDD) spec+quality review; Tasks 2–3 UI lighter combined. Proceed with Task 1 unless the user vetoes the read-cap default (3) or sample direction.
