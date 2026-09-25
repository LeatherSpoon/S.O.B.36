extends Reference
const RNG = preload("res://core/rng/deterministic_rng.gd")
const Campaign = preload("res://core/campaign/campaign_state.gd")
const Events = preload("res://core/events/event_queue.gd")
const Actions = preload("res://core/actions/action_service.gd")
const Validator = preload("res://core/save/state_validator.gd")
const Loader = preload("res://content/loaders/pack_loader.gd")

var campaign
var rng
var events
var map = {}
var enemy = {}
var phase = "exploration"
var turn = 0
var packs = {}
var initiative = {}
var content

func start(seed_value = 1, pack_root = "res://content/packs"):
	content = Loader.new()
	var result = content.load_packs(pack_root, ["placeholder"])
	if not result.ok:
		return result
	campaign = Campaign.new()
	rng = RNG.new(seed_value)
	events = Events.new()
	map = {"spaces": {}, "connections": [], "revealed_tiles": ["first"]}
	for id in ["placeholder.first", "placeholder.second"]:
		var record = content.for_rules(id)
		if record == null or record.type != "MapTile":
			return {"ok": false, "error": "Unverified map fixture"}
		for space in record.data.spaces:
			if map.spaces.has(space.id):
				return {"ok": false, "error": "Duplicate map space ID"}
			map.spaces[space.id] = space.duplicate(true)
		for connection in record.data.connections:
			map.connections.append(connection.duplicate())
	var enemy_record = content.for_rules("placeholder.enemy")
	if enemy_record == null or enemy_record.type != "Enemy":
		return {"ok": false, "error": "Unverified enemy fixture"}
	enemy = {"id": "enemy_1", "record_id": enemy_record.id, "space_id": "second_1",
		"hp": int(enemy_record.data.hp), "spawned": false, "xp_awarded": false}
	packs = {"placeholder": result.packs.placeholder.version}
	phase = "exploration"
	turn = 0
	initiative = {}
	events.emit_event("campaign_started", {"seed": seed_value})
	var errors = validate()
	if not errors.empty():
		return {"ok": false, "error": errors[0]}
	return {"ok": true}

func execute(action):
	return Actions.new().execute(self, action)

func validate():
	return Validator.new().errors(to_data())

func to_data():
	return {"campaign": campaign.to_data(), "rng": rng.to_data(),
		"events": events.to_data(), "map": map.duplicate(true),
		"enemy": enemy.duplicate(true), "phase": phase, "turn": turn,
		"packs": packs.duplicate(true), "initiative": initiative.duplicate(true)}

static func from_data(data):
	var errors = Validator.new().errors(data)
	if not errors.empty():
		return {"ok": false, "error": errors[0]}
	var game = load("res://core/campaign/game_state.gd").new()
	game.content = Loader.new()
	var result = game.content.load_packs("res://content/packs", data.packs.keys(), data.campaign.edition.id)
	if not result.ok:
		return {"ok": false, "error": "Required content packs unavailable"}
	for id in data.packs:
		if result.packs[id].version != data.packs[id]:
			return {"ok": false, "error": "Content pack version mismatch: " + id}
	var enemy_record = game.content.for_rules(data.enemy.record_id)
	if enemy_record == null or enemy_record.type != "Enemy" or data.enemy.hp > enemy_record.data.hp:
		return {"ok": false, "error": "Invalid or unverified saved enemy content"}
	for id in ["placeholder.first", "placeholder.second"]:
		var tile = game.content.for_rules(id)
		if tile == null or tile.type != "MapTile":
			return {"ok": false, "error": "Required verified demo map content unavailable"}
	game.campaign = Campaign.from_data(data.campaign)
	game.rng = RNG.new(int(data.rng.state))
	game.events = Events.new()
	game.events.history = Validator.normalize(data.events)
	game.map = Validator.normalize(data.map)
	game.enemy = Validator.normalize(data.enemy)
	game.phase = data.phase
	game.turn = int(data.turn)
	game.packs = data.packs.duplicate(true)
	game.initiative = Validator.normalize(data.initiative)
	return {"ok": true, "game": game}
