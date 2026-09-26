extends Reference
# Role mapping is private local data, separate from verified gameplay packs.
var roles = {}

func initialize():
	var candidates = [OS.get_environment("SOB_VISUAL_CONFIG"),
		ProjectSettings.globalize_path("res://.local/visuals.json"),
		OS.get_executable_path().get_base_dir().plus_file(".local/visuals.json")]
	for path in candidates:
		var file = File.new()
		if path != "" and file.file_exists(path) and file.open(path, File.READ) == OK:
			var result = JSON.parse(file.get_as_text())
			file.close()
			if result.error == OK and typeof(result.result) == TYPE_DICTIONARY:
				roles = result.result
				return

func role_texture(library, role):
	var data = roles.get(role, {})
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var relative = data.get("path", "")
	if typeof(relative) != TYPE_STRING or relative.empty() or relative.is_abs_path() or ":" in relative or ".." in relative.split("/") or "\\" in relative:
		return null
	return library.get_texture(library.root.plus_file(relative))

func region(role, texture):
	var data = roles.get(role, {})
	if typeof(data) != TYPE_DICTIONARY:
		return Rect2(Vector2.ZERO, texture.get_size())
	var d = data.get("region", [0, 0, 1, 1])
	if typeof(d) != TYPE_ARRAY or d.size() != 4:
		d = [0, 0, 1, 1]
	for value in d:
		if not typeof(value) in [TYPE_INT, TYPE_REAL]:
			return Rect2(Vector2.ZERO, texture.get_size())
	var x = clamp(d[0], 0.0, 1.0)
	var y = clamp(d[1], 0.0, 1.0)
	return Rect2(Vector2(x, y) * texture.get_size(),
		Vector2(clamp(d[2], 0.0, 1.0 - x), clamp(d[3], 0.0, 1.0 - y)) * texture.get_size())

static func load_image(path):
	var image = Image.new()
	var file = File.new()
	if not file.file_exists(path) or image.load(path) != OK:
		return null
	var texture = ImageTexture.new()
	texture.create_from_image(image, Texture.FLAG_FILTER)
	return texture

static func font(size):
	var data = DynamicFontData.new()
	data.font_path = "res://app/assets/DejaVuSerif-Bold.ttf"
	var result = DynamicFont.new()
	result.font_data = data
	result.size = size
	return result
