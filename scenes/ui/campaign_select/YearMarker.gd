extends Control

# YearMarker.gd
# Displays a year label on the central timeline axis
# Managed by TimelineController, positioned independently from TimelineNodes

var year: int = 0
var _is_highlighted: bool = false

@onready var label: Label = $CenterContainer/Panel/Label
@onready var panel: PanelContainer = $CenterContainer/Panel


func setup(p_year: int) -> void:
	year = p_year
	# Defer label update until node is in tree (for @onready vars)
	if is_inside_tree() and label:
		label.text = str(year)
	else:
		call_deferred("_update_label")


func _update_label() -> void:
	if label:
		label.text = str(year)


func get_center_position() -> Vector2:
	## Returns the global center position of this marker for connector attachment
	if panel and panel.is_inside_tree():
		return panel.global_position + panel.size / 2.0
	return global_position + size / 2.0


func get_right_edge() -> Vector2:
	## Returns the right edge center for right-side connector attachment
	if panel and panel.is_inside_tree():
		return panel.global_position + Vector2(panel.size.x, panel.size.y / 2.0)
	return global_position + Vector2(size.x / 2 + 40, size.y / 2.0)


func get_left_edge() -> Vector2:
	## Returns the left edge center for left-side connector attachment
	if panel and panel.is_inside_tree():
		return panel.global_position + Vector2(0, panel.size.y / 2.0)
	return global_position + Vector2(size.x / 2 - 40, size.y / 2.0)


func get_bottom_edge() -> Vector2:
	## Returns the bottom center for vertical connector attachment
	if panel and panel.is_inside_tree():
		return panel.global_position + Vector2(panel.size.x / 2.0, panel.size.y)
	return global_position + Vector2(size.x / 2.0, size.y)


func set_highlighted(highlighted: bool) -> void:
	if _is_highlighted == highlighted:
		return
	_is_highlighted = highlighted

	if not panel:
		return

	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	if highlighted:
		# Edge glow - animate the border
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.1, 0.2, 0.7)
		style.border_color = Color(0.5, 0.9, 1.2, 1.0) # Bright cyan border
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)

		# Year text glow with outline
		if label:
			# Ensure overrides exist before tweening (fixes Nil error)
			if not label.has_theme_color_override("font_color"):
				label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
			if not label.has_theme_color_override("font_outline_color"):
				label.add_theme_color_override("font_outline_color", Color(0.4, 0.8, 1.0, 0.0))
			label.add_theme_constant_override("outline_size", 3)

			tween.tween_property(label, "theme_override_colors/font_color",
				Color(0.9, 1.0, 1.2), 0.25)
			tween.tween_property(label, "theme_override_colors/font_outline_color",
				Color(0.4, 0.8, 1.0, 0.9), 0.25)
	else:
		# Reset to theme default
		panel.remove_theme_stylebox_override("panel")

		# Reset year text
		if label:
			tween.tween_property(label, "theme_override_colors/font_color",
				Color(0.6, 0.8, 1.0, 1.0), 0.35)
			tween.tween_property(label, "theme_override_colors/font_outline_color",
				Color(0.4, 0.8, 1.0, 0.0), 0.35)
