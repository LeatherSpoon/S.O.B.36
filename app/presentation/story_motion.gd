extends Reference
# Presentation-only clock and event interpretation. Never owns canonical state.
var clock = 0.0
var reduced = false
var hero_from = Vector2.ZERO
var hero_to = Vector2.ZERO
var travel = 1.0
var reveal = 0.0
var revealed = false
var enemy_visible = 0.0
var enemy_alive = false
var impact = 0.0
var damage = 0
var damage_age = 2.0
var last_roll = 0
var die_age = 4.0
var ending = 0.0
var finished = false
var chapter = "THE OLD MINE"
var narrative = "The lantern catches a trail disappearing into the rock."

static func point(space):
	return Vector2(105 + space.x * 141, 288 - (24 if int(space.x) % 2 else 0))

func sync(game):
	hero_to = point(game.map.spaces[game.campaign.heroes[0].space_id])
	hero_from = hero_to
	travel = 1.0
	revealed = "second" in game.map.revealed_tiles
	reveal = 1.0 if revealed else 0.0
	enemy_alive = game.enemy.spawned and game.enemy.hp > 0
	enemy_visible = 1.0 if enemy_alive else 0.0
	finished = game.phase == "finished"
	ending = 1.0 if finished else 0.0
	impact = 0.0
	damage_age = 2.0
	die_age = 4.0
	chapter = "BACK TO THE LIGHT" if finished else ("BEYOND THE DOOR" if revealed else "THE OLD MINE")
	narrative = "Your journey is recorded. The lantern waits." if finished else "A cold draft moves through the abandoned workings."

func observe(events, game):
	for event in events:
		var p = event.payload
		match event.type:
			"hero_moved":
				hero_from = hero_position()
				hero_to = point(game.map.spaces[p.to])
				travel = 0.0
				narrative = "Bootsteps break the silence. Something answers in the deep."
			"tile_revealed":
				revealed = true
				chapter = "BEYOND THE DOOR"
				narrative = "The timbers give way. Blue light spills from the dark."
			"enemy_spawned":
				enemy_alive = true
			"initiative_rolled":
				last_roll = int(p.hero)
				die_age = 0.0
				narrative = "A shape rises from the shadows. Steady your hand."
			"attack_resolved":
				damage = int(p.damage)
				last_roll = int(p.roll)
				die_age = 0.0
				damage_age = 0.0
				impact = 1.0
				narrative = "A shot echoes through the stone."
			"xp_awarded":
				enemy_alive = false
				narrative = "The darkness recoils. The way back is clear."
			"adventure_finished":
				finished = true
				chapter = "BACK TO THE LIGHT"
				narrative = "You return with a story the town may never believe."
	if reduced:
		settle()

func hero_position():
	var t = smoothstep(0.0, 1.0, travel)
	return hero_from.linear_interpolate(hero_to, t)

func set_reduced(value):
	reduced = value
	if reduced:
		settle()

func settle():
	travel = 1.0
	reveal = 1.0 if revealed else 0.0
	enemy_visible = 1.0 if enemy_alive else 0.0
	ending = 1.0 if finished else 0.0
	impact = 0.0

func advance(delta):
	if reduced:
		settle()
		return
	clock += min(delta, 0.1)
	travel = min(1.0, travel + delta / 0.38)
	reveal = move_toward(reveal, 1.0 if revealed else 0.0, delta * 0.9)
	enemy_visible = move_toward(enemy_visible, 1.0 if enemy_alive else 0.0, delta * 1.7)
	impact = max(0.0, impact - delta * 3.8)
	damage_age += delta
	die_age += delta
	ending = move_toward(ending, 1.0 if finished else 0.0, delta * 0.7)
