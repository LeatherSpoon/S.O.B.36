extends Reference

func run(t):
	var rng_script = load("res://core/rng/deterministic_rng.gd")
	t.check(rng_script != null, "deterministic RNG exists")
	if rng_script == null:
		return
	var rng = rng_script.new(1)
	for expected in [16807, 282475249, 1622650073, 984943658, 1144108930]:
		t.check(rng.next_int() == expected, "Park-Miller known vector")
	var restored = rng_script.new(rng.state)
	t.check(rng.roll(6) == restored.roll(6), "RNG continuation")
	var Game = load("res://core/campaign/game_state.gd")
	var Save = load("res://core/save/save_service.gd")
	var game = Game.new()
	game.start(12345)
	t.check(game.validate().empty(), "new canonical state validates")
	var before = game.to_data()
	var denied = game.execute({"type": "move", "target": "second_1"})
	t.check(not denied.ok and t.equal(game.to_data(), before), "illegal move is mutation and RNG free")
	t.check(game.execute({"type": "move", "target": "first_1"}).ok, "adjacent move")
	t.check(game.execute({"type": "reveal"}).ok, "reveal second tile")
	t.check(game.map.revealed_tiles == ["first", "second"], "second tile revealed")
	t.check(game.execute({"type": "move", "target": "second_0"}).ok, "cross tile connection")
	t.check(game.execute({"type": "engage"}).ok, "initiative stub")
	var save = Save.new()
	var text = save.encode(game)
	var loaded = save.decode(text)
	t.check(loaded.ok, "save decode succeeds")
	if not loaded.ok:
		return
	t.check(t.equal(loaded.game.to_data(), game.to_data()), "exact canonical JSON round trip")
	var resumed = loaded.game
	var event_a = game.execute({"type": "attack"})
	var event_b = resumed.execute({"type": "attack"})
	t.check(t.equal(event_a, event_b), "next combat events identical after reload")
	t.check(t.equal(game.to_data(), resumed.to_data()), "continued RNG and state identical")
	for _i in range(8):
		if game.enemy.hp > 0:
			game.execute({"type": "attack"})
	t.check(game.enemy.hp == 0 and game.campaign.heroes[0].xp == 5, "enemy defeated and XP awarded once")
	before = game.to_data()
	t.check(not game.execute({"type": "attack"}).ok and t.equal(before, game.to_data()), "cannot farm defeated enemy XP")
	t.check(game.execute({"type": "finish"}).ok, "finish test adventure")
	t.check(game.campaign.completed_adventures == 1, "campaign completion persisted")
	t.check(t.equal(save.decode(save.encode(game)).game.to_data(), game.to_data()), "finished save preserves campaign")
	t.check(not save.decode("garbage").ok, "corrupt JSON rejected")
	var envelope = JSON.parse(text).result
	envelope.save_version = 999
	t.check(not save.decode(JSON.print(envelope)).ok, "future save version rejected")
	envelope.save_version = 1
	envelope.state.rng.state = 0
	t.check(not save.decode(JSON.print(envelope)).ok, "invalid RNG rejected")
	var invalid = game.to_data()
	invalid.campaign.heroes[0].space_id = "missing"
	t.check(not Game.from_data(invalid).ok, "invalid topology references rejected")
	invalid = game.to_data()
	invalid.map.connections.append(["first_0", "missing"])
	t.check(not Game.from_data(invalid).ok, "broken map connection rejected")
	t.check(game.campaign.edition.status == "unverified", "edition remains unresolved")

	return true
