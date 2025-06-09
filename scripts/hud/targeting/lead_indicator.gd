class_name LeadIndicator
extends Control

## HUD-006: Lead Indicator Display Component
## Provides visual lead marker positioning and dynamic adjustment for predictive targeting
## with confidence-based visibility and smooth interpolation

signal lead_visibility_changed(visible: bool)
signal lead_accuracy_updated(accuracy: float)
signal lead_position_updated(position: Vector2)

# Visual components
var lead_marker: Control
var confidence_ring: Control
var trajectory_line: Line2D
var prediction_trail: Array[Vector2] = []

# Lead display state
var current_lead_position: Vector2 = Vector2.ZERO
var previous_lead_position: Vector2 = Vector2.ZERO
var lead_confidence: float = 0.0
var lead_visible: bool = false

# Visual configuration
var marker_size: float = 16.0
var marker_color: Color = Color.CYAN
var confidence_color: Color = Color.WHITE
var trajectory_color: Color = Color.YELLOW
var trail_color: Color = Color.ORANGE

# Animation settings
var smooth_movement: bool = true
var interpolation_speed: float = 15.0
var fade_in_duration: float = 0.3
var fade_out_duration: float = 0.2
var confidence_pulse_rate: float = 2.0

# Confidence thresholds
var min_confidence_visible: float = 0.3
var high_confidence_threshold: float = 0.8
var perfect_confidence_threshold: float = 0.95

# Performance settings
var trail_length: int = 10
var update_frequency: float = 60.0
var interpolation_enabled: bool = true

# Trail management
var trail_update_timer: float = 0.0
var trail_update_interval: float = 0.05  # 20 Hz trail updates

func _ready() -> void:
	set_process(true)
	_initialize_lead_indicator()
	print("LeadIndicator: Lead indicator initialized")

func _initialize_lead_indicator() -> void:
	# Set up full-screen canvas for lead display
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create main lead marker
	lead_marker = _create_lead_marker()
	add_child(lead_marker)
	
	# Create confidence ring
	confidence_ring = _create_confidence_ring()
	add_child(confidence_ring)
	
	# Create trajectory line
	trajectory_line = Line2D.new()
	trajectory_line.width = 2.0
	trajectory_line.default_color = trajectory_color
	trajectory_line.z_index = 1
	add_child(trajectory_line)
	
	# Initially hidden
	_hide_lead_indicator()

func _create_lead_marker() -> Control:
	var marker = Control.new()
	marker.size = Vector2(marker_size, marker_size)
	
	# Create visual marker as TextureRect or ColorRect
	var visual = ColorRect.new()
	visual.color = marker_color
	visual.size = Vector2(marker_size, marker_size)
	visual.position = Vector2(-marker_size/2, -marker_size/2)
	
	# Create crosshair pattern
	var h_line = ColorRect.new()
	h_line.color = marker_color
	h_line.size = Vector2(marker_size, 2.0)
	h_line.position = Vector2(-marker_size/2, -1.0)
	
	var v_line = ColorRect.new()
	v_line.color = marker_color
	v_line.size = Vector2(2.0, marker_size)
	v_line.position = Vector2(-1.0, -marker_size/2)
	
	marker.add_child(visual)
	marker.add_child(h_line)
	marker.add_child(v_line)
	
	# Create center dot
	var center_dot = ColorRect.new()
	center_dot.color = marker_color
	center_dot.size = Vector2(4.0, 4.0)
	center_dot.position = Vector2(-2.0, -2.0)
	marker.add_child(center_dot)
	
	return marker

func _create_confidence_ring() -> Control:
	var ring = Control.new()
	ring.size = Vector2(marker_size * 2, marker_size * 2)
	
	# Create confidence indicator ring
	var ring_visual = ColorRect.new()
	ring_visual.color = Color.TRANSPARENT
	ring_visual.size = Vector2(marker_size * 2, marker_size * 2)
	ring_visual.position = Vector2(-marker_size, -marker_size)
	
	# Add border for confidence ring
	var border_thickness = 2.0
	var border_color = confidence_color
	
	# Create ring border (simplified as four rectangles)
	var ring_size = marker_size * 2
	
	# Top border
	var top_border = ColorRect.new()
	top_border.color = border_color
	top_border.size = Vector2(ring_size, border_thickness)
	top_border.position = Vector2(-ring_size/2, -ring_size/2)
	ring.add_child(top_border)
	
	# Bottom border
	var bottom_border = ColorRect.new()
	bottom_border.color = border_color
	bottom_border.size = Vector2(ring_size, border_thickness)
	bottom_border.position = Vector2(-ring_size/2, ring_size/2 - border_thickness)
	ring.add_child(bottom_border)
	
	# Left border
	var left_border = ColorRect.new()
	left_border.color = border_color
	left_border.size = Vector2(border_thickness, ring_size)
	left_border.position = Vector2(-ring_size/2, -ring_size/2)
	ring.add_child(left_border)
	
	# Right border
	var right_border = ColorRect.new()
	right_border.color = border_color
	right_border.size = Vector2(border_thickness, ring_size)
	right_border.position = Vector2(ring_size/2 - border_thickness, -ring_size/2)
	ring.add_child(right_border)
	
	return ring

## Update lead indicator position and visibility
func update_lead_indicator(lead_position: Vector2, confidence: float) -> void:
	previous_lead_position = current_lead_position
	current_lead_position = lead_position
	lead_confidence = confidence
	
	# Update visibility based on confidence
	var should_be_visible = confidence >= min_confidence_visible and lead_position != Vector2.ZERO
	
	if should_be_visible != lead_visible:
		if should_be_visible:
			_show_lead_indicator()
		else:
			_hide_lead_indicator()
	
	if lead_visible:
		_update_lead_position()
		_update_confidence_display()
		_update_trajectory_line()
		_update_prediction_trail()
	
	lead_accuracy_updated.emit(confidence)
	lead_position_updated.emit(lead_position)

func _update_lead_position() -> void:
	if not lead_marker:
		return
	
	var target_position = current_lead_position
	
	# Apply smooth interpolation if enabled
	if smooth_movement and interpolation_enabled:
		if previous_lead_position != Vector2.ZERO:
			var current_marker_pos = lead_marker.position + Vector2(marker_size/2, marker_size/2)
			target_position = current_marker_pos.lerp(current_lead_position, interpolation_speed * get_process_delta_time())
	
	# Position marker
	lead_marker.position = target_position - Vector2(marker_size/2, marker_size/2)
	
	# Position confidence ring
	if confidence_ring:
		confidence_ring.position = target_position - Vector2(marker_size, marker_size)

func _update_confidence_display() -> void:
	if not confidence_ring:
		return
	
	# Update confidence ring opacity and color
	var confidence_alpha = clamp(lead_confidence, 0.2, 1.0)
	var ring_color = confidence_color
	
	# Color coding based on confidence
	if lead_confidence >= perfect_confidence_threshold:
		ring_color = Color.GREEN
	elif lead_confidence >= high_confidence_threshold:
		ring_color = Color.YELLOW
	else:
		ring_color = Color.RED
	
	ring_color.a = confidence_alpha
	
	# Apply color to all ring border elements
	for child in confidence_ring.get_children():
		if child is ColorRect:
			child.color = ring_color
	
	# Apply pulsing effect for high confidence
	if lead_confidence >= high_confidence_threshold:
		_apply_confidence_pulse()

func _apply_confidence_pulse() -> void:
	if not confidence_ring:
		return
	
	# Create subtle pulsing animation
	var tween = create_tween()
	tween.set_loops()
	
	var pulse_scale = 1.0 + (lead_confidence - high_confidence_threshold) * 0.5
	tween.tween_property(confidence_ring, "scale", Vector2(pulse_scale, pulse_scale), 0.5)
	tween.tween_property(confidence_ring, "scale", Vector2(1.0, 1.0), 0.5)

func _update_trajectory_line() -> void:
	if not trajectory_line:
		return
	
	# Clear existing trajectory
	trajectory_line.clear_points()
	
	# Draw line from player/weapon position to lead point
	var player_pos = _get_player_screen_position()
	if player_pos != Vector2.ZERO and current_lead_position != Vector2.ZERO:
		trajectory_line.add_point(player_pos)
		trajectory_line.add_point(current_lead_position)
		
		# Set trajectory visibility based on confidence
		var trajectory_alpha = clamp(lead_confidence * 0.6, 0.1, 0.6)
		trajectory_line.default_color = Color(trajectory_color.r, trajectory_color.g, trajectory_color.b, trajectory_alpha)

func _get_player_screen_position() -> Vector2:
	# Get player position projected to screen
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return Vector2.ZERO
	
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return Vector2.ZERO
	
	var player_3d_pos = Vector3.ZERO
	if player.has_method("get_global_position"):
		player_3d_pos = player.get_global_position()
	elif player.has_method("get_position"):
		player_3d_pos = player.get_position()
	
	if player_3d_pos == Vector3.ZERO:
		return Vector2.ZERO
	
	# Project to screen coordinates
	return camera.unproject_position(player_3d_pos)

func _update_prediction_trail() -> void:
	trail_update_timer += get_process_delta_time()
	
	if trail_update_timer >= trail_update_interval:
		# Add current position to trail
		if current_lead_position != Vector2.ZERO:
			prediction_trail.append(current_lead_position)
		
		# Limit trail length
		while prediction_trail.size() > trail_length:
			prediction_trail.pop_front()
		
		trail_update_timer = 0.0

func _draw() -> void:
	if not lead_visible or prediction_trail.size() < 2:
		return
	
	# Draw prediction trail
	for i in range(prediction_trail.size() - 1):
		var start_pos = prediction_trail[i]
		var end_pos = prediction_trail[i + 1]
		
		# Trail fade effect
		var trail_alpha = float(i + 1) / float(prediction_trail.size())
		var trail_point_color = Color(trail_color.r, trail_color.g, trail_color.b, trail_alpha * 0.5)
		
		draw_line(start_pos, end_pos, trail_point_color, 1.0)

## Show lead indicator with fade-in animation
func _show_lead_indicator() -> void:
	lead_visible = true
	
	if lead_marker:
		lead_marker.visible = true
		lead_marker.modulate.a = 0.0
		
		var tween = create_tween()
		tween.tween_property(lead_marker, "modulate:a", 1.0, fade_in_duration)
	
	if confidence_ring:
		confidence_ring.visible = true
		confidence_ring.modulate.a = 0.0
		
		var tween = create_tween()
		tween.tween_property(confidence_ring, "modulate:a", 1.0, fade_in_duration)
	
	if trajectory_line:
		trajectory_line.visible = true
	
	lead_visibility_changed.emit(true)
	queue_redraw()  # Trigger trail redraw

## Hide lead indicator with fade-out animation
func _hide_lead_indicator() -> void:
	lead_visible = false
	
	if lead_marker:
		var tween = create_tween()
		tween.tween_property(lead_marker, "modulate:a", 0.0, fade_out_duration)
		tween.tween_callback(func(): lead_marker.visible = false)
	
	if confidence_ring:
		var tween = create_tween()
		tween.tween_property(confidence_ring, "modulate:a", 0.0, fade_out_duration)
		tween.tween_callback(func(): confidence_ring.visible = false)
	
	if trajectory_line:
		trajectory_line.visible = false
		trajectory_line.clear_points()
	
	# Clear trail
	prediction_trail.clear()
	
	lead_visibility_changed.emit(false)
	queue_redraw()

## Set lead indicator visibility directly
func set_lead_visible(visible: bool) -> void:
	if visible:
		_show_lead_indicator()
	else:
		_hide_lead_indicator()

## Configure lead indicator appearance
func configure_lead_indicator(config: Dictionary) -> void:
	# Update marker settings
	if config.has("marker_size"):
		marker_size = config["marker_size"]
		_resize_marker()
	
	if config.has("marker_color"):
		marker_color = config["marker_color"]
		_update_marker_color()
	
	if config.has("confidence_color"):
		confidence_color = config["confidence_color"]
	
	if config.has("trajectory_color"):
		trajectory_color = config["trajectory_color"]
	
	if config.has("trail_color"):
		trail_color = config["trail_color"]
	
	# Update animation settings
	if config.has("smooth_movement"):
		smooth_movement = config["smooth_movement"]
	
	if config.has("interpolation_speed"):
		interpolation_speed = config["interpolation_speed"]
	
	if config.has("fade_in_duration"):
		fade_in_duration = config["fade_in_duration"]
	
	if config.has("fade_out_duration"):
		fade_out_duration = config["fade_out_duration"]
	
	# Update trail settings
	if config.has("trail_length"):
		trail_length = config["trail_length"]
	
	if config.has("trail_update_interval"):
		trail_update_interval = config["trail_update_interval"]
	
	print("LeadIndicator: Configuration updated")

func _resize_marker() -> void:
	if lead_marker:
		lead_marker.size = Vector2(marker_size, marker_size)
		# Update child element sizes and positions
		for child in lead_marker.get_children():
			if child is ColorRect:
				# Resize based on marker type
				pass  # Would implement specific resizing logic

func _update_marker_color() -> void:
	if lead_marker:
		for child in lead_marker.get_children():
			if child is ColorRect:
				child.color = marker_color

## Set confidence thresholds
func set_confidence_thresholds(min_visible: float, high_confidence: float, perfect_confidence: float) -> void:
	min_confidence_visible = clamp(min_visible, 0.0, 1.0)
	high_confidence_threshold = clamp(high_confidence, 0.0, 1.0)
	perfect_confidence_threshold = clamp(perfect_confidence, 0.0, 1.0)

## Enable/disable interpolation
func set_interpolation_enabled(enabled: bool) -> void:
	interpolation_enabled = enabled

## Get lead indicator status
func get_lead_indicator_status() -> Dictionary:
	return {
		"visible": lead_visible,
		"position": current_lead_position,
		"confidence": lead_confidence,
		"trail_length": prediction_trail.size(),
		"marker_size": marker_size,
		"interpolation_enabled": interpolation_enabled,
		"smooth_movement": smooth_movement
	}

## Update display based on weapon type
func update_for_weapon_type(weapon_type: String) -> void:
	match weapon_type:
		"missile":
			# Larger, more prominent marker for missiles
			marker_size = 20.0
			marker_color = Color.RED
			trajectory_color = Color.ORANGE
		
		"energy":
			# Standard marker for energy weapons
			marker_size = 16.0
			marker_color = Color.CYAN
			trajectory_color = Color.BLUE
		
		"ballistic":
			# Slightly different marker for ballistic weapons
			marker_size = 18.0
			marker_color = Color.YELLOW
			trajectory_color = Color.ORANGE
		
		"beam":
			# Continuous beam indicator
			marker_size = 14.0
			marker_color = Color.MAGENTA
			trajectory_color = Color.PURPLE
	
	_update_marker_color()
	_resize_marker()

func _process(delta: float) -> void:
	# Handle continuous updates
	if lead_visible:
		# Update smooth interpolation
		if smooth_movement and interpolation_enabled:
			_update_lead_position()
		
		# Queue redraw for trail updates
		queue_redraw()
