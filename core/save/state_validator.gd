extends Reference
const MAX_INT = 2147483647

static func integer(value, minimum = 0, maximum = MAX_INT):
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_REAL) and value >= minimum and value <= maximum and value == int(value)

static func fields(value, required):
	if typeof(value) != TYPE_DICTIONARY or value.size() != required.size():
		return false
	for key in required:
		if not value.has(key):
			return false
	return true

static func normalize(value):
	if typeof(value) == TYPE_REAL:
		return int(value)
	if typeof(value) == TYPE_ARRAY:
		var result = []
		for item in value:
			result.append(normalize(item))
		return result
	if typeof(value) == TYPE_DICTIONARY:
		var result = {}
		for key in value:
			result[key] = normalize(value[key])
		return result
	return value

static func exact_numbers(value):
	if typeof(value) == TYPE_REAL or typeof(value) == TYPE_INT:
		return integer(value, -MAX_INT, MAX_INT)
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			if not exact_numbers(item):
				return false
	if typeof(value) == TYPE_DICTIONARY:
		for key in value:
			if not exact_numbers(value[key]):
				return false
	return true

func errors(d):
	if not exact_numbers(d):
		return ["Canonical numbers must be exact 32-bit integers"]
	if not fields(d, ["campaign", "rng", "events", "map", "enemy", "phase", "turn", "packs", "initiative"]):
		return ["Invalid game-state fields"]
	if not fields(d.rng, ["algorithm", "state"]) or d.rng.algorithm != "park_miller_16807_v1" or not integer(d.rng.state, 1, MAX_INT - 1):
		return ["Invalid RNG state"]
	if not fields(d.campaign, ["id", "edition", "heroes", "completed_adventures"]):
		return ["Invalid campaign fields"]
	var c = d.campaign
	if typeof(c.id) != TYPE_STRING or c.id.empty() or not integer(c.completed_adventures):
		return ["Invalid campaign identity or progress"]
	if not fields(c.edition, ["id", "status"]) or typeof(c.edition.id) != TYPE_STRING or not c.edition.status in ["unverified", "provisional", "verified"]:
		return ["Invalid edition metadata"]
	if typeof(c.heroes) != TYPE_ARRAY or c.heroes.size() != 1:
		return ["Phase 0 requires exactly one hero"]
	if not fields(d.map, ["spaces", "connections", "revealed_tiles"]) or typeof(d.map.spaces) != TYPE_DICTIONARY or typeof(d.map.connections) != TYPE_ARRAY or typeof(d.map.revealed_tiles) != TYPE_ARRAY:
		return ["Invalid map"]
	if d.map.spaces.empty():
		return ["Map has no spaces"]
	var tiles = []
	var positions = []
	for id in d.map.spaces:
		var space = d.map.spaces[id]
		if not fields(space, ["id", "tile", "x", "y"]) or space.id != id or typeof(space.tile) != TYPE_STRING or not integer(space.x, 0, 20) or not integer(space.y, 0, 20):
			return ["Invalid map space"]
		var position = "%d:%d" % [space.x, space.y]
		if position in positions:
			return ["Overlapping map spaces"]
		positions.append(position)
		if not space.tile in tiles:
			tiles.append(space.tile)
	var revealed = []
	for tile in d.map.revealed_tiles:
		if not tile in tiles or tile in revealed:
			return ["Invalid revealed tile"]
		revealed.append(tile)
	if revealed.empty():
		return ["No revealed tiles"]
	var edges = []
	for edge in d.map.connections:
		if typeof(edge) != TYPE_ARRAY or edge.size() != 2 or not d.map.spaces.has(edge[0]) or not d.map.spaces.has(edge[1]) or edge[0] == edge[1]:
			return ["Invalid map connection"]
		if edge in edges or [edge[1], edge[0]] in edges:
			return ["Duplicate map connection"]
		edges.append(edge)
	var reached = [d.map.spaces.keys()[0]]
	var pending = reached.duplicate()
	while not pending.empty():
		var current = pending.pop_front()
		for edge in edges:
			if current in edge:
				var neighbor = edge[1] if edge[0] == current else edge[0]
				if not neighbor in reached:
					reached.append(neighbor)
					pending.append(neighbor)
	if reached.size() != d.map.spaces.size():
		return ["Disconnected map"]
	for hero in c.heroes:
		if not fields(hero, ["id", "name", "space_id", "xp"]) or typeof(hero.id) != TYPE_STRING or hero.id.empty() or typeof(hero.name) != TYPE_STRING or not integer(hero.xp):
			return ["Invalid hero"]
		if not d.map.spaces.has(hero.space_id) or not d.map.spaces[hero.space_id].tile in revealed:
			return ["Invalid hero location"]
	if not fields(d.enemy, ["id", "record_id", "space_id", "hp", "spawned", "xp_awarded"]) or typeof(d.enemy.id) != TYPE_STRING or typeof(d.enemy.record_id) != TYPE_STRING:
		return ["Invalid enemy"]
	if not d.map.spaces.has(d.enemy.space_id) or not integer(d.enemy.hp) or typeof(d.enemy.spawned) != TYPE_BOOL or typeof(d.enemy.xp_awarded) != TYPE_BOOL:
		return ["Invalid enemy state"]
	if d.enemy.spawned and not d.map.spaces[d.enemy.space_id].tile in revealed:
		return ["Enemy is on a hidden tile"]
	if d.enemy.xp_awarded != (d.enemy.hp == 0):
		return ["Invalid XP award state"]
	if not d.phase in ["exploration", "combat", "finished"] or not integer(d.turn):
		return ["Invalid phase or turn"]
	if d.phase == "combat" and (not d.enemy.spawned or d.enemy.hp == 0):
		return ["Invalid combat state"]
	if d.phase == "finished" and not d.enemy.xp_awarded:
		return ["Cannot finish before defeating enemy"]
	if typeof(d.initiative) != TYPE_DICTIONARY:
		return ["Invalid initiative"]
	if not d.initiative.empty():
		if not fields(d.initiative, ["hero", "enemy", "first"]) or not integer(d.initiative.hero, 1, 6) or not integer(d.initiative.enemy, 1, 6):
			return ["Invalid initiative rolls"]
		var first = "hero" if d.initiative.hero >= d.initiative.enemy else "enemy"
		if d.initiative.first != first:
			return ["Invalid initiative order"]
	elif d.phase == "combat":
		return ["Combat has no initiative"]
	if typeof(d.packs) != TYPE_DICTIONARY or d.packs.empty():
		return ["Missing content pack selection"]
	for id in d.packs:
		if typeof(id) != TYPE_STRING or typeof(d.packs[id]) != TYPE_STRING:
			return ["Invalid pack selection"]
	if typeof(d.events) != TYPE_ARRAY:
		return ["Invalid event history"]
	for i in range(d.events.size()):
		var event = d.events[i]
		if not fields(event, ["sequence", "type", "payload"]) or event.sequence != i + 1 or typeof(event.type) != TYPE_STRING or typeof(event.payload) != TYPE_DICTIONARY:
			return ["Invalid domain event"]
	return []
