class_name SexpShipModificationFunctions
extends RefCounted

## SEXP ship state modification functions
##
## Implements WCS-compatible ship modification functions including hull/shield damage,
## ship destruction, position/velocity modification, and subsystem control following
## exact WCS SEXP interface patterns and behaviors.
##
## Integrates with WCS Asset Core addon for consistent ship data handling and
## follows EPIC-002 asset structure patterns for ship reference management.

const ShipSystemInterface = preload("res://addons/sexp/objects/ship_system_interface.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpFunction = preload("res://addons/sexp/core/sexp_function.gd")

## Ship hull and shield modification functions

class SetHullStrengthFunction extends SexpFunction:
	func _init():
		super._init("set-hull-strength", "Set ship hull health percentage", ["ship", "percentage"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 2:
			return SexpResult.create_error("set-hull-strength requires exactly 2 arguments (ship name, percentage)")
		
		if not args[0].is_string() or not args[1].is_number():
			return SexpResult.create_error("set-hull-strength requires ship name as string and percentage as number")
		
		var ship_name = args[0].get_string_value()
		var percentage = args[1].get_number_value()
		
		# Clamp percentage to valid range
		percentage = clamp(percentage, 0.0, 100.0)
		
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		# Set hull health
		var success = false
		if ship_node.has_method("set_hull_percentage"):
			ship_node.set_hull_percentage(percentage / 100.0)
			success = true
		elif ship_node.has_method("set_health_percentage"):
			ship_node.set_health_percentage(percentage / 100.0)
			success = true
		elif ship_node.has_property("health") and ship_node.has_property("max_health"):
			var max_health = ship_node.get("max_health") as float
			ship_node.set("health", (percentage / 100.0) * max_health)
			success = true
		
		# If hull reaches 0, mark ship as destroyed
		if success and percentage <= 0.0:
			ship_interface.register_ship_destroyed(ship_name, ship_node)
			_trigger_ship_destruction(ship_node)
		
		# Emit cache invalidation for ship-related dependencies
		if success:
			ship_interface.cache_invalidation_required.emit("obj:" + ship_name)
		
		return SexpResult.create_boolean(success)

class SetShieldStrengthFunction extends SexpFunction:
	func _init():
		super._init("set-shield-strength", "Set ship shield health percentage", ["ship", "percentage"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 2:
			return SexpResult.create_error("set-shield-strength requires exactly 2 arguments (ship name, percentage)")
		
		if not args[0].is_string() or not args[1].is_number():
			return SexpResult.create_error("set-shield-strength requires ship name as string and percentage as number")
		
		var ship_name = args[0].get_string_value()
		var percentage = args[1].get_number_value()
		
		# Clamp percentage to valid range
		percentage = clamp(percentage, 0.0, 100.0)
		
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		# Set shield health
		var success = false
		if ship_node.has_method("set_shield_percentage"):
			ship_node.set_shield_percentage(percentage / 100.0)
			success = true
		elif ship_node.has_property("shields") and ship_node.has_property("max_shields"):
			var max_shields = ship_node.get("max_shields") as float
			if max_shields > 0.0:
				ship_node.set("shields", (percentage / 100.0) * max_shields)
				success = true
		
		return SexpResult.create_boolean(success)

class DamageShipFunction extends SexpFunction:
	func _init():
		super._init("damage-ship", "Apply damage to ship hull", ["ship", "damage_amount"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 2:
			return SexpResult.create_error("damage-ship requires exactly 2 arguments (ship name, damage amount)")
		
		if not args[0].is_string() or not args[1].is_number():
			return SexpResult.create_error("damage-ship requires ship name as string and damage as number")
		
		var ship_name = args[0].get_string_value()
		var damage_amount = args[1].get_number_value()
		
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		# Apply damage
		var success = false
		if ship_node.has_method("take_damage"):
			ship_node.take_damage(damage_amount)
			success = true
		elif ship_node.has_method("apply_damage"):
			ship_node.apply_damage(damage_amount)
			success = true
		elif ship_node.has_property("health"):
			var current_health = ship_node.get("health") as float
			ship_node.set("health", max(0.0, current_health - damage_amount))
			success = true
		
		# Check if ship was destroyed by damage
		if success:
			var current_hull = ship_interface.get_ship_hull_percentage(ship_name)
			if current_hull <= 0:
				ship_interface.register_ship_destroyed(ship_name, ship_node)
				_trigger_ship_destruction(ship_node)
		
		return SexpResult.create_boolean(success)

## Ship destruction and removal functions

class DestroyShipFunction extends SexpFunction:
	func _init():
		super._init("destroy-ship", "Destroy ship with explosion", ["ship"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("destroy-ship requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("destroy-ship requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		# Mark ship as destroyed
		ship_interface.register_ship_destroyed(ship_name, ship_node)
		
		# Trigger destruction sequence
		_trigger_ship_destruction(ship_node, true)  # With explosion
		
		return SexpResult.create_boolean(true)

class VanishShipFunction extends SexpFunction:
	func _init():
		super._init("ship-vanish", "Remove ship without explosion", ["ship"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-vanish requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-vanish requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		# Mark ship as departed (vanished)
		ship_interface.register_ship_departed(ship_name, ship_node)
		
		# Remove ship without explosion
		_remove_ship_quietly(ship_node)
		
		return SexpResult.create_boolean(true)

## Ship position and movement modification functions

class SetShipPositionFunction extends SexpFunction:
	func _init():
		super._init("set-ship-position", "Set ship world position", ["ship", "x", "y", "z"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 4:
			return SexpResult.create_error("set-ship-position requires exactly 4 arguments (ship name, x, y, z)")
		
		if not args[0].is_string():
			return SexpResult.create_error("set-ship-position requires ship name as string")
		
		for i in range(1, 4):
			if not args[i].is_number():
				return SexpResult.create_error("set-ship-position requires x, y, z coordinates as numbers")
		
		var ship_name = args[0].get_string_value()
		var position = Vector3(
			args[1].get_number_value(),
			args[2].get_number_value(), 
			args[3].get_number_value()
		)
		
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		# Set position
		var success = false
		if ship_node is Node3D:
			ship_node.global_position = position
			success = true
		elif ship_node.has_method("set_position"):
			ship_node.set_position(position)
			success = true
		elif ship_node.has_property("position"):
			ship_node.set("position", position)
			success = true
		
		return SexpResult.create_boolean(success)

class SetShipVelocityFunction extends SexpFunction:
	func _init():
		super._init("set-ship-velocity", "Set ship velocity vector", ["ship", "vx", "vy", "vz"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 4:
			return SexpResult.create_error("set-ship-velocity requires exactly 4 arguments (ship name, vx, vy, vz)")
		
		if not args[0].is_string():
			return SexpResult.create_error("set-ship-velocity requires ship name as string")
		
		for i in range(1, 4):
			if not args[i].is_number():
				return SexpResult.create_error("set-ship-velocity requires vx, vy, vz velocities as numbers")
		
		var ship_name = args[0].get_string_value()
		var velocity = Vector3(
			args[1].get_number_value(),
			args[2].get_number_value(),
			args[3].get_number_value()
		)
		
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		# Set velocity
		var success = false
		if ship_node.has_method("set_velocity"):
			ship_node.set_velocity(velocity)
			success = true
		elif ship_node is RigidBody3D:
			ship_node.linear_velocity = velocity
			success = true
		elif ship_node is CharacterBody3D:
			ship_node.velocity = velocity
			success = true
		elif ship_node.has_property("velocity"):
			ship_node.set("velocity", velocity)
			success = true
		
		return SexpResult.create_boolean(success)

## Ship visibility and state control functions

class ShipInvisibleFunction extends SexpFunction:
	func _init():
		super._init("ship-invisible", "Make ship invisible", ["ship"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-invisible requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-invisible requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		return SexpResult.create_boolean(_set_ship_visibility(ship_node, false))

class ShipVisibleFunction extends SexpFunction:
	func _init():
		super._init("ship-visible", "Make ship visible", ["ship"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-visible requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-visible requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		return SexpResult.create_boolean(_set_ship_visibility(ship_node, true))

class ShipInvulnerableFunction extends SexpFunction:
	func _init():
		super._init("ship-invulnerable", "Make ship invulnerable to damage", ["ship"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-invulnerable requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-invulnerable requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		return SexpResult.create_boolean(_set_ship_invulnerability(ship_node, true))

class ShipVulnerableFunction extends SexpFunction:
	func _init():
		super._init("ship-vulnerable", "Make ship vulnerable to damage", ["ship"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-vulnerable requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-vulnerable requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		return SexpResult.create_boolean(_set_ship_invulnerability(ship_node, false))

## Subsystem modification functions

class SetSubsystemStrengthFunction extends SexpFunction:
	func _init():
		super._init("set-subsystem-strength", "Set ship subsystem health percentage", ["ship", "subsystem", "percentage"])
		function_type = SexpFunction.FunctionType.ACTION
		category = "Ship Modification"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 3:
			return SexpResult.create_error("set-subsystem-strength requires exactly 3 arguments (ship name, subsystem name, percentage)")
		
		if not args[0].is_string() or not args[1].is_string() or not args[2].is_number():
			return SexpResult.create_error("set-subsystem-strength requires ship name, subsystem name as strings and percentage as number")
		
		var ship_name = args[0].get_string_value()
		var subsystem_name = args[1].get_string_value()
		var percentage = clamp(args[2].get_number_value(), 0.0, 100.0)
		
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		# Set subsystem health
		var success = false
		if ship_node.has_method("set_subsystem_health"):
			success = ship_node.set_subsystem_health(subsystem_name, percentage / 100.0)
		else:
			var subsystem_node = _find_subsystem_node(ship_node, subsystem_name)
			if subsystem_node != null:
				success = _set_subsystem_health_percentage(subsystem_node, percentage / 100.0)
		
		# Emit signal if subsystem was destroyed
		if success and percentage <= 0.0:
			ship_interface.ship_subsystem_destroyed.emit(ship_name, subsystem_name)
		
		return SexpResult.create_boolean(success)

## Utility functions for ship modification

static func _trigger_ship_destruction(ship_node: Node, with_explosion: bool = true):
	"""Trigger ship destruction sequence"""
	if ship_node.has_method("destroy"):
		ship_node.destroy(with_explosion)
	elif ship_node.has_method("explode") and with_explosion:
		ship_node.explode()
	elif ship_node.has_method("queue_free"):
		# Create explosion effect if possible
		if with_explosion:
			_create_explosion_effect(ship_node)
		ship_node.queue_free()

static func _remove_ship_quietly(ship_node: Node):
	"""Remove ship without destruction effects"""
	if ship_node.has_method("vanish"):
		ship_node.vanish()
	elif ship_node.has_method("hide"):
		ship_node.hide()
		# Disable physics and collision
		_disable_ship_physics(ship_node)
	else:
		ship_node.queue_free()

static func _set_ship_visibility(ship_node: Node, visible: bool) -> bool:
	"""Set ship visibility state"""
	var success = false
	
	if ship_node.has_method("set_visible"):
		ship_node.set_visible(visible)
		success = true
	elif ship_node is CanvasItem:
		ship_node.visible = visible
		success = true
	elif ship_node is Node3D:
		ship_node.visible = visible
		success = true
	elif ship_node.has_property("visible"):
		ship_node.set("visible", visible)
		success = true
	
	# Also handle rendering layers for radar/targeting
	if ship_node.has_method("set_radar_visible"):
		ship_node.set_radar_visible(visible)
	
	return success

static func _set_ship_invulnerability(ship_node: Node, invulnerable: bool) -> bool:
	"""Set ship invulnerability state"""
	var success = false
	
	if ship_node.has_method("set_invulnerable"):
		ship_node.set_invulnerable(invulnerable)
		success = true
	elif ship_node.has_property("invulnerable"):
		ship_node.set("invulnerable", invulnerable)
		success = true
	elif ship_node.has_property("can_take_damage"):
		ship_node.set("can_take_damage", not invulnerable)
		success = true
	
	# Also disable collision for invulnerable ships
	if success and ship_node is CollisionObject3D:
		for child in ship_node.get_children():
			if child is CollisionShape3D:
				child.disabled = invulnerable
	
	return success

static func _find_subsystem_node(ship_node: Node, subsystem_name: String) -> Node:
	"""Find subsystem node by name"""
	for child in ship_node.get_children():
		if child.name.to_lower() == subsystem_name.to_lower():
			return child
		if child.is_in_group("subsystems") and child.has_method("get_subsystem_name"):
			if child.get_subsystem_name().to_lower() == subsystem_name.to_lower():
				return child
	return null

static func _set_subsystem_health_percentage(subsystem_node: Node, percentage: float) -> bool:
	"""Set health percentage on subsystem node"""
	var success = false
	
	if subsystem_node.has_method("set_health_percentage"):
		subsystem_node.set_health_percentage(percentage)
		success = true
	elif subsystem_node.has_property("health") and subsystem_node.has_property("max_health"):
		var max_health = subsystem_node.get("max_health") as float
		subsystem_node.set("health", percentage * max_health)
		success = true
	
	return success

static func _create_explosion_effect(ship_node: Node):
	"""Create explosion visual effect at ship position"""
	# This would integrate with the ship's explosion system
	if ship_node.has_method("create_explosion"):
		ship_node.create_explosion()
	elif ship_node.has_method("get_explosion_effect"):
		var explosion = ship_node.get_explosion_effect()
		if explosion:
			explosion.global_position = ship_node.global_position if ship_node is Node3D else Vector3.ZERO

static func _disable_ship_physics(ship_node: Node):
	"""Disable ship physics and collision"""
	if ship_node is RigidBody3D:
		ship_node.freeze = true
		ship_node.collision_layer = 0
		ship_node.collision_mask = 0
	elif ship_node is CharacterBody3D:
		ship_node.collision_layer = 0
		ship_node.collision_mask = 0
	elif ship_node is CollisionObject3D:
		ship_node.collision_layer = 0
		ship_node.collision_mask = 0