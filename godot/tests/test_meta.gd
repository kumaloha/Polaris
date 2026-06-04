extends "res://tests/test_lib.gd"

const Enchants := preload("res://meta/enchants.gd")
const Gacha := preload("res://meta/gacha.gd")
const MetaState := preload("res://meta/meta_state.gd")

func _blank_page() -> Array:
	var p := []
	p.resize(9)
	p.fill("")
	return p

func test_enchants_aggregate() -> void:
	var page := ["moves", "moves", "moves", "moves", "moves", "moves", "opening", "opening", "opening"]
	var a := Enchants.aggregate(page)
	assert_eq(a["extra_moves"], 2, "6 move slots -> +2 (capped)")
	assert_eq(a["opening_special"], 1, "3 opening -> line special (1)")
	var b := Enchants.aggregate(_blank_page())
	assert_eq(b["extra_moves"], 0, "blank -> 0 extra moves")
	assert_eq(b["score_mult"], 1.0, "blank -> 1.0 score mult")

func test_enchants_opening_colorbomb() -> void:
	var page := _blank_page()
	for i in 6:
		page[i] = "opening"
	assert_eq(Enchants.aggregate(page)["opening_special"], 4, "6 opening -> colorbomb (4)")

func test_gacha_first_pull_borrower() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var r := Gacha.pull({}, rng, true)
	assert_eq(r["id"], "borrrower", "first pull guaranteed borrow")
	assert_false(r["dupe"], "not owned yet")
	var r2 := Gacha.pull({"borrrower": 1}, rng, false)
	assert_true(r2["id"] in Gacha.POOL, "non-first pull from pool")

func test_meta_state_gacha_and_bank() -> void:
	var ms := MetaState.new()
	ms.bank_result({"won": true, "score": 500, "fragments": 10})
	assert_eq(ms.fragments, 10, "fragments banked")
	assert_eq(ms.crystals, 1, "won -> +1 crystal")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var res := ms.do_gacha(rng)
	assert_eq(res["id"], "borrrower", "first gacha -> borrow")
	assert_eq(ms.crystals, 0, "crystal consumed")
	assert_true(ms.owned.has("borrrower"), "owns borrow now")
	assert_true(ms.do_gacha(rng).has("error"), "no crystal -> error")

func test_meta_state_loadout() -> void:
	var ms := MetaState.new()
	ms.owned["foresight"] = 3
	ms.equipped_skill = "foresight"
	ms.enchant_page[0] = "moves"
	ms.enchant_page[1] = "moves"
	ms.enchant_page[2] = "moves"
	var lo := ms.loadout()
	assert_eq(lo["skill"], "foresight", "loadout skill")
	assert_eq(lo["skill_level"], 3, "loadout level from owned")
	assert_eq(lo["extra_moves"], 1, "3 move slots -> +1")

func test_meta_state_save_load() -> void:
	var ms := MetaState.new()
	ms.fragments = 99
	ms.owned["timerewind"] = 2
	ms.equipped_skill = "timerewind"
	ms.enchant_page[0] = "score"
	ms.save()
	var ms2 := MetaState.new()
	ms2.load_state()
	assert_eq(ms2.fragments, 99, "fragments persisted")
	assert_eq(int(ms2.owned.get("timerewind", 0)), 2, "owned persisted")
	assert_eq(ms2.equipped_skill, "timerewind", "equipped persisted")
	assert_eq(ms2.enchant_page[0], "score", "enchant page persisted")
