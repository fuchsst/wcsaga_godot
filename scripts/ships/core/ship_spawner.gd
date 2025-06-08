class_name ShipSpawner
extends Node3D

## Scene-based ship spawner for WCS-Godot conversion
## Handles ship spawning using Godot scenes and .tres resource files
## Integrates with ship factory and registry for efficient ship creation

signal ship_spawned(ship: BaseShip)
signal ship_despawned(ship: BaseShip)
signal spawn_failed(reason: String)

# Ship spawning configuration
@export var auto_spawn_on_ready: bool = false
@export var default_ship_class: String = "GTF Apollo"
@export var default_ship_template: String = ""
@export var spawn_position: Vector3 = Vector3.ZERO
@export var spawn_rotation: Vector3 = Vector3.ZERO
@export var spawn_team: int = 1

# Scene-based configuration
@export_group("Scene Configuration")
@export var ship_scene_template: PackedScene  # Base ship scene template
@export var use_custom_scene: bool = false
@export var custom_ship_scenes: Dictionary = {}  # Ship class -> PackedScene

# Spawning behavior
@export_group("Spawning Behavior")
@export var max_spawned_ships: int = 100
@export var spawn_interval: float = 1.0
@export var auto_despawn_distance: float = 5000.0
@export var use_object_pooling: bool = true

# Ship factory and registry
var ship_factory: ShipFactory
var ship_registry: ShipRegistry

# Spawned ship tracking
var spawned_ships: Array[BaseShip] = []
var ship_pool: Array[BaseShip] = []
var next_spawn_time: float = 0.0

# Performance monitoring
var ships_spawned_total: int = 0
var ships_despawned_total: int = 0
var spawn_failures: int = 0

func _ready() -> void:
	# Initialize factory and registry
	ship_factory = ShipFactory.new()
	ship_registry = ShipRegistry.new()
	
	# Setup default spawn position
	if spawn_position == Vector3.ZERO:
		spawn_position = global_position
	
	# Auto-spawn if enabled
	if auto_spawn_on_ready and not default_ship_class.is_empty():
		spawn_ship_by_name(default_ship_class)

func _process(delta: float) -> void:
	# Auto-despawn distant ships
	if auto_despawn_distance > 0.0:
		_check_auto_despawn()

## Spawn ship from .tres resource file
func spawn_ship_from_resource(resource_path: String, spawn_pos: Vector3 = Vector3.ZERO, ship_name: String = "") -> BaseShip:
	var resource: Resource = load(resource_path)
	
	if resource is ShipClass:
		return spawn_ship_from_class(resource as ShipClass, spawn_pos, ship_name)
	elif resource is ShipTemplate:
		return spawn_ship_from_template(resource as ShipTemplate, spawn_pos, ship_name)
	else:
		push_error("ShipSpawner: Resource is not a ShipClass or ShipTemplate: " + resource_path)
		spawn_failed.emit("Invalid resource type")
		spawn_failures += 1
		return null

## Spawn ship from ShipClass resource
func spawn_ship_from_class(ship_class: ShipClass, spawn_pos: Vector3 = Vector3.ZERO, ship_name: String = "") -> BaseShip:
	if ship_class == null:
		push_error("ShipSpawner: ShipClass is null")
		spawn_failed.emit("Null ship class")
		spawn_failures += 1
		return null
	
	# Check spawn limits
	if spawned_ships.size() >= max_spawned_ships:
		push_error("ShipSpawner: Max spawned ships limit reached (%d)" % max_spawned_ships)
		spawn_failed.emit("Spawn limit reached")
		spawn_failures += 1
		return null
	
	var ship: BaseShip = null
	
	# Try to get from pool first
	if use_object_pooling and ship_pool.size() > 0:
		ship = ship_pool.pop_back()
		_reinitialize_pooled_ship(ship, ship_class, ship_name)
	else:
		# Create new ship using factory
		ship = ship_factory.create_ship_from_class(ship_class, ship_name)
	
	if ship == null:
		push_error("ShipSpawner: Failed to create ship from class: " + ship_class.class_name)
		spawn_failed.emit("Ship creation failed")
		spawn_failures += 1
		return null
	
	# Configure and position ship
	_configure_spawned_ship(ship, spawn_pos)
	
	# Add to scene and tracking
	add_child(ship)
	spawned_ships.append(ship)
	ships_spawned_total += 1
	
	ship_spawned.emit(ship)
	print("ShipSpawner: Spawned ship '%s' from class '%s'" % [ship.ship_name, ship_class.class_name])
	
	return ship

## Spawn ship from ShipTemplate resource
func spawn_ship_from_template(template: ShipTemplate, spawn_pos: Vector3 = Vector3.ZERO, ship_name: String = "") -> BaseShip:
	if template == null:
		push_error("ShipSpawner: ShipTemplate is null")
		spawn_failed.emit("Null ship template")
		spawn_failures += 1
		return null
	
	# Check spawn limits
	if spawned_ships.size() >= max_spawned_ships:
		push_error("ShipSpawner: Max spawned ships limit reached (%d)" % max_spawned_ships)
		spawn_failed.emit("Spawn limit reached")
		spawn_failures += 1
		return null
	
	# Create ship using factory
	var ship: BaseShip = ship_factory.create_ship_from_template(template, ship_name)
	
	if ship == null:
		push_error("ShipSpawner: Failed to create ship from template: " + template.get_full_name())
		spawn_failed.emit("Ship creation failed")
		spawn_failures += 1
		return null
	
	# Configure and position ship
	_configure_spawned_ship(ship, spawn_pos)
	
	# Add to scene and tracking
	add_child(ship)
	spawned_ships.append(ship)
	ships_spawned_total += 1
	
	ship_spawned.emit(ship)
	print("ShipSpawner: Spawned ship '%s' from template '%s'" % [ship.ship_name, template.get_full_name()])
	
	return ship

## Spawn ship by name from registry
func spawn_ship_by_name(ship_name: String, variant_suffix: String = "", spawn_pos: Vector3 = Vector3.ZERO) -> BaseShip:
	# Try template first (for variants)
	if not variant_suffix.is_empty():
		var full_name: String = ship_name + "#" + variant_suffix
		var template: ShipTemplate = ship_registry.get_ship_template(full_name)
		if template != null:
			return spawn_ship_from_template(template, spawn_pos)
	
	# Fall back to ship class
	var ship_class: ShipClass = ship_registry.get_ship_class(ship_name)
	if ship_class != null:
		return spawn_ship_from_class(ship_class, spawn_pos)
	
	push_error("ShipSpawner: Cannot find ship class or template: " + ship_name)
	spawn_failed.emit("Ship not found in registry")
	spawn_failures += 1
	return null

## Spawn ship using custom scene
func spawn_ship_from_scene(scene: PackedScene, ship_class: ShipClass, spawn_pos: Vector3 = Vector3.ZERO) -> BaseShip:
	if scene == null or ship_class == null:
		push_error("ShipSpawner: Scene or ship class is null")
		spawn_failed.emit("Null scene or ship class")
		spawn_failures += 1
		return null
	
	# Check spawn limits
	if spawned_ships.size() >= max_spawned_ships:
		push_error("ShipSpawner: Max spawned ships limit reached (%d)" % max_spawned_ships)
		spawn_failed.emit("Spawn limit reached")
		spawn_failures += 1
		return null
	
	# Instantiate scene
	var ship_instance: Node = scene.instantiate()
	if not ship_instance is BaseShip:
		push_error("ShipSpawner: Scene does not contain a BaseShip")
		ship_instance.queue_free()
		spawn_failed.emit("Invalid ship scene")
		spawn_failures += 1
		return null
	
	var ship: BaseShip = ship_instance as BaseShip
	
	# Initialize ship with class data
	if not ship.initialize_ship(ship_class, ship_class.class_name):
		push_error("ShipSpawner: Failed to initialize ship from scene")
		ship.queue_free()
		spawn_failed.emit("Ship initialization failed")
		spawn_failures += 1
		return null
	
	# Configure and position ship
	_configure_spawned_ship(ship, spawn_pos)
	
	# Add to scene and tracking
	add_child(ship)
	spawned_ships.append(ship)
	ships_spawned_total += 1
	
	ship_spawned.emit(ship)
	print("ShipSpawner: Spawned ship '%s' from custom scene" % ship.ship_name)
	
	return ship

## Spawn multiple ships in formation
func spawn_ship_formation(ship_configs: Array[Dictionary], formation_center: Vector3 = Vector3.ZERO) -> Array[BaseShip]:
	var ships: Array[BaseShip] = []
	
	for i in range(ship_configs.size()):
		var config: Dictionary = ship_configs[i]
		var ship: BaseShip = null
		
		# Determine spawn method
		if config.has("resource_path"):
			ship = spawn_ship_from_resource(config["resource_path"], Vector3.ZERO, config.get("name", ""))
		elif config.has("ship_class"):
			ship = spawn_ship_by_name(config["ship_class"], config.get("variant", ""), Vector3.ZERO)
		elif config.has("template"):
			var template: ShipTemplate = load(config["template"]) as ShipTemplate
			ship = spawn_ship_from_template(template, Vector3.ZERO, config.get("name", ""))
		
		if ship != null:
			# Apply formation positioning
			if config.has("offset"):
				ship.global_position = formation_center + config["offset"]
			else:
				ship.global_position = formation_center + Vector3(i * 50.0, 0, 0)  # Default spacing
			
			# Apply formation rotation
			if config.has("rotation"):
				ship.global_rotation = config["rotation"]
			
			ships.append(ship)
	
	print("ShipSpawner: Spawned formation of %d ships" % ships.size())
	return ships

## Despawn specific ship
func despawn_ship(ship: BaseShip, use_pool: bool = true) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	
	# Remove from tracking
	var index: int = spawned_ships.find(ship)
	if index != -1:
		spawned_ships.remove_at(index)
	
	# Handle pooling or destruction
	if use_object_pooling and use_pool and ship_pool.size() < 50:  # Pool size limit
		_return_to_pool(ship)
	else:
		ship.queue_free()
	
	ships_despawned_total += 1
	ship_despawned.emit(ship)
	print("ShipSpawner: Despawned ship '%s'" % ship.ship_name)

## Despawn all ships
func despawn_all_ships(use_pool: bool = true) -> void:
	var ships_to_despawn: Array[BaseShip] = spawned_ships.duplicate()
	
	for ship in ships_to_despawn:
		despawn_ship(ship, use_pool)
	
	print("ShipSpawner: Despawned all %d ships" % ships_to_despawn.size())

## Configure spawned ship properties
func _configure_spawned_ship(ship: BaseShip, spawn_pos: Vector3) -> void:
	# Set position
	var final_position: Vector3 = spawn_pos if spawn_pos != Vector3.ZERO else spawn_position
	ship.global_position = final_position
	
	# Set rotation
	ship.global_rotation = spawn_rotation
	
	# Set team
	ship.team = spawn_team
	
	# Connect to ship events
	ship.ship_destroyed.connect(_on_ship_destroyed)

## Reinitialize pooled ship
func _reinitialize_pooled_ship(ship: BaseShip, ship_class: ShipClass, ship_name: String) -> void:
	# Reinitialize with new class
	ship.initialize_ship(ship_class, ship_name)
	
	# Reset state
	ship.visible = true
	ship.process_mode = Node.PROCESS_MODE_INHERIT

## Return ship to pool
func _return_to_pool(ship: BaseShip) -> void:
	# Remove from scene tree but keep in memory
	if ship.get_parent() == self:
		remove_child(ship)
	
	# Reset ship state
	ship.visible = false
	ship.process_mode = Node.PROCESS_MODE_DISABLED
	ship.global_position = Vector3.ZERO
	
	# Add to pool
	ship_pool.append(ship)

## Check for auto-despawn of distant ships
func _check_auto_despawn() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	
	var camera_pos: Vector3 = camera.global_position
	var ships_to_despawn: Array[BaseShip] = []
	
	for ship in spawned_ships:
		if is_instance_valid(ship):
			var distance: float = camera_pos.distance_to(ship.global_position)
			if distance > auto_despawn_distance:
				ships_to_despawn.append(ship)
	
	for ship in ships_to_despawn:
		despawn_ship(ship)

## Handle ship destruction event
func _on_ship_destroyed(destroyed_ship: BaseShip) -> void:
	# Automatically despawn destroyed ships
	despawn_ship(destroyed_ship, false)  # Don't pool destroyed ships

## Get spawner statistics
func get_spawner_statistics() -> Dictionary:
	return {
		"ships_spawned_total": ships_spawned_total,
		"ships_despawned_total": ships_despawned_total,
		"spawn_failures": spawn_failures,
		"currently_spawned": spawned_ships.size(),
		"pool_size": ship_pool.size(),
		"max_spawned_ships": max_spawned_ships
	}

## Get spawner status for debugging
func get_spawner_status() -> String:
	var stats: Dictionary = get_spawner_statistics()
	return "ShipSpawner: %d/%d spawned, %d pooled, %d total created" % [
		stats["currently_spawned"],
		stats["max_spawned_ships"],
		stats["pool_size"],
		stats["ships_spawned_total"]
	]