class_name ArenaCamera
extends Camera3D
## Angled arena camera that pulls back as fighters spread out,
## or a side-on camera for Classic Duel. Also does screen shake.

var targets: Array[Node3D] = []
var side_view := false
var _shake := 0.0
var _focus := Vector3.ZERO
var _dist := 10.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	fov = 50.0
	snap()


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 0.6)


func snap() -> void:
	var goal := _goal()
	_focus = goal[0]
	_dist = goal[1]
	_place(0.0)


func _process(delta: float) -> void:
	var goal := _goal()
	var k := 1.0 - exp(-delta * 5.0)
	_focus = _focus.lerp(goal[0], k)
	_dist = lerpf(_dist, goal[1], k)
	_shake = maxf(_shake - delta * 1.5, 0.0)
	_place(_shake)


func _goal() -> Array:
	if targets.is_empty():
		return [Vector3.ZERO, 10.0]
	var lo := targets[0].global_position
	var hi := lo
	for t in targets:
		lo = lo.min(t.global_position)
		hi = hi.max(t.global_position)
	var mid := (lo + hi) * 0.5
	var spread := maxf(hi.x - lo.x, (hi.z - lo.z) * 1.6)
	if side_view:
		return [Vector3(mid.x * 0.85, 1.2, 0.0), clampf(6.5 + spread * 0.8, 8.5, 13.0)]
	return [Vector3(mid.x * 0.8, 0.9, mid.z * 0.6), clampf(9.0 + spread * 0.8, 11.5, 18.0)]


func _place(shake: float) -> void:
	var offset: Vector3
	if side_view:
		offset = Vector3(0, 0.22, 1.0).normalized() * _dist
	else:
		offset = Vector3(0, sin(deg_to_rad(34.0)), cos(deg_to_rad(34.0))) * _dist
	var jitter := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * shake * shake * 0.8
	global_position = _focus + offset + jitter
	look_at(_focus + jitter * 0.5, Vector3.UP)
