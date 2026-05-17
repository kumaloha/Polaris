extends SceneTree

const Hub := preload("res://ui/Hub.gd")

func _initialize() -> void:
	var scene = load("res://scenes/Game.tscn").instantiate()
	get_root().add_child(scene)
	_run.call_deferred(scene)

func _run(h) -> void:
	await self.process_frame
	h.ui["self_invest"] = "solo_reset"
	h.ui["persona"] = "rare_girl"
	h.go_face(Hub.F.SOCIAL)
	h.act_read_signal("high_sugar", "high_sugar")          # correct read → dossier archive
	h.act_compose_post("scarce")                            # opens night + sets inbound pool
	h.go_face(Hub.F.PARTY)
	h.ui["_chose_party"] = true
	h.act_choose_party("rooftop")
	var men = h.party_face_men()
	assert(men.size() >= 1, "funnel produced an inbound pool")
	var first_id = str(men[0]["id"])
	h.act_enter_party(first_id)
	while h.enc != null and not h.enc.finished:
		h.act_party("boundary")
	h.ui["after"] = { first_id: "date" }
	h.act_after(h.ui["after"])
	if h.ui.get("show_future", false):
		h.dismiss_future()
	assert(h.flow.state.day >= 2, "a full night completed via the hub")
	assert(h.flow.state.dossier.size() >= 1, "comment-read archived a dossier entry")
	print("HUB SMOKE OK day=%d dossier=%d face=%d" % [h.flow.state.day, h.flow.state.dossier.size(), h.face])
	quit(0)
