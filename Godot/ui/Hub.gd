extends Node
const SeasonFlow := preload("res://core/SeasonFlow.gd")
const Faces := preload("res://ui/Faces.gd")
const T := preload("res://ui/Theme.gd")
const UiKit := preload("res://ui/UiKit.gd")

enum F { HOME, SELF, SOCIAL, PARTY, DATING, CARDS, ASSETS }

var flow
var face: int = F.HOME
var ui: Dictionary = {}
var enc = null
var party_log: Array = []
var future_payload: Array = []
var night_open: bool = false
var overlay: String = ""
var _layer: CanvasLayer

func _ready() -> void:
	flow = SeasonFlow.new()
	_layer = CanvasLayer.new()
	add_child(_layer)
	_render()

func go_face(f: int) -> void:
	face = f
	overlay = ""
	_render()

func _render() -> void:
	for c in _layer.get_children():
		c.queue_free()
	_layer.add_child(Faces.build(self))

func ensure_night() -> void:
	if not night_open:
		flow.begin_night(ui.get("self_invest", "solo_reset"), ui.get("persona", "rare_girl"))
		if ui.has("outfit"): flow.apply_outfit(ui["outfit"])
		if ui.has("workout"): flow.apply_workout(ui["workout"])
		night_open = true

func act_choose_party(pid: String) -> void:
	ensure_night()
	if flow.choose_party(pid):
		_render()

func act_enter_party(primary_id: String) -> void:
	flow.set_primary(primary_id)
	enc = flow.start_party()
	party_log = []
	if enc == null: return
	_render()

func act_party(action: String) -> void:
	if enc == null or enc.finished: return
	var r = enc.act(action)
	flow.record_party_action(action)
	if r.has("tell") and r.tell != "": party_log.append(r.tell)
	if enc.finished:
		go_face(F.DATING)
	else:
		_render()

func act_after(decisions: Dictionary) -> void:
	future_payload = flow.resolve_after(decisions)
	var fin = flow.finish_night()
	party_log = fin.log
	night_open = false
	enc = null
	if not future_payload.is_empty():
		ui["show_future"] = true
		_render()
	else:
		_post_night()

func dismiss_future() -> void:
	ui["show_future"] = false
	_post_night()

func _post_night() -> void:
	ui.erase("after")
	ui.erase("_chose_party")
	# show_future is already false here (dismiss_future clears it before calling us,
	# and act_after only sets it when future_payload is non-empty and never reaches
	# _post_night in that branch); erase for hygiene in case of edge paths.
	ui.erase("show_future")
	if flow.at_week_boundary():
		ui["settle"] = flow.settle()
		if flow.at_season_boundary():
			ui["close"] = flow.close_season()
			overlay = "season"
		else:
			overlay = "settle"
	if overlay == "":
		go_face(F.HOME)
	else:
		_render()

func dismiss_overlay() -> void:
	overlay = ""
	go_face(F.HOME)
