class_name SpecialEffectsManager
extends Node

## SHIP-014 AC4: Special Effects Manager
## Handles HUD disruption, targeting interference, and ship system degradation with authentic timing
## Manages visual corruption, screen effects, and system interference from special weapons

# EPIC-002 Asset Core Integration
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")

# Signals
signal hud_disruption_applied(disruption_type: String, intensity: float, duration: float)
signal targeting_interference_started(interference_level: float)
signal targeting_interference_stopped()
signal visual_corruption_applied(corruption_type: String, severity: float)
signal system_degradation_applied(system: String, degradation_level: float)

# HUD disruption effects
var active_hud_disruptions: Dictionary = {}  # disruption_id -> disruption_data
var targeting_interference_level: float = 0.0
var visual_corruption_effects: Dictionary = {}  # effect_type -> effect_data

# HUD disruption types
enum HUDDisruptionType {
	TEXT_SCRAMBLING,
	GAUGE_FLICKERING,
	DISPLAY_JITTER,
	SCREEN_FLASH,
	TARGET_SWITCHING,
	SENSOR_STATIC,
	COLOR_INVERSION,
	SCAN_LINES
}

# Visual corruption configurations
var disruption_configs: Dictionary = {
	HUDDisruptionType.TEXT_SCRAMBLING: {
		"effect_name": "text_scrambling",
		"base_duration": 12.0,
		"intensity_multiplier": 1.5,
		"update_frequency": 0.1,
		"characters": "!@#$%^&*()_+-=[]{}|;:,.<>?"
	},
	HUDDisruptionType.GAUGE_FLICKERING: {
		"effect_name": "gauge_flickering",
		"base_duration": 8.0,
		"intensity_multiplier": 2.0,
		"update_frequency": 0.05,
		"flicker_rate": 4.0  # Hz
	},
	HUDDisruptionType.DISPLAY_JITTER: {
		"effect_name": "display_jitter",
		"base_duration": 10.0,
		"intensity_multiplier": 1.2,
		"update_frequency": 0.02,
		"jitter_amplitude": 8.0  # pixels
	},
	HUDDisruptionType.SCREEN_FLASH: {
		"effect_name": "screen_flash",
		"base_duration": 2.0,
		"intensity_multiplier": 3.0,
		"update_frequency": 0.1,
		"flash_color": Color.WHITE
	},
	HUDDisruptionType.TARGET_SWITCHING: {
		"effect_name": "target_switching",
		"base_duration": 15.0,
		"intensity_multiplier": 1.0,
		"update_frequency": 0.5,
		"switch_probability": 0.3
	},
	HUDDisruptionType.SENSOR_STATIC: {
		"effect_name": "sensor_static",
		"base_duration": 20.0,
		"intensity_multiplier": 1.8,
		"update_frequency": 0.03,
		"static_density": 0.25
	},
	HUDDisruptionType.COLOR_INVERSION: {
		"effect_name": "color_inversion",
		"base_duration": 5.0,
		"intensity_multiplier": 2.5,
		"update_frequency": 0.2,
		"inversion_amount": 0.8
	},
	HUDDisruptionType.SCAN_LINES: {
		"effect_name": "scan_lines",
		"base_duration": 18.0,
		"intensity_multiplier": 1.3,
		"update_frequency": 0.01,
		"line_spacing": 4.0
	}
}

# Configuration
@export var enable_hud_disruption: bool = true
@export var enable_targeting_interference: bool = true
@export var enable_visual_corruption: bool = true
@export var enable_system_degradation: bool = true
@export var max_simultaneous_effects: int = 8

# System references
var hud_system: Node = null
var targeting_system: Node = null
var visual_effects_system: Node = null
var ship_owner: Node = null

# Canvas layers for effects
var disruption_canvas: CanvasLayer = null
var corruption_overlay: ColorRect = null
var jitter_container: Control = null

# Performance tracking
var effects_performance_stats: Dictionary = {
	"total_disruptions_applied": 0,
	"active_hud_effects": 0,
	"targeting_interferences": 0,
	"visual_corruptions": 0,
	"frame_update_count": 0
}

# Update timers
var effect_update_timer: float = 0.0
var effect_update_interval: float = 0.02  # 50 FPS updates

func _ready() -> void:
	_setup_special_effects_manager()
	_create_disruption_canvas()

## Initialize special effects manager
func initialize_effects_manager(owner_ship: Node) -> void:
	ship_owner = owner_ship
	
	# Get system references
	if owner_ship.has_method("get_hud_system"):
		hud_system = owner_ship.get_hud_system()
	
	if owner_ship.has_method("get_targeting_system"):
		targeting_system = owner_ship.get_targeting_system()
	
	if owner_ship.has_method("get_visual_effects_system"):
		visual_effects_system = owner_ship.get_visual_effects_system()
	
	print("SpecialEffectsManager: Initialized for ship %s" % ship_owner.name)

## Apply HUD disruption effects
func apply_hud_disruption(disruption_types: Array, intensity: float, duration: float) -> String:
	if not enable_hud_disruption:
		return ""
	
	var disruption_id = "hud_disruption_%d" % Time.get_ticks_msec()
	var current_time = Time.get_ticks_msec() / 1000.0
	
	var disruption_data = {
		"disruption_id": disruption_id,
		"disruption_types": disruption_types.duplicate(),
		"base_intensity": intensity,
		"current_intensity": intensity,
		"duration": duration,
		"start_time": current_time,
		"end_time": current_time + duration,
		"active_effects": {}
	}
	
	# Apply each disruption type
	for disruption_type in disruption_types:
		_apply_specific_hud_disruption(disruption_id, disruption_type, intensity, duration)
	
	active_hud_disruptions[disruption_id] = disruption_data
	effects_performance_stats["total_disruptions_applied"] += 1
	effects_performance_stats["active_hud_effects"] = active_hud_disruptions.size()
	
	hud_disruption_applied.emit(disruption_types[0] if disruption_types.size() > 0 else "unknown", intensity, duration)
	
	return disruption_id

## Apply specific HUD disruption type
func _apply_specific_hud_disruption(disruption_id: String, disruption_type: int, intensity: float, duration: float) -> void:
	if not disruption_configs.has(disruption_type):
		return
	
	var config = disruption_configs[disruption_type]
	var effect_duration = config["base_duration"] * intensity * config["intensity_multiplier"]
	
	match disruption_type:
		HUDDisruptionType.TEXT_SCRAMBLING:
			_apply_text_scrambling(disruption_id, intensity, effect_duration, config)
		HUDDisruptionType.GAUGE_FLICKERING:
			_apply_gauge_flickering(disruption_id, intensity, effect_duration, config)
		HUDDisruptionType.DISPLAY_JITTER:
			_apply_display_jitter(disruption_id, intensity, effect_duration, config)
		HUDDisruptionType.SCREEN_FLASH:
			_apply_screen_flash(disruption_id, intensity, effect_duration, config)
		HUDDisruptionType.TARGET_SWITCHING:
			_apply_target_switching(disruption_id, intensity, effect_duration, config)
		HUDDisruptionType.SENSOR_STATIC:
			_apply_sensor_static(disruption_id, intensity, effect_duration, config)
		HUDDisruptionType.COLOR_INVERSION:
			_apply_color_inversion(disruption_id, intensity, effect_duration, config)
		HUDDisruptionType.SCAN_LINES:
			_apply_scan_lines(disruption_id, intensity, effect_duration, config)

## Apply text scrambling effect
func _apply_text_scrambling(disruption_id: String, intensity: float, duration: float, config: Dictionary) -> void:
	if not hud_system:
		return
	
	var effect_data = {
		"disruption_id": disruption_id,
		"intensity": intensity,
		"duration": duration,
		"config": config,
		"scramble_characters": config["characters"],
		"scramble_probability": intensity * 0.5,  # 0-50% characters scrambled
		"original_texts": {}  # Store original text for restoration
	}
	
	# Apply to HUD text elements
	if hud_system.has_method("apply_text_scrambling"):
		hud_system.apply_text_scrambling(effect_data)
	
	visual_corruption_effects["text_scrambling_%s" % disruption_id] = effect_data

## Apply gauge flickering effect
func _apply_gauge_flickering(disruption_id: String, intensity: float, duration: float, config: Dictionary) -> void:
	if not hud_system:
		return
	
	var effect_data = {
		"disruption_id": disruption_id,
		"intensity": intensity,
		"duration": duration,
		"config": config,
		"flicker_rate": config["flicker_rate"] * intensity,
		"flicker_probability": intensity * 0.8,
		"last_flicker_time": 0.0
	}
	
	# Apply to HUD gauges
	if hud_system.has_method("apply_gauge_flickering"):
		hud_system.apply_gauge_flickering(effect_data)
	
	visual_corruption_effects["gauge_flickering_%s" % disruption_id] = effect_data

## Apply display jitter effect
func _apply_display_jitter(disruption_id: String, intensity: float, duration: float, config: Dictionary) -> void:
	var effect_data = {
		"disruption_id": disruption_id,
		"intensity": intensity,
		"duration": duration,
		"config": config,
		"jitter_amplitude": config["jitter_amplitude"] * intensity,
		"original_position": Vector2.ZERO
	}
	
	# Create jitter effect on canvas
	if jitter_container:
		var jitter_amount = effect_data["jitter_amplitude"]
		var jitter_offset = Vector2(
			randf_range(-jitter_amount, jitter_amount),
			randf_range(-jitter_amount, jitter_amount)
		)
		jitter_container.position = jitter_offset
	
	visual_corruption_effects["display_jitter_%s" % disruption_id] = effect_data

## Apply screen flash effect
func _apply_screen_flash(disruption_id: String, intensity: float, duration: float, config: Dictionary) -> void:
	var effect_data = {
		"disruption_id": disruption_id,
		"intensity": intensity,
		"duration": duration,
		"config": config,
		"flash_color": config["flash_color"],
		"flash_alpha": intensity * 0.8,
		"flash_decay_rate": 1.0 / duration
	}
	
	# Create screen flash overlay
	if corruption_overlay:
		corruption_overlay.color = Color(
			effect_data["flash_color"].r,
			effect_data["flash_color"].g,
			effect_data["flash_color"].b,
			effect_data["flash_alpha"]
		)
		corruption_overlay.visible = true
	
	visual_corruption_effects["screen_flash_%s" % disruption_id] = effect_data

## Apply targeting interference
func apply_targeting_interference(interference_level: float, duration: float) -> void:
	if not enable_targeting_interference or not targeting_system:
		return
	
	targeting_interference_level = max(targeting_interference_level, interference_level)
	
	var interference_data = {
		"interference_level": interference_level,
		"duration": duration,
		"start_time": Time.get_ticks_msec() / 1000.0,
		"end_time": (Time.get_ticks_msec() / 1000.0) + duration,
		"random_switching": interference_level > 0.5,
		"lock_disruption": interference_level > 0.3,
		"accuracy_degradation": interference_level
	}
	
	# Apply to targeting system
	if targeting_system.has_method("apply_interference"):
		targeting_system.apply_interference(interference_data)
	
	effects_performance_stats["targeting_interferences"] += 1
	targeting_interference_started.emit(interference_level)

## Apply target switching effect
func _apply_target_switching(disruption_id: String, intensity: float, duration: float, config: Dictionary) -> void:
	if not targeting_system:
		return
	
	var effect_data = {
		"disruption_id": disruption_id,
		"intensity": intensity,
		"duration": duration,
		"config": config,
		"switch_probability": config["switch_probability"] * intensity,
		"last_switch_time": 0.0,
		"switch_interval": 1.0 / max(intensity, 0.1)  # More frequent switches at higher intensity
	}
	
	# Apply random target switching
	if targeting_system.has_method("apply_target_switching"):
		targeting_system.apply_target_switching(effect_data)
	
	visual_corruption_effects["target_switching_%s" % disruption_id] = effect_data

## Apply sensor static effect
func _apply_sensor_static(disruption_id: String, intensity: float, duration: float, config: Dictionary) -> void:
	if not hud_system:
		return
	
	var effect_data = {
		"disruption_id": disruption_id,
		"intensity": intensity,
		"duration": duration,
		"config": config,
		"static_density": config["static_density"] * intensity,
		"static_pattern": _generate_static_pattern(intensity)
	}
	
	# Apply to radar and sensor displays
	if hud_system.has_method("apply_sensor_static"):
		hud_system.apply_sensor_static(effect_data)
	
	visual_corruption_effects["sensor_static_%s" % disruption_id] = effect_data

## Apply color inversion effect
func _apply_color_inversion(disruption_id: String, intensity: float, duration: float, config: Dictionary) -> void:
	var effect_data = {
		"disruption_id": disruption_id,
		"intensity": intensity,
		"duration": duration,
		"config": config,
		"inversion_amount": config["inversion_amount"] * intensity
	}
	
	# Apply color inversion shader
	if corruption_overlay and corruption_overlay.material is ShaderMaterial:
		var shader_material = corruption_overlay.material as ShaderMaterial
		if shader_material.shader:
			shader_material.set_shader_parameter("inversion_amount", effect_data["inversion_amount"])
	
	visual_corruption_effects["color_inversion_%s" % disruption_id] = effect_data

## Apply scan lines effect
func _apply_scan_lines(disruption_id: String, intensity: float, duration: float, config: Dictionary) -> void:
	var effect_data = {
		"disruption_id": disruption_id,
		"intensity": intensity,
		"duration": duration,
		"config": config,
		"line_spacing": config["line_spacing"],
		"line_opacity": intensity * 0.6
	}
	
	# Apply scan lines shader
	if corruption_overlay and corruption_overlay.material is ShaderMaterial:
		var shader_material = corruption_overlay.material as ShaderMaterial
		if shader_material.shader:
			shader_material.set_shader_parameter("scan_line_spacing", effect_data["line_spacing"])
			shader_material.set_shader_parameter("scan_line_opacity", effect_data["line_opacity"])
	
	visual_corruption_effects["scan_lines_%s" % disruption_id] = effect_data

## Apply system degradation
func apply_system_degradation(system: String, degradation_level: float, duration: float) -> void:
	if not enable_system_degradation or not ship_owner:
		return
	
	var degradation_data = {
		"system": system,
		"degradation_level": degradation_level,
		"duration": duration,
		"start_time": Time.get_ticks_msec() / 1000.0,
		"end_time": (Time.get_ticks_msec() / 1000.0) + duration,
		"performance_modifier": 1.0 - degradation_level
	}
	
	# Apply system-specific degradation
	match system:
		"engines":
			if ship_owner.has_method("apply_engine_degradation"):
				ship_owner.apply_engine_degradation(degradation_data)
		"weapons":
			if ship_owner.has_method("apply_weapon_degradation"):
				ship_owner.apply_weapon_degradation(degradation_data)
		"shields":
			if ship_owner.has_method("apply_shield_degradation"):
				ship_owner.apply_shield_degradation(degradation_data)
		"sensors":
			if ship_owner.has_method("apply_sensor_degradation"):
				ship_owner.apply_sensor_degradation(degradation_data)
	
	system_degradation_applied.emit(system, degradation_level)

## Generate static pattern for sensor displays
func _generate_static_pattern(intensity: float) -> Array:
	var pattern: Array = []
	var pattern_size = int(64 * intensity)  # Dynamic pattern size
	
	for i in range(pattern_size):
		pattern.append({
			"x": randi_range(0, 255),
			"y": randi_range(0, 255),
			"intensity": randf() * intensity
		})
	
	return pattern

## Create disruption canvas for visual effects
func _create_disruption_canvas() -> void:
	# Create canvas layer for effects
	disruption_canvas = CanvasLayer.new()
	disruption_canvas.name = "DisruptionCanvas"
	disruption_canvas.layer = 100  # Above HUD
	add_child(disruption_canvas)
	
	# Create main container with jitter capability
	jitter_container = Control.new()
	jitter_container.name = "JitterContainer"
	jitter_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	disruption_canvas.add_child(jitter_container)
	
	# Create corruption overlay
	corruption_overlay = ColorRect.new()
	corruption_overlay.name = "CorruptionOverlay"
	corruption_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corruption_overlay.color = Color.TRANSPARENT
	corruption_overlay.visible = false
	jitter_container.add_child(corruption_overlay)
	
	# Load corruption shader if available
	_load_corruption_shader()

## Load corruption shader for visual effects
func _load_corruption_shader() -> void:
	var shader_path = "res://shaders/hud_corruption.gdshader"
	if ResourceLoader.exists(shader_path):
		var shader = load(shader_path)
		var shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		corruption_overlay.material = shader_material

## Update active effects
func _update_active_effects() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Update HUD disruptions
	_update_hud_disruptions(current_time)
	
	# Update visual corruption effects
	_update_visual_corruption_effects(current_time)
	
	# Update targeting interference
	_update_targeting_interference(current_time)
	
	effects_performance_stats["frame_update_count"] += 1

## Update HUD disruptions
func _update_hud_disruptions(current_time: float) -> void:
	var disruptions_to_remove: Array[String] = []
	
	for disruption_id in active_hud_disruptions.keys():
		var disruption_data = active_hud_disruptions[disruption_id]
		
		if current_time >= disruption_data["end_time"]:
			disruptions_to_remove.append(disruption_id)
			_remove_hud_disruption(disruption_id)
		else:
			# Update intensity decay over time
			var time_remaining = disruption_data["end_time"] - current_time
			var intensity_factor = time_remaining / disruption_data["duration"]
			disruption_data["current_intensity"] = disruption_data["base_intensity"] * intensity_factor
	
	# Remove expired disruptions
	for disruption_id in disruptions_to_remove:
		active_hud_disruptions.erase(disruption_id)
	
	effects_performance_stats["active_hud_effects"] = active_hud_disruptions.size()

## Update visual corruption effects
func _update_visual_corruption_effects(current_time: float) -> void:
	var effects_to_remove: Array[String] = []
	
	for effect_key in visual_corruption_effects.keys():
		var effect_data = visual_corruption_effects[effect_key]
		var end_time = effect_data.get("start_time", current_time) + effect_data["duration"]
		
		if current_time >= end_time:
			effects_to_remove.append(effect_key)
		else:
			# Update effect-specific behavior
			_update_specific_visual_effect(effect_key, effect_data, current_time)
	
	# Remove expired effects
	for effect_key in effects_to_remove:
		_remove_visual_effect(effect_key)
	
	effects_performance_stats["visual_corruptions"] = visual_corruption_effects.size()

## Update specific visual effect
func _update_specific_visual_effect(effect_key: String, effect_data: Dictionary, current_time: float) -> void:
	var effect_type = effect_key.split("_")[0]
	
	match effect_type:
		"display":  # Display jitter
			if jitter_container:
				var jitter_amount = effect_data["jitter_amplitude"]
				var jitter_offset = Vector2(
					randf_range(-jitter_amount, jitter_amount),
					randf_range(-jitter_amount, jitter_amount)
				)
				jitter_container.position = jitter_offset
		
		"screen":  # Screen flash decay
			if corruption_overlay:
				var time_factor = (current_time - effect_data.get("start_time", current_time)) / effect_data["duration"]
				var alpha = effect_data["flash_alpha"] * (1.0 - time_factor)
				var color = corruption_overlay.color
				color.a = alpha
				corruption_overlay.color = color

## Update targeting interference
func _update_targeting_interference(current_time: float) -> void:
	# Targeting interference decay is handled by the targeting system
	# We just need to check if it should be removed
	if targeting_interference_level > 0.0:
		targeting_interference_level = max(0.0, targeting_interference_level - 0.1)
		
		if targeting_interference_level <= 0.0:
			targeting_interference_stopped.emit()

## Remove HUD disruption
func _remove_hud_disruption(disruption_id: String) -> void:
	if hud_system and hud_system.has_method("remove_hud_disruption"):
		hud_system.remove_hud_disruption(disruption_id)

## Remove visual effect
func _remove_visual_effect(effect_key: String) -> void:
	visual_corruption_effects.erase(effect_key)
	
	# Reset visual elements if this was the last effect
	if visual_corruption_effects.is_empty():
		_reset_visual_effects()

## Reset visual effects to normal
func _reset_visual_effects() -> void:
	if jitter_container:
		jitter_container.position = Vector2.ZERO
	
	if corruption_overlay:
		corruption_overlay.color = Color.TRANSPARENT
		corruption_overlay.visible = false

## Get effects system status
func get_effects_system_status() -> Dictionary:
	return {
		"active_hud_disruptions": active_hud_disruptions.size(),
		"visual_corruption_effects": visual_corruption_effects.size(),
		"targeting_interference_level": targeting_interference_level,
		"hud_disruption_enabled": enable_hud_disruption,
		"targeting_interference_enabled": enable_targeting_interference,
		"visual_corruption_enabled": enable_visual_corruption,
		"performance_stats": effects_performance_stats.duplicate()
	}

## Get performance statistics
func get_effects_performance_statistics() -> Dictionary:
	return effects_performance_stats.duplicate()

## Setup special effects manager
func _setup_special_effects_manager() -> void:
	active_hud_disruptions.clear()
	visual_corruption_effects.clear()
	targeting_interference_level = 0.0
	
	effect_update_timer = 0.0
	
	# Reset performance stats
	effects_performance_stats = {
		"total_disruptions_applied": 0,
		"active_hud_effects": 0,
		"targeting_interferences": 0,
		"visual_corruptions": 0,
		"frame_update_count": 0
	}

## Process frame updates
func _process(delta: float) -> void:
	effect_update_timer += delta
	
	# Update effects at regular intervals
	if effect_update_timer >= effect_update_interval:
		effect_update_timer = 0.0
		_update_active_effects()