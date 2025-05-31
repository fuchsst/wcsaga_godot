@tool
class_name ValidationIndicator
extends Control

## Visual validation status indicator for GFRED2 mission editor components
## Shows real-time validation status with iconography and tooltips
## Part of mandatory scene-based UI architecture (EPIC-005)

signal validation_help_requested(help_topic: String)
signal validation_detail_requested(validation_result: ValidationResult)

## Visual state configuration
@export var indicator_size: Vector2 = Vector2(16, 16)
@export var show_tooltip: bool = true
@export var show_error_count: bool = false
@export var animation_enabled: bool = true

## UI nodes - configured in scene, accessed via onready
@onready var status_icon: TextureRect = $HBoxContainer/StatusIcon
@onready var error_label: Label = $HBoxContainer/ErrorLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

## Validation state
var current_validation_result: ValidationResult
var validation_status: ValidationStatus = ValidationStatus.UNKNOWN
var error_count: int = 0
var warning_count: int = 0

## Validation status enumeration
enum ValidationStatus {
	UNKNOWN,    # No validation performed yet
	VALIDATING, # Validation in progress
	VALID,      # Validation passed
	WARNING,    # Validation passed with warnings
	ERROR,      # Validation failed
	CACHED      # Using cached validation result
}

func _ready() -> void:
	name = "ValidationIndicator"
	
	# Ensure proper sizing
	custom_minimum_size = indicator_size
	
	# Connect input events for interaction
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Initialize visual state
	_update_visual_state()

func set_validation_result(result: ValidationResult) -> void:
	"""Update validation indicator with new validation result.
	Args:
		result: ValidationResult to display"""
	
	current_validation_result = result
	
	if not result:
		validation_status = ValidationStatus.UNKNOWN
		error_count = 0
		warning_count = 0
	else:
		# Determine status based on validation result
		if result.has_method("get_error_count"):
			error_count = result.get_error_count()
		else:
			error_count = 0
			
		if result.has_method("get_warning_count"):
			warning_count = result.get_warning_count()
		else:
			warning_count = 0
		
		if error_count > 0:
			validation_status = ValidationStatus.ERROR
		elif warning_count > 0:
			validation_status = ValidationStatus.WARNING
		elif result.has_method("is_valid") and result.is_valid():
			validation_status = ValidationStatus.VALID
		else:
			validation_status = ValidationStatus.UNKNOWN
	
	_update_visual_state()

func set_validation_status(status: ValidationStatus) -> void:
	"""Set validation status directly for temporary states.
	Args:
		status: ValidationStatus to display"""
	
	validation_status = status
	_update_visual_state()

func _update_visual_state() -> void:
	"""Update visual appearance based on current validation status."""
	
	if not status_icon:
		return
	
	# Configure icon and color based on status
	var icon_texture: Texture2D
	var modulate_color: Color = Color.WHITE
	var tooltip_text: String = ""
	
	match validation_status:
		ValidationStatus.UNKNOWN:
			icon_texture = _get_status_icon("unknown")
			modulate_color = Color.GRAY
			tooltip_text = "Validation status unknown"
			
		ValidationStatus.VALIDATING:
			icon_texture = _get_status_icon("validating")
			modulate_color = Color.YELLOW
			tooltip_text = "Validation in progress..."
			
		ValidationStatus.VALID:
			icon_texture = _get_status_icon("valid")
			modulate_color = Color.GREEN
			tooltip_text = "Validation passed"
			
		ValidationStatus.WARNING:
			icon_texture = _get_status_icon("warning")
			modulate_color = Color.ORANGE
			tooltip_text = "Validation passed with %d warning(s)" % warning_count
			
		ValidationStatus.ERROR:
			icon_texture = _get_status_icon("error")
			modulate_color = Color.RED
			tooltip_text = "Validation failed with %d error(s)" % error_count
			
		ValidationStatus.CACHED:
			icon_texture = _get_status_icon("cached")
			modulate_color = Color.LIGHT_BLUE
			tooltip_text = "Using cached validation result"
	
	# Apply visual changes
	status_icon.texture = icon_texture
	status_icon.modulate = modulate_color
	status_icon.size = indicator_size
	
	# Update error count label
	if error_label:
		if show_error_count and (error_count > 0 or warning_count > 0):
			var count_text: String = ""
			if error_count > 0:
				count_text += str(error_count)
			if warning_count > 0:
				if count_text.length() > 0:
					count_text += "/"
				count_text += str(warning_count)
			error_label.text = count_text
			error_label.visible = true
		else:
			error_label.visible = false
	
	# Set tooltip
	if show_tooltip:
		tooltip_text = _build_detailed_tooltip()
	
	set_tooltip_text(tooltip_text)
	
	# Play status animation if enabled
	if animation_enabled and animation_player:
		_play_status_animation()

func _get_status_icon(status_name: String) -> Texture2D:
	"""Get appropriate icon for validation status.
	Args:
		status_name: Name of status for icon lookup
	Returns:
		Texture2D for the status icon"""
	
	# Use Godot built-in editor icons for consistency
	var editor_theme: Theme = EditorInterface.get_editor_theme() if Engine.is_editor_hint() else null
	
	if editor_theme:
		match status_name:
			"unknown":
				return editor_theme.get_icon("Help", "EditorIcons")
			"validating":
				return editor_theme.get_icon("Progress1", "EditorIcons")
			"valid":
				return editor_theme.get_icon("StatusSuccess", "EditorIcons")
			"warning":
				return editor_theme.get_icon("StatusWarning", "EditorIcons")
			"error":
				return editor_theme.get_icon("StatusError", "EditorIcons")
			"cached":
				return editor_theme.get_icon("Reload", "EditorIcons")
	
	# Fallback to basic circle texture if editor icons unavailable
	return _create_fallback_icon(status_name)

func _create_fallback_icon(status_name: String) -> Texture2D:
	"""Create simple fallback icon for status.
	Args:
		status_name: Name of status for icon creation
	Returns:
		Simple texture for the status"""
	
	var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var color: Color
	
	match status_name:
		"unknown":
			color = Color.GRAY
		"validating":
			color = Color.YELLOW
		"valid":
			color = Color.GREEN
		"warning":
			color = Color.ORANGE
		"error":
			color = Color.RED
		"cached":
			color = Color.LIGHT_BLUE
		_:
			color = Color.WHITE
	
	image.fill(color)
	
	var texture: ImageTexture = ImageTexture.new()
	texture.create_from_image(image)
	return texture

func _build_detailed_tooltip() -> String:
	"""Build detailed tooltip with validation information.
	Returns:
		Formatted tooltip string"""
	
	var tooltip: String = ""
	
	match validation_status:
		ValidationStatus.UNKNOWN:
			tooltip = "Validation Status: Unknown\nClick for help"
			
		ValidationStatus.VALIDATING:
			tooltip = "Validation Status: In Progress\nPlease wait..."
			
		ValidationStatus.VALID:
			tooltip = "Validation Status: Passed\nNo issues found"
			
		ValidationStatus.WARNING:
			tooltip = "Validation Status: Warnings (%d)\n" % warning_count
			if current_validation_result and current_validation_result.has_method("get_warnings"):
				var warnings: Array[String] = current_validation_result.get_warnings()
				for i in range(min(3, warnings.size())):  # Show max 3 warnings in tooltip
					tooltip += "• %s\n" % warnings[i]
				if warnings.size() > 3:
					tooltip += "• ... and %d more\n" % (warnings.size() - 3)
			tooltip += "Click for details"
			
		ValidationStatus.ERROR:
			tooltip = "Validation Status: Errors (%d)\n" % error_count
			if current_validation_result and current_validation_result.has_method("get_errors"):
				var errors: Array[String] = current_validation_result.get_errors()
				for i in range(min(3, errors.size())):  # Show max 3 errors in tooltip
					tooltip += "• %s\n" % errors[i]
				if errors.size() > 3:
					tooltip += "• ... and %d more\n" % (errors.size() - 3)
			tooltip += "Click for details"
			
		ValidationStatus.CACHED:
			tooltip = "Validation Status: Cached Result\nClick to refresh"
	
	return tooltip

func _play_status_animation() -> void:
	"""Play appropriate animation for current status."""
	
	if not animation_player:
		return
	
	match validation_status:
		ValidationStatus.VALIDATING:
			if animation_player.has_animation("spin"):
				animation_player.play("spin")
		ValidationStatus.ERROR:
			if animation_player.has_animation("shake"):
				animation_player.play("shake")
		ValidationStatus.WARNING:
			if animation_player.has_animation("pulse"):
				animation_player.play("pulse")
		_:
			animation_player.stop()

func _on_gui_input(event: InputEvent) -> void:
	"""Handle user interaction with validation indicator.
	Args:
		event: Input event to process"""
	
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			match validation_status:
				ValidationStatus.UNKNOWN:
					validation_help_requested.emit("validation_system")
				ValidationStatus.WARNING, ValidationStatus.ERROR:
					if current_validation_result:
						validation_detail_requested.emit(current_validation_result)
				ValidationStatus.CACHED:
					# Request fresh validation
					validation_help_requested.emit("refresh_validation")

func _on_mouse_entered() -> void:
	"""Handle mouse enter for hover effects."""
	
	if status_icon:
		var tween: Tween = create_tween()
		tween.tween_property(status_icon, "scale", Vector2(1.1, 1.1), 0.1)

func _on_mouse_exited() -> void:
	"""Handle mouse exit for hover effects."""
	
	if status_icon:
		var tween: Tween = create_tween()
		tween.tween_property(status_icon, "scale", Vector2(1.0, 1.0), 0.1)

## Public API

func refresh_validation() -> void:
	"""Request fresh validation (clears cached status)."""
	
	if validation_status == ValidationStatus.CACHED:
		validation_status = ValidationStatus.UNKNOWN
		_update_visual_state()

func set_error_count_visible(visible: bool) -> void:
	"""Control visibility of error count label.
	Args:
		visible: Whether to show error count"""
	
	show_error_count = visible
	_update_visual_state()

func set_animation_enabled(enabled: bool) -> void:
	"""Control status change animations.
	Args:
		enabled: Whether to enable animations"""
	
	animation_enabled = enabled
	if not enabled and animation_player:
		animation_player.stop()

func get_validation_summary() -> Dictionary:
	"""Get summary of current validation state.
	Returns:
		Dictionary with validation summary"""
	
	return {
		"status": validation_status,
		"error_count": error_count,
		"warning_count": warning_count,
		"has_result": current_validation_result != null,
		"is_valid": validation_status in [ValidationStatus.VALID, ValidationStatus.WARNING]
	}