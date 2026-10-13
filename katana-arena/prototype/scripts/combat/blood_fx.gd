class_name BloodFx
extends Node3D
## Blood sprays, floor pools and sword sparks. Respects the gore setting:
## Full = sprays and pools, Low = small sprays, Off = sparks only.

const MAX_POOLS := 40

var _pools: Array[MeshInstance3D] = []
var _blood_mat: StandardMaterial3D
var _pool_mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_blood_mat = StandardMaterial3D.new()
	_blood_mat.albedo_color = Color(0.55, 0.0, 0.02)
	_blood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool_mat = StandardMaterial3D.new()
	_pool_mat.albedo_color = Color(0.32, 0.0, 0.01)
	_pool_mat.roughness = 0.2
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.albedo_color = Color(1.0, 0.85, 0.4)
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func blood(pos: Vector3, dir: Vector3, damage: float) -> void:
	match GameSettings.gore:
		GameSettings.Gore.OFF:
			sparks(pos, false)
			return
		GameSettings.Gore.LOW:
			_burst(pos, dir, int(6 + damage * 0.5), _blood_mat, 0.03, 3.0)
			return
	_burst(pos, dir, int(14 + damage * 2.0), _blood_mat, 0.045, 4.5)
	var pools := 1 + int(damage / 10.0)
	for i in pools:
		var offset := dir * _rng.randf_range(0.4, 1.4) + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
		_pool(Vector3(pos.x, 0, pos.z) + offset, _rng.randf_range(0.15, 0.25 + damage * 0.02))


func sparks(pos: Vector3, big: bool) -> void:
	_burst(pos, Vector3.UP, 30 if big else 12, _spark_mat, 0.03 if big else 0.02, 7.0 if big else 4.5)


func clear_pools() -> void:
	for p in _pools:
		p.queue_free()
	_pools.clear()


func _burst(pos: Vector3, dir: Vector3, amount: int, mat: Material, size: float, speed: float) -> void:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	mesh.material = mat
	p.mesh = mesh
	p.amount = maxi(amount, 1)
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.7
	p.direction = (dir.normalized() + Vector3.UP * 0.6).normalized()
	p.spread = 35.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)


func _pool(pos: Vector3, radius: float) -> void:
	var mi: MeshInstance3D
	if _pools.size() >= MAX_POOLS:
		mi = _pools.pop_front()   # recycle the oldest
	else:
		mi = MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.height = 0.005
		m.radial_segments = 10
		m.rings = 1
		mi.mesh = m
		mi.material_override = _pool_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	var cm := mi.mesh as CylinderMesh
	cm.top_radius = radius
	cm.bottom_radius = radius
	mi.position = Vector3(pos.x, 0.01 + _pools.size() * 0.0004, pos.z)
	mi.scale = Vector3(1.0, 1.0, _rng.randf_range(0.6, 1.3))
	mi.rotation.y = _rng.randf() * TAU
	_pools.append(mi)
