extends RefCounted
# 关卡库读取（05 数据契约）：读 C++ 离线导出的 JSON → 关卡 dict 列表 / Board。
# 运行时只读库摆盘、不跑算法（合 05 §一·五）。两端 RNG 不同序列，故读「确切盘面」而非凭 seed 重生成。

const Board := preload("res://core/board.gd")
const ME := preload("res://core/match_engine.gd")
const DEFAULT_LEVELS_PATH := "res://levels.json"

# 从启动参数选择关卡库。默认不变；传入：
#   --levels res://levels.generated.json
#   --levels=res://levels.generated.json
# 可切到新生成的关卡包。只返回路径，不做存在性校验，便于调用方统一 fallback/log。
static func levels_path_from_args(args: Array, default_path: String = DEFAULT_LEVELS_PATH) -> String:
	for i in args.size():
		var arg := String(args[i])
		var raw := ""
		if arg == "--levels" or arg == "--level-library":
			if i + 1 >= args.size():
				return default_path
			raw = String(args[i + 1])
		elif arg.begins_with("--levels="):
			raw = arg.substr("--levels=".length())
		elif arg.begins_with("--level-library="):
			raw = arg.substr("--level-library=".length())
		raw = raw.strip_edges()
		if not raw.is_empty():
			return raw
	return default_path

# 解析 JSON 文本 → Array[Dictionary]（每项是一关）。失败返回 []。
static func load_string(json_text: String) -> Array:
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("levels"):
		return []
	var lvls = parsed["levels"]
	return lvls if typeof(lvls) == TYPE_ARRAY else []

# 从文件读关卡库。失败返回 []。
static func load_file(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text()
	f.close()
	return load_string(text)

# 把一关 dict（05 契约）摆成可玩 Board：用导出的确切盘面，不凭 seed 重新随机生成。
static func to_board(d: Dictionary) -> Board:
	var w: int = int(d.get("w", d.get("width", 8)))
	var h: int = int(d.get("h", d.get("height", 8)))
	var sp := []
	for s in d.get("species", [0, 1, 2, 3, 4]):
		sp.append(int(s))
	var objs := _norm_objectives(d.get("objectives", []))
	var jelly_layer := _int_grid(d.get("jelly", []))
	var coat_layer := _int_grid(d.get("coat", []))
	var choco_layer := _int_grid(d.get("choco", []))   # 巧克力层(若库带)；当前关卡库多为空
	var ing_layer := _int_grid(d.get("ing", []))       # 运料关原料层(若库带)；非运料关为空
	var exit_cols := _int_arr(d.get("exits", []))      # 运料关出口列号数组(若库带)；非运料关为空
	var bomb_layer := _int_grid(d.get("bomb", []))     # 炸弹关倒计时层(若库带)；非炸弹关为空。bomb[y][x]=剩余步数
	var cannon_layer := _int_grid(d.get("cannon", []))   # 糖果炮层(若库带)；非糖果炮关为空。cannon[y][x]=1产糖/2产原料
	var popcorn_layer := _int_grid(d.get("popcorn", [])) # 爆米花层(若库带)；非爆米花关为空。popcorn[y][x]=剩余命中数
	var cake_layer := _int_grid(d.get("cake", []))       # 蛋糕层(若库带)；非蛋糕关为空。cake[y][x]=剩余血量
	var mystery_layer := _int_grid(d.get("mystery", [])) # 神秘糖层(若库带)；非神秘糖关为空。mystery[y][x]=1神秘糖
	var fx_layer := _int_grid(d.get("fx", []))           # 预置特殊宝石/奖励资源层；为空则运行时补空层
	var init_grid := _int_grid(d.get("init_board", []))
	# 从盘面提取墙掩码(WALL=-2)，让 start() 重开本关时也保留异形结构(否则 mask 空→重生成无墙盘，墙丢失)
	var mask := _wall_mask_from(init_grid)
	var b := Board.new(w, h, sp, int(d.get("target_score", 0)), int(d.get("move_limit", 25)), int(d.get("seed", 0)), mask, objs, jelly_layer, coat_layer, choco_layer, ing_layer, exit_cols, bomb_layer, cannon_layer, popcorn_layer, cake_layer, mystery_layer)
	if not init_grid.is_empty():
		b.grid = init_grid   # 用导出盘面覆盖随机生成的 make_board 结果
		b.fx = fx_layer if not fx_layer.is_empty() else b._blank_fx()
		ME.apply_blocker_occupancy(b.grid, b.fx, b.coat)
		ME.apply_ingredient_occupancy(b.grid, b.fx, b.ing)
	if bool(d.get("is_scrolling", false)):   # 滚动/挖矿关：补充从预设 feed 出，挖穿通关
		b.is_scrolling = true
		var fd := []
		for col in d.get("feed", []):
			var q := []
			for v in col:
				q.append(int(v))
			fd.append(q)
		b.feed = fd
	return b

# JSON 数字解析成 float；grid 值转回 int。
static func _int_grid(a) -> Array:
	if typeof(a) != TYPE_ARRAY:
		return []
	var out := []
	for row in a:
		var r := []
		for v in row:
			r.append(int(v))
		out.append(r)
	return out

# 一维数字数组 → int 数组（运料关出口列号 exits 用）。
static func _int_arr(a) -> Array:
	if typeof(a) != TYPE_ARRAY:
		return []
	var out := []
	for v in a:
		out.append(int(v))
	return out

# 从盘面提取墙掩码：WALL(-2) → true，其余 false。供 Board.start() 重生时保留异形结构。
static func _wall_mask_from(grid: Array) -> Array:
	var out := []
	for row in grid:
		var r := []
		for v in row:
			r.append(int(v) == -2)
		out.append(r)
	return out

# objectives 的 species 作为 collected 的 dict key 必须是 int，否则查不到。
static func _norm_objectives(objs) -> Array:
	var out := []
	if typeof(objs) != TYPE_ARRAY:
		return []
	for o in objs:
		out.append({
			"type": String(o.get("type", "SCORE")),
			"species": int(o.get("species", -1)),
			"target": int(o.get("target", 0)),
		})
	return out
