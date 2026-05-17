# Hunting Plan E — Visual Re-skin (恋与-craft, 猎场-soul)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`).

**Goal:** Lift the hub from code-gen placeholder to a **premium, layered, typographically-crafted** look — borrowing 恋与制作人's *production craft & structure* (depth, polish, refined type, smooth motion, card-detail emphasis) while keeping the LOCKED cold-premium / anti-otome / she-is-the-centre / defensive-framing soul. **Visual layer only — IA, hub logic, engine, Loc semantics, tests all unchanged.** The user will iterate on the design later; this plan establishes the re-skin pipeline + a strong first pass.

**Ceiling (honest):** no illustration/Live2D art and still code-generated → target = a clean, deep, well-typeset premium *code* UI, not pixel-恋与. The biggest levers are **a real font pair**, a **3-layer depth system**, and **a token-driven surface/spacing system** concentrated in `Theme.gd` + `UiKit.gd` so `Faces.gd` changes stay minimal.

**Architecture:** Concentrate the re-skin in `Theme.gd` (design tokens) and `UiKit.gd` (primitives: layered background, font application, panel/card/navbar/bar helpers, self-animating root). `Faces.gd` changes are mechanical: swap `root()`→`screen()`, group free-placed content into `panel()`/`card()`, add the HOME heroine emblem — content/layout/Loc calls unchanged. **`Hub.gd` is byte-unchanged** (motion lives in the UiKit-returned root, self-animating on enter — no Hub logic touched). **`Loc.gd` is byte-unchanged** (no new strings; purely visual). **`project.godot` byte-unchanged** (fonts loaded via `load()` in UiKit, not registered in project settings).

**Tech Stack:** Godot 4.6 GDScript, code-gen UI, portrait 1170×2532, Tween motion, bundled OFL font(s) (graceful fallback to engine default if unavailable). Loc zh.

**Source:** prior brainstorm (option A: 恋与 craft+structure, our locked tone); carry-spec §1 acceptability spine (cold-premium, men≠prize, she-centre, defensive). Engine/UI on `main` HEAD `4e02f52`.

**Project-wide constraints:** new commit only; **VISUAL-LAYER-ONLY** — every task verifies `git diff --stat <base>..HEAD -- Godot/core Godot/tests Godot/play.gd Godot/project.godot Godot/ui/Loc.gd Godot/ui/Hub.gd Godot/scenes Godot/ui_smoke.gd` is EMPTY; 59 engine tests + `ui_smoke.gd` (`HUB SMOKE OK day=2 dossier=3 reads=3`) + `play.gd` stay green/coherent (the re-skin is purely presentational — the smoke drives the same Hub methods, only visuals change). Established Godot-4.6 fixes apply (typed vars, bracket Variant, per-iteration capture).

---

### Task 1: Design tokens + font asset + UiKit base (layered bg, typography, surface)

**Files:** Modify `Godot/ui/Theme.gd`, `Godot/ui/UiKit.gd`; Create `Godot/assets/fonts/` (font files) + `Godot/assets/fonts/README.md` (license note).

- [ ] **Step 1: Fonts.** Create `Godot/assets/fonts/`. Attempt to fetch 2 OFL (SIL Open Font License) fonts via curl into that dir (network may be available — the repo has used brew/gh before): a clean UI/body sans and a higher-contrast display face. Suggested (OFL, from Google Fonts' GitHub raw, static TTFs): body = `Inter` (or `Manrope`), display = `Fraunces` or `Cormorant` (an elegant high-contrast serif for titles/numbers — premium, on-tone). Save as e.g. `ui_sans.ttf`, `ui_display.ttf`. Write `Godot/assets/fonts/README.md` recording exact source URLs + that both are OFL. **If network is unavailable or fetch fails**: do NOT fail the task — create `Godot/assets/fonts/README.md` documenting the intended fonts + that the engine default is used as fallback, and the rest of the plan degrades gracefully (UiKit guards: load font if the file exists, else skip the font override → engine default). State which path happened in your report.

- [ ] **Step 2: Theme tokens** — rewrite `Godot/ui/Theme.gd` as a token set (keep `class_name UiTheme`; KEEP every existing const name so existing Faces refs don't break — only re-value + ADD):
```gdscript
extends RefCounted
class_name UiTheme
# --- palette: cold premium, 3-step elevation, single warm accent ---
const BG_TOP := Color("#0c0b10")
const BG_BOT := Color("#070608")
const PANEL := Color("#15131b")          # surface
const PANEL_2 := Color("#1d1a25")        # raised surface
const PANEL_SEL := Color("#2a2233")      # selected
const STROKE := Color("#2e2a38")         # hairline
const TEXT := Color("#f1eef6")
const DIM := Color("#9b94a8")
const FAINT := Color("#615b6e")
const ACCENT := Color("#c9a26b")         # champagne — sole hero accent
const ACCENT_SOFT := Color("#7c6a4e")
const COOL := Color("#8fb3c9")           # restrained cool secondary (selected/earned)
const DANGER := Color("#7d2f33")         # debt / mirror — deep oxblood
# --- canvas / spacing rhythm (8-grid scaled to 1170x2532) ---
const REF_W := 1170
const REF_H := 2532
const PAD := 64
const GAP := 24
const S1 := 16
const S2 := 32
const S3 := 56
const S4 := 88
# --- component metrics ---
const BTN_H := 132
const CARD_H := 200
const RADIUS := 18
const NAV_H := 188
# --- type scale ---
const DISPLAY := 84
const TITLE := 60
const BODY := 40
const SMALL := 32
const TINY := 26
# --- fonts (resource paths; UiKit guards existence) ---
const FONT_SANS := "res://assets/fonts/ui_sans.ttf"
const FONT_DISPLAY := "res://assets/fonts/ui_display.ttf"
```
(Existing Faces.gd uses `T.PAD/GAP/BTN_H/CARD_H/TITLE/BODY/SMALL/ACCENT/TEXT/DIM/PANEL/PANEL_SEL/REF_W/REF_H/BG_TOP`. ALL of those names are kept above — re-valued only. New tokens are additive. So Faces.gd keeps compiling unchanged at this step.)

- [ ] **Step 3: UiKit base primitives** — rewrite `Godot/ui/UiKit.gd` keeping `class_name UiKit` and the EXISTING public signatures `root() -> Control`, `label(parent,text,x,y,size,color,w:=0) -> Label`, `btn(parent,text,x,y,w,h,cb,sel:=false) -> Button` (so Faces.gd keeps working), and ADD `screen() -> Control`, `panel(parent,x,y,w,h,raised:=false) -> Panel`, `navbar(parent) -> Control`, `bar(parent,x,y,w,frac:Float,col:Color)`, plus internal font loading + a self-animating root. Implement:
```gdscript
extends RefCounted
class_name UiKit
const T := preload("res://ui/Theme.gd")
const Loc := preload("res://ui/Loc.gd")

static var _f_sans: Font = null
static var _f_disp: Font = null
static var _f_loaded := false
static func _fonts() -> void:
	if _f_loaded: return
	_f_loaded = true
	if ResourceLoader.exists(T.FONT_SANS): _f_sans = load(T.FONT_SANS)
	if ResourceLoader.exists(T.FONT_DISPLAY): _f_disp = load(T.FONT_DISPLAY)

static func _apply_font(n: Control, display: bool) -> void:
	_fonts()
	var f: Font = _f_disp if display else _f_sans
	if f != null:
		n.add_theme_font_override("font", f)

# layered premium background: gradient + radial glow + vignette (no art)
static func screen() -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, T.BG_TOP); g.set_color(1, T.BG_BOT)
	grad.gradient = g
	grad.fill = GradientTexture2D.FILL_LINEAR
	grad.fill_from = Vector2(0.5, 0.0); grad.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.texture = grad
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	r.add_child(bg)
	var glow := GradientTexture2D.new()
	var gg := Gradient.new()
	gg.set_color(0, Color(T.ACCENT.r, T.ACCENT.g, T.ACCENT.b, 0.10))
	gg.set_color(1, Color(0,0,0,0))
	glow.gradient = gg
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.30); glow.fill_to = Vector2(1.05, 0.95)
	var gr := TextureRect.new()
	gr.texture = glow
	gr.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(gr)
	# self-animating enter (motion lives here — Hub.gd untouched)
	r.modulate = Color(1,1,1,0)
	var tw := r.create_tween()
	tw.tween_property(r, "modulate", Color(1,1,1,1), 0.18)
	return r
static func root() -> Control:
	return screen()  # back-compat alias so existing Faces calls upgrade for free

static func _stylebox(bg: Color, border: Color, bw: int, rad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.shadow_color = Color(0,0,0,0.45)
	sb.shadow_size = 10
	return sb

static func panel(parent: Control, x: int, y: int, w: int, h: int, raised := false) -> Panel:
	var p := Panel.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.add_theme_stylebox_override("panel", _stylebox(T.PANEL_2 if raised else T.PANEL, T.STROKE, 1, T.RADIUS))
	parent.add_child(p)
	return p

static func label(parent: Control, text: String, x: int, y: int, size: int, col: Color, w := 0) -> Label:
	var l := Label.new()
	l.text = Loc.t(text)
	_apply_font(l, size >= T.TITLE)            # titles/display use the display face
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.position = Vector2(x, y)
	if w > 0:
		l.size = Vector2(w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

static func btn(parent: Control, text: String, x: int, y: int, w: int, h: int, cb: Callable, sel := false) -> Button:
	var b := Button.new()
	b.text = Loc.t(text)
	_apply_font(b, false)
	b.add_theme_font_size_override("font_size", T.BODY)
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	var base := _stylebox(T.PANEL_SEL if sel else T.PANEL_2, T.ACCENT if sel else T.STROKE, 2 if sel else 1, T.RADIUS)
	var hover := _stylebox(T.PANEL_SEL, T.ACCENT, 2, T.RADIUS)
	var press := _stylebox(T.ACCENT_SOFT, T.ACCENT, 2, T.RADIUS)
	var dis := _stylebox(T.PANEL, T.STROKE, 1, T.RADIUS)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", T.TEXT)
	b.add_theme_color_override("font_color_disabled", T.FAINT)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

static func bar(parent: Control, x: int, y: int, w: int, frac: float, col: Color) -> void:
	var track := Panel.new()
	track.position = Vector2(x, y); track.size = Vector2(w, 30)
	track.add_theme_stylebox_override("panel", _stylebox(T.PANEL, T.STROKE, 1, 15))
	parent.add_child(track)
	var fillw := int(clamp(frac, 0.0, 1.0) * w)
	if fillw > 0:
		var fill := Panel.new()
		fill.position = Vector2(x, y); fill.size = Vector2(fillw, 30)
		fill.add_theme_stylebox_override("panel", _stylebox(col, col, 0, 15))
		parent.add_child(fill)

static func navbar(parent: Control) -> Panel:
	var p := Panel.new()
	p.position = Vector2(0, T.REF_H - T.NAV_H)
	p.size = Vector2(T.REF_W, T.NAV_H)
	p.add_theme_stylebox_override("panel", _stylebox(T.PANEL_2, T.STROKE, 1, 0))
	parent.add_child(p)
	return p
```
Notes: keep `root()` as an alias of `screen()` so all existing `UiKit.root(...)`-style usage in Faces upgrades automatically. Keep `label`/`btn` signatures byte-identical so Faces compiles unchanged after this task. If Godot 4.6 rejects `add_theme_font_override("font", f)` for `Label`/`Button` use the correct 4.6 theme item name (`"font"` is correct for both in 4.6) — adjust only if a real error. `create_tween()` on a Control is valid in 4.6.

- [ ] **Step 4: Verify (Task 1 — Faces.gd NOT yet modified; it must still compile & run via the upgraded primitives):**
  - `cd Godot && godot --headless --quit` → exit 0, NO parse/script errors (Hub→Faces.build→UiKit all resolve; new tokens/primitives compile).
  - `cd Godot && godot --headless --script res://tests/run_tests.gd` → `RAN 59 tests, 0 failures`, exit 0.
  - `cd Godot && godot --headless --script res://ui_smoke.gd` → `HUB SMOKE OK day=2 dossier=3 reads=3`, exit 0.
  - `cd Godot && godot --headless --script res://play.gd` → exit 0 coherent.
  - VISUAL-ONLY guard: `git diff --stat 4e02f52..HEAD -- Godot/core Godot/tests Godot/play.gd Godot/project.godot Godot/ui/Loc.gd Godot/ui/Hub.gd Godot/scenes Godot/ui_smoke.gd` → EMPTY. `git diff --stat 4e02f52..HEAD` → only `Godot/ui/Theme.gd`, `Godot/ui/UiKit.gd`, `Godot/assets/fonts/*`.
- [ ] **Step 5: Commit**
```bash
git add Godot/ui/Theme.gd Godot/ui/UiKit.gd Godot/assets/fonts
git commit -m "feat(hunting-ui): visual tokens + fonts + layered UiKit base

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Faces composition pass — apply surface/typography system to all 6 faces + overlays

**Files:** Modify `Godot/ui/Faces.gd` only.

- [ ] **Step 1:** For EACH `Hub.F.*` arm + the settle/season/future overlays + `_hud` + `_nav` in `Godot/ui/Faces.gd`, apply the system **without changing content, copy (Loc keys), callbacks, layout coordinates' intent, or the `match`/state logic**:
  - Replace the `UiKit.root()` call (start of `build`) with `UiKit.screen()` (layered bg + enter animation). (If it already calls `UiKit.root()`, that now aliases `screen()` — but switch to `screen()` explicitly for clarity.)
  - Wrap each visually-grouped block (e.g. a section's labels+buttons) in a `UiKit.panel(r, x, y, w, h)` placed BEHIND those children (add the panel first, then the labels/buttons on top at the same coords) so content sits on real surfaces with depth. Group: SELF (build/persona/outfit/workout lists), SOCIAL (post block, read block), PARTY (map / first-eye / rounds), DATING (book rows), CARDS (3 sections), ASSETS (assets/liabilities/net-worth), overlays. Keep existing child coordinates; just add a sized panel behind each group.
  - Titles: keep `UiKit.label(..., T.TITLE, T.ACCENT)` (now auto-uses the display font). Promote the single most important number per face to `T.DISPLAY` where natural (e.g. ASSETS NET WORTH, FUTURE result) — copy unchanged.
  - `_hud`: render as a clean ribbon — put a `UiKit.panel` strip behind it; the energy bar via `UiKit.bar(...)` (replace the hand-rolled ColorRect bar) using `frac = energy/16.0`, `T.ACCENT`.
  - `_nav`: put `UiKit.navbar(r)` behind the 6 tab buttons; keep the buttons + `go_face` callbacks + selected highlight exactly.
  - HOME face: add a centered **heroine emblem** — a code-gen composition (e.g. a `Panel` framed vignette + a large `T.DISPLAY` monogram/initial or a simple geometric figure drawn via a few `Panel`/`ColorRect` shapes + the persona name) as the visual centre, replacing the plain text block's prominence. No male art. Keep the existing stat/subtitle text (Loc unchanged) below it.
  - Do NOT add/alter Loc keys (no `Loc.gd` change). Do NOT change any `h.act_*`/`h.ui[...]`/`h.flow.*` call. Per-iteration capture + bracket Variant access preserved.
- [ ] **Step 2: Verify** — same 4 runtime gates as Task 1 Step 4 (boot 0, 59 tests 0-fail, ui_smoke `HUB SMOKE OK day=2 dossier=3 reads=3`, play 0). VISUAL-ONLY guard: `git diff --stat 4e02f52..HEAD -- Godot/core Godot/tests Godot/play.gd Godot/project.godot Godot/ui/Loc.gd Godot/ui/Hub.gd Godot/scenes Godot/ui_smoke.gd` → EMPTY; this task's diff (`git diff --stat <task1-sha>..HEAD`) = ONLY `Godot/ui/Faces.gd`.
- [ ] **Step 3: Windowed sanity** — `cd Godot && timeout 12 godot --path . res://scenes/Game.tscn ; echo "rc=$?"` — confirm it opens and renders the HOME screen without script errors in the log (rc may be 124 from timeout-kill of a healthy window, OR 0; the pass condition is: no parse/script ERROR lines in output and the window/scene initialized — quote the log tail). This is best-effort visual sanity; the authoritative regression gate is the headless suite + smoke.
- [ ] **Step 4: Commit**
```bash
git add Godot/ui/Faces.gd
git commit -m "feat(hunting-ui): apply premium surface/type system across all faces

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Final verification + screenshot guidance + README + push-ready

**Files:** Modify `Godot/README.md`; Create `Godot/screenshot.gd` (best-effort offscreen capture helper, optional run).

- [ ] **Step 1: Screenshot helper** — create `Godot/screenshot.gd` (`extends SceneTree`): instantiate `res://scenes/Game.tscn`, deferred + `await process_frame` ×3 (let the enter-tween settle), then `get_root().get_texture().get_image().save_png("res://reskin_home.png")`, print the saved path, `quit(0)`. Run `cd Godot && godot --path . res://screenshot.gd` (NOT `--headless` — needs a rendering server; on macOS desktop this opens briefly). If it produces a non-trivial PNG, report its path/size so the user can view `Godot/reskin_home.png`. If the environment can't render (headless-only/no display → blank or error), do NOT fail — report that visual confirmation requires the user to run `godot --path . res://scenes/Game.tscn` locally. `screenshot.gd` is a dev helper (committed; harmless, not in TESTS).
- [ ] **Step 2: Full regression gate** — `cd Godot && godot --headless --script res://tests/run_tests.gd` → `RAN 59 tests, 0 failures` exit 0; `... res://ui_smoke.gd` → `HUB SMOKE OK day=2 dossier=3 reads=3` exit 0; `godot --headless --quit` exit 0; `... res://play.gd` exit 0 coherent. VISUAL-ONLY whole-Plan-E guard: `git diff --stat 4e02f52..HEAD -- Godot/core Godot/tests Godot/play.gd Godot/project.godot Godot/ui/Loc.gd Godot/ui/Hub.gd Godot/scenes Godot/ui_smoke.gd` → EMPTY (Hub logic, engine, Loc, project, scene, smoke all untouched across ALL of Plan E); `git diff --stat 4e02f52..HEAD` → only `Theme.gd`, `UiKit.gd`, `Faces.gd`, `assets/fonts/*`, `README.md`, `screenshot.gd`.
- [ ] **Step 3: README** — append a "Visual re-skin (Plan E)" note: premium layered look (depth + font pair + surface system), code-gen no-art, soul unchanged (cold-premium/anti-otome/she-centre); to view: `godot --path . res://scenes/Game.tscn`; `godot --path . res://screenshot.gd` writes `reskin_home.png`. Note the user will iterate the design further.
- [ ] **Step 4: Commit**
```bash
git add Godot/README.md Godot/screenshot.gd
git commit -m "feat(hunting-ui): screenshot helper + reskin docs

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (plan author)

**Spec/intent coverage:** font pair (biggest premium lever) + 3-layer depth bg + token-driven surface/spacing + restyled components + Tween enter motion (in UiKit-returned root, Hub untouched) + per-face panel/typography pass + HOME heroine emblem (she-centre, no male art) — Tasks 1–2. Honest ceiling stated (code-gen, no illustration). Soul preserved: cold-premium palette, single champagne accent, anti-otome, defensive copy (Loc unchanged). User-iterates-later acknowledged.

**Placeholder scan:** complete Theme + UiKit code; Faces pass is a precise transform of an existing file via the new primitive API (content/Loc/callbacks/coords-intent unchanged) — not vague. Font fetch has an explicit graceful-fallback path so the plan is executable offline.

**Type consistency:** `UiKit.root()` aliases `screen()` and `label`/`btn` signatures kept byte-identical → Faces compiles unchanged after Task 1; new `panel/navbar/bar/screen` are additive. `T.*` keeps every existing const name (re-valued only) so no Faces ref breaks. Motion via `create_tween()` on the returned root (Hub.gd byte-unchanged).

**Visual-only invariant:** every task diff-guards engine/tests/play.gd/project.godot/Loc.gd/Hub.gd/scenes/ui_smoke EMPTY; regression proven by the unchanged 59 tests + the unchanged `ui_smoke` (same hub-driven night, `HUB SMOKE OK day=2 dossier=3 reads=3`) staying green — the re-skin cannot alter behavior.

**Scope:** one cohesive visual-layer plan, 3 tasks; first strong pass, user iterates after.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-05-17-hunting-plan-e-visual-reskin.md`. Subagent-driven: Task 1 (tokens+fonts+UiKit base) spec+quality review; Tasks 2–3 lighter combined. Proceed with Task 1 unless redirected.
