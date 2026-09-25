extends Reference
# Test mechanics only. This is deliberately NOT a Shadows of Brimstone rule set.
func validate(game, action):
	if typeof(action) != TYPE_DICTIONARY or typeof(action.get("type")) != TYPE_STRING:
		return "Action must have a type"
	if game.phase == "finished":
		return "Adventure is already finished"
	var hero = game.campaign.heroes[0]
	match action.type:
		"move":
			if game.phase != "exploration":
				return "Finish combat before moving"
			if typeof(action.get("target")) != TYPE_STRING or not game.map.spaces.has(action.target):
				return "Unknown space"
			if not game.map.spaces[action.target].tile in game.map.revealed_tiles:
				return "Reveal the next tile first"
			if action.target == game.enemy.space_id and game.enemy.spawned and game.enemy.hp > 0:
				return "Enemy occupies that space"
			if not adjacent(game, hero.space_id, action.target):
				return "Spaces are not connected"
		"reveal":
			if game.phase != "exploration" or hero.space_id != "first_1" or "second" in game.map.revealed_tiles:
				return "Reveal at the east doorway"
		"engage":
			if game.phase != "exploration" or not game.enemy.spawned or game.enemy.hp <= 0:
				return "No enemy to engage"
			if not adjacent(game, hero.space_id, game.enemy.space_id):
				return "Move next to the enemy"
		"attack":
			if game.phase != "combat" or game.enemy.hp <= 0:
				return "No active combat"
			if game.content.for_rules(game.enemy.record_id) == null:
				return "Enemy content is not verified"
		"finish":
			if game.phase != "exploration" or not game.enemy.xp_awarded:
				return "Defeat the test enemy first"
		_:
			return "Unknown action"
	return ""

func adjacent(game, source, target):
	return [source, target] in game.map.connections or [target, source] in game.map.connections

func execute(game, action):
	var error = validate(game, action)
	if error != "":
		return {"ok": false, "error": error, "events": []}
	var start = game.events.history.size()
	var hero = game.campaign.heroes[0]
	game.turn += 1
	match action.type:
		"move":
			var origin = hero.space_id
			hero.space_id = action.target
			game.events.emit_event("hero_moved", {"from": origin, "to": hero.space_id})
		"reveal":
			game.map.revealed_tiles.append("second")
			game.enemy.spawned = true
			game.events.emit_event("tile_revealed", {"tile": "second"})
			game.events.emit_event("enemy_spawned", {"enemy": game.enemy.id})
		"engage":
			game.phase = "combat"
			game.initiative = {"hero": game.rng.roll(6), "enemy": game.rng.roll(6)}
			game.initiative["first"] = "hero" if game.initiative.hero >= game.initiative.enemy else "enemy"
			game.events.emit_event("initiative_rolled", game.initiative)
		"attack":
			var roll = game.rng.roll(6)
			var damage = 1 + int(roll >= 4)
			game.enemy.hp = max(0, game.enemy.hp - damage)
			game.events.emit_event("attack_resolved", {"roll": roll, "damage": damage, "hp": game.enemy.hp})
			if game.enemy.hp == 0:
				var xp = int(game.content.for_rules(game.enemy.record_id).data.xp)
				hero.xp += xp
				game.enemy.xp_awarded = true
				game.phase = "exploration"
				game.events.emit_event("xp_awarded", {"hero": hero.id, "xp": xp})
		"finish":
			game.phase = "finished"
			game.campaign.completed_adventures += 1
			game.events.emit_event("adventure_finished")
	var emitted = []
	for i in range(start, game.events.history.size()):
		emitted.append(game.events.history[i].duplicate(true))
	return {"ok": true, "error": "", "events": emitted}
