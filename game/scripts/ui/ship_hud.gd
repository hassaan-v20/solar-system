class_name ShipHUD
extends CanvasLayer
## Minimal flight HUD (Presentation). Built in code for Milestone 1; it becomes a
## proper .tscn with role-specific panels in later milestones (GDD §19).

@export var ship: ShipController
@export var camera: Camera3D   # set by main; used to project the flight markers

const MARKER_BASE_FONT := 18           # glyph size at marker_scale 1.0
const MARKER_BASE_SIZE := Vector2(44, 26)
const HUD_BASE_FONT := 16              # readout text size at text_scale 1.0

var _root: Control
var _crosshair: Label   # where the nose points (aim)
var _prograde: Label    # the direction you're actually moving
var _retrograde: Label  # directly away from your velocity (point here + thrust to kill speed)
var _lead: Label        # lead pip: aim here to hit the tracked target
var _marker_styles: Array = []   # [{label, color}] for the uniform size/opacity pass
var _text_labels: Array = []     # readout labels scaled by Settings.text_scale
# Per-marker visibility, driven by the options menu (Settings).
var _show_crosshair: bool = true
var _show_velocity: bool = true
var _show_lead: bool = true
var _hull_label: Label
var _shield_label: Label
var _speed_label: Label
var _boost_label: Label
var _assist_label: Label
var _heat_label: Label
var _enemies_label: Label
var _cargo_label: Label
var _threat_label: Label
var _objective_label: Label
var _heat: float = 0.0          # escalating-threat level, 0..1 (from HeatDirector)
var _timer_label: Label
var _dock_label: Label
var _status_label: Label

func _ready() -> void:
	# Keep updating while the options menu pauses solo play, so marker tweaks
	# (size / opacity / on-off) preview live as the sliders move.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

	# Flight markers (projected from 3D each frame): aim crosshair, the prograde /
	# retrograde velocity vector, and a lead pip on the tracked target.
	_crosshair = _make_marker("+", Color(1, 1, 1))
	_prograde = _make_marker("(+)", Color(0.4, 1.0, 0.6))
	_retrograde = _make_marker("(-)", Color(0.5, 0.7, 0.9))
	_lead = _make_marker("[ ]", Color(1.0, 0.5, 0.3))

	var panel := VBoxContainer.new()
	panel.position = Vector2(28, 24)
	root.add_child(panel)
	_hull_label = _make_label(panel)
	_shield_label = _make_label(panel)
	_speed_label = _make_label(panel)
	_boost_label = _make_label(panel)
	_assist_label = _make_label(panel)
	_heat_label = _make_label(panel)
	_enemies_label = _make_label(panel)
	_cargo_label = _make_label(panel)
	_threat_label = _make_label(panel)

	# Mission objective banner (top-center).
	_objective_label = Label.new()
	_objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective_label.offset_top = 18
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_objective_label)

	# Meltdown countdown (top-center, under the objective; shown during extraction).
	_timer_label = Label.new()
	_timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_timer_label.offset_top = 46
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.visible = false
	root.add_child(_timer_label)

	# Docking prompt + end-of-mission status (both center; never shown together).
	_dock_label = Label.new()
	_dock_label.text = "PRESS F TO DOCK"
	_dock_label.set_anchors_preset(Control.PRESET_CENTER)
	_dock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_label.modulate = Color(0.5, 0.9, 1.0)
	_dock_label.visible = false
	root.add_child(_dock_label)

	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_CENTER)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.visible = false
	root.add_child(_status_label)

	EventBus.objective_updated.connect(func(t: String) -> void: _objective_label.text = t)
	EventBus.docking_available.connect(func(b: bool) -> void: _dock_label.visible = b)
	EventBus.extraction_timer_changed.connect(_on_extraction_timer)
	EventBus.mission_state_changed.connect(_on_mission_state)
	EventBus.heat_changed.connect(func(level: float) -> void: _heat = level)

	var hint := Label.new()
	hint.text = "W/S thrust   mouse aim   A/D roll   Q/E strafe   Space/C up·down   LMB fire   Shift boost   Ctrl brake   Z flight-assist   Esc/Options menu   F8 quit"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	root.add_child(hint)

	# Apply the saved HUD options now that every label + marker exists, and keep
	# them live as the options menu changes them. Readout text scales by text_scale;
	# the flight markers scale by their own marker_scale.
	_text_labels.append_array([_objective_label, _timer_label, _dock_label, _status_label, hint])
	Settings.changed.connect(_apply_hud_settings)
	_apply_hud_settings()

func _make_label(parent: Node) -> Label:
	var l := Label.new()
	parent.add_child(l)
	_text_labels.append(l)
	return l

## A centered glyph used as a projected world-space flight marker. Its base colour
## is recorded so _apply_hud_settings can scale size and opacity uniformly.
func _make_marker(glyph: String, color: Color) -> Label:
	var l := Label.new()
	l.text = glyph
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	_root.add_child(l)
	_marker_styles.append({"label": l, "color": color})
	return l

## Push the options-menu settings (Settings autoload) onto the HUD: marker on/off,
## marker size + opacity, and the readout text size. Called once at startup and on
## every change (live preview while the menu is open).
func _apply_hud_settings() -> void:
	_show_crosshair = Settings.hud_crosshair
	_show_velocity = Settings.hud_velocity
	_show_lead = Settings.hud_lead
	var sc: float = Settings.marker_scale
	var op: float = Settings.marker_opacity
	for style in _marker_styles:
		var l: Label = style["label"]
		var c: Color = style["color"]
		l.add_theme_font_size_override("font_size", roundi(MARKER_BASE_FONT * sc))
		l.custom_minimum_size = MARKER_BASE_SIZE * sc
		l.modulate = Color(c.r, c.g, c.b, op)
	var ts: float = Settings.text_scale
	var text_font := roundi(HUD_BASE_FONT * ts)
	for tl in _text_labels:
		(tl as Label).add_theme_font_size_override("font_size", text_font)

## Project the 3D flight markers to the screen. The markers live "out in space" at
## a fixed distance along their world directions, so they track as the ship turns.
func _update_markers() -> void:
	if camera == null or ship == null:
		return
	var origin := ship.global_position
	var fwd := -ship.global_transform.basis.z
	if _show_crosshair:
		_place(_crosshair, origin + fwd * 250.0)
	else:
		_crosshair.visible = false
	var v := ship.get_velocity()
	if _show_velocity and v.length() > 1.5:
		var vn := v.normalized()
		_place(_prograde, origin + vn * 250.0)
		_place(_retrograde, origin - vn * 250.0)
	else:
		_prograde.visible = false
		_retrograde.visible = false
	if _show_lead:
		_update_lead(origin, fwd, v)
	else:
		_lead.visible = false

func _place(marker: Label, world: Vector3) -> void:
	if camera.is_position_behind(world):
		marker.visible = false
		return
	marker.visible = true
	marker.position = camera.unproject_position(world) - marker.custom_minimum_size * 0.5

## Pick the nearest in-range target ahead of the ship and solve where to aim so a
## bolt (which inherits the ship's velocity) intercepts it. Same ballistics the
## drones use to lead the player.
func _update_lead(origin: Vector3, fwd: Vector3, vel: Vector3) -> void:
	_lead.visible = false
	if ship.weapon == null or ship.weapon.weapon_def == null:
		return
	var bs: float = maxf(1.0, ship.weapon.weapon_def.projectile_speed)
	var rng: float = ship.weapon.weapon_def.weapon_range
	var best: Node3D = null
	var best_d := rng
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D):
			continue
		var to: Vector3 = (e as Node3D).global_position - origin
		var d := to.length()
		if d < 0.001 or d > rng or fwd.dot(to / d) < 0.3:
			continue
		if d < best_d:
			best_d = d
			best = e as Node3D
	if best == null:
		return
	var p := best.global_position - origin
	var vt: Vector3 = best.get_velocity() if best.has_method("get_velocity") else Vector3.ZERO
	var t := _intercept_time(p, vt - vel, bs)
	if t <= 0.0:
		return
	var dir := (p + (vt - vel) * t) / (bs * t)
	if dir.length() < 0.001:
		return
	_place(_lead, origin + dir.normalized() * best_d)

## Smallest positive time at which a bolt of muzzle speed `bs` intercepts a target
## at relative position `p` closing at relative velocity `vrel`. 0 = no solution.
func _intercept_time(p: Vector3, vrel: Vector3, bs: float) -> float:
	var a := bs * bs - vrel.length_squared()
	var pv := p.dot(vrel)
	if absf(a) < 0.0001:
		return -p.length_squared() / (2.0 * pv) if absf(pv) > 0.0001 else 0.0
	var disc := pv * pv + a * p.length_squared()
	if disc < 0.0:
		return 0.0
	var root := sqrt(disc)
	var best := -1.0
	for tt in [(pv + root) / a, (pv - root) / a]:
		if tt > 0.0 and (best < 0.0 or tt < best):
			best = tt
	return best

func _on_extraction_timer(seconds_left: float) -> void:
	_timer_label.visible = true
	var s := int(ceil(seconds_left))
	_timer_label.text = "MELTDOWN  %d:%02d" % [s / 60, s % 60]
	# Flash to red as the deadline closes in.
	_timer_label.modulate = Color(1.0, 0.3, 0.25) if seconds_left < 15.0 else Color(1.0, 0.85, 0.3)

func _on_mission_state(state: String) -> void:
	if state == "success":
		_timer_label.visible = false
		_dock_label.visible = false
		_status_label.text = "MISSION COMPLETE"
		_status_label.modulate = Color(0.4, 1.0, 0.5)
		_status_label.visible = true
	elif state == "failed":
		_timer_label.visible = false
		_dock_label.visible = false
		_status_label.text = "MISSION FAILED — F8 to quit"
		_status_label.modulate = Color(1.0, 0.3, 0.25)
		_status_label.visible = true

func _process(_delta: float) -> void:
	if ship == null or ship.ship_def == null:
		return
	_hull_label.text = "HULL    %d / %d" % [int(ship.current_hull), int(ship.ship_def.hull_max)]
	_shield_label.text = "SHIELD  %d / %d" % [int(ship.current_shield), int(ship.ship_def.shield_max)]
	_speed_label.text = "SPEED   %d m/s" % roundi(ship.get_speed())
	_boost_label.text = "BOOST   %s" % ("ENGAGED" if ship.is_boosting else "ready")
	# Flag Newtonian (assist-off) flight in amber so the changed handling is obvious.
	if ship.flight_assist:
		_assist_label.text = "ASSIST  on"
		_assist_label.modulate = Color(1, 1, 1)
	else:
		_assist_label.text = "ASSIST  OFF — NEWTONIAN"
		_assist_label.modulate = Color(1.0, 0.7, 0.2)
	if ship.weapon != null and ship.weapon.weapon_def != null:
		_heat_label.text = "HEAT    %d%%" % int(100.0 * ship.weapon.heat / ship.weapon.weapon_def.max_heat)
	_enemies_label.text = "DRONES  %d" % get_tree().get_nodes_in_group("enemies").size()
	if ship.cargo != null:
		_cargo_label.text = "CARGO   %d/%d  •  %d cr" % [ship.cargo.slots_used(), ship.cargo.max_slots, ship.cargo.salvage_value]
	_threat_label.text = "THREAT  %d%%" % int(_heat * 100.0)
	_threat_label.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.3, 0.25), _heat)
	_update_markers()
