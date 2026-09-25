extends Reference
const TYPES = ["Campaign", "Party", "Hero", "HeroClass", "Ability", "Item", "Card",
	"Enemy", "EnemyGroup", "Encounter", "Threat", "Mission", "World", "Location",
	"Town", "TownLocation", "MapTile", "MapSpace", "MapConnection", "Deck",
	"StatusEffect", "ExpansionPack"]
const Validate = preload("res://core/save/state_validator.gd")

func safe_path(path):
	if typeof(path) != TYPE_STRING or path.empty() or path.begins_with("/") or ":" in path or "\\" in path:
		return false
	for part in path.split("/"):
		if part in ["", ".", ".."]:
			return false
	return path.ends_with(".json")

func stable_id(value):
	if typeof(value) != TYPE_STRING or value.empty():
		return false
	for c in value:
		if not c in "abcdefghijklmnopqrstuvwxyz0123456789._-":
			return false
	return true

func manifest_errors(value):
	if not Validate.fields(value, ["schema_version", "id", "name", "version", "dependencies", "supported_editions", "content_files"]):
		return ["Manifest fields do not match schema"]
	if not Validate.integer(value.schema_version, 1, 1) or not stable_id(value.id) or typeof(value.name) != TYPE_STRING or value.name.empty() or typeof(value.version) != TYPE_STRING or value.version.empty():
		return ["Invalid manifest identity/version"]
	for key in ["dependencies", "supported_editions", "content_files"]:
		if typeof(value[key]) != TYPE_ARRAY:
			return ["Manifest " + key + " must be an array"]
	var seen = []
	for dependency in value.dependencies:
		if not Validate.fields(dependency, ["id", "version"]) or not stable_id(dependency.id) or typeof(dependency.version) != TYPE_STRING or dependency.version.empty() or dependency.id in seen:
			return ["Invalid or duplicate dependency"]
		seen.append(dependency.id)
	seen = []
	for edition in value.supported_editions:
		if typeof(edition) != TYPE_STRING or edition.empty() or edition in seen:
			return ["Invalid or duplicate edition"]
		seen.append(edition)
	seen = []
	for path in value.content_files:
		if not safe_path(path) or path in seen:
			return ["Unsafe or duplicate content path"]
		seen.append(path)
	if value.content_files.empty():
		return ["Pack needs at least one content file"]
	return []

func record_errors(value, pack_id):
	if not Validate.fields(value, ["schema_version", "id", "pack_id", "type", "status", "source_ref", "data"]):
		return ["Record fields do not match schema"]
	if not Validate.integer(value.schema_version, 1, 1) or not stable_id(value.id) or value.pack_id != pack_id or not value.id.begins_with(pack_id + "."):
		return ["Invalid record identity/provenance"]
	if not value.type in TYPES or not value.status in ["imported", "identified", "verified"]:
		return ["Invalid record type/status"]
	if typeof(value.source_ref) != TYPE_STRING or value.source_ref.empty() or value.source_ref.begins_with("/") or ":" in value.source_ref or "\\" in value.source_ref or ".." in value.source_ref.split("/"):
		return ["Source reference must be a local logical relative reference"]
	if typeof(value.data) != TYPE_DICTIONARY:
		return ["Record data must be an object"]
	if value.type == "Enemy":
		if not Validate.fields(value.data, ["hp", "xp"]) or not Validate.integer(value.data.hp, 1, 10000) or not Validate.integer(value.data.xp, 0, 10000):
			return ["Invalid placeholder enemy data"]
	if value.type == "MapTile":
		if not Validate.fields(value.data, ["spaces", "connections"]) or typeof(value.data.spaces) != TYPE_ARRAY or value.data.spaces.empty() or typeof(value.data.connections) != TYPE_ARRAY:
			return ["Invalid map tile data"]
		var ids = []
		for space in value.data.spaces:
			if not Validate.fields(space, ["id", "tile", "x", "y"]) or not stable_id(space.id) or not stable_id(space.tile) or not Validate.integer(space.x, 0, 20) or not Validate.integer(space.y, 0, 20) or space.id in ids:
				return ["Invalid or duplicate map space"]
			ids.append(space.id)
		for edge in value.data.connections:
			if typeof(edge) != TYPE_ARRAY or edge.size() != 2 or not stable_id(edge[0]) or not stable_id(edge[1]) or edge[0] == edge[1]:
				return ["Invalid map connection"]
	return []
