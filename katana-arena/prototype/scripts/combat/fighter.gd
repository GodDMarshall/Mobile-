class_name Fighter
extends CharacterBody3D
## One samurai. The match drives it one fixed 60 Hz tick at a time (tick, then
## resolve_attacks), never from its own _physics_process, so the same simulation
## can later run on a Wi-Fi host and be sent to the other phones.

enum State { IDLE, ATTACK, GUARD, HITSTUN, BLOCKSTUN, DASH, STUN, THROWN, DEAD, VICTORY }

const MoveTable := preload("res://data/move_table.gd")
const BUTTONS := ["light", "heavy", "kick", "guard", "dash"]
const RADIUS := 0.45

var G: Dictionary = MoveTable.GLOBALS

var player_index := 0
var fighter_id := ""
var display_name := ""
var body_color := Color.RED
var trim_color := Color.BLACK
var speed_mult := 1.0
var damage_mult := 1.0

var input_source: InputSource
var opponents: Array[Fighter] = []
var side_view := false
var controllable := false

var max_hp := 100.0
var hp := 100.0
var stamina := 100.0
var state: State = State.IDLE
var state_frame := 0
var stun_frames := 0
var frame := 0

var facing := Vector3(0, 0, -1)
var move_vel := Vector3.ZERO
var knock := Vector3.ZERO

var move_name := ""
var move: Dictionary = {}
var chain_index := 0
var charge := 0
var damage_taken_this_round := 0.0
var hazard_cooldown := 0

var _move_hit := {}
var _queued_light := false
var _dash_dir := Vector3.ZERO
var _dash_cooldown := 0
var _guard_press_frame := -1000
var _held := {}
var _pressed := {}
var _last_press := {}
var _last_tap_frame := -1000
var _prev_mag := 0.0
var _sprinting := false
var _flash := 0

var _model: Node3D
var _sword_pivot: Node3D
var _leg_pivot: Node3D
var _body_mat: StandardMaterial3D
var _blade_mat: StandardMaterial3D


func setup(id: String, stats: Dictionary, index: int) -> void:
	fighter_id = id
	player_index = index
	display_name = stats.name
	body_color = stats.color
	trim_color = stats.trim
	speed_mult = stats.speed
	damage_mult = stats.damage
	max_hp = stats.hp
	name = "P%d_%s" % [index + 1, id]
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)
	_build_model()
	for b in BUTTONS:
		_held[b] = false
		_pressed[b] = false
		_last_press[b] = -1000


func reset_for_round(pos: Vector3, face: Vector3) -> void:
	position = pos
	facing = face.normalized()
	hp = max_hp
	stamina = G.max_stamina
	knock = Vector3.ZERO
	move_vel = Vector3.ZERO
	damage_taken_this_round = 0.0
	charge = 0
	_dash_cooldown = 0
	hazard_cooldown = 0
	_flash = 0
	_enter(State.IDLE)
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO
	rotation.y = atan2(-facing.x, -facing.z)
	_update_visuals()


# --- Simulation -------------------------------------------------------------

func tick(inp: InputFrame) -> void:
	frame += 1
	state_frame += 1
	if not controllable or state == State.DEAD or state == State.VICTORY:
		inp = InputFrame.new()
	_read_input(inp)
	if _dash_cooldown > 0:
		_dash_cooldown -= 1
	if hazard_cooldown > 0:
		hazard_cooldown -= 1
	match state:
		State.IDLE:
			_tick_idle(inp)
		State.GUARD:
			_tick_guard(inp)
		State.ATTACK:
			_tick_attack()
		State.DASH:
			_tick_dash()
		State.HITSTUN, State.BLOCKSTUN, State.STUN, State.THROWN:
			move_vel = Vector3.ZERO
			stun_frames -= 1
			if stun_frames <= 0:
				_enter(State.IDLE)
		State.DEAD, State.VICTORY:
			move_vel = Vector3.ZERO
	_regen()
	_apply_motion()
	_update_visuals()


## Called by the match after every fighter has ticked, so hits are resolved in a fixed order.
func resolve_attacks() -> void:
	if not is_active():
		return
	var mv := move   # the defender's reaction (a parry) can end this move mid-loop
	var mv_name := move_name
	for o in opponents:
		var id := o.get_instance_id()
		if _move_hit.has(id) or o.state == State.DEAD:
			continue
		if mv.get("is_throw", false) and (o.state == State.THROWN or o.is_invulnerable()):
			continue
		var to := o.position - position
		to.y = 0.0
		var dist := to.length()
		if dist > float(mv.range) + RADIUS:
			continue
		var dir := to / dist if dist > 0.001 else facing
		if facing.dot(dir) < cos(deg_to_rad(float(mv.arc) * 0.5)):
			continue
		_move_hit[id] = true
		var dmg := float(mv.damage) * damage_mult
		var result: String
		if mv.get("is_throw", false):
			result = o.receive_throw(self, mv, dir, dmg)
		else:
			result = o.receive_hit(self, mv, dir, dmg)
		EventBus.attack_resolved.emit(self, o, mv_name, result, dmg)
		if mv.get("is_throw", false):
			return


func receive_hit(attacker: Fighter, mv: Dictionary, dir: Vector3, dmg: float) -> String:
	if state == State.DEAD:
		return "none"
	if is_invulnerable():
		return "evade"
	var from_front := facing.dot(-dir) > 0.2
	if (state == State.GUARD or state == State.BLOCKSTUN) and from_front:
		if state == State.GUARD and frame - _guard_press_frame <= int(G.parry_window):
			attacker.get_stunned(int(G.parry_stun))
			return "parry"
		stamina -= dmg * float(G.block_stamina_mult)
		knock = dir * float(mv.pushback) * 0.5
		if stamina <= 0.0:
			stamina = 0.0
			get_stunned(int(G.guard_break_stun))
			return "guard_break"
		stun_frames = int(mv.blockstun)
		_enter(State.BLOCKSTUN)
		return "block"
	if state == State.ATTACK and move.get("armor_vs_light", false) and mv.get("light", false) \
			and state_frame < int(move.startup) + int(move.active) + charge:
		_take_damage(dmg)
		_flash = 4
		if hp <= 0.0:
			_die(dir)
			return "kill"
		return "armor"
	_take_damage(dmg)
	knock = dir * float(mv.pushback)
	_flash = 5
	if hp <= 0.0:
		_die(dir)
		return "kill"
	stun_frames = int(mv.hitstun)
	_enter(State.HITSTUN)
	return "hit"


func receive_throw(_attacker: Fighter, mv: Dictionary, dir: Vector3, dmg: float) -> String:
	_take_damage(dmg)
	knock = dir * float(mv.pushback)
	_flash = 5
	if hp <= 0.0:
		_die(dir)
		return "kill"
	stun_frames = int(mv.hitstun)
	_enter(State.THROWN)
	return "throw"


## Spikes and other arena hazards. Returns true if it killed.
func receive_hazard(push_dir: Vector3, dmg: float) -> bool:
	hazard_cooldown = 30
	_take_damage(dmg)
	knock = push_dir * 6.0
	_flash = 6
	if hp <= 0.0:
		_die(push_dir)
		return true
	stun_frames = 30
	_enter(State.HITSTUN)
	return false


func get_stunned(frames: int) -> void:
	if state == State.DEAD:
		return
	stun_frames = frames
	_enter(State.STUN)


func win_pose() -> void:
	if state != State.DEAD:
		_enter(State.VICTORY)


func is_active() -> bool:
	if state != State.ATTACK:
		return false
	var s := int(move.startup)
	return state_frame >= s and state_frame < s + int(move.active)


func is_invulnerable() -> bool:
	return state == State.DASH and state_frame >= int(G.dash_invuln_start) and state_frame <= int(G.dash_invuln_end)


func is_alive() -> bool:
	return state != State.DEAD


func knock_speed() -> float:
	return knock.length()


func nearest_opponent() -> Fighter:
	var best: Fighter = null
	var best_d := INF
	for o in opponents:
		if not o.is_alive():
			continue
		var d := position.distance_squared_to(o.position)
		if d < best_d:
			best_d = d
			best = o
	return best


func _read_input(inp: InputFrame) -> void:
	for b in BUTTONS:
		var h: bool = inp.get(b)
		_pressed[b] = h and not _held[b]
		if _pressed[b]:
			_last_press[b] = frame
		_held[b] = h
	# Double-tap a direction to sprint.
	var mag := inp.move.length()
	if _prev_mag < 0.3 and mag > 0.6:
		if frame - _last_tap_frame <= int(G.double_tap_frames):
			_sprinting = true
		_last_tap_frame = frame
	if mag < 0.3 or stamina <= 0.0:
		_sprinting = false
	_prev_mag = mag


func _recent(b: String) -> bool:
	return frame - int(_last_press[b]) <= int(G.combo_window)


func _tick_idle(inp: InputFrame) -> void:
	if _pressed.dash and _dash_cooldown == 0 and stamina >= float(G.dash_cost):
		_start_dash(inp)
		return
	if (_pressed.kick and _recent("guard")) or (_pressed.guard and _recent("kick")):
		_start_move("throw")
		return
	if (_pressed.light and _recent("heavy")) or (_pressed.heavy and _recent("light")):
		if _can_afford("special"):
			_start_move("special")
			return
	if _pressed.light:
		chain_index = 0
		_start_move("light1")
		return
	if _pressed.heavy:
		_start_move("heavy")
		return
	if _pressed.kick:
		_start_move("kick")
		return
	if _held.guard:
		_guard_press_frame = int(_last_press.guard)
		_enter(State.GUARD)
		_face_nearest()
		move_vel = Vector3.ZERO
		return
	_walk(inp, float(G.walk_speed))


func _tick_guard(inp: InputFrame) -> void:
	if _pressed.kick and state_frame <= int(G.combo_window):
		_start_move("throw")
		return
	if _pressed.dash and _dash_cooldown == 0 and stamina >= float(G.dash_cost):
		_start_dash(inp)
		return
	if not _held.guard:
		_enter(State.IDLE)
		return
	stamina -= float(G.guard_drain)
	if stamina <= 0.0:
		stamina = 0.0
		get_stunned(int(G.guard_break_stun))
		EventBus.attack_resolved.emit(null, self, "", "guard_break", 0.0)
		return
	var dir := _move_dir(inp)
	move_vel = dir * float(G.guard_walk_speed) * speed_mult
	_face_nearest()


func _tick_attack() -> void:
	var s := int(move.startup)
	var a := int(move.active)
	var r := int(move.recovery)
	var f := state_frame
	# Two buttons pressed nearly together upgrade the move that just started.
	if f <= int(G.combo_window):
		if move_name in ["light1", "heavy"] and _recent("light") and _recent("heavy") and _can_afford("special"):
			_start_move("special")
			return
		if move_name == "kick" and _recent("guard"):
			_start_move("throw")
			return
	# Hold heavy to charge the overhead cleave.
	if move_name == "heavy" and f == s - 1 and _held.heavy:
		charge += 1
		state_frame -= 1
		move_vel = Vector3.ZERO
		if charge >= int(G.charge_frames):
			_start_move("overhead")
		return
	# Light slashes chain up to three hits.
	if move.get("light", false) and _pressed.light and chain_index < 2:
		_queued_light = true
	if _queued_light and f >= s + a:
		chain_index += 1
		_start_move("light%d" % (chain_index + 1))
		return
	if f == s:
		Sfx.play(str(move.get("sfx", "swing_light")))
	move_vel = facing * float(move.lunge) * speed_mult if f < s + a else Vector3.ZERO
	if f >= s + a + r:
		_enter(State.IDLE)


func _tick_dash() -> void:
	var t := float(state_frame) / float(G.dash_frames)
	move_vel = _dash_dir * float(G.dash_speed) * (1.0 - t * 0.7) * speed_mult
	if state_frame >= int(G.dash_frames):
		_enter(State.IDLE)


func _start_move(n: String) -> void:
	move_name = n
	move = MoveTable.MOVES[n]
	_move_hit.clear()
	_queued_light = false
	if n != "overhead":
		charge = 0
	stamina = maxf(stamina - float(move.get("stamina_cost", 0.0)), 0.0)
	_soft_lock()
	_enter(State.ATTACK)


func _start_dash(inp: InputFrame) -> void:
	var d := _move_dir(inp)
	if d.length() < 0.2:
		d = -facing   # no direction held: backstep
	_dash_dir = d.normalized()
	stamina -= float(G.dash_cost)
	_dash_cooldown = int(G.dash_cooldown)
	_enter(State.DASH)
	Sfx.play("dash", -4.0)


func _can_afford(n: String) -> bool:
	return stamina >= float(MoveTable.MOVES[n].get("stamina_cost", 0.0))


func _enter(s: State) -> void:
	state = s
	state_frame = 0
	if s != State.ATTACK:
		move_name = ""
		move = {}
		charge = 0


func _move_dir(inp: InputFrame) -> Vector3:
	var d := Vector3(inp.move.x, 0.0, inp.move.y)
	if side_view:
		d.z = 0.0
	return d.limit_length(1.0)


func _walk(inp: InputFrame, base_speed: float) -> void:
	var dir := _move_dir(inp)
	var mag := dir.length()
	if mag < 0.15:
		move_vel = Vector3.ZERO
		_face_nearest()
		return
	var speed := base_speed
	if _sprinting and stamina > 0.0:
		speed = float(G.sprint_speed)
		stamina -= float(G.sprint_cost)
	move_vel = dir.normalized() * mag * speed * speed_mult
	if side_view:
		_face_nearest()
	else:
		facing = dir.normalized()


## Every attack turns to the nearest enemy in range (soft lock-on).
func _soft_lock() -> void:
	var o := nearest_opponent()
	if o and position.distance_to(o.position) <= float(G.soft_lock_range):
		_face_nearest()


func _face_nearest() -> void:
	var o := nearest_opponent()
	if o == null:
		return
	var to := o.position - position
	to.y = 0.0
	if side_view:
		to.z = 0.0
	if to.length() > 0.01:
		facing = to.normalized()


func _regen() -> void:
	if state in [State.GUARD, State.BLOCKSTUN, State.DASH, State.DEAD] or _sprinting:
		return
	stamina = minf(stamina + float(G.stamina_regen), float(G.max_stamina))


func _take_damage(dmg: float) -> void:
	hp = maxf(hp - dmg, 0.0)
	damage_taken_this_round += dmg


func _die(dir: Vector3) -> void:
	hp = 0.0
	_enter(State.DEAD)
	knock = dir * 3.0
	move_vel = Vector3.ZERO


func _apply_motion() -> void:
	knock = knock.move_toward(Vector3.ZERO, float(G.knock_friction) / 60.0)
	var v := move_vel + knock
	if side_view:
		v.z = 0.0
	velocity = Vector3(v.x, 0.0, v.z)
	# Fixed 1/60 s step (not the engine's frame delta) so the simulation is deterministic.
	var motion := velocity / 60.0
	for i in 2:
		var hit := move_and_collide(motion)
		if hit == null:
			break
		motion = hit.get_remainder().slide(hit.get_normal())
	position.y = 0.0
	if side_view:
		position.z = 0.0
	rotation.y = atan2(-facing.x, -facing.z)


# --- Placeholder model and procedural animation -----------------------------

func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_body_mat = _mat(body_color)
	var trim_mat := _mat(trim_color)
	var skin_mat := _mat(Color(0.85, 0.66, 0.5))
	var straw_mat := _mat(Color(0.78, 0.66, 0.38))
	_blade_mat = _mat(Color(0.85, 0.87, 0.92))
	_blade_mat.metallic = 0.8
	_blade_mat.roughness = 0.25

	# Hakama (wide trousers), torso, belt, head and the straw kasa hat.
	_part(_model, _cyl(0.30, 0.42, 0.8), trim_mat, Vector3(0, 0.4, 0))
	_part(_model, _capsule(0.30, 0.95), _body_mat, Vector3(0, 1.15, 0))
	_part(_model, _cyl(0.32, 0.32, 0.1), trim_mat, Vector3(0, 0.82, 0))
	_part(_model, _sphere(0.18), skin_mat, Vector3(0, 1.72, 0))
	_part(_model, _cyl(0.03, 0.46, 0.2), straw_mat, Vector3(0, 1.9, 0))

	# Kicking leg, pivoting at the hip.
	_leg_pivot = Node3D.new()
	_leg_pivot.position = Vector3(0.12, 0.8, 0)
	_model.add_child(_leg_pivot)
	_part(_leg_pivot, _box(Vector3(0.16, 0.75, 0.16)), trim_mat, Vector3(0, -0.4, 0))
	_leg_pivot.visible = false

	# Katana in the right hand, blade along the pivot's -Z.
	_sword_pivot = Node3D.new()
	_sword_pivot.position = Vector3(0.3, 1.22, -0.1)
	_model.add_child(_sword_pivot)
	_part(_sword_pivot, _sphere(0.08), skin_mat, Vector3.ZERO)
	_part(_sword_pivot, _box(Vector3(0.05, 0.05, 0.28)), _mat(Color(0.1, 0.06, 0.04)), Vector3(0, 0, -0.02))
	_part(_sword_pivot, _box(Vector3(0.12, 0.12, 0.02)), _mat(Color(0.7, 0.55, 0.2)), Vector3(0, 0, -0.17))
	_part(_sword_pivot, _box(Vector3(0.025, 0.07, 1.0)), _blade_mat, Vector3(0, 0, -0.68))


func _update_visuals() -> void:
	if _model == null:
		return
	var pose := Vector3(-20, 15, 0)       # ready stance
	var pivot_z := -0.1
	var leg := 0.0
	var tilt := Vector3.ZERO
	var drop := 0.0
	match state:
		State.ATTACK:
			var a := _anim_poses(str(move.get("anim", "")))
			var s := float(move.startup)
			var act := float(move.active)
			var f := float(state_frame)
			if f < s:
				var t := f / maxf(s, 1.0)
				pose = pose.lerp(a.wind, ease(t, 0.5))
				pivot_z = lerpf(-0.1, a.wind_z, t)
				leg = lerpf(0.0, a.leg, t * 0.3)
			elif f < s + act:
				var t2 := (f - s + 1.0) / act
				pose = a.wind.lerp(a.end, ease(t2, 0.4))
				pivot_z = lerpf(a.wind_z, a.end_z, t2)
				leg = a.leg
			else:
				var rec := float(move.recovery)
				var t3 := clampf((f - s - act) / maxf(rec, 1.0), 0.0, 1.0)
				pose = a.end.lerp(pose, ease(t3, 2.0))
				pivot_z = lerpf(a.end_z, -0.1, t3)
				leg = lerpf(a.leg, 0.0, t3 * 2.0)
			if charge > 0:
				tilt.z = sin(frame * 1.7) * 2.0
		State.GUARD, State.BLOCKSTUN:
			pose = Vector3(30, 85, 0)
			pivot_z = -0.35
		State.HITSTUN, State.THROWN:
			tilt.x = -18.0
			pose = Vector3(-50, -30, 0)
		State.STUN:
			tilt.z = sin(frame * 0.35) * 12.0
			pose = Vector3(-60, -20, 0)
		State.DASH:
			tilt.x = 15.0
		State.DEAD:
			var td := clampf(state_frame / 20.0, 0.0, 1.0)
			tilt.x = lerpf(0.0, -88.0, ease(td, 0.4))
			drop = lerpf(0.0, 0.15, td)
			pose = Vector3(-70, -40, 0)
		State.VICTORY:
			pose = Vector3(110, 0, 0)
			pivot_z = 0.0
	_sword_pivot.rotation_degrees = pose
	_sword_pivot.position.z = pivot_z
	_leg_pivot.visible = leg > 1.0
	_leg_pivot.rotation_degrees.x = leg
	_model.rotation_degrees = tilt
	_model.position.y = drop
	# Hit flash and charge glow.
	if _flash > 0:
		_flash -= 1
	_body_mat.emission_enabled = _flash > 0
	_body_mat.emission = Color(1, 0.9, 0.85)
	_body_mat.emission_energy_multiplier = 1.5
	var glowing := charge > 0 or move_name == "overhead"
	_blade_mat.emission_enabled = glowing
	_blade_mat.emission = Color(1.0, 0.15, 0.05)
	_blade_mat.emission_energy_multiplier = 0.6 + 0.08 * charge


func _anim_poses(anim: String) -> Dictionary:
	match anim:
		"sweep_l":
			return {"wind": Vector3(5, -110, 0), "end": Vector3(-10, 80, 0), "wind_z": -0.1, "end_z": -0.2, "leg": 0.0}
		"sweep_r":
			return {"wind": Vector3(5, 95, 0), "end": Vector3(-10, -100, 0), "wind_z": -0.1, "end_z": -0.2, "leg": 0.0}
		"thrust":
			return {"wind": Vector3(0, -5, 0), "end": Vector3(-5, 0, 0), "wind_z": 0.3, "end_z": -0.5, "leg": 0.0}
		"diagonal":
			return {"wind": Vector3(75, -70, 0), "end": Vector3(-60, 60, 0), "wind_z": 0.0, "end_z": -0.2, "leg": 0.0}
		"overhead":
			return {"wind": Vector3(130, 0, 0), "end": Vector3(-70, 0, 0), "wind_z": 0.1, "end_z": -0.3, "leg": 0.0}
		"rising":
			return {"wind": Vector3(-75, -40, 0), "end": Vector3(115, 30, 0), "wind_z": -0.1, "end_z": -0.2, "leg": 0.0}
		"kick":
			return {"wind": Vector3(-20, 15, 0), "end": Vector3(-20, 15, 0), "wind_z": -0.1, "end_z": -0.1, "leg": 85.0}
		"throw":
			return {"wind": Vector3(-40, 40, 0), "end": Vector3(-30, -20, 0), "wind_z": 0.0, "end_z": -0.4, "leg": 0.0}
	return {"wind": Vector3(-20, 15, 0), "end": Vector3(-20, 15, 0), "wind_z": -0.1, "end_z": -0.1, "leg": 0.0}


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 4
	return m


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 12
	return m
