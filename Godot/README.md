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

## Play with UI (interactive)

Open the project in Godot 4.6 and press Play, or:
`godot --path . res://scenes/Game.tscn`

Click through: Ready Room → Girlfriend Night → First Eye → Party (5 rounds) → After Party → Future Eye → repeat. Headless UI smoke: `godot --headless --script res://ui_smoke.gd`.
Visuals are a code-generated baseline (cold-premium, no art); to be re-skinned from a reference app later.

## Engine: social funnel + dossier (Plan A)

- `SeasonFlow.compose_post(posture)` — `posture ∈ {"scarce","validation"}`; reuses ControlEngine (scarce=earn, validation=chase). Returns `{inbound_men, gf_leads, control_delta, standing_delta, mirror}`. Intra-night, one post/night, never advances the day.
- `SeasonFlow.inbound_men()` — the funnel-produced men pool for the night.
- `SeasonFlow.read_signal(hidden_type, guess)` — high-frequency read; correct guess archives a `state.dossier` entry (judgment equity → net worth).
- `SeasonFlow.apply_outfit(id)` / `apply_workout(id)` — apply `Content.outfits()/workouts()` effects.
- Numbers live in `data/tuning.json` `social` / `dossier`.

## Play with UI — Hub (current)

The linear flow was replaced by a portrait hub. Open the project in Godot 4.6 and Play, or:
`godot --path . res://scenes/Game.tscn`

Home shows your avatar/stats + energy bar (opportunity cost). Bottom nav: 自我提升 / 社媒 / 派对 / 约会 / 集卡 / 资产. Soft daily cycle: pick build in 自我提升 → enter 派对 (begins the night) → 派对 rounds → 约会 resolves it (Future Eye) → settlement; build is locked for the night once you enter 派对. 社媒 / 集卡 / 资产 are Plan C stubs. Headless hub smoke: `godot --headless --script res://ui_smoke.gd`.

## Full night flow (Plan C)

A night now flows: 自我提升 (set build) → 社交媒体 (post: 克制/博认同 → who slides in; read DMs → dossier) → 派对 (read the people your post attracted) → 约会 (resolve; Future Eye) → settlement. 集卡 browses dossier / girlfriend network / earned keyframes; 资产清单 shows the net-worth balance sheet. Headless: `godot --headless --script res://ui_smoke.gd` (drives a full night incl. the post).

## Read-practice (Plan D)

The 社交媒体 comment/DM read is now a varied deterministic sample set (8 DMs incl. disguised tells where the surface vibe ≠ the real type). Each correct read archives the dossier (judgment equity → net worth). Capped at `social.read_cap` (default 3) reads/night; resets each night.

## Visual re-skin (Plan E)

Premium layered look: 3-layer gradient background + radial glow, a display/sans font pair (Cinzel display / Montserrat body), a token-driven surface system (rounded panels with stroke + soft shadow), restyled buttons and energy bar, a gated 0.18 s enter-fade (plays only on real face/overlay transitions, not on every tap).

Per-face panel + typography pass across all 6 faces, _hud ribbon, and navbar. A code-gen **HOME heroine emblem** (layered panels + shapes + display monogram + persona name) — she-at-the-centre, no illustration or art assets, no male art.

Soul unchanged: cold-premium palette, single champagne accent, anti-otome, defensive copy. No Loc/gameplay/engine change — the unmodified 59 tests + `ui_smoke` prove behavior is identical.

To view: `godot --path . res://scenes/Game.tscn`. To capture: `godot --path . res://screenshot.gd` writes `reskin_home.png` (needs a display; not `--headless`).

Note: this is a first strong pass; the design will be iterated further.
