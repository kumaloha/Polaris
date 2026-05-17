extends RefCounted
class_name PeekChat

# 派对前开天眼 · 看他跟别人的聊记。
# Returns ONLY what the player is allowed to see: who he is by name,
# the surface he performs to her (for the gut-punch contrast), and his
# chats with OTHER people. The truth (hidden_type) is deliberately NOT
# returned — the reveal is the player's to read. Deterministic, pure.
static func peek(man: Dictionary) -> Dictionary:
	var others: Array = man.get("others_chat", [])
	return {
		"name": str(man.get("name", "")),
		"surface_claim": str(man.get("surface", "")),
		"others_chat": others,
	}
