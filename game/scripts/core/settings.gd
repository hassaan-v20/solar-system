extends Node
## Autoload "Settings": player options, persisted as JSON at user://settings.json
## (mirrors PlayerProfile). For now: the HUD flight markers (on/off, size, opacity).
## Emits `changed` so the HUD live-updates while the options menu is open.

signal changed

# Overridable so tests can use a temp file.
var save_path := "user://settings.json"

# HUD flight markers (see ShipHUD).
var hud_crosshair: bool = true     # the white aim crosshair
var hud_velocity: bool = true      # prograde + retrograde velocity vectors
var hud_lead: bool = true          # the lead pip on the tracked target
var marker_scale: float = 1.0      # 0.5 .. 2.0 — glyph size
var marker_opacity: float = 0.9    # 0.1 .. 1.0 — "strength"
var text_scale: float = 1.3        # 0.7 .. 2.5 — HUD readout text size

# Transient (NOT saved): true while a blocking menu (SettingsMenu) is open, so the
# ship/weapon ignore flight input and the mouse-capture loop stands down.
var input_locked: bool = false

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(save_path):
		save_settings()
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	hud_crosshair = bool(data.get("hud_crosshair", true))
	hud_velocity = bool(data.get("hud_velocity", true))
	hud_lead = bool(data.get("hud_lead", true))
	marker_scale = clampf(float(data.get("marker_scale", 1.0)), 0.5, 2.0)
	marker_opacity = clampf(float(data.get("marker_opacity", 0.9)), 0.1, 1.0)
	text_scale = clampf(float(data.get("text_scale", 1.3)), 0.7, 2.5)

func save_settings() -> void:
	var data := {
		"hud_crosshair": hud_crosshair,
		"hud_velocity": hud_velocity,
		"hud_lead": hud_lead,
		"marker_scale": marker_scale,
		"marker_opacity": marker_opacity,
		"text_scale": text_scale,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("Settings: cannot write %s" % save_path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

## Called by the options menu after editing a field: persist and notify listeners.
func notify_changed() -> void:
	marker_scale = clampf(marker_scale, 0.5, 2.0)
	marker_opacity = clampf(marker_opacity, 0.1, 1.0)
	text_scale = clampf(text_scale, 0.7, 2.5)
	save_settings()
	changed.emit()
