class_name InputSource
extends RefCounted
## Base class for anything that can drive a fighter.


func poll(_fighter: Node) -> InputFrame:
	return InputFrame.new()
