extends Control
## Kestrel Station hub (GDD §17). Presentation: credits, ship condition + repair,
## the Mission Board (launch Ghost Station), co-op lobby, and the upgrade shop.
## Built in code, consistent with the rest of the slice. Reads/writes PlayerProfile.
##
## This hub is themed (Orbitron + a cyan station palette) and renders a live 3D
## backdrop: your ship turning in space, wearing the upgrades you own. Hovering an
## upgrade in the shop "tries it on" — its visual is fitted to the backdrop ship so
## you can see the look before you buy. The shop also shows each upgrade's concrete
## before → after on the ship's stats, and a "Your Ship" panel of the live build.

const RAID_SCENE := "res://scenes/raid/ghost_station_raid.tscn"
const FONT_PATH := "res://fonts/Orbitron.ttf"

# Backdrop ship + the assets its "try-on" visuals reuse (mirrors main.gd).
const SHIP_MODEL_PATH := "res://assets/models/ship/spaceship_ezno.glb"
const SHIP_MODEL_CENTER := Vector3(0.0, -1.346, -2.524)
const SALVAGE_MODEL_PATH := "res://assets/models/salvage/scifi_crates.glb"
const SALVAGE_MODEL_CENTER := Vector3(0.0, 0.03, -0.013)

# Palette — a cyan derelict-station look (the cyan matches the in-game data core).
const COL_PANEL := Color(0.06, 0.09, 0.14, 0.88)
const COL_BORDER := Color(0.18, 0.42, 0.55)
const COL_ACCENT := Color(0.35, 0.82, 1.0)
const COL_GOLD := Color(1.0, 0.82, 0.38)
const COL_GREEN := Color(0.5, 0.95, 0.62)
const COL_RED := Color(1.0, 0.5, 0.45)
const COL_TEXT := Color(0.74, 0.82, 0.92)
const COL_DIM := Color(0.5, 0.58, 0.68)

# Friendly label / unit / decimals for every stat an upgrade can touch (used to
# format the shop's before → after previews and the "Your Ship" panel).
const STAT_META := {
	"hull_max": {"label": "HULL", "suffix": "", "dec": 0},
	"shield_max": {"label": "SHIELD", "suffix": "", "dec": 0},
	"max_speed": {"label": "SPEED", "suffix": "", "dec": 0},
	"boost_speed": {"label": "BOOST", "suffix": "", "dec": 0},
	"cargo_slots": {"label": "CARGO", "suffix": "", "dec": 0},
	"acceleration": {"label": "THRUST", "suffix": "", "dec": 0},
	"turn_speed": {"label": "TURN", "suffix": "", "dec": 1},
	"strafe_accel": {"label": "STRAFE", "suffix": "", "dec": 0},
	"roll_speed": {"label": "ROLL", "suffix": "", "dec": 1},
	"boost_accel_mult": {"label": "BOOST ACCEL", "suffix": "x", "dec": 2},
	"brake_damp": {"label": "BRAKING", "suffix": "", "dec": 1},
	"weapon_slots": {"label": "HARDPOINTS", "suffix": "", "dec": 0},
	"utility_slots": {"label": "UTILITY", "suffix": "", "dec": 0},
	"repair_kits": {"label": "REPAIR KITS", "suffix": "", "dec": 0},
}
# Which stats appear in the "Your Ship" summary panel.
const PANEL_STATS := ["hull_max", "shield_max", "max_speed", "boost_speed", "cargo_slots", "acceleration", "turn_speed"]

var _credits_value: Label
var _repair_button: Button
var _hull_bar: ProgressBar
var _launch_button: Button
var _hint_label: Label
var _tryon_label: Label
var _upgrade_rows: Array = []         # [{id, cost, def, button, preview}]
var _ship_stat_labels: Dictionary = {}
var _all_defs: Array = []
var _base_def: ShipDef
var _current_device := MenuNav.DEVICE_NONE

# 3D backdrop (presentation only).
var _backdrop_ship: Node3D
var _ship_addons: Node3D               # owned-upgrade visuals hang here
var _preview_node: Node3D              # the "trying on" visual, if any
var _preview_time: float = 0.0

# Co-op (M5 Phase 1c)
var _coop_status: Label
var _host_button: Button
var _join_button: Button
var _coop_launch_button: Button
var _ip_edit: LineEdit
var _coop_ips_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuNav.enable_gamepad_ui()
	_base_def = load("res://data/ships/wayfarer.tres") as ShipDef
	if _base_def == null:
		_base_def = ShipDef.new()
	_all_defs = UpgradeSystem.all_upgrades()
	theme = _build_theme()
	_build_ui()
	EventBus.profile_changed.connect(_refresh)
	Net.hosted.connect(_refresh_coop)
	Net.joined.connect(_refresh_coop)
	Net.join_failed.connect(_on_join_failed)
	Net.peers_changed.connect(_refresh_coop)
	_refresh()
	_refresh_coop()
	_launch_button.grab_focus.call_deferred()
	_current_device = MenuNav.DEVICE_GAMEPAD if MenuNav.gamepad_connected() else MenuNav.DEVICE_KBM
	_update_hint()

func _process(delta: float) -> void:
	if _backdrop_ship != null:
		_backdrop_ship.rotate_y(delta * 0.3)   # slow turntable show-off
	if _preview_node != null and is_instance_valid(_preview_node):
		_preview_time += delta
		_preview_node.scale = Vector3.ONE * (1.0 + 0.06 * sin(_preview_time * 6.0))

func _input(event: InputEvent) -> void:
	var d := MenuNav.device_of(event)
	if d != MenuNav.DEVICE_NONE and d != _current_device:
		_current_device = d
		_update_hint()

func _update_hint() -> void:
	_hint_label.text = MenuNav.hint_text(_current_device)

# ── theme ───────────────────────────────────────────────────────────────────────
func _build_theme() -> Theme:
	var th := Theme.new()
	var font := load(FONT_PATH) as Font
	if font != null:
		th.default_font = font
	th.default_font_size = 15

	th.set_stylebox("normal", "Button", _sb(Color(0.10, 0.15, 0.22), COL_BORDER, 1, 4, 14))
	th.set_stylebox("hover", "Button", _sb(Color(0.15, 0.23, 0.34), COL_ACCENT, 1, 4, 14))
	th.set_stylebox("pressed", "Button", _sb(Color(0.18, 0.28, 0.40), COL_ACCENT, 1, 4, 14))
	th.set_stylebox("disabled", "Button", _sb(Color(0.07, 0.09, 0.12), Color(0.15, 0.20, 0.25), 1, 4, 14))
	th.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), COL_ACCENT, 2, 4, 14))
	th.set_color("font_color", "Button", COL_TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", COL_DIM)

	th.set_color("font_color", "Label", COL_TEXT)
	th.set_stylebox("panel", "PanelContainer", _sb(COL_PANEL, COL_BORDER, 1, 6, 16))

	th.set_stylebox("normal", "LineEdit", _sb(Color(0.08, 0.11, 0.16), COL_BORDER, 1, 4, 8))
	th.set_stylebox("focus", "LineEdit", _sb(Color(0.10, 0.14, 0.20), COL_ACCENT, 2, 4, 8))
	th.set_color("font_color", "LineEdit", COL_TEXT)

	th.set_stylebox("background", "ProgressBar", _sb(Color(0.05, 0.07, 0.10), COL_BORDER, 1, 3, 0))
	th.set_stylebox("fill", "ProgressBar", _sb(COL_ACCENT, Color(0, 0, 0, 0), 0, 3, 0))
	th.set_color("font_color", "ProgressBar", COL_TEXT)
	return th

func _sb(bg: Color, border: Color, bw: int, rad: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_corner_radius_all(rad)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s

# ── layout ──────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	_build_backdrop()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 46)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)

	_build_topbar(page)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)

	# A deliberate empty gap in the middle so the rotating backdrop ship is always
	# visible (centred on screen) while you work the upgrade shop on the right.
	var window := Control.new()
	window.custom_minimum_size = Vector2(360, 0)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(window)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	_build_ship_panel(left)
	_build_condition_panel(left)
	_build_mission_panel(left)
	_build_coop_panel(left)
	_build_upgrades_panel(right)

	# Floating "trying on" caption over the backdrop (top-centre), hidden by default.
	_tryon_label = Label.new()
	_tryon_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_tryon_label.offset_top = 18
	_tryon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tryon_label.add_theme_font_size_override("font_size", 20)
	_tryon_label.add_theme_color_override("font_color", COL_ACCENT)
	_tryon_label.visible = false
	add_child(_tryon_label)

	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -34
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.modulate = Color(1, 1, 1, 0.55)
	add_child(_hint_label)

func _build_topbar(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	parent.add_child(bar)

	var titleblock := VBoxContainer.new()
	titleblock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(titleblock)
	var title := Label.new()
	title.text = "KESTREL STATION"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color.WHITE)
	titleblock.add_child(title)
	var sub := Label.new()
	sub.text = "DOCKED · UPGRADE BAY"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", COL_ACCENT)
	titleblock.add_child(sub)

	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	bar.add_child(pill)
	var pv := VBoxContainer.new()
	pill.add_child(pv)
	var clab := Label.new()
	clab.text = "CREDITS"
	clab.add_theme_font_size_override("font_size", 12)
	clab.add_theme_color_override("font_color", COL_DIM)
	clab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(clab)
	_credits_value = Label.new()
	_credits_value.add_theme_font_size_override("font_size", 28)
	_credits_value.add_theme_color_override("font_color", COL_GOLD)
	_credits_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(_credits_value)

func _build_ship_panel(parent: Control) -> void:
	var vb := _add_card(parent, "YOUR SHIP")
	var name_l := Label.new()
	name_l.text = _base_def.display_name + "  ·  class hull"
	name_l.add_theme_color_override("font_color", COL_DIM)
	name_l.add_theme_font_size_override("font_size", 13)
	vb.add_child(name_l)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	for key in PANEL_STATS:
		var meta: Dictionary = STAT_META[key]
		var n := Label.new()
		n.text = meta["label"]
		n.add_theme_color_override("font_color", COL_DIM)
		n.add_theme_font_size_override("font_size", 13)
		grid.add_child(n)
		var v := Label.new()
		v.add_theme_color_override("font_color", COL_TEXT)
		grid.add_child(v)
		_ship_stat_labels[key] = v

func _build_condition_panel(parent: Control) -> void:
	var vb := _add_card(parent, "SHIP CONDITION")
	_hull_bar = ProgressBar.new()
	_hull_bar.min_value = 0.0
	_hull_bar.max_value = 100.0
	_hull_bar.custom_minimum_size = Vector2(0, 22)
	_hull_bar.show_percentage = true
	vb.add_child(_hull_bar)
	_repair_button = Button.new()
	_repair_button.pressed.connect(_on_repair)
	vb.add_child(_repair_button)

func _build_mission_panel(parent: Control) -> void:
	var vb := _add_card(parent, "MISSION BOARD")
	var desc := Label.new()
	desc.text = "Ghost Station — derelict salvage run & data-core extraction."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", COL_DIM)
	desc.add_theme_font_size_override("font_size", 13)
	vb.add_child(desc)
	_launch_button = Button.new()
	_launch_button.text = "▶  LAUNCH  (solo)"
	_launch_button.add_theme_font_size_override("font_size", 18)
	_launch_button.pressed.connect(_on_launch)
	vb.add_child(_launch_button)

func _build_coop_panel(parent: Control) -> void:
	var vb := _add_card(parent, "CO-OP")
	_coop_status = Label.new()
	_coop_status.modulate = Color(0.7, 0.85, 1.0)
	_coop_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coop_status.add_theme_font_size_override("font_size", 13)
	vb.add_child(_coop_status)
	var coop_row := HBoxContainer.new()
	coop_row.add_theme_constant_override("separation", 8)
	vb.add_child(coop_row)
	_host_button = Button.new()
	_host_button.text = "Host"
	_host_button.pressed.connect(_on_host)
	coop_row.add_child(_host_button)
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.custom_minimum_size = Vector2(160, 0)
	coop_row.add_child(_ip_edit)
	_join_button = Button.new()
	_join_button.text = "Join"
	_join_button.pressed.connect(_on_join)
	coop_row.add_child(_join_button)
	_coop_launch_button = Button.new()
	_coop_launch_button.text = "▶  Launch Co-op raid"
	_coop_launch_button.pressed.connect(_on_launch_coop)
	_coop_launch_button.visible = false
	vb.add_child(_coop_launch_button)
	_coop_ips_label = Label.new()
	_coop_ips_label.modulate = Color(1, 1, 1, 0.5)
	_coop_ips_label.add_theme_font_size_override("font_size", 12)
	_coop_ips_label.visible = false
	vb.add_child(_coop_ips_label)

func _build_upgrades_panel(parent: Control) -> void:
	var vb := _add_card(parent, "UPGRADES")
	(vb.get_parent() as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tip := Label.new()
	tip.text = "Bought once, persist between runs. Hover to try one on the ship →"
	tip.add_theme_color_override("font_color", COL_DIM)
	tip.add_theme_font_size_override("font_size", 13)
	vb.add_child(tip)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for def in _all_defs:
		var rowpanel := PanelContainer.new()
		rowpanel.add_theme_stylebox_override("panel",
			_sb(Color(0.08, 0.11, 0.16, 0.7), Color(0.16, 0.30, 0.40), 1, 4, 12))
		rowpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(rowpanel)
		var rr := HBoxContainer.new()
		rr.add_theme_constant_override("separation", 12)
		rowpanel.add_child(rr)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rr.add_child(info)
		var name_l := Label.new()
		name_l.text = def.display_name
		name_l.add_theme_font_size_override("font_size", 16)
		name_l.add_theme_color_override("font_color", Color.WHITE)
		info.add_child(name_l)
		var desc_l := Label.new()
		desc_l.text = def.description
		desc_l.add_theme_color_override("font_color", COL_DIM)
		desc_l.add_theme_font_size_override("font_size", 13)
		info.add_child(desc_l)
		var prev := Label.new()
		prev.add_theme_color_override("font_color", COL_ACCENT)
		prev.add_theme_font_size_override("font_size", 14)
		info.add_child(prev)

		var buy := Button.new()
		buy.custom_minimum_size = Vector2(150, 0)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.pressed.connect(_on_buy.bind(def.upgrade_id, def.cost))
		rr.add_child(buy)

		# Try-on: hover the row (mouse) or focus the buy button (gamepad/keyboard).
		rowpanel.mouse_entered.connect(_on_try_on.bind(def))
		rowpanel.mouse_exited.connect(_on_try_off)
		buy.focus_entered.connect(_on_try_on.bind(def))
		buy.focus_exited.connect(_on_try_off)

		_upgrade_rows.append({"id": def.upgrade_id, "cost": def.cost, "def": def, "button": buy, "preview": prev})

func _add_card(parent: Control, title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var h := Label.new()
	h.text = title_text
	h.add_theme_font_size_override("font_size", 17)
	h.add_theme_color_override("font_color", COL_ACCENT)
	vb.add_child(h)
	vb.add_child(_rule())
	return vb

func _rule() -> Control:
	var c := ColorRect.new()
	c.color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.25)
	c.custom_minimum_size = Vector2(0, 1)
	return c

# ── refresh ─────────────────────────────────────────────────────────────────────
func _refresh() -> void:
	_credits_value.text = "%d cr" % PlayerProfile.credits

	var pct := PlayerProfile.ship_hull_pct
	_hull_bar.value = pct * 100.0
	_hull_bar.add_theme_stylebox_override("fill", _sb(COL_RED.lerp(COL_GREEN, pct), Color(0, 0, 0, 0), 0, 3, 0))

	var rcost := RewardCalculator.repair_cost(pct)
	if rcost <= 0:
		_repair_button.text = "HULL OK"
		_repair_button.disabled = true
	else:
		_repair_button.disabled = false
		var tail := "" if PlayerProfile.can_afford(rcost) else "  (free basic)"
		_repair_button.text = "REPAIR — %d cr%s" % [rcost, tail]

	# Live, outfitted stats (base + everything owned).
	var outfitted := UpgradeSystem.outfit(_base_def, PlayerProfile.owned_upgrades)
	for key in PANEL_STATS:
		var meta: Dictionary = STAT_META[key]
		var lbl: Label = _ship_stat_labels.get(key)
		if lbl == null:
			continue
		var val := float(outfitted.get(key))
		var base_val := float(_base_def.get(key))
		lbl.text = String.num(val, meta["dec"]) + meta["suffix"]
		lbl.add_theme_color_override("font_color", COL_GREEN if not is_equal_approx(val, base_val) else COL_TEXT)

	for row in _upgrade_rows:
		var def: UpgradeDef = row["def"]
		var prev: Label = row["preview"]
		var btn: Button = row["button"]
		var meta := _stat_meta(def.stat)
		var cur := (float(outfitted.get(def.stat))) if (def.stat in outfitted) else 0.0
		if PlayerProfile.has_upgrade(row["id"]):
			prev.text = "%s  %s%s  ✓ installed" % [meta["label"], String.num(cur, meta["dec"]), meta["suffix"]]
			prev.add_theme_color_override("font_color", COL_GREEN)
			btn.text = "✓ OWNED"
			btn.disabled = true
			btn.add_theme_color_override("font_disabled_color", COL_GOLD)
		else:
			var after := cur * def.mult + def.add
			prev.text = "%s  %s → %s%s" % [meta["label"], String.num(cur, meta["dec"]), String.num(after, meta["dec"]), meta["suffix"]]
			prev.add_theme_color_override("font_color", COL_ACCENT)
			var afford := PlayerProfile.can_afford(row["cost"])
			btn.disabled = not afford
			btn.text = ("BUY — %d cr" % row["cost"]) if afford else ("%d cr" % row["cost"])
			btn.add_theme_color_override("font_disabled_color", COL_RED)

	_rebuild_ship_addons()

func _stat_meta(key: String) -> Dictionary:
	return STAT_META.get(key, {"label": key.to_upper(), "suffix": "", "dec": 1})

# ── 3D backdrop + try-on visuals ─────────────────────────────────────────────────
## The ship is rendered directly in the hub's main 3D world (not a SubViewport): a
## Window viewport always draws its 3D world first, then the 2D UI on top, so the
## ship shows through the transparent centre gap and behind the semi-transparent
## panels — no SubViewportContainer quirks, and it just works.
func _build_backdrop() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := PanoramaSkyMaterial.new()
	var pano := load("res://assets/textures/8k_stars_milky_way.jpg")
	if pano != null:
		sm.panorama = pano
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.1
	# Darken the sky so the busy starfield doesn't fight the UI text.
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.55
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 35, 0)
	key.light_energy = 1.5
	key.light_color = Color(0.7, 0.85, 1.0)
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(15, -140, 0)
	rim.light_energy = 1.0
	rim.light_color = Color(1.0, 0.6, 0.45)
	add_child(rim)

	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.position = Vector3(15, 8, 58)        # pulled back for a framed 3/4 hero shot
	add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)   # after entering the tree
	cam.current = true                       # active 3D camera for the hub

	# Scale 1.0 so the try-on visuals (sized in model units) line up without scaling.
	var ship := ModelUtil.spawn(SHIP_MODEL_PATH, 1.0, Vector3.ZERO, SHIP_MODEL_CENTER)
	if ship != null:
		add_child(ship)
		_backdrop_ship = ship
		_ship_addons = Node3D.new()
		ship.add_child(_ship_addons)

## Rebuilds the persistent visuals for everything the player owns. Uses the shared
## ShipLoadoutVisuals so the hub ship and the real in-game ship wear identical parts.
func _rebuild_ship_addons() -> void:
	if _ship_addons == null:
		return
	for c in _ship_addons.get_children():
		c.queue_free()
	_preview_node = null   # was a child of _ship_addons; just freed above
	var built := ShipLoadoutVisuals.build(PlayerProfile.owned_upgrades, _all_defs)
	for c in built.get_children().duplicate():
		built.remove_child(c)
		_ship_addons.add_child(c)
	built.queue_free()

func _on_try_on(def: UpgradeDef) -> void:
	var owned: bool = PlayerProfile.has_upgrade(def.upgrade_id)
	_tryon_label.text = ("INSTALLED · %s" % def.display_name) if owned else ("TRYING ON · %s" % def.display_name)
	_tryon_label.visible = true
	if owned:
		return   # already worn by _rebuild_ship_addons; nothing to preview
	_clear_preview()
	if _ship_addons == null:
		return
	var v := ShipLoadoutVisuals.make(ShipLoadoutVisuals.category_for(def.stat))
	if v == null:
		return
	_preview_node = v
	_preview_time = 0.0   # _process pulses it (a looped tween here triggered an
	_ship_addons.add_child(v)   # "infinite loop" warning, so we animate by hand)

func _on_try_off() -> void:
	_tryon_label.visible = false
	_clear_preview()

func _clear_preview() -> void:
	if _preview_node != null and is_instance_valid(_preview_node):
		_preview_node.queue_free()
	_preview_node = null

# ── actions ─────────────────────────────────────────────────────────────────────
func _on_launch() -> void:
	get_tree().change_scene_to_file(RAID_SCENE)

func _on_buy(id: String, cost: int) -> void:
	if PlayerProfile.buy_upgrade(id, cost):   # UI refreshes via EventBus.profile_changed
		_flash(_credits_value)

func _on_repair() -> void:
	PlayerProfile.repair(RewardCalculator.repair_cost(PlayerProfile.ship_hull_pct))

func _flash(node: CanvasItem) -> void:
	node.modulate = Color(1.4, 1.4, 1.0)
	create_tween().tween_property(node, "modulate", Color.WHITE, 0.4)

# ── co-op lobby (M5 Phase 1c) ─────────────────────────────────────────────────
func _on_host() -> void:
	if Net.host_game():
		_refresh_coop()

func _on_join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	if Net.join_game(ip):
		_coop_status.text = "Connecting to %s…" % ip

func _on_launch_coop() -> void:
	Net.start_coop_raid()

func _on_join_failed() -> void:
	_coop_status.text = "Connection failed — check the IP and that the host is up."
	_refresh_coop()

func _refresh_coop() -> void:
	if not Net.active:
		_coop_status.text = "Offline. Host a game, or enter an IP and Join."
		_host_button.disabled = false
		_join_button.disabled = false
		_ip_edit.editable = true
		_coop_launch_button.visible = false
		_coop_ips_label.visible = false
		_launch_button.disabled = false
		return
	_host_button.disabled = true
	_join_button.disabled = true
	_ip_edit.editable = false
	_launch_button.disabled = true
	if Net.is_host():
		_coop_status.text = "Hosting on :%d — %d player(s). Launch when everyone's in." % [Net.DEFAULT_PORT, Net.player_count()]
		_coop_launch_button.visible = true
		_coop_ips_label.visible = true
		_coop_ips_label.text = "Your address (share it): %s" % _local_ips_text()
	else:
		_coop_status.text = "Connected as peer %d — waiting for the host to launch…" % multiplayer.get_unique_id()
		_coop_launch_button.visible = false
		_coop_ips_label.visible = false

func _local_ips_text() -> String:
	var out := ""
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			out += ("" if out.is_empty() else ", ") + a
	return out if not out.is_empty() else "(no IPv4 found)"
