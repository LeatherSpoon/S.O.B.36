extends Reference

func write_json(path, data):
	Directory.new().make_dir_recursive(path.get_base_dir())
	var f = File.new()
	assert(f.open(path, File.WRITE) == OK)
	f.store_string(JSON.print(data))
	f.close()

func run(t):
	var Loader = load("res://content/loaders/pack_loader.gd")
	var loader = Loader.new()
	var root = "res://.local/pack-tests"
	var manifest = {"schema_version": 1, "id": "test", "name": "Test", "version": "1",
		"dependencies": [], "supported_editions": ["fixture-edition"], "content_files": ["records.json"]}
	var record = {"schema_version": 1, "id": "test.enemy", "pack_id": "test", "type": "Enemy",
		"status": "verified", "source_ref": "original/test", "data": {"hp": 2, "xp": 1}}
	write_json(root + "/test/manifest.json", manifest)
	write_json(root + "/test/records.json", [record])
	t.check(loader.load_packs(root, ["test"], "fixture-edition").ok, "external pack discovers and validates")
	t.check(not loader.load_packs(root, ["test"], "other-edition").ok, "explicit unsupported edition rejected")
	t.check(not loader.load_packs(root, ["test", "test"]).ok, "duplicate enabled IDs rejected")
	write_json(root + "/test/records.json", [record, record])
	t.check(not loader.load_packs(root, ["test"]).ok, "duplicate record IDs rejected")
	record.status = "identified"
	write_json(root + "/test/records.json", [record])
	t.check(loader.load_packs(root, ["test"]).ok and loader.for_rules("test.enemy") == null, "unverified imports retained but never exposed to rules")
	record.status = "verified"
	record.data.hp = 0
	write_json(root + "/test/records.json", [record])
	t.check(not loader.load_packs(root, ["test"]).ok, "record payload schema enforced")
	record.data.hp = 2
	record.erase("source_ref")
	write_json(root + "/test/records.json", [record])
	t.check(not loader.load_packs(root, ["test"]).ok, "source provenance required")
	manifest.content_files = ["missing.json"]
	write_json(root + "/test/manifest.json", manifest)
	t.check(not loader.load_packs(root, ["test"]).ok, "missing declared content file rejected")
	t.check(loader.records.empty() and loader.packs.empty(), "failed load publishes no partial pack state")
	manifest.content_files = ["records.json"]
	manifest.dependencies = [{"id": "absent", "version": "1"}]
	write_json(root + "/test/manifest.json", manifest)
	t.check(not loader.load_packs(root, ["test"]).ok, "actual missing dependency fails load")
	var original = loader.read_json("res://content/packs/placeholder/manifest.json").value
	var fixtures = loader.read_json("res://content/packs/placeholder/records.json").value
	var bad_root = "res://.local/bad-start"
	write_json(bad_root + "/placeholder/manifest.json", original)
	fixtures[0].data.connections.append(["missing", "first_0"])
	write_json(bad_root + "/placeholder/records.json", fixtures)
	var Game = load("res://core/campaign/game_state.gd")
	t.check(not Game.new().start(1, bad_root).ok, "bad assembled topology rejected before startup")
	fixtures[0].data.connections.pop_back()
	fixtures[1].data.spaces[0].id = "first_0"
	write_json(bad_root + "/placeholder/records.json", fixtures)
	t.check(not Game.new().start(1, bad_root).ok, "duplicate assembled map space IDs rejected")
	return true
