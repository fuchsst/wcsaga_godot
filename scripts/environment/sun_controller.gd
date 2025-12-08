# SunController - Sun Rendering with Lens Flares
# Manages sun display with corona, glow, and lens flare effects
# Uses WCSSunData and WCSSunFlare resources

class_name SunController
extends Node3D

## Emitted when sun is fully initialized
signal sun_ready

## Emitted when sun parameters change
signal sun_updated

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Sun Data")
## Sun resource containing configuration
@export var sun_data: Resource # WCSSunData

@export_group("Sun Position")
## Distance from scene origin
@export var sun_distance: float = 800.0
## Sun direction (normalized)
@export var sun_direction: Vector3 = Vector3(1, 0.5, -1).normalized()

@export_group("Rendering")
## Base scale multiplier
@export var base_scale: float = 100.0
## Corona intensity
@export_range(0.0, 2.0) var corona_intensity: float = 1.0
## Flare visibility threshold (dot product with camera)
@export_range(0.0, 1.0) var flare_visibility_threshold: float = 0.0

@export_group("Animation")
## Enable corona pulsing
@export var enable_pulse: bool = true
## Pulse frequency (Hz)
@export var pulse_frequency: float = 0.1
## Pulse intensity range
@export_range(0.0, 0.3) var pulse_intensity: float = 0.05

# ==============================================================================
# INTERNAL STATE
# ==============================================================================

## Main sun sprite
var _sun_sprite: Sprite3D = null

## Corona/glow sprite
var _corona_sprite: Sprite3D = null

## Lens flare sprites
var _flare_sprites: Array[Sprite3D] = []

## Camera reference for flare calculations  
var _camera: Camera3D = null

## Time accumulator
var _time: float = 0.0

## Light node for scene illumination
var _sun_light: DirectionalLight3D = null

## Current sun color
var _sun_color: Color = Color.WHITE

## Current sun scale
var _sun_scale: float = 1.0

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	_setup_sun()
	if sun_data:
		initialize_from_resource(sun_data)
	sun_ready.emit()


func _process(delta: float) -> void:
	_time += delta
	
	if enable_pulse:
		_update_pulse()
	
	if _camera:
		_update_flares()


## Initialize from WCSSunData resource
func initialize_from_resource(data: Resource) -> void:
	sun_data = data
	
	if not data:
		push_warning("SunController: No sun data provided")
		return
	
	# Extract sun properties
	_sun_color = data.get("color") if data.get("color") else Color.WHITE
	_sun_scale = data.get("scale") if data.get("scale") else 1.0
	
	# Set up sun glow texture
	var sunglow: Texture2D = data.get("sunglow")
	if sunglow and _sun_sprite:
		_sun_sprite.texture = sunglow
	
	if sunglow and _corona_sprite:
		_corona_sprite.texture = sunglow
	
	# Set up flares
	var flares: Array = data.get("flares") if data.get("flares") else []
	_setup_flares(flares)
	
	# Apply color and scale
	_apply_sun_appearance()
	
	print("SunController: Initialized sun '%s' with %d flares" % [
		data.get("sun_name") if data.get("sun_name") else "unnamed",
		flares.size()
	])
	
	sun_updated.emit()


## Set camera for flare visibility calculations
func set_camera(camera: Camera3D) -> void:
	_camera = camera


## Set sun direction
func set_sun_direction(direction: Vector3) -> void:
	sun_direction = direction.normalized()
	_update_sun_position()


# ==============================================================================
# SETUP
# ==============================================================================


func _setup_sun() -> void:
	# Create main sun sprite (facing camera billboard)
	_sun_sprite = Sprite3D.new()
	_sun_sprite.name = "SunSprite"
	_sun_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sun_sprite.no_depth_test = true
	_sun_sprite.render_priority = -50
	add_child(_sun_sprite)
	
	# Create corona/glow sprite (larger, more transparent)
	_corona_sprite = Sprite3D.new()
	_corona_sprite.name = "CoronaSprite"
	_corona_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_corona_sprite.no_depth_test = true
	_corona_sprite.modulate = Color(1, 1, 1, 0.5)
	_corona_sprite.render_priority = -51
	add_child(_corona_sprite)
	
	# Create directional light
	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "SunLight"
	_sun_light.light_energy = 1.0
	_sun_light.shadow_enabled = true
	add_child(_sun_light)
	
	_update_sun_position()


func _setup_flares(flares: Array) -> void:
	# Clear existing flares
	for flare in _flare_sprites:
		if is_instance_valid(flare):
			flare.queue_free()
	_flare_sprites.clear()
	
	# Create new flare sprites
	for i in range(flares.size()):
		var flare_data: Resource = flares[i]
		if not flare_data:
			continue
		
		var flare_sprite := Sprite3D.new()
		flare_sprite.name = "Flare_%d" % i
		flare_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		flare_sprite.no_depth_test = true
		flare_sprite.render_priority = -49 + i
		flare_sprite.visible = false # Hidden until camera in view
		
		# Get flare texture
		var texture: Texture2D = flare_data.get("texture")
		if texture:
			flare_sprite.texture = texture
		
		# Store flare properties
		var position_factor: float = flare_data.get("position") if flare_data.get("position") else 0.0
		var scale_factor: float = flare_data.get("scale") if flare_data.get("scale") else 1.0
		
		flare_sprite.set_meta("position_factor", position_factor)
		flare_sprite.set_meta("scale_factor", scale_factor)
		
		add_child(flare_sprite)
		_flare_sprites.append(flare_sprite)


func _apply_sun_appearance() -> void:
	var final_scale := base_scale * _sun_scale
	
	if _sun_sprite:
		_sun_sprite.pixel_size = final_scale * 0.01
		_sun_sprite.modulate = _sun_color
	
	if _corona_sprite:
		_corona_sprite.pixel_size = final_scale * 0.02 * corona_intensity
		_corona_sprite.modulate = Color(_sun_color.r, _sun_color.g, _sun_color.b, 0.3)
	
	if _sun_light:
		_sun_light.light_color = _sun_color


func _update_sun_position() -> void:
	var sun_pos := sun_direction * sun_distance
	
	if _sun_sprite:
		_sun_sprite.global_position = sun_pos
	
	if _corona_sprite:
		_corona_sprite.global_position = sun_pos
	
	if _sun_light:
		_sun_light.look_at_from_position(sun_pos, Vector3.ZERO)


# ==============================================================================
# ANIMATION
# ==============================================================================


func _update_pulse() -> void:
	var pulse := 1.0 + sin(_time * pulse_frequency * TAU) * pulse_intensity
	
	if _corona_sprite:
		var base_alpha := 0.3 * corona_intensity
		_corona_sprite.modulate.a = base_alpha * pulse


func _update_flares() -> void:
	if not _camera:
		return
	
	var camera_forward := -_camera.global_basis.z
	var to_sun := sun_direction
	var dot := camera_forward.dot(to_sun)
	
	# Calculate flare visibility
	var flare_visible: bool = dot > flare_visibility_threshold
	var flare_alpha: float = clamp((dot - flare_visibility_threshold) / (1.0 - flare_visibility_threshold), 0.0, 1.0)
	
	# Get screen center to sun line
	var screen_center := _camera.global_position
	var sun_pos := sun_direction * sun_distance
	var sun_to_center := (screen_center - sun_pos).normalized()
	
	for flare in _flare_sprites:
		if not is_instance_valid(flare):
			continue
		
		flare.visible = flare_visible
		
		if flare_visible:
			var pos_factor: float = flare.get_meta("position_factor", 0.0)
			var scale_factor: float = flare.get_meta("scale_factor", 1.0)
			
			# Position flare along sun-to-center line
			var flare_pos := sun_pos + sun_to_center * (sun_distance * 2.0 * pos_factor)
			flare.global_position = flare_pos
			flare.pixel_size = base_scale * scale_factor * 0.005
			flare.modulate = Color(_sun_color.r, _sun_color.g, _sun_color.b, flare_alpha * 0.5)


# ==============================================================================
# PUBLIC API
# ==============================================================================


## Get the sun's directional light
func get_sun_light() -> DirectionalLight3D:
	return _sun_light


## Set sun intensity
func set_intensity(intensity: float) -> void:
	if _sun_light:
		_sun_light.light_energy = intensity


## Set sun color
func set_sun_color(color: Color) -> void:
	_sun_color = color
	_apply_sun_appearance()


## Enable/disable sun shadows
func set_shadows_enabled(enabled: bool) -> void:
	if _sun_light:
		_sun_light.shadow_enabled = enabled


## Get sun world position
func get_sun_position() -> Vector3:
	return sun_direction * sun_distance


## Check if sun is visible from camera position
func is_sun_visible() -> bool:
	if not _camera:
		return true
	
	var camera_forward := -_camera.global_basis.z
	return camera_forward.dot(sun_direction) > flare_visibility_threshold
