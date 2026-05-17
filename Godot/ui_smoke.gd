extends SceneTree

const Hub := preload("res://ui/Hub.gd")
const Content := preload("res://core/Content.gd")

func _initialize() -> void:
	var scene = load("res://scenes/Game.tscn").instantiate()
	get_root().add_child(scene)
	_run.call_deferred(scene)

func _run(h) -> void:
	await self.process_frame
	h.ui["self_invest"] = "solo_reset"
	h.ui["persona"] = "rare_girl"
	h.go_face(Hub.F.SOCIAL)

	# --- CAP-EXERCISING MULTI-READ (before post/party) ---
	var cap: int = h._tuning_read_cap()        # = 3
	var d0: int = int(h.flow.state.dossier.size())

	# Loop cap+1 times: on the (cap+1)th call the hub gate makes it a no-op
	for _i in range(cap + 1):
		var samples = Content.dm_signals()
		var truth = str(samples[int(h.flow.state.dossier.size()) % samples.size()]["hidden_type"])
		h.act_read_signal(truth, truth)         # correct guess → archives dossier entry

	assert(int(h.flow.state.dossier.size()) == d0 + cap,
		"exactly cap correct reads archived; the over-cap read was a no-op")
	assert(int(h.ui.get("reads_tonight", 0)) == cap,
		"reads_tonight capped at cap, never exceeds")

	# Snapshot reads_tonight before _post_night erases it at end-of-night
	var reads_snapshot: int = int(h.ui.get("reads_tonight", 0))

	# --- FULL NIGHT DRIVE (post → party → date → settle) ---
	h.act_compose_post("scarce")                # opens night + sets inbound pool
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
	print("HUB SMOKE OK day=%d dossier=%d reads=%d" % [h.flow.state.day, h.flow.state.dossier.size(), reads_snapshot])
	quit(0)
