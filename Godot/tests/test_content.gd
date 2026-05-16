extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")
func test_three_archetypes() -> void:
	var men = Content.men()
	eq(men.size(), 3, "3 base men")
	var types := []
	for m in men: types.append(m.hidden_type)
	ok("resource" in types and "high_sugar" in types and "growth" in types, "all archetypes")
func test_man_has_surface_and_chat() -> void:
	for m in Content.men():
		ok(m.has("surface"), "has surface signals")
		ok(m.chat.size() >= 2, "has chat evidence")
func test_personas_gfs_parties() -> void:
	eq(Content.personas().size(), 3, "3 personas")
	eq(Content.girlfriends().size(), 3, "3 gfs")
	ok(Content.parties().size() >= 3, ">=3 parties tiered")
	eq(Content.self_investments().size(), 4, "4 self-invest cards")
