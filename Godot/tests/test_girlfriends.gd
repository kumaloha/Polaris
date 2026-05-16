extends "res://tests/test_base.gd"
const GF := preload("res://core/Girlfriends.gd")
const GameState := preload("res://core/GameState.gd")
func test_starts_tier1() -> void:
	var g = GF.new(GameState.new())
	eq(g.available_tier(), 1, "tier1 open by default")
func test_warmth_unlocks_higher_tier() -> void:
	var g = GF.new(GameState.new())
	g.adjust("claire", 3)
	eq(g.available_tier(), 2, "claire warmth opens tier 2")
func test_neglect_contracts_access() -> void:
	var g = GF.new(GameState.new())
	g.adjust("claire", 3)
	g.adjust("claire", -3)
	eq(g.available_tier(), 1, "lost warmth contracts back to tier 1")
