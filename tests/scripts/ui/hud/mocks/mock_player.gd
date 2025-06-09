extends Node3D

## Mock Player for HUD-005 Testing
## Simulates a player ship with targeting capabilities

# Player ship properties
var ship_name: String = "Test Player Ship"
var ship_class: String = "Fighter"
var ship_type: String = "Interceptor"

# Movement
var velocity: Vector3 = Vector3(0, 0, 0)
var max_speed: float = 150.0

# Current target
var current_target: Node = null

# Weapon loadout
var weapon_loadout: Array[Dictionary] = [
	{"name": "laser_cannon", "type": "energy", "count": 4, "range": 1200.0, "projectile_speed": 1800.0},
	{"name": "missile_launcher", "type": "guided", "count": 2, "range": 2500.0, "projectile_speed": 1000.0}
]

## Movement methods
func get_velocity() -> Vector3:
	return velocity

func get_max_speed() -> float:
	return max_speed

func get_player_position() -> Vector3:
	return global_position

## Targeting methods
func get_current_target() -> Node:
	return current_target

func set_current_target(target: Node) -> void:
	current_target = target

## Weapon methods
func get_weapon_loadout() -> Array:
	var loadout: Array = []
	for weapon in weapon_loadout:
		loadout.append(weapon)
	return loadout

## Ship identification
func get_ship_name() -> String:
	return ship_name

func get_ship_class() -> String:
	return ship_class

func get_ship_type() -> String:
	return ship_type

## Test utility methods
func set_velocity_vector(new_velocity: Vector3) -> void:
	velocity = new_velocity

func set_player_position(new_position: Vector3) -> void:
	global_position = new_position