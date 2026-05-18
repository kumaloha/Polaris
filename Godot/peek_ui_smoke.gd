extends SceneTree
const Content := preload("res://core/Content.gd")
const Spotter := preload("res://core/Spotter.gd")
const PeekChat := preload("res://core/PeekChat.gd")

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
		print("SPOT SMOKE FAIL: built no nodes"); quit(1); return
	if p.state != "party":
		print("SPOT SMOKE FAIL: did not open on party"); quit(1); return
	var total: int = Content.men().size()
	if total < 36:
		print("SPOT SMOKE FAIL: corpus floor <36"); quit(1); return
	var m0: Dictionary = Content.men()[0]
	var truth0: bool = Spotter.is_scumbag(m0)
	var nthreads: int = PeekChat.threads(m0).size()
	if nthreads != (m0["others_chat"] as Array).size() + 1:
		print("SPOT SMOKE FAIL: threads != others+1"); quit(1); return
	p.open_inbox(0)
	await self.process_frame
	if p.state != "inbox":
		print("SPOT SMOKE FAIL: party->inbox failed"); quit(1); return
	p.open_thread(0)
	await self.process_frame
	if p.state != "thread":
		print("SPOT SMOKE FAIL: inbox->thread failed"); quit(1); return
	if _walk_has_hidden_type(p._layer):
		print("SPOT SMOKE FAIL: thread leaked hidden_type/high_sugar"); quit(1); return
	p.back()
	await self.process_frame
	if p.state != "inbox":
		print("SPOT SMOKE FAIL: thread->inbox back failed"); quit(1); return
	p.begin_judge()
	await self.process_frame
	if p.state != "judge":
		print("SPOT SMOKE FAIL: inbox->judge failed"); quit(1); return
	p.judge(truth0, "expose")
	await self.process_frame
	if p.state != "ending":
		print("SPOT SMOKE FAIL: judge->ending failed"); quit(1); return
	if p.correct != 1:
		print("SPOT SMOKE FAIL: correct not tallied"); quit(1); return
	if _walk_has_hidden_type(p._layer):
		print("SPOT SMOKE FAIL: ending leaked truth"); quit(1); return
	p.next_round()
	await self.process_frame
	if p.state != "party":
		print("SPOT SMOKE FAIL: next_round did not return to party"); quit(1); return
	var id0: String = str(m0.get("id", ""))
	if not p.judged.has(id0) or p.judged[id0] != true:
		print("SPOT SMOKE FAIL: man not marked judged-correct"); quit(1); return
	print("SPOT SMOKE OK men=%d threads0=%d" % [total, nthreads])
	quit(0)
