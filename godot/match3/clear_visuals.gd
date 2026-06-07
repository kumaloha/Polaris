extends RefCounted
## 清除表现规划：只决定被特效波及的格子应该染成哪个触发宝石 species。
## 实际清除范围仍由 match_engine 决定，这里不扩张几何。

const ME := preload("res://core/match_engine.gd")

const COLORBOMB_CONVERT_TIME := 0.24
const COLORBOMB_CONVERT_HOLD := 0.26


static func special_clear_species_overrides(grid: Array, fx: Array, to_clear: Array, spawn_set: Dictionary = {}, override_fx: Dictionary = {}) -> Dictionary:
	var species := {}
	for p in to_clear:
		if spawn_set.has(p):
			continue
		var kind: int = int(override_fx.get(p, fx[p.y][p.x]))
		if kind != ME.SP_LINE_H and kind != ME.SP_LINE_V and kind != ME.SP_BOMB:
			continue
		var sp: int = grid[p.y][p.x]
		if sp < 0:
			continue
		for e in ME.special_effect_cells(grid, p, kind, sp):
			if not species.has(e):
				species[e] = sp
	return species


static func colorbomb_combo_has_conversion_phase(virtual_fx: Dictionary) -> bool:
	return not virtual_fx.is_empty()


static func colorbomb_virtual_conversion_delay(virtual_fx: Dictionary) -> float:
	if not colorbomb_combo_has_conversion_phase(virtual_fx):
		return 0.0
	return COLORBOMB_CONVERT_TIME + COLORBOMB_CONVERT_HOLD
