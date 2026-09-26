extends Reference
const Assets = preload("res://app/presentation/presentation_assets.gd")
const GOLD = Color("#d8b478")
const PAPER = Color("#e0d1ac")
var font
var title
var heading
var small
var backdrop
var hero_art
var enemy_art
var role_assets
var world_art

func setup(base_font, assets, library):
	font = base_font
	title = Assets.font(25)
	heading = Assets.font(15)
	small = base_font
	role_assets = assets
	backdrop = Assets.load_image("res://app/assets/mine_backdrop.png")
	hero_art = assets.role_texture(library, "hero")
	enemy_art = assets.role_texture(library, "enemy")
	world_art = assets.role_texture(library, "world")

func label(c, pos, value, color = PAPER, use_font = null):
	c.draw_string(font if use_font == null else use_font, pos, value, color)

func panel(c, rect, color = Color("#221910")):
	c.draw_rect(rect, Color("#0e0b08"))
	c.draw_rect(rect.grow(-2), color)
	c.draw_rect(rect.grow(-1), Color("#886133"), false, 1)
	for point in [rect.position + Vector2(5, 5), rect.position + Vector2(rect.size.x - 5, 5),
		rect.position + Vector2(5, rect.size.y - 5), rect.end - Vector2(5, 5)]:
		c.draw_circle(point, 1.5, GOLD)

func cropped(c, role, texture, rect, modulate = Color.white):
	if texture != null:
		c.draw_texture_rect_region(texture, rect, role_assets.region(role, texture), modulate)

func paint(c):
	var g = c.game
	var m = c.motion
	c.draw_rect(Rect2(0, 0, 640, 480), Color("#17120e"))
	panel(c, Rect2(12, 10, 616, 68))
	label(c, Vector2(27, 42), "S.O.B.36", GOLD, title)
	label(c, Vector2(28, 65), "BENEATH THE BRIMSTONE", Color("#b5996c"))
	if g == null:
		label(c, Vector2(20, 110), c.message)
		return
	label(c, Vector2(373, 36), "EXPLORER  /  %d XP" % g.campaign.heroes[0].xp, PAPER, heading)
	label(c, Vector2(374, 59), "Turn %02d   -   %s" % [g.turn, g.phase.capitalize()], Color("#b5996c"))
	var stage = Rect2(12, 87, 616, 256)
	panel(c, stage)
	if backdrop != null:
		c.draw_texture_rect(backdrop, stage.grow(-3), false)
	else:
		cropped(c, "world", world_art, stage.grow(-3))
	# Lantern light breathes independently of the canonical RNG.
	var time = m.clock
	for r in range(4):
		c.draw_circle(Vector2(68, 154), 11 + r * 8, Color(1.0, 0.55, 0.15, (0.023 + sin(time * 3.1) * 0.005) * (4 - r)))
	# The unexplored chamber lifts out of darkness as its reveal event plays.
	for i in range(12):
		c.draw_rect(Rect2(314 + i * 26, 91, 27, 248), Color(0.025, 0.035, 0.035, (1.0 - m.reveal) * (0.86 + i * 0.01)))
	if not m.reduced:
		for i in range(19):
			var x = 28 + fmod(i * 71.3 + time * (3 + i % 3), 580)
			var y = 110 + fmod(i * 37.1 - time * (6 + i % 4) + 100000, 205)
			c.draw_circle(Vector2(x, y), 0.7 + (i % 2) * 0.5, Color(0.94, 0.70, 0.33, 0.12 + sin(time + i) * 0.06))
	c.draw_rect(Rect2(21, 96, 253, 24), Color(0.06, 0.045, 0.025, 0.85))
	label(c, Vector2(30, 113), m.chapter, GOLD, heading)
	if m.reveal < 0.2:
		label(c, Vector2(411, 180), "THE UNKNOWN", Color("#acbfc0"), heading)
		label(c, Vector2(416, 200), "Reveal at the doorway", Color("#889a98"))
	for edge in g.map.connections:
		var a = g.map.spaces[edge[0]]
		var b = g.map.spaces[edge[1]]
		if a.tile in g.map.revealed_tiles and b.tile in g.map.revealed_tiles:
			c.draw_line(m.point(a), m.point(b), Color(0.76, 0.61, 0.35, 0.52), 2, true)
	for id in g.map.spaces:
		var space = g.map.spaces[id]
		if not space.tile in g.map.revealed_tiles:
			continue
		var p = m.point(space)
		c.draw_circle(p, 16, Color(0.07, 0.065, 0.045, 0.82))
		c.draw_arc(p, 16, 0, TAU, 28, GOLD, 1.0, true)
		if id == "first_1":
			label(c, p + Vector2(-16, 34), "DOOR", Color("#c8b58d"))
	var hero = m.hero_position()
	c.draw_circle(hero + Vector2(0, 6), 23, Color(0.01, 0.01, 0.01, 0.6))
	var bob = 0.0 if m.reduced else sin(m.travel * PI * 4) * (1 - m.travel) * 4
	var hero_rect = Rect2(hero + Vector2(-23, -59 - bob), Vector2(46, 65))
	c.draw_rect(hero_rect.grow(2), GOLD)
	if hero_art != null:
		cropped(c, "hero", hero_art, hero_rect)
	else:
		c.draw_rect(hero_rect, Color("#382c1e"))
		label(c, hero + Vector2(-8, -20), "H", GOLD, title)
	if m.enemy_visible > 0.01:
		var p = m.point(g.map.spaces[g.enemy.space_id])
		var sway = 0 if m.reduced else sin(time * 2.8) * 3
		var shake = 0 if m.reduced else sin(time * 61) * m.impact * 6
		var enemy_rect = Rect2(p + Vector2(-27 + sway + shake, -66), Vector2(54, 70))
		c.draw_circle(p + Vector2(0, 5), 25, Color(0.0, 0.02, 0.03, 0.6 * m.enemy_visible))
		c.draw_rect(enemy_rect.grow(2), Color(0.26, 0.56, 0.58, m.enemy_visible))
		if enemy_art != null:
			cropped(c, "enemy", enemy_art, enemy_rect, Color(1, 1 - m.impact * 0.4, 1 - m.impact * 0.5, m.enemy_visible))
		else:
			label(c, p + Vector2(-8, -25), "?", Color("#69abb0"), title)
		label(c, p + Vector2(-22, 29), "%d / 4" % g.enemy.hp, Color("#c4d1ca"))
	if m.impact > 0:
		var from = hero + Vector2(22, -34)
		var to = m.point(g.map.spaces[g.enemy.space_id]) + Vector2(-5, -35)
		c.draw_line(from, to, Color(1, 0.77, 0.3, m.impact * 0.8), 2)
		c.draw_circle(from, 10 * m.impact, Color(1, 0.84, 0.5, m.impact))
	if m.damage_age < 1.2 and not m.reduced:
		var p = m.point(g.map.spaces[g.enemy.space_id]) + Vector2(-8, -77 - m.damage_age * 18)
		label(c, p, "-" + str(m.damage), Color(1, 0.75, 0.45, 1 - m.damage_age / 1.2), heading)
	if m.die_age < 2.8:
		var shown = int(fmod(m.clock * 26, 6)) + 1 if m.die_age < 0.35 and not m.reduced else m.last_roll
		var rect = Rect2(292, 130, 36, 36)
		panel(c, rect, Color("#d3bd89"))
		label(c, Vector2(302, 157), str(shown), Color("#342216"), title)
	if m.ending > 0:
		c.draw_rect(stage.grow(-4), Color(0.8, 0.52, 0.19, m.ending * 0.12))
		panel(c, Rect2(207, 190, 229, 55), Color(0.1, 0.07, 0.04, 0.9))
		label(c, Vector2(225, 213), "A TALE TO TELL", GOLD, heading)
		label(c, Vector2(225, 234), "+5 test XP  /  journey complete", PAPER)
	panel(c, Rect2(12, 352, 616, 66), Color("#d1bb8b"))
	label(c, Vector2(25, 374), m.narrative.left(81), Color("#302419"))
	var lines = c.wrap_message(c.message, 578)
	for i in range(min(2, lines.size())):
		label(c, Vector2(25, 395 + i * 16), lines[i], Color("#593e24"))
	label(c, Vector2(18, 439), "Arrows: move    A / Enter: act    X / F5: save    Y / F9: load", PAPER)
	label(c, Vector2(18, 459), "Select / G: collection    LB / M: motion    Start / N: new", Color("#b59c72"))
	label(c, Vector2(18, 477), "Visual demo - original test mechanics; tabletop rules not yet verified.", Color("#8b7e67"))
