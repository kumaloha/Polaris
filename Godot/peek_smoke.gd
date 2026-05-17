extends SceneTree
const Content := preload("res://core/Content.gd")
const PeekChat := preload("res://core/PeekChat.gd")

func _man(id: String) -> Dictionary:
	for m in Content.men():
		if m["id"] == id:
			return m
	return {}

func _show(id: String) -> void:
	var r: Dictionary = PeekChat.peek(_man(id))
	print("── 开天眼 · %s ──" % str(r["name"]))
	print("   他对你演的样子: %s" % str(r["surface_claim"]))
	print("   他跟别人怎么说:")
	for line in r["others_chat"]:
		print("     → (%s) %s" % [str(line["to"]), str(line["text"])])
	print("")

func _initialize() -> void:
	# evan: sweet to her, hollow to everyone (痛). leo: posturing to her, real offstage (爽).
	_show("evan")
	_show("leo")
	_show("adrian")
	print("PEEK SMOKE OK men=%d" % Content.men().size())
	quit(0)
