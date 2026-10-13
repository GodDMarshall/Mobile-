class_name AIInput
extends InputSource
## A simple CPU opponent so one person can try the game, and so automated
## tests can play whole matches. Seeded, so a test match plays out the same way every time.

var rng := RandomNumberGenerator.new()
var aggression := 0.6
var _plan := "wait"
var _plan_frames := 0


func _init(seed_value: int = 1, aggression_level: float = 0.6) -> void:
	rng.seed = seed_value
	aggression = aggression_level


func poll(fighter: Node) -> InputFrame:
	var f := InputFrame.new()
	var me := fighter as Fighter
	if me == null:
		return f
	var foe := me.nearest_opponent()
	if foe == null:
		return f
	var to := foe.global_position - me.global_position
	var dist := Vector2(to.x, to.z).length()
	var dir := Vector2(to.x, to.z).normalized()
	if _plan_frames <= 0:
		_choose_plan(me, foe, dist)
	_plan_frames -= 1
	match _plan:
		"approach":
			f.move = dir
		"retreat":
			f.move = -dir
		"circle":
			f.move = (dir + Vector2(-dir.y, dir.x) * 1.5).normalized() if dist > 1.5 else Vector2(-dir.y, dir.x)
		"guard":
			f.guard = true
		"light":
			f.light = _plan_frames % 8 >= 4
		"heavy":
			f.heavy = _plan_frames > 2
		"charge":
			f.heavy = true
		"kick":
			f.kick = _plan_frames > 2
		"special":
			f.light = _plan_frames > 1
			f.heavy = _plan_frames > 1
		"throw":
			f.kick = _plan_frames > 1
			f.guard = _plan_frames > 1
		"dash_back":
			f.dash = _plan_frames > 1
			f.move = -dir
	return f


func _set_plan(plan: String, frames: int) -> void:
	_plan = plan
	_plan_frames = frames


func _choose_plan(me: Fighter, foe: Fighter, dist: float) -> void:
	var was_attack := _plan in ["light", "heavy", "charge", "kick", "special", "throw", "dash_back"]
	if was_attack:
		# Let go of the buttons briefly so the next press registers.
		_set_plan("wait", rng.randi_range(2, int(lerpf(18.0, 4.0, aggression))))
		return
	if dist < 2.8 and foe.state == Fighter.State.ATTACK and rng.randf() < 0.35:
		_set_plan("guard", rng.randi_range(10, 24))
		return
	if dist > 2.3:
		_set_plan("circle" if rng.randf() < 0.2 else "approach", rng.randi_range(8, 20))
		return
	var r := rng.randf()
	if foe.state == Fighter.State.GUARD and r < 0.4:
		_set_plan("throw", 4)
	elif r < 0.34:
		_set_plan("light", rng.randi_range(10, 20))
	elif r < 0.48:
		_set_plan("heavy", 6)
	elif r < 0.55:
		_set_plan("charge", 32)
	elif r < 0.65:
		_set_plan("kick", 6)
	elif r < 0.71 and me.stamina > 40.0:
		_set_plan("special", 4)
	elif r < 0.85:
		_set_plan("guard", rng.randi_range(12, 28))
	elif r < 0.91:
		_set_plan("dash_back", 4)
	else:
		_set_plan("circle", rng.randi_range(8, 16))
