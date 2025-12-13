# CountermeasureWeapon - Countermeasure projectile behavior
# Extends BaseWeapon with backwards launch velocity and diversion effects
# Used to distract homing missiles

class_name CountermeasureWeapon
extends BaseWeapon

## Signals
signal missile_diverted(missile: Node3D)
signal countermeasure_expired

# ==============================================================================
# CONSTANTS
# ==============================================================================

## Max tracking distance for missiles
const MAX_TRACK_DIST: float = 300.0

## Backward launch velocity (m/s)
const LAUNCH_VELOCITY: float = 25.0

## Random spread for velocity (m/s)
const VELOCITY_SPREAD: float = 2.0

# ==============================================================================
# STATE
# ==============================================================================

## Missiles currently diverted by this CM
var diverted_missiles: Array[Node3D] = []

## Parent ship that launched this CM
var parent_ship: Node3D = null

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _initialize_from_data() -> void:
	super._initialize_from_data()

	# Add to countermeasures group for missile detection
	add_to_group("countermeasures")


func set_launch_velocity(parent: Node3D, random_seed: int = -1) -> void:
	"""Set the backwards launch velocity with random spread"""
	parent_ship = parent

	if "team" in parent:
		team = parent.team

	# Get parent velocity and orientation
	var parent_vel := Vector3.ZERO
	if "velocity" in parent:
		parent_vel = parent.velocity
	elif parent is RigidBody3D:
		parent_vel = parent.linear_velocity

	# Calculate rear velocity (opposite of forward)
	var parent_basis := parent.global_transform.basis
	var rear_velocity := parent_vel + parent_basis.z * LAUNCH_VELOCITY  # +Z is back in Godot

	# Add random spread
	var rng := RandomNumberGenerator.new()
	if random_seed >= 0:
		rng.seed = random_seed
	else:
		rng.randomize()

	var random_vec := (
		(
			Vector3(
				rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)
			)
			. normalized()
		)
		* VELOCITY_SPREAD
	)

	velocity = rear_velocity + random_vec

	# Set initial position
	global_position = parent.global_position


# ==============================================================================
# PROCESSING
# ==============================================================================


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Check for expiration
	if weapon_data and life_time >= weapon_data.lifetime:
		_on_expired()


func _on_expired() -> void:
	# Notify if we successfully diverted any missiles
	if diverted_missiles.size() > 0:
		_alert_success()

	countermeasure_expired.emit()
	queue_free()


func _alert_success() -> void:
	"""Alert player of successful evasion"""
	if not parent_ship:
		return

	# Check if parent is player
	if parent_ship.is_in_group("player_ship"):
		# Show HUD message
		var subtitle_mgr: Node = get_node_or_null("/root/SubtitleManager")
		if subtitle_mgr and subtitle_mgr.has_method("show_subtitle"):
			subtitle_mgr.show_subtitle("Evaded", -1, -1, 0.8, 0.1)

		# Play sound
		var audio_mgr: Node = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sound"):
			audio_mgr.play_sound("missile_evaded")


# ==============================================================================
# DIVERSION API
# ==============================================================================


func register_diverted_missile(missile: Node3D) -> void:
	"""Called by missile when it switches target to this CM"""
	if missile not in diverted_missiles:
		diverted_missiles.append(missile)
		missile_diverted.emit(missile)


func unregister_diverted_missile(missile: Node3D) -> void:
	"""Called by missile when it stops tracking this CM"""
	diverted_missiles.erase(missile)


# ==============================================================================
# QUERIES
# ==============================================================================


func get_cm_strength() -> float:
	"""Get effectiveness of this CM (for diversion probability)"""
	if not weapon_data:
		return 1.0

	# Could add more factors like remaining lifetime
	var lifetime_factor: float = 1.0 - (life_time / weapon_data.lifetime)
	return lifetime_factor
