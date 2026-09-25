extends Reference
const Game = preload("res://core/campaign/game_state.gd")
const VERSION = 1

func encode(game):
	return JSON.print({"format": "sob36.campaign", "save_version": VERSION, "state": game.to_data()}, "  ", true)

func decode(text):
	var parsed = JSON.parse(text)
	if parsed.error != OK:
		return {"ok": false, "error": "Invalid save JSON"}
	var envelope = parsed.result
	if typeof(envelope) != TYPE_DICTIONARY or envelope.size() != 3 or envelope.get("format") != "sob36.campaign":
		return {"ok": false, "error": "Invalid save envelope"}
	if not preload("res://core/save/state_validator.gd").integer(envelope.get("save_version"), VERSION, VERSION):
		return {"ok": false, "error": "Unsupported save version; migration required"}
	return Game.from_data(envelope.get("state"))

func write(path, game):
	var errors = game.validate()
	if not errors.empty():
		return {"ok": false, "error": errors[0]}
	var dir = Directory.new()
	var err = dir.make_dir_recursive(path.get_base_dir())
	if err != OK:
		return {"ok": false, "error": "Cannot create save directory"}
	var temporary = path + ".tmp"
	var backup = path + ".bak"
	var file = File.new()
	err = file.open(temporary, File.WRITE)
	if err != OK:
		return {"ok": false, "error": "Cannot write save"}
	file.store_string(encode(game))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "error": "Save write failed"}
	# Validate the complete staged file before replacing the current save.
	var verification = read(temporary)
	if not verification.ok:
		return verification
	if dir.file_exists(backup):
		if dir.remove(backup) != OK:
			return {"ok": false, "error": "Cannot replace save backup"}
	if dir.file_exists(path):
		if dir.rename(path, backup) != OK:
			return {"ok": false, "error": "Cannot preserve previous save"}
	err = dir.rename(temporary, path)
	if err != OK:
		if dir.file_exists(backup):
			dir.rename(backup, path)
		return {"ok": false, "error": "Cannot install new save"}
	return {"ok": true, "error": ""}

func read(path):
	var file = File.new()
	if file.open(path, File.READ) != OK:
		return {"ok": false, "error": "No readable save at " + path}
	var text = file.get_as_text()
	file.close()
	return decode(text)
