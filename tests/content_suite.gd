extends Reference

func run(t):
	var script = load("res://content/loaders/pack_loader.gd")
	t.check(script != null, "pack loader exists")
	if script == null:
		return
	var loader = script.new()
	var result = loader.load_packs("res://content/packs", ["placeholder"])
	t.check(result.ok, "discover and validate placeholder pack")
	t.check(result.records.size() == 3, "all placeholder content files discovered")
	t.check(loader.for_rules("placeholder.enemy") != null, "verified content allowed")
	loader.records["placeholder.enemy"].status = "identified"
	t.check(loader.for_rules("placeholder.enemy") == null, "unverified content blocked")
	t.check(not loader.load_packs("res://content/packs", ["missing"]).ok, "missing enabled pack rejected")
	t.check(loader.load_packs("res://content/packs", []).records.empty(), "disabled packs contribute no records")
	var schema = load("res://content/loaders/schema.gd").new()
	var manifest = {"schema_version": 1, "id": "test", "name": "Test", "version": "0.1.0", "dependencies": [], "supported_editions": [], "content_files": ["records.json"]}
	t.check(schema.manifest_errors(manifest).empty(), "manifest schema accepts valid pack")
	manifest.content_files = ["../private.json"]
	t.check(not schema.manifest_errors(manifest).empty(), "path traversal rejected")
	manifest.content_files = ["C:/private.json"]
	t.check(not schema.manifest_errors(manifest).empty(), "absolute content path rejected")
	manifest.content_files = ["records.json"]
	manifest.schema_version = 2
	t.check(not schema.manifest_errors(manifest).empty(), "unsupported schema rejected")
	var a = {"id": "a", "version": "1", "dependencies": [{"id": "b", "version": "1"}]}
	var b = {"id": "b", "version": "1", "dependencies": [{"id": "a", "version": "1"}]}
	t.check(not loader.dependency_errors({"a": a, "b": b}, ["a", "b"]).empty(), "dependency cycle rejected")
	t.check(not loader.dependency_errors({"a": a, "b": b}, ["a"]).empty(), "disabled dependency rejected")
	b.dependencies = []
	b.version = "2"
	t.check(not loader.dependency_errors({"a": a, "b": b}, ["a", "b"]).empty(), "dependency version mismatch rejected")

	return true
