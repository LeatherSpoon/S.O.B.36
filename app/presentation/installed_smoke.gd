extends Reference
# Opt-in diagnostic for a packaged build. Called only with --sob-smoke.
static func run(scene):
	yield(scene.get_tree(), "idle_frame")
	if scene.game == null or scene.story_view.backdrop == null:
		printerr("Installed smoke failed: project/art unavailable")
		scene.get_tree().quit(1)
		return
	for action in ["move_right", "confirm", "move_right", "confirm"]:
		scene.handle_action(action)
	var before = JSON.print(scene.game.to_data(), "", true)
	scene.handle_action("save_campaign")
	scene.handle_action("confirm")
	scene.handle_action("load_campaign")
	if JSON.print(scene.game.to_data(), "", true) != before:
		printerr("Installed smoke failed: save/load")
		scene.get_tree().quit(1)
		return
	scene.open_collection()
	if scene.gallery.entries.empty():
		printerr("Installed smoke failed: no local scans")
		scene.get_tree().quit(1)
		return
	print("Installed smoke passed; local images: ", scene.gallery.entries.size())
	scene.get_tree().quit(0)
