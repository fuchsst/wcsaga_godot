class_name HotkeyTarget
extends Resource

## Hotkey target resource for storing keyed target assignments.
## Corresponds to WCS keyed_targets array functionality.

enum TargetType {
	NONE = 0,
	SHIP = 1,
	WING = 2, 
	SUBSYSTEM = 3,
	OBJECT = 4
}

@export var target_type: TargetType = TargetType.NONE
@export var target_name: String = ""           ## Name/callsign of target
@export var target_ship_class: String = ""     ## Ship class name if applicable
@export var target_wing: String = ""           ## Wing name if applicable  
@export var target_subsystem: String = ""      ## Subsystem name if applicable
@export var target_distance: float = 0.0       ## Distance to target when set
@export var is_valid: bool = false             ## Whether target is still valid
@export var hotkey_index: int = -1             ## Which hotkey slot (0-7)

func _init() -> void:
	clear_target()

## Clear the hotkey target
func clear_target() -> void:
	target_type = TargetType.NONE
	target_name = ""
	target_ship_class = ""
	target_wing = ""
	target_subsystem = ""
	target_distance = 0.0
	is_valid = false

## Set ship target
func set_ship_target(ship_name: String, ship_class: String = "", distance: float = 0.0) -> void:
	clear_target()
	target_type = TargetType.SHIP
	target_name = ship_name
	target_ship_class = ship_class
	target_distance = distance
	is_valid = true

## Set wing target  
func set_wing_target(wing_name: String, distance: float = 0.0) -> void:
	clear_target()
	target_type = TargetType.WING
	target_wing = wing_name
	target_name = wing_name
	target_distance = distance
	is_valid = true

## Set subsystem target
func set_subsystem_target(ship_name: String, subsystem_name: String, ship_class: String = "", distance: float = 0.0) -> void:
	clear_target()
	target_type = TargetType.SUBSYSTEM
	target_name = ship_name
	target_ship_class = ship_class
	target_subsystem = subsystem_name
	target_distance = distance
	is_valid = true

## Get display name for UI
func get_display_name() -> String:
	match target_type:
		TargetType.SHIP:
			if target_ship_class.is_empty():
				return target_name
			return target_name + " (" + target_ship_class + ")"
		TargetType.WING:
			return target_wing + " Wing"
		TargetType.SUBSYSTEM:
			if target_ship_class.is_empty():
				return target_name + "." + target_subsystem
			return target_name + " (" + target_ship_class + ")." + target_subsystem
		_:
			return "Empty"

## Check if target matches given parameters
func matches_target(check_name: String, check_type: TargetType = TargetType.SHIP) -> bool:
	return target_type == check_type and target_name == check_name and is_valid