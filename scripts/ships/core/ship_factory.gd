class_name ShipFactory
extends RefCounted

## Ship factory for creating configured ship instances from templates and classes
## Handles ship spawning, configuration, and initialization pipeline
## Supports WCS variant system and template-based ship creation

# Ship creation modes
enum CreationMode {
	FROM_CLASS = 0,      # Create from ShipClass resource
	FROM_TEMPLATE = 1,   # Create from ShipTemplate resource
	FROM_MISSION = 2,    # Create from mission file data
	FROM_REGISTRY = 3    # Create by name lookup in registry
}

# Ship initialization flags
enum InitFlags {
	PHYSICS = 1 << 0,           # Initialize physics body
	SUBSYSTEMS = 1 << 1,        # Initialize subsystem manager
	AI = 1 << 2,               # Initialize AI controller
	WEAPONS = 1 << 3,          # Initialize weapon systems
	VISUAL = 1 << 4,           # Load 3D models and textures
	AUDIO = 1 << 5,            # Initialize audio systems
	NETWORKING = 1 << 6,       # Initialize network sync
	ALL = 0x7F                 # Initialize everything
}

# Default initialization flags
const DEFAULT_INIT_FLAGS: int = InitFlags.PHYSICS | InitFlags.SUBSYSTEMS | InitFlags.VISUAL

# Factory configuration
var asset_loader: AssetLoader
var ship_registry: ShipRegistry
var performance_monitor: PerformanceMonitor

# Ship creation statistics
var ships_created: int = 0
var creation_times: Array[float] = []
var last_creation_time: float = 0.0

func _init(loader: AssetLoader = null, registry: ShipRegistry = null) -> void:
	asset_loader = loader if loader else AssetLoader.new()
	ship_registry = registry if registry else ShipRegistry.new()
	performance_monitor = PerformanceMonitor.new()

## Create ship from ShipClass resource
func create_ship_from_class(ship_class: ShipClass, ship_name: String = "", init_flags: int = DEFAULT_INIT_FLAGS) -> BaseShip:
	if ship_class == null or not ship_class.is_valid():
		push_error("ShipFactory: Invalid ship class provided")
		return null
	
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Create ship instance
	var ship: BaseShip = BaseShip.new()
	
	# Set ship name
	var final_name: String = ship_name if not ship_name.is_empty() else ship_class.class_name
	
	# Initialize ship from class
	if not ship.initialize_ship(ship_class, final_name):
		push_error("ShipFactory: Failed to initialize ship from class: " + ship_class.class_name)
		ship.queue_free()
		return null
	
	# Apply initialization flags
	_apply_initialization_flags(ship, ship_class, init_flags)
	
	# Record creation statistics
	_record_creation_statistics(start_time)
	
	print("ShipFactory: Created ship '%s' from class '%s'" % [final_name, ship_class.class_name])
	return ship

## Create ship from ShipTemplate resource
func create_ship_from_template(template: ShipTemplate, ship_name: String = "", init_flags: int = DEFAULT_INIT_FLAGS) -> BaseShip:
	if template == null or not template.is_valid():
		push_error("ShipFactory: Invalid ship template provided")
		return null
	
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Generate configured ship class from template
	var configured_class: ShipClass = template.create_ship_class()
	if configured_class == null:
		push_error("ShipFactory: Failed to create ship class from template: " + template.get_full_name())
		return null
	
	# Create ship from configured class
	var ship: BaseShip = create_ship_from_class(configured_class, ship_name, init_flags)
	if ship == null:
		return null
	
	# Apply template-specific initialization
	_apply_template_initialization(ship, template)
	
	print("ShipFactory: Created ship '%s' from template '%s'" % [ship.ship_name, template.get_full_name()])
	return ship

## Create ship by name from registry
func create_ship_by_name(ship_name: String, variant_suffix: String = "", init_flags: int = DEFAULT_INIT_FLAGS) -> BaseShip:
	if ship_name.is_empty():
		push_error("ShipFactory: Ship name cannot be empty")
		return null
	
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Build full ship name with variant
	var full_name: String = ship_name
	if not variant_suffix.is_empty():
		full_name += "#" + variant_suffix
	
	# Try to find template first (for variants)
	if not variant_suffix.is_empty():
		var template: ShipTemplate = ship_registry.get_ship_template(full_name)
		if template != null:
			return create_ship_from_template(template, "", init_flags)
	
	# Fall back to ship class lookup
	var ship_class: ShipClass = ship_registry.get_ship_class(ship_name)
	if ship_class != null:
		return create_ship_from_class(ship_class, "", init_flags)
	
	push_error("ShipFactory: Cannot find ship class or template: " + full_name)
	return null

## Create ship from mission data
func create_ship_from_mission_data(mission_data: Dictionary, init_flags: int = DEFAULT_INIT_FLAGS) -> BaseShip:
	if not mission_data.has("ship_class"):
		push_error("ShipFactory: Mission data missing ship_class")
		return null
	
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Parse ship class name and variant
	var ship_class_name: String = mission_data["ship_class"]
	var variant_suffix: String = ""
	
	# Handle WCS variant naming (e.g., "GTF Apollo#Advanced")
	var hash_pos: int = ship_class_name.find("#")
	if hash_pos != -1:
		variant_suffix = ship_class_name.substr(hash_pos + 1)
		ship_class_name = ship_class_name.substr(0, hash_pos)
	
	# Create ship
	var ship: BaseShip = create_ship_by_name(ship_class_name, variant_suffix, init_flags)
	if ship == null:
		return null
	
	# Apply mission-specific configuration
	_apply_mission_configuration(ship, mission_data)
	
	print("ShipFactory: Created mission ship '%s' class '%s'" % [mission_data.get("name", "Unnamed"), ship_class_name])
	return ship

## Create multiple ships efficiently (batch creation)
func create_ships_batch(creation_requests: Array[Dictionary], init_flags: int = DEFAULT_INIT_FLAGS) -> Array[BaseShip]:
	var ships: Array[BaseShip] = []
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Preload all required resources
	var required_classes: Array[String] = []
	var required_templates: Array[String] = []
	
	for request in creation_requests:
		match request.get("mode", CreationMode.FROM_REGISTRY):
			CreationMode.FROM_CLASS:
				if request.has("class_path"):
					required_classes.append(request["class_path"])
			CreationMode.FROM_TEMPLATE:
				if request.has("template_path"):
					required_templates.append(request["template_path"])
	
	# Batch preload resources
	asset_loader.preload_resources(required_classes + required_templates)
	
	# Create ships
	for request in creation_requests:
		var ship: BaseShip = null
		
		match request.get("mode", CreationMode.FROM_REGISTRY):
			CreationMode.FROM_CLASS:
				var ship_class: ShipClass = load(request["class_path"]) as ShipClass
				ship = create_ship_from_class(ship_class, request.get("name", ""), init_flags)
			CreationMode.FROM_TEMPLATE:
				var template: ShipTemplate = load(request["template_path"]) as ShipTemplate
				ship = create_ship_from_template(template, request.get("name", ""), init_flags)
			CreationMode.FROM_MISSION:
				ship = create_ship_from_mission_data(request, init_flags)
			CreationMode.FROM_REGISTRY:
				ship = create_ship_by_name(request["ship_name"], request.get("variant", ""), init_flags)
		
		if ship != null:
			ships.append(ship)
			
			# Apply batch-specific positioning
			if request.has("position"):
				ship.global_position = request["position"]
			if request.has("rotation"):
				ship.global_rotation = request["rotation"]
	
	var end_time: float = Time.get_ticks_msec() / 1000.0
	print("ShipFactory: Batch created %d ships in %.3f seconds" % [ships.size(), end_time - start_time])
	
	return ships

## Apply initialization flags to ship
func _apply_initialization_flags(ship: BaseShip, ship_class: ShipClass, flags: int) -> void:
	# Physics initialization
	if (flags & InitFlags.PHYSICS) != 0:
		_initialize_physics(ship, ship_class)
	
	# Subsystem initialization
	if (flags & InitFlags.SUBSYSTEMS) != 0:
		_initialize_subsystems(ship, ship_class)
	
	# AI initialization
	if (flags & InitFlags.AI) != 0:
		_initialize_ai(ship, ship_class)
	
	# Weapon initialization
	if (flags & InitFlags.WEAPONS) != 0:
		_initialize_weapons(ship, ship_class)
	
	# Visual initialization
	if (flags & InitFlags.VISUAL) != 0:
		_initialize_visual(ship, ship_class)
	
	# Audio initialization
	if (flags & InitFlags.AUDIO) != 0:
		_initialize_audio(ship, ship_class)
	
	# Networking initialization
	if (flags & InitFlags.NETWORKING) != 0:
		_initialize_networking(ship, ship_class)

## Initialize ship physics
func _initialize_physics(ship: BaseShip, ship_class: ShipClass) -> void:
	if ship.physics_body == null:
		return
	
	# Set physics properties
	ship.physics_body.mass = ship_class.mass
	ship.physics_body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	ship.physics_body.center_of_mass = Vector3.ZERO
	
	# Set collision shape based on ship type
	var collision_shape_type: String = ShipTypes.get_collision_shape_type(ship_class.ship_type)
	_setup_collision_shape(ship, ship_class, collision_shape_type)

## Initialize ship subsystems
func _initialize_subsystems(ship: BaseShip, ship_class: ShipClass) -> void:
	if ship.subsystem_manager == null:
		return
	
	# Subsystems are already created by BaseShip initialization
	# Additional subsystem configuration can be added here
	pass

## Initialize ship AI
func _initialize_ai(ship: BaseShip, ship_class: ShipClass) -> void:
	# AI initialization would be handled by AI system integration
	# This is a placeholder for future AI system integration
	pass

## Initialize ship weapons
func _initialize_weapons(ship: BaseShip, ship_class: ShipClass) -> void:
	# Weapon initialization would be handled by weapon system integration
	# This is a placeholder for future weapon system integration
	pass

## Initialize ship visuals
func _initialize_visual(ship: BaseShip, ship_class: ShipClass) -> void:
	if ship_class.model_path.is_empty():
		return
	
	# Load 3D model
	var model_scene: PackedScene = asset_loader.load_model(ship_class.model_path)
	if model_scene != null:
		var model_instance: Node3D = model_scene.instantiate()
		ship.add_child(model_instance)
		
		# Apply textures and materials
		if not ship_class.texture_path.is_empty():
			_apply_ship_textures(model_instance, ship_class)

## Initialize ship audio
func _initialize_audio(ship: BaseShip, ship_class: ShipClass) -> void:
	# Audio initialization would be handled by audio system integration
	pass

## Initialize ship networking
func _initialize_networking(ship: BaseShip, ship_class: ShipClass) -> void:
	# Networking initialization would be handled by networking system integration
	pass

## Apply template-specific initialization
func _apply_template_initialization(ship: BaseShip, template: ShipTemplate) -> void:
	# Apply team colors if specified
	for color_variation in template.team_color_variations:
		if color_variation.is_valid():
			_apply_team_colors(ship, color_variation)
	
	# Apply special flags
	for flag in template.special_flags:
		_apply_special_flag(ship, flag)

## Apply mission-specific configuration
func _apply_mission_configuration(ship: BaseShip, mission_data: Dictionary) -> void:
	# Set position and orientation
	if mission_data.has("position"):
		ship.global_position = mission_data["position"]
	if mission_data.has("orientation"):
		ship.global_rotation = mission_data["orientation"]
	
	# Set team/IFF
	if mission_data.has("team"):
		ship.team = mission_data["team"]
	
	# Set initial hull and shield values
	if mission_data.has("initial_hull"):
		var hull_percent: float = mission_data["initial_hull"] / 100.0
		ship.current_hull_strength = ship.max_hull_strength * hull_percent
	
	if mission_data.has("initial_shields"):
		var shield_percent: float = mission_data["initial_shields"] / 100.0
		ship.current_shield_strength = ship.max_shield_strength * shield_percent

## Setup collision shape for ship
func _setup_collision_shape(ship: BaseShip, ship_class: ShipClass, shape_type: String) -> void:
	# This would integrate with the model loading system to create appropriate collision shapes
	pass

## Apply ship textures and materials
func _apply_ship_textures(model_instance: Node3D, ship_class: ShipClass) -> void:
	# This would integrate with the texture/material system
	pass

## Apply team colors to ship
func _apply_team_colors(ship: BaseShip, color_variation: TeamColorVariation) -> void:
	# This would integrate with the material system to apply team colors
	pass

## Apply special flag to ship
func _apply_special_flag(ship: BaseShip, flag: String) -> void:
	# Apply special flags like "no_collide", "invulnerable", etc.
	match flag:
		"invulnerable":
			ship.is_invulnerable = true
		"no_collide":
			if ship.physics_body:
				ship.physics_body.collision_layer = 0
		"stealth":
			ship.is_stealthed = true

## Record creation statistics
func _record_creation_statistics(start_time: float) -> void:
	ships_created += 1
	last_creation_time = Time.get_ticks_msec() / 1000.0 - start_time
	creation_times.append(last_creation_time)
	
	# Keep only last 100 creation times for rolling average
	if creation_times.size() > 100:
		creation_times.pop_front()

## Get factory performance statistics
func get_performance_statistics() -> Dictionary:
	var avg_time: float = 0.0
	if creation_times.size() > 0:
		for time in creation_times:
			avg_time += time
		avg_time /= creation_times.size()
	
	return {
		"ships_created": ships_created,
		"last_creation_time": last_creation_time,
		"average_creation_time": avg_time,
		"samples": creation_times.size()
	}

## Reset factory statistics
func reset_statistics() -> void:
	ships_created = 0
	creation_times.clear()
	last_creation_time = 0.0

## Check factory health and performance
func is_factory_healthy() -> bool:
	# Check if factory is performing within acceptable parameters
	var stats: Dictionary = get_performance_statistics()
	
	# Consider factory unhealthy if average creation time > 100ms
	if stats["average_creation_time"] > 0.1:
		return false
	
	return true

## Get factory status for debugging
func get_factory_status() -> String:
	var stats: Dictionary = get_performance_statistics()
	return "ShipFactory: %d ships created, avg: %.3fs, last: %.3fs" % [
		stats["ships_created"],
		stats["average_creation_time"],
		stats["last_creation_time"]
	]