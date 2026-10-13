class_name MainMenu
extends CanvasLayer
## Title and main menu. Wi-Fi Host and Join arrive with step 3.

signal start_requested(mode: String)

var _option_buttons := {}


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.03, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var title := Label.new()
	title.text = "KATANA ARENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 88)
	title.add_theme_color_override("font_color", Color(0.85, 0.1, 0.08))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 16)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "prototype: duel in the Spike Courtyard"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.75, 0.65, 0.6))
	col.add_child(sub)

	col.add_child(_big_button("2 PLAYERS  (this phone)", func(): start_requested.emit("pvp")))
	col.add_child(_big_button("VS CPU", func(): start_requested.emit("cpu")))
	col.add_child(_big_button("CPU VS CPU  (watch)", func(): start_requested.emit("demo")))

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 10)
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(opts)
	opts.add_child(_option("camera", ["Camera: Arena", "Camera: Classic side"]))
	opts.add_child(_option("touch", ["Controls: Facing", "Controls: Side by side"]))
	opts.add_child(_option("gore", ["Gore: Full", "Gore: Low", "Gore: Off"]))
	_refresh()


func _big_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(520, 76)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(cb)
	return b


func _option(key: String, labels: Array) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(250, 56)
	b.add_theme_font_size_override("font_size", 20)
	b.set_meta("labels", labels)
	b.pressed.connect(func(): _cycle(key))
	_option_buttons[key] = b
	return b


func _cycle(key: String) -> void:
	match key:
		"camera":
			GameSettings.camera_mode = (GameSettings.camera_mode + 1) % 2 as GameSettings.CameraMode
		"touch":
			GameSettings.touch_layout = (GameSettings.touch_layout + 1) % 2 as GameSettings.TouchLayout
		"gore":
			GameSettings.gore = (GameSettings.gore + 1) % 3 as GameSettings.Gore
	_refresh()


func _refresh() -> void:
	var values := {"camera": GameSettings.camera_mode, "touch": GameSettings.touch_layout, "gore": GameSettings.gore}
	for key in _option_buttons:
		var b: Button = _option_buttons[key]
		b.text = b.get_meta("labels")[int(values[key])]
