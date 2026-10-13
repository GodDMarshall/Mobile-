class_name CombatTests
extends Node
## Scripted combat checks. Each test builds a fresh duel with no intro, places the
## fighters, feeds both of them a fixed list of inputs and checks the outcome.
## Run: godot --headless --path . -- --combat-tests

var _main: Node
var _results: Array[String] = []
var _failures := 0
var _events: Array = []


func run_all(main: Node) -> int:
	_main = main
	EventBus.attack_resolved.connect(func(_a, _d, m, r, _dmg): _events.append("%s:%s" % [m, r]))
	await _test_light_hit()
	await _test_three_hit_chain()
	await _test_block()
	await _test_parry()
	await _test_guard_break()
	await _test_throw_beats_guard()
	await _test_heavy_armor_beats_light()
	await _test_charged_overhead()
	await _test_special()
	await _test_dash_evades()
	await _test_kick_into_spikes()
	await _test_sprint_double_tap()
	print("")
	for r in _results:
		print(r)
	print("COMBAT TESTS: %d passed, %d failed" % [_results.size() - _failures, _failures])
	return _failures


# --- helpers ----------------------------------------------------------------

func _duel(p1: ScriptedInput, p2: ScriptedInput, x1 := -1.0, x2 := 0.5) -> DuelMatch:
	_events.clear()
	var m := DuelMatch.new()
	_main.add_child(m)
	m.setup({"mode": "test", "fighters": ["ronin_kage", "ronin_kage"], "scripts": [p1, p2]})
	m.fighters[0].reset_for_round(Vector3(x1, 0, 0), Vector3.RIGHT)
	m.fighters[1].reset_for_round(Vector3(x2, 0, 0), Vector3.LEFT)
	return m


## Runs real physics frames, so body positions reach the physics server like in a match.
func _run(m: DuelMatch, frames: int) -> void:
	await get_tree().physics_frame
	var start := m.fighters[0].frame
	m.auto_step = true
	while m.fighters[0].frame - start < frames:
		await get_tree().physics_frame
	m.auto_step = false


func _done(m: DuelMatch) -> void:
	_main.remove_child(m)
	m.queue_free()


func _check(test: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	_results.append("%s  %s  (%s)" % ["PASS" if ok else "FAIL", test, detail])


static func press(n: int, buttons: Array, move := Vector2.ZERO) -> Callable:
	return func(f: InputFrame):
		for b in buttons:
			f.set(b, true)
		f.move = move


func _s() -> ScriptedInput:
	return ScriptedInput.new()


# --- tests --------------------------------------------------------------------

func _test_light_hit() -> void:
	var m := _duel(_s().hold(2, press(2, ["light"])), _s())
	await _run(m, 40)
	var hp := m.fighters[1].hp
	_check("Light slash hits an idle opponent for 6", is_equal_approx(hp, 94.0), "P2 hp %.1f, events %s" % [hp, _events])
	_done(m)


func _test_three_hit_chain() -> void:
	var p1 := _s().hold(2, press(2, ["light"])).idle(6).hold(2, press(2, ["light"])).idle(6).hold(2, press(2, ["light"]))
	var m := _duel(p1, _s())
	await _run(m, 90)
	var hp := m.fighters[1].hp
	_check("Three light slashes chain for 18", is_equal_approx(hp, 82.0), "P2 hp %.1f, events %s" % [hp, _events])
	_done(m)


func _test_block() -> void:
	var m := _duel(_s().idle(15).hold(2, press(2, ["light"])), _s().hold(80, press(80, ["guard"])))
	await _run(m, 40)
	var f := m.fighters[1]
	_check("Guard blocks a light slash", is_equal_approx(f.hp, 100.0) and f.stamina < 100.0 and _events.has("light1:block"),
		"P2 hp %.1f stamina %.1f, events %s" % [f.hp, f.stamina, _events])
	_done(m)


func _test_parry() -> void:
	# The light slash lands on tick 7; P2 presses guard on tick 5, inside the 6-frame window.
	var m := _duel(_s().hold(2, press(2, ["light"])), _s().idle(4).hold(30, press(30, ["guard"])))
	await _run(m, 12)
	var a := m.fighters[0]
	var d := m.fighters[1]
	_check("Fresh guard right before a hit parries and stuns the attacker",
		_events.has("light1:parry") and a.state == Fighter.State.STUN and is_equal_approx(d.hp, 100.0),
		"attacker state %s, P2 hp %.1f, events %s" % [Fighter.State.keys()[a.state], d.hp, _events])
	_done(m)


func _test_guard_break() -> void:
	var m := _duel(_s().idle(15).hold(2, press(2, ["heavy"])), _s().hold(80, press(80, ["guard"])))
	m.fighters[1].stamina = 10.0
	await _run(m, 40)
	var d := m.fighters[1]
	_check("Blocking with no stamina left breaks the guard", _events.has("heavy:guard_break") and d.state == Fighter.State.STUN,
		"P2 state %s, events %s" % [Fighter.State.keys()[d.state], _events])
	_done(m)


func _test_throw_beats_guard() -> void:
	var m := _duel(_s().idle(12).hold(3, press(3, ["kick", "guard"])), _s().hold(80, press(80, ["guard"])))
	await _run(m, 30)
	var d := m.fighters[1]
	_check("Kick + Guard throws a blocking opponent for 12", is_equal_approx(d.hp, 88.0) and _events.has("throw:throw"),
		"P2 hp %.1f, events %s" % [d.hp, _events])
	_done(m)


func _test_heavy_armor_beats_light() -> void:
	var m := _duel(_s().hold(2, press(2, ["heavy"])), _s().idle(2).hold(2, press(2, ["light"])))
	await _run(m, 45)
	var a := m.fighters[0]
	var d := m.fighters[1]
	_check("Heavy slash breaks through a light slash", _events.has("light1:armor") and is_equal_approx(d.hp, 86.0) and is_equal_approx(a.hp, 94.0),
		"P1 hp %.1f, P2 hp %.1f, events %s" % [a.hp, d.hp, _events])
	_done(m)


func _test_charged_overhead() -> void:
	var m := _duel(_s().hold(60, press(60, ["heavy"])), _s())
	await _run(m, 80)
	var d := m.fighters[1]
	_check("Holding heavy charges an overhead cleave for 25", is_equal_approx(d.hp, 75.0) and _events.has("overhead:hit"),
		"P2 hp %.1f, events %s" % [d.hp, _events])
	_done(m)


func _test_special() -> void:
	var m := _duel(_s().hold(3, press(3, ["light", "heavy"])), _s())
	await _run(m, 50)
	var a := m.fighters[0]
	var d := m.fighters[1]
	_check("Light + Heavy does the special for 17", is_equal_approx(d.hp, 83.0) and _events.has("special:hit"),
		"P2 hp %.1f, P1 stamina %.1f, events %s" % [d.hp, a.stamina, _events])
	_done(m)


func _test_dash_evades() -> void:
	# P2 dashes through the slash; its invulnerable frames cover the hit.
	var m := _duel(_s().hold(2, press(2, ["light"])), _s().idle(4).hold(3, press(3, ["dash"], Vector2.LEFT)))
	await _run(m, 30)
	var d := m.fighters[1]
	_check("Dash is invulnerable", is_equal_approx(d.hp, 100.0) and _events.has("light1:evade"),
		"P2 hp %.1f, events %s" % [d.hp, _events])
	_done(m)


func _test_kick_into_spikes() -> void:
	var m := _duel(_s().hold(2, press(2, ["kick"])), _s(), 5.6, 6.6)
	await _run(m, 40)
	var d := m.fighters[1]
	_check("Kicking someone into the spike wall adds 30 hazard damage", is_equal_approx(d.hp, 66.0),
		"P2 hp %.1f, x %.2f, events %s" % [d.hp, d.position.x, _events])
	_done(m)


func _test_sprint_double_tap() -> void:
	var p1 := _s().hold(3, press(3, [], Vector2.LEFT)).idle(3).hold(30, press(30, [], Vector2.LEFT))
	var m := _duel(p1, _s(), 0.0, 5.0)
	await _run(m, 36)
	var walked := 0.0 - m.fighters[0].position.x
	_check("Double-tapping a direction sprints", walked > 3.0 and m.fighters[0].stamina < 100.0,
		"moved %.2f m in 36 ticks, stamina %.1f" % [walked, m.fighters[0].stamina])
	_done(m)
