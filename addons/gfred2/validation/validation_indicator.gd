@tool
class_name ValidationIndicator
extends Control

## Visual validation indicator for GFRED2 mission editor
## Provides real-time visual feedback for validation status with accessibility support
## Integrates with MissionValidationController for status updates

signal indicator_clicked(validation_result: ValidationResult)

## Visual state configuration
enum IndicatorState {
	UNKNOWN,    # Gray - no validation performed
	VALID,      # Green - validation passed
	WARNING,    # Yellow - validation has warnings
	ERROR,      # Red - validation has errors
	VALIDATING  # Blue - validation in progress
}

## Indicator styling
@export var indicator_size: Vector2 = Vector2(16, 16)
@export var show_text_label: bool = false
@export var show_tooltip: bool = true
@export var animate_transitions: bool = true

## Accessibility configuration
@export var high_contrast_mode: bool = false
@export var screen_reader_enabled: bool = true

## State management
var current_state: IndicatorState = IndicatorState.UNKNOWN
var validation_result: ValidationResult
var animation_tween: Tween

## Visual elements
var status_icon: TextureRect
var status_label: Label
var background_panel: Panel

## Colors for different states (accessible)
var state_colors: Dictionary = {
	IndicatorState.UNKNOWN: Color(0.6, 0.6, 0.6, 1.0),      # Gray
	IndicatorState.VALID: Color(0.2, 0.8, 0.2, 1.0),        # Green  
	IndicatorState.WARNING: Color(1.0, 0.8, 0.0, 1.0),      # Yellow
	IndicatorState.ERROR: Color(0.9, 0.2, 0.2, 1.0),        # Red
	IndicatorState.VALIDATING: Color(0.2, 0.5, 1.0, 1.0)    # Blue
}

## High contrast colors (WCAG 2.1 AA compliant)
var high_contrast_colors: Dictionary = {
	IndicatorState.UNKNOWN: Color(0.4, 0.4, 0.4, 1.0),      # Dark Gray
	IndicatorState.VALID: Color(0.0, 0.6, 0.0, 1.0),        # Dark Green
	IndicatorState.WARNING: Color(0.8, 0.6, 0.0, 1.0),      # Dark Yellow  
	IndicatorState.ERROR: Color(0.8, 0.0, 0.0, 1.0),        # Dark Red
	IndicatorState.VALIDATING: Color(0.0, 0.3, 0.8, 1.0)    # Dark Blue
}

## State icons (Unicode symbols for universal support)
var state_icons: Dictionary = {
	IndicatorState.UNKNOWN: "?",
	IndicatorState.VALID: "✓",
	IndicatorState.WARNING: "⚠",
	IndicatorState.ERROR: "✕",
	IndicatorState.VALIDATING: "⟳"
}

## Screen reader text
var state_descriptions: Dictionary = {
	IndicatorState.UNKNOWN: "Validation status unknown",
	IndicatorState.VALID: "Validation passed",
	IndicatorState.WARNING: "Validation passed with warnings",
	IndicatorState.ERROR: "Validation failed with errors",
	IndicatorState.VALIDATING: "Validation in progress"
}

func _init() -> void:
	custom_minimum_size = indicator_size
	size = indicator_size
	
	# Enable accessibility
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	_setup_visual_elements()
	_setup_accessibility()
	_update_visual_state()

func _setup_visual_elements() -> void:
	"""Initialize visual elements for the indicator."""
	
	# Background panel
	background_panel = Panel.new()
	background_panel.anchors_preset = Control.PRESET_FULL_RECT
	background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_panel)
	
	# Status icon
	status_icon = TextureRect.new()
	status_icon.anchors_preset = Control.PRESET_CENTER
	status_icon.size = indicator_size * 0.8
	status_icon.position = (indicator_size - status_icon.size) * 0.5
	status_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(status_icon)
	
	# Status label (if enabled)
	if show_text_label:
		status_label = Label.new()
		status_label.anchors_preset = Control.PRESET_FULL_RECT
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 8)
		add_child(status_label)
	
	# Animation tween
	if animate_transitions:
		animation_tween = Tween.new()
		add_child(animation_tween)
	
	# Connect mouse input
	gui_input.connect(_on_gui_input)

func _setup_accessibility() -> void:
	"""Configure accessibility features."""
	
	# Screen reader support
	if screen_reader_enabled:
		# Set accessible role and description
		set("accessibility_role", 1)  # ROLE_BUTTON
		set("accessibility_description", state_descriptions[current_state])
	
	# Keyboard navigation
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

func _on_gui_input(event: InputEvent) -> void:
	"""Handle mouse input for indicator interaction."""
	
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_on_indicator_activated()
	
	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
			_on_indicator_activated()

func _on_focus_entered() -> void:
	"""Handle focus gained for accessibility."""
	
	if background_panel:
		# Add focus outline
		var style_box: StyleBoxFlat = StyleBoxFlat.new()
		style_box.bg_color = Color.TRANSPARENT
		style_box.border_width_left = 2
		style_box.border_width_right = 2  
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.border_color = Color.WHITE
		background_panel.add_theme_stylebox_override("panel", style_box)

func _on_focus_exited() -> void:
	"""Handle focus lost for accessibility."""
	
	if background_panel:
		# Remove focus outline
		background_panel.remove_theme_stylebox_override("panel")

func _on_indicator_activated() -> void:
	"""Handle indicator activation (click or keyboard)."""
	
	indicator_clicked.emit(validation_result)
	
	# Visual feedback
	if animate_transitions and animation_tween:
		animation_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
		animation_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func set_validation_state(state: IndicatorState, result: ValidationResult = null) -> void:
	"""Update validation state and visual appearance.
	Args:
		state: New validation state
		result: Validation result (optional)"""
	
	if current_state == state and validation_result == result:
		return
	
	current_state = state
	validation_result = result
	
	_update_visual_state()
	_update_accessibility()

func _update_visual_state() -> void:
	"""Update visual appearance based on current state."""
	
	if not is_inside_tree():
		return
	
	var colors: Dictionary = high_contrast_colors if high_contrast_mode else state_colors
	var state_color: Color = colors[current_state]
	
	# Update background color
	if background_panel:
		var style_box: StyleBoxFlat = StyleBoxFlat.new()
		style_box.bg_color = state_color
		style_box.corner_radius_top_left = 2
		style_box.corner_radius_top_right = 2
		style_box.corner_radius_bottom_left = 2
		style_box.corner_radius_bottom_right = 2
		background_panel.add_theme_stylebox_override("panel", style_box)
	
	# Update icon
	if status_icon:
		# Create text texture for icon
		var icon_text: String = state_icons[current_state]
		_set_icon_text(icon_text, state_color)
	
	# Update label
	if status_label:
		status_label.text = state_icons[current_state]
		status_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Animate transition
	if animate_transitions and animation_tween:
		animation_tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func _set_icon_text(text: String, color: Color) -> void:
	"""Set icon using text rendering.
	Args:
		text: Text to display as icon
		color: Text color"""
	
	# Create a temporary label to render text as texture
	var temp_label: Label = Label.new()
	temp_label.text = text
	temp_label.add_theme_font_size_override("font_size", int(indicator_size.x * 0.8))
	temp_label.add_theme_color_override("font_color", Color.WHITE)
	temp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	temp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	temp_label.size = indicator_size
	
	# Create texture from label
	if has_method("get_viewport"):
		add_child(temp_label)
		await get_tree().process_frame
		
		var viewport: SubViewport = SubViewport.new()
		viewport.size = indicator_size
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(viewport)
		
		temp_label.reparent(viewport)
		
		await get_tree().process_frame
		var texture: ImageTexture = viewport.get_texture()
		
		if status_icon and texture:
			status_icon.texture = texture
		
		viewport.queue_free()
		temp_label.queue_free()

func _update_accessibility() -> void:
	"""Update accessibility information."""
	
	if screen_reader_enabled:
		var description: String = state_descriptions[current_state]
		
		if validation_result:
			var error_count: int = validation_result.get_error_count()
			var warning_count: int = validation_result.get_warning_count()
			
			if error_count > 0:
				description += " with %d errors" % error_count
			if warning_count > 0:
				description += " and %d warnings" % warning_count
		
		set("accessibility_description", description)
	
	# Update tooltip
	if show_tooltip:
		tooltip_text = _generate_tooltip_text()

func _generate_tooltip_text() -> String:
	"""Generate tooltip text based on validation result.
	Returns:
		Formatted tooltip text"""
	
	var tooltip: String = state_descriptions[current_state]
	
	if validation_result:
		var errors: Array[String] = validation_result.get_errors()
		var warnings: Array[String] = validation_result.get_warnings()
		
		if not errors.is_empty():
			tooltip += "\n\nErrors:"
			for i in range(min(errors.size(), 3)):  # Show max 3 errors
				tooltip += "\n• " + errors[i]
			if errors.size() > 3:
				tooltip += "\n• ... and %d more" % (errors.size() - 3)
		
		if not warnings.is_empty():
			tooltip += "\n\nWarnings:"
			for i in range(min(warnings.size(), 3)):  # Show max 3 warnings
				tooltip += "\n• " + warnings[i]
			if warnings.size() > 3:
				tooltip += "\n• ... and %d more" % (warnings.size() - 3)
	
	return tooltip

## Public API

func set_unknown() -> void:
	"""Set indicator to unknown state."""
	set_validation_state(IndicatorState.UNKNOWN)

func set_valid(result: ValidationResult = null) -> void:
	"""Set indicator to valid state."""
	set_validation_state(IndicatorState.VALID, result)

func set_warning(result: ValidationResult) -> void:
	"""Set indicator to warning state."""
	set_validation_state(IndicatorState.WARNING, result)

func set_error(result: ValidationResult) -> void:
	"""Set indicator to error state."""
	set_validation_state(IndicatorState.ERROR, result)

func set_validating() -> void:
	"""Set indicator to validating state."""
	set_validation_state(IndicatorState.VALIDATING)

func update_from_validation_result(result: ValidationResult) -> void:
	"""Update indicator based on validation result.
	Args:
		result: Validation result to analyze"""
	
	if not result:
		set_unknown()
		return
	
	if not result.is_valid():
		set_error(result)
	elif result.has_warnings():
		set_warning(result)
	else:
		set_valid(result)

func set_high_contrast_mode(enabled: bool) -> void:
	"""Enable or disable high contrast mode for accessibility.
	Args:
		enabled: Whether to use high contrast colors"""
	
	high_contrast_mode = enabled
	_update_visual_state()

func set_screen_reader_support(enabled: bool) -> void:
	"""Enable or disable screen reader support.
	Args:
		enabled: Whether to provide screen reader information"""
	
	screen_reader_enabled = enabled
	_update_accessibility()

func get_current_state() -> IndicatorState:
	"""Get current validation state.
	Returns:
		Current indicator state"""
	
	return current_state

func get_validation_result() -> ValidationResult:
	"""Get associated validation result.
	Returns:
		Current validation result or null"""
	
	return validation_result