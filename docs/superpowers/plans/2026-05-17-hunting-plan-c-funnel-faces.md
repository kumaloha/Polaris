# Hunting Plan C — Social/Collection/Asset Faces + Funnel Wiring

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`).

**Goal:** Fill the 3 Plan-B stub faces and wire the Plan-A social funnel into the hub's soft daily cycle: 社交媒体 (compose post → who slides in + gf leads; comment/DM read → dossier), 派对 consumes the funnel-produced inbound pool, 集卡 browses dossier/network/keyframes, 资产清单 shows the net-worth balance sheet. End state: a full night **自我提升 → 社交媒体(发帖) → 派对(读 inbound) → 约会 → 结算** is click-walkable in Chinese.

**Architecture:** UI-ONLY. The engine (Plan A added `compose_post`/`inbound_men`/`read_signal`; everything else) is **NOT touched** — Plan C only consumes it from `ui/Hub.gd` + `ui/Faces.gd` (+ `Loc.gd` append-only). 56 engine tests + `play.gd` stay green. Reuse `UiKit`/`Theme`/`Loc`; follow Plan B patterns (preloaded `const Hub` for `match` patterns, per-iteration lambda-capture locals, bracket Variant access, `Loc.t` whole-string with `%`-split for formatted lines).

**Soft-cycle integration:** posting is intra-night, before 派对. `compose_post` is one-per-night (engine guards `_np_posted`, reset in `begin_night`). The hub must call `ensure_night()` before posting (opens the night, locks the build consistently — same soft-cycle semantics as entering 派对) and, after a post, show the result and NOT offer re-post that night (visible, like Plan B's build-lock). `_post_night()` must also erase the new per-night social ui keys so night N+1 starts clean. 派对 First Eye shows `flow.inbound_men()` (who your post attracted) when non-empty, else falls back to `flow.party_men()`.

**Carried Plan-A-review constraints (honor):** (1) one post per night, made visible (no silent free-roll standing farming); (2) posting raises Standing and may trip the gf-lead in the same call — intended; just display it.

**Tech Stack:** Godot 4.6 GDScript, code-gen UI, portrait, Loc zh. **Source:** hub-IA spec §4.2/§4.6/§4.7/§8 Plan C. Engine on `main` HEAD `aee65a1`.

**Project-wide constraints:** new commit only; **UI-only — verify `git diff` shows zero `core/`/`tests/`/`play.gd`/`project.godot` change each task**; `Loc.gd` append-only (no existing key altered; no duplicate key — a dup parse-errors at boot, which is the check).

---

## Engine API consumed (already on `main`; do NOT modify)

`flow.compose_post(posture:String) -> {inbound_men:Array, gf_leads:Array, control_delta:int, standing_delta:int, mirror:String}` (posture "scarce"|"validation"; one/night via `_np_posted`; intra-night, no day advance; resets in `begin_night`). `flow.inbound_men() -> Array` (the night's funnel pool). `flow.read_signal(hidden_type:String, guess:String) -> {correct:bool, dossier_size:int}` (correct → archives `state.dossier`). `flow.state.dossier:Array` (`[{type,result}]`), `flow.state.keyframes:Array` (`[{man,result}]`). `flow.gf` Girlfriends (`available_tier()`, `_warmth:Dictionary`). `Content.men()` (each `{id,name,hidden_type,surface,...}`), `Content.girlfriends()` (`{id,name,role,tier}`). Existing hub: `flow.party_men()`, `available_parties()`, `choose_party`, `set_primary`, `start_party`, `record_party_action`, `book_for_after`, `resolve_after`, `finish_night`, `at_week_boundary`, `settle`, `at_season_boundary`, `close_season`, `state.snapshot()`/`net_worth()`. Hub: `enum F{HOME,SELF,SOCIAL,PARTY,DATING,CARDS,ASSETS}`, `ensure_night()`, `_post_night()` (erases `after`/`_chose_party`/`show_future`).

---

### Task 1: SOCIAL face — compose post + comment/DM read; Hub wiring

**Files:** Modify `Godot/ui/Hub.gd`, `Godot/ui/Faces.gd`, `Godot/ui/Loc.gd` (append).

- [ ] **Step 1: Hub methods** — append to `Godot/ui/Hub.gd`:
```gdscript
func act_compose_post(posture: String) -> void:
	ensure_night()
	if ui.has("post_result"):
		return
	ui["post_result"] = flow.compose_post(posture)
	_render()

func act_read_signal(hidden_type: String, guess: String) -> void:
	var r = flow.read_signal(hidden_type, guess)
	ui["read_feedback"] = "correct" if r.correct else "wrong"
	_render()
```
And in `_post_night()`, alongside the existing `ui.erase("after")` / `ui.erase("_chose_party")` / `ui.erase("show_future")` block, add: `ui.erase("post_result")` and `ui.erase("read_feedback")` (so social state resets each night). (Append these two erase lines into that same existing block — do not remove/alter the existing erases.)

- [ ] **Step 2: SOCIAL face** — replace the `Hub.F.SOCIAL` arm stub in `Godot/ui/Faces.gd` with:
```gdscript
		Hub.F.SOCIAL:
			K.label(r, "SOCIAL MEDIA", T.PAD, 240, T.TITLE, T.ACCENT)
			K.label(r, "After you change your look you post. What you post decides who slides in.", T.PAD, 330, T.SMALL, T.DIM, W)
			var y := 470
			if h.ui.has("post_result"):
				var pr = h.ui["post_result"]
				K.label(r, "Posted. %d slid in · %d girlfriend lead(s) · Standing %+d · Control %+d" % [int(pr["inbound_men"].size()), int(pr["gf_leads"].size()), int(pr["standing_delta"]), int(pr["control_delta"])], T.PAD, y, T.BODY, T.TEXT, W)
				y += 150
				if str(pr["mirror"]) != "":
					K.label(r, str(pr["mirror"]), T.PAD, y, T.SMALL, Color(0.85,0.35,0.35), W)
					y += 140
				K.label(r, "(One post per night. Go to PARTY to read who showed up.)", T.PAD, y, T.SMALL, T.DIM, W)
			else:
				K.label(r, "POST TONIGHT", T.PAD, y, T.SMALL, T.DIM); y += 56
				K.btn(r, "Scarce — restrained, fewer but higher-value", T.PAD, y, W, T.BTN_H, func(): h.act_compose_post("scarce")); y += T.BTN_H + 16
				K.btn(r, "Validation — chase the feed, more but cheaper", T.PAD, y, W, T.BTN_H, func(): h.act_compose_post("validation")); y += T.BTN_H + 28
			y += 20
			K.label(r, "READ THE COMMENTS", T.PAD, y, T.SMALL, T.DIM); y += 56
			if h.ui.has("read_feedback"):
				var fb: String = h.ui["read_feedback"]
				K.label(r, "Filed — you read him right." if fb == "correct" else "Off. Look again.", T.PAD, y, T.SMALL, (T.ACCENT if fb == "correct" else T.DIM), W)
				y += 90
			K.label(r, "A DM: \"hey gorgeous, up late thinking about you 😉\"", T.PAD, y, T.SMALL, T.TEXT, W); y += 80
			for g in ["high_sugar", "resource", "growth"]:
				var gg: String = g
				K.btn(r, gg, T.PAD, y, W, 100, func(): h.act_read_signal("high_sugar", gg))
				y += 116
```
(The DM sample is a high_sugar tell; guessing `high_sugar` is the correct read → dossier archive. Keep deterministic. Buttons show the raw type id — localized via Loc keys added in Step 3.)

- [ ] **Step 3: Loc append** — append to `Godot/ui/Loc.gd` `ZH` (only if the exact key is absent; no duplicate, no existing-key change) zh for the new fixed strings: `"After you change your look you post. What you post decides who slides in."→"换好造型就发出去。你发什么，决定谁来撩你。"`, `"POST TONIGHT"→"今晚发帖"`, `"Scarce — restrained, fewer but higher-value"→"克制——少而高质"`, `"Validation — chase the feed, more but cheaper"→"博取认同——多但廉价"`, `"(One post per night. Go to PARTY to read who showed up.)"→"（每晚一帖。去派对看谁来了。）"`, `"READ THE COMMENTS"→"读评论区"`, `"Filed — you read him right."→"已归档——你读对了。"`, `"Off. Look again."→"看走眼了，再看看。"`, `"A DM: \"hey gorgeous, up late thinking about you 😉\""→"一条私信：「美女还没睡呀，一直在想你 😉」"`, `"high_sugar"→"糖衣型"`, `"resource"→"资源型"`, `"growth"→"成长型"`. (The `Posted. %d ... %+d` line is numeric/format — leave it as-is; numbers+`%` line, not a translatable whole string, acceptable per the established rule.)

- [ ] **Step 4: Verify** — `cd Godot && godot --headless --quit` → exit 0, NO parse/script errors (no dup Loc key). `cd Godot && godot --headless --script res://tests/run_tests.gd` → `RAN 56 tests, 0 failures`, exit 0. `cd Godot && godot --headless --script res://play.gd` → exit 0 coherent. `git diff --stat aee65a1..HEAD -- Godot/core Godot/tests Godot/play.gd Godot/project.godot` → EMPTY. `git diff aee65a1..HEAD -- Godot/ui/Loc.gd | grep -E '^-[^-]' | wc -l` → 0. (Do NOT run ui_smoke — extended in Task 4.)

- [ ] **Step 5: Commit**
```bash
git add Godot/ui/Hub.gd Godot/ui/Faces.gd Godot/ui/Loc.gd
git commit -m "feat(hunting-ui): social face — compose post + comment read (funnel)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: PARTY face consumes the funnel inbound pool

**Files:** Modify `Godot/ui/Hub.gd` (add helper), `Godot/ui/Faces.gd` (PARTY First-Eye list source).

- [ ] **Step 1: Hub helper** — append to `Godot/ui/Hub.gd`:
```gdscript
func party_face_men() -> Array:
	var inbound = flow.inbound_men()
	if inbound.size() > 0:
		return inbound
	return flow.party_men()
```

- [ ] **Step 2: Faces PARTY First-Eye** — in `Godot/ui/Faces.gd`, in the `Hub.F.PARTY` arm, the First-Eye substate currently iterates `h.flow.party_men()`. Change ONLY that iteration source to `h.party_face_men()` (and the guard `h.flow.party_men().size() > 0` → `h.party_face_men().size() > 0`). Do not change the map / rounds substates, the `act_enter_party` wiring, or anything else. (`party_face_men()` returns the funnel inbound pool when a post was made this night, else the default party pool — so the men you read are who your post attracted.)

- [ ] **Step 3: Verify** — `cd Godot && godot --headless --quit` exit 0 no errors. `... res://tests/run_tests.gd` → `RAN 56 tests, 0 failures` exit 0. `... res://play.gd` exit 0. `git diff --stat aee65a1..HEAD -- Godot/core Godot/tests Godot/play.gd Godot/project.godot` EMPTY.

- [ ] **Step 4: Commit**
```bash
git add Godot/ui/Hub.gd Godot/ui/Faces.gd
git commit -m "feat(hunting-ui): party reads the social-funnel inbound pool

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: 集卡 (CARDS) + 资产清单 (ASSETS) faces

**Files:** Modify `Godot/ui/Faces.gd`, `Godot/ui/Loc.gd` (append).

- [ ] **Step 1: CARDS + ASSETS faces** — replace the `Hub.F.CARDS` and `Hub.F.ASSETS` stub arms in `Godot/ui/Faces.gd`:
```gdscript
		Hub.F.CARDS:
			K.label(r, "COLLECTION", T.PAD, 240, T.TITLE, T.ACCENT)
			K.label(r, "Your reads, your circle, your proven calls — earned, not drawn.", T.PAD, 330, T.SMALL, T.DIM, W)
			var y := 470
			K.label(r, "DOSSIER (men you read right)", T.PAD, y, T.SMALL, T.DIM); y += 56
			var d := h.flow.state.dossier
			if d.size() == 0:
				K.label(r, "— none yet —", T.PAD, y, T.SMALL, T.TEXT); y += 60
			else:
				for e in d:
					K.label(r, "·  %s" % str(e["type"]), T.PAD + 16, y, T.SMALL, T.TEXT); y += 50
			y += 30
			K.label(r, "GIRLFRIEND NETWORK", T.PAD, y, T.SMALL, T.DIM); y += 56
			for g in Content.girlfriends():
				var warm: int = int(h.flow.gf._warmth.get(g["id"], 0))
				K.label(r, "·  %s (%s)  warmth %d" % [str(g["name"]), str(g["role"]), warm], T.PAD + 16, y, T.SMALL, T.TEXT, W - 16); y += 56
			y += 30
			K.label(r, "KEYFRAMES (proven futures)", T.PAD, y, T.SMALL, T.DIM); y += 56
			var kf := h.flow.state.keyframes
			if kf.size() == 0:
				K.label(r, "— none yet —", T.PAD, y, T.SMALL, T.TEXT)
			else:
				for k in kf:
					K.label(r, "·  %s — %s" % [str(k["man"]), str(k["result"])], T.PAD + 16, y, T.SMALL, T.TEXT, W - 16); y += 50
		Hub.F.ASSETS:
			K.label(r, "ASSET LIST", T.PAD, 240, T.TITLE, T.ACCENT)
			K.label(r, "What you compounded. The men cleared; you didn't.", T.PAD, 330, T.SMALL, T.DIM, W)
			var s2 = h.flow.state.snapshot()
			var dz: int = h.flow.state.dossier.size()
			var kz: int = h.flow.state.keyframes.size()
			var liab := 0
			for db in h.flow.state.debts:
				liab += int(db.get("amount", 0))
			var y := 480
			K.label(r, "ASSETS", T.PAD, y, T.SMALL, T.DIM); y += 56
			K.label(r, "Standing %d   Dossier %d   Keyframes %d" % [int(s2["position"]), dz, kz], T.PAD + 16, y, T.BODY, T.TEXT, W); y += 110
			K.label(r, "LIABILITIES", T.PAD, y, T.SMALL, T.DIM); y += 56
			K.label(r, "Fantasy debt %d" % liab, T.PAD + 16, y, T.BODY, Color(0.85,0.35,0.35), W); y += 110
			K.label(r, "NET WORTH  %d" % int(s2["net_worth"]), T.PAD, y, T.TITLE, T.ACCENT, W); y += 110
			if h.ui.has("settle"):
				K.label(r, "last week settled at %s" % str(h.ui["settle"].get("net_worth", 0)), T.PAD, y, T.SMALL, T.DIM, W)
```

- [ ] **Step 2: Loc append** — append (absent keys only, no dup/alter): `"Your reads, your circle, your proven calls — earned, not drawn."→"你的读人、你的圈子、你应验的判断——挣来的，不是抽来的。"`, `"DOSSIER (men you read right)"→"案底（你读对过的男人）"`, `"GIRLFRIEND NETWORK"→"闺蜜网络"`, `"KEYFRAMES (proven futures)"→"关键帧（被验证的未来）"`, `"— none yet —"→"— 暂无 —"`, `"What you compounded. The men cleared; you didn't."→"你复利下来的东西。男人都清仓了，你没有。"`, `"ASSETS"→"资产"`, `"LIABILITIES"→"负债"`. (Lines with `%d`/`%s` stay numeric per the established rule.)

- [ ] **Step 3: Verify** — `godot --headless --quit` exit 0 no errors; `... run_tests.gd` `RAN 56 tests, 0 failures` exit 0; `... play.gd` exit 0; engine guard diff EMPTY; Loc `grep '^-[^-]'|wc -l`=0.

- [ ] **Step 4: Commit**
```bash
git add Godot/ui/Faces.gd Godot/ui/Loc.gd
git commit -m "feat(hunting-ui): collection + asset-list faces (dossier/network/keyframes/net worth)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Full-night smoke (incl. post) + verification + README + push-ready

**Files:** Modify `Godot/ui_smoke.gd`, `Godot/README.md`.

- [ ] **Step 1: Extend `ui_smoke.gd`** — drive the FULL night through the hub INCLUDING the social post: after setting `ui.self_invest`/`ui.persona`, do `h.go_face(h.F.SOCIAL)` then `h.act_compose_post("scarce")` (opens the night + sets inbound pool), then `h.go_face(h.F.PARTY)`, `h.ui["_chose_party"]=true`, `h.act_choose_party("rooftop")`, then enter a man from `h.party_face_men()` (use its first element's `id`, NOT a hardcoded "adrian", since the inbound pool drives it) → `h.act_enter_party(<that id>)`, loop `act_party("boundary")` until `enc.finished`, `h.ui["after"]={<that id>:"date"}`, `h.act_after(h.ui["after"])`, `if h.ui.get("show_future",false): h.dismiss_future()`. Assert `h.flow.state.day >= 2` AND `h.flow.state.dossier.size() >= 0` (post path ran). Print `HUB SMOKE OK day=%d dossier=%d` , `quit(0)`. Keep the deferred/await `_ready` pattern. Drive ONLY via Hub methods.

- [ ] **Step 2: Run** — `cd Godot && godot --headless --script res://ui_smoke.gd` → `HUB SMOKE OK day=2 ...`, exit 0. Fix real cause if it errors (e.g. `party_face_men()` empty if compose_post inbound empty — but scarce reach≥1 guarantees ≥1; if the chosen party gating blocks, ensure `act_choose_party("rooftop")` after `ensure_night` via compose_post's `ensure_night`). Do NOT weaken asserts; do NOT bypass the hub.

- [ ] **Step 3: Gates + UI-only** — `... run_tests.gd` → `RAN 56 tests, 0 failures` exit 0; `godot --headless --quit` exit 0; `... play.gd` exit 0. `git diff --stat aee65a1..HEAD -- Godot/core Godot/tests Godot/play.gd Godot/project.godot` → EMPTY. `git diff aee65a1..HEAD -- Godot/ui/Loc.gd | grep -E '^-[^-]' | wc -l` → 0.

- [ ] **Step 4: README** — append a short note to `Godot/README.md`: full night now flows 自我提升 → 社交媒体(发帖:克制/博认同) → 派对(读你帖子招来的人) → 约会 → 结算; 集卡/资产 browse dossier/network/keyframes/net worth.

- [ ] **Step 5: Commit**
```bash
git add Godot/ui_smoke.gd Godot/README.md
git commit -m "test(hunting-ui): full-night hub smoke incl. social post; docs

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (plan author)

**Spec coverage (hub-IA §4.2/§4.6/§4.7/§8 Plan C):** SOCIAL = compose_post posture (scarce/validation = the Control B-decision) + result incl. mirror + comment/DM `read_signal` (dossier producer surfaced) — Task 1; 派对 consumes `inbound_men()` (who the post attracted), fallback party_men — Task 2; 集卡 browses dossier/network/keyframes (earned-not-drawn copy) + 资产清单 net-worth balance sheet — Task 3; full-night walkable incl. post, zh — Task 4. Carried Plan-A constraints honored: one post/night made visible (post_result gate + "one post per night" copy; engine `_np_posted` guards); standing+gf-lead same-call shown not hidden. Equity *curve* shown as a balance-sheet breakdown + last-settle figure (engine has no history; curve = future, noted).

**Placeholder scan:** no TBD; complete code each step; `%`-format lines intentionally numeric (established rule), all translatable whole strings keyed.

**Type consistency:** `act_compose_post`/`act_read_signal`/`party_face_men` added to Hub; Faces arms use `Hub.F.*` patterns (preloaded const), bracket Variant access, per-iteration capture (`gg`,`e`,`g`,`k`,`db`); `flow.*` calls match on-`main` API exactly; `_post_night` erase-block extended for `post_result`/`read_feedback` (same per-night-reset pattern as Plan B's fix).

**UI-only:** every task verifies zero `core/`/`tests/`/`play.gd`/`project.godot` change + 56 tests + play.gd green + Loc append-only (0 deletions, boot-no-dup).

**Scope:** final sub-plan; completes the hub IA. One coherent UI plan.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-05-17-hunting-plan-c-funnel-faces.md`. Subagent-driven: Task 1 (SOCIAL + Hub wiring) spec+quality review; Tasks 2–4 lighter combined. Proceed with Task 1 unless redirected.
