extends RefCounted
class_name SoftRuin
static func is_insolvent(state) -> bool:
	return state.net_worth() < 0
