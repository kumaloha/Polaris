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
	h.go_face(Hub.F.PARTY)
	h.ui["_chose_party"] = true
	h.act_choose_party("rooftop")
	h.act_enter_party("adrian")
	while h.enc != null and not h.enc.finished:
		h.act_party("boundary")
	h.ui["after"] = {"adrian": "date"}
	h.act_after(h.ui.get("after", {}))
	if h.ui.get("show_future", false):
		h.dismiss_future()
	assert(h.flow.state.day >= 2, "a full night completed via the hub")
	print("HUB SMOKE OK day=%d face=%d night_open=%s" % [h.flow.state.day, h.face, str(h.night_open)])
	quit(0)
