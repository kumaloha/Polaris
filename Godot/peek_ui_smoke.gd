extends SceneTree
const Content := preload("res://core/Content.gd")
const PeekChat := preload("res://core/PeekChat.gd")

func _initialize() -> void:
	var scene = load("res://scenes/Peek.tscn").instantiate()
	get_root().add_child(scene)
	_run.call_deferred(scene)

func _run(p) -> void:
	await self.process_frame
	if p._layer == null or p._layer.get_child_count() <= 0:
		print("PEEK UI SMOKE FAIL: list built no nodes")
		quit(1); return
	if p.state != "list":
		print("PEEK UI SMOKE FAIL: initial state not list")
		quit(1); return
	p.open_reveal("evan")
	await self.process_frame
	if p.state != "reveal" or p.sel_id != "evan":
		print("PEEK UI SMOKE FAIL: open_reveal did not switch")
		quit(1); return
	if p._layer.get_child_count() <= 0:
		print("PEEK UI SMOKE FAIL: reveal built no nodes")
		quit(1); return
	var pk: Dictionary = PeekChat.peek(p._man("evan"))
	if (pk["to_you_chat"] as Array).size() < 1 or (pk["others_chat"] as Array).size() < 1:
		print("PEEK UI SMOKE FAIL: peek data not wired")
		quit(1); return
	p.back_to_list()
	await self.process_frame
	if p.state != "list" or p.sel_id != "":
		print("PEEK UI SMOKE FAIL: back_to_list did not reset")
		quit(1); return
	print("PEEK UI SMOKE OK men=%d" % Content.men().size())
	quit(0)
