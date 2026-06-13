class_name MenuNav
extends RefCounted
## Shared helpers for the code-built menus (station + results): gamepad UI
## navigation, and device-aware control hints that follow the active input.

const DEVICE_NONE := -1
const DEVICE_KBM := 0
const DEVICE_GAMEPAD := 1

static var _ui_bound := false

## Adds left-stick / D-pad / face-button events to Godot's built-in ui_* actions
## so menus are navigable by gamepad (focus still has to be granted by the scene).
## Idempotent across scene changes.
static func enable_gamepad_ui() -> void:
	if _ui_bound:
		return
	_ui_bound = true
	_add_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_add_button("ui_up", JOY_BUTTON_DPAD_UP)
	_add_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_button("ui_accept", JOY_BUTTON_A)   # Cross
	_add_button("ui_cancel", JOY_BUTTON_B)   # Circle

static func gamepad_connected() -> bool:
	return not Input.get_connected_joypads().is_empty()

## Which device an event came from, or DEVICE_NONE if it shouldn't flip the hint
## (e.g. mouse motion, or idle stick drift).
static func device_of(event: InputEvent) -> int:
	if event is InputEventJoypadButton:
		return DEVICE_GAMEPAD
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		return DEVICE_GAMEPAD
	if event is InputEventKey or event is InputEventMouseButton:
		return DEVICE_KBM
	return DEVICE_NONE

static func hint_text(device: int) -> String:
	if device == DEVICE_GAMEPAD:
		return "Left stick / D-pad: navigate      ✕: select      ○: back"
	return "↑ ↓: navigate      Enter / click: select      Esc: back"

static func _add_axis(action: StringName, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		return
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
	InputMap.action_set_deadzone(action, 0.5)

static func _add_button(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
