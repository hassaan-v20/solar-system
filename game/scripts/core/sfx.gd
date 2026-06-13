class_name Sfx
extends Node
## Procedural combat audio. Synthesises short sounds in code (no asset files) and
## plays them in response to EventBus combat signals. A small voice pool lets
## sounds overlap.

const RATE := 22050
const VOICES := 12

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0

func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build()
	EventBus.shot_fired.connect(_on_shot)
	EventBus.hit_landed.connect(func(_t, _at): _play("hit"))
	EventBus.enemy_died.connect(func(_at): _play("explosion"))
	EventBus.player_hit.connect(func(): _play("hurt"))
	EventBus.pickup_collected.connect(func(_k): _play("pickup"))

func _on_shot(team: String) -> void:
	if team == "missile":
		_play("missile")
	elif team == "enemy":
		_play("elaser")
	else:
		_play("laser")

func _play(name: String, vol_db: float = -6.0) -> void:
	if not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _sounds[name]
	p.volume_db = vol_db
	p.play()

# ── synthesis ─────────────────────────────────────────────────────────────────
func _build() -> void:
	_sounds["laser"] = _wav(_sweep(900.0, 420.0, 0.12, 0.9))
	_sounds["elaser"] = _wav(_sweep(500.0, 240.0, 0.14, 0.8))
	_sounds["missile"] = _wav(_mix(_noise(0.30, 6.0, 0.5), _sweep(180.0, 90.0, 0.30, 0.5)))
	_sounds["hit"] = _wav(_tone(1200.0, 0.05, 0.7))
	_sounds["explosion"] = _wav(_noise(0.45, 7.0, 1.0))
	_sounds["hurt"] = _wav(_mix(_tone(140.0, 0.22, 0.8), _noise(0.20, 10.0, 0.5)))
	_sounds["pickup"] = _wav(_arp([700.0, 1050.0, 1400.0], 0.06))

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _tone(freq: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * freq * t) * exp(-t * 3.0 / dur) * vol
	return out

func _sweep(f0: float, f1: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		phase += TAU * f / RATE
		out[i] = sin(phase) * exp(-t * 2.6 / dur) * vol
	return out

func _noise(dur: float, decay: float, vol: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := randf() * 2.0 - 1.0
		prev = lerpf(prev, x, 0.45)            # low-pass for a rumble
		out[i] = prev * exp(-t * decay) * vol
	return out

func _arp(freqs: Array, step: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in freqs.size():
		out.append_array(_tone(freqs[k], step * 2.0, 0.6))
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var va := a[i] if i < a.size() else 0.0
		var vb := b[i] if i < b.size() else 0.0
		out[i] = clampf(va + vb, -1.0, 1.0)
	return out
