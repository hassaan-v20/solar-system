class_name InputSetup
extends RefCounted
## Registers all gameplay input actions in code (so project.godot stays clean and
## the raid + station hub share one binding set).

static var _registered := false

static func register() -> void:
	if _registered:
		return  # InputMap is global & persists; registering once per run is enough
	_registered = true
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
	_setup_gamepad()

# ── gamepad (PS5 DualSense & other controllers) ────────────────────────────────
# Left stick flies (thrust + strafe), right stick steers the nose (read in
# ShipController._steer), shoulders roll, triggers fire. Analog axes feed the
# same actions the keys do; Triangle opens station kiosks.
static func _setup_gamepad() -> void:
	# Sticks are analog: tighten the 0.5 default deadzone so small deflections register.
	for a in ["thrust_forward", "thrust_back", "strafe_left", "strafe_right"]:
		InputMap.action_set_deadzone(a, 0.2)
	_pad_axis("thrust_forward", JOY_AXIS_LEFT_Y, -1.0)  # left stick up
	_pad_axis("thrust_back",    JOY_AXIS_LEFT_Y,  1.0)
	_pad_axis("strafe_left",    JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("strafe_right",   JOY_AXIS_LEFT_X,  1.0)
	for a in ["look_left", "look_right", "look_up", "look_down"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
	_pad_axis("look_left",  JOY_AXIS_RIGHT_X, -1.0)
	_pad_axis("look_right", JOY_AXIS_RIGHT_X,  1.0)
	_pad_axis("look_up",    JOY_AXIS_RIGHT_Y, -1.0)
	_pad_axis("look_down",  JOY_AXIS_RIGHT_Y,  1.0)
	_pad_btn("roll_left",       JOY_BUTTON_LEFT_SHOULDER)    # L1
	_pad_btn("roll_right",      JOY_BUTTON_RIGHT_SHOULDER)   # R1
	_pad_btn("boost",           JOY_BUTTON_A)                # ✕ Cross
	_pad_btn("brake",           JOY_BUTTON_B)                # ○ Circle
	_pad_btn("interact",        JOY_BUTTON_Y)                # △ Triangle — kiosks
	_pad_btn("toggle_mouse",    JOY_BUTTON_START)            # Options
	_pad_axis("fire",           JOY_AXIS_TRIGGER_RIGHT, 1.0) # R2 — laser
	_pad_axis("fire_secondary", JOY_AXIS_TRIGGER_LEFT,  1.0) # L2 — missile

static func _pad_btn(action: String, button: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)

static func _pad_axis(action: String, axis: int, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)
