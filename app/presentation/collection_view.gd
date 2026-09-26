extends Control
var library
var entries = []
var categories = []
var category = 0
var selection = 0
var zoom = 1.0
var pan = Vector2.ZERO
var current_texture
var font
var heading
var slide = 0.0
var reduced = false
var close_requested = false

func setup(source_library, source_entries):
	library = source_library
	entries = source_entries
	font = get_font("font")
	heading = preload("res://app/presentation/presentation_assets.gd").font(20)
	for entry in entries:
		if not entry.category in categories:
			categories.append(entry.category)
	categories.sort()
	visible = false

func selected_entries():
	var result = []
	if categories.empty():
		return result
	for entry in entries:
		if entry.category == categories[category]:
			result.append(entry)
	return result

func refresh():
	var chosen = selected_entries()
	current_texture = null if chosen.empty() else library.get_texture(chosen[selection].path, 2048)
	slide = 0.0 if reduced else 1.0
	update()

func open():
	close_requested = false
	visible = true
	refresh()

func handle(action):
	close_requested = false
	if action == "collection" or (action == "cancel" and zoom == 1.0):
		visible = false
		close_requested = true
		return
	if categories.empty():
		return
	if action == "cancel":
		zoom = 1.0
		pan = Vector2.ZERO
	elif action == "confirm":
		zoom = 1.0 if zoom >= 3.0 else zoom + 1.0
		pan = Vector2.ZERO
	elif action.begins_with("move_") and zoom > 1.0:
		var steps = {"move_left": Vector2(55, 0), "move_right": Vector2(-55, 0),
			"move_up": Vector2(0, 55), "move_down": Vector2(0, -55)}
		pan += steps[action]
		pan.x = clamp(pan.x, -500, 500)
		pan.y = clamp(pan.y, -500, 500)
	elif action == "move_left" or action == "move_right":
		var amount = -1 if action == "move_left" else 1
		selection = posmod(selection + amount, selected_entries().size())
		refresh()
	elif action == "move_up" or action == "move_down":
		category = posmod(category + (-1 if action == "move_up" else 1), categories.size())
		selection = 0
		refresh()
	update()

func _process(delta):
	if visible and slide > 0:
		slide = max(0, slide - delta * 4)
		update()

func _draw():
	if font == null:
		return
	draw_rect(Rect2(0, 0, 640, 480), Color("#140f0b"))
	if current_texture != null:
		var scale_value = min(580.0 / current_texture.get_width(), 335.0 / current_texture.get_height()) * zoom
		var size = current_texture.get_size() * scale_value
		var location = Vector2(320, 252) - size / 2 + pan + Vector2(slide * 24, 0)
		draw_rect(Rect2(location - Vector2(3, 3), size + Vector2(6, 6)), Color("#95692e"))
		draw_texture_rect(current_texture, Rect2(location, size), false)
	draw_rect(Rect2(0, 0, 640, 80), Color("#20170e"))
	draw_rect(Rect2(0, 422, 640, 58), Color("#20170e"))
	draw_line(Vector2(18, 77), Vector2(622, 77), Color("#9e783c"))
	draw_string(heading, Vector2(22, 31), "YOUR CARD COLLECTION", Color("#e3bd79"))
	if categories.empty():
		draw_string(font, Vector2(22, 60), "No image library found. Place scans in the SOB folder.", Color("#d4c3a4"))
		draw_string(font, Vector2(22, 455), "Select / G or B / Esc: return to adventure", Color("#d4c3a4"))
		return
	var chosen = selected_entries()
	var name = chosen[selection].name.replace("_", " ")
	draw_string(font, Vector2(22, 59), categories[category] + "   /   " + str(selection + 1) + " of " + str(chosen.size()), Color("#d4c3a4"))
	draw_string(font, Vector2(390, 59), str(entries.size()) + " local images", Color("#b99b6d"))
	if current_texture == null:
		draw_string(font, Vector2(130, 250), "This image could not be read.", Color("#e3bd79"))
	draw_string(font, Vector2(22, 442), name.left(64), Color("#e3bd79"))
	var instruction = "Arrows: pan   A / Enter: zoom " + str(int(zoom)) + "x   B / Esc: fit" if zoom > 1 else "Left/right: card   Up/down: deck   A / Enter: zoom"
	draw_string(font, Vector2(22, 465), instruction + "   G: back", Color("#d4c3a4"))
