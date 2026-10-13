class_name KeyboardInput
extends InputSource
## Desktop testing controls.
## Player 1: WASD move, F light, G heavy, H kick, T guard, R dash.
## Player 2: arrows move, numpad 1 light, 2 heavy, 3 kick, 5 guard, 0 dash.

const SCHEMES := [
	{"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
		"light": KEY_F, "heavy": KEY_G, "kick": KEY_H, "guard": KEY_T, "dash": KEY_R},
	{"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
		"light": KEY_KP_1, "heavy": KEY_KP_2, "kick": KEY_KP_3, "guard": KEY_KP_5, "dash": KEY_KP_0},
]

var keys: Dictionary


func _init(scheme: int) -> void:
	keys = SCHEMES[clampi(scheme, 0, SCHEMES.size() - 1)]


func poll(_fighter: Node) -> InputFrame:
	var f := InputFrame.new()
	var v := Vector2(
		float(_down("right")) - float(_down("left")),
		float(_down("down")) - float(_down("up")))
	f.move = v.normalized() if v.length() > 0.0 else Vector2.ZERO
	f.light = _down("light")
	f.heavy = _down("heavy")
	f.kick = _down("kick")
	f.guard = _down("guard")
	f.dash = _down("dash")
	return f


func _down(action: String) -> bool:
	return Input.is_physical_key_pressed(keys[action])
