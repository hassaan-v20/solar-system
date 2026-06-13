class_name InputSetup
extends RefCounted
## Registers all gameplay input actions in code (so project.godot stays clean and
## the raid + station hub share one binding set).

static func register() -> void:
	var binds := {
		"thrust_forward": [KEY_W], "thrust_back": [KEY_S],
		"strafe_left": [KEY_Q], "strafe_right": [KEY_E],
		"roll_left": [KEY_A], "roll_right": [KEY_D],
		"boost": [KEY_SHIFT], "brake": [KEY_CTRL],
		"fire": [KEY_SPACE],
		"interact": [KEY_F],
		"toggle_mouse": [KEY_ESCAPE], "quit_game": [KEY_F8],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# Left mouse fires the laser.
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", mb)
	# Secondary fire (missile): right mouse.
	if not InputMap.has_action("fire_secondary"):
		InputMap.add_action("fire_secondary")
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("fire_secondary", rmb)
