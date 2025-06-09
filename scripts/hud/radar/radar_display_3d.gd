class_name RadarDisplay3D
extends HUDElementBase

## HUD-009 Component 1: 3D Radar Display and Visualization
## Primary 3D radar display system providing spatial awareness of the battlefield
## Displays ships, objects, and navigation points in three-dimensional representation

signal radar_contact_selected(contact: RadarContact)
signal radar_range_changed(new_range: float)
signal radar_zoom_changed(new_zoom: int)
signal radar_mode_changed(new_mode: String)
signal radar_jamming_detected(jamming_strength: float)

# 3D radar display parameters
@export var radar_range: float = 10000.0  # Current radar range in meters
@export var zoom_level: int = 2           # Current zoom level (1-5)
@export var display_size: Vector2 = Vector2(300, 300)  # Radar display dimensions
@export var radar_update_frequency: float = 30.0  # 30 Hz for smooth radar updates
@export var max_contacts: int = 200        # Maximum radar contacts to display

# Display components
var spatial_manager: RadarSpatialManager
var object_renderer: RadarObjectRenderer
var zoom_controller: RadarZoomController
var performance_optimizer: RadarPerformanceOptimizer
var data_provider: Node  # HUD data provider reference

# Current radar state
var player_position: Vector3 = Vector3.ZERO
var player_orientation: Quaternion = Quaternion.IDENTITY
var tracked_objects: Array[RadarContact] = []
var selected_contact: RadarContact = null

# Display configuration
var display_mode: String = "tactical"  # tactical, strategic, navigation
var show_range_rings: bool = true
var show_elevation_markers: bool = true
var show_object_labels: bool = true
var auto_zoom: bool = false

# Performance tracking
var contacts_rendered: int = 0
var render_time_ms: float = 0.0
var last_performance_check: float = 0.0

# Contact management
var contact_pool: Array[RadarContact] = []
var active_contacts: Dictionary = {}  # object_id -> RadarContact
var contact_counter: int = 0

# Radar modes and settings
var radar_modes: Dictionary = {
	"tactical": {"range": 5000.0, "detail": "high", "filter": "combat"},
	"strategic": {"range": 50000.0, "detail": "medium", "filter": "all"},
	"navigation": {"range": 20000.0, "detail": "low", "filter": "navigation"}
}

# Zoom levels with corresponding ranges
var zoom_levels: Array[float] = [2000.0, 5000.0, 10000.0, 25000.0, 50000.0]

func _ready() -> void:
	super._ready()
	_initialize_radar_display()

func _initialize_radar_display() -> void:
	print("RadarDisplay3D: Initializing 3D radar display system...")
	
	# Create component instances
	spatial_manager = RadarSpatialManager.new()
	object_renderer = RadarObjectRenderer.new()
	zoom_controller = RadarZoomController.new()
	performance_optimizer = RadarPerformanceOptimizer.new()
	
	# Configure components
	spatial_manager.setup_radar_display(display_size, radar_range)
	object_renderer.setup_renderer(self)
	zoom_controller.setup_zoom_system(zoom_levels, zoom_level)
	performance_optimizer.setup_performance_monitoring()
	
	# Add object renderer as child for drawing
	add_child(object_renderer)
	
	# Connect component signals
	zoom_controller.zoom_changed.connect(_on_zoom_changed)
	object_renderer.contact_selected.connect(_on_contact_selected)
	
	# Setup update timer
	var update_timer = Timer.new()
	update_timer.wait_time = 1.0 / radar_update_frequency
	update_timer.timeout.connect(_on_radar_update_timer)
	update_timer.autostart = true
	add_child(update_timer)
	
	# Initialize contact pool
	_initialize_contact_pool()
	
	print("RadarDisplay3D: 3D radar display initialized")

func _initialize_contact_pool() -> void:
	# Pre-allocate RadarContact objects for performance
	for i in range(max_contacts):
		var contact = RadarContact.new()
		contact_pool.append(contact)

## Update radar display
func update_radar_display(delta: float) -> void:
	var start_time = Time.get_ticks_usec()
	
	# Update player position and orientation
	_update_player_data()
	
	# Update spatial manager
	spatial_manager.update_spatial_data(player_position, player_orientation, radar_range)
	
	# Process contacts
	_update_radar_contacts()
	
	# Update object renderer
	object_renderer.update_render_data(tracked_objects, spatial_manager)
	
	# Check for auto-zoom conditions
	if auto_zoom:
		_check_auto_zoom_conditions()
	
	# Performance monitoring
	var end_time = Time.get_ticks_usec()
	render_time_ms = (end_time - start_time) / 1000.0
	
	# Optimize performance if needed
	performance_optimizer.monitor_performance(render_time_ms, tracked_objects.size())

func _update_player_data() -> void:
	# Get player ship data from HUD data provider
	var player_ship = _get_player_ship()
	if player_ship:
		player_position = player_ship.global_position
		# Convert rotation to quaternion for proper 3D orientation
		var euler = player_ship.global_rotation
		player_orientation = Quaternion.from_euler(euler)

func _update_radar_contacts() -> void:
	# Clear previous frame contacts
	tracked_objects.clear()
	
	# Get contacts from data provider
	var available_contacts = _get_available_contacts()
	
	contacts_rendered = 0
	
	for contact_data in available_contacts:
		if contacts_rendered >= max_contacts:
			break
			
		var contact = _create_or_update_contact(contact_data)
		if contact and _should_display_contact(contact):
			tracked_objects.append(contact)
			contacts_rendered += 1

func _get_available_contacts() -> Array:
	# Integration with HUD data provider for radar contacts
	var contacts: Array = []
	
	# Get data from HUD data provider if available
	if data_provider:
		var radar_data = data_provider.get_radar_contacts()
		if radar_data.has("contacts"):
			contacts = radar_data.contacts
	
	# Fallback: Get contacts from scene tree
	if contacts.is_empty():
		contacts = _get_contacts_from_scene()
	
	return contacts

func _get_contacts_from_scene() -> Array:
	var contacts: Array = []
	
	# Find all radar-visible objects in the scene
	var all_objects = get_tree().get_nodes_in_group("radar_visible")
	
	for obj in all_objects:
		if obj == _get_player_ship():
			continue  # Don't show player ship on radar
			
		var distance = player_position.distance_to(obj.global_position)
		if distance <= radar_range:
			contacts.append({
				"object": obj,
				"position": obj.global_position,
				"velocity": obj.get("velocity") if obj.has_method("get") else Vector3.ZERO,
				"object_type": _determine_object_type(obj),
				"iff_status": _determine_iff_status(obj),
				"name": obj.name,
				"signature": _calculate_radar_signature(obj)
			})
	
	return contacts

func _create_or_update_contact(contact_data: Dictionary) -> RadarContact:
	var obj = contact_data.get("object")
	if not obj:
		return null
		
	var object_id = obj.get_instance_id()
	
	# Get existing contact or create new one
	var contact: RadarContact
	if active_contacts.has(object_id):
		contact = active_contacts[object_id]
	else:
		contact = _get_contact_from_pool()
		if not contact:
			return null
		active_contacts[object_id] = contact
	
	# Update contact data
	contact.object_id = object_id
	contact.object_reference = obj
	contact.world_position = contact_data.get("position", Vector3.ZERO)
	contact.velocity = contact_data.get("velocity", Vector3.ZERO)
	contact.object_type = contact_data.get("object_type", RadarContact.ObjectType.UNKNOWN)
	contact.iff_status = contact_data.get("iff_status", "unknown")
	contact.object_name = contact_data.get("name", "Unknown")
	contact.radar_signature = contact_data.get("signature", 1.0)
	contact.last_updated = Time.get_ticks_usec() / 1000000.0
	
	# Calculate radar position using spatial manager
	contact.radar_position = spatial_manager.world_to_radar_coordinates(
		contact.world_position, player_position, player_orientation
	)
	
	# Calculate additional display data
	contact.distance = player_position.distance_to(contact.world_position)
	contact.elevation = spatial_manager.calculate_elevation_indicator(
		contact.world_position, player_position
	)
	contact.is_targeted = (selected_contact == contact)
	
	return contact

func _get_contact_from_pool() -> RadarContact:
	for contact in contact_pool:
		if not contact.is_active:
			contact.is_active = true
			return contact
	
	# Pool exhausted - this shouldn't happen with proper max_contacts limit
	print("RadarDisplay3D: Warning - Contact pool exhausted")
	return null

func _should_display_contact(contact: RadarContact) -> bool:
	# Distance filtering
	if contact.distance > radar_range:
		return false
	
	# Mode-based filtering
	var mode_filter = radar_modes[display_mode].get("filter", "all")
	match mode_filter:
		"combat":
			return contact.iff_status in ["enemy", "unknown"]
		"navigation":
			return contact.object_type in [RadarContact.ObjectType.STATION, RadarContact.ObjectType.WAYPOINT]
		"all":
			return true
		_:
			return true

func _determine_object_type(obj: Node) -> RadarContact.ObjectType:
	# Try to determine object type from node groups or properties
	if obj.is_in_group("fighters"):
		return RadarContact.ObjectType.FIGHTER
	elif obj.is_in_group("bombers"):
		return RadarContact.ObjectType.BOMBER
	elif obj.is_in_group("cruisers"):
		return RadarContact.ObjectType.CRUISER
	elif obj.is_in_group("capital_ships"):
		return RadarContact.ObjectType.CAPITAL
	elif obj.is_in_group("stations"):
		return RadarContact.ObjectType.STATION
	elif obj.is_in_group("missiles"):
		return RadarContact.ObjectType.MISSILE
	elif obj.is_in_group("debris"):
		return RadarContact.ObjectType.DEBRIS
	elif obj.is_in_group("waypoints"):
		return RadarContact.ObjectType.WAYPOINT
	else:
		return RadarContact.ObjectType.UNKNOWN

func _determine_iff_status(obj: Node) -> String:
	# Try to determine IFF status from object properties
	if obj.has_method("get_iff_status"):
		return obj.get_iff_status()
	elif obj.is_in_group("friendly"):
		return "friendly"
	elif obj.is_in_group("enemy"):
		return "enemy"
	elif obj.is_in_group("neutral"):
		return "neutral"
	else:
		return "unknown"

func _calculate_radar_signature(obj: Node) -> float:
	# Calculate radar cross-section or signature strength
	if obj.has_method("get_radar_signature"):
		return obj.get_radar_signature()
	
	# Estimate based on object type and size
	var signature = 1.0
	
	if obj.is_in_group("capital_ships"):
		signature = 10.0
	elif obj.is_in_group("cruisers"):
		signature = 5.0
	elif obj.is_in_group("bombers"):
		signature = 2.0
	elif obj.is_in_group("fighters"):
		signature = 1.0
	elif obj.is_in_group("missiles"):
		signature = 0.2
	
	return signature

func _check_auto_zoom_conditions() -> void:
	if not auto_zoom:
		return
	
	# Auto-zoom based on contact density and engagement range
	var close_contacts = 0
	var medium_contacts = 0
	
	for contact in tracked_objects:
		if contact.distance < 2000.0:
			close_contacts += 1
		elif contact.distance < 5000.0:
			medium_contacts += 1
	
	var desired_zoom = zoom_level
	
	if close_contacts > 3:
		desired_zoom = 1  # Zoom in for close combat
	elif medium_contacts > 5:
		desired_zoom = 2  # Medium zoom for tactical view
	elif tracked_objects.size() > 10:
		desired_zoom = 4  # Zoom out for strategic overview
	
	if desired_zoom != zoom_level:
		set_zoom_level(desired_zoom)

## Public interface methods

## Set radar range
func set_radar_range(new_range: float) -> void:
	radar_range = max(1000.0, min(100000.0, new_range))
	spatial_manager.set_radar_range(radar_range)
	radar_range_changed.emit(radar_range)

## Set zoom level
func set_zoom_level(new_zoom: int) -> void:
	if new_zoom >= 1 and new_zoom <= zoom_levels.size():
		zoom_level = new_zoom
		var new_range = zoom_levels[zoom_level - 1]
		set_radar_range(new_range)
		zoom_controller.set_zoom_level(zoom_level)
		radar_zoom_changed.emit(zoom_level)

## Set display mode
func set_display_mode(new_mode: String) -> void:
	if new_mode in radar_modes:
		display_mode = new_mode
		var mode_config = radar_modes[new_mode]
		set_radar_range(mode_config.range)
		radar_mode_changed.emit(new_mode)

## Select radar contact
func select_contact(contact: RadarContact) -> void:
	if selected_contact:
		selected_contact.is_targeted = false
	
	selected_contact = contact
	if contact:
		contact.is_targeted = true
		radar_contact_selected.emit(contact)

## Get current radar contacts
func get_radar_contacts() -> Array[RadarContact]:
	return tracked_objects.duplicate()

## Get contact at screen position
func get_contact_at_position(screen_pos: Vector2) -> RadarContact:
	return object_renderer.get_contact_at_position(screen_pos)

## Event handlers

func _on_radar_update_timer() -> void:
	if is_visible() and is_active:
		update_radar_display(1.0 / radar_update_frequency)

func _on_zoom_changed(new_zoom: int) -> void:
	set_zoom_level(new_zoom)

func _on_contact_selected(contact: RadarContact) -> void:
	select_contact(contact)

## Utility methods

func _get_player_ship() -> Node:
	var player_ships = get_tree().get_nodes_in_group("player_ships")
	return player_ships[0] if not player_ships.is_empty() else null

## Transform world coordinates to radar display coordinates
func transform_world_to_radar(world_pos: Vector3) -> Vector2:
	return spatial_manager.world_to_radar_coordinates(world_pos, player_position, player_orientation)

## Check if position is within radar range
func is_within_radar_range(world_pos: Vector3) -> bool:
	var distance = player_position.distance_to(world_pos)
	return distance <= radar_range

## Get radar display status
func get_radar_status() -> Dictionary:
	return {
		"radar_range": radar_range,
		"zoom_level": zoom_level,
		"display_mode": display_mode,
		"contacts_tracked": tracked_objects.size(),
		"contacts_rendered": contacts_rendered,
		"render_time_ms": render_time_ms,
		"player_position": player_position,
		"performance_level": performance_optimizer.get_performance_level()
	}

## Cleanup inactive contacts
func _cleanup_inactive_contacts() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	var cleanup_threshold = 5.0  # Remove contacts not updated for 5 seconds
	
	var to_remove: Array[int] = []
	
	for object_id in active_contacts.keys():
		var contact = active_contacts[object_id]
		if current_time - contact.last_updated > cleanup_threshold:
			to_remove.append(object_id)
			contact.is_active = false  # Return to pool
	
	for object_id in to_remove:
		active_contacts.erase(object_id)

## Performance monitoring
func get_performance_metrics() -> Dictionary:
	return {
		"contacts_rendered": contacts_rendered,
		"render_time_ms": render_time_ms,
		"update_frequency": radar_update_frequency,
		"memory_usage": active_contacts.size(),
		"pool_usage": contact_pool.size() - active_contacts.size()
	}

# RadarContact data structure
class RadarContact:
	enum ObjectType {
		FIGHTER,
		BOMBER, 
		CRUISER,
		CAPITAL,
		STATION,
		MISSILE,
		DEBRIS,
		WAYPOINT,
		UNKNOWN
	}
	
	# Object identification
	var object_id: int = 0
	var object_reference: Node = null
	var object_type: ObjectType = ObjectType.UNKNOWN
	var object_name: String = ""
	var iff_status: String = "unknown"  # friendly, enemy, neutral, unknown
	
	# Spatial data
	var world_position: Vector3 = Vector3.ZERO
	var radar_position: Vector2 = Vector2.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var distance: float = 0.0
	var elevation: float = 0.0  # Relative elevation from player
	
	# Display data
	var radar_signature: float = 1.0
	var is_targeted: bool = false
	var is_jammed: bool = false
	var is_active: bool = false
	var last_updated: float = 0.0
	
	func _init():
		last_updated = Time.get_ticks_usec() / 1000000.0
