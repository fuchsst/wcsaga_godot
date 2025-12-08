# StarfieldController - Background Star Field Management
# Creates and manages procedural starfield with parallax effect
# Uses PixelsResource data for star density and appearance

class_name StarfieldController
extends Node3D

## Emitted when starfield is fully initialized
signal starfield_ready

## Emitted when starfield parameters change
signal starfield_updated

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Star Layers")
## Number of star layers for parallax depth
@export_range(1, 5) var num_layers: int = 3
## Base number of stars per layer
@export_range(100, 5000) var stars_per_layer: int = 1000
## Radius of the star sphere
@export var star_sphere_radius: float = 1000.0

@export_group("Star Appearance")
## Minimum star brightness
@export_range(0.0, 1.0) var min_brightness: float = 0.3
## Maximum star brightness
@export_range(0.0, 1.0) var max_brightness: float = 1.0
## Star size range
@export var min_star_size: float = 0.5
@export var max_star_size: float = 3.0
## Star color variance (0 = white only, 1 = full color range)
@export_range(0.0, 1.0) var color_variance: float = 0.2

@export_group("Parallax")
## Parallax movement multiplier per layer (0 = no movement, 1 = full movement)
@export var parallax_strength: float = 0.1
## Layer depth scale (each layer is this much further than previous)
@export var layer_depth_scale: float = 1.5

@export_group("Animation")
## Enable star twinkle effect
@export var enable_twinkle: bool = true
## Twinkle frequency (Hz)
@export var twinkle_frequency: float = 0.5
## Twinkle intensity (0-1)
@export_range(0.0, 0.5) var twinkle_intensity: float = 0.15

@export_group("Background Bitmaps")
## Background bitmap instances projected onto spheres (from mission data)
## Each entry: {texture: Texture2D, scale_x: float, scale_y: float, div_x: int, div_y: int, angles: Vector3}
@export var background_bitmaps: Array[Resource] = []

@export_group("Motion Debris")
## Enable motion debris (small particles flying past camera)
@export var debris_enabled: bool = true
## Maximum debris pieces (legacy default: 200)
@export_range(0, 200) var max_debris: int = 200
## Debris textures for normal/nebula mode
@export var debris_textures: Array[Texture2D] = []
## Use nebula debris textures instead of normal
@export var use_nebula_debris: bool = false
## Motion debris size
@export var debris_base_size: float = 0.12
## Debris size in nebula (larger)
@export var debris_nebula_size: float = 0.5

# ==============================================================================
# CONSTANTS (from legacy starfield.cpp)
# ==============================================================================

const MAX_STARS: int = 2000
const MAX_DEBRIS: int = 200
const MAX_DIST: float = 50.0
const MAX_DIST_RANGE: float = 60.0
const MIN_DIST_RANGE: float = 14.0
const DEBRIS_ROT_MIN: int = 10000
const DEBRIS_ROT_RANGE: int = 8

# ==============================================================================
# INTERNAL STATE
# ==============================================================================

## Star layer meshes
var _star_layers: Array[MeshInstance3D] = []

## Star data for each layer
var _star_data: Array[Array] = []

## Time accumulator for animation
var _time: float = 0.0

## Camera reference for parallax
var _camera: Camera3D = null

## Previous camera position for parallax calculation
var _prev_camera_pos: Vector3 = Vector3.ZERO

## Loaded pixels resource (optional)
var _pixels_resource: PixelsResource = null

# Star color palette
const STAR_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0), # White
	Color(0.9, 0.9, 1.0), # Blue-white
	Color(1.0, 0.95, 0.9), # Warm white
	Color(0.8, 0.85, 1.0), # Light blue
	Color(1.0, 0.9, 0.8), # Yellow-white
	Color(1.0, 0.7, 0.6), # Orange tint
	Color(0.7, 0.8, 1.0), # Deep blue
]

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	_generate_starfield()
	starfield_ready.emit()


func _process(delta: float) -> void:
	if enable_twinkle:
		_update_twinkle(delta)
	
	if parallax_strength > 0 and _camera:
		_update_parallax()


## Initialize starfield from a PixelsResource
func initialize_from_resource(pixels_res: PixelsResource) -> void:
	_pixels_resource = pixels_res
	_regenerate()


## Set the camera for parallax effect
func set_camera(camera: Camera3D) -> void:
	_camera = camera
	_prev_camera_pos = camera.global_position if camera else Vector3.ZERO


## Regenerate the entire starfield
func regenerate() -> void:
	_regenerate()


# ==============================================================================
# GENERATION
# ==============================================================================


func _generate_starfield() -> void:
	_clear_layers()
	
	for layer_idx in range(num_layers):
		var layer_data: Array = []
		var layer_mesh := _create_star_layer(layer_idx, layer_data)
		
		_star_layers.append(layer_mesh)
		_star_data.append(layer_data)
		add_child(layer_mesh)
	
	print("StarfieldController: Generated %d layers with ~%d total stars" % [
		num_layers, stars_per_layer * num_layers
	])


func _create_star_layer(layer_idx: int, out_star_data: Array) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "StarLayer_%d" % layer_idx
	
	# Calculate layer properties
	var depth_multiplier := pow(layer_depth_scale, layer_idx)
	var layer_radius := star_sphere_radius * depth_multiplier
	var layer_star_count := int(stars_per_layer * (1.0 / depth_multiplier)) # Fewer stars at greater depth
	
	# Create immediate mesh with points
	var array_mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	
	for i in range(layer_star_count):
		# Random point on sphere
		var theta := randf() * TAU
		var phi := acos(2.0 * randf() - 1.0)
		
		var pos := Vector3(
			layer_radius * sin(phi) * cos(theta),
			layer_radius * sin(phi) * sin(theta),
			layer_radius * cos(phi)
		)
		vertices.append(pos)
		
		# Random color with variance
		var base_color := STAR_COLORS[randi() % STAR_COLORS.size()]
		var brightness := randf_range(min_brightness, max_brightness)
		var final_color := base_color.lerp(Color.WHITE, 1.0 - color_variance)
		final_color = final_color * brightness
		final_color.a = brightness
		colors.append(final_color)
		
		# Store star data for animation
		out_star_data.append({
			"index": i,
			"base_brightness": brightness,
			"twinkle_phase": randf() * TAU,
			"twinkle_speed": randf_range(0.5, 2.0) * twinkle_frequency
		})
	
	# Build mesh arrays
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	mesh_instance.mesh = array_mesh
	
	# Create material for point rendering
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.point_size = randf_range(min_star_size, max_star_size)
	material.use_point_size = true
	material.render_priority = -100 # Render behind everything
	
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Store layer metadata
	mesh_instance.set_meta("layer_idx", layer_idx)
	mesh_instance.set_meta("depth_multiplier", depth_multiplier)
	
	return mesh_instance


func _clear_layers() -> void:
	for layer in _star_layers:
		if is_instance_valid(layer):
			layer.queue_free()
	_star_layers.clear()
	_star_data.clear()


func _regenerate() -> void:
	_generate_starfield()
	starfield_updated.emit()


# ==============================================================================
# ANIMATION
# ==============================================================================


func _update_twinkle(delta: float) -> void:
	_time += delta
	
	for layer_idx in range(_star_layers.size()):
		var layer := _star_layers[layer_idx]
		var data: Array = _star_data[layer_idx]
		
		if not is_instance_valid(layer) or layer.mesh == null:
			continue
		
		var array_mesh := layer.mesh as ArrayMesh
		if array_mesh.get_surface_count() == 0:
			continue
		
		# Get current colors
		var arrays: Array = array_mesh.surface_get_arrays(0)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		
		# Update colors with twinkle
		for i in range(min(data.size(), colors.size())):
			var star_info: Dictionary = data[i]
			var phase: float = star_info["twinkle_phase"]
			var speed: float = star_info["twinkle_speed"]
			var base_brightness: float = star_info["base_brightness"]
			
			var twinkle := sin(_time * speed + phase) * twinkle_intensity
			var new_brightness := clampf(base_brightness + twinkle, 0.0, 1.0)
			
			var color := colors[i]
			color.a = new_brightness
			colors[i] = color
		
		# Update mesh
		arrays[Mesh.ARRAY_COLOR] = colors
		array_mesh.clear_surfaces()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)


func _update_parallax() -> void:
	if not _camera:
		return
	
	var camera_delta := _camera.global_position - _prev_camera_pos
	_prev_camera_pos = _camera.global_position
	
	for layer_idx in range(_star_layers.size()):
		var layer := _star_layers[layer_idx]
		if not is_instance_valid(layer):
			continue
		
		var depth: float = layer.get_meta("depth_multiplier", 1.0)
		var layer_parallax := parallax_strength / depth
		
		# Move layer opposite to camera movement
		layer.global_position -= camera_delta * layer_parallax


# ==============================================================================
# PUBLIC API
# ==============================================================================


## Set star visibility
func set_visible_stars(show_stars: bool) -> void:
	for layer in _star_layers:
		if is_instance_valid(layer):
			layer.visible = show_stars


## Get total star count
func get_star_count() -> int:
	var total := 0
	for layer_data in _star_data:
		total += layer_data.size()
	return total


## Adjust star density (regenerates starfield)
func set_star_density(density_multiplier: float) -> void:
	stars_per_layer = int(1000 * clamp(density_multiplier, 0.1, 5.0))
	_regenerate()


## Apply nebula fog effect to stars (reduces visibility)
func apply_nebula_fog(fog_density: float, fog_color: Color) -> void:
	for layer in _star_layers:
		if is_instance_valid(layer):
			var material := layer.material_override as StandardMaterial3D
			if material:
				# Dim stars based on fog
				material.albedo_color = Color.WHITE.lerp(fog_color, fog_density * 0.3)
