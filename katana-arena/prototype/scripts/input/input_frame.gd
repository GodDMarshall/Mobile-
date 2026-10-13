class_name InputFrame
extends RefCounted
## One tick of player intent. Touch, gamepad, keyboard, CPU and (later) network
## inputs all produce this, so the fighter never knows where input came from.

## Direction on the arena floor: x = world X (screen right), y = world Z (towards the camera).
var move := Vector2.ZERO
var light := false
var heavy := false
var kick := false
var guard := false
var dash := false


func merge(other: InputFrame) -> void:
	if other.move.length() > move.length():
		move = other.move
	light = light or other.light
	heavy = heavy or other.heavy
	kick = kick or other.kick
	guard = guard or other.guard
	dash = dash or other.dash


func to_dict() -> Dictionary:
	return {"m": move, "l": light, "h": heavy, "k": kick, "g": guard, "d": dash}
