extends Node
const SeasonFlow := preload("res://core/SeasonFlow.gd")
const Screens := preload("res://ui/Screens.gd")

enum S { READY, MAP, FIRST_EYE, PARTY, AFTER, FUTURE, WEEK, SEASON_END }

var flow
var screen: int = S.READY
var ui: Dictionary = {}
var enc = null
var party_log: Array = []
var future_payload: Array = []
var _layer: CanvasLayer

func _ready() -> void:
	flow = SeasonFlow.new()
	_layer = CanvasLayer.new()
	add_child(_layer)
	_render()

func go(next_screen: int) -> void:
	screen = next_screen
	_render()

func _render() -> void:
	for c in _layer.get_children():
		c.queue_free()
	_layer.add_child(Screens.build(self))

func act_begin_night() -> void:
	flow.begin_night(ui.get("self_invest", "solo_reset"), ui.get("persona", "rare_girl"))
	go(S.MAP)

func act_choose_party(pid: String) -> void:
	if flow.choose_party(pid):
		go(S.FIRST_EYE)

func act_enter_party(primary_id: String) -> void:
	flow.set_primary(primary_id)
	enc = flow.start_party()
	party_log = []
	if enc == null:
		return
	go(S.PARTY)

func act_party(action: String) -> void:
	if enc == null or enc.finished:
		return
	var r = enc.act(action)
	flow.record_party_action(action)
	if r.has("tell") and r.tell != "":
		party_log.append(r.tell)
	if enc.finished:
		go(S.AFTER)
	else:
		_render()

func act_after(decisions: Dictionary) -> void:
	future_payload = flow.resolve_after(decisions)
	var fin = flow.finish_night()
	party_log = fin.log
	if not future_payload.is_empty():
		go(S.FUTURE)
	else:
		_after_future()

func _after_future() -> void:
	if flow.at_week_boundary():
		ui["settle"] = flow.settle()
		if flow.at_season_boundary():
			ui["close"] = flow.close_season()
			go(S.SEASON_END)
		else:
			go(S.WEEK)
	else:
		go(S.READY)

func act_continue_from_future() -> void:
	_after_future()

func act_next_night() -> void:
	go(S.READY)
