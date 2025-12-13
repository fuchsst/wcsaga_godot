class_name Fireball
extends Node3D

## Fireball Entity
## Handles the lifecycle of a fireball effect, including explosions and warp effects.

signal finished
signal warp_opened
signal warp_closed

const FireballResource = preload("res://scripts/resources/effects/fireball_resource.gd")

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

var _resource: FireballResource
var _time_elapsed: float = 0.0
var _is_warping: bool = false
var _warp_state: int = 0  # 0: None, 1: Opening, 2: Open, 3: Closing

# Warp grid mesh components
var _warp_grid: MeshInstance3D = null
var _warp_material: ShaderMaterial = null
const WARP_GRID_RINGS: int = 10
const WARP_GRID_SEGMENTS: int = 32


func setup(resource: FireballResource, params: Dictionary = {}) -> void:
	_resource = resource

	if sprite and resource:
		# Set billboard mode based on type
		if (
			resource.render_type == FireballResource.FireballType.EXPLOSION_LARGE1
			or resource.render_type == FireballResource.FireballType.EXPLOSION_LARGE2
		):
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		else:
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED

		# Scale
		if params.has("scale"):
			scale = Vector3.ONE * params["scale"]
		elif resource.radius > 0:
			pass

	if resource.is_warp:
		_create_warp_grid()
		_start_warp_in()
	else:
		_start_explosion()


func _ready() -> void:
	# If setup wasn't called (e.g. testing scene directly), try to play default
	if not _resource and sprite:
		sprite.animation_finished.connect(_on_animation_finished)
		sprite.play("default")


func _process(delta: float) -> void:
	if _is_warping:
		_process_warp(delta)
		_update_warp_grid(delta)


func _start_explosion() -> void:
	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)
		sprite.play("default")


func _start_warp_in() -> void:
	_is_warping = true
	_warp_state = 1  # Opening
	_time_elapsed = 0.0

	# Start small
	scale = Vector3.ZERO

	if sprite:
		sprite.play("default")

	# Tween scale up
	var tween := create_tween()
	(
		tween
		. tween_property(self, "scale", Vector3.ONE, _resource.warp_lifetime)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.finished.connect(_on_warp_opened)


func _on_warp_opened() -> void:
	_warp_state = 2  # Open
	warp_opened.emit()


func start_warp_out() -> void:
	if not _resource or not _resource.is_warp:
		return

	_warp_state = 3  # Closing
	_time_elapsed = 0.0

	# Tween scale down
	var tween := create_tween()
	(
		tween
		. tween_property(self, "scale", Vector3.ZERO, _resource.warp_lifetime)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	tween.finished.connect(_on_warp_closed)


func _on_warp_closed() -> void:
	warp_closed.emit()
	finished.emit()
	queue_free()


func _process_warp(delta: float) -> void:
	_time_elapsed += delta


func _on_animation_finished() -> void:
	if not _is_warping:
		finished.emit()
		queue_free()


# ==============================================================================
# WARP GRID MESH
# ==============================================================================


func _create_warp_grid() -> void:
	"""Create circular warp grid mesh with ripple effect"""
	_warp_grid = MeshInstance3D.new()
	_warp_grid.name = "WarpGrid"
	add_child(_warp_grid)

	# Build circular mesh
	var arr_mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var radius: float = _resource.radius if _resource and _resource.radius > 0 else 10.0

	# Generate rings
	for ring in range(WARP_GRID_RINGS + 1):
		var ring_radius: float = (float(ring) / WARP_GRID_RINGS) * radius
		var v_coord: float = float(ring) / WARP_GRID_RINGS

		for seg in range(WARP_GRID_SEGMENTS):
			var angle: float = (float(seg) / WARP_GRID_SEGMENTS) * TAU
			var x: float = cos(angle) * ring_radius
			var z: float = sin(angle) * ring_radius
			var u_coord: float = float(seg) / WARP_GRID_SEGMENTS

			verts.append(Vector3(x, 0, z))
			uvs.append(Vector2(u_coord, v_coord))

	# Generate triangle indices (connect rings)
	for ring in range(WARP_GRID_RINGS):
		for seg in range(WARP_GRID_SEGMENTS):
			var curr: int = ring * WARP_GRID_SEGMENTS + seg
			var next_seg: int = ring * WARP_GRID_SEGMENTS + ((seg + 1) % WARP_GRID_SEGMENTS)
			var curr_outer: int = (ring + 1) * WARP_GRID_SEGMENTS + seg
			var next_outer: int = (ring + 1) * WARP_GRID_SEGMENTS + ((seg + 1) % WARP_GRID_SEGMENTS)

			# Triangle 1
			indices.append(curr)
			indices.append(next_seg)
			indices.append(curr_outer)

			# Triangle 2
			indices.append(next_seg)
			indices.append(next_outer)
			indices.append(curr_outer)

	# Create mesh arrays
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_warp_grid.mesh = arr_mesh

	# Create animated shader material
	_warp_material = ShaderMaterial.new()
	_warp_material.shader = _create_warp_shader()
	_warp_material.set_shader_parameter("warp_color", Color(0.3, 0.5, 1.0, 0.8))
	_warp_material.set_shader_parameter("ripple_speed", 3.0)
	_warp_material.set_shader_parameter("ripple_frequency", 10.0)
	_warp_grid.material_override = _warp_material


func _create_warp_shader() -> Shader:
	"""Create ripple effect shader for warp portal"""
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 warp_color : source_color = vec4(0.3, 0.5, 1.0, 0.8);
uniform float ripple_speed = 3.0;
uniform float ripple_frequency = 10.0;
uniform float time_offset = 0.0;

void fragment() {
	float dist = length(UV - vec2(0.5, 0.5)) * 2.0;
	float ripple = sin((dist - (TIME + time_offset) * ripple_speed) * ripple_frequency) * 0.5 + 0.5;
	float alpha = (1.0 - dist) * warp_color.a * ripple;
	
	ALBEDO = warp_color.rgb;
	ALPHA = clamp(alpha, 0.0, 1.0);
	EMISSION = warp_color.rgb * ripple * 0.5;
}
"""
	return shader


func _update_warp_grid(_delta: float) -> void:
	"""Update warp grid animation"""
	if not _warp_material:
		return

	# Adjust intensity based on warp state
	var intensity: float = 1.0
	match _warp_state:
		1:  # Opening
			intensity = clampf(_time_elapsed / _resource.warp_lifetime, 0.0, 1.0)
		2:  # Open
			intensity = 1.0
		3:  # Closing
			intensity = 1.0 - clampf(_time_elapsed / _resource.warp_lifetime, 0.0, 1.0)

	var base_color := Color(0.3, 0.5, 1.0, 0.8)
	base_color.a = intensity * 0.8
	_warp_material.set_shader_parameter("warp_color", base_color)
