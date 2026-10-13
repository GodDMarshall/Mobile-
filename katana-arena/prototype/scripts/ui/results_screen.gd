class_name ResultsScreen
extends CanvasLayer
## End of match: winner, rounds, rematch or back to menu.

signal rematch
signal back_to_menu


func show_result(result: Dictionary) -> void:
	layer = 20
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)
	var title := Label.new()
	title.text = "DRAW" if int(result.winner) < 0 else "%s WINS THE DUEL" % str(result.winner_name).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	title.add_theme_color_override("font_outline_color", Color(0.3, 0, 0))
	title.add_theme_constant_override("outline_size", 14)
	col.add_child(title)
	var detail := Label.new()
	detail.text = "Rounds %d - %d" % [result.round_wins[0], result.round_wins[1]]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 26)
	col.add_child(detail)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	for pair in [["REMATCH", rematch], ["MENU", back_to_menu]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(240, 72)
		b.add_theme_font_size_override("font_size", 28)
		var sig: Signal = pair[1]
		b.pressed.connect(func(): sig.emit())
		row.add_child(b)
