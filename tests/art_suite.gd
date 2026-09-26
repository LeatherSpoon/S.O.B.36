extends Reference

func _write_image(path, color = Color(0.7, 0.3, 0.1, 1)):
	Directory.new().make_dir_recursive(path.get_base_dir())
	var image = Image.new()
	image.create(24, 12, false, Image.FORMAT_RGBA8)
	image.fill(color)
	assert(image.save_png(path) == OK)

func run(t):
	var script_path = "res://app/presentation/art_library.gd"
	if not File.new().file_exists(script_path):
		t.check(false, "private art library exists")
		return true
	var Art = load(script_path)
	var art = Art.new()
	var root = ProjectSettings.globalize_path("res://.local/art-tests/library-%s" % OS.get_ticks_usec())
	_write_image(root + "/Zed/Zebra.png")
	_write_image(root + "/Alpha/Amber.PNG")
	_write_image(root + "/Alpha/Blue.png")
	_write_image(root + "/Alpha/ignored.bmp")
	_write_image(root + "-outside/Other.png")
	if OS.get_name() == "Windows":
		var script = "$ErrorActionPreference='Stop'; New-Item -ItemType Junction -Path '" + root.replace("'", "''") + "/Linked' -Target '" + root.replace("'", "''") + "-outside' | Out-Null"
		t.check(OS.execute("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", script], true, [], false, false) == 0, "synthetic junction fixture created")
	elif OS.get_name() in ["X11", "OSX", "Server"]:
		t.check(OS.execute("ln", ["-s", root + "-outside", root + "/Linked"], true, [], false, false) == 0, "synthetic symlink fixture created")
	var file = File.new()
	assert(file.open(root + "/Alpha/note.txt", File.WRITE) == OK)
	file.store_string("synthetic fixture")
	file.close()
	var game = load("res://core/campaign/game_state.gd").new()
	game.start(8675309)
	var before = game.to_data()
	var records = art.discover(root)
	t.check(records.size() == 3, "art discovery includes only supported image extensions")
	if records.size() == 3:
		t.check(records[0].name == "Amber" and records[1].name == "Blue" and records[2].name == "Zebra", "art discovery sorted by relative path")
		t.check(records[0].category == "Alpha" and records[2].category == "Zed", "art categories use parent folders")
		t.check(records[0].path.is_abs_path(), "art discovery returns absolute paths")
	t.check(art.get_texture(false) == null, "false image path fails gracefully")
	t.check(art.get_texture(root + "/Alpha/missing.png") == null, "missing image fails gracefully")
	t.check(art.get_texture(root + "-outside/Other.png") == null, "sibling prefix cannot escape art root")
	t.check(art.get_texture(root + "/../library-outside/Other.png") == null, "parent traversal cannot escape art root")
	t.check(art.get_texture(root + "/Linked/Other.png") == null, "linked image cannot escape art root")
	t.check(art.get_texture(root + "/Alpha/note.txt") == null, "unsupported image path rejected")
	var hash_before = file.get_sha256(root + "/Alpha/Blue.png")
	var texture = art.get_texture(root + "/Alpha/Blue.png", 8)
	t.check(texture != null, "private image loads without Godot import")
	if texture != null:
		t.check(texture.get_width() == 8 and texture.get_height() == 4, "texture resizing preserves aspect ratio in memory")
		t.check(art.get_texture(root + "/Alpha/Blue.png", 8) == texture, "repeat texture load uses cached object")
	t.check(file.get_sha256(root + "/Alpha/Blue.png") == hash_before, "texture loading preserves source bytes")
	for index in range(10):
		_write_image(root + "/Cache/image_%02d.png" % index)
	art.discover(root)
	for index in range(9):
		t.check(art.get_texture(root + "/Cache/image_%02d.png" % index, 8) != null, "synthetic cache image loads")
	t.check(art.cache_size() == 8, "texture cache bounded to eight entries")
	var recent = art.get_texture(root + "/Cache/image_01.png", 8)
	art.get_texture(root + "/Cache/image_09.png", 8)
	t.check(art.get_texture(root + "/Cache/image_01.png", 8) == recent, "recently used texture survives cache eviction")
	t.check(t.equal(game.to_data(), before), "art presentation leaves campaign and deterministic RNG unchanged")
	t.check(art.discover(root + "/missing-library").empty(), "missing art root produces empty library")
	t.check(art.cache_size() == 0 and art.root == "", "missing root clears old textures and root")
	t.check(art.get_texture(root + "/Alpha/Blue.png") == null, "old texture unavailable after missing root")
	t.check(art.discover(root + "/Linked").empty(), "linked root is rejected")
	var old_source = OS.get_environment("SOB_SOURCE_ROOT")
	OS.set_environment("SOB_SOURCE_ROOT", root)
	t.check(art.source_root() == root, "environment source root takes precedence")
	OS.set_environment("SOB_SOURCE_ROOT", old_source)
	return true
