extends Reference

func run(t):
	var script = load("res://app/input/controls.gd")
	t.check(script != null, "input abstraction exists")
	if script == null:
		return
	script.install()
	for action in ["move_left", "move_right", "move_up", "move_down", "confirm", "save_campaign", "load_campaign", "new_campaign"]:
		var keyboard = false
		var controller = false
		for event in InputMap.get_action_list(action):
			keyboard = keyboard or event is InputEventKey
			controller = controller or event is InputEventJoypadButton
		t.check(keyboard and controller, "keyboard + controller binding: " + action)

	return true
