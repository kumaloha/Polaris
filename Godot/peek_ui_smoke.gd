extends SceneTree
const Content := preload("res://core/Content.gd")
const Spotter := preload("res://core/Spotter.gd")

func _initialize() -> void:
	var scene = load("res://scenes/Peek.tscn").instantiate()
	get_root().add_child(scene)
	_run.call_deferred(scene)

func _walk_has_hidden_type(n) -> bool:
	if n is Label and ("hidden_type" in n.text or "high_sugar" in n.text):
		return true
	for c in n.get_children():
		if _walk_has_hidden_type(c):
			return true
	return false

func _run(p) -> void:
	await self.process_frame
	if p._layer == null or p._layer.get_child_count() <= 0:
		print("SPOT SMOKE FAIL: round built no nodes"); quit(1); return
	if p.state != "intel":
		print("SPOT SMOKE FAIL: did not open on intel"); quit(1); return
	var total: int = Content.men().size()
	var m0: Dictionary = p._man_now()
	var truth0: bool = Spotter.is_scumbag(m0)
	p.reveal_face()
	await self.process_frame
	if p.state != "face":
		print("SPOT SMOKE FAIL: intel->face failed"); quit(1); return
	p.judge(truth0, "expose")
	await self.process_frame
	if p.state != "ending":
		print("SPOT SMOKE FAIL: judge->ending failed"); quit(1); return
	if p.correct != 1:
		print("SPOT SMOKE FAIL: correct guess not tallied"); quit(1); return
	if _walk_has_hidden_type(p._layer):
		print("SPOT SMOKE FAIL: UI leaked hidden_type/high_sugar"); quit(1); return
	p.next_round()
	await self.process_frame
	if p.state != "intel" or p.idx != 1 or p.seen != 1:
		print("SPOT SMOKE FAIL: next_round did not advance"); quit(1); return
	print("SPOT SMOKE OK men=%d" % total)
	quit(0)
