extends Reference
const Schema = preload("res://content/loaders/schema.gd")
var packs = {}
var records = {}
var enabled_ids = []
var schema = Schema.new()

func read_json(path):
	var file = File.new()
	if file.open(path, File.READ) != OK:
		return {"ok": false, "error": "Cannot read " + path}
	var parsed = JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK:
		return {"ok": false, "error": "Invalid JSON: " + path}
	return {"ok": true, "value": parsed.result}

func dependency_errors(manifests, enabled):
	var errors = []
	for id in enabled:
		if not manifests.has(id):
			errors.append("Missing pack: " + str(id))
			continue
		for dependency in manifests[id].dependencies:
			if not dependency.id in enabled or not manifests.has(dependency.id):
				errors.append("Missing or disabled dependency: " + dependency.id)
			elif manifests[dependency.id].version != dependency.version:
				errors.append("Dependency version mismatch: " + dependency.id)
	if not errors.empty():
		return errors
	var visiting = []
	var done = []
	for id in enabled:
		if cycle(id, manifests, visiting, done):
			return ["Content dependency cycle"]
	return errors

func cycle(id, manifests, visiting, done):
	if id in visiting:
		return true
	if id in done:
		return false
	visiting.append(id)
	for dependency in manifests[id].dependencies:
		if cycle(dependency.id, manifests, visiting, done):
			return true
	visiting.erase(id)
	done.append(id)
	return false

func load_packs(root, enabled, edition_id = ""):
	packs = {}
	records = {}
	enabled_ids = []
	var dir = Directory.new()
	if dir.open(root) != OK:
		return fail("Cannot discover pack directory")
	var folders = []
	dir.list_dir_begin(true, true)
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			folders.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	folders.sort()
	var manifests = {}
	var paths = {}
	for folder in folders:
		var manifest_path = root.plus_file(folder).plus_file("manifest.json")
		if not dir.file_exists(manifest_path):
			continue
		var parsed = read_json(manifest_path)
		if not parsed.ok:
			return fail(parsed.error)
		var errors = schema.manifest_errors(parsed.value)
		if not errors.empty():
			return fail(folder + ": " + errors[0])
		var manifest = parsed.value
		if manifests.has(manifest.id):
			return fail("Duplicate pack ID: " + manifest.id)
		manifests[manifest.id] = manifest
		paths[manifest.id] = root.plus_file(folder)
	var selected = []
	for id in enabled:
		if typeof(id) != TYPE_STRING or id in selected:
			return fail("Invalid or duplicate enabled pack")
		selected.append(id)
	selected.sort()
	var errors = dependency_errors(manifests, selected)
	if not errors.empty():
		return fail(errors[0])
	var next_records = {}
	var next_packs = {}
	for id in selected:
		var manifest = manifests[id]
		if edition_id != "" and not manifest.supported_editions.empty() and not edition_id in manifest.supported_editions:
			return fail("Pack does not support edition: " + id)
		var files = manifest.content_files.duplicate()
		files.sort()
		for filename in files:
			var parsed = read_json(paths[id].plus_file(filename))
			if not parsed.ok:
				return fail(parsed.error)
			if typeof(parsed.value) != TYPE_ARRAY:
				return fail("Content file must be an array: " + filename)
			for record in parsed.value:
				errors = schema.record_errors(record, id)
				if not errors.empty():
					return fail(filename + ": " + errors[0])
				if next_records.has(record.id):
					return fail("Duplicate record ID: " + record.id)
				next_records[record.id] = record
		next_packs[id] = manifest
	packs = next_packs
	records = next_records
	enabled_ids = selected
	return {"ok": true, "errors": [], "packs": packs.duplicate(true), "records": records.duplicate(true)}

func for_rules(id):
	if not records.has(id) or records[id].status != "verified":
		return null
	return records[id].duplicate(true)

func fail(message):
	return {"ok": false, "error": message, "errors": [message], "packs": {}, "records": {}}
