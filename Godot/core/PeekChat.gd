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
