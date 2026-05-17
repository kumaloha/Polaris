extends SceneTree

func _initialize() -> void:
	var scene = load("res://scenes/Game.tscn").instantiate()
	get_root().add_child(scene)
	_run.call_deferred(scene)

func _run(c) -> void:
	await self.process_frame
	c.ui["self_invest"] = "solo_reset"
	c.ui["persona"] = "rare_girl"
	c.act_begin_night()
	c.act_choose_party("rooftop")
	c.act_enter_party("adrian")
	while c.enc != null and not c.enc.finished:
		c.act_party("boundary")
	c.ui["after"] = {"adrian": "date"}
	c.act_after(c.ui["after"])
	c.act_continue_from_future()
	assert(c.flow.state.day >= 2, "a full night completed")
	print("UI SMOKE OK day=%d screen=%d" % [c.flow.state.day, c.screen])
	quit(0)
