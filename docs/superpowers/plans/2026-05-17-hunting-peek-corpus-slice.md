# 看聊记语料扩充 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the male corpus from 3 to 12 men (append 9, full locked schema, rich chat/others_chat) so the 看聊记 hook can be experienced repeatedly with real disguise variety.

**Architecture:** Pure additive content in `Godot/core/Content.gd` `men()` — append 9 new dict entries after `leo`, change nothing else in `men()` and no other Content function. Adjust the ONE hardcoded count assertion (`test_content.gd:5` `eq(men.size(),3)` → `>=`, intent preserved) and append integrity/spot-check assertions to `test_peek_chat.gd`. Peek UI / PeekChat / engine / hub all untouched and keep working (Peek lists `Content.men()` so new men appear automatically; engine picks men by id and `parties()` still references only the original 3).

**Tech Stack:** Godot 4.6 GDScript, pure data, headless harness `tests/run_tests.gd` (path-based `extends "res://tests/test_base.gd"`). `godot` = `/opt/homebrew/bin/godot`. Commit on `main`, do NOT push.

**Spec:** `docs/superpowers/specs/2026-05-17-hunting-peek-corpus-design.zh.md` (locked). Soul: cold-premium, anti-otome, specific, "心里咯噔一下". `hidden_type` stays the locked 3 (`resource`/`high_sugar`/`growth`).

---

## File Structure

- **Modify** `Godot/core/Content.gd` — append 9 men to the `men()` return array, immediately after the `leo` entry's closing `}` and before the array-closing `]`. No existing man/field/function changed.
- **Modify** `Godot/tests/test_content.gd:5` — `eq(men.size(), 3, "3 base men")` → `ge(men.size(), 12, "≥12 men")` (count-based assertion only; the archetype check on the next lines is unchanged, intent preserved).
- **Modify** `Godot/tests/test_peek_chat.gd` — APPEND 2 tests (existing tests/`_man()` byte-unchanged). Already registered in `run_tests.gd` (no run_tests change).

**Out of scope — do NOT touch:** `Godot/ui/Peek.gd`, `Godot/core/PeekChat.gd`, `Godot/ui/UiKit.gd`/`Theme.gd`/`Loc.gd`, `Godot/ui/Hub.gd`/`Faces.gd`, `Godot/core/*` (except Content.gd), `Godot/play.gd`, `Godot/ui_smoke.gd`, `Godot/peek_ui_smoke.gd`, `Godot/data/tuning.json`, `Godot/scenes/*`, `Godot/tests/run_tests.gd`. Do NOT rename/reorder adrian/evan/leo or change `parties()`. Do NOT add a 4th `hidden_type`.

---

### Task 1: Append 9 men + adjust tests (one cohesive content slice)

**Files:**
- Modify: `Godot/core/Content.gd` (append 9 men in `men()`)
- Modify: `Godot/tests/test_content.gd:5`
- Modify: `Godot/tests/test_peek_chat.gd` (append 2 tests)

- [ ] **Step 1: Adjust the hardcoded count assertion** in `Godot/tests/test_content.gd`. Change exactly line 5 from:

```gdscript
	eq(men.size(), 3, "3 base men")
```
to:
```gdscript
	ge(men.size(), 12, "≥12 men")
```
(Leave every other line of `test_content.gd` unchanged — `test_three_archetypes` still asserts all 3 archetypes present on the lines below; `ge` is the soft-assert helper in `tests/test_base.gd`.)

- [ ] **Step 2: Append the failing assertions** to the END of `Godot/tests/test_peek_chat.gd` (reuse the existing `_man()` and `const PeekChat`; do not alter existing tests):

```gdscript

func test_corpus_expanded_and_shaped() -> void:
	var men: Array = Content.men()
	ge(men.size(), 12, "≥12 men in the corpus")
	var disguised := 0
	for m in men:
		ok(m.has("chat") and (m["chat"] as Array).size() >= 2, "%s chat ≥2" % str(m["id"]))
		ok(m.has("others_chat") and (m["others_chat"] as Array).size() >= 4, "%s others_chat ≥4" % str(m["id"]))
		ok(m.has("hidden_type") and m["hidden_type"] in ["resource", "high_sugar", "growth"], "%s hidden_type is locked archetype" % str(m["id"]))
		ok(m.has("surface") and m.has("risk") and m.has("opportunity") and m.has("energy_cost"), "%s full schema" % str(m["id"]))
		if m["surface"] != m["hidden_type"]:
			disguised += 1
	ge(disguised, 5, "≥5 disguised men (surface != hidden_type)")

func test_new_reveal_cases_present() -> void:
	# Spot-check disguise-matrix coverage on 3 new ids (both directions).
	var marcus := _man("marcus")
	var daniel := _man("daniel")
	var julian := _man("julian")
	eq(marcus["hidden_type"], "high_sugar", "marcus truth = high_sugar")
	eq(marcus["surface"], "resource", "marcus performs resource (痛: hollow provider)")
	eq(daniel["hidden_type"], "resource", "daniel truth = resource")
	eq(daniel["surface"], "high_sugar", "daniel performs high_sugar (爽: dismissable but real)")
	eq(julian["hidden_type"], "high_sugar", "julian truth = high_sugar")
	eq(julian["surface"], "growth", "julian performs growth (痛: performative depth)")
	for id in ["marcus", "daniel", "julian"]:
		var r: Dictionary = PeekChat.peek(_man(id))
		ok(not r.has("hidden_type"), "%s peek still hides truth" % id)
```

- [ ] **Step 3: Run, verify it FAILS**

Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -6`
Expected: `RAN <N> tests, <≥1> failures` — only 3 men exist, so `ge(men.size(),12)` and the `_man("marcus")` spot-checks fail (`_man` returns `{}` → `marcus["hidden_type"]` errors / mismatches).

- [ ] **Step 4: Append the 9 men.** In `Godot/core/Content.gd`, find the `leo` entry inside `men()`. Its last line is:
```gdscript
				{"to": "his brother", "text": "Didn't get the round. It's fair. Going back in better, not louder."}]},
```
immediately followed by the array close `	]`. Insert the following 9 entries BETWEEN that `leo` closing `}]},` line and the `	]` (i.e., they become men #4..#12; do not modify adrian/evan/leo or the `]`):

```gdscript
		{"id": "marcus", "name": "Marcus", "hidden_type": "high_sugar",
			"surface": "resource", "energy_cost": 3,
			"risk": "All optics, nothing clears", "opportunity": "None — the bill never lands",
			"chat": [{"from": "him", "text": "Booked the chef's table Friday. Wear something I can show off."},
					 {"from": "you", "text": "Sure."},
					 {"from": "him", "text": "Car gets you at 8. I hate waiting."}],
			"others_chat": [
				{"to": "his assistant", "text": "Cancel the Friday table if she doesn't confirm by noon. Not chasing it."},
				{"to": "another girl, same week", "text": "chef's table Friday if you're free 😏 you'd love it"},
				{"to": "the group chat", "text": "lol I never pay full, comped every time, it's all optics"},
				{"to": "a contact, 3rd week running", "text": "yeah yeah I'll wire it next week, you know I'm good for it"},
				{"to": "his brother", "text": "she's fine for now. not serious. don't bring her up at mum's."}]},
		{"id": "daniel", "name": "Daniel", "hidden_type": "resource",
			"surface": "high_sugar", "energy_cost": 2,
			"risk": "Reads like a line, isn't", "opportunity": "Concrete and boundaried under the corny",
			"chat": [{"from": "him", "text": "good morning beautiful ☀️ thought about you"},
					 {"from": "you", "text": "morning."},
					 {"from": "him", "text": "can't help it. you're trouble 😅"}],
			"others_chat": [
				{"to": "a colleague", "text": "Revised contract sent 7am. Two changes flagged red. Call me once you've read it."},
				{"to": "his mother", "text": "Landed, cab home. I'll fix the boiler Saturday — don't call anyone."},
				{"to": "an ex", "text": "I'm not doing this at midnight. If it matters it'll matter at 10am."},
				{"to": "a friend", "text": "she's great. I'm slow on purpose. doing it properly this time."}]},
		{"id": "theo", "name": "Theo", "hidden_type": "growth",
			"surface": "high_sugar", "energy_cost": 1,
			"risk": "Deflects with jokes", "opportunity": "Quietly doing the work",
			"chat": [{"from": "him", "text": "you up? 🌝 had something smooth to say but i forgot it"},
					 {"from": "you", "text": "go to sleep, theo."},
					 {"from": "him", "text": "rude. iconic. night 😌"}],
			"others_chat": [
				{"to": "a notes app (shared by mistake)", "text": "pattern: I joke when it gets real. stay in it 3 more seconds."},
				{"to": "a mentor", "text": "took the note. shipped the boring version. you were right."},
				{"to": "his sister", "text": "didn't text her the funny thing. said the true thing instead. felt worse, then better."},
				{"to": "a friend", "text": "not drinking this month. not a bit. just clearer."}]},
		{"id": "julian", "name": "Julian", "hidden_type": "high_sugar",
			"surface": "growth", "energy_cost": 2,
			"risk": "Performs depth, recycles it", "opportunity": "None — the vulnerability is a script",
			"chat": [{"from": "him", "text": "I don't open up easily. but with you I feel safe to."},
					 {"from": "you", "text": "that's a lot."},
					 {"from": "him", "text": "you make me want to be a better man. genuinely."}],
			"others_chat": [
				{"to": "another girl, two days earlier", "text": "I don't open up easily. but with you I feel safe to."},
				{"to": "a third girl, last month", "text": "you make me want to be a better man. genuinely."},
				{"to": "the group chat", "text": "vulnerability is the cheat code, they eat it up"},
				{"to": "his ex, 2am from the club", "text": "I'm in such a healing era rn 🙏"},
				{"to": "a friend", "text": "nah I don't read the book, I just quote the back cover"}]},
		{"id": "wes", "name": "Wes", "hidden_type": "resource",
			"surface": "resource", "energy_cost": 3,
			"risk": "Cold, takes not asks", "opportunity": "Cold ≠ sugar — clears every time",
			"chat": [{"from": "him", "text": "Thursday 8. The place on Elm. I made it."},
					 {"from": "you", "text": "you could ask, not tell."},
					 {"from": "him", "text": "I did. that was the ask. Thursday 8."}],
			"others_chat": [
				{"to": "a contractor", "text": "Payment cleared. Don't ask twice. Do the work."},
				{"to": "his father", "text": "Handled. You don't need to worry about it. It's done."},
				{"to": "an ex", "text": "I won't do the long talk. What do you need, specifically."},
				{"to": "a friend", "text": "she thinks I'm cold. maybe. I show up though. every time."}]},
		{"id": "cole", "name": "Cole", "hidden_type": "high_sugar",
			"surface": "false_alpha", "energy_cost": 2,
			"risk": "Loud, owes everyone", "opportunity": "None — nothing behind the volume",
			"chat": [{"from": "him", "text": "I run the room wherever I go. Stick with me, you'll see."},
					 {"from": "you", "text": "see what?"},
					 {"from": "him", "text": "Everything. I'll show you a life. trust me."}],
			"others_chat": [
				{"to": "a creditor", "text": "bro I told you the money's coming, stop emailing me"},
				{"to": "another girl", "text": "I basically run that whole company 💪 come thru this weekend"},
				{"to": "the group chat", "text": "told her I 'run the room' lmaooo I just talk loud"},
				{"to": "his landlord, 4th Friday", "text": "I'll have rent Friday for sure this time"},
				{"to": "his brother", "text": "don't tell mum I left the job. it's fine. it's fine."}]},
		{"id": "sam", "name": "Sam", "hidden_type": "growth",
			"surface": "growth", "energy_cost": 1,
			"risk": "Slow, scared, honest about it", "opportunity": "Real — same on stage and off",
			"chat": [{"from": "him", "text": "liked what you said about quitting cleanly. been sitting with it."},
					 {"from": "you", "text": "and?"},
					 {"from": "him", "text": "booked the hard conversation for Monday. scared. doing it anyway."}],
			"others_chat": [
				{"to": "a mentor", "text": "did the Monday conversation. went badly and I'm okay. learned the thing."},
				{"to": "his sister", "text": "not going to over-explain it to her. just going to keep showing up."},
				{"to": "a friend", "text": "didn't text her drunk. went for a run instead. small win."},
				{"to": "a colleague", "text": "I was wrong in the meeting. said so. it was fine."}]},
		{"id": "hugo", "name": "Hugo", "hidden_type": "resource",
			"surface": "false_alpha", "energy_cost": 2,
			"risk": "Oversells loudly", "opportunity": "Delivers quietly under the noise",
			"chat": [{"from": "him", "text": "I don't do small. Penthouse, jet, the whole thing. You in?"},
					 {"from": "you", "text": "sounds exhausting."},
					 {"from": "him", "text": "ha. fair. it kind of is."}],
			"others_chat": [
				{"to": "a colleague", "text": "Oversold it at dinner, ignore the jet line. Numbers are real though — deck's solid, sending it."},
				{"to": "his mother", "text": "Paid the house off. Don't make it a thing. Happy birthday."},
				{"to": "an employee", "text": "Take the leave. I covered it. Don't tell the others, just go."},
				{"to": "a friend", "text": "I talk big around women, I know. it's armour. I do deliver though."}]},
		{"id": "rhys", "name": "Rhys", "hidden_type": "high_sugar",
			"surface": "high_sugar", "energy_cost": 1,
			"risk": "Shallow, and consistent about it", "opportunity": "None — consistent ≠ safe",
			"chat": [{"from": "him", "text": "not gonna lie I'm bad at texting back. fun in person tho 😉"},
					 {"from": "you", "text": "noted."},
					 {"from": "him", "text": "tonight? no plans, just vibes"}],
			"others_chat": [
				{"to": "another girl, same night", "text": "tonight? no plans, just vibes"},
				{"to": "the group chat", "text": "I'm honest about it at least lmao I tell them upfront"},
				{"to": "a friend", "text": "never met her family, never will, that's just not me"},
				{"to": "his brother", "text": "not looking for anything. she knows. think she knows. whatever."}]},
```

(Match the existing file's TAB indentation exactly — 2 tabs for the `{"id": ...` line, 3 tabs for continuation lines and the `"others_chat": [` block, 4 tabs for each `{"to": ...}` line, exactly like the `leo` entry above it. Each new entry ends with `]},` except keep the array's existing closing `	]` untouched after the last (`rhys`) entry.)

- [ ] **Step 5: Run, verify it PASSES**

Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: `RAN <N> tests, 0 failures` (N = prior 70 + 2 new in test_peek_chat = 72; `test_content.gd` count unchanged in number, just `ge` instead of `eq`). No FAIL lines.

- [ ] **Step 6: Confirm UI + engine unaffected**

Run: `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --script res://ui_smoke.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --script res://play.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --quit; echo "boot=$?"`
Expected: `PEEK UI SMOKE OK men=12` (the smoke prints the count — now 12; it does not assert a specific value); `HUB SMOKE OK day=2 dossier=3 reads=3` (hub picks men by id / party list — unaffected); play.gd ends with a `Season close.` line; `boot=0`. No `SCRIPT ERROR`.

- [ ] **Step 7: Commit** (from repo root, NOT Godot/):

```bash
cd /Users/kuma/Projects/Polaris && git add Godot/core/Content.gd Godot/tests/test_content.gd Godot/tests/test_peek_chat.gd && git commit -m "$(cat <<'EOF'
feat(hunting): expand 看聊记 corpus 3→12 men (disguise-matrix coverage)

9 new men, full locked schema, rich chat/others_chat. 痛: sugar masked
as resource/growth/false_alpha (marcus/julian/cole). 爽: substance masked
as sugar/false_alpha + cold-but-clears (daniel/theo/hugo/wes). Calibration
consistent men (sam real, rhys honestly shallow). hidden_type stays the
locked 3; peek() still never leaks truth. test_content count assertion
relaxed to >=; integrity + spot-check tests appended. UI/engine untouched.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```
Do NOT push.

## Self-Review (plan author)

**Spec coverage:** "3→12, append-only, no rename/reorder" → Step 4 inserts 9 after `leo`, adrian/evan/leo untouched. "Locked schema each man (id,name,hidden_type∈3,surface,energy_cost,risk,opportunity,chat 2-3,others_chat 4-6)" → every new entry has all 8 fields; chat = 3 lines, others_chat = 4–5 lines (≥4, within 4–6). "Disguise matrix, ≥5 disguised, both directions, multiple flavors" → disguised: marcus(sugar→resource), daniel(resource→sugar), theo(growth→sugar), julian(sugar→growth), cole(sugar→false_alpha), hugo(resource→false_alpha) = **6 disguised**, 痛 ×3 (marcus/julian/cole) + 爽 ×3 (daniel/theo/hugo) distinct flavors; consistent calibration: wes(resource cold), sam(growth real), rhys(high_sugar honestly shallow) + existing adrian. "Truth leaks via how he talks to OTHERS; chat sells surface" → each chat sells the surface, each others_chat exposes the truth (recycled identical lines julian/rhys; group-chat confessions marcus/julian/cole/rhys; offstage-delivers daniel/theo/hugo/wes). "Cold-premium/anti-otome/specific English matching adrian/evan/leo" → timestamps, "another girl", group-chat tells, terse-real, no otome chrome. "hidden_type stays 3 / peek never leaks" → Step 2 asserts both. "Suite green, >= not hardcoded, fix only count assertions, UI/engine unaffected" → Step 1 (eq→ge, intent preserved), Steps 5–6 gates.

**Placeholder scan:** No TBD/TODO. The full 9-man corpus is verbatim GDScript in Step 4; both test bodies and the exact `test_content.gd` line change are verbatim. Expected outputs given; counts as `≥`/"0 failures".

**Type consistency:** New men dicts use the exact field names/shapes of the existing `leo` entry (`chat` = `{from,text}`, `others_chat` = `{to,text}`). `test_peek_chat` reads `m["id"]/["chat"]/["others_chat"]/["hidden_type"]/["surface"]` (bracket Variant access, matches existing tests) and `_man()`/`const PeekChat` reused. `ge` is the real helper in `test_base.gd`. Spot-check ids (`marcus`/`daniel`/`julian`) exist in Step 4 with exactly the asserted hidden_type/surface. `PeekChat.peek` 4-key contract (no `hidden_type`) consistent with the still-passing earlier peek tests.

**Scope:** One cohesive content slice, one task, one commit. Produces a richer, immediately-experienceable hook (run `godot --path . res://scenes/Peek.tscn`); copy iteration by the user follows.
