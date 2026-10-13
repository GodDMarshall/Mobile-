class_name TouchInput
extends InputSource
## Reads one player's half of the screen (a TouchPad control).

var pad: Control


func _init(touch_pad: Control) -> void:
	pad = touch_pad


func poll(_fighter: Node) -> InputFrame:
	var f := InputFrame.new()
	if pad == null or not is_instance_valid(pad) or not pad.visible:
		return f
	f.move = pad.world_move()
	f.light = pad.is_down("light")
	f.heavy = pad.is_down("heavy")
	f.kick = pad.is_down("kick")
	f.guard = pad.is_down("guard")
	f.dash = pad.is_down("dash")
	return f
