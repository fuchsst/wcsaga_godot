class_name CollisionLayerDebugger
extends Control

## Debug visualization for collision layers and active collision relationships.
## Provides visual representation of collision layer assignments, mask compatibility,
## and real-time collision filtering statistics for development and debugging.

# EPIC-002 Asset Core Integration
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")

signal debug_mode_toggled(enabled: bool)
signal layer_visibility_changed(layer: CollisionLayers.Layer, visible: bool)

# Debug configuration
@export var enable_debug_overlay: bool = false
@export var show_collision_shapes: bool = true
@export var show_layer_assignments: bool = true
@export var show_collision_statistics: bool = true
@export var update_frequency: float = 0.1  # Update frequency in seconds

# Debug UI elements
var debug_panel: Panel
var layer_list: VBoxContainer
var statistics_label: RichTextLabel
var collision_filter_ref: CollisionFilter

# Layer visibility tracking
var layer_visibility: Dictionary = {}
var debug_objects: Array[Node3D] = []

# Statistics tracking
var debug_update_timer: float = 0.0

func _ready() -> void:
	_setup_debug_ui()
	_initialize_layer_visibility()
	
	# Try to find CollisionFilter in scene
	collision_filter_ref = _find_collision_filter()
	
	if collision_filter_ref:
		# Connect to collision filter signals
		collision_filter_ref.collision_filtered.connect(_on_collision_filtered)
		collision_filter_ref.collision_mask_changed.connect(_on_collision_mask_changed)
		collision_filter_ref.temporary_rule_added.connect(_on_temporary_rule_added)
		collision_filter_ref.temporary_rule_expired.connect(_on_temporary_rule_expired)
	
	print("CollisionLayerDebugger: Initialized with debug overlay support")

func _process(delta: float) -> void:
	"""Update debug visualization each frame."""
	if not enable_debug_overlay:
		return
	
	debug_update_timer += delta
	if debug_update_timer >= update_frequency:
		_update_debug_display()
		debug_update_timer = 0.0

func _setup_debug_ui() -> void:
	"""Create debug overlay UI elements."""
	# Main debug panel
	debug_panel = Panel.new()
	debug_panel.size = Vector2(400, 600)
	debug_panel.position = Vector2(20, 20)
	debug_panel.visible = enable_debug_overlay
	add_child(debug_panel)
	
	# Main container
	var main_container: VBoxContainer = VBoxContainer.new()
	debug_panel.add_child(main_container)
	
	# Title label
	var title_label: Label = Label.new()
	title_label.text = "Collision Layer Debugger"
	title_label.add_theme_font_size_override("font_size", 16)
	main_container.add_child(title_label)
	
	# Layer visibility section
	var layer_section_label: Label = Label.new()
	layer_section_label.text = "Layer Visibility:"
	layer_section_label.add_theme_font_size_override("font_size", 14)
	main_container.add_child(layer_section_label)
	
	# Scrollable layer list
	var layer_scroll: ScrollContainer = ScrollContainer.new()
	layer_scroll.custom_minimum_size = Vector2(380, 200)
	main_container.add_child(layer_scroll)
	
	layer_list = VBoxContainer.new()
	layer_scroll.add_child(layer_list)
	
	# Statistics section
	var stats_label: Label = Label.new()
	stats_label.text = "Collision Statistics:"
	stats_label.add_theme_font_size_override("font_size", 14)
	main_container.add_child(stats_label)
	
	statistics_label = RichTextLabel.new()
	statistics_label.custom_minimum_size = Vector2(380, 150)
	statistics_label.fit_content = true
	main_container.add_child(statistics_label)
	
	# Control buttons
	var button_container: HBoxContainer = HBoxContainer.new()
	main_container.add_child(button_container)
	
	var toggle_debug_button: Button = Button.new()
	toggle_debug_button.text = "Toggle Debug"
	toggle_debug_button.pressed.connect(_on_toggle_debug_pressed)
	button_container.add_child(toggle_debug_button)
	
	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_on_refresh_pressed)
	button_container.add_child(refresh_button)

func _initialize_layer_visibility() -> void:
	"""Initialize layer visibility tracking and UI."""
	var all_layers: Array[CollisionLayers.Layer] = CollisionLayers.get_all_layers()
	
	for layer in all_layers:
		layer_visibility[layer] = true
		_create_layer_toggle(layer)

func _create_layer_toggle(layer: CollisionLayers.Layer) -> void:
	"""Create a toggle checkbox for a collision layer."""
	var layer_container: HBoxContainer = HBoxContainer.new()
	layer_list.add_child(layer_container)
	
	var checkbox: CheckBox = CheckBox.new()
	checkbox.button_pressed = layer_visibility[layer]
	checkbox.text = CollisionLayers.get_layer_name(layer)
	checkbox.toggled.connect(func(pressed: bool): _on_layer_visibility_toggled(layer, pressed))
	layer_container.add_child(checkbox)
	
	# Layer status indicator
	var status_label: Label = Label.new()
	status_label.text = "[Active]"
	status_label.add_theme_color_override("font_color", Color.GREEN)
	layer_container.add_child(status_label)

func _find_collision_filter() -> CollisionFilter:
	"""Find CollisionFilter node in the scene tree."""
	# Search in common locations
	var potential_paths: Array[String] = [
		"/root/CollisionDetector/CollisionFilter",
		"/root/CollisionFilter", 
		"CollisionFilter"
	]
	
	for path in potential_paths:
		var node: Node = get_node_or_null(path)
		if node and node is CollisionFilter:
			return node as CollisionFilter
	
	# Search recursively in scene tree
	return _search_for_collision_filter(get_tree().root)

func _search_for_collision_filter(parent: Node) -> CollisionFilter:
	"""Recursively search for CollisionFilter node."""
	if parent is CollisionFilter:
		return parent as CollisionFilter
	
	for child in parent.get_children():
		var result: CollisionFilter = _search_for_collision_filter(child)
		if result:
			return result
	
	return null

func _update_debug_display() -> void:
	"""Update the debug overlay with current collision information."""
	if not enable_debug_overlay or not debug_panel.visible:
		return
	
	_update_statistics_display()
	_update_object_visualization()

func _update_statistics_display() -> void:
	"""Update collision statistics in the debug panel."""
	if not collision_filter_ref or not statistics_label:
		return
	
	var stats: Dictionary = collision_filter_ref.get_filter_statistics()
	
	var stats_text: String = "[b]Collision Filter Statistics:[/b]\n"
	stats_text += "• Total Filtered: %d\n" % stats.get("total_filtered", 0)
	stats_text += "• Parent-Child: %d\n" % stats.get("parent_child_filtered", 0)
	stats_text += "• Collision Groups: %d\n" % stats.get("collision_group_filtered", 0)
	stats_text += "• Distance: %d\n" % stats.get("distance_filtered", 0)
	stats_text += "• Type Incompatible: %d\n" % stats.get("type_filtered", 0)
	
	# Add dynamic override information
	stats_text += "\n[b]Dynamic Overrides:[/b]\n"
	stats_text += "• Active Overrides: %d\n" % collision_filter_ref.dynamic_collision_overrides.size()
	stats_text += "• Temporary Rules: %d\n" % collision_filter_ref.temporary_collision_rules.size()
	
	statistics_label.text = stats_text

func _update_object_visualization() -> void:
	"""Update visual representation of collision objects."""
	if not show_collision_shapes:
		return
	
	# Get all collision objects in scene
	debug_objects.clear()
	_collect_collision_objects(get_tree().root)
	
	# Update layer visibility for each object
	for obj in debug_objects:
		_update_object_layer_visualization(obj)

func _collect_collision_objects(parent: Node) -> void:
	"""Recursively collect all collision objects."""
	if parent is RigidBody3D or parent is CharacterBody3D or parent is Area3D:
		debug_objects.append(parent as Node3D)
	
	for child in parent.get_children():
		_collect_collision_objects(child)

func _update_object_layer_visualization(obj: Node3D) -> void:
	"""Update visual representation for a specific object."""
	if not collision_filter_ref:
		return
	
	var effective_layer: int = collision_filter_ref.get_object_effective_collision_layer(obj)
	var layer_visible: bool = _is_layer_visible(effective_layer)
	
	# Update object visibility based on layer settings
	if obj.has_method("set_collision_layer_debug_visible"):
		obj.set_collision_layer_debug_visible(layer_visible)

func _is_layer_visible(layer_mask: int) -> bool:
	"""Check if any layers in the mask are visible."""
	for layer in layer_visibility:
		if CollisionLayers.has_layer(layer_mask, layer):
			return layer_visibility[layer]
	
	return true  # Default to visible if no specific layer found

## Public API functions (AC6)

func toggle_debug_overlay() -> void:
	"""Toggle the debug overlay visibility."""
	enable_debug_overlay = not enable_debug_overlay
	debug_panel.visible = enable_debug_overlay
	debug_mode_toggled.emit(enable_debug_overlay)
	print("CollisionLayerDebugger: Debug overlay %s" % ("enabled" if enable_debug_overlay else "disabled"))

func set_layer_visibility(layer: CollisionLayers.Layer, visible: bool) -> void:
	"""Set visibility for a specific collision layer.
	
	Args:
		layer: Collision layer to modify
		visible: Visibility state for the layer
	"""
	layer_visibility[layer] = visible
	layer_visibility_changed.emit(layer, visible)
	print("CollisionLayerDebugger: Layer %s visibility: %s" % [CollisionLayers.get_layer_name(layer), visible])

func get_active_collision_relationships() -> Dictionary:
	"""Get information about active collision relationships.
	
	Returns:
		Dictionary containing collision relationship data
	"""
	var relationships: Dictionary = {
		"total_objects": debug_objects.size(),
		"layer_counts": {},
		"active_overrides": 0,
		"temporary_rules": 0
	}
	
	if collision_filter_ref:
		relationships.active_overrides = collision_filter_ref.dynamic_collision_overrides.size()
		relationships.temporary_rules = collision_filter_ref.temporary_collision_rules.size()
	
	# Count objects per layer
	for obj in debug_objects:
		if not collision_filter_ref:
			continue
			
		var layer: int = collision_filter_ref.get_object_effective_collision_layer(obj)
		
		for collision_layer in CollisionLayers.get_all_layers():
			if CollisionLayers.has_layer(layer, collision_layer):
				var layer_name: String = CollisionLayers.get_layer_name(collision_layer)
				relationships.layer_counts[layer_name] = relationships.layer_counts.get(layer_name, 0) + 1
	
	return relationships

func highlight_collision_pair(object_a: Node3D, object_b: Node3D, highlight_time: float = 2.0) -> void:
	"""Highlight a specific collision pair for debugging.
	
	Args:
		object_a: First object in collision pair
		object_b: Second object in collision pair  
		highlight_time: Duration to highlight in seconds
	"""
	if not enable_debug_overlay:
		return
	
	print("CollisionLayerDebugger: Highlighting collision pair: %s <-> %s" % [object_a.name, object_b.name])
	
	# Add visual highlight effect
	_add_highlight_effect(object_a, highlight_time)
	_add_highlight_effect(object_b, highlight_time)

func _add_highlight_effect(obj: Node3D, duration: float) -> void:
	"""Add temporary highlight effect to an object."""
	if not obj:
		return
	
	# Create temporary highlight material/effect
	var highlight_node: Node3D = _create_highlight_visual(obj)
	if highlight_node:
		obj.add_child(highlight_node)
		
		# Remove highlight after duration
		await get_tree().create_timer(duration).timeout
		if is_instance_valid(highlight_node):
			highlight_node.queue_free()

func _create_highlight_visual(obj: Node3D) -> Node3D:
	"""Create visual highlight effect for collision debugging."""
	var highlight: Node3D = Node3D.new()
	highlight.name = "CollisionDebugHighlight"
	
	# Add wireframe or outline effect if possible
	# This would depend on the specific visual system being used
	
	return highlight

## Signal handlers

func _on_collision_filtered(object_a: Node3D, object_b: Node3D, filter_reason: String) -> void:
	"""Handle collision filtering events for debugging."""
	if enable_debug_overlay:
		print("CollisionLayerDebugger: Filtered collision %s <-> %s: %s" % [object_a.name, object_b.name, filter_reason])

func _on_collision_mask_changed(object: Node3D, new_layer: int, new_mask: int) -> void:
	"""Handle collision mask changes for debugging."""
	if enable_debug_overlay:
		print("CollisionLayerDebugger: Mask changed for %s - Layer: %d, Mask: %d" % [object.name, new_layer, new_mask])

func _on_temporary_rule_added(rule_id: String, type_a: int, type_b: int) -> void:
	"""Handle temporary rule addition for debugging."""
	if enable_debug_overlay:
		print("CollisionLayerDebugger: Temporary rule added: %s (%d <-> %d)" % [rule_id, type_a, type_b])

func _on_temporary_rule_expired(rule_id: String) -> void:
	"""Handle temporary rule expiration for debugging."""
	if enable_debug_overlay:
		print("CollisionLayerDebugger: Temporary rule expired: %s" % rule_id)

func _on_layer_visibility_toggled(layer: CollisionLayers.Layer, visible: bool) -> void:
	"""Handle layer visibility toggle."""
	set_layer_visibility(layer, visible)

func _on_toggle_debug_pressed() -> void:
	"""Handle debug overlay toggle button."""
	toggle_debug_overlay()

func _on_refresh_pressed() -> void:
	"""Handle refresh button press."""
	_update_debug_display()
	print("CollisionLayerDebugger: Debug display refreshed")