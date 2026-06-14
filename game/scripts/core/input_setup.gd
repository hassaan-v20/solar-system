class_name InputSetup
extends RefCounted
## Registers all gameplay input actions in code (keyboard/mouse + gamepad), so both
## the raid (main) and the flyable lobby share one binding source. Idempotent —
## InputMap persists across scene changes, so configuring once per run is enough.

static var _done := false

static func configure() -> void:
	if _done:
		return
	_done = true

	var binds := {
		"thrust_forward": [KEY_W],
		"thrust_back": [KEY_S],
		"strafe_left": [KEY_Q],
		"strafe_right": [KEY_E],
		"thrust_up": [KEY_SPACE],
		"thrust_down": [KEY_C],
		"roll_left": [KEY_A],
		"roll_right": [KEY_D],
		"boost": [KEY_SHIFT],
		"brake": [KEY_CTRL],
		"toggle_assist": [KEY_Z],
		"dock": [KEY_F],
		"toggle_settings": [KEY_ESCAPE],
		"toggle_fullscreen": [KEY_F11],
		"quit_game": [KEY_F8],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

	# Primary fire on the left mouse button (works while the mouse is captured).
	if not InputMap.has_action("fire_primary"):
		InputMap.add_action("fire_primary")
	var fire_ev := InputEventMouseButton.new()
	fire_ev.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire_primary", fire_ev)

	_configure_gamepad()

## Gamepad (DualSense / any SDL-mapped pad), bound to the SAME actions as the
## keyboard/mouse. Right stick steers as a turn rate (ShipController._integrate_rotation).
static func _configure_gamepad() -> void:
	var pad_buttons := {
		"roll_left": JOY_BUTTON_LEFT_SHOULDER,     # L1
		"roll_right": JOY_BUTTON_RIGHT_SHOULDER,   # R1
		"brake": JOY_BUTTON_B,                      # Circle
		"toggle_assist": JOY_BUTTON_X,             # Square
		"toggle_settings": JOY_BUTTON_START,       # Options
		"dock": JOY_BUTTON_A,                       # Cross
	}
	for action in pad_buttons:
		var be := InputEventJoypadButton.new()
		be.button_index = pad_buttons[action]
		InputMap.action_add_event(action, be)

	var pad_axes := {
		"thrust_forward": [JOY_AXIS_LEFT_Y, -1.0],
		"thrust_back": [JOY_AXIS_LEFT_Y, 1.0],
		"strafe_left": [JOY_AXIS_LEFT_X, -1.0],
		"strafe_right": [JOY_AXIS_LEFT_X, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0],
		"look_right": [JOY_AXIS_RIGHT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
		"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"boost": [JOY_AXIS_TRIGGER_LEFT, 1.0],     # L2
		"fire_primary": [JOY_AXIS_TRIGGER_RIGHT, 1.0],  # R2
	}
	for action in pad_axes:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var me := InputEventJoypadMotion.new()
		me.axis = pad_axes[action][0]
		me.axis_value = pad_axes[action][1]
		InputMap.action_add_event(action, me)
		InputMap.action_set_deadzone(action, 0.2)
