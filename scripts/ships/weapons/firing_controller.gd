class_name FiringController
extends Node

## Weapon firing controller with precise timing, rate limiting, and burst fire mechanics
## Implements WCS-authentic firing behavior for all weapon types
## Implementation of SHIP-005: Firing System component

# EPIC-002 Asset Core Integration
const WeaponData = preload("res://addons/wcs_asset_core/structures/weapon_data.gd")
const WeaponBankType = preload("res://addons/wcs_asset_core/constants/weapon_bank_types.gd")

# Basic weapon projectile system
const WeaponBase = preload("res://scripts/object/weapon_base.gd")

# Firing controller signals
signal firing_sequence_started(bank_type: WeaponBankType.Type)
signal firing_sequence_completed(bank_type: WeaponBankType.Type)
signal projectile_created(projectile: WeaponBase)
signal burst_fire_completed(bank_type: WeaponBankType.Type, bank_index: int)

# Ship reference
var ship: BaseShip

# Firing state tracking
var active_firing_sequences: Dictionary = {}  # bank_type -> FiringSequence
var last_fire_times: Dictionary = {}  # weapon_bank -> last_fire_time
var burst_fire_states: Dictionary = {}  # weapon_bank -> BurstFireState

# Performance tracking
var projectiles_created_this_frame: int = 0
var max_projectiles_per_frame: int = 20

## Firing sequence state class
class FiringSequence:
	var bank_type: WeaponBankType.Type
	var weapon_banks: Array[WeaponBank]
	var firing_pattern: String
	var sequence_start_time: float
	var sequence_duration: float
	var is_active: bool = false
	
	func _init(type: WeaponBankType.Type, banks: Array[WeaponBank], pattern: String = "simultaneous") -> void:
		bank_type = type
		weapon_banks = banks
		firing_pattern = pattern
		sequence_start_time = Time.get_ticks_msec()

## Burst fire state class for managing weapon burst firing
class BurstFireState:
	var weapon_bank: WeaponBank
	var shots_fired: int = 0
	var shots_per_burst: int = 1
	var burst_interval: float = 0.1
	var last_shot_time: float = 0.0
	var is_burst_active: bool = false
	
	func _init(bank: WeaponBank, burst_count: int, interval: float) -> void:
		weapon_bank = bank
		shots_per_burst = burst_count
		burst_interval = interval
		last_shot_time = Time.get_ticks_msec()

func _ready() -> void:
	# Reset performance tracking each frame
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	# Reset projectile count for this frame
	projectiles_created_this_frame = 0
	
	# Update active firing sequences
	_update_firing_sequences(delta)
	
	# Update burst fire states
	_update_burst_fire_states(delta)

## Initialize firing controller with ship reference
func initialize_firing_controller(parent_ship: BaseShip) -> void:
	ship = parent_ship
	
	if not ship:
		push_error("FiringController: Cannot initialize without valid ship reference")
		return

## Fire weapon bank with precise timing control (SHIP-005 AC2)
func fire_weapon_bank(weapon_bank: WeaponBank, firing_data: Dictionary) -> bool:
	if not weapon_bank or not weapon_bank.can_fire():
		return false
	
	# Check rate limiting (SHIP-005 AC2)
	if _is_rate_limited(weapon_bank):
		return false
	
	# Check projectile creation limits for performance
	if projectiles_created_this_frame >= max_projectiles_per_frame:
		return false
	
	# Get weapon data for firing calculations
	var weapon_data: WeaponData = weapon_bank.get_weapon_data()
	if not weapon_data:
		return false
	
	# Determine firing mode based on weapon data
	var firing_mode: String = _determine_firing_mode(weapon_data)
	
	match firing_mode:
		"single_shot":
			return _fire_single_shot(weapon_bank, firing_data)
		"burst_fire":
			return _fire_burst_shot(weapon_bank, firing_data)
		"continuous":
			return _fire_continuous(weapon_bank, firing_data)
		_:
			push_error("FiringController: Unknown firing mode: %s" % firing_mode)
			return false

## Fire single projectile from weapon bank (SHIP-005 AC2)
func _fire_single_shot(weapon_bank: WeaponBank, firing_data: Dictionary) -> bool:
	var weapon_data: WeaponData = weapon_bank.get_weapon_data()
	
	# Create projectile
	var projectile: WeaponBase = _create_projectile(weapon_data, firing_data)
	if not projectile:
		return false
	
	# Position projectile at weapon mount point
	var mount_position: Vector3 = weapon_bank.get_mount_position()
	var mount_orientation: Vector3 = weapon_bank.get_mount_orientation()
	_position_projectile(projectile, mount_position, mount_orientation, firing_data)
	
	# Apply firing solution for accuracy
	_apply_firing_solution(projectile, firing_data)
	
	# Update firing time tracking
	_update_firing_time(weapon_bank)
	
	# Consume ammunition or energy
	weapon_bank.consume_shot()
	
	# Emit signals
	projectile_created.emit(projectile)
	
	return true

## Fire burst shot sequence (SHIP-005 AC2)
func _fire_burst_shot(weapon_bank: WeaponBank, firing_data: Dictionary) -> bool:
	var weapon_data: WeaponData = weapon_bank.get_weapon_data()
	
	# Get or create burst fire state
	var burst_state: BurstFireState
	var bank_id: int = weapon_bank.get_instance_id()
	
	if not burst_fire_states.has(bank_id):
		var burst_count: int = weapon_data.burst_shots if weapon_data.has("burst_shots") else 3
		var burst_interval: float = weapon_data.burst_delay if weapon_data.has("burst_delay") else 0.1
		burst_state = BurstFireState.new(weapon_bank, burst_count, burst_interval)
		burst_fire_states[bank_id] = burst_state
	else:
		burst_state = burst_fire_states[bank_id]
	
	# Start burst if not active
	if not burst_state.is_burst_active:
		burst_state.is_burst_active = true
		burst_state.shots_fired = 0
		burst_state.last_shot_time = Time.get_ticks_msec()
	
	# Fire single shot as part of burst
	if _fire_single_shot(weapon_bank, firing_data):
		burst_state.shots_fired += 1
		burst_state.last_shot_time = Time.get_ticks_msec()
		
		# Check if burst is complete
		if burst_state.shots_fired >= burst_state.shots_per_burst:
			burst_state.is_burst_active = false
			burst_fire_completed.emit(weapon_bank.get_bank_type(), weapon_bank.get_bank_index())
		
		return true
	
	return false

## Fire continuous weapon (beam weapons) (SHIP-005 AC2)
func _fire_continuous(weapon_bank: WeaponBank, firing_data: Dictionary) -> bool:
	# Continuous weapons maintain beam until firing stops
	# This would be implemented differently for beam weapons
	# For now, treat as single shot with different timing
	return _fire_single_shot(weapon_bank, firing_data)

## Create projectile from weapon data (SHIP-005 AC2)
func _create_projectile(weapon_data: WeaponData, firing_data: Dictionary) -> WeaponBase:
	var projectile: WeaponBase = null
	
	# Check if weapon has custom projectile scene
	if not weapon_data.projectile_scene_path.is_empty():
		var projectile_scene: PackedScene = load(weapon_data.projectile_scene_path)
		if projectile_scene:
			projectile = projectile_scene.instantiate()
		else:
			push_error("FiringController: Failed to load projectile scene: %s" % weapon_data.projectile_scene_path)
			return null
	else:
		# Use default WeaponBase for basic projectiles
		projectile = WeaponBase.new()
	
	# Setup projectile with weapon data
	var target: Node3D = firing_data.get("target", null)
	var target_subsystem: Node = firing_data.get("target_subsystem", null)
	var ship_velocity: Vector3 = firing_data.get("ship_velocity", Vector3.ZERO)
	
	projectile.setup(weapon_data, ship, target, target_subsystem, ship_velocity)
	
	# Add to scene tree
	if ship.get_parent():
		ship.get_parent().add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)
	
	projectiles_created_this_frame += 1
	
	return projectile

## Position projectile at weapon mount with proper orientation
func _position_projectile(projectile: WeaponBase, mount_position: Vector3, mount_orientation: Vector3, firing_data: Dictionary) -> void:
	if not projectile or not ship:
		return
	
	# Calculate world position from ship-relative mount position
	var world_position: Vector3 = ship.global_transform * mount_position
	projectile.global_position = world_position
	
	# Calculate firing direction
	var firing_direction: Vector3 = -ship.global_transform.basis.z  # Ship forward
	
	# Apply convergence if specified
	var convergence_distance: float = firing_data.get("convergence_distance", 500.0)
	if convergence_distance > 0.0:
		var convergence_target: Vector3 = world_position + firing_direction * convergence_distance
		firing_direction = (convergence_target - world_position).normalized()
	
	# Orient projectile in firing direction
	projectile.look_at(world_position + firing_direction, Vector3.UP)

## Apply firing solution for target leading (SHIP-005 AC6)
func _apply_firing_solution(projectile: WeaponBase, firing_data: Dictionary) -> void:
	var firing_solution: Dictionary = firing_data.get("firing_solution", {})
	if firing_solution.is_empty():
		return
	
	# Apply lead calculation
	var lead_vector: Vector3 = firing_solution.get("lead_vector", Vector3.ZERO)
	if lead_vector != Vector3.ZERO:
		var current_direction: Vector3 = -projectile.global_transform.basis.z
		var adjusted_direction: Vector3 = (current_direction + lead_vector).normalized()
		projectile.look_at(projectile.global_position + adjusted_direction, Vector3.UP)
	
	# Apply accuracy modifications
	var accuracy_modifier: float = firing_solution.get("accuracy_modifier", 1.0)
	if accuracy_modifier < 1.0:
		# Add random spread based on accuracy
		var spread_amount: float = (1.0 - accuracy_modifier) * 0.1  # Max 10% spread
		var random_spread: Vector3 = Vector3(
			randf_range(-spread_amount, spread_amount),
			randf_range(-spread_amount, spread_amount),
			0.0
		)
		var current_direction: Vector3 = -projectile.global_transform.basis.z
		var spread_direction: Vector3 = (current_direction + random_spread).normalized()
		projectile.look_at(projectile.global_position + spread_direction, Vector3.UP)

## Check if weapon bank is rate limited (SHIP-005 AC2)
func _is_rate_limited(weapon_bank: WeaponBank) -> bool:
	var weapon_data: WeaponData = weapon_bank.get_weapon_data()
	if not weapon_data:
		return true
	
	var bank_id: int = weapon_bank.get_instance_id()
	var current_time: float = Time.get_ticks_msec()
	
	# Check if enough time has passed since last firing
	if last_fire_times.has(bank_id):
		var time_since_last_fire: float = current_time - last_fire_times[bank_id]
		var required_interval: float = 1.0 / weapon_data.fire_rate if weapon_data.fire_rate > 0.0 else 0.1
		
		return time_since_last_fire < required_interval
	
	return false

## Update firing time tracking
func _update_firing_time(weapon_bank: WeaponBank) -> void:
	var bank_id: int = weapon_bank.get_instance_id()
	last_fire_times[bank_id] = Time.get_ticks_msec()

## Determine firing mode from weapon data
func _determine_firing_mode(weapon_data: WeaponData) -> String:
	# Check weapon properties to determine firing mode
	if weapon_data.has("is_beam") and weapon_data.is_beam:
		return "continuous"
	elif weapon_data.has("burst_shots") and weapon_data.burst_shots > 1:
		return "burst_fire"
	else:
		return "single_shot"

## Update active firing sequences
func _update_firing_sequences(delta: float) -> void:
	var sequences_to_remove: Array[WeaponBankType.Type] = []
	
	for bank_type in active_firing_sequences.keys():
		var sequence: FiringSequence = active_firing_sequences[bank_type]
		
		# Update sequence timing
		var current_time: float = Time.get_ticks_msec()
		var elapsed_time: float = current_time - sequence.sequence_start_time
		
		# Check if sequence is complete
		if elapsed_time >= sequence.sequence_duration:
			firing_sequence_completed.emit(bank_type)
			sequences_to_remove.append(bank_type)
	
	# Remove completed sequences
	for bank_type in sequences_to_remove:
		active_firing_sequences.erase(bank_type)

## Update burst fire states
func _update_burst_fire_states(delta: float) -> void:
	var states_to_remove: Array[int] = []
	var current_time: float = Time.get_ticks_msec()
	
	for bank_id in burst_fire_states.keys():
		var burst_state: BurstFireState = burst_fire_states[bank_id]
		
		# Check if burst is complete and should be cleaned up
		if not burst_state.is_burst_active:
			var time_since_last_shot: float = current_time - burst_state.last_shot_time
			if time_since_last_shot > 1.0:  # Clean up after 1 second
				states_to_remove.append(bank_id)
	
	# Remove old burst states
	for bank_id in states_to_remove:
		burst_fire_states.erase(bank_id)

## Start firing sequence for weapon bank type
func start_firing_sequence(bank_type: WeaponBankType.Type, weapon_banks: Array[WeaponBank], pattern: String = "simultaneous") -> void:
	var sequence: FiringSequence = FiringSequence.new(bank_type, weapon_banks, pattern)
	sequence.is_active = true
	sequence.sequence_duration = 1.0  # Default sequence duration
	
	active_firing_sequences[bank_type] = sequence
	firing_sequence_started.emit(bank_type)

## Stop firing sequence for weapon bank type
func stop_firing_sequence(bank_type: WeaponBankType.Type) -> void:
	if active_firing_sequences.has(bank_type):
		active_firing_sequences.erase(bank_type)
		firing_sequence_completed.emit(bank_type)

## Check if firing sequence is active
func is_firing_sequence_active(bank_type: WeaponBankType.Type) -> bool:
	return active_firing_sequences.has(bank_type)

## Get firing performance statistics
func get_firing_statistics() -> Dictionary:
	var stats: Dictionary = {}
	
	stats["active_sequences"] = active_firing_sequences.size()
	stats["active_burst_states"] = burst_fire_states.size()
	stats["projectiles_this_frame"] = projectiles_created_this_frame
	stats["max_projectiles_per_frame"] = max_projectiles_per_frame
	
	return stats

## Debug information
func get_debug_info() -> String:
	var info: String = "FiringController Debug Info:\n"
	info += "  Active Sequences: %d\n" % active_firing_sequences.size()
	info += "  Active Burst States: %d\n" % burst_fire_states.size()
	info += "  Projectiles This Frame: %d / %d\n" % [projectiles_created_this_frame, max_projectiles_per_frame]
	info += "  Tracked Fire Times: %d\n" % last_fire_times.size()
	return info