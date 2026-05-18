# 看聊记语料扩充 12→36 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Append 24 new men (12→36) to `Content.men()` so the casual 鉴渣 game has far more variety before it repeats.

**Architecture:** Pure additive content in `Godot/core/Content.gd` `men()` — append two batches of 12 after the last existing man (`rhys`), changing nothing else. Existing per-man `>=`-based tests (`test_peek_chat.gd`, `test_content.gd`, `test_spotter.gd`) generalise to 36 automatically and stay green at 24 and 36. A final task appends one size-lock assertion. Peek/Spotter/PeekChat/UiKit are untouched (Peek lists `Content.men()` so new men auto-enter the game; `_sharp_line` shows `others_chat[0]`, so every new man's `others_chat[0]` is authored as his sharpest tell).

**Tech Stack:** Godot 4.6 GDScript, pure data, headless harness `tests/run_tests.gd`. `godot` = `/opt/homebrew/bin/godot`. Commit on `main`, do NOT push.

**Spec:** `docs/superpowers/specs/2026-05-17-hunting-peek-corpus-design.zh.md` + `docs/superpowers/specs/2026-05-18-hunting-casual-spotter-design.zh.md` (locked). `hidden_type` strictly ∈ {`resource`,`high_sugar`,`growth`}. Spotter: `high_sugar`=渣, `resource`/`growth`=好. Soul: cold-premium, anti-otome, specific, "心里咯噔一下".

---

## File Structure

- **Modify** `Godot/core/Content.gd` — append 24 men to the `men()` array in two batches (Task 1: 12, Task 2: 12), after the last existing entry (`rhys`), before the array-closing `	]`. No existing man/field/function changed; `parties()` etc. untouched.
- **Modify** `Godot/tests/test_peek_chat.gd` — Task 3 APPENDS one test (`test_corpus_size_locked`); existing tests byte-unchanged. Already registered in `run_tests.gd` (no run_tests change).
- **Untouched:** `Peek.gd`, `Spotter.gd`, `PeekChat.gd`, `UiKit.gd`, `Theme.gd`, `Loc.gd`, `run_tests.gd`, `Hub.gd`, `Faces.gd`, `play.gd`, `ui_smoke.gd`, `peek_ui_smoke.gd`, `tuning.json`, `scenes/*`.

**Out of scope:** any non-content change, any 4th `hidden_type`, renaming/reordering existing men, the shelved complex systems.

**Insertion anchor (both batches):** in `Godot/core/Content.gd` `men()`, the LAST man entry is `rhys`; its final line is
`				{"to": "his brother", "text": "not looking for anything. she knows. think she knows. whatever."}]},`
immediately followed by the array close `	]`. Task 1 inserts its 12 entries between that `rhys` `}]},` line and `	]`. Task 2 inserts its 12 between the last Task-1 entry (`dane`) `}]},` and `	]`. Match the existing TAB indentation exactly (2 tabs at `{"id":`, 3 tabs at continuation lines and `"others_chat": [`, 4 tabs at each `{"to": ...}` line). Every entry ends `]},`; never touch the final `	]`.

---

### Task 1: Append men #13–24 (batch A: owen…dane)

**Files:** Modify `Godot/core/Content.gd`.

- [ ] **Step 1: Run baseline.** `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -1` — expect `RAN 76 tests, 0 failures` (baseline; no test change in this task).

- [ ] **Step 2: Insert batch A.** Insert these 12 entries at the anchor (between `rhys` `}]},` and `	]`):

```gdscript
		{"id": "owen", "name": "Owen", "hidden_type": "high_sugar",
			"surface": "resource", "energy_cost": 3,
			"risk": "Access he can't actually grant", "opportunity": "None — the intro never lands",
			"chat": [{"from": "him", "text": "I'll get you in the room with my guy at the fund. I look after people I like."},
					 {"from": "you", "text": "okay."},
					 {"from": "him", "text": "trust me, I've got you. just say yes."}],
			"others_chat": [
				{"to": "the friend who'd intro him", "text": "haven't talked to that fund guy in two years lol, just say it so I sound like I move"},
				{"to": "another girl, same line", "text": "I'll get you in the room with my guy. I look after people I like."},
				{"to": "a friend he owes", "text": "I'll sort you out next month bro, you know me"},
				{"to": "the group chat", "text": "promise them access, they never check, works every time"}]},
		{"id": "felix", "name": "Felix", "hidden_type": "high_sugar",
			"surface": "growth", "energy_cost": 2,
			"risk": "Fast-tracked false intimacy", "opportunity": "None — the wound is a script",
			"chat": [{"from": "him", "text": "I don't tell people this. my dad left when I was nine. but you feel safe."},
					 {"from": "you", "text": "that's heavy."},
					 {"from": "him", "text": "you get me on a level no one has."}],
			"others_chat": [
				{"to": "another girl, last week, verbatim", "text": "I don't tell people this. my dad left when I was nine. but you feel safe."},
				{"to": "a third girl", "text": "you get me on a level no one ever has"},
				{"to": "the group chat", "text": "open with the dad thing, instant closeness, never misses"},
				{"to": "his actual friend", "text": "my dad? he's fine, we golfed sunday"}]},
		{"id": "dominic", "name": "Dominic", "hidden_type": "high_sugar",
			"surface": "false_alpha", "energy_cost": 2,
			"risk": "Name-drops, delivers nothing", "opportunity": "None — the doors don't open",
			"chat": [{"from": "him", "text": "I know everyone worth knowing in this city. stick close."},
					 {"from": "you", "text": "like who?"},
					 {"from": "him", "text": "you'll see. doors just open for me."}],
			"others_chat": [
				{"to": "a contact he barely knows", "text": "hey long shot — can you intro me to your boss? we've never actually met but"},
				{"to": "another girl", "text": "I know everyone worth knowing here, stick close"},
				{"to": "his landlord", "text": "rent's coming, had a cash flow thing this month"},
				{"to": "the group chat", "text": "name-drop hard enough and nobody ever checks"}]},
		{"id": "gabe", "name": "Gabe", "hidden_type": "high_sugar",
			"surface": "high_sugar", "energy_cost": 1,
			"risk": "Upfront, still a rotation", "opportunity": "None — honest ≠ safe",
			"chat": [{"from": "him", "text": "not gonna pretend I'm deep. you're hot, I'm fun, let's not overthink 😄"},
					 {"from": "you", "text": "at least you're upfront."},
					 {"from": "him", "text": "tonight?"}],
			"others_chat": [
				{"to": "another girl, same night", "text": "tonight? you're hot, I'm fun, let's not overthink 😄"},
				{"to": "the group chat", "text": "same text to all of them, some say yes, it's just math"},
				{"to": "a friend", "text": "three on rotation rn, none know, keeping it light"},
				{"to": "his brother", "text": "nah never meeting her people, that's not the deal"}]},
		{"id": "ezra", "name": "Ezra", "hidden_type": "high_sugar",
			"surface": "growth", "energy_cost": 2,
			"risk": "Therapy-speak as a shield", "opportunity": "None — 'the work' is the dodge",
			"chat": [{"from": "him", "text": "I'm doing a lot of work on myself. holding space for us feels right."},
					 {"from": "you", "text": "what does that mean"},
					 {"from": "him", "text": "it means I'm present. that's rare."}],
			"others_chat": [
				{"to": "an ex he ghosted", "text": "I can't engage with that energy, it's not aligned for me rn 🙏"},
				{"to": "another girl", "text": "holding space for us feels right"},
				{"to": "the group chat", "text": "say 'doing the work' and they literally can't be mad at you"},
				{"to": "a friend", "text": "therapy? went once. great vocabulary though"}]},
		{"id": "caleb", "name": "Caleb", "hidden_type": "resource",
			"surface": "high_sugar", "energy_cost": 2,
			"risk": "Reads corny, isn't hollow", "opportunity": "Quietly handles the hard things",
			"chat": [{"from": "him", "text": "morning sunshine ☀️ dork misses you"},
					 {"from": "you", "text": "you're so corny"},
					 {"from": "him", "text": "devastatingly. dinner thursday, already booked it."}],
			"others_chat": [
				{"to": "his sister, 6am", "text": "I've got the deposit. don't argue. it's handled — go sign the lease today."},
				{"to": "a colleague", "text": "sent the fixed file 7am, two flags in red, call when you've read it"},
				{"to": "a friend", "text": "she thinks I'm a goofball. fine being underestimated. she's worth doing right."},
				{"to": "his mother", "text": "landing tonight, I'll take you to the appointment friday"}]},
		{"id": "nico", "name": "Nico", "hidden_type": "growth",
			"surface": "high_sugar", "energy_cost": 1,
			"risk": "Flirts to deflect", "opportunity": "Privately doing the real work",
			"chat": [{"from": "him", "text": "you're trouble and I'm into it 😏"},
					 {"from": "you", "text": "go to bed"},
					 {"from": "him", "text": "bossy. fine. night, trouble."}],
			"others_chat": [
				{"to": "his sponsor", "text": "90 days today. wanted to text her something dumb. texted you instead. that's the win."},
				{"to": "a friend", "text": "keeping it light with her till I'm steadier. not fair otherwise."},
				{"to": "his sister", "text": "didn't go saturday. stayed in. boring is good right now."},
				{"to": "a mentor", "text": "took the smaller role. less money, less noise. correct call."}]},
		{"id": "reid", "name": "Reid", "hidden_type": "resource",
			"surface": "false_alpha", "energy_cost": 2,
			"risk": "Loud at the gym", "opportunity": "Keeps his word where it counts",
			"chat": [{"from": "him", "text": "I out-lift everyone at that gym, just facts 💪 you should come watch"},
					 {"from": "you", "text": "hard pass"},
					 {"from": "him", "text": "ha. respect."}],
			"others_chat": [
				{"to": "his sister", "text": "tuition cleared for the term. stop checking, it's done. focus on exams."},
				{"to": "a friend", "text": "the gym talk is a bit. what I say where it matters, I keep."},
				{"to": "a contractor", "text": "paid in full this morning. do it right, not fast."},
				{"to": "his dad", "text": "I've got the medical bill. you don't get to worry about that part."}]},
		{"id": "mateo", "name": "Mateo", "hidden_type": "growth",
			"surface": "false_alpha", "energy_cost": 2,
			"risk": "Cocky front", "opportunity": "Owns it, actually changing",
			"chat": [{"from": "him", "text": "I'm kind of a big deal in my field, not bragging just true"},
					 {"from": "you", "text": "definitely bragging"},
					 {"from": "him", "text": "...yeah okay. it was bragging."}],
			"others_chat": [
				{"to": "a mentor", "text": "I botched the pitch making it about me. owning it. redoing it their way."},
				{"to": "his brother", "text": "apologized to the junior I talked over. should've done it sooner."},
				{"to": "a friend", "text": "the cocky thing is a shield. working on dropping it for real."},
				{"to": "a colleague", "text": "your idea was better. said so in the room. credit's yours."}]},
		{"id": "jonah", "name": "Jonah", "hidden_type": "resource",
			"surface": "high_sugar", "energy_cost": 3,
			"risk": "Lays it on thick", "opportunity": "Also actually shows up",
			"chat": [{"from": "him", "text": "can't stop thinking about you, it's a problem 😅"},
					 {"from": "you", "text": "smooth."},
					 {"from": "him", "text": "only true things. friday's locked, I handled it."}],
			"others_chat": [
				{"to": "his assistant", "text": "move my friday so it's actually free. if I say I'll be there, I'm there."},
				{"to": "an ex", "text": "I'm not doing midnight talks. daytime, a call, or not at all."},
				{"to": "a friend", "text": "yeah I lay it on thick with her. I also show up. both true."},
				{"to": "his mother", "text": "flights booked, aisle seat, I'll drive you from the airport"}]},
		{"id": "beck", "name": "Beck", "hidden_type": "growth",
			"surface": "false_alpha", "energy_cost": 1,
			"risk": "Ego talks first", "opportunity": "Shows up when it's real",
			"chat": [{"from": "him", "text": "I don't really chase. people come to me."},
					 {"from": "you", "text": "okay, ego."},
					 {"from": "him", "text": "fair. that came out worse than I meant."}],
			"others_chat": [
				{"to": "a friend at 2am", "text": "on my way. don't move. 10 minutes out, stay on the phone."},
				{"to": "his sister", "text": "I'll take the early shift with mum so you sleep. just go."},
				{"to": "a mentor", "text": "said the arrogant thing again. catching it faster. still catching it late."},
				{"to": "a colleague", "text": "my call was wrong. yours was right. we ship yours."}]},
		{"id": "dane", "name": "Dane", "hidden_type": "resource",
			"surface": "resource", "energy_cost": 3,
			"risk": "Blunt, not warm", "opportunity": "Says it, then does exactly it",
			"chat": [{"from": "him", "text": "Saturday. 7. I made a reservation. I'd like to take you."},
					 {"from": "you", "text": "direct."},
					 {"from": "him", "text": "I'd rather be clear than cute."}],
			"others_chat": [
				{"to": "his daughter", "text": "recital's in my calendar in ink. nothing moves it. front row."},
				{"to": "a colleague", "text": "numbers by friday. you'll have them friday. you always do."},
				{"to": "his ex", "text": "co-parenting only. respectful, on time, nothing extra. that's the lane."},
				{"to": "a friend", "text": "I like her. being deliberate. she deserves deliberate."}]},
```

- [ ] **Step 3: Run, verify GREEN.** `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -2` — expect `RAN 76 tests, 0 failures` (count unchanged — no new test; per-man `>=` integrity tests now iterate 24 men and still pass). Then `/opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -1` — expect `SPOT SMOKE OK men=24`.

- [ ] **Step 4: Commit** (repo root):
```bash
cd /Users/kuma/Projects/Polaris && git add Godot/core/Content.gd && git commit -m "$(cat <<'EOF'
feat(hunting): corpus batch A — +12 men (12→24)

owen/felix/dominic/gabe/ezra (痛: sugar masked as resource/growth/
false_alpha + consistent fuckboy), caleb/nico/reid/mateo/jonah/beck
(爽: substance masked as sugar/false_alpha), dane (consistent 好).
Full locked schema; others_chat[0] = sharpest tell. Append-only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Append men #25–36 (batch B: soren…arlo)

**Files:** Modify `Godot/core/Content.gd`.

- [ ] **Step 1: Insert batch B.** Insert these 12 entries between the last Task-1 entry (`dane` … `}]},`) and the array-closing `	]`:

```gdscript
		{"id": "soren", "name": "Soren", "hidden_type": "growth",
			"surface": "growth", "energy_cost": 1,
			"risk": "Slow, scared, says so", "opportunity": "Real — same on and off stage",
			"chat": [{"from": "him", "text": "been sitting with that thing you said about settling. it landed."},
					 {"from": "you", "text": "and?"},
					 {"from": "him", "text": "booked the scary conversation for monday. doing it."}],
			"others_chat": [
				{"to": "a mentor", "text": "had the monday talk. went badly. I'm okay. learned the actual thing."},
				{"to": "his brother", "text": "not over-explaining myself to her. just going to keep showing up steady."},
				{"to": "a friend", "text": "didn't drink at the thing. wasn't even hard this time."},
				{"to": "a colleague", "text": "I was wrong in the review. said so first. it was fine."}]},
		{"id": "tariq", "name": "Tariq", "hidden_type": "resource",
			"surface": "resource", "energy_cost": 2,
			"risk": "Unromantic", "opportunity": "Nothing promised ever doesn't happen",
			"chat": [{"from": "him", "text": "Thursday works. I'll send the place and time by noon."},
					 {"from": "you", "text": "efficient."},
					 {"from": "him", "text": "your time matters. so does mine. noon."}],
			"others_chat": [
				{"to": "a client", "text": "scope's fixed, price won't move, delivery is the 14th. it'll be the 14th."},
				{"to": "his father", "text": "the care home's paid through the year. don't bring it up again, it's handled."},
				{"to": "an ex", "text": "I won't relitigate it. what do you concretely need. I'll answer that."},
				{"to": "a friend", "text": "she calls me unromantic. maybe. nothing I promise her doesn't happen."}]},
		{"id": "idris", "name": "Idris", "hidden_type": "high_sugar",
			"surface": "high_sugar", "energy_cost": 1,
			"risk": "Honest about being a mess", "opportunity": "None — consistent ≠ safe",
			"chat": [{"from": "him", "text": "you're stunning and I'm shameless about it 😘"},
					 {"from": "you", "text": "noticed."},
					 {"from": "him", "text": "come out, no agenda, just me being delightful"}],
			"others_chat": [
				{"to": "two other girls, same text", "text": "come out, no agenda, just me being delightful"},
				{"to": "the group chat", "text": "I'm honest that I'm a mess, somehow that works lol"},
				{"to": "a friend", "text": "never meeting anyone's parents ever, that's the whole brand"},
				{"to": "his brother", "text": "not serious about any of them. they know. mostly."}]},
		{"id": "pierce", "name": "Pierce", "hidden_type": "high_sugar",
			"surface": "resource", "energy_cost": 3,
			"risk": "Optics on credit", "opportunity": "None — the card's a prop",
			"chat": [{"from": "him", "text": "private table, my card, you don't think about anything tonight."},
					 {"from": "you", "text": "generous."},
					 {"from": "him", "text": "only the best. you're the best."}],
			"others_chat": [
				{"to": "the restaurant", "text": "comp it and I'll 'tip big' on camera, you know the arrangement"},
				{"to": "a creditor", "text": "transfer's pending, bank thing, end of week for sure"},
				{"to": "another girl", "text": "private table, my card, you don't think about anything 🥂"},
				{"to": "his brother", "text": "don't say anything about the card situation around her"}]},
		{"id": "knox", "name": "Knox", "hidden_type": "high_sugar",
			"surface": "growth", "energy_cost": 2,
			"risk": "Borrowed depth", "opportunity": "None — the lines are recycled",
			"chat": [{"from": "him", "text": "stillness with you feels like growth. I don't say that lightly."},
					 {"from": "you", "text": "that's poetic"},
					 {"from": "him", "text": "you bring it out of me. genuinely."}],
			"others_chat": [
				{"to": "another girl, verbatim", "text": "stillness with you feels like growth. I don't say that lightly."},
				{"to": "the group chat", "text": "drop one deep line and they build a whole personality for you"},
				{"to": "an ex, 3am from the afterparty", "text": "I'm in such a real introspective season 🙏"},
				{"to": "a friend", "text": "the book? I read the quotes people post. same effect."}]},
		{"id": "vance", "name": "Vance", "hidden_type": "resource",
			"surface": "high_sugar", "energy_cost": 2,
			"risk": "Filler-text flirt", "opportunity": "Shows up hard when it's real",
			"chat": [{"from": "him", "text": "thinking about you, ridiculous, I know 🙈"},
					 {"from": "you", "text": "ridiculous indeed"},
					 {"from": "him", "text": "guilty. also handled the saturday thing, don't worry about it"}],
			"others_chat": [
				{"to": "a friend mid-crisis", "text": "I'm outside. left the dinner. don't apologize, just come down, I'm here."},
				{"to": "his mother", "text": "cleared the bill with the hospital. you focus on getting better."},
				{"to": "a colleague", "text": "sent the corrected deck, owned the error to the client myself"},
				{"to": "his sister", "text": "yeah I'm goofy with her. I also drove four hours for you. both true."}]},
		{"id": "emmett", "name": "Emmett", "hidden_type": "growth",
			"surface": "growth", "energy_cost": 1,
			"risk": "Slow on purpose", "opportunity": "Consistent, no 'but' in his apologies",
			"chat": [{"from": "him", "text": "I'm slow. I'd rather be slow and real than fast and gone."},
					 {"from": "you", "text": "noted."},
					 {"from": "him", "text": "no pressure. just honest."}],
			"others_chat": [
				{"to": "a mentor", "text": "said no to the shiny offer. it was ego bait. staying the course."},
				{"to": "his sister", "text": "apologized properly, no 'but'. took me a year to learn that sentence."},
				{"to": "a friend", "text": "didn't text her when I was lonely and bored. that's not a reason. waited."},
				{"to": "a colleague", "text": "your win, your spotlight. I'll say it in the meeting too."}]},
		{"id": "cyrus", "name": "Cyrus", "hidden_type": "high_sugar",
			"surface": "false_alpha", "energy_cost": 2,
			"risk": "Volume, no substance", "opportunity": "None — broke behind the swagger",
			"chat": [{"from": "him", "text": "I move different. people follow me. you'll feel it."},
					 {"from": "you", "text": "feel what?"},
					 {"from": "him", "text": "the energy. trust the energy."}],
			"others_chat": [
				{"to": "a friend he owes", "text": "bro stop asking about the money, it's coming, you're killing the vibe"},
				{"to": "another girl", "text": "I move different, people follow me, you'll feel it"},
				{"to": "his landlord, 3rd notice", "text": "friday, 100%, locked in"},
				{"to": "his brother", "text": "don't tell mum about the job thing. it's handled. it's fine."}]},
		{"id": "devon", "name": "Devon", "hidden_type": "resource",
			"surface": "growth", "energy_cost": 2,
			"risk": "Buzzword packaging", "opportunity": "Underneath, just keeps his word",
			"chat": [{"from": "him", "text": "I'm big on intention and showing up. let's build something real."},
					 {"from": "you", "text": "buzzwords."},
					 {"from": "him", "text": "fair. plainly: I do what I say. test me."}],
			"others_chat": [
				{"to": "a contractor", "text": "deposit's in. milestones in the doc. miss one, we talk. hit them, we're great."},
				{"to": "his father", "text": "care's covered through december. it's done. don't ask twice."},
				{"to": "an ex", "text": "no late talks. one daytime call if it's real. otherwise nothing."},
				{"to": "a friend", "text": "the 'intention' talk is packaging. underneath I just keep my word."}]},
		{"id": "hale", "name": "Hale", "hidden_type": "growth",
			"surface": "high_sugar", "energy_cost": 1,
			"risk": "Jokes past the real thing", "opportunity": "Privately the one who shows up",
			"chat": [{"from": "him", "text": "you're a menace and my favorite notification 😌"},
					 {"from": "you", "text": "smooth operator"},
					 {"from": "him", "text": "operator? forgot my own joke halfway. night, menace."}],
			"others_chat": [
				{"to": "a kid he mentors", "text": "you bombed it. good. now we know what to fix. tuesday, same time, we go again."},
				{"to": "a friend", "text": "told the team I dropped the ball, not them. it was me. owned it."},
				{"to": "his sister", "text": "didn't send the funny deflection. said the real thing. felt bad, then lighter."},
				{"to": "a mentor", "text": "taking the unglamorous project. it's the one that'll actually teach me."}]},
		{"id": "roman", "name": "Roman", "hidden_type": "high_sugar",
			"surface": "resource", "energy_cost": 2,
			"risk": "Provider cosplay", "opportunity": "None — you'll get the bill",
			"chat": [{"from": "him", "text": "I take care of my people. with me you never want for anything."},
					 {"from": "you", "text": "big claim."},
					 {"from": "him", "text": "watch me. you'll see."}],
			"others_chat": [
				{"to": "a waiter", "text": "split it onto her card 'as a joke', I'll get the next one (he won't)"},
				{"to": "another girl", "text": "I take care of my people, with me you never want for anything"},
				{"to": "a friend", "text": "owe you? bro that was ages ago, let it go, we're family"},
				{"to": "his mother", "text": "can't make sunday again, work, you understand"}]},
		{"id": "arlo", "name": "Arlo", "hidden_type": "resource",
			"surface": "resource", "energy_cost": 1,
			"risk": "Not smooth at all", "opportunity": "Shows up with tools, stays till it's done",
			"chat": [{"from": "him", "text": "Pipe under your sink — I'll fix it Saturday. Also: dinner after."},
					 {"from": "you", "text": "that's a weird combo."},
					 {"from": "him", "text": "both real. both happening."}],
			"others_chat": [
				{"to": "a neighbor", "text": "left the ladder by your door. fixed your gate hinge while I was there. no charge, obviously."},
				{"to": "his brother", "text": "moved the money quietly. mum doesn't need to know who covered it."},
				{"to": "a friend", "text": "I'm not smooth. I show up with tools and stay till it's done. that's the whole me."},
				{"to": "an ex", "text": "I'll drop the boxes saturday 10am. clean and done. no conversation needed."}]},
```

- [ ] **Step 2: Run, verify GREEN.** `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -2` — expect `RAN 76 tests, 0 failures`. Then `/opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -1` — expect `SPOT SMOKE OK men=36`.

- [ ] **Step 3: Commit** (repo root):
```bash
cd /Users/kuma/Projects/Polaris && git add Godot/core/Content.gd && git commit -m "$(cat <<'EOF'
feat(hunting): corpus batch B — +12 men (24→36)

soren/tariq/emmett/arlo (consistent 好), idris (consistent 渣),
pierce/knox/cyrus/roman (痛: sugar masked as resource/growth/
false_alpha), vance/devon/hale (爽: substance masked as sugar/growth).
Full locked schema; others_chat[0] = sharpest tell. Append-only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Lock the new floor + full regression

**Files:** Modify `Godot/tests/test_peek_chat.gd` (append one test).

- [ ] **Step 1: Append the size-lock test** to the END of `Godot/tests/test_peek_chat.gd` (reuse the existing `_man()`/`const Content`; do not alter existing tests):

```gdscript

func test_corpus_size_locked() -> void:
	ge(Content.men().size(), 36, "≥36 men after 12→36 expansion")
	# Spot-check a few new ids across both disguise directions + a consistent one.
	var owen := _man("owen")
	var caleb := _man("caleb")
	var arlo := _man("arlo")
	eq(owen["hidden_type"], "high_sugar", "owen truth = high_sugar (痛: sugar→resource)")
	eq(owen["surface"], "resource", "owen performs resource")
	eq(caleb["hidden_type"], "resource", "caleb truth = resource (爽: resource→sugar)")
	eq(caleb["surface"], "high_sugar", "caleb performs high_sugar")
	eq(arlo["hidden_type"], "resource", "arlo truth = resource (consistent 好)")
	eq(arlo["surface"], "resource", "arlo consistent (surface == truth)")
	for nid in ["owen", "caleb", "arlo"]:
		var r: Dictionary = PeekChat.peek(_man(nid))
		ok(not r.has("hidden_type"), "%s peek still hides truth" % nid)
```

- [ ] **Step 2: Run, verify GREEN.** `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --script res://tests/run_tests.gd 2>&1 | tail -2` — expect `RAN 77 tests, 0 failures` (76 + 1 new).

- [ ] **Step 3: Full regression + unaffected.** `cd /Users/kuma/Projects/Polaris/Godot && /opt/homebrew/bin/godot --headless --quit; echo "boot=$?"; /opt/homebrew/bin/godot --headless --script res://peek_ui_smoke.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --script res://ui_smoke.gd 2>&1 | tail -1; /opt/homebrew/bin/godot --headless --script res://play.gd 2>&1 | tail -1` — expect `boot=0`; `SPOT SMOKE OK men=36`; `HUB SMOKE OK day=2 dossier=3 reads=3`; play ends `Season close.`.

- [ ] **Step 4: Windowed sanity (best-effort).** `cd /Users/kuma/Projects/Polaris/Godot && timeout 12 /opt/homebrew/bin/godot --path . res://scenes/Peek.tscn 2>&1 | tail -6 ; echo "rc=$?"` — pass: NO `SCRIPT ERROR`/parse ERROR; rc 124 or 0 both fine; headless-only acceptable (say so). Quote the tail.

- [ ] **Step 5: Commit** (repo root):
```bash
cd /Users/kuma/Projects/Polaris && git add Godot/tests/test_peek_chat.gd && git commit -m "$(cat <<'EOF'
test(hunting): lock corpus floor at ≥36 + new-id disguise spot-checks

Asserts men.size()≥36 and pins owen(痛)/caleb(爽)/arlo(consistent)
hidden_type×surface; peek still never leaks truth. Full regression
green; hub/play/engine unaffected.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review (plan author)

**Spec coverage:** "12→36 append-only, no rename/reorder, full locked schema each" → Tasks 1–2 insert 24 entries after `rhys` before `	]`; every entry has id/name/hidden_type/surface/energy_cost/risk/opportunity/chat(3)/others_chat(4). "hidden_type ∈ exactly {resource,high_sugar,growth}, no 4th" → every new man uses only those three (false_alpha/high_sugar/growth/resource appear only as `surface`). "others_chat[0] = sharpest tell" → each man's first others_chat line is his most damning/revealing (the recycled-verbatim line for 痛 cases owen/felix/idris/knox/roman; the offstage-delivers line for 爽 cases; the consistent tell for calibration men). "disguise matrix, ≥5 disguised, both directions, distinct flavors, no cross-man copy-paste" → 17 disguised of 24 (痛: owen/felix/dominic/ezra/pierce/knox/cyrus/roman; 爽: caleb/nico/reid/mateo/jonah/beck/vance/devon/hale), 7 consistent (gabe/idris 渣; dane/soren/tariq/emmett/arlo 好); each flavor distinct (career-access / trauma-script / name-drop / therapy-speak / optics-on-credit / borrowed-depth / provider-cosplay / volume vs. handles-crisis / recovery / funds-tuition / owns-mistakes / logistics / 2am-shows-up / mentors); intra-man recycled lines used deliberately, no two different men share lines. "cold-premium/anti-otome/specific English matching the 12" → timestamps, "another girl", group-chat confessions, terse-real, no otome. "tests >=-based generalize, stay green at 24 & 36, add one size-lock" → Tasks 1–2 add no tests (suite stays `RAN 76 … 0 failures`), Task 3 appends `test_corpus_size_locked` (→77). "Peek/Spotter/PeekChat/UiKit/run_tests/tuning/hub untouched" → only `Content.gd` (Tasks 1–2) and `test_peek_chat.gd` (Task 3) modified.

**Placeholder scan:** No TBD/TODO. All 24 men are verbatim GDScript; the appended test is verbatim; exact anchor, commands, expected outputs given. Counts stated 76 (Tasks 1–2, unchanged) → 77 (Task 3).

**Type consistency:** New men dict shape byte-matches existing entries (`chat`=`{from,text}`, `others_chat`=`{to,text}`). `hidden_type` values ∈ the 3 the existing `test_peek_chat`/`test_spotter` assert. Task 3 reads `man["hidden_type"]/["surface"]` (bracket Variant), `_man()`/`const PeekChat`/`ge`/`eq`/`ok` reused (all exist). Spot-check ids (`owen`/`caleb`/`arlo`) exist in Tasks 1–2 with exactly the asserted hidden_type/surface. `PeekChat.peek` 4-key contract (no `hidden_type`) unchanged → spot-check holds.

**Scope:** Two atomic content commits (each independently green at 24 then 36) + one test-lock commit. Pure content slab; the casual game picks the 36 men up automatically. User runs `godot --path . res://scenes/Peek.tscn` and iterates copy after.
