extends RefCounted
class_name Girlfriends
const Tuning := preload("res://core/Tuning.gd")
const Content := preload("res://core/Content.gd")
var state
var _warmth: Dictionary = {}
func _init(game_state) -> void:
	state = game_state
	for g in Content.girlfriends():
		_warmth[g.id] = 0
func warmth(gf_id: String) -> int:
	return _warmth.get(gf_id, 0)
func adjust(gf_id: String, delta: int) -> void:
	_warmth[gf_id] = _warmth.get(gf_id, 0) + delta
func available_tier() -> int:
	var tier := 1
	for g in Content.girlfriends():
		var w: int = _warmth.get(g.id, 0)
		var need: int = Tuning.num("gates.tier%d_warmth" % g.tier, 0)
		if g.tier == 1 or w >= need:
			tier = max(tier, g.tier)
	return tier
