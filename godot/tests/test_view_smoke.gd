extends "res://tests/test_lib.gd"
# test_view_smoke.gd — 表现层(game.gd) 冒烟测试（headless 友好）。
# 目的：① preload 即编译 game.gd，捕获语法错误；
#       ② 校验 4 个 demo 关都能拼出合法 Board（构造不报错、维度对、目标/层正确）；
#       ③ 校验目标 HUD 文案按 objectives 渲染、空目标回退分数。
# 只调 game.gd 里不依赖场景节点的纯函数（_demo_level/_demo_*_layer/_layer_at/_objectives_text）。
# 实例化为裸 Node（不入树→不触发 _ready），用完即 free()，避免退出时 CanvasItem RID 泄漏告警。

const Game := preload("res://view/game.gd")  # 编译期即验证 game.gd 无语法错误
const Board := preload("res://core/board.gd")

func test_view_script_loads() -> void:
	var v: Game = Game.new()
	assert_true(v != null, "game.gd instantiates (compiles clean)")
	assert_eq(v.DEMO_COUNT, 5, "five demo levels declared")
	v.free()

func test_all_demo_levels_build_valid_board() -> void:
	var v: Game = Game.new()
	for idx in v.DEMO_COUNT:
		var lvl: Dictionary = v._demo_level(idx)
		assert_true(lvl.has("name") and not String(lvl["name"]).is_empty(), "level %d has a name" % idx)
		# 用关卡参数真正构造一局 Board —— 任一构造期报错都会在此暴露（含运料层 ing/exits）。
		var b := Board.new(v.W, v.H, v.SPECIES, lvl["target"], lvl["moves"], 99,
				lvl["mask"], lvl["objs"], lvl["jelly"], lvl["coat"], [], lvl.get("ing", []), lvl.get("exits", []))
		assert_eq(b.grid.size(), v.H, "level %d board height" % idx)
		assert_eq(b.grid[0].size(), v.W, "level %d board width" % idx)
		assert_false(b.is_over(), "level %d not already over at start" % idx)
	v.free()

func test_demo_levels_cover_all_objective_types() -> void:
	var v: Game = Game.new()
	var types := {}
	for idx in v.DEMO_COUNT:
		var lvl: Dictionary = v._demo_level(idx)
		if lvl["objs"].is_empty():
			types["SCORE_FALLBACK"] = true  # 现状分数关：objectives 空 → 旧式判定
		for o in lvl["objs"]:
			types[o["type"]] = true
	assert_true(types.has("SCORE_FALLBACK"), "has the legacy score level (empty objectives)")
	assert_true(types.has("COLLECT"), "has a COLLECT level")
	assert_true(types.has("CLEAR_JELLY"), "has a CLEAR_JELLY level")
	assert_true(types.has("CLEAR_BLOCKER"), "has a CLEAR_BLOCKER level")
	assert_true(types.has("COLLECT_INGREDIENT"), "has a COLLECT_INGREDIENT (运料) level")
	v.free()

func test_demo_jelly_layer_shape() -> void:
	var v: Game = Game.new()
	var j: Array = v._demo_jelly_layer()
	assert_eq(j.size(), v.H, "jelly layer height")
	assert_eq(j[0].size(), v.W, "jelly layer width")
	assert_eq(j[2][2], 1, "outer jelly ring is 1 layer")
	assert_eq(j[3][3], 2, "inner 2x2 jelly is 2 layers (multi-layer demo)")
	assert_eq(j[0][0], 0, "no jelly outside center region")
	v.free()

func test_demo_coat_layer_avoids_wall_corners() -> void:
	var v: Game = Game.new()
	var c: Array = v._demo_coat_layer()
	assert_eq(c.size(), v.H, "coat layer height")
	# 4 角是墙 → 不放锁（否则锁挂在不可动的墙上，玩家永远破不掉）。
	assert_eq(c[0][0], 0, "top-left corner has no coat (it's a wall)")
	assert_eq(c[0][v.W - 1], 0, "top-right corner has no coat")
	assert_eq(c[v.H - 1][0], 0, "bottom-left corner has no coat")
	assert_eq(c[v.H - 1][v.W - 1], 0, "bottom-right corner has no coat")
	assert_eq(c[0][3], 1, "top edge (non-corner) is locked 1 layer")
	assert_eq(c[2][2], 2, "interior accent lock is 2 layers")
	v.free()

func test_layer_at_handles_empty_layer() -> void:
	var v: Game = Game.new()
	# 该关无 jelly/coat 时层数组为空 —— 读取须安全返回 0，不可越界。
	assert_eq(v._layer_at([], 3, 4), 0, "empty layer reads 0")
	var c: Array = v._demo_coat_layer()
	assert_eq(v._layer_at(c, 3, 0), 1, "populated layer reads actual value")
	v.free()

func test_objectives_text_empty_falls_back_to_score() -> void:
	var v: Game = Game.new()
	# objectives 为空 → 回退旧式"分数 X / TARGET"。
	v.board = Board.new(v.W, v.H, v.SPECIES, v.TARGET, v.MOVES, 1)
	var txt: String = v._objectives_text()
	assert_true(txt.contains("分数"), "fallback shows score label")
	assert_true(txt.contains(str(v.TARGET)), "fallback shows target")
	v.free()

func test_objectives_text_renders_each_type() -> void:
	var v: Game = Game.new()
	var objs := [
		{"type": "COLLECT", "species": 0, "target": 10},
		{"type": "CLEAR_JELLY", "species": -1, "target": 8},
		{"type": "CLEAR_BLOCKER", "species": -1, "target": 5},
		{"type": "COLLECT_INGREDIENT", "species": -1, "target": 4},
		{"type": "SCORE", "species": -1, "target": 2000},
	]
	v.board = Board.new(v.W, v.H, v.SPECIES, 2000, 30, 1, [], objs)
	var txt: String = v._objectives_text()
	assert_true(txt.contains("收集"), "COLLECT label present")
	assert_true(txt.contains(v.SYMBOLS[0]), "COLLECT shows species symbol")
	assert_true(txt.contains("果冻"), "CLEAR_JELLY label present")
	assert_true(txt.contains("解锁"), "CLEAR_BLOCKER label present")
	assert_true(txt.contains("运料"), "COLLECT_INGREDIENT label present")
	assert_true(txt.contains("分数"), "SCORE label present")
	assert_true(txt.contains("10"), "COLLECT target shown")
	assert_true(txt.contains("8"), "CLEAR_JELLY target shown")
	v.free()

func test_demo_ingredient_layer_shape() -> void:
	var v: Game = Game.new()
	var g: Array = v._demo_ingredient_layer()
	assert_eq(g.size(), v.H, "ingredient layer height")
	assert_eq(g[0].size(), v.W, "ingredient layer width")
	assert_eq(g[0][1], 1, "top-row ingredient placed at col 1")
	assert_eq(g[0][7], 1, "top-row ingredient placed at col 7")
	assert_eq(g[0][0], 0, "no ingredient where not seeded")
	var total := 0
	for row in g:
		for val in row:
			total += val
	assert_eq(total, 4, "exactly 4 ingredients (matches target)")
	v.free()
