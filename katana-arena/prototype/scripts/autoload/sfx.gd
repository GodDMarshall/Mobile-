extends Node
## Plays placeholder sound effects by name. A name like "cut" picks a random
## file from res://audio/sfx/cut_1.wav, cut_2.wav, ... so variations need no code changes.

const SFX_DIR := "res://audio/sfx/"
const VOICES := 12

var _streams := {}   # name -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func play(sound: String, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	var variants := _variants(sound)
	if variants.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = variants[_rng.randi() % variants.size()]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func _variants(sound: String) -> Array:
	if _streams.has(sound):
		return _streams[sound]
	var found: Array = []
	var single := SFX_DIR + sound + ".wav"
	if ResourceLoader.exists(single):
		found.append(load(single))
	var i := 1
	while ResourceLoader.exists("%s%s_%d.wav" % [SFX_DIR, sound, i]):
		found.append(load("%s%s_%d.wav" % [SFX_DIR, sound, i]))
		i += 1
	_streams[sound] = found
	return found
