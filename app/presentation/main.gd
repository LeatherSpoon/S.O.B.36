extends Control
const Game = preload("res://core/campaign/game_state.gd")
const Save = preload("res://core/save/save_service.gd")
const Controls = preload("res://app/input/controls.gd")
const ArtLibrary = preload("res://app/presentation/art_library.gd")
const Assets = preload("res://app/presentation/presentation_assets.gd")
const Motion = preload("res://app/presentation/story_motion.gd")
const StoryView = preload("res://app/presentation/story_view.gd")
const Collection = preload("res://app/presentation/collection_view.gd")
const ACTIONS = ["move_left", "move_right", "move_up", "move_down", "confirm",
	"save_campaign", "load_campaign", "new_campaign", "cancel", "collection", "reduced_motion"]
const INK = Color("#e6e3d8")
const MUTED = Color("#9eabb4")
const GOLD = Color("#e2b768")
const TEAL = Color("#6bc7b3")
var motion = Motion.new()
var art = ArtLibrary.new()
var assets = Assets.new()
var story_view = StoryView.new()
var gallery = Collection.new()
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
	assets.initialize()
	var entries = art.discover()
	story_view.setup(font, assets, art)
	add_child(gallery)
	gallery.setup(art, entries)
	var product_root = OS.get_executable_path().get_base_dir()
	if Directory.new().dir_exists(product_root.plus_file("SOB")):
		save_path = product_root.plus_file("saves/campaign.json")
	var configured = OS.get_environment("SOB_SAVE_PATH")
	if configured != "":
		save_path = configured
	start_campaign()
	if "--sob-smoke" in OS.get_cmdline_args():
		preload("res://app/presentation/installed_smoke.gd").run(self)

func start_campaign():
	var next = Game.new()
	var result = next.start(12345)
	if not result.ok:
		message = "Content error: " + result.error
		set_process(false)
		update()
		return
	game = next
	motion.sync(game)
	new_pending = false
	event_lines = ["Original fixtures loaded. Seed 12345."]
	message = "Move right to the doorway, then press A / Enter to reveal."
	update()

func _process(delta):
	motion.advance(delta)
	update()
	for action in ACTIONS:
		if Input.is_action_just_pressed(action):
			handle_action(action)

func open_collection():
	gallery.open()

func handle_action(action):
	if action == "reduced_motion":
		motion.set_reduced(not motion.reduced)
		gallery.reduced = motion.reduced
		message = "Reduced motion on." if motion.reduced else "Full animation on."
		return
	if gallery.visible:
		gallery.handle(action)
		return
	if action == "collection":
		open_collection()
		return
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
			motion.sync(game)
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
	motion.observe(result.events, game)
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

func _draw():
	if font != null:
		story_view.paint(self)

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
