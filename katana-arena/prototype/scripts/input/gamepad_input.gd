class_name GamepadInput
extends InputSource
## Bluetooth or USB controller. Left stick or d-pad to move,
## X light, Y heavy, A kick, B dash, right bumper or right trigger guard.

const DEADZONE := 0.2

var device := 0


func _init(device_id: int) -> void:
	device = device_id


func poll(_fighter: Node) -> InputFrame:
	var f := InputFrame.new()
	if not Input.get_connected_joypads().has(device):
		return f
	var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	if v.length() < DEADZONE:
		v = Vector2(
			float(_btn(JOY_BUTTON_DPAD_RIGHT)) - float(_btn(JOY_BUTTON_DPAD_LEFT)),
			float(_btn(JOY_BUTTON_DPAD_DOWN)) - float(_btn(JOY_BUTTON_DPAD_UP)))
	f.move = v.limit_length(1.0) if v.length() >= DEADZONE else Vector2.ZERO
	f.light = _btn(JOY_BUTTON_X)
	f.heavy = _btn(JOY_BUTTON_Y)
	f.kick = _btn(JOY_BUTTON_A)
	f.dash = _btn(JOY_BUTTON_B)
	f.guard = _btn(JOY_BUTTON_RIGHT_SHOULDER) or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	return f


func _btn(b: JoyButton) -> bool:
	return Input.is_joy_button_pressed(device, b)
