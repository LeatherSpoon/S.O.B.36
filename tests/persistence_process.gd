extends SceneTree
const Game = preload("res://core/campaign/game_state.gd")
const Save = preload("res://core/save/save_service.gd")

func _init():
	var mode = OS.get_environment("SOB_TEST_MODE")
	var path = "res://.local/process_campaign.json"
	var save = Save.new()
	if mode == "write":
		var game = Game.new()
		game.start(12345)
		for action in [{"type": "move", "target": "first_1"}, {"type": "reveal"},
			{"type": "move", "target": "second_0"}, {"type": "engage"}]:
			if not game.execute(action).ok:
				quit(1)
				return
		if not save.write(path, game).ok:
			quit(1)
			return
		var before = game.to_data()
		var result = game.execute({"type": "attack"})
		var expected = {"before": before, "after": game.to_data(), "result": result}
		var file = File.new()
		if file.open("res://.local/process_expected.json", File.WRITE) != OK:
			quit(1)
			return
		file.store_string(JSON.print(expected, "", true))
		file.close()
		print("Persistence write complete")
		quit(0)
	elif mode == "read":
		var loaded = save.read(path)
		if not loaded.ok:
			printerr(loaded.error)
			quit(1)
			return
		var file = File.new()
		if file.open("res://.local/process_expected.json", File.READ) != OK:
			quit(1)
			return
		var expected = JSON.parse(file.get_as_text()).result
		file.close()
		var before = loaded.game.to_data()
		var result = loaded.game.execute({"type": "attack"})
		var actual = {"before": before, "after": loaded.game.to_data(), "result": result}
		if JSON.print(expected, "", true) != JSON.print(actual, "", true):
			printerr("FAIL: process restart changed canonical state/RNG/events")
			quit(1)
			return
		print("Separate-process persistence proof passed")
		quit(0)
	else:
		printerr("SOB_TEST_MODE must be write or read")
		quit(1)
