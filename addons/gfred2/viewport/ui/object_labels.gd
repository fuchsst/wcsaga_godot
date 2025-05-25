@tool
class_name ObjectLabels
extends Node3D

## Manages 3D labels for mission objects in the viewport.
## Provides dynamic label visibility, scaling, and positioning
## with performance optimizations for large numbers of objects.

signal label_clicked(object: MissionObjectNode3D)

@export var max_visible_labels: int = 50
@export var label_fade_distance: float = 500.0
@export var label_min_scale: float = 0.5
@export var label_max_scale: float = 2.0
@export var show_selected_only: bool = false

# Label management
var object_labels: Dictionary = {}  # MissionObjectNode3D -> Label3D
var viewport: MissionViewport3D
var camera: MissionCamera3D

# Performance optimization
var update_timer: Timer
var update_interval: float = 0.1  # Update labels 10 times per second
var labels_need_update: bool = true

func _ready() -> void:
	setup_update_timer()

## Sets up the viewport reference.
func setup_viewport(mission_viewport: MissionViewport3D) -> void:
	viewport = mission_viewport
	camera = viewport.mission_camera
	
	# Connect signals
	if viewport:
		viewport.object_selected.connect(_on_objects_selected)
		viewport.object_deselected.connect(_on_objects_deselected)
	
	if camera:
		camera.camera_moved.connect(_on_camera_moved)

## Sets up the update timer for performance optimization.
func setup_update_timer() -> void:
	update_timer = Timer.new()
	update_timer.name = "UpdateTimer"
	update_timer.wait_time = update_interval
	update_timer.timeout.connect(_on_update_timer_timeout)
	update_timer.autostart = true
	add_child(update_timer)

## Creates a label for a mission object.
func create_object_label(obj: MissionObjectNode3D) -> Label3D:
	if not obj or object_labels.has(obj):
		return null
	
	var label: Label3D = Label3D.new()
	label.name = "Label_" + obj.name
	label.text = obj.mission_object.name if obj.mission_object else obj.name
	
	# Configure label appearance
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.font_size = 16
	
	# Set label colors
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.outline_size = 2
	
	# Position above object
	label.position = obj.position + Vector3(0, obj.selection_radius + 5.0, 0)
	
	# Add to scene
	add_child(label)
	object_labels[obj] = label
	
	# Connect object signals
	obj.transform_changed.connect(_on_object_transform_changed)
	
	return label

## Removes a label for a mission object.
func remove_object_label(obj: MissionObjectNode3D) -> void:
	if not obj or not object_labels.has(obj):
		return
	
	var label: Label3D = object_labels[obj]
	if label and is_instance_valid(label):
		label.queue_free()
	
	object_labels.erase(obj)

## Updates all object labels with current mission objects.
func update_object_labels() -> void:
	if not viewport:
		return
	
	# Remove labels for deleted objects
	var objects_to_remove: Array[MissionObjectNode3D] = []
	for obj: MissionObjectNode3D in object_labels.keys():
		if not obj or not is_instance_valid(obj) or not obj in viewport.mission_objects:
			objects_to_remove.append(obj)
	
	for obj: MissionObjectNode3D in objects_to_remove:
		remove_object_label(obj)
	
	# Create labels for new objects
	for obj: MissionObjectNode3D in viewport.mission_objects:
		if obj and not object_labels.has(obj):
			create_object_label(obj)

## Updates label visibility and scaling based on camera position.
func update_label_visibility() -> void:
	if not camera:
		return
	
	var camera_pos: Vector3 = camera.global_position
	var visible_count: int = 0
	
	# Calculate distances and sort by priority
	var label_priorities: Array[Dictionary] = []
	
	for obj: MissionObjectNode3D in object_labels.keys():
		if not obj or not is_instance_valid(obj):
			continue
		
		var label: Label3D = object_labels[obj]
		if not label or not is_instance_valid(label):
			continue
		
		var distance: float = camera_pos.distance_to(obj.global_position)
		var is_selected: bool = obj.is_selected
		var priority: float = calculate_label_priority(obj, distance, is_selected)
		
		label_priorities.append({
			"object": obj,
			"label": label,
			"distance": distance,
			"priority": priority,
			"is_selected": is_selected
		})
	
	# Sort by priority (higher priority first)
	label_priorities.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Update visibility and scaling
	for i: int in range(label_priorities.size()):
		var item: Dictionary = label_priorities[i]
		var label: Label3D = item.label
		var distance: float = item.distance
		var is_selected: bool = item.is_selected
		
		# Determine visibility
		var should_be_visible: bool = should_show_label(item.object, distance, is_selected, visible_count)
		
		if should_be_visible:
			visible_count += 1
			
			# Update label visibility and scale
			label.visible = true
			update_label_scale(label, distance)
			update_label_alpha(label, distance)
		else:
			label.visible = false

## Calculates the priority of a label for visibility sorting.
func calculate_label_priority(obj: MissionObjectNode3D, distance: float, is_selected: bool) -> float:
	var priority: float = 0.0
	
	# Selected objects get highest priority
	if is_selected:
		priority += 1000.0
	
	# Closer objects get higher priority
	priority += max(0.0, label_fade_distance - distance)
	
	# Important object types get bonus priority
	if obj.mission_object:
		match obj.object_type:
			MissionObject.ObjectType.SHIP:
				priority += 100.0
			MissionObject.ObjectType.JUMP_NODE:
				priority += 50.0
			MissionObject.ObjectType.WAYPOINT:
				priority += 25.0
	
	return priority

## Determines if a label should be shown.
func should_show_label(obj: MissionObjectNode3D, distance: float, is_selected: bool, current_visible_count: int) -> bool:
	# Always show selected objects (if not in selected-only mode)
	if is_selected and not show_selected_only:
		return true
	
	# In selected-only mode, only show selected objects
	if show_selected_only:
		return is_selected
	
	# Don't exceed maximum visible labels
	if current_visible_count >= max_visible_labels:
		return false
	
	# Don't show labels that are too far away
	if distance > label_fade_distance:
		return false
	
	return true

## Updates the scale of a label based on distance.
func update_label_scale(label: Label3D, distance: float) -> void:
	# Calculate scale based on distance
	var scale_factor: float = 1.0 - (distance / label_fade_distance)
	scale_factor = clamp(scale_factor, 0.0, 1.0)
	
	# Apply scale limits
	var final_scale: float = lerp(label_min_scale, label_max_scale, scale_factor)
	label.scale = Vector3.ONE * final_scale

## Updates the alpha/transparency of a label based on distance.
func update_label_alpha(label: Label3D, distance: float) -> void:
	# Calculate alpha based on distance
	var alpha_factor: float = 1.0 - (distance / label_fade_distance)
	alpha_factor = clamp(alpha_factor, 0.1, 1.0)
	
	# Apply alpha
	var color: Color = label.modulate
	color.a = alpha_factor
	label.modulate = color

## Updates label positions to follow their objects.
func update_label_positions() -> void:
	for obj: MissionObjectNode3D in object_labels.keys():
		if not obj or not is_instance_valid(obj):
			continue
		
		var label: Label3D = object_labels[obj]
		if not label or not is_instance_valid(label):
			continue
		
		# Position label above object
		label.position = obj.position + Vector3(0, obj.selection_radius + 5.0, 0)

## Sets whether to show only selected object labels.
func set_show_selected_only(enabled: bool) -> void:
	show_selected_only = enabled
	labels_need_update = true

## Sets the maximum number of visible labels.
func set_max_visible_labels(count: int) -> void:
	max_visible_labels = max(1, count)
	labels_need_update = true

## Sets the label fade distance.
func set_label_fade_distance(distance: float) -> void:
	label_fade_distance = max(10.0, distance)
	labels_need_update = true

## Clears all object labels.
func clear_all_labels() -> void:
	for label: Label3D in object_labels.values():
		if label and is_instance_valid(label):
			label.queue_free()
	
	object_labels.clear()

## Signal handlers

func _on_update_timer_timeout() -> void:
	if labels_need_update:
		update_object_labels()
		update_label_positions()
		update_label_visibility()
		labels_need_update = false

func _on_objects_selected(objects: Array[MissionObjectNode3D]) -> void:
	labels_need_update = true

func _on_objects_deselected() -> void:
	labels_need_update = true

func _on_camera_moved(camera_node: MissionCamera3D) -> void:
	labels_need_update = true

func _on_object_transform_changed(obj: MissionObjectNode3D) -> void:
	labels_need_update = true