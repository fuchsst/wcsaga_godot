class_name RepairMechanicsSystem
extends Node

## SHIP-010 AC5: Repair Mechanics System
## Provides subsystem restoration with time-based healing and resource requirements
## Implements WCS-authentic repair mechanics with realistic time constraints and material costs

# EPIC-002 Asset Core Integration
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Signals
signal repair_started(subsystem_name: String, repair_data: Dictionary)
signal repair_progress_updated(subsystem_name: String, progress_percentage: float)
signal repair_completed(subsystem_name: String, final_health: float)
signal repair_failed(subsystem_name: String, failure_reason: String)
signal emergency_repair_activated(subsystem_name: String)
signal auto_repair_toggled(enabled: bool)

# Repair tracking
var active_repairs: Dictionary = {}          # subsystem_name -> repair_data
var repair_queue: Array[Dictionary] = []     # Queued repairs
var repair_resources: Dictionary = {}        # resource_type -> quantity
var emergency_repair_available: bool = true

# Ship references
var owner_ship: Node = null
var subsystem_health_manager: SubsystemHealthManager = null
var destruction_manager: SubsystemDestructionManager = null

# Configuration
@export var auto_repair_enabled: bool = false
@export var emergency_repair_enabled: bool = true
@export var repair_crew_efficiency: float = 1.0
@export var max_concurrent_repairs: int = 3
@export var debug_repair_logging: bool = false

# Repair timing parameters (seconds)
@export var base_repair_time: float = 30.0        # Base time for full repair
@export var emergency_repair_time: float = 5.0    # Emergency repair time
@export var auto_repair_interval: float = 2.0     # Auto repair check interval
@export var repair_skill_modifier: float = 1.0    # Crew skill modifier

# Resource requirements
@export var enable_resource_requirements: bool = true
@export var repair_material_base_cost: float = 10.0
@export var spare_parts_base_cost: float = 5.0
@export var emergency_repair_resource_cost: float = 50.0

# Repair effectiveness
@export var repair_effectiveness: float = 1.0       # How much health restored per repair
@export var field_repair_penalty: float = 0.8      # Field repairs less effective
@export var emergency_repair_effectiveness: float = 0.6  # Emergency repairs temporary

# Internal state
var auto_repair_timer: float = 0.0
var emergency_repair_cooldown: float = 0.0
var repair_crew_status: String = "available"  # available, busy, injured

func _ready() -> void:
	_setup_initial_resources()
	_setup_repair_parameters()

## Initialize repair mechanics system for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	
	# Find required components
	subsystem_health_manager = ship.get_node_or_null("SubsystemHealthManager")
	destruction_manager = ship.get_node_or_null("SubsystemDestructionManager")
	
	if not subsystem_health_manager:
		push_error("RepairMechanicsSystem: SubsystemHealthManager not found on ship")
		return
	
	# Connect to health manager signals
	subsystem_health_manager.subsystem_health_changed.connect(_on_subsystem_health_changed)
	subsystem_health_manager.subsystem_failed.connect(_on_subsystem_failed)
	
	if debug_repair_logging:
		print("RepairMechanicsSystem: Initialized for ship %s" % ship.name)

## Start repair of specific subsystem
func start_repair(subsystem_name: String, repair_type: String = "standard", priority: int = 1) -> bool:
	if not subsystem_health_manager:
		return false
	
	# Check if subsystem exists and needs repair
	var current_health = subsystem_health_manager.get_subsystem_health(subsystem_name)
	if current_health < 0:
		push_warning("RepairMechanicsSystem: Cannot repair unknown subsystem: %s" % subsystem_name)
		return false
	
	var max_health = subsystem_health_manager.subsystem_max_health.get(subsystem_name, 100.0)
	if current_health >= max_health:
		if debug_repair_logging:
			print("RepairMechanicsSystem: %s already at full health" % subsystem_name)
		return false
	
	# Check if subsystem is destroyed
	if destruction_manager and destruction_manager.is_subsystem_destroyed(subsystem_name):
		# Check if repair is possible for destroyed systems
		var destruction_info = destruction_manager.get_destruction_info(subsystem_name)
		if destruction_info.get("permanent_damage", false):
			repair_failed.emit(subsystem_name, "permanent_damage")
			return false
	
	# Check if repair is already in progress
	if active_repairs.has(subsystem_name):
		if debug_repair_logging:
			print("RepairMechanicsSystem: %s repair already in progress" % subsystem_name)
		return false
	
	# Check repair capacity
	if active_repairs.size() >= max_concurrent_repairs:
		# Add to queue
		var repair_request: Dictionary = {
			"subsystem_name": subsystem_name,
			"repair_type": repair_type,
			"priority": priority,
			"queued_time": Time.get_unix_time_from_system()
		}
		repair_queue.append(repair_request)
		_sort_repair_queue()
		
		if debug_repair_logging:
			print("RepairMechanicsSystem: %s added to repair queue (position: %d)" % [subsystem_name, repair_queue.size()])
		return true
	
	# Check resource requirements
	if not _check_repair_resources(subsystem_name, repair_type):
		repair_failed.emit(subsystem_name, "insufficient_resources")
		return false
	
	# Calculate repair parameters
	var repair_data = _calculate_repair_parameters(subsystem_name, repair_type)
	if repair_data.is_empty():
		repair_failed.emit(subsystem_name, "calculation_failed")
		return false
	
	# Consume resources
	_consume_repair_resources(subsystem_name, repair_type)
	
	# Start repair
	active_repairs[subsystem_name] = repair_data
	repair_started.emit(subsystem_name, repair_data)
	
	if debug_repair_logging:
		print("RepairMechanicsSystem: Started %s repair of %s (%.1fs, %.1f health)" % [
			repair_type, subsystem_name, repair_data["duration"], repair_data["health_restored"]
		])
	
	return true

## Start emergency repair (faster but less effective)
func start_emergency_repair(subsystem_name: String) -> bool:
	if not emergency_repair_enabled or not emergency_repair_available:
		repair_failed.emit(subsystem_name, "emergency_repair_unavailable")
		return false
	
	if emergency_repair_cooldown > 0.0:
		repair_failed.emit(subsystem_name, "emergency_repair_on_cooldown")
		return false
	
	# Force start emergency repair even if at capacity
	if active_repairs.has(subsystem_name):
		# Cancel existing repair
		cancel_repair(subsystem_name)
	
	# Check emergency resource requirements
	if enable_resource_requirements:
		if repair_resources.get("emergency_supplies", 0.0) < emergency_repair_resource_cost:
			repair_failed.emit(subsystem_name, "insufficient_emergency_supplies")
			return false
		
		repair_resources["emergency_supplies"] -= emergency_repair_resource_cost
	
	# Calculate emergency repair parameters
	var repair_data = _calculate_repair_parameters(subsystem_name, "emergency")
	repair_data["is_emergency"] = true
	
	# Start emergency repair
	active_repairs[subsystem_name] = repair_data
	emergency_repair_activated.emit(subsystem_name)
	repair_started.emit(subsystem_name, repair_data)
	
	# Set cooldown
	emergency_repair_cooldown = 120.0  # 2 minute cooldown
	
	if debug_repair_logging:
		print("RepairMechanicsSystem: Emergency repair started for %s" % subsystem_name)
	
	return true

## Cancel ongoing repair
func cancel_repair(subsystem_name: String) -> bool:
	if not active_repairs.has(subsystem_name):
		return false
	
	var repair_data = active_repairs[subsystem_name]
	
	# Refund partial resources if repair was in progress
	if repair_data["progress"] < 0.5:  # Less than 50% complete
		_refund_repair_resources(subsystem_name, repair_data["type"], 0.5)
	
	active_repairs.erase(subsystem_name)
	
	# Start next repair in queue
	_process_repair_queue()
	
	if debug_repair_logging:
		print("RepairMechanicsSystem: Cancelled repair of %s" % subsystem_name)
	
	return true

## Get repair progress for subsystem
func get_repair_progress(subsystem_name: String) -> float:
	if not active_repairs.has(subsystem_name):
		return -1.0
	
	return active_repairs[subsystem_name]["progress"]

## Get all active repairs
func get_active_repairs() -> Dictionary:
	return active_repairs.duplicate()

## Get repair queue status
func get_repair_queue() -> Array[Dictionary]:
	return repair_queue.duplicate()

## Toggle auto repair system
func set_auto_repair_enabled(enabled: bool) -> void:
	auto_repair_enabled = enabled
	auto_repair_toggled.emit(enabled)
	
	if debug_repair_logging:
		print("RepairMechanicsSystem: Auto repair %s" % ("enabled" if enabled else "disabled"))

## Add repair resources
func add_repair_resources(resource_type: String, amount: float) -> void:
	repair_resources[resource_type] = repair_resources.get(resource_type, 0.0) + amount
	
	if debug_repair_logging:
		print("RepairMechanicsSystem: Added %.1f %s (total: %.1f)" % [
			amount, resource_type, repair_resources[resource_type]
		])

## Get current resource levels
func get_repair_resources() -> Dictionary:
	return repair_resources.duplicate()

## Calculate repair parameters for subsystem and type
func _calculate_repair_parameters(subsystem_name: String, repair_type: String) -> Dictionary:
	if not subsystem_health_manager:
		return {}
	
	var current_health = subsystem_health_manager.get_subsystem_health(subsystem_name)
	var max_health = subsystem_health_manager.subsystem_max_health.get(subsystem_name, 100.0)
	var health_deficit = max_health - current_health
	var subsystem_type = subsystem_health_manager.subsystem_types.get(subsystem_name, SubsystemTypes.Type.WEAPONS)
	
	# Calculate repair duration
	var duration = _calculate_repair_duration(subsystem_type, health_deficit, repair_type)
	
	# Calculate health to be restored
	var health_restored = _calculate_health_restored(subsystem_type, health_deficit, repair_type)
	
	# Calculate resource cost
	var resource_cost = _calculate_resource_cost(subsystem_type, health_deficit, repair_type)
	
	return {
		"type": repair_type,
		"duration": duration,
		"health_restored": health_restored,
		"resource_cost": resource_cost,
		"subsystem_type": subsystem_type,
		"start_time": Time.get_unix_time_from_system(),
		"progress": 0.0,
		"estimated_completion": Time.get_unix_time_from_system() + duration
	}

## Calculate repair duration based on parameters
func _calculate_repair_duration(subsystem_type: int, health_deficit: float, repair_type: String) -> float:
	var base_duration = base_repair_time
	
	# Repair type modifiers
	match repair_type:
		"emergency":
			base_duration = emergency_repair_time
		"field":
			base_duration *= 1.5  # Field repairs take longer
		"depot":
			base_duration *= 0.7  # Depot repairs faster
		"auto":
			base_duration *= 0.8  # Auto repairs efficient
	
	# Subsystem type modifiers
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			base_duration *= 1.3  # Engines complex to repair
		SubsystemTypes.Type.TURRET, SubsystemTypes.Type.WEAPONS:
			base_duration *= 1.1  # Weapons moderately complex
		SubsystemTypes.Type.RADAR:
			base_duration *= 0.9  # Electronics faster to repair
		SubsystemTypes.Type.NAVIGATION:
			base_duration *= 0.8  # Navigation systems simpler
		SubsystemTypes.Type.COMMUNICATION:
			base_duration *= 0.7  # Communication easiest
	
	# Health deficit modifier (more damage = longer repair)
	var health_factor = health_deficit / 100.0
	base_duration *= (0.5 + health_factor)
	
	# Crew efficiency modifier
	base_duration /= repair_crew_efficiency
	
	# Skill modifier
	base_duration /= repair_skill_modifier
	
	return max(1.0, base_duration)  # Minimum 1 second

## Calculate health restored by repair
func _calculate_health_restored(subsystem_type: int, health_deficit: float, repair_type: String) -> float:
	var health_restored = health_deficit
	
	# Repair type effectiveness
	match repair_type:
		"emergency":
			health_restored *= emergency_repair_effectiveness
		"field":
			health_restored *= field_repair_penalty
		"depot":
			health_restored *= 1.0  # Full effectiveness
		"auto":
			health_restored *= 0.3  # Auto repairs gradual
		"standard":
			health_restored *= repair_effectiveness
	
	# Subsystem type factors
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			health_restored *= 0.8  # Engines harder to fully repair
		SubsystemTypes.Type.RADAR:
			health_restored *= 1.2  # Electronics repair well
		_:
			pass
	
	return max(1.0, health_restored)

## Calculate resource cost for repair
func _calculate_resource_cost(subsystem_type: int, health_deficit: float, repair_type: String) -> Dictionary:
	var cost: Dictionary = {
		"repair_materials": 0.0,
		"spare_parts": 0.0,
		"emergency_supplies": 0.0
	}
	
	if not enable_resource_requirements:
		return cost
	
	var health_factor = health_deficit / 100.0
	
	# Base costs
	cost["repair_materials"] = repair_material_base_cost * health_factor
	cost["spare_parts"] = spare_parts_base_cost * health_factor
	
	# Repair type modifiers
	match repair_type:
		"emergency":
			cost["emergency_supplies"] = emergency_repair_resource_cost
			cost["repair_materials"] *= 0.5  # Less materials needed
		"field":
			cost["repair_materials"] *= 1.2  # Field repairs waste materials
		"depot":
			cost["spare_parts"] *= 0.8  # Depot has better parts access
	
	# Subsystem type modifiers
	match subsystem_type:
		SubsystemTypes.Type.ENGINE:
			cost["spare_parts"] *= 1.5  # Engines need more parts
		SubsystemTypes.Type.TURRET, SubsystemTypes.Type.WEAPONS:
			cost["spare_parts"] *= 1.2  # Weapons need specialized parts
		SubsystemTypes.Type.RADAR:
			cost["repair_materials"] *= 1.3  # Electronics need special materials
		_:
			pass
	
	return cost

## Check if sufficient resources available for repair
func _check_repair_resources(subsystem_name: String, repair_type: String) -> bool:
	if not enable_resource_requirements:
		return true
	
	var current_health = subsystem_health_manager.get_subsystem_health(subsystem_name)
	var max_health = subsystem_health_manager.subsystem_max_health.get(subsystem_name, 100.0)
	var health_deficit = max_health - current_health
	var subsystem_type = subsystem_health_manager.subsystem_types.get(subsystem_name, SubsystemTypes.Type.WEAPONS)
	
	var required_cost = _calculate_resource_cost(subsystem_type, health_deficit, repair_type)
	
	for resource_type in required_cost.keys():
		var required = required_cost[resource_type]
		var available = repair_resources.get(resource_type, 0.0)
		if available < required:
			if debug_repair_logging:
				print("RepairMechanicsSystem: Insufficient %s for %s (need: %.1f, have: %.1f)" % [
					resource_type, subsystem_name, required, available
				])
			return false
	
	return true

## Consume resources for repair
func _consume_repair_resources(subsystem_name: String, repair_type: String) -> void:
	if not enable_resource_requirements:
		return
	
	var current_health = subsystem_health_manager.get_subsystem_health(subsystem_name)
	var max_health = subsystem_health_manager.subsystem_max_health.get(subsystem_name, 100.0)
	var health_deficit = max_health - current_health
	var subsystem_type = subsystem_health_manager.subsystem_types.get(subsystem_name, SubsystemTypes.Type.WEAPONS)
	
	var cost = _calculate_resource_cost(subsystem_type, health_deficit, repair_type)
	
	for resource_type in cost.keys():
		var amount = cost[resource_type]
		repair_resources[resource_type] = max(0.0, repair_resources.get(resource_type, 0.0) - amount)

## Refund resources for cancelled repair
func _refund_repair_resources(subsystem_name: String, repair_type: String, refund_percentage: float) -> void:
	if not enable_resource_requirements:
		return
	
	var current_health = subsystem_health_manager.get_subsystem_health(subsystem_name)
	var max_health = subsystem_health_manager.subsystem_max_health.get(subsystem_name, 100.0)
	var health_deficit = max_health - current_health
	var subsystem_type = subsystem_health_manager.subsystem_types.get(subsystem_name, SubsystemTypes.Type.WEAPONS)
	
	var cost = _calculate_resource_cost(subsystem_type, health_deficit, repair_type)
	
	for resource_type in cost.keys():
		var refund_amount = cost[resource_type] * refund_percentage
		repair_resources[resource_type] = repair_resources.get(resource_type, 0.0) + refund_amount

## Process repair queue to start next repair
func _process_repair_queue() -> void:
	if repair_queue.is_empty() or active_repairs.size() >= max_concurrent_repairs:
		return
	
	var next_repair = repair_queue.pop_front()
	start_repair(next_repair["subsystem_name"], next_repair["repair_type"], next_repair["priority"])

## Sort repair queue by priority
func _sort_repair_queue() -> void:
	repair_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["priority"] > b["priority"]
	)

## Setup initial repair resources
func _setup_initial_resources() -> void:
	repair_resources = {
		"repair_materials": 100.0,
		"spare_parts": 50.0,
		"emergency_supplies": 20.0
	}

## Setup repair parameters based on ship type
func _setup_repair_parameters() -> void:
	# These could be customized based on ship class
	pass

## Process frame updates for repair progress
func _process(delta: float) -> void:
	# Update active repairs
	_update_active_repairs(delta)
	
	# Update auto repair system
	if auto_repair_enabled:
		_update_auto_repair_system(delta)
	
	# Update emergency repair cooldown
	if emergency_repair_cooldown > 0.0:
		emergency_repair_cooldown -= delta

## Update active repair progress
func _update_active_repairs(delta: float) -> void:
	var completed_repairs: Array[String] = []
	
	for subsystem_name in active_repairs.keys():
		var repair_data = active_repairs[subsystem_name]
		var elapsed_time = Time.get_unix_time_from_system() - repair_data["start_time"]
		var progress = min(1.0, elapsed_time / repair_data["duration"])
		
		repair_data["progress"] = progress
		repair_progress_updated.emit(subsystem_name, progress)
		
		if progress >= 1.0:
			completed_repairs.append(subsystem_name)
	
	# Complete finished repairs
	for subsystem_name in completed_repairs:
		_complete_repair(subsystem_name)

## Complete a repair
func _complete_repair(subsystem_name: String) -> void:
	if not active_repairs.has(subsystem_name):
		return
	
	var repair_data = active_repairs[subsystem_name]
	var health_restored = repair_data["health_restored"]
	
	# Apply health restoration
	if subsystem_health_manager:
		subsystem_health_manager.repair_subsystem(subsystem_name, health_restored)
		var final_health = subsystem_health_manager.get_subsystem_health(subsystem_name)
		repair_completed.emit(subsystem_name, final_health)
	
	# Remove from active repairs
	active_repairs.erase(subsystem_name)
	
	# Process next repair in queue
	_process_repair_queue()
	
	if debug_repair_logging:
		print("RepairMechanicsSystem: Completed repair of %s (restored: %.1f health)" % [
			subsystem_name, health_restored
		])

## Update auto repair system
func _update_auto_repair_system(delta: float) -> void:
	auto_repair_timer += delta
	if auto_repair_timer >= auto_repair_interval:
		auto_repair_timer = 0.0
		_perform_auto_repair_check()

## Perform auto repair check
func _perform_auto_repair_check() -> void:
	if not subsystem_health_manager or repair_crew_status != "available":
		return
	
	# Find subsystem that needs repair most urgently
	var repair_candidates: Array[String] = []
	var subsystem_statuses = subsystem_health_manager.get_all_subsystem_statuses()
	
	for subsystem_name in subsystem_statuses.keys():
		var status = subsystem_statuses[subsystem_name]
		var health_pct = status["health_percentage"]
		
		# Auto repair for systems below 70% health
		if health_pct < 0.7 and not active_repairs.has(subsystem_name):
			repair_candidates.append(subsystem_name)
	
	if not repair_candidates.is_empty():
		# Sort by health (lowest first)
		repair_candidates.sort_custom(func(a: String, b: String) -> bool:
			var health_a = subsystem_health_manager.get_subsystem_health_percentage(a)
			var health_b = subsystem_health_manager.get_subsystem_health_percentage(b)
			return health_a < health_b
		)
		
		# Start auto repair for most damaged system
		var target_subsystem = repair_candidates[0]
		start_repair(target_subsystem, "auto", 2)

## Handle subsystem health changes
func _on_subsystem_health_changed(subsystem_name: String, old_health: float, new_health: float) -> void:
	# Auto repair system will handle this on next check
	pass

## Handle subsystem failures
func _on_subsystem_failed(subsystem_name: String, failure_type: String) -> void:
	# Cancel any ongoing repair for failed subsystem
	if active_repairs.has(subsystem_name):
		cancel_repair(subsystem_name)
	
	if debug_repair_logging:
		print("RepairMechanicsSystem: Subsystem %s failed, repair cancelled" % subsystem_name)

## Get repair system status
func get_repair_status() -> Dictionary:
	return {
		"auto_repair_enabled": auto_repair_enabled,
		"emergency_repair_available": emergency_repair_available and emergency_repair_cooldown <= 0.0,
		"emergency_repair_cooldown": emergency_repair_cooldown,
		"active_repairs": active_repairs.size(),
		"repair_queue_length": repair_queue.size(),
		"crew_status": repair_crew_status,
		"repair_resources": repair_resources.duplicate(),
		"repair_capacity": max_concurrent_repairs
	}