extends SceneTree
var failures = []

func _init():
	call_deferred("run")

func check(condition, label):
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func press(scene, action):
	scene.handle_action(action)

func run():
	var packed = load("res://app/presentation/main.tscn")
	if packed == null:
		printerr("FAIL: playable scene missing")
		quit(1)
		return
	var scene = packed.instance()
	get_root().add_child(scene)
	yield(self, "idle_frame")
	check(scene.has_method("open_collection"), "collection viewer exists")
	check(get_root().size == Vector2(640, 480), "logical viewport is 640x480")
	check(scene.game.campaign.heroes[0].space_id == "first_0", "new campaign created")
	# Exercise the real input path, not only a domain API.
	var key = InputEventKey.new()
	key.scancode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	key.pressed = false
	Input.parse_input_event(key)
	yield(self, "idle_frame")
	check(scene.game.campaign.heroes[0].space_id == "first_1", "keyboard moves via input abstraction")
	var joy = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_0
	joy.pressed = true
	Input.parse_input_event(joy)
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	joy.pressed = false
	Input.parse_input_event(joy)
	yield(self, "idle_frame")
	check(scene.game.enemy.spawned, "gamepad confirm reveals and spawns")
	press(scene, "move_right")
	press(scene, "confirm")
	check(scene.game.phase == "combat", "engage through UI")
	scene.save_path = "res://.local/smoke_campaign.json"
	press(scene, "save_campaign")
	var saved = JSON.print(scene.game.to_data(), "", true)
	press(scene, "confirm")
	press(scene, "load_campaign")
	check(saved == JSON.print(scene.game.to_data(), "", true), "UI save/reload restores state")
	for _i in range(4):
		if scene.game.phase == "combat":
			press(scene, "confirm")
	check(scene.game.campaign.heroes[0].xp == 5, "UI combat awards XP")
	press(scene, "confirm")
	check(scene.game.phase == "finished", "UI finishes adventure")
	press(scene, "save_campaign")
	press(scene, "load_campaign")
	check(scene.game.phase == "finished", "finished campaign reload")
	if OS.get_environment("SOB_CAPTURE") == "1":
		yield(self, "idle_frame")
		yield(self, "idle_frame")
		var capture = get_root().get_texture().get_data()
		capture.flip_y()
		check(capture.save_png("res://.local/board-smoke.png") == OK, "screenshot saved")
	print("Scene smoke failures: ", failures.size())
	scene.queue_free()
	yield(self, "idle_frame")
	quit(0 if failures.empty() else 1)
