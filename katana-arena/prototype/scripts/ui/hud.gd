class_name Hud
extends CanvasLayer
## Health and stamina bars, round pips, timer and announcer callouts.

var fighters: Array[Fighter] = []
var round_wins: Array[int] = [0, 0]
var rounds_to_win := 2
var time_left_frames := 0
## Two players facing each other across a flat phone: each gets their bar at their own edge.
var facing_layout := false

var _bars: Control
var _callout: Label
var _seat2: Control


func _ready() -> void:
	layer = 5
	_bars = Control.new()
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	if facing_layout:
		_seat2 = Control.new()
		_seat2.set_anchors_preset(Control.PRESET_FULL_RECT)
		_seat2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_seat2.draw.connect(func(): _draw_seat(_seat2, 1))
		_seat2.resized.connect(func(): _seat2.pivot_offset = _seat2.size * 0.5)
		_seat2.rotation = PI
		add_child(_seat2)

	_callout = Label.new()
	_callout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_callout.add_theme_font_size_override("font_size", 84)
	_callout.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	_callout.add_theme_color_override("font_outline_color", Color(0.25, 0.0, 0.0))
	_callout.add_theme_constant_override("outline_size", 18)
	_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_callout)
	Announcer.callout_shown.connect(_on_callout)
	Announcer.callout_cleared.connect(func(): _callout.text = "")


func _process(_delta: float) -> void:
	_bars.queue_redraw()
	if _seat2:
		_seat2.pivot_offset = _seat2.size * 0.5
		_seat2.queue_redraw()


func _on_callout(text: String, big: bool) -> void:
	_callout.text = text
	_callout.add_theme_font_size_override("font_size", 84 if big else 52)
	_callout.pivot_offset = _callout.size * 0.5
	_callout.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.tween_property(_callout, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw_bars() -> void:
	var w := _bars.size.x
	if facing_layout:
		# Each player's bar sits at their own edge of the phone, between stick and buttons.
		_draw_seat(_bars, 0)
		_draw_timer(Vector2(70, _bars.size.y * 0.5 + 14))
		return
	var bar_w := minf(w * 0.36, 460.0)
	for i in mini(fighters.size(), 2):
		var left := i == 0
		_draw_player(_bars, i, 24.0 if left else w - 24.0 - bar_w, 16.0, bar_w, left)
	_draw_timer(Vector2(w * 0.5, 50))


func _draw_seat(c: Control, i: int) -> void:
	if i >= fighters.size():
		return
	var bar_w := minf(c.size.x * 0.4, 500.0)
	_draw_player(c, i, (c.size.x - bar_w) * 0.5, c.size.y - 82.0, bar_w, true)


func _draw_player(c: Control, i: int, x: float, top: float, bar_w: float, left: bool) -> void:
	var f := fighters[i]
	var font := c.get_theme_default_font()
	# Health
	var hp_frac := clampf(f.hp / f.max_hp, 0.0, 1.0)
	c.draw_rect(Rect2(x - 3, top - 3, bar_w + 6, 30), Color(0, 0, 0, 0.7))
	c.draw_rect(Rect2(x, top, bar_w, 24), Color(0.35, 0.0, 0.0))
	var hp_w := bar_w * hp_frac
	var hp_col := Color(0.15, 0.75, 0.2).lerp(Color(0.9, 0.75, 0.1), 1.0 - hp_frac)
	c.draw_rect(Rect2(x if left else x + bar_w - hp_w, top, hp_w, 24), hp_col)
	# Stamina
	var st_full := bar_w * 0.7
	var st_w := st_full * clampf(f.stamina / 100.0, 0.0, 1.0)
	var st_x := x if left else x + bar_w - st_full
	c.draw_rect(Rect2(st_x, top + 30, st_full, 9), Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(st_x if left else st_x + st_full - st_w, top + 30, st_w, 9), Color(0.3, 0.6, 1.0))
	# Name and round pips
	var name_text := f.display_name.to_upper()
	var align := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	c.draw_string_outline(font, Vector2(x, top + 64), name_text, align, bar_w, 20, 6, Color.BLACK)
	c.draw_string(font, Vector2(x, top + 64), name_text, align, bar_w, 20, f.body_color.lightened(0.35))
	for r in rounds_to_win:
		var px := (x + bar_w - 14.0 - r * 26.0) if left else (x + 14.0 + r * 26.0)
		var won := r < round_wins[i]
		c.draw_circle(Vector2(px, top + 56), 9.0, Color(1.0, 0.8, 0.2) if won else Color(0, 0, 0, 0.6))


func _draw_timer(centre: Vector2) -> void:
	var font := _bars.get_theme_default_font()
	var secs := str(ceili(time_left_frames / 60.0))
	var pos := centre + Vector2(-60, -16)
	_bars.draw_string_outline(font, pos, secs, HORIZONTAL_ALIGNMENT_CENTER, 120, 40, 8, Color.BLACK)
	_bars.draw_string(font, pos, secs, HORIZONTAL_ALIGNMENT_CENTER, 120, 40, Color.WHITE)
