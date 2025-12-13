# AsteroidFieldManager - Runtime Asteroid Field Controller
# Manages asteroid spawning, lifecycle, wrapping, and destruction cascades
# Based on legacy asteroid.cpp functionality

class_name AsteroidFieldManager
extends Node3D

# ==============================================================================
# SIGNALS
# ==============================================================================

## Emitted when an asteroid is destroyed
signal asteroid_destroyed(asteroid: Node3D, position: Vector3, size_type: int)

## Emitted when the field is fully initialized
signal field_initialized(asteroid_count: int)

# ==============================================================================
# CONSTANTS
# ==============================================================================

const AsteroidFieldDataClass = preload("res://scripts/resources/asteroids/asteroid_field_data.gd")
const AsteroidDataClass = preload("res://scripts/resources/asteroids/asteroid_data.gd")

const WRAP_CHECK_INTERVAL := 2.0 # Seconds between wrap checks per asteroid
const COLLISION_CHECK_INTERVAL := 2.0 # Seconds between collision predictions
const MIN_THROW_DELAY := 1.0 # Minimum seconds between throws
const THROW_TIME_BASE := 24.0 # Base time for intercept calculation

# Size spawn weights for initial field generation
const SMALL_WEIGHT := 8
const MEDIUM_WEIGHT := 4
const LARGE_WEIGHT := 1

# ==============================================================================
# CONFIGURATION
# ==============================================================================

## Field configuration data
@export var field_data: Resource # AsteroidFieldData

## Asteroid scene (if not provided via AsteroidData)
@export var default_asteroid_scene: PackedScene

## Maximum active asteroids (performance limit)
@export var max_asteroids: int = 512

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

## Currently active asteroids
var asteroids: Array[Node3D] = []

## Ship to throw asteroids at (active throwing)
var throw_target: Node3D = null

## Max simultaneous incoming asteroids
var max_incoming_asteroids: int = 3

## Enabled state
var _field_enabled: bool = true

## Field initialized
var _initialized: bool = false

## Active throwing internal state
var _next_throw_time: float = 0.0
var _thrown_count: int = 0

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	if field_data:
		initialize_field(field_data)


## Initialize the asteroid field from data
func initialize_field(data: Resource) -> void: # AsteroidFieldData
	field_data = data

	if not data:
		push_warning("AsteroidFieldManager: No field data provided")
		return

	# Clear any existing asteroids
	clear_field()

	# Create initial asteroids/debris based on genre
	for i in range(data.num_initial_asteroids):
		if asteroids.size() >= max_asteroids:
			break

		var obj: Node3D = null
		if data.debris_genre == AsteroidFieldDataClass.DebrisGenre.SHIP:
			# Ship debris field - spawn debris with weighted sizes
			obj = _create_ship_debris()
		else:
			# Asteroid field - spawn asteroids (large only initially)
			obj = create_asteroid(AsteroidDataClass.SizeType.LARGE)

		if obj:
			asteroids.append(obj)

	_initialized = true
	field_initialized.emit(asteroids.size())

	var genre_name := "asteroids" if data.debris_genre == 0 else "ship debris"
	print("AsteroidFieldManager: Created %d %s" % [asteroids.size(), genre_name])


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


# ==============================================================================
# SHIP DEBRIS CREATION
# ==============================================================================


## Create ship debris for DG_SHIP genre fields
func _create_ship_debris(spawn_position: Vector3 = Vector3.ZERO) -> Node3D:
	if not field_data:
		return null

	# Get weighted debris type based on size
	var size_type := _get_weighted_size_type()

	# Find appropriate debris scene
	var debris_idx := 0
	if field_data.debris_types.size() > 0:
		# Use enabled debris types from field config
		debris_idx = field_data.debris_types[randi() % field_data.debris_types.size()]

	var scene: PackedScene = null
	if field_data.ship_debris_scenes.size() > debris_idx:
		scene = field_data.ship_debris_scenes[debris_idx]

	if not scene:
		# Fallback to default debris scene
		if ResourceLoader.exists("res://scenes/entities/debris.tscn"):
			scene = load("res://scenes/entities/debris.tscn")

	if not scene:
		push_warning("AsteroidFieldManager: No debris scene available")
		return null

	# Instantiate debris
	var debris: Node3D = scene.instantiate()
	if not debris:
		return null

	# Position
	if spawn_position == Vector3.ZERO:
		debris.global_position = field_data.get_random_spawn_position()
	else:
		debris.global_position = spawn_position

	# Random orientation
	debris.global_rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

	# Add to scene
	add_child(debris)

	# Configure velocity
	if debris is RigidBody3D:
		var rb: RigidBody3D = debris as RigidBody3D
		rb.linear_velocity = field_data.get_random_velocity()
		rb.angular_velocity = Vector3(
			(randf() - 0.5) * 0.5, (randf() - 0.5) * 0.5, (randf() - 0.5) * 0.5
		)

	# Set debris data if available
	if field_data.ship_debris_data.size() > debris_idx:
		if "debris_data" in debris:
			debris.debris_data = field_data.ship_debris_data[debris_idx]

	# Mark as hull debris for larger sizes
	if "is_hull_debris" in debris:
		debris.is_hull_debris = (size_type == AsteroidDataClass.SizeType.LARGE)

	# Connect destruction signal
	if debris.has_signal("destroyed"):
		debris.destroyed.connect(_on_debris_destroyed.bind(debris))

	return debris


func _on_debris_destroyed(debris: Node3D) -> void:
	"""Handle debris destruction"""
	var idx := asteroids.find(debris)
	if idx >= 0:
		asteroids.remove_at(idx)


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
func _get_asteroid_data_for_size(size_type: int) -> Resource: # AsteroidData
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
			return # Small asteroids don't spawn sub-asteroids

	# Get parent data to determine count
	var parent_data := _get_asteroid_data_for_size(parent_size_type)
	var sub_count := 3 # Default
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


# ==============================================================================
# ACTIVE THROWING
# ==============================================================================


## Set the target ship for active throwing
func set_throw_target(target: Node3D) -> void:
	throw_target = target
	if target:
		_next_throw_time = Time.get_ticks_msec() / 1000.0 + MIN_THROW_DELAY


## Call periodically to maybe throw an asteroid at the target
func _process(_delta: float) -> void:
	if not _field_enabled or not _initialized:
		return

	if field_data and field_data.field_type == AsteroidFieldDataClass.FieldType.ACTIVE:
		_maybe_throw_asteroid()


func _maybe_throw_asteroid() -> void:
	"""Periodically throw asteroids at the throw target"""
	if throw_target == null or not is_instance_valid(throw_target):
		return

	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time < _next_throw_time:
		return

	# Count asteroids currently heading towards target
	var incoming := _count_incoming_asteroids()
	if incoming >= max_incoming_asteroids:
		return

	# Create and aim asteroid
	var asteroid := create_asteroid(AsteroidDataClass.SizeType.LARGE)
	if asteroid:
		_aim_at_target(asteroid, throw_target)
		asteroids.append(asteroid)
		_thrown_count += 1

		# Schedule next throw (longer delay as more thrown)
		_next_throw_time = current_time + MIN_THROW_DELAY + _thrown_count * 0.5


func _count_incoming_asteroids() -> int:
	"""Count asteroids heading towards throw target"""
	var count := 0
	if throw_target == null:
		return 0

	var target_pos := throw_target.global_position

	for asteroid in asteroids:
		if not is_instance_valid(asteroid):
			continue

		if asteroid is RigidBody3D:
			var to_target := target_pos - asteroid.global_position
			var vel: Vector3 = (asteroid as RigidBody3D).linear_velocity
			if vel.length() > 0.1 and to_target.normalized().dot(vel.normalized()) > 0.5:
				count += 1

	return count


func _aim_at_target(asteroid: Node3D, target: Node3D) -> void:
	"""Calculate intercept trajectory for asteroid to hit target"""
	if not asteroid or not target:
		return

	var target_pos := target.global_position
	var target_vel := Vector3.ZERO
	if target is RigidBody3D:
		target_vel = (target as RigidBody3D).linear_velocity
	elif "velocity" in target:
		target_vel = target.velocity

	# Predict where target will be
	var delta_time := THROW_TIME_BASE + randf() * 20.0
	var predicted_pos := target_pos + target_vel * delta_time

	# Add randomness to hit area
	var rand_offset := Vector3(
		(randf() - 0.5) * 50.0,
		(randf() - 0.5) * 50.0,
		(randf() - 0.5) * 50.0
	)
	predicted_pos += rand_offset

	# Calculate velocity to intercept
	var asteroid_data: Resource = null
	if "asteroid_data" in asteroid:
		asteroid_data = asteroid.asteroid_data

	var max_speed := 60.0
	if asteroid_data and "max_speed" in asteroid_data:
		max_speed = asteroid_data.max_speed

	var speed := max_speed * (randf() * 0.5 + 0.5)

	# Direction from current position towards predicted target
	var direction := (predicted_pos - asteroid.global_position).normalized()

	# Position asteroid so it will arrive at target in delta_time
	asteroid.global_position = predicted_pos - direction * speed * delta_time

	if asteroid is RigidBody3D:
		(asteroid as RigidBody3D).linear_velocity = direction * speed


## Get number of thrown asteroids this session
func get_thrown_count() -> int:
	return _thrown_count
