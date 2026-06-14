class_name SettingsMenu
extends CanvasLayer
## In-flight options overlay (Presentation). Opens on the PS5 Options button / Esc,
## pauses solo play (co-op keeps running), frees the mouse, and lets the pilot
## toggle and tune the HUD flight markers. Gamepad-navigable; edits the Settings
## autoload live, so the HUD updates the instant a control changes.

const MENU_BASE_FONT := 16   # menu text size at text_scale 1.0

var _open: bool = false
var _first_focus: Control
var _theme: Theme            # scales the whole menu from Settings.text_scale

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep working while the tree is paused
	layer = 50                                # above the HUD
	MenuNav.enable_gamepad_ui()               # left stick / D-pad / face buttons in menus
	_build()
	# The whole menu scales with the same "HUD text size" the pilot sets, live.
	Settings.changed.connect(_apply_scale)
	_apply_scale()
	visible = false

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # swallow clicks/steering behind the menu
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	# A theme on the panel scales every descendant's text + icons together; _apply_scale
	# drives its size from Settings.text_scale. (The dim is a sibling, so it's untouched.)
	_theme = Theme.new()
	panel.theme = _theme
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := Label.new()
	title.text = "OPTIONS — HUD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(HSeparator.new())

	_first_focus = _add_check(col, "Aim crosshair", "hud_crosshair")
	_add_check(col, "Velocity markers (prograde / retrograde)", "hud_velocity")
	_add_check(col, "Lead pip (firing solution)", "hud_lead")
	_add_slider(col, "Marker size", "marker_scale", 0.5, 2.0, 0.05)
	_add_slider(col, "Marker opacity", "marker_opacity", 0.1, 1.0, 0.05)
	_add_slider(col, "HUD text size", "text_scale", 0.7, 2.5, 0.05)

	col.add_child(HSeparator.new())
	var resume := Button.new()
	resume.text = "Resume   (Esc / Options / ○)"
	resume.focus_mode = Control.FOCUS_ALL
	resume.pressed.connect(close)
	col.add_child(resume)

func _add_check(parent: Node, label: String, key: String) -> CheckButton:
	var cb := CheckButton.new()
	cb.text = label
	cb.focus_mode = Control.FOCUS_ALL
	cb.button_pressed = bool(Settings.get(key))
	cb.toggled.connect(_on_check_toggled.bind(key))
	parent.add_child(cb)
	return cb

func _add_slider(parent: Node, label: String, key: String, min_v: float, max_v: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(170, 0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = float(Settings.get(key))
	slider.focus_mode = Control.FOCUS_ALL
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200, 0)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = "%.2f" % slider.value
	value_label.custom_minimum_size = Vector2(48, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(_on_slider_changed.bind(key, value_label))

## Scale the whole menu (text via default_font_size, icons/grabbers/padding via
## default_base_scale) to match the pilot's HUD text size. Re-runs live whenever a
## setting changes, so dragging "HUD text size" resizes this menu in real time.
func _apply_scale() -> void:
	if _theme == null:
		return
	var s: float = Settings.text_scale
	_theme.default_font_size = roundi(MENU_BASE_FONT * s)
	_theme.default_base_scale = s

func _on_check_toggled(pressed: bool, key: String) -> void:
	Settings.set(key, pressed)
	Settings.notify_changed()

func _on_slider_changed(value: float, key: String, value_label: Label) -> void:
	Settings.set(key, value)
	value_label.text = "%.2f" % value
	Settings.notify_changed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_settings"):
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	Settings.input_locked = true                 # ship/weapon stand down; capture loop too
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not Net.active:
		get_tree().paused = true                 # full freeze in solo; co-op can't pause
	if _first_focus != null:
		_first_focus.grab_focus()

func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	Settings.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # main's capture loop keeps it grabbed
