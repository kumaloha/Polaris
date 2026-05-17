extends "res://tests/test_base.gd"
const Content := preload("res://core/Content.gd")

func _man(id: String) -> Dictionary:
	for m in Content.men():
		if m["id"] == id:
			return m
	return {}

func test_every_man_has_others_chat() -> void:
	var men: Array = Content.men()
	ok(men.size() >= 3, "≥3 men")
	for m in men:
		ok(m.has("others_chat"), "man %s has others_chat" % str(m.get("id", "?")))
		var oc: Array = m["others_chat"]
		ok(oc.size() >= 2, "others_chat for %s has ≥2 lines" % str(m["id"]))
		for line in oc:
			ok(line.has("to") and line.has("text"), "line shape {to,text} for %s" % str(m["id"]))
			ok(str(line["to"]) != "you" and str(line["to"]) != "him", "line is to OTHERS, not her/him echo (%s)" % str(m["id"]))
			ok(str(line["text"]).strip_edges() != "", "non-empty line text for %s" % str(m["id"]))

func test_disguised_men_have_revealing_chat() -> void:
	var disguised := 0
	for m in Content.men():
		if m["surface"] != m["hidden_type"]:
			disguised += 1
			ok((m["others_chat"] as Array).size() >= 2, "disguised man %s has a real others_chat" % str(m["id"]))
	ok(disguised >= 2, "≥2 disguised men exist (surface != hidden_type)")

func test_known_reveal_cases_present() -> void:
	var evan := _man("evan")
	var leo := _man("leo")
	eq(evan["hidden_type"], "high_sugar", "evan truth = high_sugar")
	eq(evan["surface"], "growth", "evan performs growth to her (disguised)")
	ok((evan["others_chat"] as Array).size() >= 2, "evan others_chat exists")
	eq(leo["hidden_type"], "growth", "leo truth = growth")
	eq(leo["surface"], "false_alpha", "leo postures false_alpha to her (disguised)")
	ok((leo["others_chat"] as Array).size() >= 2, "leo others_chat exists")
