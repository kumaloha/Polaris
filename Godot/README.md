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
