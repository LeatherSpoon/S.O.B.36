extends SceneTree

func _init():
	var loader = load("res://content/loaders/pack_loader.gd").new()
	var root = OS.get_environment("SOB_PACK_ROOT")
	if root.empty():
		root = "res://content/packs"
	var selection = OS.get_environment("SOB_ENABLED_PACKS")
	var enabled = ["placeholder"] if selection.empty() else Array(selection.split(",", false))
	var result = loader.load_packs(root, enabled, OS.get_environment("SOB_EDITION_ID"))
	if not result.ok:
		printerr(result.error)
		quit(1)
		return
	print("Validated ", result.packs.size(), " pack(s), ", result.records.size(), " record(s).")
	quit(0)
