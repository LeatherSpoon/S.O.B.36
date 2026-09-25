extends SceneTree

var count = 0
var failures = []

func check(condition, label):
	count += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func equal(a, b):
	return JSON.print(a, "", true) == JSON.print(b, "", true)

func _init():
	for path in ["res://tests/core_suite.gd", "res://tests/content_suite.gd", "res://tests/input_suite.gd", "res://tests/save_edges_suite.gd", "res://tests/content_edges_suite.gd"]:
		var script = load(path)
		check(script != null and script.can_instance(), "suite loads: " + path)
		if script != null and script.can_instance():
			check(script.new().run(self) == true, "suite completed: " + path)
	print("Assertions: ", count, "; failures: ", failures.size())
	quit(0 if failures.empty() else 1)
