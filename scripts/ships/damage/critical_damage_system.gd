class_name CriticalDamageSystem
extends Node

## Critical damage system handling structural failures, subsystem destruction, and cascade damage effects
## Manages WCS-authentic critical damage mechanics with progressive failure states (SHIP-009 AC5)

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Critical damage signals (SHIP-009 AC5)
signal critical_event_triggered(event_type: String, severity: float, location: Vector3)
signal cascade_failure_started(failure_type: String, affected_systems: Array[String])
signal structural_integrity_compromised(integrity_percentage: float)
signal emergency_protocol_activated(protocol_name: String)
signal catastrophic_failure_imminent(time_to_failure: float)

# Critical damage event types
enum CriticalEventType {
	STRUCTURAL_BREACH,     # Hull breach causing atmosphere loss
	POWER_CORE_OVERLOAD,   # Reactor damage causing power fluctuations
	ENGINE_EXPLOSION,      # Engine destruction causing thrust loss
	WEAPON_MAGAZINE_DETONATION,  # Missile/ammunition explosion
	BRIDGE_DESTRUCTION,    # Command center destruction
	SENSOR_ARRAY_FAILURE,  # Sensor system critical failure
	LIFE_SUPPORT_FAILURE,  # Life support system critical failure
	FIRE_OUTBREAK,         # Ship fire spreading damage
	ELECTRICAL_FAILURE,    # Power system cascade failure
	HULL_FRACTURE         # Structural integrity failure
}

# Ship integration
var ship: BaseShip
var subsystem_manager: Node
var damage_manager: Node

# Critical damage tracking (SHIP-009 AC5)
var active_critical_events: Array[Dictionary] = []
var structural_integrity: float = 100.0  # Overall structural health
var cascade_failure_threshold: float = 25.0  # Threshold for cascade failures
var catastrophic_failure_threshold: float = 10.0  # Point of no return

# Critical event configuration
var event_configurations: Dictionary = {}
var emergency_protocols: Dictionary = {}
var cascade_rules: Dictionary = {}

# Progressive damage state
var progressive_damage_rate: float = 0.0  # Damage per second from critical events
var fire_spread_rate: float = 0.0  # Fire damage spread rate
var atmosphere_loss_rate: float = 0.0  # Atmosphere loss from breaches

# Emergency protocol state
var emergency_protocols_active: Dictionary = {}
var catastrophic_failure_timer: float = -1.0  # Time until complete failure

func _ready() -> void:
	name = "CriticalDamageSystem"
	_initialize_critical_event_configurations()
	_initialize_emergency_protocols()
	_initialize_cascade_rules()

func _physics_process(delta: float) -> void:
	# Process active critical events
	_process_critical_events(delta)
	
	# Process progressive damage
	_process_progressive_damage(delta)
	
	# Check for catastrophic failure
	_check_catastrophic_failure(delta)

## Initialize critical damage system for specific ship (SHIP-009 AC5)
func initialize_critical_system(parent_ship: BaseShip) -> bool:
	"""Initialize critical damage system for specific ship.
	
	Args:
		parent_ship: Ship to manage critical damage for
		
	Returns:
		true if initialization successful
	"""
	if not parent_ship:
		push_error("CriticalDamageSystem: Cannot initialize with null ship")
		return false
	
	ship = parent_ship
	subsystem_manager = ship.subsystem_manager
	damage_manager = ship.get_node_or_null("DamageManager")
	
	# Configure critical thresholds based on ship type
	_configure_critical_thresholds()
	
	# Connect to ship signals
	_connect_ship_signals()
	
	return true

## Initialize critical event configurations (SHIP-009 AC5)
func _initialize_critical_event_configurations() -> void:
	"""Initialize configuration for different critical event types."""
	event_configurations = {
		CriticalEventType.STRUCTURAL_BREACH: {
			"duration": 30.0,  # 30 seconds
			"damage_rate": 2.0,  # 2 HP/sec structural damage
			"spread_chance": 0.3,  # 30% chance to spread
			"atmosphere_loss": 1.5,  # Atmosphere loss rate
			"repair_difficulty": 0.8
		},
		CriticalEventType.POWER_CORE_OVERLOAD: {
			"duration": 20.0,
			"damage_rate": 3.0,
			"spread_chance": 0.5,
			"power_loss": 0.7,  # 70% power reduction
			"repair_difficulty": 0.9
		},
		CriticalEventType.ENGINE_EXPLOSION: {
			"duration": 15.0,
			"damage_rate": 5.0,
			"spread_chance": 0.4,
			"thrust_loss": 0.8,  # 80% thrust reduction
			"repair_difficulty": 0.95
		},
		CriticalEventType.WEAPON_MAGAZINE_DETONATION: {
			"duration": 10.0,
			"damage_rate": 8.0,
			"spread_chance": 0.6,
			"explosive_damage": 50.0,
			"repair_difficulty": 1.0  # Cannot be repaired
		},
		CriticalEventType.BRIDGE_DESTRUCTION: {
			"duration": 60.0,
			"damage_rate": 1.0,
			"spread_chance": 0.1,
			"control_loss": 0.9,  # 90% control reduction
			"repair_difficulty": 0.85
		},
		CriticalEventType.SENSOR_ARRAY_FAILURE: {
			"duration": 45.0,
			"damage_rate": 0.5,
			"spread_chance": 0.2,
			"sensor_loss": 0.8,  # 80% sensor reduction
			"repair_difficulty": 0.6
		},
		CriticalEventType.LIFE_SUPPORT_FAILURE: {
			"duration": 120.0,
			"damage_rate": 0.5,
			"spread_chance": 0.1,
			"life_support_loss": 0.9,
			"repair_difficulty": 0.7
		},
		CriticalEventType.FIRE_OUTBREAK: {
			"duration": 40.0,
			"damage_rate": 1.5,
			"spread_chance": 0.8,  # High spread chance
			"fire_spread_rate": 2.0,
			"repair_difficulty": 0.5
		},
		CriticalEventType.ELECTRICAL_FAILURE: {
			"duration": 25.0,
			"damage_rate": 1.0,
			"spread_chance": 0.7,
			"system_disruption": 0.6,
			"repair_difficulty": 0.6
		},
		CriticalEventType.HULL_FRACTURE: {
			"duration": 90.0,
			"damage_rate": 2.5,
			"spread_chance": 0.4,
			"structural_loss": 0.3,  # 30% structural integrity loss
			"repair_difficulty": 0.9
		}
	}

## Initialize emergency protocol configurations
func _initialize_emergency_protocols() -> void:
	"""Initialize emergency response protocols."""
	emergency_protocols = {
		"fire_suppression": {
			"trigger_conditions": ["fire_outbreak"],
			"effectiveness": 0.7,  # 70% fire damage reduction
			"duration": 30.0,
			"cooldown": 60.0
		},
		"emergency_power": {
			"trigger_conditions": ["power_core_overload", "electrical_failure"],
			"effectiveness": 0.5,  # 50% power restoration
			"duration": 45.0,
			"cooldown": 120.0
		},
		"damage_control": {
			"trigger_conditions": ["structural_breach", "hull_fracture"],
			"effectiveness": 0.6,  # 60% structural damage reduction
			"duration": 60.0,
			"cooldown": 90.0
		},
		"emergency_shutdown": {
			"trigger_conditions": ["catastrophic_failure"],
			"effectiveness": 0.3,  # 30% damage rate reduction
			"duration": 180.0,
			"cooldown": 300.0
		}
	}

## Initialize cascade failure rules
func _initialize_cascade_rules() -> void:
	"""Initialize rules for cascade failures between systems."""
	cascade_rules = {
		CriticalEventType.POWER_CORE_OVERLOAD: [
			CriticalEventType.ELECTRICAL_FAILURE,
			CriticalEventType.LIFE_SUPPORT_FAILURE
		],
		CriticalEventType.ENGINE_EXPLOSION: [
			CriticalEventType.FIRE_OUTBREAK,
			CriticalEventType.STRUCTURAL_BREACH
		],
		CriticalEventType.WEAPON_MAGAZINE_DETONATION: [
			CriticalEventType.FIRE_OUTBREAK,
			CriticalEventType.HULL_FRACTURE,
			CriticalEventType.POWER_CORE_OVERLOAD
		],
		CriticalEventType.FIRE_OUTBREAK: [
			CriticalEventType.ELECTRICAL_FAILURE,
			CriticalEventType.LIFE_SUPPORT_FAILURE
		],
		CriticalEventType.HULL_FRACTURE: [
			CriticalEventType.STRUCTURAL_BREACH,
			CriticalEventType.LIFE_SUPPORT_FAILURE
		]
	}

## Configure critical thresholds based on ship type
func _configure_critical_thresholds() -> void:
	"""Configure critical damage thresholds based on ship class."""
	if not ship or not ship.ship_class:
		return
	
	# Adjust thresholds based on ship robustness
	match ship.ship_class.ship_type:
		ShipTypes.Type.FIGHTER:
			cascade_failure_threshold = 35.0  # Fighters fail earlier
			catastrophic_failure_threshold = 15.0
		ShipTypes.Type.BOMBER:
			cascade_failure_threshold = 30.0
			catastrophic_failure_threshold = 12.0
		ShipTypes.Type.CRUISER:
			cascade_failure_threshold = 20.0  # More robust
			catastrophic_failure_threshold = 8.0
		ShipTypes.Type.CAPITAL:
			cascade_failure_threshold = 15.0  # Very robust
			catastrophic_failure_threshold = 5.0

## Connect to ship signals for critical damage integration
func _connect_ship_signals() -> void:
	"""Connect to ship signals for critical damage coordination."""
	if not ship:
		return
	
	# Connect to ship destruction for final critical events
	ship.ship_destroyed.connect(_on_ship_destroyed)
	
	# Connect to subsystem manager for cascade failures
	if subsystem_manager:
		subsystem_manager.subsystem_destroyed.connect(_on_subsystem_destroyed)

# ============================================================================
# CRITICAL EVENT TRIGGERING API (SHIP-009 AC5)
# ============================================================================

## Trigger critical damage event (SHIP-009 AC5)
func trigger_critical_event(event_type: String, severity: float, location: Vector3, source_damage: float = 0.0) -> bool:
	"""Trigger critical damage event with cascade potential.
	
	Args:
		event_type: Type of critical event
		severity: Severity multiplier (1.0 = normal, 2.0 = double effect)
		location: Location where event occurred
		source_damage: Original damage that caused the event
		
	Returns:
		true if event was triggered successfully
	"""
	# Map string to enum if needed
	var event_enum: int = _get_event_type_from_string(event_type)
	if event_enum < 0:
		return false
	
	# Get event configuration
	if not event_configurations.has(event_enum):
		return false
	
	var config: Dictionary = event_configurations[event_enum]
	
	# Create critical event data
	var critical_event: Dictionary = {
		"type": event_enum,
		"type_name": event_type,
		"severity": severity,
		"location": location,
		"start_time": Time.get_ticks_msec() * 0.001,
		"duration": config.duration * severity,
		"damage_rate": config.damage_rate * severity,
		"spread_chance": config.spread_chance,
		"config": config,
		"active": true,
		"spread_timer": 0.0
	}
	
	# Add to active events
	active_critical_events.append(critical_event)
	
	# Apply immediate effects
	_apply_immediate_critical_effects(critical_event)
	
	# Check for cascade failures
	_check_cascade_failures(event_enum, severity, location)
	
	# Trigger emergency protocols
	_evaluate_emergency_protocols(event_type)
	
	# Emit critical event signal
	critical_event_triggered.emit(event_type, severity, location)
	
	return true

## Apply immediate effects of critical damage event
func _apply_immediate_critical_effects(event: Dictionary) -> void:
	"""Apply immediate effects when critical event is triggered."""
	var config: Dictionary = event.config
	var severity: float = event.severity
	
	# Apply immediate structural damage
	if config.has("structural_loss"):
		var structural_damage: float = config.structural_loss * severity * 100.0
		structural_integrity = max(0.0, structural_integrity - structural_damage)
		structural_integrity_compromised.emit(structural_integrity)
	
	# Apply explosive damage to nearby subsystems
	if config.has("explosive_damage"):
		_apply_explosive_damage(event.location, config.explosive_damage * severity)
	
	# Reduce ship performance immediately
	if ship:
		match event.type:
			CriticalEventType.ENGINE_EXPLOSION:
				ship.engine_performance = min(ship.engine_performance, 1.0 - config.thrust_loss)
			CriticalEventType.POWER_CORE_OVERLOAD:
				ship.weapon_performance = min(ship.weapon_performance, 1.0 - config.power_loss)
			CriticalEventType.BRIDGE_DESTRUCTION:
				ship.performance_modifier = min(ship.performance_modifier, 1.0 - config.control_loss)

## Check for cascade failures from critical event (SHIP-009 AC5)
func _check_cascade_failures(event_type: int, severity: float, location: Vector3) -> void:
	"""Check if critical event should trigger cascade failures."""
	if not cascade_rules.has(event_type):
		return
	
	var potential_cascades: Array = cascade_rules[event_type]
	
	for cascade_type in potential_cascades:
		# Calculate cascade probability based on severity and ship condition
		var cascade_chance: float = severity * 0.3  # Base 30% per severity point
		
		# Increase chance if ship is already critically damaged
		if structural_integrity < cascade_failure_threshold:
			cascade_chance *= 2.0
		
		# Roll for cascade
		if randf() < cascade_chance:
			_trigger_cascade_failure(cascade_type, severity * 0.8, location)

## Trigger cascade failure to another system
func _trigger_cascade_failure(cascade_type: int, severity: float, origin_location: Vector3) -> void:
	"""Trigger cascade failure to another system."""
	# Find appropriate location for cascade (near origin or at subsystem location)
	var cascade_location: Vector3 = origin_location + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	
	# Get cascade event name
	var cascade_name: String = CriticalEventType.keys()[cascade_type]
	
	# Trigger cascade event
	var cascade_event_name: String = cascade_name.to_lower().replace("_", " ")
	trigger_critical_event(cascade_event_name, severity, cascade_location)
	
	# Emit cascade signal
	var affected_systems: Array[String] = _get_affected_subsystems(cascade_location)
	cascade_failure_started.emit(cascade_event_name, affected_systems)

## Get event type enum from string name
func _get_event_type_from_string(event_name: String) -> int:
	"""Convert event name string to enum value."""
	var normalized_name: String = event_name.to_upper().replace(" ", "_")
	
	# Map common variations
	var name_mappings: Dictionary = {
		"BRIDGE_CRITICAL_DAMAGE": CriticalEventType.BRIDGE_DESTRUCTION,
		"ENGINE_CRITICAL_DAMAGE": CriticalEventType.ENGINE_EXPLOSION,
		"REACTOR_CRITICAL_DAMAGE": CriticalEventType.POWER_CORE_OVERLOAD,
		"WEAPONS_CRITICAL_DAMAGE": CriticalEventType.WEAPON_MAGAZINE_DETONATION
	}
	
	if name_mappings.has(normalized_name):
		return name_mappings[normalized_name]
	
	# Try direct enum lookup
	for i in range(CriticalEventType.size()):
		if CriticalEventType.keys()[i] == normalized_name:
			return i
	
	return -1  # Not found

# ============================================================================
# CRITICAL EVENT PROCESSING (SHIP-009 AC5)
# ============================================================================

## Process active critical events each frame (SHIP-009 AC5)
func _process_critical_events(delta: float) -> void:
	"""Process ongoing critical events and their effects."""
	var current_time: float = Time.get_ticks_msec() * 0.001
	var events_to_remove: Array[int] = []
	
	for i in range(active_critical_events.size()):
		var event: Dictionary = active_critical_events[i]
		
		# Check if event has expired
		var elapsed_time: float = current_time - event.start_time
		if elapsed_time >= event.duration:
			events_to_remove.append(i)
			continue
		
		# Process ongoing effects
		_process_critical_event_effects(event, delta)
		
		# Check for spread
		_check_critical_event_spread(event, delta)
	
	# Remove expired events (in reverse order to maintain indices)
	for i in range(events_to_remove.size() - 1, -1, -1):
		active_critical_events.remove_at(events_to_remove[i])

## Process effects of individual critical event
func _process_critical_event_effects(event: Dictionary, delta: float) -> void:
	"""Process ongoing effects of a critical event."""
	var config: Dictionary = event.config
	
	# Apply continuous damage
	if config.has("damage_rate"):
		var damage_amount: float = config.damage_rate * event.severity * delta
		progressive_damage_rate += damage_amount
	
	# Process fire spread
	if event.type == CriticalEventType.FIRE_OUTBREAK:
		fire_spread_rate = config.get("fire_spread_rate", 0.0) * event.severity
	
	# Process atmosphere loss
	if config.has("atmosphere_loss"):
		atmosphere_loss_rate = config.atmosphere_loss * event.severity

## Check if critical event should spread to nearby areas
func _check_critical_event_spread(event: Dictionary, delta: float) -> void:
	"""Check if critical event spreads to nearby ship areas."""
	var config: Dictionary = event.config
	
	if not config.has("spread_chance"):
		return
	
	# Update spread timer
	event.spread_timer += delta
	
	# Check for spread every 5 seconds
	if event.spread_timer >= 5.0:
		event.spread_timer = 0.0
		
		var spread_chance: float = config.spread_chance * event.severity * 0.2  # 20% per check
		
		if randf() < spread_chance:
			_spread_critical_event(event)

## Spread critical event to nearby location
func _spread_critical_event(original_event: Dictionary) -> void:
	"""Spread critical event to nearby ship location."""
	# Calculate spread location (random nearby position)
	var spread_offset: Vector3 = Vector3(randf_range(-3, 3), randf_range(-2, 2), randf_range(-3, 3))
	var spread_location: Vector3 = original_event.location + spread_offset
	
	# Trigger spread event with reduced severity
	var spread_severity: float = original_event.severity * 0.7
	trigger_critical_event(original_event.type_name, spread_severity, spread_location)

## Process progressive damage from critical events
func _process_progressive_damage(delta: float) -> void:
	"""Process cumulative progressive damage from all critical events."""
	if progressive_damage_rate > 0.0 and ship:
		# Apply progressive hull damage
		var damage_amount: float = progressive_damage_rate * delta
		if damage_manager:
			damage_manager.apply_hull_damage(damage_amount, ship.global_position, DamageTypes.Type.KINETIC, "critical_damage")
		
		# Decay damage rate gradually
		progressive_damage_rate *= 0.99  # 1% decay per frame

## Apply explosive damage to nearby subsystems
func _apply_explosive_damage(explosion_location: Vector3, damage_amount: float) -> void:
	"""Apply explosive damage to subsystems near explosion."""
	if not subsystem_manager:
		return
	
	# Get subsystems within explosion radius
	var explosion_radius: float = 5.0
	var affected_subsystems: Array = subsystem_manager.get_subsystems_near_location(explosion_location, explosion_radius)
	
	# Apply damage to affected subsystems
	for subsystem in affected_subsystems:
		var distance: float = subsystem.global_position.distance_to(explosion_location)
		var damage_falloff: float = 1.0 - (distance / explosion_radius)
		var effective_damage: float = damage_amount * damage_falloff
		
		subsystem.apply_damage(effective_damage, explosion_location)

## Get list of affected subsystems near location
func _get_affected_subsystems(location: Vector3) -> Array[String]:
	"""Get list of subsystem names affected by critical event at location."""
	var affected_names: Array[String] = []
	
	if not subsystem_manager:
		return affected_names
	
	var nearby_subsystems: Array = subsystem_manager.get_subsystems_near_location(location, 3.0)
	for subsystem in nearby_subsystems:
		affected_names.append(subsystem.subsystem_name)
	
	return affected_names

# ============================================================================
# EMERGENCY PROTOCOLS (SHIP-009 AC5)
# ============================================================================

## Evaluate and trigger emergency protocols
func _evaluate_emergency_protocols(event_type: String) -> void:
	"""Evaluate if emergency protocols should be triggered."""
	for protocol_name in emergency_protocols.keys():
		var protocol: Dictionary = emergency_protocols[protocol_name]
		
		# Check if this event type triggers the protocol
		if event_type in protocol.trigger_conditions:
			_activate_emergency_protocol(protocol_name, protocol)

## Activate emergency protocol
func _activate_emergency_protocol(protocol_name: String, protocol: Dictionary) -> void:
	"""Activate emergency response protocol."""
	# Check cooldown
	if emergency_protocols_active.has(protocol_name):
		var last_activation: float = emergency_protocols_active[protocol_name]
		var cooldown: float = protocol.get("cooldown", 60.0)
		var current_time: float = Time.get_ticks_msec() * 0.001
		
		if current_time - last_activation < cooldown:
			return  # Still on cooldown
	
	# Activate protocol
	emergency_protocols_active[protocol_name] = Time.get_ticks_msec() * 0.001
	
	# Apply protocol effects
	_apply_emergency_protocol_effects(protocol_name, protocol)
	
	# Emit signal
	emergency_protocol_activated.emit(protocol_name)

## Apply effects of emergency protocol
func _apply_emergency_protocol_effects(protocol_name: String, protocol: Dictionary) -> void:
	"""Apply effects of activated emergency protocol."""
	var effectiveness: float = protocol.get("effectiveness", 0.5)
	
	match protocol_name:
		"fire_suppression":
			# Reduce fire spread rate
			fire_spread_rate *= (1.0 - effectiveness)
			
		"emergency_power":
			# Temporarily restore some power
			if ship:
				ship.weapon_performance = min(1.0, ship.weapon_performance + effectiveness)
				
		"damage_control":
			# Reduce progressive damage
			progressive_damage_rate *= (1.0 - effectiveness)
			
		"emergency_shutdown":
			# Reduce all damage rates significantly
			progressive_damage_rate *= 0.3
			fire_spread_rate *= 0.2
			atmosphere_loss_rate *= 0.1

# ============================================================================
# CATASTROPHIC FAILURE MANAGEMENT (SHIP-009 AC5)  
# ============================================================================

## Check for catastrophic failure conditions
func _check_catastrophic_failure(delta: float) -> void:
	"""Check if ship should undergo catastrophic failure."""
	# Check structural integrity threshold
	if structural_integrity <= catastrophic_failure_threshold:
		if catastrophic_failure_timer < 0.0:
			# Start catastrophic failure countdown
			catastrophic_failure_timer = 30.0  # 30 seconds to complete failure
			catastrophic_failure_imminent.emit(catastrophic_failure_timer)
			_activate_emergency_protocol("emergency_shutdown", emergency_protocols["emergency_shutdown"])
	
	# Process catastrophic failure countdown
	if catastrophic_failure_timer > 0.0:
		catastrophic_failure_timer -= delta
		
		# Increase damage rate as failure approaches
		var failure_acceleration: float = (30.0 - catastrophic_failure_timer) / 30.0
		progressive_damage_rate += failure_acceleration * 2.0 * delta
		
		# Trigger final critical events
		if catastrophic_failure_timer <= 0.0:
			_trigger_final_catastrophic_failure()

## Trigger final catastrophic failure sequence
func _trigger_final_catastrophic_failure() -> void:
	"""Trigger final catastrophic failure sequence."""
	# Trigger multiple critical failures simultaneously
	var failure_locations: Array[Vector3] = [
		Vector3(0, 0, 0),    # Core
		Vector3(0, 0, 8),    # Front
		Vector3(0, 0, -8),   # Rear
		Vector3(-5, 0, 0),   # Left
		Vector3(5, 0, 0)     # Right
	]
	
	for location in failure_locations:
		trigger_critical_event("hull_fracture", 3.0, location)
		trigger_critical_event("fire_outbreak", 2.0, location)
	
	# Massive power core explosion
	trigger_critical_event("power_core_overload", 5.0, Vector3.ZERO)
	
	# Ship is now doomed
	if ship:
		ship._trigger_ship_destruction()

## Process critical effects over time
func process_critical_effects(delta: float) -> void:
	"""Process critical effects - called by DamageManager."""
	# This method is called by DamageManager for integration
	# Most processing is already done in _physics_process
	pass

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Handle ship destruction
func _on_ship_destroyed(destroyed_ship: BaseShip) -> void:
	"""Handle ship destruction event."""
	if destroyed_ship == ship:
		# Trigger final critical events for dramatic effect
		trigger_critical_event("weapon_magazine_detonation", 3.0, Vector3.ZERO)

## Handle subsystem destruction for cascade failures
func _on_subsystem_destroyed(subsystem_name: String) -> void:
	"""Handle subsystem destruction that may trigger critical events."""
	# Map subsystem failures to critical events
	var critical_events: Dictionary = {
		"reactor": "power_core_overload",
		"engine": "engine_explosion", 
		"bridge": "bridge_destruction",
		"weapons": "weapon_magazine_detonation",
		"sensors": "sensor_array_failure",
		"life_support": "life_support_failure"
	}
	
	if critical_events.has(subsystem_name):
		var subsystem_location: Vector3 = Vector3.ZERO  # Would get from subsystem manager
		trigger_critical_event(critical_events[subsystem_name], 2.0, subsystem_location)

# ============================================================================
# SAVE/LOAD AND PERSISTENCE (SHIP-009 AC6)
# ============================================================================

## Get critical damage save data for persistence
func get_critical_save_data() -> Dictionary:
	"""Get critical damage system save data for persistence."""
	return {
		"structural_integrity": structural_integrity,
		"progressive_damage_rate": progressive_damage_rate,
		"fire_spread_rate": fire_spread_rate,
		"atmosphere_loss_rate": atmosphere_loss_rate,
		"catastrophic_failure_timer": catastrophic_failure_timer,
		"active_critical_events": active_critical_events.duplicate(),
		"emergency_protocols_active": emergency_protocols_active.duplicate(),
		"cascade_failure_threshold": cascade_failure_threshold,
		"catastrophic_failure_threshold": catastrophic_failure_threshold
	}

## Load critical damage save data from persistence
func load_critical_save_data(save_data: Dictionary) -> bool:
	"""Load critical damage system save data from persistence."""
	if not save_data:
		return false
	
	# Load damage state
	structural_integrity = save_data.get("structural_integrity", structural_integrity)
	progressive_damage_rate = save_data.get("progressive_damage_rate", progressive_damage_rate)
	fire_spread_rate = save_data.get("fire_spread_rate", fire_spread_rate)
	atmosphere_loss_rate = save_data.get("atmosphere_loss_rate", atmosphere_loss_rate)
	catastrophic_failure_timer = save_data.get("catastrophic_failure_timer", catastrophic_failure_timer)
	
	# Load thresholds
	cascade_failure_threshold = save_data.get("cascade_failure_threshold", cascade_failure_threshold)
	catastrophic_failure_threshold = save_data.get("catastrophic_failure_threshold", catastrophic_failure_threshold)
	
	# Load active events
	if save_data.has("active_critical_events"):
		active_critical_events = save_data.active_critical_events.duplicate()
	
	# Load emergency protocols
	if save_data.has("emergency_protocols_active"):
		emergency_protocols_active = save_data.emergency_protocols_active.duplicate()
	
	return true

# ============================================================================
# DEBUG AND INFORMATION
# ============================================================================

## Get critical damage status information
func get_critical_status() -> Dictionary:
	"""Get comprehensive critical damage status for debugging and UI."""
	var active_event_types: Array[String] = []
	var active_protocols: Array[String] = []
	
	for event in active_critical_events:
		active_event_types.append(event.type_name)
	
	for protocol_name in emergency_protocols_active.keys():
		active_protocols.append(protocol_name)
	
	return {
		"structural_integrity": structural_integrity,
		"progressive_damage_rate": progressive_damage_rate,
		"fire_spread_rate": fire_spread_rate,
		"atmosphere_loss_rate": atmosphere_loss_rate,
		"catastrophic_failure_timer": catastrophic_failure_timer,
		"active_critical_events": active_event_types,
		"active_protocols": active_protocols,
		"cascade_threshold": cascade_failure_threshold,
		"catastrophic_threshold": catastrophic_failure_threshold,
		"is_critical": structural_integrity <= cascade_failure_threshold,
		"is_catastrophic": catastrophic_failure_timer > 0.0
	}

## Get debug information string
func debug_info() -> String:
	"""Get debug information string."""
	return "[Critical SI:%.0f%% Events:%d Damage:%.1f/s Timer:%.1f]" % [
		structural_integrity,
		active_critical_events.size(),
		progressive_damage_rate,
		catastrophic_failure_timer
	]