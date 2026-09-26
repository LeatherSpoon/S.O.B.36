extends Reference
# Local presentation only: this class never writes scans or touches gameplay RNG.

const CACHE_LIMIT = 8
const EXTENSIONS = ["jpg", "jpeg", "png", "webp"]

var root = ""
var _known_paths = {}
var _textures = {}
var _recent = []

func source_root():
	var configured = OS.get_environment("SOB_SOURCE_ROOT").strip_edges()
	if configured != "":
		return _absolute(configured)
	var config_path = ProjectSettings.globalize_path("res://.local/paths.local.json")
	var file = File.new()
	if file.open(config_path, File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text())
		file.close()
		if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
			configured = parsed.result.get("source_root", "")
			if typeof(configured) == TYPE_STRING and configured.strip_edges() != "":
				return _absolute(configured)
	var sibling = OS.get_executable_path().get_base_dir().plus_file("SOB")
	if Directory.new().dir_exists(sibling):
		return _absolute(sibling)
	return _absolute("res://SOB")

func discover(source = ""):
	root = ""
	_known_paths.clear()
	_textures.clear()
	_recent.clear()
	var candidate = _absolute(source_root() if source == "" else source)
	if candidate == "" or not Directory.new().dir_exists(candidate):
		return []
	var paths = _safe_files(candidate)
	if paths == null:
		return []
	root = candidate
	paths.sort()
	var records = []
	for path in paths:
		path = _absolute(path)
		if _inside(path) and path.get_extension().to_lower() in EXTENSIONS:
			_known_paths[_key(path)] = true
			records.append({"path": path, "category": path.get_base_dir().get_file(), "name": path.get_file().get_basename()})
	return records

func get_texture(path, max_edge = 1024):
	if typeof(path) != TYPE_STRING or not (typeof(max_edge) in [TYPE_INT, TYPE_REAL]) or max_edge < 1:
		return null
	var absolute = _absolute(path)
	if not _inside(absolute) or not _known_paths.has(_key(absolute)):
		return null
	var edge = int(clamp(max_edge, 1, 4096))
	var cache_key = _key(absolute) + ":" + str(edge)
	if _textures.has(cache_key):
		_touch(cache_key)
		return _textures[cache_key]
	if not _safe_file(absolute):
		return null
	var image = Image.new()
	if image.load(absolute) != OK or image.is_empty():
		return null
	var largest = max(image.get_width(), image.get_height())
	if largest > edge:
		var scale = float(edge) / largest
		image.resize(max(1, int(round(image.get_width() * scale))), max(1, int(round(image.get_height() * scale))), Image.INTERPOLATE_BILINEAR)
	var texture = ImageTexture.new()
	texture.create_from_image(image, Texture.FLAG_FILTER)
	_textures[cache_key] = texture
	_touch(cache_key)
	while _recent.size() > CACHE_LIMIT:
		_textures.erase(_recent.pop_front())
	return texture

func cache_size():
	return _textures.size()

func _touch(cache_key):
	_recent.erase(cache_key)
	_recent.append(cache_key)

func _key(path):
	return path.to_lower() if OS.get_name() == "Windows" else path

func _inside(path):
	return root != "" and path != "" and _key(path).begins_with(_key(root).rstrip("/") + "/")

func _absolute(path):
	if typeof(path) != TYPE_STRING or path.strip_edges() == "" or "\n" in path or "\r" in path:
		return ""
	var normalized = path.replace("\\", "/")
	if ".." in normalized.split("/", false):
		return ""
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		normalized = ProjectSettings.globalize_path(normalized)
	elif not normalized.is_abs_path():
		normalized = ProjectSettings.globalize_path("res://").plus_file(normalized)
	return normalized.replace("\\", "/").simplify_path().rstrip("/")

func _windows_prefix(path):
	# Single-quoted PowerShell literals keep user paths separate from executable code.
	return "$ErrorActionPreference='Stop'; $p='" + path.replace("'", "''") + "'; " + \
		"function SafePath($value) { while ($value) { $item=Get-Item -LiteralPath $value -Force; if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }; $value=[IO.Path]::GetDirectoryName($value) }; return $true }; " + \
		"try { if (-not (SafePath $p)) { exit 1 }; "

func _powershell(script):
	var output = []
	var result = OS.execute("powershell.exe", ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script + " } catch { exit 1 }"], true, output, false, false)
	if result != 0 or output.empty():
		return null
	var parsed = JSON.parse(output[0])
	return parsed.result if parsed.error == OK else null

func _safe_files(path):
	# Godot 3.5 has no lstat/reparse API. Fail closed if platform metadata is unavailable.
	if OS.get_name() == "Windows":
		var script = _windows_prefix(path) + \
			"$pending=New-Object 'System.Collections.Generic.Stack[string]'; $pending.Push($p); $files=New-Object 'System.Collections.Generic.List[string]'; " + \
			"while ($pending.Count -gt 0) { foreach ($entry in Get-ChildItem -LiteralPath $pending.Pop() -Force) { " + \
			"if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }; " + \
			"if ($entry.PSIsContainer) { $pending.Push($entry.FullName) } elseif ($entry.Extension.ToLowerInvariant() -in @('.jpg','.jpeg','.png','.webp')) { $files.Add($entry.FullName) } } }; " + \
			"ConvertTo-Json -InputObject @($files.ToArray()) -Compress"
		var result = _powershell(script)
		return result if typeof(result) == TYPE_ARRAY else null
	if OS.get_name() in ["X11", "OSX", "Server"]:
		var output = []
		var script = "p=$1; while [ -n \"$p\" ] && [ \"$p\" != / ]; do [ ! -L \"$p\" ] || exit 1; p=${p%/*}; done; find \"$1\" -type f -print"
		if OS.execute("/bin/sh", ["-c", script, "sob-art", path], true, output, false, false) != 0 or output.empty():
			return null
		var paths = []
		for item in output[0].split("\n", false):
			if item.get_extension().to_lower() in EXTENSIONS:
				paths.append(item)
		return paths
	return null

func _safe_file(path):
	if not File.new().file_exists(path):
		return false
	if OS.get_name() == "Windows":
		return _powershell(_windows_prefix(path) + "if ((Get-Item -LiteralPath $p -Force).PSIsContainer) { exit 1 }; 'true'") == true
	if OS.get_name() in ["X11", "OSX", "Server"]:
		var script = "[ -f \"$1\" ] || exit 1; p=$1; while [ -n \"$p\" ] && [ \"$p\" != / ]; do [ ! -L \"$p\" ] || exit 1; p=${p%/*}; done"
		return OS.execute("/bin/sh", ["-c", script, "sob-art", path], true, [], false, false) == 0
	return false
