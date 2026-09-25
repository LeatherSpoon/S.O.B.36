extends Control
const Game = preload("res://core/campaign/game_state.gd")
const Save = preload("res://core/save/save_service.gd")
const Controls = preload("res://app/input/controls.gd")
const ACTIONS = ["move_left", "move_right", "move_up", "move_down", "confirm",
	"save_campaign", "load_campaign", "new_campaign", "cancel"]
const INK = Color("#e6e3d8")
const MUTED = Color("#9eabb4")
const GOLD = Color("#e2b768")
const TEAL = Color("#6bc7b3")
var game
var save_path = "user://campaign.json"
var message = ""
var new_pending = false
var font
var save_service = Save.new()
var event_lines = []

func _ready():
	Controls.install()
	font = get_font("font")
	var configured = OS.get_environment("SOB_SAVE_PATH")
	if configured != "":
		save_path = configured
	start_campaign()

func start_campaign():
	var next = Game.new()
	var result = next.start(12345)
	if not result.ok:
		message = "Content error: " + result.error
		set_process(false)
		update()
		return
	game = next
	new_pending = false
	event_lines = ["Original fixtures loaded. Seed 12345."]
	message = "Move right to the doorway, then press A / Enter to reveal."
	update()

func _process(_delta):
	for action in ACTIONS:
		if Input.is_action_just_pressed(action):
			handle_action(action)

func handle_action(action):
	if new_pending:
		if action == "confirm":
			start_campaign()
		elif action == "cancel" or action == "new_campaign":
			new_pending = false
			message = "New campaign canceled."
			update()
		return
	if action == "new_campaign":
		new_pending = true
		message = "Start over? A / Enter confirms. B / Esc cancels."
	elif action == "save_campaign":
		var result = save_service.write(save_path, game)
		message = "Campaign saved, including RNG state." if result.ok else result.error
	elif action == "load_campaign":
		var result = save_service.read(save_path)
		if result.ok:
			game = result.game
			event_lines = ["Campaign restored. RNG and event history preserved."]
			message = "Loaded campaign. " + objective()
		else:
			message = result.error
	elif action == "confirm":
		if game.phase == "combat":
			dispatch({"type": "attack"})
		elif game.enemy.xp_awarded and game.phase != "finished":
			dispatch({"type": "finish"})
			if game.phase == "finished":
				var saved = save_service.write(save_path, game)
				message = "Adventure complete. Campaign saved." if saved.ok else "Complete, but save failed: " + saved.error
		elif game.campaign.heroes[0].space_id == "first_1" and not "second" in game.map.revealed_tiles:
			dispatch({"type": "reveal"})
		else:
			dispatch({"type": "engage"})
	elif action.begins_with("move_"):
		move(action)
	update()

func move(action):
	var current = game.map.spaces[game.campaign.heroes[0].space_id]
	var direction = {"move_left": Vector2(-1, 0), "move_right": Vector2(1, 0),
		"move_up": Vector2(0, -1), "move_down": Vector2(0, 1)}[action]
	for id in game.map.spaces:
		var space = game.map.spaces[id]
		if Vector2(space.x, space.y) == Vector2(current.x, current.y) + direction:
			dispatch({"type": "move", "target": id})
			return
	message = "No connected space in that direction."

func dispatch(action):
	var result = game.execute(action)
	if not result.ok:
		message = result.error
		return
	for event in result.events:
		event_lines.append(describe(event))
	while event_lines.size() > 3:
		event_lines.pop_front()
	message = objective()

func objective():
	if game.phase == "finished":
		return "Adventure complete. Your hero earned 5 test XP."
	if game.phase == "combat":
		return "A / Enter: attack the test enemy."
	if game.enemy.xp_awarded:
		return "A / Enter: finish the adventure and save."
	if game.enemy.spawned:
		return "Move beside the enemy. A / Enter: roll initiative."
	return "Move to the doorway. A / Enter: reveal the second tile."

func describe(event):
	var p = event.payload
	match event.type:
		"hero_moved": return "Hero moved to " + p.to.replace("_", " ") + "."
		"tile_revealed": return "Second tile connected."
		"enemy_spawned": return "A test enemy appeared."
		"initiative_rolled": return "Initiative: hero %d / enemy %d. %s first (stub)." % [p.hero, p.enemy, p.first]
		"attack_resolved": return "Attack: d6 %d, damage %d, enemy HP %d." % [p.roll, p.damage, p.hp]
		"xp_awarded": return "Enemy defeated. +%d test XP." % p.xp
		"adventure_finished": return "Adventure finished."
	return event.type.replace("_", " ")

func text_at(position, text, color = INK):
	draw_string(font, position, text, color)

func position_for(space):
	return Vector2(94 + space.x * 148, 195)

func _draw():
	if font == null:
		return
	draw_rect(Rect2(0, 0, 640, 480), Color("#111920"))
	draw_rect(Rect2(20, 22, 4, 39), GOLD)
	text_at(Vector2(36, 36), "S.O.B.36  /  FOUNDATION", GOLD)
	text_at(Vector2(36, 59), "PHASE 0     ORIGINAL PLACEHOLDERS     EDITION UNVERIFIED", MUTED)
	if game == null:
		text_at(Vector2(28, 100), message)
		return
	var hero = game.campaign.heroes[0]
	text_at(Vector2(24, 96), "TRAIL TESTER   /   XP %d" % hero.xp, TEAL)
	text_at(Vector2(335, 96), "TURN %02d   /   %s" % [game.turn, game.phase.to_upper()])
	draw_rect(Rect2(20, 114, 290, 153), Color("#24312f"))
	draw_rect(Rect2(330, 114, 290, 153), Color("#2a302f") if "second" in game.map.revealed_tiles else Color("#1b232a"))
	text_at(Vector2(34, 139), "01 / TRAILHEAD", MUTED)
	text_at(Vector2(345, 139), "02 / TEST CHAMBER" if "second" in game.map.revealed_tiles else "02 / UNEXPLORED", MUTED)
	for edge in game.map.connections:
		var a = game.map.spaces[edge[0]]
		var b = game.map.spaces[edge[1]]
		if a.tile in game.map.revealed_tiles and b.tile in game.map.revealed_tiles:
			draw_line(position_for(a), position_for(b), Color("#6b7061"), 3)
	for id in game.map.spaces:
		var space = game.map.spaces[id]
		if not space.tile in game.map.revealed_tiles:
			continue
		var pos = position_for(space)
		draw_circle(pos, 24, Color("#435044"))
		draw_arc(pos, 24, 0, TAU, 40, GOLD, 2, true)
		text_at(pos + Vector2(-21, 47), "DOOR" if id == "first_1" else "SPACE", MUTED)
		if hero.space_id == id:
			draw_circle(pos, 16, TEAL)
			text_at(pos + Vector2(-5, 5), "H", Color("#13231f"))
		elif game.enemy.spawned and game.enemy.hp > 0 and game.enemy.space_id == id:
			draw_rect(Rect2(pos - Vector2(15, 15), Vector2(30, 30)), Color("#c7745b"))
			text_at(pos + Vector2(-5, 5), "E", Color("#211714"))
	if not "second" in game.map.revealed_tiles:
		text_at(Vector2(376, 198), "REVEAL AT THE DOOR", MUTED)
	if game.enemy.spawned:
		text_at(Vector2(462, 255), "ENEMY HP  %d / 4" % game.enemy.hp, GOLD)
	draw_line(Vector2(24, 283), Vector2(616, 283), Color("#39434b"))
	# Message may wrap so errors and controller guidance stay within the viewport.
	var label_lines = wrap_message(message, 580)
	for i in range(min(2, label_lines.size())):
		text_at(Vector2(24, 306 + i * 19), label_lines[i], GOLD if new_pending else INK)
	for i in range(event_lines.size()):
		text_at(Vector2(24, 353 + i * 20), event_lines[i], MUTED)
	draw_rect(Rect2(0, 420, 640, 60), Color("#202b34"))
	text_at(Vector2(24, 443), "D-pad / Arrows  MOVE       A / Enter  ACT       Start / N  NEW")
	text_at(Vector2(24, 465), "X / F5  SAVE       Y / F9  LOAD       Test mechanics; not tabletop rules.", MUTED)

func wrap_message(value, width):
	var lines = []
	var line = ""
	for word in value.split(" "):
		var next = word if line.empty() else line + " " + word
		if font.get_string_size(next).x > width and not line.empty():
			lines.append(line)
			line = word
		else:
			line = next
	lines.append(line)
	return lines
