extends RefCounted
class_name FirstEye
static func intel(man: Dictionary, dossier: Array, bought_depth: int) -> Dictionary:
	var tag := ""
	for d in dossier:
		if d.get("hidden_type", "") == man["hidden_type"]:
			tag = "Pings like a type you've burned before."
			break
	var clues := []
	clues.append(man["risk"])
	for i in range(bought_depth):
		var chat: Array = man["chat"]
		clues.append(chat[i % chat.size()]["text"])
	return {
		"claims": {"surface": man["surface"], "name": man["name"]},
		"dossier_tag": tag,
		"clues": clues,
		"depth": bought_depth,
	}
