class_name SubsystemManager
extends Node

## Subsystem management coordinator for ship subsystem lifecycle and state
## Handles subsystem creation, damage allocation, performance coordination
## Implements WCS-authentic subsystem behavior and ship integration

# Required references
const Subsystem = preload("res://scripts/ships/subsystems/subsystem.gd")
const SubsystemDefinition = preload("res://addons/wcs_asset_core/resources/ship/subsystem_definition.gd")
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Signals for subsystem management (SHIP-002 AC7)
signal subsystems_initialized()
signal subsystem_performance_changed(subsystem_name: String, performance: float)
signal critical_subsystem_destroyed(subsystem_name: String)
signal subsystem_repaired(subsystem_name: String)
signal turret_target_acquired(turret_name: String, target: Node3D)

# Ship reference
var parent_ship: BaseShip

# Subsystem tracking
var subsystems: Dictionary = {}  # String -> Subsystem
var subsystem_list: Array[Subsystem] = []
var subsystems_by_type: Dictionary = {}  # SubsystemTypes.Type -> Array[Subsystem]

# Performance tracking (SHIP-002 AC2, AC3)
var overall_engine_performance: float = 1.0
var overall_weapon_performance: float = 1.0
var overall_shield_performance: float = 1.0
var overall_sensor_performance: float = 1.0

# Damage allocation state (SHIP-002 AC4)
var damage_allocation_enabled: bool = true
var last_damage_frame: int = 0

# Repair coordination (SHIP-002 AC6)
var repair_queue: Array[Subsystem] = []
var max_concurrent_repairs: int = 2
var active_repairs: int = 0

# SEXP integration state (SHIP-002 AC7)
var sexp_query_cache: Dictionary = {}
var sexp_cache_expiry: float = 0.0

func _init() -> void:
	name = "SubsystemManager"

func _ready() -> void:
	set_physics_process(true)  # For repair coordination and performance updates

## Initialize subsystem manager with ship reference (SHIP-002 AC1)
func initialize_manager(ship: BaseShip) -> bool:
	"""Initialize subsystem manager with ship reference.
	
	Args:
		ship: Parent ship reference
		
	Returns:
		true if initialization successful
	"""
	if not ship:
		push_error("SubsystemManager: Cannot initialize without ship reference")
		return false
	
	parent_ship = ship
	_setup_signal_connections()
	
	return true

## Setup signal connections for subsystem communication
func _setup_signal_connections() -> void:
	"""Connect signals for subsystem state management."""
	# Connect to parent ship signals if available
	if parent_ship:
		# Ship damage events will trigger subsystem damage allocation
		parent_ship.collision_detected.connect(_on_ship_collision_detected)

## Physics processing for repair coordination and performance updates
func _physics_process(delta: float) -> void:
	# Update performance tracking
	_update_overall_performance()
	
	# Process repair queue
	_process_repair_queue(delta)
	
	# Clear SEXP cache if expired
	if Time.get_ticks_msec() * 0.001 > sexp_cache_expiry:
		sexp_query_cache.clear()

## Create subsystems from ship class definitions (SHIP-002 AC1)
func create_subsystems_from_ship_class(ship_class: ShipClass) -> bool:
	"""Create subsystems from ship class subsystem definitions.
	
	Args:
		ship_class: Ship class resource with subsystem definitions
		
	Returns:
		true if subsystems created successfully
	"""
	if not ship_class or not parent_ship:
		push_error("SubsystemManager: Invalid ship class or parent ship")
		return false
	
	# Clear existing subsystems
	_clear_all_subsystems()
	
	# Create subsystems from ship class (will be expanded when ship class has subsystems)
	# For now, create default subsystems based on ship type
	_create_default_subsystems_for_ship_type(ship_class.ship_type)
	
	# Initialize subsystem performance tracking
	_initialize_performance_tracking()
	
	subsystems_initialized.emit()
	return true

## Create default subsystems for ship type
func _create_default_subsystems_for_ship_type(ship_type: ShipTypes.Type) -> void:
	"""Create default subsystem configuration based on ship type."""
	var subsystem_definitions: Array[SubsystemDefinition] = []
	
	# All ships have engines
	subsystem_definitions.append(SubsystemDefinition.create_default_engine())
	
	# All ships have weapons
	subsystem_definitions.append(SubsystemDefinition.create_default_weapons())
	
	# All ships have radar
	subsystem_definitions.append(SubsystemDefinition.create_default_radar())
	
	# Add ship-type specific subsystems
	match ship_type:
		ShipTypes.Type.FIGHTER:
			# Fighters are simple, just basic subsystems
			pass
		ShipTypes.Type.BOMBER:
			# Bombers get additional weapon subsystems
			var heavy_weapons := SubsystemDefinition.create_default_weapons()
			heavy_weapons.subsystem_name = "Heavy Weapons"
			heavy_weapons.max_hits = 40.0
			subsystem_definitions.append(heavy_weapons)
		ShipTypes.Type.CRUISER, ShipTypes.Type.CAPITAL, ShipTypes.Type.SUPER_CAPITAL:
			# Capital ships get turrets and additional systems
			var turret_count: int = 2 if ship_type == ShipTypes.Type.CRUISER else 4
			for i in range(turret_count):
				var turret := SubsystemDefinition.create_default_turret("Turret_%d" % (i + 1))
				turret.position = Vector3(randf_range(-10, 10), randf_range(-5, 5), randf_range(-15, 15))
				subsystem_definitions.append(turret)
			
			# Additional systems for capitals
			var navigation := SubsystemDefinition.new()
			navigation.subsystem_name = "Navigation"
			navigation.subsystem_type = SubsystemTypes.Type.NAVIGATION
			navigation.max_hits = 20.0
			subsystem_definitions.append(navigation)
			
			var communication := SubsystemDefinition.new()
			communication.subsystem_name = "Communication"
			communication.subsystem_type = SubsystemTypes.Type.COMMUNICATION
			communication.max_hits = 10.0
			subsystem_definitions.append(communication)
	
	# Create subsystem instances
	for definition in subsystem_definitions:
		_create_subsystem_instance(definition)

## Create individual subsystem instance
func _create_subsystem_instance(definition: SubsystemDefinition) -> Subsystem:
	"""Create and configure subsystem instance from definition."""
	var subsystem := Subsystem.new()
	add_child(subsystem)
	
	# Initialize subsystem
	if not subsystem.initialize_subsystem(definition, parent_ship, self):
		subsystem.queue_free()
		return null
	
	# Connect subsystem signals
	_connect_subsystem_signals(subsystem)
	
	# Register subsystem
	_register_subsystem(subsystem)
	
	return subsystem

## Connect subsystem signals for state management
func _connect_subsystem_signals(subsystem: Subsystem) -> void:
	"""Connect subsystem signals to manager handlers."""
	subsystem.subsystem_damaged.connect(_on_subsystem_damaged)
	subsystem.subsystem_destroyed.connect(_on_subsystem_destroyed)
	subsystem.subsystem_repaired.connect(_on_subsystem_repaired)
	subsystem.performance_changed.connect(_on_subsystem_performance_changed)
	subsystem.target_acquired.connect(_on_turret_target_acquired)
	subsystem.target_lost.connect(_on_turret_target_lost)

## Register subsystem in tracking collections
func _register_subsystem(subsystem: Subsystem) -> void:
	"""Register subsystem in manager collections."""
	var subsystem_name: String = subsystem.name
	var subsystem_type: SubsystemTypes.Type = subsystem.subsystem_definition.subsystem_type
	
	# Register in main collections
	subsystems[subsystem_name] = subsystem
	subsystem_list.append(subsystem)
	
	# Register by type
	if not subsystems_by_type.has(subsystem_type):
		subsystems_by_type[subsystem_type] = []
	subsystems_by_type[subsystem_type].append(subsystem)

## Clear all subsystems
func _clear_all_subsystems() -> void:
	"""Remove all current subsystems."""
	for subsystem in subsystem_list:
		if is_instance_valid(subsystem):
			subsystem.queue_free()
	
	subsystems.clear()
	subsystem_list.clear()
	subsystems_by_type.clear()
	repair_queue.clear()
	active_repairs = 0

## Initialize performance tracking
func _initialize_performance_tracking() -> void:
	"""Initialize overall performance tracking."""
	overall_engine_performance = 1.0
	overall_weapon_performance = 1.0
	overall_shield_performance = 1.0
	overall_sensor_performance = 1.0

## Apply proximity-based damage allocation (SHIP-002 AC4)
func allocate_damage_to_subsystems(total_damage: float, impact_position: Vector3) -> float:
	"""Allocate damage to subsystems based on proximity to impact point.
	
	Args:
		total_damage: Total damage to allocate
		impact_position: World position of damage impact
		
	Returns:
		Total damage actually applied to subsystems
	"""
	if not damage_allocation_enabled or subsystem_list.is_empty():
		return 0.0
	
	var total_applied: float = 0.0
	var damage_per_subsystem: float = total_damage / max(1, subsystem_list.size())
	
	# Sort subsystems by distance to impact
	var sorted_subsystems: Array[Subsystem] = subsystem_list.duplicate()
	sorted_subsystems.sort_custom(func(a: Subsystem, b: Subsystem) -> bool:
		var dist_a: float = a.global_position.distance_to(impact_position)
		var dist_b: float = b.global_position.distance_to(impact_position)
		return dist_a < dist_b
	)
	
	# Apply damage with proximity falloff
	for i in range(sorted_subsystems.size()):
		var subsystem: Subsystem = sorted_subsystems[i]
		if not subsystem.is_functional:
			continue
		
		# Apply more damage to closer subsystems
		var distance_factor: float = 1.0 - (float(i) / float(sorted_subsystems.size()))
		var subsystem_damage: float = damage_per_subsystem * distance_factor
		
		if subsystem_damage > 0.1:  # Only apply meaningful damage
			var applied: float = subsystem.apply_damage(subsystem_damage, impact_position)
			total_applied += applied
	
	return total_applied

## Update overall performance tracking (SHIP-002 AC2, AC3)
func _update_overall_performance() -> void:
	"""Update overall performance metrics from subsystem states."""
	var engine_subsystems: Array[Subsystem] = get_subsystems_by_type(SubsystemTypes.Type.ENGINE)
	var weapon_subsystems: Array[Subsystem] = get_subsystems_by_type(SubsystemTypes.Type.WEAPONS)
	var sensor_subsystems: Array[Subsystem] = get_subsystems_by_type(SubsystemTypes.Type.RADAR)
	sensor_subsystems.append_array(get_subsystems_by_type(SubsystemTypes.Type.SENSORS))
	
	# Calculate average performance for each category
	overall_engine_performance = _calculate_average_performance(engine_subsystems)
	overall_weapon_performance = _calculate_average_performance(weapon_subsystems)
	overall_sensor_performance = _calculate_average_performance(sensor_subsystems)
	
	# Shield performance affected by sensors and dedicated shield subsystems
	overall_shield_performance = overall_sensor_performance
	
	# Apply performance to parent ship (SHIP-002 AC2)
	if parent_ship:
		parent_ship.engine_performance = overall_engine_performance
		parent_ship.weapon_performance = overall_weapon_performance
		parent_ship.shield_performance = overall_shield_performance

## Calculate average performance for subsystem group
func _calculate_average_performance(subsystems_group: Array[Subsystem]) -> float:
	"""Calculate average performance for a group of subsystems."""
	if subsystems_group.is_empty():
		return 1.0
	
	var total_performance: float = 0.0
	var functional_count: int = 0
	
	for subsystem in subsystems_group:
		if subsystem.is_functional:
			total_performance += subsystem.performance_modifier
			functional_count += 1
	
	if functional_count == 0:
		return 0.0
	
	return total_performance / functional_count

## Process repair queue (SHIP-002 AC6)
func _process_repair_queue(delta: float) -> void:
	"""Process subsystem repair queue with priority handling."""
	# Remove completed repairs from active count
	active_repairs = 0
	for subsystem in subsystem_list:
		if subsystem.is_repairing:
			active_repairs += 1
	
	# Start new repairs if below maximum
	while active_repairs < max_concurrent_repairs and not repair_queue.is_empty():
		var next_repair: Subsystem = repair_queue.pop_front()
		if is_instance_valid(next_repair) and next_repair.current_hits < next_repair.max_hits:
			if next_repair.start_repair():
				active_repairs += 1

## Add subsystem to repair queue (SHIP-002 AC6)
func queue_subsystem_repair(subsystem: Subsystem) -> bool:
	"""Add subsystem to repair queue with priority ordering.
	
	Args:
		subsystem: Subsystem to repair
		
	Returns:
		true if added to queue successfully
	"""
	if not subsystem or subsystem.current_hits >= subsystem.max_hits:
		return false
	
	if subsystem in repair_queue:
		return false  # Already in queue
	
	# Insert based on repair priority
	var inserted: bool = false
	var priority: int = subsystem.subsystem_definition.get_repair_priority()
	
	for i in range(repair_queue.size()):
		var queue_priority: int = repair_queue[i].subsystem_definition.get_repair_priority()
		if priority > queue_priority:
			repair_queue.insert(i, subsystem)
			inserted = true
			break
	
	if not inserted:
		repair_queue.append(subsystem)
	
	return true

## Remove subsystem from repair queue
func remove_subsystem_from_repair_queue(subsystem: Subsystem) -> bool:
	"""Remove subsystem from repair queue.
	
	Args:
		subsystem: Subsystem to remove
		
	Returns:
		true if removed successfully
	"""
	var index: int = repair_queue.find(subsystem)
	if index >= 0:
		repair_queue.remove_at(index)
		return true
	return false

## Get subsystem by name
func get_subsystem_by_name(subsystem_name: String) -> Subsystem:
	"""Get subsystem instance by name."""
	return subsystems.get(subsystem_name)

## Get subsystems by type
func get_subsystems_by_type(subsystem_type: SubsystemTypes.Type) -> Array[Subsystem]:
	"""Get all subsystems of specified type."""
	return subsystems_by_type.get(subsystem_type, [])

## Get all functional subsystems
func get_functional_subsystems() -> Array[Subsystem]:
	"""Get all currently functional subsystems."""
	var functional: Array[Subsystem] = []
	for subsystem in subsystem_list:
		if subsystem.is_functional:
			functional.append(subsystem)
	return functional

## Get all destroyed subsystems
func get_destroyed_subsystems() -> Array[Subsystem]:
	"""Get all destroyed subsystems."""
	var destroyed: Array[Subsystem] = []
	for subsystem in subsystem_list:
		if not subsystem.is_functional:
			destroyed.append(subsystem)
	return destroyed

## SEXP integration methods (SHIP-002 AC7)

## Check if subsystem is functional (SEXP query)
func is_subsystem_functional(subsystem_name: String) -> bool:
	"""SEXP query: Check if named subsystem is functional."""
	var subsystem: Subsystem = get_subsystem_by_name(subsystem_name)
	return subsystem != null and subsystem.is_functional

## Get subsystem health percentage (SEXP query)
func get_subsystem_health(subsystem_name: String) -> float:
	"""SEXP query: Get subsystem health percentage (0-100)."""
	var cache_key: String = "health_" + subsystem_name
	var current_time: float = Time.get_ticks_msec() * 0.001
	
	# Check cache
	if sexp_query_cache.has(cache_key) and current_time < sexp_cache_expiry:
		return sexp_query_cache[cache_key]
	
	# Calculate health
	var subsystem: Subsystem = get_subsystem_by_name(subsystem_name)
	var health: float = 0.0 if not subsystem else subsystem.get_health_percentage()
	
	# Cache result
	sexp_query_cache[cache_key] = health
	sexp_cache_expiry = current_time + 1.0  # Cache for 1 second
	
	return health

## Get subsystem count by type (SEXP query)
func get_subsystem_count_by_type(subsystem_type: SubsystemTypes.Type, functional_only: bool = false) -> int:
	"""SEXP query: Get count of subsystems of specified type."""
	var subsystems_of_type: Array[Subsystem] = get_subsystems_by_type(subsystem_type)
	
	if not functional_only:
		return subsystems_of_type.size()
	
	var functional_count: int = 0
	for subsystem in subsystems_of_type:
		if subsystem.is_functional:
			functional_count += 1
	
	return functional_count

## Check if any critical subsystems are destroyed
func has_critical_subsystem_failure() -> bool:
	"""Check if any critical subsystems are destroyed."""
	for subsystem in subsystem_list:
		if subsystem.subsystem_definition.is_critical and not subsystem.is_functional:
			return true
	return false

## Get overall performance by category
func get_overall_performance(category: String) -> float:
	"""Get overall performance for specified category."""
	match category.to_lower():
		"engine", "engines":
			return overall_engine_performance
		"weapon", "weapons":
			return overall_weapon_performance
		"shield", "shields":
			return overall_shield_performance
		"sensor", "sensors", "radar":
			return overall_sensor_performance
		_:
			return 1.0

## Get comprehensive subsystem status
func get_subsystem_status() -> Dictionary:
	"""Get comprehensive status of all subsystems."""
	var status: Dictionary = {
		"total_subsystems": subsystem_list.size(),
		"functional_subsystems": get_functional_subsystems().size(),
		"destroyed_subsystems": get_destroyed_subsystems().size(),
		"repairing_subsystems": active_repairs,
		"repair_queue_size": repair_queue.size(),
		"overall_performance": {
			"engine": overall_engine_performance,
			"weapon": overall_weapon_performance,
			"shield": overall_shield_performance,
			"sensor": overall_sensor_performance
		},
		"subsystems": {}
	}
	
	# Add individual subsystem status
	for subsystem in subsystem_list:
		status.subsystems[subsystem.name] = subsystem.get_status_info()
	
	return status

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Handle ship collision for damage allocation
func _on_ship_collision_detected(other_object: BaseSpaceObject, collision_info: Dictionary) -> void:
	"""Handle ship collision to trigger subsystem damage allocation."""
	# This will be expanded when damage system is implemented
	# For now, just placeholder for integration
	pass

## Handle subsystem damage events
func _on_subsystem_damaged(subsystem: Subsystem, damage_amount: float) -> void:
	"""Handle subsystem damage events."""
	# Add to repair queue if not already there
	if subsystem.current_hits > 0.0 and subsystem.current_hits < subsystem.max_hits:
		queue_subsystem_repair(subsystem)

## Handle subsystem destruction events
func _on_subsystem_destroyed(subsystem: Subsystem) -> void:
	"""Handle subsystem destruction events."""
	# Remove from repair queue if present
	remove_subsystem_from_repair_queue(subsystem)
	
	# Emit critical failure signal if applicable
	if subsystem.subsystem_definition.is_critical:
		critical_subsystem_destroyed.emit(subsystem.name)

## Handle subsystem repair completion
func _on_subsystem_repaired(subsystem: Subsystem, repair_amount: float) -> void:
	"""Handle subsystem repair events."""
	# Remove from repair queue if fully repaired
	if subsystem.current_hits >= subsystem.max_hits:
		remove_subsystem_from_repair_queue(subsystem)
		subsystem_repaired.emit(subsystem.name)

## Handle subsystem performance changes
func _on_subsystem_performance_changed(subsystem: Subsystem, new_performance: float) -> void:
	"""Handle subsystem performance changes."""
	subsystem_performance_changed.emit(subsystem.name, new_performance)

## Handle turret target acquisition
func _on_turret_target_acquired(subsystem: Subsystem, target: Node3D) -> void:
	"""Handle turret target acquisition events."""
	turret_target_acquired.emit(subsystem.name, target)

## Handle turret target loss
func _on_turret_target_lost(subsystem: Subsystem) -> void:
	"""Handle turret target loss events."""
	# Signal could be added if needed for turret coordination

## Debug information
func debug_info() -> String:
	var info: String = "[SubsystemMgr: %d/%d functional, " % [get_functional_subsystems().size(), subsystem_list.size()]
	info += "Perf(E:%.2f W:%.2f S:%.2f)]" % [overall_engine_performance, overall_weapon_performance, overall_shield_performance]
	return info