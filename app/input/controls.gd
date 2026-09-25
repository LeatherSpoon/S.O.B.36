extends Reference
# Logical actions are shared by keyboard and Godot's mapped gamepad API.
static func install():
	bind("move_left", [KEY_LEFT, KEY_A], JOY_DPAD_LEFT, JOY_AXIS_0, -1.0)
	bind("move_right", [KEY_RIGHT, KEY_D], JOY_DPAD_RIGHT, JOY_AXIS_0, 1.0)
	bind("move_up", [KEY_UP, KEY_W], JOY_DPAD_UP, JOY_AXIS_1, -1.0)
	bind("move_down", [KEY_DOWN, KEY_S], JOY_DPAD_DOWN, JOY_AXIS_1, 1.0)
	bind("confirm", [KEY_ENTER, KEY_SPACE], JOY_BUTTON_0)
	bind("save_campaign", [KEY_F5], JOY_BUTTON_2)
	bind("load_campaign", [KEY_F9], JOY_BUTTON_3)
	bind("new_campaign", [KEY_N], JOY_START)
	bind("cancel", [KEY_ESCAPE], JOY_BUTTON_1)

static func bind(action, keys, button, axis = -1, value = 0.0):
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	InputMap.action_erase_events(action)
	for key in keys:
		var event = InputEventKey.new()
		event.scancode = key
		InputMap.action_add_event(action, event)
	var joy = InputEventJoypadButton.new()
	joy.button_index = button
	InputMap.action_add_event(action, joy)
	if axis >= 0:
		var motion = InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = value
		InputMap.action_add_event(action, motion)
