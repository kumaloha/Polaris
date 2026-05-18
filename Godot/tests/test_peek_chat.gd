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

const PeekChat := preload("res://core/PeekChat.gd")

func test_peek_shape_and_surface() -> void:
	var r: Dictionary = PeekChat.peek(_man("evan"))
	ok(r.has("name") and r.has("surface_claim") and r.has("others_chat"), "peek shape {name,surface_claim,others_chat}")
	eq(r["name"], "Evan", "peek carries the name")
	eq(r["surface_claim"], "growth", "peek shows the surface he performs to her, for contrast")
	ok((r["others_chat"] as Array).size() >= 2, "peek carries the chats-with-others")

func test_peek_never_reveals_truth() -> void:
	for id in ["adrian", "evan", "leo"]:
		var r: Dictionary = PeekChat.peek(_man(id))
		ok(not r.has("hidden_type"), "peek never exposes the truth for %s (clue, not answer)" % id)
		ok(not r.has("risk"), "peek does not leak the engine risk label for %s" % id)

func test_peek_is_deterministic() -> void:
	var a: Dictionary = PeekChat.peek(_man("leo"))
	var b: Dictionary = PeekChat.peek(_man("leo"))
	eq(str(a), str(b), "peek is deterministic — same man, identical record")

func test_peek_handles_empty_man() -> void:
	var r: Dictionary = PeekChat.peek({})
	ok(r.has("others_chat"), "empty man still returns a well-formed record")
	eq((r["others_chat"] as Array).size(), 0, "empty man -> empty others_chat, no crash")

func test_peek_others_chat_is_a_distinct_copy() -> void:
	var m: Dictionary = _man("evan")
	var r: Dictionary = PeekChat.peek(m)
	ok(not is_same(r["others_chat"], m["others_chat"]), "peek returns a copy, not a reference into Content data")
	eq(str(r["others_chat"]), str(m["others_chat"]), "the copy is value-equal to the source")

func test_peek_carries_to_you_chat() -> void:
	var r: Dictionary = PeekChat.peek(_man("evan"))
	ok(r.has("to_you_chat"), "peek carries to_you_chat (his performance face)")
	var ty: Array = r["to_you_chat"]
	ok(ty.size() >= 1, "evan to_you_chat non-empty")
	for line in ty:
		ok(line.has("from") and line.has("text"), "to_you line shape {from,text}")

func test_peek_to_you_is_a_distinct_copy() -> void:
	var m: Dictionary = _man("leo")
	var r: Dictionary = PeekChat.peek(m)
	ok(not is_same(r["to_you_chat"], m["chat"]), "to_you_chat is a copy, not a ref into Content")
	eq(str(r["to_you_chat"]), str(m["chat"]), "the copy is value-equal to the source")

func test_peek_with_to_you_still_hides_truth() -> void:
	for id in ["adrian", "evan", "leo"]:
		var r: Dictionary = PeekChat.peek(_man(id))
		ok(not r.has("hidden_type"), "still no truth for %s after adding to_you_chat" % id)
		ok(not r.has("risk"), "still no risk label for %s" % id)
	var e: Dictionary = PeekChat.peek({})
	eq((e["to_you_chat"] as Array).size(), 0, "empty man -> empty to_you_chat, no crash")

func test_corpus_expanded_and_shaped() -> void:
	var men: Array = Content.men()
	ge(men.size(), 12, "≥12 men in the corpus")
	var disguised := 0
	for m in men:
		ok(m.has("chat") and (m["chat"] as Array).size() >= 2, "%s chat ≥2" % str(m["id"]))
		ok(m.has("others_chat") and (m["others_chat"] as Array).size() >= 3, "%s others_chat ≥3" % str(m["id"]))
		ok(m.has("hidden_type") and m["hidden_type"] in ["resource", "high_sugar", "growth"], "%s hidden_type is locked archetype" % str(m["id"]))
		ok(m.has("surface") and m.has("risk") and m.has("opportunity") and m.has("energy_cost"), "%s full schema" % str(m["id"]))
		if m["surface"] != m["hidden_type"]:
			disguised += 1
	ge(disguised, 5, "≥5 disguised men (surface != hidden_type)")
	# New men are written richer (4-6 lines); the original 3 stay as shipped (3).
	var new_ids := ["marcus", "daniel", "theo", "julian", "wes", "cole", "sam", "hugo", "rhys"]
	for nid in new_ids:
		var nm: Dictionary = _man(nid)
		ok(not nm.is_empty(), "new man %s exists" % nid)
		ge((nm["others_chat"] as Array).size(), 4, "%s others_chat ≥4 (new men written厚)" % nid)

func test_new_reveal_cases_present() -> void:
	var marcus := _man("marcus")
	var daniel := _man("daniel")
	var julian := _man("julian")
	eq(marcus["hidden_type"], "high_sugar", "marcus truth = high_sugar")
	eq(marcus["surface"], "resource", "marcus performs resource (痛: hollow provider)")
	eq(daniel["hidden_type"], "resource", "daniel truth = resource")
	eq(daniel["surface"], "high_sugar", "daniel performs high_sugar (爽: dismissable but real)")
	eq(julian["hidden_type"], "high_sugar", "julian truth = high_sugar")
	eq(julian["surface"], "growth", "julian performs growth (痛: performative depth)")
	for id in ["marcus", "daniel", "julian"]:
		var r: Dictionary = PeekChat.peek(_man(id))
		ok(not r.has("hidden_type"), "%s peek still hides truth" % id)

func test_corpus_size_locked() -> void:
	ge(Content.men().size(), 36, "≥36 men after 12→36 expansion")
	# Spot-check new ids across both disguise directions + a consistent one.
	var owen := _man("owen")
	var caleb := _man("caleb")
	var arlo := _man("arlo")
	eq(owen["hidden_type"], "high_sugar", "owen truth = high_sugar (痛: sugar→resource)")
	eq(owen["surface"], "resource", "owen performs resource")
	eq(caleb["hidden_type"], "resource", "caleb truth = resource (爽: resource→sugar)")
	eq(caleb["surface"], "high_sugar", "caleb performs high_sugar")
	eq(arlo["hidden_type"], "resource", "arlo truth = resource (consistent 好)")
	eq(arlo["surface"], "resource", "arlo consistent (surface == truth)")
	for nid in ["owen", "caleb", "arlo"]:
		var r: Dictionary = PeekChat.peek(_man(nid))
		ok(not r.has("hidden_type"), "%s peek still hides truth" % nid)

func test_threads_you_first_and_count() -> void:
	var m: Dictionary = _man("marcus")
	var th: Array = PeekChat.threads(m)
	eq(th.size(), (m["others_chat"] as Array).size() + 1, "threads = others_chat + 你 thread")
	eq(th[0]["contact"], "你", "thread[0] 是 你 thread")
	eq(th[0]["kind"], "you", "thread[0] kind = you")
	eq(str(th[0]["msgs"]), str(m["chat"]), "你 thread 携带他对你的 chat")

func test_threads_others_are_single_him_bubbles() -> void:
	var m: Dictionary = _man("evan")
	var th: Array = PeekChat.threads(m)
	ok(th.size() >= 2, "evan 有别人 thread")
	for i in range(1, th.size()):
		var t: Dictionary = th[i]
		eq(t["kind"], "other", "非 0 号是别人 thread")
		eq((t["msgs"] as Array).size(), 1, "别人 thread 现状单气泡")
		eq((t["msgs"][0] as Dictionary)["from"], "him", "别人气泡来自 him")

func test_threads_never_reveal_truth() -> void:
	for id in ["adrian", "evan", "marcus", "owen", "caleb"]:
		var th: Array = PeekChat.threads(_man(id))
		for t in th:
			ok(not (t as Dictionary).has("hidden_type"), "thread 无 hidden_type (%s)" % id)
			for msg in ((t as Dictionary)["msgs"] as Array):
				ok(not (msg as Dictionary).has("hidden_type"), "msg 无 hidden_type (%s)" % id)

func test_threads_copy_not_ref() -> void:
	var m: Dictionary = _man("leo")
	var th: Array = PeekChat.threads(m)
	ok(not is_same(th[0]["msgs"], m["chat"]), "你 thread msgs 是拷贝,不是 Content 引用")

func test_threads_empty_man_safe() -> void:
	var th: Array = PeekChat.threads({})
	eq(th.size(), 1, "空 man → 只剩 你 thread")
	eq((th[0]["msgs"] as Array).size(), 0, "空 man → 你 msgs 空,不崩")
