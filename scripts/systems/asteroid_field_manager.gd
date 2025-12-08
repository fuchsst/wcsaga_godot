# AsteroidFieldManager - Runtime Asteroid Field Controller
# Manages asteroid spawning, lifecycle, wrapping, and destruction cascades
# Based on legacy asteroid.cpp functionality

class_name AsteroidFieldManager
extends Node3D

const AsteroidFieldDataClass = preload("res://scripts/resources/asteroids/asteroid_field_data.gd")
const AsteroidDataClass = preload("res://scripts/resources/asteroids/asteroid_data.gd")

## Emitted when an asteroid is destroyed
signal asteroid_destroyed(asteroid: Node3D, position: Vector3, size_type: int)

## Emitted when the field is fully initialized
signal field_initialized(asteroid_count: int)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

## Field configuration data
@export var field_data: Resource  # AsteroidFieldData

## Asteroid scene (if not provided via AsteroidData)
@export var default_asteroid_scene: PackedScene

## Maximum active asteroids (performance limit)
@export var max_asteroids: int = 512

# ==============================================================================
# CONSTANTS
# ==============================================================================

const WRAP_CHECK_INTERVAL := 2.0  # Seconds between wrap checks per asteroid
const COLLISION_CHECK_INTERVAL := 2.0  # Seconds between collision predictions

# Size spawn weights for initial field generation
const SMALL_WEIGHT := 8
const MEDIUM_WEIGHT := 4
const LARGE_WEIGHT := 1

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

## Currently active asteroids
var asteroids: Array[Node3D] = []

## Enabled state
var _field_enabled: bool = true

## Field initialized
var _initialized: bool = false

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	if field_data:
		initialize_field(field_data)


## Initialize the asteroid field from data
func initialize_field(data: Resource) -> void:  # AsteroidFieldData
	field_data = data

	if not data:
		push_warning("AsteroidFieldManager: No field data provided")
		return

	# Clear any existing asteroids
	clear_field()

	# Create initial asteroids
	for i in range(data.num_initial_asteroids):
		if asteroids.size() >= max_asteroids:
			break

		# Determine size type based on weights
		var size_type := _get_weighted_size_type()

		# Create asteroid at random position
		var asteroid := create_asteroid(size_type)
		if asteroid:
			asteroids.append(asteroid)

	_initialized = true
	field_initialized.emit(asteroids.size())

	print("AsteroidFieldManager: Created %d asteroids" % asteroids.size())


## Get a weighted random size type
func _get_weighted_size_type() -> int:
	var total_weight := SMALL_WEIGHT + MEDIUM_WEIGHT + LARGE_WEIGHT
	var roll := randi() % total_weight

	if roll < LARGE_WEIGHT:
		return AsteroidDataClass.SizeType.LARGE
	if roll < LARGE_WEIGHT + MEDIUM_WEIGHT:
		return AsteroidDataClass.SizeType.MEDIUM
	return AsteroidDataClass.SizeType.SMALL


# ==============================================================================
# ASTEROID CREATION
# ==============================================================================


## Create an asteroid of the given size type
func create_asteroid(
	size_type: int = AsteroidData.SizeType.LARGE,
	spawn_position: Vector3 = Vector3.ZERO,
	inherit_velocity: Vector3 = Vector3.ZERO
) -> Node3D:
	if not field_data:
		push_warning("AsteroidFieldManager: No field data")
		return null

	# Get the appropriate asteroid data
	var asteroid_data: AsteroidData = _get_asteroid_data_for_size(size_type)
	if not asteroid_data:
		push_warning("AsteroidFieldManager: No asteroid data for size %d" % size_type)
		return null

	# Get the scene to instantiate
	var scene := (
		asteroid_data.asteroid_scene if asteroid_data.asteroid_scene else default_asteroid_scene
	)
	if not scene:
		push_warning("AsteroidFieldManager: No scene for asteroid")
		return null

	# Instantiate
	var asteroid: Node3D = scene.instantiate()
	if not asteroid:
		push_warning("AsteroidFieldManager: Failed to instantiate asteroid scene")
		return null

	# Set position
	if spawn_position == Vector3.ZERO:
		asteroid.global_position = field_data.get_random_spawn_position()
	else:
		asteroid.global_position = spawn_position

	# Random orientation
	asteroid.global_rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

	# Add to scene
	add_child(asteroid)

	# Configure asteroid properties
	_configure_asteroid(asteroid, asteroid_data, inherit_velocity)

	# Connect destruction signal
	if asteroid.has_signal("asteroid_destroyed"):
		asteroid.asteroid_destroyed.connect(_on_asteroid_destroyed)
	if asteroid.has_signal("destroyed"):
		asteroid.destroyed.connect(_on_asteroid_destroyed.bind(asteroid))

	return asteroid


## Configure an asteroid after instantiation
func _configure_asteroid(asteroid: Node3D, data: AsteroidData, inherit_velocity: Vector3) -> void:
	# Set data reference
	if "asteroid_data" in asteroid:
		asteroid.asteroid_data = data

	# Set field manager reference
	if "field_manager" in asteroid:
		asteroid.field_manager = self

	# Configure velocity
	if asteroid is RigidBody3D:
		var rb: RigidBody3D = asteroid as RigidBody3D

		# Base velocity from field + random
		var base_vel: Vector3 = field_data.get_random_velocity()
		rb.linear_velocity = base_vel + inherit_velocity

		# Random rotational velocity
		rb.angular_velocity = Vector3(
			(randf() - 0.5) * 0.5, (randf() - 0.5) * 0.5, (randf() - 0.5) * 0.5
		)

		# Set mass
		if data:
			rb.mass = data.calculate_mass(asteroid.scale.x)


## Get asteroid data for a size type
func _get_asteroid_data_for_size(size_type: int) -> Resource:  # AsteroidData
	if not field_data:
		return null

	match size_type:
		AsteroidDataClass.SizeType.SMALL:
			return field_data.small_asteroid_data
		AsteroidDataClass.SizeType.MEDIUM:
			return field_data.medium_asteroid_data
		AsteroidDataClass.SizeType.LARGE:
			return field_data.large_asteroid_data
		_:
			return null


# ==============================================================================
# FIELD WRAPPING
# ==============================================================================


## Check and wrap an asteroid if needed (called periodically per asteroid)
func check_wrap(asteroid: Node3D) -> void:
	if not field_data or not _field_enabled:
		return

	if field_data.field_type != AsteroidFieldDataClass.FieldType.ACTIVE:
		return

	var pos := asteroid.global_position

	if not field_data.is_in_field(pos) or field_data.is_in_inner_bound(pos):
		wrap_position(asteroid)


## Wrap an asteroid to the opposite side of the field
func wrap_position(asteroid: Node3D) -> void:
	if not field_data:
		return

	var pos := asteroid.global_position
	var new_pos := pos

	# Wrap on each axis
	for axis in 3:
		if pos[axis] < field_data.min_bound[axis]:
			new_pos[axis] = field_data.max_bound[axis] + (pos[axis] - field_data.min_bound[axis])
		elif pos[axis] > field_data.max_bound[axis]:
			new_pos[axis] = field_data.min_bound[axis] + (pos[axis] - field_data.max_bound[axis])

	# Fix inner bound if needed
	if field_data.is_in_inner_bound(new_pos):
		new_pos = field_data._fixup_inner_bound_position(new_pos)

	asteroid.global_position = new_pos


# ==============================================================================
# DESTRUCTION HANDLING
# ==============================================================================


## Handle asteroid destruction - spawn sub-asteroids or debris
func _on_asteroid_destroyed(position_or_asteroid: Variant) -> void:
	var pos: Vector3
	var velocity := Vector3.ZERO
	var size_type := AsteroidData.SizeType.LARGE
	var asteroid_ref: Node3D = null

	# Handle different call patterns
	if position_or_asteroid is Vector3:
		pos = position_or_asteroid
	elif position_or_asteroid is Node3D:
		asteroid_ref = position_or_asteroid
		pos = asteroid_ref.global_position

		# Get velocity if RigidBody
		if asteroid_ref is RigidBody3D:
			velocity = (asteroid_ref as RigidBody3D).linear_velocity

		# Get size type
		if "asteroid_data" in asteroid_ref and asteroid_ref.asteroid_data:
			size_type = asteroid_ref.asteroid_data.size_type

		# Remove from our list
		var idx := asteroids.find(asteroid_ref)
		if idx >= 0:
			asteroids.remove_at(idx)

	# Emit signal
	asteroid_destroyed.emit(asteroid_ref, pos, size_type)

	# Spawn sub-asteroids if not the smallest size
	if size_type != AsteroidDataClass.SizeType.SMALL:
		_spawn_sub_asteroids(pos, velocity, size_type)


## Spawn sub-asteroids when a larger asteroid is destroyed
func _spawn_sub_asteroids(
	spawn_pos_origin: Vector3, parent_velocity: Vector3, parent_size_type: int
) -> void:
	# Determine sub-asteroid size
	var sub_size_type: int
	match parent_size_type:
		AsteroidDataClass.SizeType.LARGE:
			sub_size_type = AsteroidDataClass.SizeType.MEDIUM
		AsteroidDataClass.SizeType.MEDIUM:
			sub_size_type = AsteroidDataClass.SizeType.SMALL
		_:
			return  # Small asteroids don't spawn sub-asteroids

	# Get parent data to determine count
	var parent_data := _get_asteroid_data_for_size(parent_size_type)
	var sub_count := 3  # Default
	var speed_factor := 1.5

	if parent_data:
		sub_count = parent_data.sub_asteroid_count
		speed_factor = parent_data.sub_asteroid_speed_factor

	# Cap at max asteroids
	sub_count = mini(sub_count, max_asteroids - asteroids.size())

	# Spawn sub-asteroids in random directions
	for i in range(sub_count):
		# Spawn slightly offset from explosion center
		var offset := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized() * 20.0

		var spawn_pos := spawn_pos_origin + offset

		# Calculate inherit velocity with speed factor
		var random_dir := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
		var inherit_vel := parent_velocity + random_dir * parent_velocity.length() * speed_factor

		var asteroid := create_asteroid(sub_size_type, spawn_pos, inherit_vel)
		if asteroid:
			asteroids.append(asteroid)


# ==============================================================================
# FIELD MANAGEMENT
# ==============================================================================


## Clear all asteroids from the field
func clear_field() -> void:
	for asteroid in asteroids:
		if is_instance_valid(asteroid):
			asteroid.queue_free()
	asteroids.clear()
	_initialized = false


## Enable/disable field updates
func set_field_enabled(enabled: bool) -> void:
	_field_enabled = enabled


## Get current asteroid count
func get_asteroid_count() -> int:
	return asteroids.size()


## Check if field is initialized
func is_initialized() -> bool:
	return _initialized
