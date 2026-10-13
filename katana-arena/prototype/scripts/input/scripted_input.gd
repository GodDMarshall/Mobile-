class_name ScriptedInput
extends InputSource
## Plays back a fixed list of frames. Used by the automated combat tests.

var frames: Array = []   # of InputFrame (or null for "nothing")
var index := 0


func hold(frame_count: int, setup: Callable = Callable()) -> ScriptedInput:
	for i in frame_count:
		var f := InputFrame.new()
		if setup.is_valid():
			setup.call(f)
		frames.append(f)
	return self


func idle(frame_count: int) -> ScriptedInput:
	return hold(frame_count)


func poll(_fighter: Node) -> InputFrame:
	if index >= frames.size():
		return InputFrame.new()
	var f: InputFrame = frames[index]
	index += 1
	return f
