extends RefCounted
# 关卡库读取（05 数据契约）：读 C++ 离线导出的 JSON → 关卡 dict 列表 / Board。
# 运行时只读库摆盘、不跑算法（合 05 §一·五）。两端 RNG 不同序列，故读「确切盘面」而非凭 seed 重生成。

const Board := preload("res://core/board.gd")

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
	var b := Board.new(w, h, sp, int(d.get("target_score", 0)), int(d.get("move_limit", 25)), int(d.get("seed", 0)), [], objs, jelly_layer, coat_layer)
	if d.has("init_board"):
		b.grid = _int_grid(d["init_board"])   # 用导出盘面覆盖随机生成的 make_board 结果
		b.fx = b._blank_fx()
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
