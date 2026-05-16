extends "res://tests/test_base.gd"
const CE := preload("res://core/ControlEngine.gd")
func test_classify() -> void:
	eq(CE.classify("engage"), "chase", "engage = chase")
	eq(CE.classify("boundary"), "earn", "boundary = earn")
	eq(CE.classify("exit"), "neutral", "exit = neutral")
func test_chase_raises_cheap_lowers_costly() -> void:
	var pos := {"cheap": 0, "costly": 0}
	var r = CE.resolve(pos, "engage")
	ok(r.cheap > 0, "chase raises cheap (sweet talk up)")
	ok(r.costly < 0, "chase lowers costly (concrete action down)")
	ok(r.control < 0, "chase costs control")
	ok(r.sign != "", "emits an ambiguous sign line")
func test_earn_raises_costly_and_control() -> void:
	var r = CE.resolve({"cheap": 0, "costly": 0}, "boundary")
	ok(r.costly > 0, "earn raises costly (he must produce)")
	ok(r.control > 0, "earn gains control")
