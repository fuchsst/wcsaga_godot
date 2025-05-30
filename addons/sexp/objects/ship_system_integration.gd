class_name ShipSystemIntegration
extends RefCounted

## Integration layer for ship functions with collision, weapon, and subsystem management
##
## Provides seamless integration between SEXP ship functions and Godot's
## physics, weapon, and subsystem management systems, ensuring ship operations
## properly interact with all game systems and maintain consistency.
##
## Handles signal propagation, system state synchronization, and cross-system
## communication for ship-related operations.

signal subsystem_state_changed(ship_name: String, subsystem_name: String, old_state: String, new_state: String)
signal weapon_system_updated(ship_name: String, weapon_config: Dictionary)
signal collision_state_changed(ship_name: String, collision_enabled: bool)
signal ship_system_synchronized(ship_name: String, systems_updated: Array[String])

## Integration with Godot physics and collision systems
const CollisionSystemIntegration = preload("res://addons/sexp/objects/collision_system_integration.gd")
const WeaponSystemIntegration = preload("res://addons/sexp/objects/weapon_system_integration.gd")
const SubsystemManagerIntegration = preload("res://addons/sexp/objects/subsystem_manager_integration.gd")

## System references
var _ship_interface: ShipSystemInterface
var _object_ref_system: ObjectReferenceSystem
var _collision_integration: CollisionSystemIntegration
var _weapon_integration: WeaponSystemIntegration
var _subsystem_integration: SubsystemManagerIntegration

## System state tracking
var _ship_collision_states: Dictionary = {}   # ship_name -> collision_enabled
var _ship_weapon_states: Dictionary = {}      # ship_name -> weapon_config
var _ship_subsystem_states: Dictionary = {}   # ship_name -> subsystem_states
var _system_sync_pending: Dictionary = {}     # ship_name -> Array[String] (pending systems)

## Integration configuration
var _auto_sync_enabled: bool = true
var _collision_integration_enabled: bool = true
var _weapon_integration_enabled: bool = true
var _subsystem_integration_enabled: bool = true
var _signal_propagation_enabled: bool = true

## Singleton pattern
static var _instance: ShipSystemIntegration = null

static func get_instance() -> ShipSystemIntegration:
	if _instance == null:
		_instance = ShipSystemIntegration.new()
	return _instance

func _init():
	if _instance == null:
		_instance = self
	_initialize_system_integration()

func _initialize_system_integration():
	"""Initialize system integration components"""
	_ship_interface = ShipSystemInterface.get_instance()
	_object_ref_system = ObjectReferenceSystem.get_instance()
	
	# Initialize subsystem integrations
	_collision_integration = CollisionSystemIntegration.new()
	_weapon_integration = WeaponSystemIntegration.new()
	_subsystem_integration = SubsystemManagerIntegration.new()
	
	# Connect to ship interface signals
	_ship_interface.ship_destroyed.connect(_on_ship_destroyed)
	_ship_interface.ship_departed.connect(_on_ship_departed)
	_ship_interface.ship_subsystem_destroyed.connect(_on_subsystem_destroyed)
	
	# Connect to integration subsystem signals
	_collision_integration.collision_enabled_changed.connect(_on_collision_state_changed)
	_weapon_integration.weapon_configuration_changed.connect(_on_weapon_config_changed)
	_subsystem_integration.subsystem_status_changed.connect(_on_subsystem_status_changed)

## Main integration functions

func integrate_ship_damage(ship_name: String, damage_amount: float, damage_type: String = "kinetic") -> bool:
	"""
	Integrate ship damage with all relevant systems
	Args:
		ship_name: Ship to damage
		damage_amount: Amount of damage to apply
		damage_type: Type of damage (kinetic, energy, etc.)
	Returns:
		true if damage was successfully integrated
	"""
	var ship_node = _ship_interface.ship_name_lookup(ship_name, true)
	if ship_node == null:
		return false
	
	var integration_success = true
	var systems_updated: Array[String] = []
	
	# Apply damage to ship hull
	if ship_node.has_method("take_damage"):
		ship_node.take_damage(damage_amount, damage_type)
		systems_updated.append("hull")
	
	# Update collision system if ship is destroyed
	var hull_percentage = _ship_interface.get_ship_hull_percentage(ship_name)
	if hull_percentage <= 0:
		if _collision_integration_enabled:
			_collision_integration.disable_ship_collision(ship_node)
			systems_updated.append("collision")
		
		# Trigger weapon system shutdown
		if _weapon_integration_enabled:
			_weapon_integration.disable_all_weapons(ship_node)
			systems_updated.append("weapons")
		
		# Mark all subsystems as destroyed
		if _subsystem_integration_enabled:
			_subsystem_integration.destroy_all_subsystems(ship_node)
			systems_updated.append("subsystems")
	
	# Update ship system states
	_update_ship_system_states(ship_name, systems_updated)
	
	if _signal_propagation_enabled:
		ship_system_synchronized.emit(ship_name, systems_updated)
	
	return integration_success

func integrate_ship_destruction(ship_name: String, explosion_type: String = "standard") -> bool:
	"""
	Integrate ship destruction with all systems
	Args:
		ship_name: Ship to destroy
		explosion_type: Type of explosion effect
	Returns:
		true if destruction was successfully integrated
	"""
	var ship_node = _ship_interface.ship_name_lookup(ship_name, true)
	if ship_node == null:
		return false
	
	var systems_updated: Array[String] = []
	
	# Disable collision system
	if _collision_integration_enabled:
		_collision_integration.disable_ship_collision(ship_node)
		_collision_integration.create_debris_collision(ship_node, explosion_type)
		systems_updated.append("collision")
	
	# Shutdown weapon systems
	if _weapon_integration_enabled:
		_weapon_integration.trigger_weapon_explosions(ship_node)
		_weapon_integration.disable_all_weapons(ship_node)
		systems_updated.append("weapons")
	
	# Destroy all subsystems
	if _subsystem_integration_enabled:
		_subsystem_integration.trigger_subsystem_failures(ship_node)
		_subsystem_integration.destroy_all_subsystems(ship_node)
		systems_updated.append("subsystems")
	
	# Create explosion effects
	_create_ship_explosion_effects(ship_node, explosion_type)
	systems_updated.append("effects")
	
	# Update tracking
	_ship_collision_states.erase(ship_name)
	_ship_weapon_states.erase(ship_name)
	_ship_subsystem_states.erase(ship_name)
	
	if _signal_propagation_enabled:
		ship_system_synchronized.emit(ship_name, systems_updated)
	
	return true

func integrate_ship_position_change(ship_name: String, new_position: Vector3) -> bool:
	"""
	Integrate ship position change with physics and collision systems
	Args:
		ship_name: Ship to move
		new_position: New position
	Returns:
		true if position change was successfully integrated
	"""
	var ship_node = _ship_interface.ship_name_lookup(ship_name, true)
	if ship_node == null:
		return false
	
	var systems_updated: Array[String] = []
	
	# Update physics position
	if ship_node is RigidBody3D:
		ship_node.global_position = new_position
		ship_node.linear_velocity = Vector3.ZERO  # Stop movement
		systems_updated.append("physics")
	elif ship_node is CharacterBody3D:
		ship_node.global_position = new_position
		ship_node.velocity = Vector3.ZERO
		systems_updated.append("physics")
	elif ship_node is Node3D:
		ship_node.global_position = new_position
		systems_updated.append("transform")
	
	# Update collision system
	if _collision_integration_enabled:
		_collision_integration.update_collision_position(ship_node, new_position)
		systems_updated.append("collision")
	
	# Update weapon targeting systems
	if _weapon_integration_enabled:
		_weapon_integration.update_weapon_positions(ship_node)
		systems_updated.append("weapons")
	
	if _signal_propagation_enabled:
		ship_system_synchronized.emit(ship_name, systems_updated)
	
	return true

func integrate_subsystem_damage(ship_name: String, subsystem_name: String, damage_amount: float) -> bool:
	"""
	Integrate subsystem damage with related systems
	Args:
		ship_name: Ship containing the subsystem
		subsystem_name: Subsystem to damage
		damage_amount: Amount of damage to apply
	Returns:
		true if subsystem damage was successfully integrated
	"""
	var ship_node = _ship_interface.ship_name_lookup(ship_name, true)
	if ship_node == null:
		return false
	
	var systems_updated: Array[String] = []
	
	# Apply subsystem damage
	if _subsystem_integration_enabled:
		var damage_applied = _subsystem_integration.damage_subsystem(ship_node, subsystem_name, damage_amount)
		if damage_applied:
			systems_updated.append("subsystems")
			
			# Check if subsystem was destroyed
			var subsystem_health = _ship_interface.get_ship_subsystem_health(ship_name, subsystem_name)
			if subsystem_health <= 0:
				_handle_subsystem_destruction(ship_node, subsystem_name, systems_updated)
	
	# Update ship system states
	_update_ship_subsystem_state(ship_name, subsystem_name)
	
	if _signal_propagation_enabled and not systems_updated.is_empty():
		ship_system_synchronized.emit(ship_name, systems_updated)
	
	return true

## Subsystem integration

func _handle_subsystem_destruction(ship_node: Node, subsystem_name: String, systems_updated: Array[String]):
	"""Handle the effects of subsystem destruction"""
	var subsystem_type = _get_subsystem_type(subsystem_name)
	
	match subsystem_type:
		"engine", "engines":
			# Reduce ship speed and maneuverability
			if ship_node.has_method("reduce_engine_power"):
				ship_node.reduce_engine_power(0.5)
			systems_updated.append("propulsion")
		
		"weapon", "weapons", "turret":
			# Disable specific weapon systems
			if _weapon_integration_enabled:
				_weapon_integration.disable_weapon_group(ship_node, subsystem_name)
				systems_updated.append("weapons")
		
		"sensor", "sensors", "radar":
			# Reduce targeting accuracy and range
			if ship_node.has_method("degrade_sensors"):
				ship_node.degrade_sensors(0.3)
			systems_updated.append("sensors")
		
		"navigation", "nav", "pilot":
			# Affect maneuverability and autopilot
			if ship_node.has_method("degrade_navigation"):
				ship_node.degrade_navigation(0.4)
			systems_updated.append("navigation")
		
		"communication", "comm":
			# Reduce communication range and effectiveness
			if ship_node.has_method("degrade_communications"):
				ship_node.degrade_communications(0.6)
			systems_updated.append("communications")

## Collision system integration

func integrate_ship_visibility_change(ship_name: String, visible: bool) -> bool:
	"""
	Integrate ship visibility change with collision and targeting systems
	Args:
		ship_name: Ship to change visibility for
		visible: New visibility state
	Returns:
		true if visibility change was successfully integrated
	"""
	var ship_node = _ship_interface.ship_name_lookup(ship_name, true)
	if ship_node == null:
		return false
	
	var systems_updated: Array[String] = []
	
	# Update visual visibility
	if ship_node is CanvasItem:
		ship_node.visible = visible
		systems_updated.append("visual")
	elif ship_node is Node3D:
		ship_node.visible = visible
		systems_updated.append("visual")
	
	# Update collision detection
	if _collision_integration_enabled:
		_collision_integration.set_collision_detection(ship_node, visible)
		systems_updated.append("collision")
	
	# Update weapon targeting
	if _weapon_integration_enabled:
		_weapon_integration.set_targeting_visibility(ship_node, visible)
		systems_updated.append("targeting")
	
	# Update radar/sensor visibility
	if ship_node.has_method("set_radar_visible"):
		ship_node.set_radar_visible(visible)
		systems_updated.append("radar")
	
	if _signal_propagation_enabled:
		ship_system_synchronized.emit(ship_name, systems_updated)
	
	return true

## Weapon system integration

func integrate_weapon_configuration_change(ship_name: String, weapon_config: Dictionary) -> bool:
	"""
	Integrate weapon configuration changes
	Args:
		ship_name: Ship to update weapons for
		weapon_config: New weapon configuration
	Returns:
		true if weapon configuration was successfully integrated
	"""
	var ship_node = _ship_interface.ship_name_lookup(ship_name, true)
	if ship_node == null:
		return false
	
	var systems_updated: Array[String] = []
	
	if _weapon_integration_enabled:
		var config_applied = _weapon_integration.apply_weapon_configuration(ship_node, weapon_config)
		if config_applied:
			systems_updated.append("weapons")
			
			# Update power consumption if ship has power management
			if ship_node.has_method("update_power_consumption"):
				ship_node.update_power_consumption()
				systems_updated.append("power")
	
	# Update weapon state tracking
	_ship_weapon_states[ship_name] = weapon_config.duplicate()
	
	if _signal_propagation_enabled:
		weapon_system_updated.emit(ship_name, weapon_config)
		ship_system_synchronized.emit(ship_name, systems_updated)
	
	return true

## System state management

func _update_ship_system_states(ship_name: String, updated_systems: Array[String]):
	"""Update tracked system states for a ship"""
	for system in updated_systems:
		match system:
			"collision":
				var ship_node = _ship_interface.ship_name_lookup(ship_name, true)
				if ship_node:
					_ship_collision_states[ship_name] = _collision_integration.is_collision_enabled(ship_node)
			"weapons":
				_update_ship_weapon_state(ship_name)
			"subsystems":
				_update_ship_subsystem_state(ship_name)

func _update_ship_weapon_state(ship_name: String):
	"""Update weapon state tracking for a ship"""
	var ship_node = _ship_interface.ship_name_lookup(ship_name, true)
	if ship_node and _weapon_integration_enabled:
		_ship_weapon_states[ship_name] = _weapon_integration.get_weapon_configuration(ship_node)

func _update_ship_subsystem_state(ship_name: String, specific_subsystem: String = ""):
	"""Update subsystem state tracking for a ship"""
	var ship_node = _ship_interface.ship_name_lookup(ship_name, true)
	if ship_node and _subsystem_integration_enabled:
		if specific_subsystem.is_empty():
			_ship_subsystem_states[ship_name] = _subsystem_integration.get_all_subsystem_states(ship_node)
		else:
			if not _ship_subsystem_states.has(ship_name):
				_ship_subsystem_states[ship_name] = {}
			_ship_subsystem_states[ship_name][specific_subsystem] = _subsystem_integration.get_subsystem_state(ship_node, specific_subsystem)

## Signal handlers

func _on_ship_destroyed(ship_name: String, ship_node: Node):
	"""Handle ship destruction event"""
	if _auto_sync_enabled:
		integrate_ship_destruction(ship_name, "standard")

func _on_ship_departed(ship_name: String, ship_node: Node):
	"""Handle ship departure event"""
	# Clean up system states
	_ship_collision_states.erase(ship_name)
	_ship_weapon_states.erase(ship_name)
	_ship_subsystem_states.erase(ship_name)

func _on_subsystem_destroyed(ship_name: String, subsystem_name: String):
	"""Handle subsystem destruction event"""
	if _auto_sync_enabled:
		var ship_node = _ship_interface.ship_name_lookup(ship_name, true)
		if ship_node:
			var systems_updated: Array[String] = []
			_handle_subsystem_destruction(ship_node, subsystem_name, systems_updated)
			if _signal_propagation_enabled:
				subsystem_state_changed.emit(ship_name, subsystem_name, "active", "destroyed")

func _on_collision_state_changed(ship_node: Node, collision_enabled: bool):
	"""Handle collision state change from collision integration"""
	var ship_name = _get_ship_name_from_node(ship_node)
	if not ship_name.is_empty():
		_ship_collision_states[ship_name] = collision_enabled
		if _signal_propagation_enabled:
			collision_state_changed.emit(ship_name, collision_enabled)

func _on_weapon_config_changed(ship_node: Node, weapon_config: Dictionary):
	"""Handle weapon configuration change from weapon integration"""
	var ship_name = _get_ship_name_from_node(ship_node)
	if not ship_name.is_empty():
		_ship_weapon_states[ship_name] = weapon_config.duplicate()
		if _signal_propagation_enabled:
			weapon_system_updated.emit(ship_name, weapon_config)

func _on_subsystem_status_changed(ship_node: Node, subsystem_name: String, old_status: String, new_status: String):
	"""Handle subsystem status change from subsystem integration"""
	var ship_name = _get_ship_name_from_node(ship_node)
	if not ship_name.is_empty():
		_update_ship_subsystem_state(ship_name, subsystem_name)
		if _signal_propagation_enabled:
			subsystem_state_changed.emit(ship_name, subsystem_name, old_status, new_status)

## Utility functions

func _get_ship_name_from_node(ship_node: Node) -> String:
	"""Get ship name from ship node"""
	if ship_node.has_method("get_ship_name"):
		return ship_node.get_ship_name()
	elif ship_node.has_property("ship_name"):
		return ship_node.get("ship_name")
	else:
		return ship_node.name

func _get_subsystem_type(subsystem_name: String) -> String:
	"""Determine subsystem type from name"""
	var name_lower = subsystem_name.to_lower()
	
	if name_lower.contains("engine") or name_lower.contains("propulsion") or name_lower.contains("thruster"):
		return "engine"
	elif name_lower.contains("weapon") or name_lower.contains("turret") or name_lower.contains("gun"):
		return "weapon"
	elif name_lower.contains("sensor") or name_lower.contains("radar") or name_lower.contains("targeting"):
		return "sensor"
	elif name_lower.contains("nav") or name_lower.contains("pilot") or name_lower.contains("helm"):
		return "navigation"
	elif name_lower.contains("comm") or name_lower.contains("radio"):
		return "communication"
	else:
		return "unknown"

func _create_ship_explosion_effects(ship_node: Node, explosion_type: String):
	"""Create explosion effects for ship destruction"""
	# This would integrate with the effects system
	if ship_node.has_method("create_explosion"):
		ship_node.create_explosion(explosion_type)
	elif ship_node.has_method("explode"):
		ship_node.explode()

## Public API

func get_ship_collision_state(ship_name: String) -> bool:
	"""Get current collision state for a ship"""
	return _ship_collision_states.get(ship_name, true)

func get_ship_weapon_configuration(ship_name: String) -> Dictionary:
	"""Get current weapon configuration for a ship"""
	return _ship_weapon_states.get(ship_name, {})

func get_ship_subsystem_states(ship_name: String) -> Dictionary:
	"""Get current subsystem states for a ship"""
	return _ship_subsystem_states.get(ship_name, {})

func get_integration_statistics() -> Dictionary:
	"""Get system integration statistics"""
	return {
		"tracked_collision_states": _ship_collision_states.size(),
		"tracked_weapon_states": _ship_weapon_states.size(),
		"tracked_subsystem_states": _ship_subsystem_states.size(),
		"auto_sync_enabled": _auto_sync_enabled,
		"integrations_enabled": {
			"collision": _collision_integration_enabled,
			"weapons": _weapon_integration_enabled,
			"subsystems": _subsystem_integration_enabled
		}
	}

func configure_integration(config: Dictionary):
	"""
	Configure system integration behavior
	Args:
		config: Configuration options
	"""
	if config.has("auto_sync_enabled"):
		_auto_sync_enabled = config["auto_sync_enabled"]
	
	if config.has("collision_integration_enabled"):
		_collision_integration_enabled = config["collision_integration_enabled"]
	
	if config.has("weapon_integration_enabled"):
		_weapon_integration_enabled = config["weapon_integration_enabled"]
	
	if config.has("subsystem_integration_enabled"):
		_subsystem_integration_enabled = config["subsystem_integration_enabled"]
	
	if config.has("signal_propagation_enabled"):
		_signal_propagation_enabled = config["signal_propagation_enabled"]