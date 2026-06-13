extends Control
## Post-raid results (GDD §26.4 / §26.5). Reads PlayerProfile.last_run, shows the
## outcome + credit breakdown, then returns to Kestrel Station.

const STATION_SCENE := "res://scenes/station/station_hub.tscn"

var _return_button: Button
var _hint_label: Label
var _current_device := MenuNav.DEVICE_NONE

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuNav.enable_gamepad_ui()
	_build_ui()
	_return_button.grab_focus.call_deferred()
	_current_device = MenuNav.DEVICE_GAMEPAD if MenuNav.gamepad_connected() else MenuNav.DEVICE_KBM
	_update_hint()

func _input(event: InputEvent) -> void:
	var d := MenuNav.device_of(event)
	if d != MenuNav.DEVICE_NONE and d != _current_device:
		_current_device = d
		_update_hint()

func _update_hint() -> void:
	_hint_label.text = MenuNav.hint_text(_current_device)

func _build_ui() -> void:
	var r: Dictionary = PlayerProfile.last_run
	var success := bool(r.get("success", false))

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var title := Label.new()
	title.text = "MISSION COMPLETE" if success else "MISSION FAILED"
	title.modulate = Color(0.4, 1.0, 0.5) if success else Color(1.0, 0.4, 0.3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var lines := [
		"Drones destroyed:  %d" % int(r.get("drones_killed", 0)),
		"Data Core:  %s" % ("recovered" if r.get("data_core", false) else "lost"),
		"Credits earned:  %d" % int(r.get("credits_earned", 0)),
		"Balance:  %d cr" % PlayerProfile.credits,
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(lbl)

	_return_button = Button.new()
	_return_button.text = "Return to Kestrel Station"
	_return_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(STATION_SCENE))
	box.add_child(_return_button)

	# Device-aware navigation guide, pinned to the bottom.
	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -34
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.modulate = Color(1, 1, 1, 0.55)
	add_child(_hint_label)
