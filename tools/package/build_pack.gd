extends SceneTree
# Source allowlist: never enumerate the scan library or ignored private directories.
var count = 0

func _init():
	var destination = OS.get_environment("SOB_PACK_OUTPUT")
	if destination.empty():
		printerr("Set SOB_PACK_OUTPUT to an output .pck path")
		quit(1)
		return
	var paths = ["res://project.godot"]
	for folder in ["res://app", "res://core", "res://content/loaders", "res://content/packs/placeholder"]:
		collect(folder, paths)
	paths.sort()
	Directory.new().make_dir_recursive(destination.get_base_dir())
	var packer = PCKPacker.new()
	if packer.pck_start(destination) != OK:
		quit(1)
		return
	for path in paths:
		if packer.add_file(path, path) != OK:
			printerr("Cannot pack: ", path)
			quit(1)
			return
		count += 1
	if packer.flush() != OK:
		quit(1)
		return
	print("Packed ", count, " public application files.")
	quit(0)

func collect(path, result):
	var dir = Directory.new()
	if dir.open(path) != OK:
		return
	dir.list_dir_begin(true, true)
	var name = dir.get_next()
	while name != "":
		var child = path.plus_file(name)
		if dir.current_is_dir():
			collect(child, result)
		elif name.get_extension().to_lower() in ["gd", "tscn", "json", "png", "ttf", "txt"]:
			result.append(child)
		name = dir.get_next()
	dir.list_dir_end()
