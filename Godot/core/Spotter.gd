extends RefCounted
class_name Spotter

# 鉴渣纯逻辑。high_sugar=渣;resource/growth=好。绝不向 UI 暴露 hidden_type。
static func is_scumbag(man: Dictionary) -> bool:
	return str(man.get("hidden_type", "")) == "high_sugar"

# (真相 × 选择) → Loc key。choice ∈ {"expose"(拆穿),"probe"(试探),"leave"(走开)}。
# 未知 choice 退化为 "leave" 行,绝不返回空。
static func ending_key(is_scum: bool, choice: String) -> String:
	var c := choice
	if c != "expose" and c != "probe" and c != "leave":
		c = "leave"
	var who := "SCUM" if is_scum else "GOOD"
	return "END_%s_%s" % [who, c.to_upper()]

# (读对? × 真相) → 裁定 Loc key。绝不空,4 档互异,纯,绝不向 UI 暴露真相。
static func verdict_key(was_right: bool, is_scum: bool) -> String:
	var r := "RIGHT" if was_right else "WRONG"
	var who := "SCUM" if is_scum else "GOOD"
	return "VERDICT_%s_%s" % [r, who]
