class_name ReticleRenderer
extends Control

## HUD-006: Reticle Renderer Component
## Handles visual rendering of targeting reticles, lead indicators, and convergence displays
## with weapon-specific designs and status-based color coding

signal reticle_render_completed()
signal reticle_visibility_changed(visible: bool)

# Visual components
var central_reticle: TextureRect
var lead_marker: TextureRect
var convergence_indicator: Control
var range_markers: Array[Control] = []

# Reticle textures and resources
var reticle_textures: Dictionary = {}
var marker_textures: Dictionary = {}
var custom_shaders: Dictionary = {}

# Render configuration
var reticle_colors: Dictionary = {
	"ready": Color.GREEN,
	"charging": Color.YELLOW,
	"out_of_range": Color.RED,
	"no_target": Color.GRAY,
	"lead_indicator": Color.CYAN,
	"convergence": Color.MAGENTA,
	"range_marker": Color.WHITE
}

var reticle_sizes: Dictionary = {
	"central": 32.0,
	"lead": 16.0,
	"convergence": 24.0,
	"range_marker": 8.0
}

# Animation settings
var animation_enabled: bool = true
var fade_duration: float = 0.2
var pulse_frequency: float = 2.0
var flash_duration: float = 0.5

# Visual state
var current_weapon_type: String = "energy"
var current_status: String = "no_target"
var reticle_opacity: float = 1.0
var lead_confidence: float = 1.0

# Performance settings
var render_lod: int = 0  # 0=full, 1=reduced, 2=minimal
var max_range_markers: int = 5
var update_throttle: float = 0.0

func _ready() -> void:
	set_process(true)
	_initialize_renderer()
	print("ReticleRenderer: Reticle renderer initialized")

func _initialize_renderer() -> void:
	# Set up canvas layer for overlay rendering
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create central reticle
	central_reticle = TextureRect.new()
	central_reticle.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	central_reticle.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	central_reticle.anchor_left = 0.5
	central_reticle.anchor_top = 0.5
	central_reticle.anchor_right = 0.5
	central_reticle.anchor_bottom = 0.5
	central_reticle.visible = false
	add_child(central_reticle)
	
	# Create lead indicator
	lead_marker = TextureRect.new()
	lead_marker.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	lead_marker.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	lead_marker.anchor_left = 0.5
	lead_marker.anchor_top = 0.5
	lead_marker.anchor_right = 0.5
	lead_marker.anchor_bottom = 0.5
	lead_marker.visible = false
	add_child(lead_marker)
	
	# Create convergence indicator
	convergence_indicator = Control.new()
	convergence_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	convergence_indicator.visible = false
	add_child(convergence_indicator)
	
	# Load default textures and create fallback designs
	_load_reticle_resources()
	_create_fallback_designs()

func _load_reticle_resources() -> void:
	# Load reticle textures for different weapon types
	# For now, create procedural textures since assets may not exist yet
	_create_procedural_textures()

func _create_procedural_textures() -> void:
	# Create simple procedural reticle textures
	var image_size = 64
	
	# Energy weapon reticle (crosshair)
	var energy_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBA8)
	energy_image.fill(Color.TRANSPARENT)
	_draw_crosshair(energy_image, Color.WHITE, 2)
	var energy_texture = ImageTexture.create_from_image(energy_image)
	reticle_textures["energy"] = energy_texture
	
	# Ballistic weapon reticle (circle with crosshair)
	var ballistic_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBA8)
	ballistic_image.fill(Color.TRANSPARENT)
	_draw_circle(ballistic_image, Color.WHITE, 20, 2)
	_draw_crosshair(ballistic_image, Color.WHITE, 1)
	var ballistic_texture = ImageTexture.create_from_image(ballistic_image)
	reticle_textures["ballistic"] = ballistic_texture
	
	# Missile reticle (square with corner marks)
	var missile_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBA8)
	missile_image.fill(Color.TRANSPARENT)
	_draw_missile_reticle(missile_image, Color.WHITE, 2)
	var missile_texture = ImageTexture.create_from_image(missile_image)
	reticle_textures["missile"] = missile_texture
	
	# Beam weapon reticle (diamond)
	var beam_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBA8)
	beam_image.fill(Color.TRANSPARENT)
	_draw_diamond(beam_image, Color.WHITE, 16, 2)
	var beam_texture = ImageTexture.create_from_image(beam_image)
	reticle_textures["beam"] = beam_texture
	
	# Lead indicator (small circle)
	var lead_image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	lead_image.fill(Color.TRANSPARENT)
	_draw_circle(lead_image, Color.WHITE, 8, 2)
	var lead_texture = ImageTexture.create_from_image(lead_image)
	marker_textures["lead"] = lead_texture
	
	print("ReticleRenderer: Created procedural reticle textures")

func _draw_crosshair(image: Image, color: Color, thickness: int) -> void:
	var size = image.get_width()
	var center = size / 2
	var arm_length = size / 4
	
	# Horizontal line
	for x in range(center - arm_length, center + arm_length + 1):
		for t in range(thickness):
			for ty in range(thickness):
				if x >= 0 and x < size and (center + t - thickness/2) >= 0 and (center + t - thickness/2) < size:
					image.set_pixel(x, center + t - thickness/2, color)
	
	# Vertical line
	for y in range(center - arm_length, center + arm_length + 1):
		for t in range(thickness):
			if (center + t - thickness/2) >= 0 and (center + t - thickness/2) < size and y >= 0 and y < size:
				image.set_pixel(center + t - thickness/2, y, color)

func _draw_circle(image: Image, color: Color, radius: int, thickness: int) -> void:
	var size = image.get_width()
	var center = size / 2
	
	for y in range(size):
		for x in range(size):
			var dx = x - center
			var dy = y - center
			var distance = sqrt(dx * dx + dy * dy)
			
			if distance >= radius - thickness/2 and distance <= radius + thickness/2:
				image.set_pixel(x, y, color)

func _draw_missile_reticle(image: Image, color: Color, thickness: int) -> void:
	var size = image.get_width()
	var corner_size = size / 6
	
	# Draw corner marks
	var corners = [
		Vector2(corner_size, corner_size),
		Vector2(size - corner_size, corner_size),
		Vector2(corner_size, size - corner_size),
		Vector2(size - corner_size, size - corner_size)
	]
	
	for corner in corners:
		# Horizontal mark
		for x in range(-corner_size/2, corner_size/2 + 1):
			for t in range(thickness):
				var px = int(corner.x + x)
				var py = int(corner.y + t - thickness/2)
				if px >= 0 and px < size and py >= 0 and py < size:
					image.set_pixel(px, py, color)
		
		# Vertical mark
		for y in range(-corner_size/2, corner_size/2 + 1):
			for t in range(thickness):
				var px = int(corner.x + t - thickness/2)
				var py = int(corner.y + y)
				if px >= 0 and px < size and py >= 0 and py < size:
					image.set_pixel(px, py, color)

func _draw_diamond(image: Image, color: Color, radius: int, thickness: int) -> void:
	var size = image.get_width()
	var center = size / 2
	
	for y in range(size):
		for x in range(size):
			var dx = abs(x - center)
			var dy = abs(y - center)
			var distance = dx + dy  # Manhattan distance for diamond
			
			if distance >= radius - thickness/2 and distance <= radius + thickness/2:
				image.set_pixel(x, y, color)

func _create_fallback_designs() -> void:
	# Set default texture if none loaded
	if not reticle_textures.has("energy"):
		# Create basic white pixel texture as fallback
		var fallback_image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		fallback_image.fill(Color.WHITE)
		var fallback_texture = ImageTexture.create_from_image(fallback_image)
		reticle_textures["energy"] = fallback_texture

## Render central targeting reticle
func render_central_reticle(position: Vector2, weapon_type: String, status: String) -> void:
	if not central_reticle:
		return
	
	current_weapon_type = weapon_type
	current_status = status
	
	# Set appropriate texture for weapon type
	var texture = reticle_textures.get(weapon_type, reticle_textures.get("energy"))
	central_reticle.texture = texture
	
	# Set color based on status
	var status_color = reticle_colors.get(status, Color.WHITE)
	central_reticle.modulate = status_color
	
	# Position reticle
	var reticle_size = reticle_sizes["central"]
	central_reticle.position = position - Vector2(reticle_size/2, reticle_size/2)
	central_reticle.size = Vector2(reticle_size, reticle_size)
	
	# Apply visual effects based on status
	_apply_status_effects(central_reticle, status)
	
	central_reticle.visible = true
	
	# Apply LOD based on performance settings
	_apply_render_lod(central_reticle)

## Render lead indicator
func render_lead_indicator(lead_position: Vector2, confidence: float) -> void:
	if not lead_marker:
		return
	
	lead_confidence = confidence
	
	# Set texture and color
	var lead_texture = marker_textures.get("lead")
	if lead_texture:
		lead_marker.texture = lead_texture
	
	# Color based on confidence
	var lead_color = reticle_colors["lead_indicator"]
	lead_color.a = confidence  # Alpha based on confidence
	lead_marker.modulate = lead_color
	
	# Position marker
	var marker_size = reticle_sizes["lead"]
	lead_marker.position = lead_position - Vector2(marker_size/2, marker_size/2)
	lead_marker.size = Vector2(marker_size, marker_size)
	
	# Apply pulsing effect for high confidence
	if confidence > 0.8 and animation_enabled:
		_apply_pulse_effect(lead_marker)
	
	lead_marker.visible = true

## Render weapon convergence display
func render_convergence_display(convergence_point: Vector2, range: float) -> void:
	if not convergence_indicator:
		return
	
	# Clear previous convergence markers
	for child in convergence_indicator.get_children():
		child.queue_free()
	
	# Create convergence marker
	var marker = ColorRect.new()
	marker.color = reticle_colors["convergence"]
	marker.color.a = 0.6
	
	var marker_size = reticle_sizes["convergence"]
	marker.position = convergence_point - Vector2(marker_size/2, marker_size/2)
	marker.size = Vector2(marker_size, marker_size)
	
	convergence_indicator.add_child(marker)
	
	# Add range rings based on effective range
	_create_range_rings(convergence_point, range)
	
	convergence_indicator.visible = true

func _create_range_rings(center: Vector2, max_range: float) -> void:
	if render_lod > 1:  # Skip range rings in minimal LOD
		return
	
	var ring_count = min(3, max_range_markers)
	var ring_spacing = max_range / (ring_count + 1)
	
	for i in range(ring_count):
		var ring_range = ring_spacing * (i + 1)
		var ring_radius = (ring_range / max_range) * 100.0  # Scale to screen pixels
		
		_create_range_ring(center, ring_radius, reticle_colors["range_marker"])

func _create_range_ring(center: Vector2, radius: float, color: Color) -> void:
	# Create a circular range indicator
	var ring = Control.new()
	ring.position = center - Vector2(radius, radius)
	ring.size = Vector2(radius * 2, radius * 2)
	ring.draw.connect(_draw_range_ring.bind(radius, color))
	
	convergence_indicator.add_child(ring)

func _draw_range_ring(radius: float, color: Color) -> void:
	# Draw circle outline for range indicator
	var points = PackedVector2Array()
	var segments = 32
	
	for i in range(segments + 1):
		var angle = (i * 2.0 * PI) / segments
		var point = Vector2(cos(angle), sin(angle)) * radius + Vector2(radius, radius)
		points.append(point)
	
	# Note: This would need a proper draw call in a real implementation
	# For now, this is a placeholder for the ring drawing logic

## Apply status-based visual effects
func _apply_status_effects(element: Control, status: String) -> void:
	if not animation_enabled:
		return
	
	match status:
		"charging":
			_apply_pulse_effect(element)
		"out_of_range":
			_apply_flash_effect(element)
		"ready":
			_apply_steady_glow(element)

func _apply_pulse_effect(element: Control) -> void:
	# Create pulsing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(element, "modulate:a", 0.5, 0.5)
	tween.tween_property(element, "modulate:a", 1.0, 0.5)

func _apply_flash_effect(element: Control) -> void:
	# Create flashing animation for attention
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(element, "modulate:a", 0.2, 0.2)
	tween.tween_property(element, "modulate:a", 1.0, 0.2)

func _apply_steady_glow(element: Control) -> void:
	# Ensure steady visibility
	var tween = create_tween()
	tween.tween_property(element, "modulate:a", 1.0, fade_duration)

## Apply Level of Detail based on performance
func _apply_render_lod(element: Control) -> void:
	match render_lod:
		0:  # Full quality
			element.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		1:  # Reduced quality
			element.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		2:  # Minimal quality
			element.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			# Could reduce size or complexity here

## Hide all reticles
func hide_all_reticles() -> void:
	if central_reticle:
		central_reticle.visible = false
	if lead_marker:
		lead_marker.visible = false
	if convergence_indicator:
		convergence_indicator.visible = false
	
	# Clear any active animations
	_clear_animations()
	
	reticle_visibility_changed.emit(false)

func _clear_animations() -> void:
	# Stop all active tweens
	var tweens = get_tree().get_nodes_in_group("reticle_tweens")
	for tween in tweens:
		if tween is Tween:
			tween.kill()

## Apply configuration to renderer
func apply_configuration(config: Dictionary) -> void:
	# Update colors
	if config.has("reticle_colors"):
		var colors = config["reticle_colors"]
		for color_name in colors.keys():
			reticle_colors[color_name] = colors[color_name]
	
	# Update sizes
	if config.has("reticle_sizes"):
		var sizes = config["reticle_sizes"]
		for size_name in sizes.keys():
			reticle_sizes[size_name] = sizes[size_name]
	
	# Update animation settings
	if config.has("animation_enabled"):
		animation_enabled = config["animation_enabled"]
	
	if config.has("fade_duration"):
		fade_duration = config["fade_duration"]
	
	# Update LOD settings
	if config.has("render_lod"):
		render_lod = config["render_lod"]
	
	print("ReticleRenderer: Applied configuration updates")

## Set rendering performance level
func set_render_lod(lod_level: int) -> void:
	render_lod = clamp(lod_level, 0, 2)
	print("ReticleRenderer: Set render LOD to %d" % render_lod)

## Get rendering statistics
func get_render_statistics() -> Dictionary:
	return {
		"central_reticle_visible": central_reticle.visible if central_reticle else false,
		"lead_marker_visible": lead_marker.visible if lead_marker else false,
		"convergence_visible": convergence_indicator.visible if convergence_indicator else false,
		"current_weapon_type": current_weapon_type,
		"current_status": current_status,
		"render_lod": render_lod,
		"animation_enabled": animation_enabled,
		"textures_loaded": reticle_textures.size(),
		"range_markers_active": convergence_indicator.get_child_count() if convergence_indicator else 0
	}

func _process(delta: float) -> void:
	# Handle any continuous rendering updates
	update_throttle += delta
	
	# Throttle updates based on LOD
	var update_interval = 0.0166  # 60 FPS
	match render_lod:
		1: update_interval = 0.033  # 30 FPS
		2: update_interval = 0.066  # 15 FPS
	
	if update_throttle >= update_interval:
		_update_continuous_effects()
		update_throttle = 0.0

func _update_continuous_effects() -> void:
	# Update any time-based visual effects
	if animation_enabled:
		# Could update particle effects, glow intensities, etc.
		pass