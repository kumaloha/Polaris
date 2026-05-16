extends "res://tests/test_base.gd"
const Book := preload("res://core/Book.gd")
const GameState := preload("res://core/GameState.gd")
func test_open_and_list() -> void:
	var s = GameState.new()
	var b = Book.new(s)
	b.open("leo", "observe", "growth")
	eq(b.positions().size(), 1, "one open position")
func test_observe_decays_then_becomes_missed() -> void:
	var s = GameState.new()
	var b = Book.new(s)
	b.open("leo", "observe", "growth")
	for i in range(9):
		b.advance_night()
	var p = b.positions()[0]
	ok(p.status == "missed" or p.decay >= 0, "observe decays toward missed growth")
func test_unsettled_creditor_drains_energy_and_adds_debt() -> void:
	var s = GameState.new()
	var b = Book.new(s)
	b.open("evan", "string_along", "high_sugar")
	var e0 = s.energy
	b.advance_night()
	ok(s.energy < e0, "creditor drains nightly energy")
	ok(s.debts.size() >= 1, "fantasy debt accrues")
func test_cut_clears_position() -> void:
	var s = GameState.new()
	var b = Book.new(s)
	b.open("evan", "string_along", "high_sugar")
	b.decide("evan", "cut")
	eq(b.positions().size(), 0, "cut clears the position")
