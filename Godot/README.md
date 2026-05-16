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
