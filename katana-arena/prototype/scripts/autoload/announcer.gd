extends Node
## Announcer callouts with a priority queue: two callouts never overlap, and a
## higher-priority line replaces a lower one. For the prototype a callout is big
## on-screen text plus a placeholder sting; the voiced lines arrive in step 4.

signal callout_shown(text: String, big: bool)
signal callout_cleared

const PRIORITY_LOW := 0
const PRIORITY_NORMAL := 1
const PRIORITY_HIGH := 2

var _queue: Array = []   # of {text, priority, sound, duration, big}
var _current: Dictionary = {}
var _time_left := 0.0


func say(text: String, priority := PRIORITY_NORMAL, sound := "callout", duration := 1.2, big := true) -> void:
	var item := {"text": text, "priority": priority, "sound": sound, "duration": duration, "big": big}
	if _current.is_empty():
		_show(item)
	elif priority > int(_current.priority):
		_show(item)
	else:
		_queue.append(item)


func clear() -> void:
	_queue.clear()
	_current = {}
	_time_left = 0.0
	callout_cleared.emit()


func _show(item: Dictionary) -> void:
	_current = item
	_time_left = float(item.duration)
	if item.sound != "":
		Sfx.play(item.sound, 0.0, 0.0)
	callout_shown.emit(item.text, item.big)


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	_current = {}
	if _queue.is_empty():
		callout_cleared.emit()
		return
	# Highest priority first, oldest first within a priority.
	var best := 0
	for i in _queue.size():
		if int(_queue[i].priority) > int(_queue[best].priority):
			best = i
	_show(_queue.pop_at(best))
