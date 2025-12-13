# TurretController - Per-Turret AI Component
# Manages individual turret behavior, targeting, and firing
# Based on legacy aiturret.cpp

class_name TurretController
extends Node3D

## Turret configuration
@export var turret_subsystem: Resource = null ## SubsystemData reference
@export var weapon_system: Node = null ## WeaponSystem node for this turret

## Targeting settings
@export var fov_angle: float = 90.0 ## Field of view cone (degrees)
@export var max_range: float = 2000.0 ## Maximum targeting range
@export var rotation_speed: float = 45.0 ## Degrees per second

## Targeting priorities (higher = more priority)
@export_group("Target Priorities")
@export var priority_bombs: int = 100
@export var priority_missiles: int = 80
@export var priority_fighters: int = 60
@export var priority_bombers: int = 70
@export var priority_capital: int = 40

## Current state
var current_target: Node = null
var target_position: Vector3 = Vector3.ZERO
var is_tracking: bool = false
var last_fire_time: float = 0.0

## Parent ship reference
var parent_ship: Node = null

## Targeting helper
var _targeting: TurretTargeting = null


func _ready() -> void:
	parent_ship = get_parent()
	if parent_ship and parent_ship.has_method("get_parent"):
		# May be nested under subsystem node
		var p = parent_ship.get_parent()
		if p and "ship_data" in p:
			parent_ship = p

	_targeting = TurretTargeting.new()
	_targeting.fov_angle = fov_angle
	_targeting.max_range = max_range
	add_child(_targeting)


func _process(delta: float) -> void:
	if not is_instance_valid(parent_ship):
		return

	# Update targeting
	_update_target()

	# Track target
	if current_target and is_instance_valid(current_target):
		_track_target(delta)

	# Fire if able
	if is_tracking and _can_fire():
		_fire()


# === PUBLIC API ===


func set_target(target: Node) -> void:
	"""Force a specific target"""
	current_target = target
	if target:
		target_position = target.global_position


func clear_target() -> void:
	"""Clear current target"""
	current_target = null
	is_tracking = false


func get_turret_position() -> Vector3:
	"""Get world position of turret"""
	return global_position


func get_turret_forward() -> Vector3:
	"""Get world forward vector of turret"""
	return -global_transform.basis.z


# === PRIVATE ===


func _update_target() -> void:
	"""Find best target if none or invalid"""
	if current_target and is_instance_valid(current_target):
		# Validate current target still in range/FOV
		if not _is_valid_target(current_target):
			current_target = null
			is_tracking = false

	if not current_target:
		current_target = _targeting.find_best_target(
			self, parent_ship, _get_priority_function()
		)


func _track_target(delta: float) -> void:
	"""Rotate turret to track target"""
	if not current_target:
		is_tracking = false
		return

	target_position = current_target.global_position
	var to_target = (target_position - global_position).normalized()

	# Calculate desired rotation
	var current_fwd = - global_transform.basis.z
	var angle = rad_to_deg(current_fwd.angle_to(to_target))

	# Check if in FOV
	if angle > fov_angle / 2.0:
		is_tracking = false
		return

	# Rotate towards target
	var max_rotation = rotation_speed * delta
	if angle <= max_rotation:
		is_tracking = true
		look_at(target_position, Vector3.UP)
	else:
		is_tracking = false
		# Partial rotation
		var rotation_axis = current_fwd.cross(to_target).normalized()
		if rotation_axis.length_squared() > 0.001:
			rotate(rotation_axis, deg_to_rad(max_rotation))


func _is_valid_target(target: Node) -> bool:
	"""Check if target is still valid"""
	if not is_instance_valid(target):
		return false

	var to_target = target.global_position - global_position
	var dist = to_target.length()

	# Range check
	if dist > max_range:
		return false

	# FOV check
	var current_fwd = - global_transform.basis.z
	var angle = rad_to_deg(current_fwd.angle_to(to_target.normalized()))
	if angle > fov_angle / 2.0:
		return false

	# Line of sight check (simplified)
	# TODO: Raycast for occlusion

	return true


func _can_fire() -> bool:
	"""Check if turret can fire"""
	if not weapon_system:
		return false

	# Check cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_fire_time < 0.5: # TODO: Get from weapon data
		return false

	return true


func _fire() -> void:
	"""Fire turret weapons"""
	if weapon_system and weapon_system.has_method("fire_primary"):
		weapon_system.fire_primary()
		last_fire_time = Time.get_ticks_msec() / 1000.0


func _get_priority_function() -> Callable:
	"""Return priority calculation function"""
	return func(target: Node) -> float:
		var priority: float = 0.0

		# Check target type
		if target.is_in_group("bomb"):
			priority = priority_bombs
		elif target.is_in_group("missile"):
			priority = priority_missiles
		elif target.is_in_group("fighter"):
			priority = priority_fighters
		elif target.is_in_group("bomber"):
			priority = priority_bombers
		elif target.is_in_group("capital"):
			priority = priority_capital
		else:
			priority = 30.0

		# Distance modifier (closer = higher priority)
		var dist = global_position.distance_to(target.global_position)
		priority += (1.0 - dist / max_range) * 20.0

		# Threat modifier (heading towards parent)
		if parent_ship and "global_position" in parent_ship:
			var to_parent = parent_ship.global_position - target.global_position
			if "velocity" in target:
				var dot = to_parent.normalized().dot(target.velocity.normalized())
				if dot > 0.5: # Heading towards us
					priority += 30.0

		return priority
