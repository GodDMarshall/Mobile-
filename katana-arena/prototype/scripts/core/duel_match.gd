class_name DuelMatch
extends Node3D
## Duel mode: two samurai, best of three rounds, in the Spike Courtyard.
## Owns the fixed 60 Hz step: input -> fighter ticks -> hit resolution -> hazards -> round rules.
## Hit-stop freezes the simulation for a few ticks while effects keep playing.

signal finished(result: Dictionary)

enum Phase { INTRO, FIGHT, ROUND_OVER, MATCH_OVER }

const MoveTable := preload("res://data/move_table.gd")
const FighterTable := preload("res://data/fighter_table.gd")
const INTRO_FRAMES := 130
const ROUND_OVER_FRAMES := 170
const MATCH_OVER_FRAMES := 150

var G: Dictionary = MoveTable.GLOBALS
var config: Dictionary
var side_view := false
var auto_step := true

var arena: SpikeCourtyard
var fx: BloodFx
var camera: ArenaCamera
var hud: Hud
var touch_layer: CanvasLayer
var pads: Array[TouchPad] = []
var fighters: Array[Fighter] = []
var inputs: Array[InputSource] = []

var phase: Phase = Phase.INTRO
var phase_frames := 0
var round_number := 0
var round_wins: Array[int] = [0, 0]
var round_frames_left := 0
var hitstop := 0
var first_blood_done := false
var round_log: Array = []   # one entry per round, for results and tests
var hit_count := 0

var _rng := RandomNumberGenerator.new()


func setup(cfg: Dictionary) -> void:
	config = cfg
	name = "DuelMatch"
	_rng.seed = int(cfg.get("seed", 7))
	side_view = GameSettings.camera_mode == GameSettings.CameraMode.CLASSIC_SIDE
	arena = SpikeCourtyard.new()
	add_child(arena)
	arena.build(side_view)
	fx = BloodFx.new()
	add_child(fx)

	var ids: Array = cfg.get("fighters", ["ronin_kage", "akane"])
	for i in 2:
		var f := Fighter.new()
		f.setup(ids[i], FighterTable.FIGHTERS[ids[i]], i)
		f.side_view = side_view
		add_child(f)
		fighters.append(f)
	fighters[0].opponents.append(fighters[1])
	fighters[1].opponents.append(fighters[0])

	_build_inputs(str(cfg.get("mode", "pvp")))

	camera = ArenaCamera.new()
	camera.side_view = side_view
	for f in fighters:
		camera.targets.append(f)
	add_child(camera)
	camera.current = true

	hud = Hud.new()
	hud.fighters = fighters
	hud.round_wins = round_wins
	hud.rounds_to_win = int(G.rounds_to_win)
	hud.facing_layout = pads.size() == 2 and GameSettings.touch_layout == GameSettings.TouchLayout.FACING
	add_child(hud)

	EventBus.attack_resolved.connect(_on_attack)

	if cfg.get("mode") == "test":
		auto_step = false
		phase = Phase.FIGHT
		round_frames_left = 1 << 30
		for i in 2:
			fighters[i].reset_for_round(arena.spawn_points[i], Vector3(1 - 2 * i, 0, 0))
			fighters[i].controllable = true
	else:
		_start_round()
	camera.snap()


func _exit_tree() -> void:
	if EventBus.attack_resolved.is_connected(_on_attack):
		EventBus.attack_resolved.disconnect(_on_attack)
	Announcer.clear()


func _build_inputs(mode: String) -> void:
	var want_touch := GameSettings.touch_controls_wanted() and mode in ["pvp", "cpu"]
	if want_touch:
		_build_touch(mode == "cpu")
	for i in 2:
		var src: InputSource
		match mode:
			"demo":
				src = AIInput.new(int(config.get("seed", 7)) * 31 + i, 0.75)
			"cpu":
				src = _human_input(i) if i == 0 else AIInput.new(_rng.randi(), 0.55)
			"test":
				src = config.scripts[i]
			_:
				src = _human_input(i)
		inputs.append(src)


func _human_input(i: int) -> InputSource:
	var list: Array[InputSource] = [KeyboardInput.new(i), GamepadInput.new(i)]
	if i < pads.size():
		list.append(TouchInput.new(pads[i]))
	return CompositeInput.new(list)


func _build_touch(single_player: bool) -> void:
	touch_layer = CanvasLayer.new()
	touch_layer.layer = 10
	add_child(touch_layer)
	var count := 1 if single_player else 2
	for i in count:
		var pad := TouchPad.new()
		pad.player_color = FighterTable.FIGHTERS[config.get("fighters", ["ronin_kage", "akane"])[i]].color.lightened(0.3)
		touch_layer.add_child(pad)
		pads.append(pad)
	get_viewport().size_changed.connect(_layout_touch)
	_layout_touch()


## Two players facing each other across a flat phone: P1 owns the bottom half,
## P2 the top half rotated to face them. Side by side: left and right halves.
func _layout_touch() -> void:
	var vs := get_viewport().get_visible_rect().size
	if pads.size() == 1:
		pads[0].position = Vector2.ZERO
		pads[0].size = vs
		pads[0].rotation = 0.0
		return
	var facing := GameSettings.touch_layout == GameSettings.TouchLayout.FACING
	for i in pads.size():
		var pad := pads[i]
		if facing:
			pad.size = Vector2(vs.x, vs.y * 0.5)
			pad.position = Vector2(0, vs.y * 0.5) if i == 0 else Vector2.ZERO
			pad.pivot_offset = pad.size * 0.5
			pad.rotation = 0.0 if i == 0 else PI
		else:
			pad.size = Vector2(vs.x * 0.5, vs.y)
			pad.position = Vector2(vs.x * 0.5 * i, 0)
			pad.rotation = 0.0
		pad.queue_redraw()


# --- Fixed step -------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if auto_step:
		step()


func step() -> void:
	_tick_phase()
	if hitstop > 0:
		hitstop -= 1
		return
	for i in fighters.size():
		fighters[i].tick(inputs[i].poll(fighters[i]))
	for f in fighters:
		f.resolve_attacks()
	_check_hazards()
	if phase == Phase.FIGHT:
		round_frames_left -= 1
		if round_frames_left <= 0:
			_end_round_on_time()
	hud.time_left_frames = maxi(round_frames_left, 0)


func _tick_phase() -> void:
	match phase:
		Phase.INTRO:
			phase_frames -= 1
			if phase_frames == INTRO_FRAMES - 55:
				Announcer.say("Draw your blades...", Announcer.PRIORITY_NORMAL, "callout", 1.0, false)
			elif phase_frames == 0:
				Announcer.say("FIGHT!", Announcer.PRIORITY_HIGH, "gong", 0.9)
				phase = Phase.FIGHT
				for f in fighters:
					f.controllable = true
				EventBus.fight_began.emit()
		Phase.ROUND_OVER:
			phase_frames -= 1
			if phase_frames == ROUND_OVER_FRAMES - 45:
				for f in fighters:
					if f.is_alive() and f == _round_winner():
						f.win_pose()
			if phase_frames <= 0:
				if round_wins.max() >= int(G.rounds_to_win):
					_end_match()
				else:
					_start_round()
		Phase.MATCH_OVER:
			phase_frames -= 1
			if phase_frames == 0:
				finished.emit(_result())


func _start_round() -> void:
	round_number += 1
	phase = Phase.INTRO
	phase_frames = INTRO_FRAMES
	round_frames_left = int(G.round_frames)
	hitstop = 0
	fx.clear_pools()
	for i in 2:
		fighters[i].reset_for_round(arena.spawn_points[i], Vector3(1 - 2 * i, 0, 0))
		fighters[i].controllable = false
	for pad in pads:
		pad.release_all()
	var final_round := round_wins[0] == int(G.rounds_to_win) - 1 and round_wins[1] == int(G.rounds_to_win) - 1
	Announcer.clear()
	Announcer.say("FINAL ROUND" if final_round else "ROUND %d" % round_number, Announcer.PRIORITY_NORMAL, "callout", 0.9)
	EventBus.round_started.emit(round_number)
	if camera:
		camera.snap()


func _on_attack(attacker: Node, defender: Node, move_name: String, result: String, dmg: float) -> void:
	var mv: Dictionary = MoveTable.MOVES.get(move_name, {})
	var hs := int(mv.get("hitstop", 3))
	var d := defender as Fighter
	var hit_pos := d.position + Vector3(0, 1.2, 0)
	var dir := Vector3.RIGHT
	if attacker:
		dir = (d.position - (attacker as Fighter).position)
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.RIGHT
	match result:
		"hit", "kill", "throw":
			hit_count += 1
			hitstop = maxi(hitstop, hs + (8 if result == "kill" else 0))
			fx.blood(hit_pos, dir, dmg)
			if move_name == "kick":
				Sfx.play("kick_hit")
			elif result == "throw":
				Sfx.play("body_fall")
			else:
				Sfx.play("cut")
			camera.add_shake(0.12 + dmg * 0.012)
			if result == "kill":
				Sfx.play("body_fall", -2.0)
				_on_kill(d, attacker as Fighter, "blade")
		"armor":
			hitstop = maxi(hitstop, 2)
			fx.blood(hit_pos, dir, dmg * 0.5)
			Sfx.play("cut", -4.0)
		"block":
			hitstop = maxi(hitstop, 3)
			fx.sparks(hit_pos + dir * -0.4, false)
			Sfx.play("clang")
			camera.add_shake(0.05)
		"parry":
			hitstop = maxi(hitstop, 10)
			fx.sparks(hit_pos + dir * -0.4, true)
			Sfx.play("parry")
			camera.add_shake(0.2)
			if _rng.randf() < 0.35:
				Announcer.say("DENIED!", Announcer.PRIORITY_LOW, "callout", 0.9, false)
		"guard_break":
			hitstop = maxi(hitstop, 6)
			fx.sparks(hit_pos, true)
			Sfx.play("guard_break")
			camera.add_shake(0.25)


func _check_hazards() -> void:
	for f in fighters:
		if not f.is_alive() or f.hazard_cooldown > 0 or f.knock_speed() < float(G.hazard_knock_min):
			continue
		var push := arena.spike_push(f.position)
		if push == Vector3.ZERO:
			continue
		var killed := f.receive_hazard(push, float(G.hazard_damage))
		fx.blood(f.position + Vector3(0, 1.0, 0), push, 30.0)
		Sfx.play("spike")
		camera.add_shake(0.35)
		hitstop = maxi(hitstop, 8)
		EventBus.hazard_hit.emit(f, killed)
		if killed:
			Announcer.say("INTO THE SPIKES!", Announcer.PRIORITY_HIGH, "callout", 1.3)
			_on_kill(f, f.opponents[0], "spikes")


func _on_kill(victim: Fighter, killer: Fighter, cause: String) -> void:
	if phase != Phase.FIGHT:
		return
	EventBus.fighter_killed.emit(victim, killer, cause)
	if not first_blood_done:
		first_blood_done = true
		Announcer.say("FIRST BLOOD!", Announcer.PRIORITY_NORMAL, "callout", 1.0)
	_finish_round(fighters.find(killer), "kill")


func _end_round_on_time() -> void:
	var a := fighters[0].hp / fighters[0].max_hp
	var b := fighters[1].hp / fighters[1].max_hp
	Announcer.say("TIME!", Announcer.PRIORITY_HIGH, "gong", 0.9)
	if absf(a - b) < 0.001:
		_finish_round(-1, "time")
	else:
		_finish_round(0 if a > b else 1, "time")


func _finish_round(winner: int, reason: String) -> void:
	phase = Phase.ROUND_OVER
	phase_frames = ROUND_OVER_FRAMES
	for f in fighters:
		f.controllable = false
	if winner == -1:
		# A draw gives both fighters the round.
		round_wins[0] += 1
		round_wins[1] += 1
		Announcer.say("DRAW", Announcer.PRIORITY_NORMAL, "callout", 1.2)
	else:
		round_wins[winner] += 1
		var w := fighters[winner]
		if w.damage_taken_this_round <= 0.0:
			Announcer.say("UNTOUCHED!", Announcer.PRIORITY_NORMAL, "callout", 1.2)
		Announcer.say("%s WINS!" % w.display_name.to_upper(), Announcer.PRIORITY_NORMAL, "callout", 1.4)
	round_log.append({"round": round_number, "winner": winner, "reason": reason,
		"hp": [fighters[0].hp, fighters[1].hp]})
	EventBus.round_ended.emit(fighters[winner] if winner >= 0 else null, reason)


func _round_winner() -> Fighter:
	if round_log.is_empty():
		return null
	var w: int = round_log[-1].winner
	return fighters[w] if w >= 0 else null


func _end_match() -> void:
	phase = Phase.MATCH_OVER
	phase_frames = MATCH_OVER_FRAMES
	var w := _match_winner()
	EventBus.match_ended.emit(fighters[w] if w >= 0 else null)


func _match_winner() -> int:
	var need := int(G.rounds_to_win)
	if round_wins[0] >= need and round_wins[1] >= need:
		return -1
	return 0 if round_wins[0] >= need else 1


func _result() -> Dictionary:
	var w := _match_winner()
	return {"winner": w, "winner_name": fighters[w].display_name if w >= 0 else "", "rounds": round_log,
		"round_wins": round_wins.duplicate(), "hits": hit_count}
