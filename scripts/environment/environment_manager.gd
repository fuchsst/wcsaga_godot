# EnvironmentManager - Master Environment Coordinator
# Manages all environment systems: starfield, suns, nebulae, and lighting
# Provides unified API for mission environment configuration

class_name EnvironmentManager
extends Node3D

## Emitted when environment is fully loaded
signal environment_ready

## Emitted when environment configuration changes
signal environment_changed

## Emitted when environmental damage occurs
signal environmental_damage(damage_info: Dictionary)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Environment Components")
## Starfield controller (StarfieldController)
@export var starfield: Node3D
## Active suns in the environment (Array of SunController)
@export var suns: Array[Node3D] = []
## Active nebula if any (NebulaController)
@export var nebula: Node3D

@export_group("Ambient Lighting")
## Base ambient light color (used when no nebula)
@export var ambient_color: Color = Color(0.1, 0.1, 0.15)
## Ambient light energy
@export_range(0.0, 2.0) var ambient_energy: float = 0.3

@export_group("Quality Settings")
## Star density multiplier
@export_range(0.1, 3.0) var star_density: float = 1.0
## Enable volumetric effects
@export var volumetric_effects: bool = true
## Enable dynamic lighting
@export var dynamic_lighting: bool = true

# ==============================================================================
# INTERNAL STATE
# ==============================================================================

## World environment for ambient settings
var _world_environment: WorldEnvironment = null

## Ambient light node
var _ambient_light: DirectionalLight3D = null

## Current camera reference
var _camera: Camera3D = null

## Is environment initialized
var _initialized: bool = false

## Environment configuration data
var _config: Dictionary = {}

# Preload scripts for runtime instantiation
const StarfieldControllerScript = preload("res://scripts/environment/starfield_controller.gd")
const SunControllerScript = preload("res://scripts/environment/sun_controller.gd")
const NebulaControllerScript = preload("res://scripts/environment/nebula_controller.gd")

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	_setup_base_environment()
	_find_or_create_components()
	_initialized = true
	environment_ready.emit()


func _process(delta: float) -> void:
	if not _initialized:
		return

	# Update dynamic light lifetimes
	_update_dynamic_lights()

	# Apply nebula damage to registered ships
	if nebula:
		_process_nebula_effects(delta)


## Configure environment from mission data
func configure_from_mission(mission_data: Resource) -> void:
	if not mission_data:
		push_warning("EnvironmentManager: No mission data provided")
		return

	# Extract environment configuration from mission
	_config = _extract_environment_config(mission_data)

	# Configure starfield
	if starfield:
		var nebula_config = _config.get("nebula", {})
		if not nebula_config.is_empty():
			# Dim stars in nebula
			var fog_density: float = nebula_config.get("fog_density", 0.0)
			starfield.apply_nebula_fog(fog_density, nebula_config.get("fog_color", Color.WHITE))

	# Configure suns
	var sun_configs: Array = _config.get("suns", [])
	_setup_suns(sun_configs)

	# Configure nebula
	var neb_config: Dictionary = _config.get("nebula", {})
	if not neb_config.is_empty():
		_setup_nebula(neb_config)
	else:
		_clear_nebula()

	# Configure ambient lighting
	_apply_ambient_settings()

	print(
		(
			"EnvironmentManager: Environment configured with %d suns, nebula: %s"
			% [suns.size(), "yes" if nebula else "no"]
		)
	)

	environment_changed.emit()


## Set camera reference for effects that need it
func set_camera(camera: Camera3D) -> void:
	_camera = camera

	if starfield:
		starfield.set_camera(camera)

	for sun in suns:
		if is_instance_valid(sun):
			sun.set_camera(camera)


# ==============================================================================
# SETUP
# ==============================================================================


func _setup_base_environment() -> void:
	# Create base world environment
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "BaseEnvironment"

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy

	# Tone mapping for space scenes
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0

	# Glow for bright objects
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1

	_world_environment.environment = env
	add_child(_world_environment)

	# Create ambient directional light
	_ambient_light = DirectionalLight3D.new()
	_ambient_light.name = "AmbientLight"
	_ambient_light.light_color = ambient_color
	_ambient_light.light_energy = ambient_energy
	_ambient_light.shadow_enabled = false
	add_child(_ambient_light)


func _find_or_create_components() -> void:
	# Find existing components or create defaults
	# Starfield
	if not starfield:
		for child in get_children():
			if child.get_script() == StarfieldControllerScript:
				starfield = child
				break

	if not starfield:
		starfield = StarfieldControllerScript.new()
		starfield.name = "Starfield"
		starfield.set("stars_per_layer", int(1000 * star_density))
		add_child(starfield)

	# Suns - don't create default, mission will configure
	suns.clear()
	for child in get_children():
		if child.get_script() == SunControllerScript:
			suns.append(child)

	# Nebula - don't create default, mission will configure
	for child in get_children():
		if child.get_script() == NebulaControllerScript:
			nebula = child
			break


func _setup_suns(sun_configs: Array) -> void:
	# Clear existing suns
	for sun in suns:
		if is_instance_valid(sun):
			sun.queue_free()
	suns.clear()

	# Create suns from config
	for config in sun_configs:
		var sun := SunControllerScript.new()
		var sun_name: String = config.get("name", "Sun_%d" % suns.size())
		sun.name = sun_name

		# Configure sun direction from angles or direct direction
		if config.has("direction"):
			sun.sun_direction = config.get("direction")

		# Configure distance if specified
		if config.has("distance"):
			sun.sun_distance = config.get("distance")

		# Configure WCSSunData resource if available (from stars.tbl conversion)
		if config.has("resource") and config.get("resource"):
			sun.sun_data = config.get("resource")

		# Configure scale
		if config.has("scale"):
			sun.set("base_scale", config.get("scale", 1.0) * 100.0)

		# Configure texture directly if no WCSSunData but texture provided
		if config.has("texture") and config.get("texture"):
			# Will be applied after sun is added to tree via deferred call
			sun.set_meta("initial_texture", config.get("texture"))

		add_child(sun)
		suns.append(sun)

		if _camera:
			sun.set_camera(_camera)


func _setup_nebula(nebula_config: Dictionary) -> void:
	# Create or configure nebula
	if not nebula:
		nebula = NebulaControllerScript.new()
		nebula.name = "Nebula"
		add_child(nebula)

	if nebula_config.has("resource"):
		nebula.initialize_from_resource(nebula_config.get("resource"))

	if nebula_config.has("background"):
		nebula.set_background_texture(nebula_config.get("background"))

	# Connect damage signal
	if not nebula.damage_applied.is_connected(_on_nebula_damage):
		nebula.damage_applied.connect(_on_nebula_damage)


func _clear_nebula() -> void:
	if nebula:
		nebula.queue_free()
		nebula = null


func _apply_ambient_settings() -> void:
	if not _world_environment or not _world_environment.environment:
		return

	var env := _world_environment.environment

	# Adjust ambient based on nebula presence
	if nebula:
		var nebula_color: Color = nebula.get_fog_color()
		env.ambient_light_color = nebula_color.lerp(ambient_color, 0.5)
		env.ambient_light_energy = ambient_energy * 0.5  # Dimmer in nebula
	else:
		env.ambient_light_color = ambient_color
		env.ambient_light_energy = ambient_energy


# ==============================================================================
# MISSION DATA EXTRACTION
# ==============================================================================


func _extract_environment_config(mission_data: Resource) -> Dictionary:
	var config := {}

	# MissionManifest has 'backgrounds: BackgroundData' field
	var background_data: Resource = mission_data.get("backgrounds")
	if background_data:
		var sun_list: Array = []

		# BackgroundData has 'suns: Array[SunData]' - sun texture/angles/scale
		var suns_data: Array = background_data.get("suns") if background_data.get("suns") else []
		for sun_entry in suns_data:
			# SunData has: texture, angles (Vector3), scale
			var sun_angles: Vector3 = (
				sun_entry.get("angles") if sun_entry.get("angles") else Vector3.ZERO
			)
			sun_list.append(
				{
					"name": "Sun_%d" % sun_list.size(),
					"direction": _angles_to_direction(sun_angles),
					"texture": sun_entry.get("texture"),  # Texture2D
					"scale": sun_entry.get("scale", 1.0)
				}
			)

		# Also check background_sets for additional suns
		var background_sets: Array = (
			background_data.get("background_sets") if background_data.get("background_sets") else []
		)
		for bg_set in background_sets:
			var set_suns: Array = bg_set.get("suns") if bg_set.get("suns") else []
			for sun_entry in set_suns:
				var sun_angles: Vector3 = (
					sun_entry.get("angles") if sun_entry.get("angles") else Vector3.ZERO
				)
				sun_list.append(
					{
						"name": "Sun_%d" % sun_list.size(),
						"direction": _angles_to_direction(sun_angles),
						"texture": sun_entry.get("texture"),
						"scale": sun_entry.get("scale", 1.0)
					}
				)

		config["suns"] = sun_list

		# BackgroundData has 'nebula: MissionNebulaData'
		var nebula_data: Resource = background_data.get("nebula")
		if nebula_data:
			var nebula_type: String = (
				nebula_data.get("nebula_type") if nebula_data.get("nebula_type") else ""
			)
			if not nebula_type.is_empty():
				var neb_texture = nebula_data.get("texture")
				var neb_color = nebula_data.get("color")
				var neb_pitch = nebula_data.get("pitch")
				var neb_bank = nebula_data.get("bank")
				var neb_heading = nebula_data.get("heading")
				config["nebula"] = {
					"texture": neb_texture if neb_texture else "",
					"nebula_type": nebula_type,
					"color": neb_color if neb_color else "",
					"pitch": neb_pitch if neb_pitch else 0,
					"bank": neb_bank if neb_bank else 0,
					"heading": neb_heading if neb_heading else 0,
					"fog_density": 0.3,  # Default, override from NebulaData if available
					"fog_color": Color(0.3, 0.2, 0.4)
				}

		# BackgroundData.neb_awacs for AWACS suppression
		var neb_awacs_val = background_data.get("neb_awacs")
		var neb_awacs: float = neb_awacs_val if neb_awacs_val != null else -1.0
		if neb_awacs >= 0:
			if config.has("nebula"):
				config["nebula"]["awacs_suppression"] = neb_awacs
			else:
				config["nebula"] = {"awacs_suppression": neb_awacs}

		# Storm name for ion storm effects
		var storm_name_val = background_data.get("storm_name")
		var storm_name: String = storm_name_val if storm_name_val else ""
		if not storm_name.is_empty() and config.has("nebula"):
			config["nebula"]["storm_name"] = storm_name

	# Check mission flags for special environment conditions
	var mission_flags: Array = mission_data.get("flags") if mission_data.get("flags") else []
	config["flags"] = mission_flags

	return config


func _angles_to_direction(angles: Vector3) -> Vector3:
	# Convert pitch/bank/heading to direction vector
	var pitch := deg_to_rad(angles.x)
	var heading := deg_to_rad(angles.z)

	return Vector3(sin(heading) * cos(pitch), sin(pitch), -cos(heading) * cos(pitch)).normalized()


# ==============================================================================
# RUNTIME UPDATES
# ==============================================================================


func _process_nebula_effects(_delta: float) -> void:
	# This would iterate through ships and apply nebula effects
	# Implementation depends on how ships are tracked globally
	pass


func _on_nebula_damage(damage_info: Dictionary) -> void:
	environmental_damage.emit(damage_info)


# ==============================================================================
# PUBLIC API
# ==============================================================================


## Get the primary sun's light (for shadow casting)
func get_primary_sun_light() -> DirectionalLight3D:
	if suns.is_empty():
		return null

	var primary_sun: Node3D = suns[0]
	if is_instance_valid(primary_sun) and primary_sun.has_method("get_sun_light"):
		return primary_sun.get_sun_light()
	return null


## Check if currently in a nebula
func is_in_nebula() -> bool:
	return nebula != null and nebula._is_initialized


## Get current nebula severity (0.0 if not in nebula)
func get_nebula_severity() -> float:
	if nebula:
		return nebula.get_tactical_severity()
	return 0.0


## Get visibility range modifier
func get_visibility_modifier() -> float:
	if nebula:
		return 1.0 - nebula.get_visibility_concealment()
	return 1.0


## Calculate ship impact from current environment
func calculate_ship_impact(ship_stats: Resource) -> Dictionary:
	if nebula:
		return nebula.calculate_ship_impact(ship_stats)
	return {}


## Apply environmental effects to a ship
func apply_effects_to_ship(ship: Node3D, delta: float) -> Dictionary:
	if nebula:
		return nebula.apply_damage_to_ship(ship, delta)
	return {}


## Set quality settings
func set_quality_preset(preset: int) -> void:
	match preset:
		0:  # Low
			star_density = 0.3
			volumetric_effects = false
			if starfield:
				starfield.enable_twinkle = false
		1:  # Medium
			star_density = 0.7
			volumetric_effects = false
			if starfield:
				starfield.enable_twinkle = true
		2:  # High
			star_density = 1.0
			volumetric_effects = true
			if starfield:
				starfield.enable_twinkle = true
		3:  # Ultra
			star_density = 1.5
			volumetric_effects = true
			if starfield:
				starfield.enable_twinkle = true

	# Apply changes
	if starfield:
		starfield.set_star_density(star_density)

	if nebula:
		nebula.fog_enabled = volumetric_effects
		nebula.particles_enabled = volumetric_effects


## Get environment report for HUD/briefing display
func get_environment_report() -> Dictionary:
	var report := {
		"has_nebula": is_in_nebula(),
		"num_suns": suns.size(),
		"visibility_modifier": get_visibility_modifier()
	}

	if nebula:
		report["nebula_name"] = (
			nebula.nebula_data.get("nebula_name") if nebula.nebula_data else "Unknown"
		)
		report["nebula_type"] = nebula.get_classification_name()
		report["nebula_severity"] = get_nebula_severity()
		report["safe_for_exposure"] = nebula.is_safe_for_prolonged_exposure()

	return report


## Clear all environment elements (for mission end/load)
func clear_environment() -> void:
	# Clear suns
	for sun in suns:
		if is_instance_valid(sun):
			sun.queue_free()
	suns.clear()

	# Clear nebula
	_clear_nebula()

	# Clear dynamic lights
	_clear_dynamic_lights()

	# Reset starfield
	if starfield:
		starfield.regenerate()

	# Reset ambient
	_apply_ambient_settings()

	_config.clear()
	_initialized = false


# ==============================================================================
# DYNAMIC LIGHTING API
# ==============================================================================

## Pool of reusable dynamic lights
var _point_light_pool: Array[OmniLight3D] = []
var _active_point_lights: Array[Dictionary] = []  # {light, end_time}

const MAX_DYNAMIC_LIGHTS := 32
const LIGHT_POOL_SIZE := 16


## Add a dynamic point light (for explosions, weapon impacts)
## Returns the light node for further customization, or null if pool exhausted
func add_point_light(
	light_position: Vector3, color: Color, energy: float, radius: float, duration: float = 0.0
) -> OmniLight3D:
	if not dynamic_lighting:
		return null

	# Get or create a light from pool
	var light := _get_pooled_light()
	if not light:
		return null

	# Configure the light
	light.global_position = light_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.5  # Quadratic falloff
	light.visible = true

	# Track if it has a duration
	if duration > 0.0:
		_active_point_lights.append(
			{
				"light": light,
				"end_time": Time.get_ticks_msec() + int(duration * 1000.0),
				"start_energy": energy
			}
		)

	return light


## Add a tube light approximation (for beam weapons)
## Uses two point lights at endpoints - Godot doesn't have native tube lights
func add_tube_light(
	start_pos: Vector3,
	end_pos: Vector3,
	color: Color,
	energy: float,
	radius: float,
	_affected_object: Node3D = null
) -> Array[OmniLight3D]:
	if not dynamic_lighting:
		return []

	var lights: Array[OmniLight3D] = []

	# Create light at start
	var start_light := add_point_light(start_pos, color, energy * 0.5, radius)
	if start_light:
		lights.append(start_light)

	# Create light at end
	var end_light := add_point_light(end_pos, color, energy * 0.5, radius)
	if end_light:
		lights.append(end_light)

	# For longer beams, add intermediate lights
	var beam_length := start_pos.distance_to(end_pos)
	if beam_length > radius * 2.0:
		var mid_pos := (start_pos + end_pos) * 0.5
		var mid_light := add_point_light(mid_pos, color, energy * 0.3, radius)
		if mid_light:
			lights.append(mid_light)

	return lights


## Remove a dynamic light immediately
func remove_point_light(light: OmniLight3D) -> void:
	if not is_instance_valid(light):
		return

	light.visible = false

	# Remove from active list if present
	for i in range(_active_point_lights.size() - 1, -1, -1):
		if _active_point_lights[i].light == light:
			_active_point_lights.remove_at(i)
			break

	# Return to pool
	if light not in _point_light_pool:
		_point_light_pool.append(light)


func _get_pooled_light() -> OmniLight3D:
	# Try to get from pool first
	if not _point_light_pool.is_empty():
		return _point_light_pool.pop_back()

	# Check if we've hit the limit
	var total_lights := get_tree().get_nodes_in_group("dynamic_lights").size()
	if total_lights >= MAX_DYNAMIC_LIGHTS:
		# Recycle oldest active light
		if not _active_point_lights.is_empty():
			var oldest: Dictionary = _active_point_lights.pop_front()
			if is_instance_valid(oldest.light):
				oldest.light.visible = false
				return oldest.light
		return null

	# Create new light
	var light := OmniLight3D.new()
	light.name = "DynamicLight_%d" % total_lights
	light.add_to_group("dynamic_lights")
	light.shadow_enabled = false  # Performance
	add_child(light)
	return light


func _clear_dynamic_lights() -> void:
	# Return all active lights to pool
	for entry in _active_point_lights:
		if is_instance_valid(entry.light):
			entry.light.visible = false
			if entry.light not in _point_light_pool:
				_point_light_pool.append(entry.light)
	_active_point_lights.clear()


## Called each frame to update dynamic light lifetimes
func _update_dynamic_lights() -> void:
	if _active_point_lights.is_empty():
		return

	var current_time := Time.get_ticks_msec()

	for i in range(_active_point_lights.size() - 1, -1, -1):
		var entry: Dictionary = _active_point_lights[i]
		var light: OmniLight3D = entry.light

		if not is_instance_valid(light):
			_active_point_lights.remove_at(i)
			continue

		if current_time >= entry.end_time:
			# Light expired
			light.visible = false
			if light not in _point_light_pool:
				_point_light_pool.append(light)
			_active_point_lights.remove_at(i)
		else:
			# Fade out as it expires (last 20% of lifetime)
			var remaining := float(entry.end_time - current_time) / 1000.0
			if remaining < 0.2:
				light.light_energy = entry.start_energy * (remaining / 0.2)
