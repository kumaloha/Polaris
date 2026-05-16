extends SceneTree
const SeasonFlow := preload("res://core/SeasonFlow.gd")
func _initialize() -> void:
	var f = SeasonFlow.new()
	# A scripted demo season: chase Evan (bad), make Adrian earn it (good), observe Leo.
	var script := [
		{"self_invest": "evidence_study", "primary": "evan",
			"party_actions": ["engage", "engage", "engage", "engage", "engage"],
			"after": {"evan": "date"}},
		{"self_invest": "solo_reset", "primary": "adrian",
			"party_actions": ["engage", "boundary", "social_proof", "boundary", "exit"],
			"after": {"adrian": "date"}},
		{"self_invest": "work_win", "primary": "leo",
			"party_actions": ["engage", "boundary", "exit", "exit", "exit"],
			"after": {"leo": "observe"}},
	]
	var night := 0
	for wk in range(f.weeks_per_season):
		for n in range(f.nights_per_week):
			var choices = script[night % script.size()]
			var r = f.step_night(choices)
			night += 1
			print("--- Night %d (S%d W%d) ---" % [night, f.state.season, f.state.week])
			for line in r.log:
				if line != "": print("  " + line)
			print("  net_worth=%d energy=%d control=%d debts=%d insolvent=%s" % [
				r["snapshot"]["net_worth"], r["snapshot"]["energy"], r["snapshot"]["control"],
				r["snapshot"]["debts"], str(r.insolvent)])
		var s = f.settle()
		print("=== Week settle: net_worth=%d keyframes=%d debts=%d ===" % [
			s["net_worth"], s["keyframes"], s["debts"]])
	var carried = f.close_season()
	print("=== Season close. Carried dossier=%d position=%d ===" % [
		carried["dossier"].size(), carried["position"]])
	quit(0)
