# Central ship system management coordinating data, physics, visuals, and audio
# Integrates converted TRES data with Godot's scene system
class_name ShipSystemManager
extends Node3D

# Configuration
@export var enable_caching: bool = true
@export var validation_on_use: bool = false
@export var performance_logging: bool = false
@export var memory_limit_mb: int = 512

# System references (set in scene)
@onready var data_manager: ShipDataManager = $ShipDataManager
@onready var weapon_manager: WeaponSystemManager = $WeaponSystemManager
@onready var species_manager: SpeciesManager = $SpeciesManager
@onready var physics_calculator: ShipPhysicsCalculator = $ShipPhysicsCalculator
@onready var visual_system: ShipVisualSystem = $ShipVisualSystem
@onready var audio_system: ShipAudioSystem = $ShipAudioSystem
@onready var resource_manager: WCSResourceManager = $ResourceManager

# Performance monitoring
var system_stats: Dictionary = {
	"ships_loaded": 0,
	"weapons_loaded": 0,
	"species_loaded": 0,
	"data_requests": 0,
	"cache_hits": 0,
	"cache_misses": 0,
	"physics_calculations": 0,
	"validation_errors": 0
}

# Cache for active ship instances
var active_ships: Dictionary = {}
var active_weapons: Dictionary = {}
var ship_categories: Dictionary = {  # Pre-categorized for performance
	"fighters": [],
	"bombers": [],
	"capitals": []
}

# Signal system
signal ship_system_activated(ship_class: String, ship_instance: ShipInstance)
signal weapon_system_activated(weapon_class: String, weapon_instance: WeaponInstance)
signal system_performance_warning(system_name: String, usage_percent: float)
signal resource_load_error(resource_path: String, error_message: String)
signal validation_error(resource_type: String, error_details: Dictionary)

func _ready() -> void:
	"""Initialize ship system manager"""
	setup_system_connections()
	preload_core_systems()
	print("Ship System Manager initialized")

func setup_system_connections() -> void:
	"""Setup signal connections between subsystems"""
	# Data manager connections
	data_manager.resource_load_error.connect(_on_resource_load_error)
	data_manager.validation_error.connect(_on_validation_error)

	# Weapon manager connections
	weapon_manager.weapon_system_error.connect(_on_weapon_system_error)
	weapon_manager.weapon_data_ready.connect(_on_weapon_data_ready)

	# Species manager connections
	species_manager.species_data_error.connect(_on_species_data_error)

	# Physics calculator connections
	physics_calculator.physics_calculation_error.connect(_on_physics_calculation_error)

	# Visual/Audio system connections
	visual_system.visual_system_error.connect(_on_visual_system_error)
	audio_system.audio_system_error.connect(_on_audio_system_error)

func preload_core_systems() -> void:
	"""Preload core systems for improved performance"""
	# Preload critical ship classes
	var critical_ships = ["F-86C Hellcat V", "F-27B Arrow", "KF-227 Sartha"]
	for ship_class in critical_ships:
		get_ship_instance(ship_class, false)  # Preload without creating visual instance

func get_ship_instance(ship_class: String, create_visual_instance: bool = true) -> ShipInstance:
	"""Get or create ship instance with all associated systems"""
	system_stats["data_requests"] += 1

	# Check cache first
	if ship_class in active_ships:
		system_stats["cache_hits"] += 1
		return active_ships[ship_class]

	system_stats["cache_misses"] += 1
	return create_new_ship_instance(ship_class, create_visual_instance)

func create_new_ship_instance(ship_class: String, create_visual_instance: bool) -> ShipInstance:
	"""Create new ship instance with all systems integrated"""
	print("Creating new ship instance: %s" % ship_class)

	# Load ship stats from converted TRES data
	var ship_stats = data_manager.get_ship_stats(ship_class)
	if not ship_stats:
		send_error("Failed to load ship stats: %s" % ship_class)
		return null

	# Validate ship data if enabled
	if validation_on_use and not validate_ship_data(ship_stats):
		return null

	# Create ship instance container
	var ship_instance = ShipInstance.new()
	ship_instance.ship_class = ship_class
	ship_instance.ship_stats = ship_stats
	ship_instance.instance_id = generate_unique_id()

	# Initialize physics system
	ship_instance.physics_data = physics_calculator.create_physics_data(ship_stats)

	# Initialize weapon systems
	ship_instance.weapon_systems = weapon_manager.create_weapon_systems(ship_stats)

	# Initialize visual system if requested
	if create_visual_instance:
		ship_instance.visual_instance = visual_system.create_ship_visuals(ship_stats)

	# Initialize audio systems
	ship_instance.audio_data = audio_system.create_audio_data(ship_stats)

	# Cache the instance
	active_ships[ship_class] = ship_instance
	categorize_ship(ship_instance)  # For optimized access patterns

	system_stats["ships_loaded"] += 1
	ship_system_activated.emit(ship_class, ship_instance)

	return ship_instance

func validate_ship_data(ship_stats: ShipStats) -> bool:
	"""Validate ship data integrity"""
	if not ship_stats.validate():
		system_stats["validation_errors"] += 1
		var validation_summary = ship_stats.get_validation_summary()
		validation_error.emit("ship_stats", validation_summary)
		return false
	return true

func get_weapon_instance(weapon_class: String) -> WeaponInstance:
	"""Get or create weapon instance"""
	if weapon_class in active_weapons:
		return active_weapons[weapon_class]

	return create_new_weapon_instance(weapon_class)

func create_new_weapon_instance(weapon_class: String) -> WeaponInstance:
	"""Create new weapon instance"""
	var weapon_data = weapon_manager.get_weapon_data(weapon_class)
	if not weapon_data:
		send_error("Failed to load weapon data: %s" % weapon_class)
		return null

	var weapon_instance = WeaponInstance.new()
	weapon_instance.weapon_class = weapon_class
	weapon_instance.weapon_data = weapon_data
	weapon_instance.instance_id = generate_unique_id()

	# Initialize all weapon systems
	weapon_instance.physics_data = weapon_manager.create_weapon_physics(weapon_data)
	weapon_instance.visual_effects = visual_system.create_weapon_visuals(weapon_data)
	weapon_instance.audio_effects = audio_system.create_weapon_audio(weapon_data)

	active_weapons[weapon_class] = weapon_instance
	system_stats["weapons_loaded"] += 1
	weapon_system_activated.emit(weapon_class, weapon_instance)

	return weapon_instance

func categorize_ship(ship_instance: ShipInstance) -> void:
	"""Categorize ship for optimized access"""
	var category = "fighters"  # Default

	if ship_instance.ship_stats:
		if ship_instance.ship_stats.ship_role == 1:  # Bomber
			category = "bombers"
		elif ship_instance.ship_stats.ship_role in [2, 3]:  # Capital/Support
			category = "capitals"

	if category not in ship_categories:
		ship_categories[category] = []

	ship_categories[category].append(ship_instance.instance_id)

func get_ships_by_category(category: String) -> Array[ShipInstance]:
	"""Get all ships in a specific category"""
	var ship_ids = ship_categories.get(category, [])
	var ships = []
	for ship_id in ship_ids:
		for ship_instance in active_ships.values():
			if ship_instance.instance_id == ship_id:
				ships.append(ship_instance)
				break
	return ships

func apply_damage_to_ship(ship_instance: ShipInstance, damage_type: String, damage_amount: float, impact_point: Vector3) -> Dictionary:
	"""Apply damage to ship with physics-based feedback"""
	system_stats["physics_calculations"] += 1

	# Calculate actual damage based on ship properties
	var damage_result = physics_calculator.calculate_damage(
		ship_instance.ship_stats, damage_type, damage_amount, impact_point
	)

	# Update ship instance with new damage state
	ship_instance.current_hitpoints -= damage_result.actual_damage
	ship_instance.damage_feedback.push_back(damage_result)

	# Generate visual feedback
	if damage_result.actual_damage > 0:
		visual_system.show_damage_effect(ship_instance, damage_result)
		audio_system.play_damage_sound(ship_instance, damage_result)

	return damage_result

func update_ship_physics(ship_instance: ShipInstance, delta: float, input_state: Dictionary) -> void:
	"""Update ship physics based on input and TRES data"""
	system_stats["physics_calculations"] += 1

	# Calculate movement forces based on TRES weapon stats
	var physics_update = physics_calculator.update_ship_physics(
		ship_instance.ship_stats, ship_instance.physics_data, delta, input_state
	)

	ship_instance.physics_data = physics_update
	ship_instance.current_velocity = physics_update.current_velocity
	ship_instance.current_rotation = physics_update.current_rotation

	# Update visual representation
	if ship_instance.visual_instance:
		visual_system.update_ship_visuals(ship_instance, physics_update)

func simulate_weapon_fire(weapon_instance: WeaponInstance, origin_position: Vector3, target_info: Dictionary) -> Dictionary:
	"""Simulate weapon fire with full system integration"""
	var simulation_result = weapon_manager.simulate_weapon_fire(
		weapon_instance.weapon_data, origin_position, target_info
	)

	# Visual effects
	visual_system.show_muzzle_flash(weapon_instance, origin_position)
	visual_system.create_projectiles_from_simulation(simulation_result)

	# Audio effects
	audio_system.play_weapon_fire_sound(weapon_instance, simulation_result)

	return simulation_result

func optimize_memory_usage() -> void:
	"""Optimize memory usage by cleaning up unused resources"""
	var current_usage = calculate_current_memory_usage()
	var usage_percent = (current_usage / (memory_limit_mb * 1024 * 1024)) * 100

	if usage_percent > 80:  # 80% threshold for optimization
		perform_memory_cleanup()

	if usage_percent > 90:  # Warning level
		system_performance_warning.emit("ship_systems", usage_percent)

func calculate_current_memory_usage() -> int:
	"""Calculate current memory usage across all subsystems"""
	var total_usage = 0

	# Count active instances
	total_usage += active_ships.size() * 1024 * 50     # ~50MB per ship instance
	total_usage += active_weapons.size() * 1024 * 10   # ~10MB per weapon instance
	return total_usage

func perform_memory_cleanup() -> void:
	"""Clean up memory by removing unused/hidden instances"""
	var cleanup_count = 0

	# Remove ships not actively needed
	for ship_class in active_ships.keys():
		if should_cleanup_instance(active_ships[ship_class]):
			cleanup_ship_instance(ship_class)
			cleanup_count += 1

	# Remove unused weapons
	for weapon_class in active_weapons.keys():
		if should_cleanup_instance(active_weapons[weapon_class]):
			cleanup_weapon_instance(weapon_class)
			cleanup_count += 1

	if performance_logging:
		print("Memory cleanup completed: %d instances removed" % cleanup_count)

func should_cleanup_instance(instance) -> bool:
	"""Determine if an instance should be cleaned up"""
	# Implementation based on instance age, visibility, and usage patterns
	var timeout_threshold = 30.0  # 30 seconds unused
	return Time.get_unix_time_from_system() - instance.last_access_time > timeout_threshold

func cleanup_ship_instance(ship_class: String) -> void:
	"""Clean up specific ship instance"""
	if ship_class in active_ships:
		var ship_instance = active_ships[ship_class]

		# Remove from categories
		for category in ship_categories.keys():
			if ship_instance.instance_id in ship_categories[category]:
				var index = ship_categories[category].find(ship_instance.instance_id)
				if index != -1:
					ship_categories[category].remove_at(index)

		# Free visual and audio resources
		if ship_instance.visual_instance:
			ship_instance.visual_instance.queue_free()

		# Remove from cache
		active_ships.erase(ship_class)

func cleanup_weapon_instance(weapon_class: String) -> void:
	"""Clean up specific weapon instance"""
	if weapon_class in active_weapons:
		var weapon_instance = active_weapons[weapon_class]

		# Free visual and audio resources
		if weapon_instance.visual_effects:
			for effect in weapon_instance.visual_effects:
				effect.queue_free()

		# Remove from cache
		active_weapons.erase(weapon_class)

# Event handlers
func _on_resource_load_error(resource_path: String, error_message: String) -> void:
	resource_load_error.emit(resource_path, error_message)

func _on_validation_error(resource_type: String, error_details: Dictionary) -> void:
	validation_error.emit(resource_type, error_details)

func _on_weapon_system_error(weapon_class: String, error_message: String) -> void:
	send_error("Weapon system error [%s]: %s" % [weapon_class, error_message])

func _on_species_data_error(species_name: String, error_message: String) -> void:
	send_error("Species data error [%s]: %s" % [species_name, error_message])

func _on_physics_calculation_error(calculation_type: String, error_message: String) -> void:
	send_error("Physics calculation error [%s]: %s" % [calculation_type, error_message])

func _on_visual_system_error(system_name: String, error_message: String) -> void:
	send_error("Visual system error [%s]: %s" % [system_name, error_message])

func _on_audio_system_error(system_name: String, error_message: String) -> void:
	send_error("Audio system error [%s]: %s" % [system_name, error_message])

func _on_weapon_data_ready(weapon_class: String, weapon_data: WeaponData) -> void:
	# Create weapon instance when data is ready
	create_new_weapon_instance(weapon_class)

friend func generate_unique_id() -> String:
	"""Generate unique instance ID"""
	return "ship_%s_%d" % [str(Time.get_unix_time_from_system()), randi()]

friend func send_error(message: String) -> void:
	"""Send system error message"""
	push_error("[Ship System Manager] %s" % message)

func get_system_statistics() -> Dictionary:
	"""Get comprehensive system statistics"""
	return {
		"performance": system_stats.duplicate(true),
		"memory_usage": calculate_current_memory_usage(),
		"active_instances": {
			"ships": active_ships.size(),
			"weapons": active_weapons.size()
		},
		"categorized_ships": {
			category: ship_categories[category].size() for category in ship_categories.keys()
		},
		"subsystem_health": get_subsystem_health_status()
	}

func get_subsystem_health_status() -> Dictionary:
	"""Get health status of all subsystems"""
	return {
		"data_manager": data_manager != null and is_instance_valid(data_manager),
		"weapon_manager": weapon_manager != null and is_instance_valid(weapon_manager),
		"species_manager": species_manager != null and is_instance_valid(species_manager),
		"physics_calculator": physics_calculator != null and is_instance_valid(physics_calculator),
		"visual_system": visual_system != null and is_instance_valid(visual_system),
		"audio_system": audio_system != null and is_instance_valid(audio_system)
	}

func _process(delta: float) -> void:
	"""Periodic system maintenance"""
	# Optimize memory usage periodically
	optimize_memory_usage()

func _input(event: InputEvent) -> void:
	"""Handle system-wide input events"""
	if event.is_action_pressed("debug_memory_info"):
		print_debug_info()

func print_debug_info() -> void:
	"""Print comprehensive debug information"""
	var stats = get_system_statistics()
	print("=== Ship System Manager Debug Info ===")
	print("Memory Usage: %.2f MB" % (stats["memory_usage"] / (1024.0 * 1024.0)))
	print("Active Ship Instances: %d" % stats["active_instances"]["ships"])
	print("Active Weapon Instances: %d" % stats["active_instances"]["weapons"])
	print("Cache Hit Rate: %.2f%%" % ((system_stats["cache_hits"] / max(system_stats["data_requests"], 1)) * 100))
	print("Subsystem Health:")
	for subsystem, health in stats["subsystem_health"].items():
		print("  %s: %s" % [subsystem.capitalize(), "OK" if health else "FAILED"])
	print("=====================================")

func _exit_tree() -> void:
	"""Cleanup ship system manager"""
	# Cleanup all active instances
	for ship_instance in active_ships.values():
		if ship_instance.visual_instance:
			ship_instance.visual_instance.queue_free()

	for weapon_instance in active_weapons.values():
		if weapon_instance.visual_effects:
			for effect in weapon_instance.visual_effects:
				effect.queue_free()

	print("Ship System Manager shutdown completed")