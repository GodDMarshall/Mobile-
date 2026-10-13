extends Node
## Player-facing options. Kept in memory for the prototype; saving to disk comes with the settings screen.

enum Gore { FULL, LOW, OFF }
enum CameraMode { ARENA, CLASSIC_SIDE }
enum TouchLayout { FACING, SIDE_BY_SIDE }

var gore: Gore = Gore.FULL
var camera_mode: CameraMode = CameraMode.ARENA
var touch_layout: TouchLayout = TouchLayout.FACING
## Show on-screen touch controls even without a touchscreen (handy for testing with a mouse).
var force_touch_controls := false


func touch_controls_wanted() -> bool:
	return force_touch_controls or DisplayServer.is_touchscreen_available()
