class_name CompositeInput
extends InputSource
## Merges several sources, so a player can use touch, a keyboard and a gamepad at once.

var sources: Array[InputSource] = []


func _init(list: Array[InputSource] = []) -> void:
	sources = list


func poll(fighter: Node) -> InputFrame:
	var f := InputFrame.new()
	for s in sources:
		f.merge(s.poll(fighter))
	return f
