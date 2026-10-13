class_name SpikeCourtyard
extends Node3D
## The prototype arena: a walled stone courtyard with spike walls on the left and right.
## Kick someone into the spikes for heavy damage (a kill if they're low).

const HALF_W := 8.0     # x extent of the floor
const HALF_D := 5.0     # z extent of the floor
const SPIKE_DEPTH := 0.95

var spawn_points := [Vector3(-3, 0, 0.5), Vector3(3, 0, 0.5)]


func build(side_view: bool) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.07, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.45, 0.5)
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.25, 0.12, 0.12)
	e.fog_density = 0.012
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color(1.0, 0.85, 0.7)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var stone := Fighter._mat(Color(0.42, 0.38, 0.33))
	var dark_stone := Fighter._mat(Color(0.25, 0.22, 0.2))
	var iron := Fighter._mat(Color(0.35, 0.35, 0.38))
	iron.metallic = 0.7
	iron.roughness = 0.4
	var wood := Fighter._mat(Color(0.45, 0.08, 0.06))

	# Floor tiles in a checker of two stones.
	for ix in range(-4, 4):
		for iz in range(-3, 3):
			var tile := Fighter._part(self, Fighter._box(Vector3(2.0, 0.2, 1.7)),
				stone if (ix + iz) % 2 == 0 else dark_stone,
				Vector3(ix * 2.0 + 1.0, -0.1, iz * 1.7 + 0.85))
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Back wall and a low front wall (low so it never hides the fighters).
	_wall(Vector3(0, 1.5, -HALF_D - 0.25), Vector3(HALF_W * 2 + 1.0, 3.0, 0.5), dark_stone)
	_wall(Vector3(0, 0.25, HALF_D + 0.25), Vector3(HALF_W * 2 + 1.0, 0.5, 0.5), dark_stone, not side_view)

	# Spike walls on the left and right.
	for side in [-1.0, 1.0]:
		_wall(Vector3(side * (HALF_W + 0.25), 1.5, 0), Vector3(0.5, 3.0, HALF_D * 2), iron)
		for row in range(3):
			for i in range(11):
				var z := -HALF_D + 0.5 + i * 0.9 + (0.45 if row % 2 == 1 else 0.0)
				if z > HALF_D - 0.3:
					continue
				var spike := Fighter._part(self, Fighter._cyl(0.0, 0.12, SPIKE_DEPTH), iron,
					Vector3(side * (HALF_W - SPIKE_DEPTH * 0.5), 0.5 + row * 0.7, z))
				spike.rotation_degrees.z = 90.0 * side

	# A torii gate and lanterns behind the back wall for flavour.
	for x in [-2.6, 2.6]:
		Fighter._part(self, Fighter._cyl(0.22, 0.25, 6.0), wood, Vector3(x, 3.0, -HALF_D - 1.6))
	Fighter._part(self, Fighter._box(Vector3(7.4, 0.35, 0.5)), wood, Vector3(0, 5.6, -HALF_D - 1.6))
	Fighter._part(self, Fighter._box(Vector3(6.2, 0.25, 0.4)), wood, Vector3(0, 4.7, -HALF_D - 1.6))
	for x in [-6.0, 6.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, 3.4, -HALF_D + 0.3)
		lamp.light_color = Color(1.0, 0.5, 0.2)
		lamp.light_energy = 1.6
		lamp.omni_range = 7.0
		add_child(lamp)
		var glow_mat := Fighter._mat(Color(1.0, 0.55, 0.2))
		glow_mat.emission_enabled = true
		glow_mat.emission = Color(1.0, 0.45, 0.1)
		Fighter._part(self, Fighter._box(Vector3(0.4, 0.55, 0.4)), glow_mat, lamp.position)


## Push direction (away from the wall) if this position is touching spikes, else zero.
func spike_push(pos: Vector3) -> Vector3:
	if pos.x > HALF_W - SPIKE_DEPTH - Fighter.RADIUS * 0.5:
		return Vector3(-1, 0, 0)
	if pos.x < -HALF_W + SPIKE_DEPTH + Fighter.RADIUS * 0.5:
		return Vector3(1, 0, 0)
	return Vector3.ZERO


func _wall(pos: Vector3, size: Vector3, mat: Material, visible_mesh := true) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if visible_mesh:
		Fighter._part(body, Fighter._box(size), mat, Vector3.ZERO)
	add_child(body)
