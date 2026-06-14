class_name LobbyPanel
extends CanvasLayer
## The panel that opens when the player docks at a lobby service zone (Departure /
## Upgrades / Repair / Ship Bay). Builds the relevant controls per service, reusing
## PlayerProfile / UpgradeSystem / Net (the same logic the old flat hub used). The
## lobby controller frees the mouse + locks flight while it's open.

signal closed

const RAID_SCENE := "res://scenes/raid/ghost_station_raid.tscn"
const BASE_FONT := 18

var _open := false
var _service := ""
var _content: VBoxContainer
var _theme: Theme

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	MenuNav.enable_gamepad_ui()
	_build_frame()
	EventBus.profile_changed.connect(_refresh)
	Net.hosted.connect(_refresh)
	Net.joined.connect(_refresh)
	Net.peers_changed.connect(_refresh)
	Net.join_failed.connect(_refresh)
	visible = false

func is_open() -> bool:
	return _open

func open(service: String) -> void:
	_service = service
	_open = true
	visible = true
	_theme.default_font_size = roundi(BASE_FONT * Settings.text_scale)
	_theme.default_base_scale = Settings.text_scale
	_rebuild()

func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_settings") \
			or event.is_action_pressed("dock"):
		close()
		get_viewport().set_input_as_handled()

# ── frame ─────────────────────────────────────────────────────────────────────
func _build_frame() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	_theme = Theme.new()
	panel.theme = _theme
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	margin.add_child(_content)

func _refresh() -> void:
	if _open:
		_rebuild()

func _rebuild() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	var first: Control = null
	match _service:
		"launch": first = _build_launch()
		"upgrades": first = _build_upgrades()
		"repair": first = _build_repair()
		"ship": _build_ship_bay()
		_: _label("UNKNOWN SERVICE")

	_content.add_child(HSeparator.new())
	var close_btn := Button.new()
	close_btn.text = "Close   (Esc / F / ○)"
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.pressed.connect(close)
	_content.add_child(close_btn)
	(first if first != null else close_btn).grab_focus.call_deferred()

# ── services ──────────────────────────────────────────────────────────────────
func _build_launch() -> Control:
	_title("DEPARTURE")
	_label("Credits: %d" % PlayerProfile.credits)
	var solo := Button.new()
	solo.text = "▶  Launch: Ghost Station (solo)"
	solo.focus_mode = Control.FOCUS_ALL
	solo.disabled = Net.active
	solo.pressed.connect(_launch_solo)
	_content.add_child(solo)

	_content.add_child(HSeparator.new())
	_label("CO-OP  (separate ships, vs. drones together)")
	_label(_coop_status_text())
	if not Net.active:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var host := Button.new()
		host.text = "Host"
		host.pressed.connect(func() -> void: Net.host_game())
		row.add_child(host)
		var ip := LineEdit.new()
		ip.text = "127.0.0.1"
		ip.custom_minimum_size = Vector2(190, 0)
		row.add_child(ip)
		var join := Button.new()
		join.text = "Join"
		join.pressed.connect(func() -> void: Net.join_game(ip.text.strip_edges()))
		row.add_child(join)
		_content.add_child(row)
	elif Net.is_host():
		_label("Share an address below (Tailscale = the 100.x one), then Join from the other PC:")
		_label(_local_ips_text())
		var launch := Button.new()
		launch.text = "▶  Launch Co-op raid"
		launch.pressed.connect(_launch_coop)
		_content.add_child(launch)
	return solo

## The host's IPv4 addresses to share (keeps Tailscale's 100.x; drops loopback/link-local).
func _local_ips_text() -> String:
	var out := ""
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			out += ("" if out.is_empty() else ", ") + a
	return out if not out.is_empty() else "(no IPv4 found)"

func _build_upgrades() -> Control:
	_title("UPGRADES")
	_label("Credits: %d  (bought once, persist between runs)" % PlayerProfile.credits)
	var first: Control = null
	for def in UpgradeSystem.all_upgrades():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := Label.new()
		info.text = "%s — %s  (%d cr)" % [def.display_name, def.description, def.cost]
		info.custom_minimum_size = Vector2(430, 0)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_ALL
		if PlayerProfile.has_upgrade(def.upgrade_id):
			btn.text = "OWNED"
			btn.disabled = true
		else:
			btn.text = "Buy"
			btn.disabled = not PlayerProfile.can_afford(def.cost)
			btn.pressed.connect(func() -> void: PlayerProfile.buy_upgrade(def.upgrade_id, def.cost))
		row.add_child(btn)
		_content.add_child(row)
		if first == null:
			first = btn
	return first

func _build_repair() -> Control:
	_title("REPAIR BAY")
	_label("Credits: %d" % PlayerProfile.credits)
	_label("Ship hull: %d%%" % int(round(PlayerProfile.ship_hull_pct * 100.0)))
	var cost := RewardCalculator.repair_cost(PlayerProfile.ship_hull_pct)
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_ALL
	if cost <= 0:
		btn.text = "Hull OK"
		btn.disabled = true
	else:
		var tail := "" if PlayerProfile.can_afford(cost) else "  (free basic — low credits)"
		btn.text = "Repair hull — %d cr%s" % [cost, tail]
		btn.pressed.connect(func() -> void: PlayerProfile.repair(cost))
	_content.add_child(btn)
	return btn

func _build_ship_bay() -> void:
	_title("SHIP BAY")
	_label("Wayfarer — your only hull for now.")
	_label("More ships are coming; you'll switch them here.")

# ── helpers ───────────────────────────────────────────────────────────────────
func _launch_solo() -> void:
	Settings.input_locked = false   # don't carry the menu lock into the raid
	get_tree().change_scene_to_file(RAID_SCENE)

func _launch_coop() -> void:
	Settings.input_locked = false
	Net.start_coop_raid()

func _coop_status_text() -> String:
	if not Net.active:
		return "Offline — Host, or enter an IP and Join."
	if Net.is_host():
		return "Hosting on :%d — %d player(s). Launch when everyone's in." % [Net.DEFAULT_PORT, Net.player_count()]
	return "Connected as peer %d — waiting for the host to launch…" % multiplayer.get_unique_id()

func _title(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(l)
	_content.add_child(HSeparator.new())

func _label(t: String) -> void:
	var l := Label.new()
	l.text = t
	_content.add_child(l)
