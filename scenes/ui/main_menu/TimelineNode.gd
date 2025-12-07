extends Control

# TimelineNode.gd
# Represents a single event card on the timeline scroll
# Connectors are managed externally by TimelineController using ElbowConnector

signal clicked(year: int, data: Resource)

var year: int
var data: Resource # TimelineEventResource
var _is_right_aligned: bool = true
var _is_hovered: bool = false
var _is_selected: bool = false

# Layout constants
const CONTENT_WIDTH: float = 260.0
const CONTENT_MAX_HEIGHT: float = 100.0
const GAP_FROM_CENTER: float = 60.0

@onready var title_label: Label = $CenterAxis/ContentRoot/CardPanel/MarginContainer/ContentVBox/TitleLabel
@onready var desc_label: Label = $CenterAxis/ContentRoot/CardPanel/MarginContainer/ContentVBox/DescLabel
@onready var content_root: Control = $CenterAxis/ContentRoot
@onready var hologram_panel: Panel = $CenterAxis/ContentRoot/CardPanel/HologramPanel
@onready var glow_layer1: ColorRect = $CenterAxis/ContentRoot/CardPanel/GlowLayer1
@onready var glow_layer2: ColorRect = $CenterAxis/ContentRoot/CardPanel/GlowLayer2
@onready var glow_layer3: ColorRect = $CenterAxis/ContentRoot/CardPanel/GlowLayer3
@onready var card_panel: PanelContainer = $CenterAxis/ContentRoot/CardPanel
@onready var center_axis: Control = $CenterAxis


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(year, data)
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		clicked.emit(year, data)


func _ready() -> void:
	# Duplicate material to allow unique highlighting per node
	if hologram_panel and hologram_panel.material:
		hologram_panel.material = hologram_panel.material.duplicate()

	# Listen for content size changes and enable clipping
	if card_panel:
		card_panel.minimum_size_changed.connect(_update_layout)
		card_panel.clip_contents = true
		# Connect card panel clicks
		card_panel.gui_input.connect(_on_card_panel_input)

	update_ui()

	# Connect mouse signals
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

	# Pivot for animations
	pivot_offset = size / 2.0

	# Defer layout update


func _on_card_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(year, data)


func setup(p_year: int, p_data: Resource, _show_year: bool = true) -> void:
	year = p_year
	data = p_data
	update_ui()
	call_deferred("_update_layout")


func set_alignment(is_right: bool) -> void:
	_is_right_aligned = is_right
	_update_layout()


func is_right_aligned() -> bool:
	return _is_right_aligned


func get_card_edge_global_position() -> Vector2:
	## Returns the global position of the card top edge where a connector should attach
	if not card_panel or not is_inside_tree():
		return global_position

	# Return top center of card for vertical connector
	var card_center_x = card_panel.global_position.x + card_panel.size.x / 2.0
	var card_top_y = card_panel.global_position.y
	return Vector2(card_center_x, card_top_y)


func _update_layout() -> void:
	if not is_inside_tree() or not card_panel:
		return

	# Get actual content size with constraints
	var content_min_size = card_panel.get_combined_minimum_size()
	var content_height = min(content_min_size.y, CONTENT_MAX_HEIGHT)
	var content_width = min(content_min_size.x, CONTENT_WIDTH)

	# Set ContentRoot size with max constraints
	content_root.custom_minimum_size = Vector2(content_width, content_height)
	content_root.size = Vector2(content_width, content_height)

	# Update TimelineNode height
	var required_height = max(80.0, content_height + 30.0)
	custom_minimum_size.y = required_height

	# Center content vertically relative to node center
	var center_y = required_height / 2.0
	content_root.position.y = center_y - (content_height / 2.0)

	# Position content on left or right side
	if _is_right_aligned:
		content_root.position.x = GAP_FROM_CENTER
	else:
		content_root.position.x = - GAP_FROM_CENTER - content_width


func apply_scroll_effect(scroll_scale: float, scroll_alpha: float) -> void:
	if not _is_hovered and not _is_selected:
		# Use lerp for smooth transitions during scrolling
		var target_scale = Vector2(scroll_scale, scroll_scale)
		var target_alpha = scroll_alpha
		scale = scale.lerp(target_scale, 0.15)
		modulate.a = lerpf(modulate.a, target_alpha, 0.15)


func set_selected(selected: bool) -> void:
	if _is_selected == selected:
		return
	_is_selected = selected

	if selected:
		_apply_highlight_effect()
	elif not _is_hovered:
		_apply_normal_effect()


func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_highlight_effect()


func _on_mouse_exited() -> void:
	_is_hovered = false
	if not _is_selected:
		_apply_normal_effect()


func _apply_highlight_effect() -> void:
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	# Subtle node scale
	tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.25)
	modulate.a = 1.0

	# Title glow - bright cyan with outline for glow effect
	if title_label:
		# Ensure outline color exists before tweening (fixes Nil error)
		if not title_label.has_theme_color_override("font_outline_color"):
			title_label.add_theme_color_override("font_outline_color", Color(0.4, 0.8, 1.0, 0.0))
		title_label.add_theme_constant_override("outline_size", 3)

		tween.tween_property(title_label, "theme_override_colors/font_color",
			Color(0.9, 1.0, 1.2), 0.25)
		tween.tween_property(title_label, "theme_override_colors/font_outline_color",
			Color(0.4, 0.8, 1.0, 0.9), 0.25)

	# Multi-layer glow for smooth blur effect around the box
	# Inner layer: brightest, smallest
	if glow_layer1:
		tween.tween_property(glow_layer1, "modulate", Color(0.3, 0.6, 1.0, 0.5), 0.2)
	# Middle layer: medium brightness
	if glow_layer2:
		tween.tween_property(glow_layer2, "modulate", Color(0.3, 0.6, 1.0, 0.3), 0.25)
	# Outer layer: softest, largest
	if glow_layer3:
		tween.tween_property(glow_layer3, "modulate", Color(0.3, 0.6, 1.0, 0.15), 0.3)


func _apply_normal_effect() -> void:
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Reset scale
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

	# Reset title to normal
	if title_label:
		tween.tween_property(title_label, "theme_override_colors/font_color",
			Color(0.6, 0.8, 1, 1), 0.35)
		tween.tween_property(title_label, "theme_override_colors/font_outline_color",
			Color(0.4, 0.8, 1.0, 0.0), 0.35)

	# Hide all glow layers
	if glow_layer1:
		tween.tween_property(glow_layer1, "modulate", Color(0.3, 0.6, 1.0, 0.0), 0.3)
	if glow_layer2:
		tween.tween_property(glow_layer2, "modulate", Color(0.3, 0.6, 1.0, 0.0), 0.35)
	if glow_layer3:
		tween.tween_property(glow_layer3, "modulate", Color(0.3, 0.6, 1.0, 0.0), 0.4)


func update_ui() -> void:
	if not data:
		return

	if data.get("locked"):
		if title_label:
			var title_text = data.get("title") if data.get("title") else "Unknown"
			title_label.text = "[ENCRYPTED] " + title_text
			title_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
		if desc_label:
			desc_label.text = "Access Restricted. Decryption algorithms pending."
			desc_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2, 0.7))
		modulate = Color(0.8, 0.8, 0.8, 0.5)
	else:
		if title_label:
			var title_text = data.get("title") if data.get("title") else "Unknown"
			title_label.text = title_text
			title_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1, 1))
		if desc_label:
			var text_to_show = ""
			if data.get("short_description"):
				text_to_show = data.get("short_description")
			elif data.get("long_description"):
				text_to_show = data.get("long_description")
			else:
				text_to_show = "No description available."

			desc_label.text = text_to_show
			desc_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1, 0.7))
		modulate = Color.WHITE
