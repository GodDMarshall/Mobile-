class_name TouchPad
extends Control
## One player's on-screen controls: a floating stick on the left and five buttons
## on the right, from that player's own seat. The far player's pad is simply rotated
## 180 degrees, and the stick is converted to arena directions through the pad's own rotation.

const STICK_RADIUS := 80.0
const BUTTONS := [
	# name, label, offset from the cluster centre, radius
	["light", "LIGHT", Vector2(-88, 0), 46.0],
	["heavy", "HEAVY", Vector2(0, -88), 46.0],
	["kick", "KICK", Vector2(0, 88), 46.0],
	["guard", "GUARD", Vector2(88, 0), 46.0],
	["dash", "DASH", Vector2(-190, -70), 38.0],
]

var player_color := Color.WHITE
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _finger_button := {}   # touch index -> button name


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_down(button: String) -> bool:
	return _finger_button.values().has(button)


## Stick direction on the arena floor (x = world X, y = world Z).
func world_move() -> Vector2:
	if _stick_finger == -1:
		return Vector2.ZERO
	var v := (_stick_pos - _stick_origin) / STICK_RADIUS
	v = v.limit_length(1.0)
	if v.length() < 0.15:
		return Vector2.ZERO
	# Local "up" is away from this player. Rotate into screen space; screen down = world +Z.
	return get_global_transform().basis_xform(v).normalized() * v.length()


func release_all() -> void:
	_stick_finger = -1
	_finger_button.clear()
	queue_redraw()


func _cluster_centre() -> Vector2:
	return Vector2(size.x - 170.0, size.y - 150.0)


func _button_at(local: Vector2) -> String:
	var c := _cluster_centre()
	for b in BUTTONS:
		if local.distance_to(c + b[2]) <= b[3] * 1.25:
			return b[0]
	return ""


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var local := (make_input_local(event) as InputEventScreenTouch).position
		if event.pressed:
			if not Rect2(Vector2.ZERO, size).has_point(local):
				return
			var b := _button_at(local)
			if b != "":
				_finger_button[event.index] = b
			elif local.x < size.x * 0.55 and _stick_finger == -1:
				_stick_finger = event.index
				_stick_origin = local
				_stick_pos = local
		else:
			if event.index == _stick_finger:
				_stick_finger = -1
			_finger_button.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var local := (make_input_local(event) as InputEventScreenDrag).position
		if event.index == _stick_finger:
			_stick_pos = local
			var off := _stick_pos - _stick_origin
			if off.length() > STICK_RADIUS * 1.4:   # drag the stick base along
				_stick_origin = _stick_pos - off.normalized() * STICK_RADIUS * 1.4
			queue_redraw()
		elif _finger_button.has(event.index):
			var b := _button_at(local)
			if b != "" and b != _finger_button[event.index]:
				_finger_button[event.index] = b   # slide between buttons
				queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var base_col := Color(player_color, 0.18)
	var ring_col := Color(player_color, 0.55)
	# Stick
	var origin := _stick_origin if _stick_finger != -1 else Vector2(170.0, size.y - 150.0)
	draw_circle(origin, STICK_RADIUS, base_col)
	draw_arc(origin, STICK_RADIUS, 0, TAU, 40, ring_col, 3.0)
	var knob := origin
	if _stick_finger != -1:
		knob = origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS)
	draw_circle(knob, 34.0, Color(player_color, 0.5))
	# Buttons
	var c := _cluster_centre()
	for b in BUTTONS:
		var pos: Vector2 = c + b[2]
		var down := is_down(b[0])
		draw_circle(pos, b[3], Color(player_color, 0.55 if down else 0.2))
		draw_arc(pos, b[3], 0, TAU, 32, ring_col, 3.0)
		var fs := 15 if b[3] > 40.0 else 13
		draw_string(font, pos + Vector2(-b[3], fs * 0.35), b[1], HORIZONTAL_ALIGNMENT_CENTER, b[3] * 2.0, fs, Color(1, 1, 1, 0.85))
