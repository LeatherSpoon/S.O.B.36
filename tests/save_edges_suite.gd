extends Reference

func run(t):
	var Game = load("res://core/campaign/game_state.gd")
	var Save = load("res://core/save/save_service.gd")
	var game = Game.new()
	game.start(7)
	var save = Save.new()
	var path = "res://.local/tests/campaign.json"
	t.check(save.write(path, game).ok, "disk save succeeds")
	t.check(t.equal(save.read(path).game.to_data(), game.to_data()), "disk save preserves exact state")
	game.execute({"type": "move", "target": "first_1"})
	t.check(save.write(path, game).ok, "existing save can be replaced")
	t.check(File.new().file_exists(path + ".bak"), "previous save retained for recovery")
	var invalid = game.to_data()
	invalid.campaign.heroes[0].xp = 1.5
	t.check(not Game.from_data(invalid).ok, "fractional XP rejected")
	invalid = game.to_data()
	invalid.map.connections = []
	t.check(not Game.from_data(invalid).ok, "disconnected map rejected")
	invalid = game.to_data()
	invalid.map.spaces.second_0.x = 0
	t.check(not Game.from_data(invalid).ok, "overlapping map spaces rejected")
	invalid = game.to_data()
	invalid.packs.placeholder = "99"
	t.check(not Game.from_data(invalid).ok, "wrong content version rejected")
	invalid = game.to_data()
	invalid.enemy.record_id = "missing.enemy"
	t.check(not Game.from_data(invalid).ok, "save cannot reference unknown gameplay content")
	invalid = game.to_data()
	invalid.events[0].payload.seed = 1.25
	t.check(not Game.from_data(invalid).ok, "fractional canonical event numbers rejected without lossy coercion")
	var before = game.to_data()
	for action in [null, {}, {"type": "unknown"}, {"type": "attack"}, {"type": "finish"}, {"type": "move", "target": 4}]:
		t.check(not game.execute(action).ok and t.equal(before, game.to_data()), "invalid action rejected atomically")
	return true
