extends "res://tests/test_base.gd"
const PE := preload("res://core/PartyEncounter.gd")
const Content := preload("res://core/Content.gd")
func _man(id):
	for m in Content.men():
		if m.id == id: return m
	return {}
func test_rounds_and_finish() -> void:
	var e = PE.new(_man("adrian"))
	ok(not e.finished, "starts unfinished")
	var rounds = e.total_rounds
	for i in range(rounds):
		e.act("exit")
	ok(e.finished, "finished after all rounds")
	eq(e.act("engage"), {}, "no acts after finish")
func test_boundary_on_resource_yields_concrete_tell() -> void:
	var e = PE.new(_man("adrian"))
	var r = e.act("boundary")
	ok(r.tell.length() > 0, "boundary produces a tell")
	ok(r.evidence == "resource" or r.evidence == "uncertain", "evidence points toward type")
func test_boundary_on_sugar_exposes() -> void:
	var e = PE.new(_man("evan"))
	var r = e.act("boundary")
	eq(r.evidence, "high_sugar", "sugar man fails the boundary -> exposed tell")
func test_social_proof_backfires_on_growth() -> void:
	var e = PE.new(_man("leo"))
	var r = e.act("social_proof")
	eq(r.evidence, "growth", "ego-sensitive withdraws -> growth tell")
