class_name SexpShipStatusFunctions
extends RefCounted

## SEXP ship status query functions
##
## Implements WCS-compatible ship status query functions including health, shields,
## position, velocity, distance calculations, and subsystem status following
## exact WCS SEXP interface patterns and return value formats.
##
## Integrates with WCS Asset Core addon for consistent ship data handling and
## follows EPIC-002 asset structure patterns for ship reference management.

const ShipSystemInterface = preload("res://addons/sexp/objects/ship_system_interface.gd")
const ShipErrorHandler = preload("res://addons/sexp/objects/ship_error_handler.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpFunction = preload("res://addons/sexp/core/sexp_function.gd")

## Ship hull and shield status functions

class ShipHullFunction extends SexpFunction:
	func _init():
		super._init("hits-left", "Get ship hull health percentage", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("hits-left requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("hits-left requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var error_handler = ShipErrorHandler.get_instance()
		
		# Validate ship reference before operation
		var validation_result = error_handler.validate_ship_reference(ship_name, "hits-left")
		if validation_result != ShipErrorHandler.ErrorCode.NONE:
			# Handle the error and return appropriate SEXP result
			match validation_result:
				ShipErrorHandler.ErrorCode.SHIP_DESTROYED, ShipErrorHandler.ErrorCode.SHIP_DEPARTED:
					return SexpResult.create_number(SexpResult.SEXP_NAN_FOREVER)
				ShipErrorHandler.ErrorCode.SHIP_NOT_FOUND:
					return SexpResult.create_number(SexpResult.SEXP_NAN)
				_:
					return SexpResult.create_error("Invalid ship reference: " + ship_name)
		
		var ship_interface = ShipSystemInterface.get_instance()
		var hull_percentage = ship_interface.get_ship_hull_percentage(ship_name)
		
		return SexpResult.create_number(hull_percentage)

class ShipShieldsFunction extends SexpFunction:
	func _init():
		super._init("shields-left", "Get ship shield health percentage", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("shields-left requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("shields-left requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var shield_percentage = ship_interface.get_ship_shield_percentage(ship_name)
		
		return SexpResult.create_number(shield_percentage)

## Ship position and distance functions

class ShipDistanceFunction extends SexpFunction:
	func _init():
		super._init("distance", "Get distance between two ships", ["ship1", "ship2"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 2:
			return SexpResult.create_error("distance requires exactly 2 arguments (ship names)")
		
		if not args[0].is_string() or not args[1].is_string():
			return SexpResult.create_error("distance requires ship names as strings")
		
		var ship_name1 = args[0].get_string_value()
		var ship_name2 = args[1].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var distance = ship_interface.get_ship_distance(ship_name1, ship_name2)
		
		return SexpResult.create_number(distance)

class ShipPositionXFunction extends SexpFunction:
	func _init():
		super._init("ship-pos-x", "Get ship X coordinate", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-pos-x requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-pos-x requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var position = ship_interface.get_ship_position(ship_name)
		
		if position == Vector3.ZERO and ship_interface.is_ship_destroyed(ship_name):
			return SexpResult.create_number(SexpResult.SEXP_NAN_FOREVER)
		elif position == Vector3.ZERO:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		return SexpResult.create_number(position.x)

class ShipPositionYFunction extends SexpFunction:
	func _init():
		super._init("ship-pos-y", "Get ship Y coordinate", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-pos-y requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-pos-y requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var position = ship_interface.get_ship_position(ship_name)
		
		if position == Vector3.ZERO and ship_interface.is_ship_destroyed(ship_name):
			return SexpResult.create_number(SexpResult.SEXP_NAN_FOREVER)
		elif position == Vector3.ZERO:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		return SexpResult.create_number(position.y)

class ShipPositionZFunction extends SexpFunction:
	func _init():
		super._init("ship-pos-z", "Get ship Z coordinate", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-pos-z requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-pos-z requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var position = ship_interface.get_ship_position(ship_name)
		
		if position == Vector3.ZERO and ship_interface.is_ship_destroyed(ship_name):
			return SexpResult.create_number(SexpResult.SEXP_NAN_FOREVER)
		elif position == Vector3.ZERO:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		return SexpResult.create_number(position.z)

## Ship velocity and speed functions

class ShipVelocityXFunction extends SexpFunction:
	func _init():
		super._init("ship-vel-x", "Get ship X velocity", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-vel-x requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-vel-x requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var velocity = ship_interface.get_ship_velocity(ship_name)
		
		if velocity == Vector3.ZERO and ship_interface.is_ship_destroyed(ship_name):
			return SexpResult.create_number(SexpResult.SEXP_NAN_FOREVER)
		elif velocity == Vector3.ZERO:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		return SexpResult.create_number(velocity.x)

class ShipVelocityYFunction extends SexpFunction:
	func _init():
		super._init("ship-vel-y", "Get ship Y velocity", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-vel-y requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-vel-y requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var velocity = ship_interface.get_ship_velocity(ship_name)
		
		if velocity == Vector3.ZERO and ship_interface.is_ship_destroyed(ship_name):
			return SexpResult.create_number(SexpResult.SEXP_NAN_FOREVER)
		elif velocity == Vector3.ZERO:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		return SexpResult.create_number(velocity.y)

class ShipVelocityZFunction extends SexpFunction:
	func _init():
		super._init("ship-vel-z", "Get ship Z velocity", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-vel-z requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-vel-z requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var velocity = ship_interface.get_ship_velocity(ship_name)
		
		if velocity == Vector3.ZERO and ship_interface.is_ship_destroyed(ship_name):
			return SexpResult.create_number(SexpResult.SEXP_NAN_FOREVER)
		elif velocity == Vector3.ZERO:
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		return SexpResult.create_number(velocity.z)

class ShipCurrentSpeedFunction extends SexpFunction:
	func _init():
		super._init("current-speed", "Get ship current speed (velocity magnitude)", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("current-speed requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("current-speed requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		
		# Check if ship is destroyed or departed
		if ship_interface.is_ship_destroyed(ship_name) or ship_interface.is_ship_departed(ship_name):
			return SexpResult.create_number(SexpResult.SEXP_NAN_FOREVER)
		
		var speed = ship_interface.get_ship_speed(ship_name)
		if speed < 0.0:  # Ship not found
			return SexpResult.create_number(SexpResult.SEXP_NAN)
		
		return SexpResult.create_number(speed)

## Subsystem status functions

class ShipSubsystemHealthFunction extends SexpFunction:
	func _init():
		super._init("hits-left-subsystem", "Get ship subsystem health percentage", ["ship", "subsystem"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 2:
			return SexpResult.create_error("hits-left-subsystem requires exactly 2 arguments (ship name, subsystem name)")
		
		if not args[0].is_string() or not args[1].is_string():
			return SexpResult.create_error("hits-left-subsystem requires ship and subsystem names as strings")
		
		var ship_name = args[0].get_string_value()
		var subsystem_name = args[1].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var subsystem_health = ship_interface.get_ship_subsystem_health(ship_name, subsystem_name)
		
		return SexpResult.create_number(subsystem_health)

## Ship existence and state query functions

class ShipExistsFunction extends SexpFunction:
	func _init():
		super._init("ship-exists", "Check if ship exists in mission", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-exists requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-exists requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		return SexpResult.create_boolean(ship_node != null)

class ShipIsDestroyedFunction extends SexpFunction:
	func _init():
		super._init("ship-is-destroyed", "Check if ship has been destroyed", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-is-destroyed requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-is-destroyed requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var is_destroyed = ship_interface.is_ship_destroyed(ship_name)
		
		return SexpResult.create_boolean(is_destroyed)

class ShipIsDepartedFunction extends SexpFunction:
	func _init():
		super._init("ship-is-departed", "Check if ship has departed", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-is-departed requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-is-departed requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var is_departed = ship_interface.is_ship_departed(ship_name)
		
		return SexpResult.create_boolean(is_departed)

## Advanced ship query functions

class ShipTypeFunction extends SexpFunction:
	func _init():
		super._init("ship-type", "Get ship class/type name", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-type requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-type requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_string("")  # Ship not found
		
		# Get ship type/class
		var ship_type: String = ""
		if ship_node.has_method("get_ship_type"):
			ship_type = ship_node.get_ship_type()
		elif ship_node.has_method("get_ship_class"):
			ship_type = ship_node.get_ship_class()
		elif ship_node.has_property("ship_type"):
			ship_type = ship_node.get("ship_type")
		elif ship_node.has_property("ship_class"):
			ship_type = ship_node.get("ship_class")
		
		return SexpResult.create_string(ship_type)

class ShipTeamFunction extends SexpFunction:
	func _init():
		super._init("ship-team", "Get ship team/faction", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-team requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-team requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_number(SexpResult.SEXP_NAN)  # Ship not found
		
		# Get ship team
		var team: int = -1
		if ship_node.has_method("get_team"):
			team = ship_node.get_team()
		elif ship_node.has_method("get_faction"):
			team = ship_node.get_faction()
		elif ship_node.has_property("team"):
			team = ship_node.get("team")
		elif ship_node.has_property("faction"):
			team = ship_node.get("faction")
		
		return SexpResult.create_number(team)

class ShipIsPlayerFunction extends SexpFunction:
	func _init():
		super._init("ship-is-player", "Check if ship is player-controlled", ["ship"])
		function_type = SexpFunction.FunctionType.QUERY
		category = "Ship Status"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		if args.size() != 1:
			return SexpResult.create_error("ship-is-player requires exactly 1 argument (ship name)")
		
		if not args[0].is_string():
			return SexpResult.create_error("ship-is-player requires ship name as string")
		
		var ship_name = args[0].get_string_value()
		var ship_interface = ShipSystemInterface.get_instance()
		var ship_node = ship_interface.ship_name_lookup(ship_name, true)
		
		if ship_node == null:
			return SexpResult.create_boolean(false)  # Ship not found
		
		# Check if player ship
		var is_player = false
		if ship_node.has_method("is_player_ship"):
			is_player = ship_node.is_player_ship()
		elif ship_node.is_in_group("player_ships"):
			is_player = true
		elif ship_node.has_meta("is_player"):
			is_player = ship_node.get_meta("is_player")
		
		return SexpResult.create_boolean(is_player)