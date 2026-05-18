extends RefCounted
class_name PeekChat

# 派对前开天眼 · 看他跟别人的聊记。
# Returns ONLY what the player is allowed to see: who he is by name,
# the surface he performs to her (for the gut-punch contrast), and his
# chats with OTHER people. The truth (hidden_type) is deliberately NOT
# returned — the reveal is the player's to read. Deterministic, pure.
# NOTE: uses defensive man.get(...) (unlike FirstEye's direct man["..."])
# on purpose — peek must survive partial/empty input (see test_peek_handles_empty_man).
static func peek(man: Dictionary) -> Dictionary:
	# Shallow copies: never hand a consumer a reference into Content's data
	# (a future UI may sort/annotate these in place). Lines are value dicts.
	var others: Array = (man.get("others_chat", []) as Array).duplicate()
	var to_you: Array = (man.get("chat", []) as Array).duplicate()
	return {
		"name": str(man.get("name", "")),
		"surface_claim": str(man.get("surface", "")),
		"to_you_chat": to_you,
		"others_chat": others,
	}

# 派对收件箱视图：他对你那段(chat)成第 0 个「你」thread,他对每个别人
# 那条各成一个单气泡 thread。仍绝不含 hidden_type。确定性,纯。
# others_chat[0] 是最狠一句 → 它天然落在别人区第一行。空/缺字段安全。
static func threads(man: Dictionary) -> Array:
	var out: Array = []
	var to_you: Array = (man.get("chat", []) as Array).duplicate(true)
	out.append({"contact": "你", "kind": "you", "msgs": to_you})
	for ln in (man.get("others_chat", []) as Array):
		var d: Dictionary = ln
		out.append({
			"contact": str(d.get("to", "")),
			"kind": "other",
			"msgs": [{"from": "him", "text": str(d.get("text", ""))}],
		})
	return out
