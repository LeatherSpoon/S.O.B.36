extends SceneTree
var failures = []

func check(value, label):
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func _init():
	call_deferred("run")

func run():
	var old_root = OS.get_environment("SOB_SOURCE_ROOT")
	var source = "res://.local/visual-scene-fixture"
	for category in ["Alpha", "Beta"]:
		for i in range(2):
			var path = source + "/" + category + "/" + str(i) + ".png"
			Directory.new().make_dir_recursive(path.get_base_dir())
			var image = Image.new()
			image.create(40, 60, false, Image.FORMAT_RGB8)
			image.fill(Color(0.6, 0.3 + i * 0.2, 0.1))
			image.save_png(path)
	OS.set_environment("SOB_SOURCE_ROOT", ProjectSettings.globalize_path(source))
	var scene = load("res://app/presentation/main.tscn").instance()
	get_root().add_child(scene)
	yield(self, "idle_frame")
	var snapshot = JSON.print(scene.game.to_data(), "", true)
	scene.handle_action("collection")
	check(scene.gallery.visible and scene.gallery.entries.size() == 4, "collection opens with all local image records")
	scene.handle_action("move_right")
	check(scene.gallery.selection == 1, "next card navigation")
	scene.handle_action("move_down")
	check(scene.gallery.category == 1 and scene.gallery.selection == 0, "next deck navigation")
	scene.handle_action("confirm")
	check(scene.gallery.zoom == 2.0, "card zoom")
	scene.handle_action("move_up")
	check(scene.gallery.pan.y > 0, "zoomed card panning")
	scene.handle_action("cancel")
	check(scene.gallery.zoom == 1.0 and scene.gallery.visible, "cancel fits card before closing")
	scene.handle_action("cancel")
	check(not scene.gallery.visible, "cancel returns to adventure")
	check(snapshot == JSON.print(scene.game.to_data(), "", true), "browsing scans never advances game or RNG")
	scene.handle_action("move_right")
	scene.handle_action("confirm")
	scene.handle_action("move_right")
	scene.handle_action("confirm")
	var data = JSON.print(scene.game.to_data(), "", true)
	var rng = scene.game.rng.state
	for _i in range(12):
		scene.motion.advance(0.1)
	check(data == JSON.print(scene.game.to_data(), "", true) and rng == scene.game.rng.state, "visual animation never changes saved state")
	scene.handle_action("reduced_motion")
	check(scene.motion.reduced and scene.motion.impact == 0, "reduced motion control")
	# Invalid cosmetic configuration must not grant access outside the scan root.
	scene.assets.roles["hero"] = {"path": "../outside.png"}
	check(scene.assets.role_texture(scene.art, "hero") == null, "private visual roles cannot escape source root")
	scene.assets.roles["hero"] = null
	check(scene.assets.role_texture(scene.art, "hero") == null, "invalid role value falls back to placeholder")
	var texture = scene.art.get_texture(scene.gallery.entries[0].path)
	check(scene.assets.region("hero", texture) == Rect2(Vector2.ZERO, texture.get_size()), "invalid role region uses full image")
	scene.queue_free()
	yield(self, "idle_frame")
	OS.set_environment("SOB_SOURCE_ROOT", old_root)
	print("Visual scene failures: ", failures.size())
	quit(0 if failures.empty() else 1)
