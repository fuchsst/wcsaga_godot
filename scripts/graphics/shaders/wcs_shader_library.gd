class_name WCSShaderLibrary
extends RefCounted

## Complete library of WCS-style shader definitions and conversions
## Provides standardized shader configurations for authentic WCS visual effects

static var shader_definitions: Dictionary = {}
static var effect_templates: Dictionary = {}
static var is_initialized: bool = false

## Initialize the shader library with all WCS effect definitions
static func initialize() -> void:
	if is_initialized:
		return
	
	_create_shader_definitions()
	_create_effect_templates()
	is_initialized = true
	print("WCSShaderLibrary: Initialized with %d shader definitions and %d effect templates" % [shader_definitions.size(), effect_templates.size()])

## Get shader definition for a specific effect type
static func get_shader_definition(shader_name: String) -> Dictionary:
	if not is_initialized:
		initialize()
	
	if shader_name in shader_definitions:
		return shader_definitions[shader_name]
	else:
		push_warning("WCSShaderLibrary: Shader definition not found: " + shader_name)
		return {}

## Get effect template with pre-configured parameters
static func get_effect_template(template_name: String) -> Dictionary:
	if not is_initialized:
		initialize()
	
	if template_name in effect_templates:
		return effect_templates[template_name]
	else:
		push_warning("WCSShaderLibrary: Effect template not found: " + template_name)
		return {}

## Get all available shader names
static func get_available_shaders() -> Array[String]:
	if not is_initialized:
		initialize()
	
	return shader_definitions.keys()

## Get all available effect templates
static func get_available_templates() -> Array[String]:
	if not is_initialized:
		initialize()
	
	return effect_templates.keys()

## Create standardized shader parameters for a given weapon type
static func create_weapon_shader_params(weapon_type: String, color: Color = Color.RED, 
                                       intensity: float = 1.0) -> Dictionary:
	match weapon_type.to_lower():
		"laser":
			return {
				"beam_color": Vector3(color.r, color.g, color.b),
				"beam_intensity": intensity,
				"beam_width": 1.0,
				"flicker_speed": 5.0,
				"energy_variation": 0.2
			}
		"plasma":
			return {
				"plasma_color": Vector3(color.r, color.g, color.b),
				"plasma_intensity": intensity,
				"energy_core_size": 0.6,
				"plasma_flicker": 0.3
			}
		"missile":
			return {
				"trail_color": Vector3(color.r, color.g, color.b),
				"exhaust_intensity": intensity,
				"heat_distortion": 0.1,
				"particle_density": 0.8
			}
		_:
			return {}

## Create shield effect parameters based on shield type
static func create_shield_shader_params(shield_strength: float = 1.0, 
                                       shield_color: Color = Color.CYAN) -> Dictionary:
	return {
		"shield_strength": shield_strength,
		"shield_color": Vector3(shield_color.r, shield_color.g, shield_color.b),
		"pulse_speed": 3.0,
		"hexagon_scale": 8.0,
		"impact_intensity": 0.0,
		"impact_position": Vector3.ZERO,
		"impact_radius": 0.5
	}

## Create explosion effect parameters based on explosion type
static func create_explosion_shader_params(explosion_type: String, scale: float = 1.0) -> Dictionary:
	var base_params: Dictionary = {
		"explosion_scale": scale,
		"explosion_intensity": 2.0
	}
	
	match explosion_type.to_lower():
		"small":
			base_params.merge({
				"explosion_color": Vector3(1.0, 0.8, 0.3),  # Orange-yellow
				"explosion_duration": 0.8,
				"debris_count": 50
			})
		"large":
			base_params.merge({
				"explosion_color": Vector3(1.0, 0.5, 0.0),  # Red-orange
				"explosion_duration": 1.5,
				"debris_count": 100
			})
		"nuclear":
			base_params.merge({
				"explosion_color": Vector3(1.0, 1.0, 0.8),  # Bright white-yellow
				"explosion_duration": 2.0,
				"debris_count": 200
			})
		_:
			base_params.merge({
				"explosion_color": Vector3(1.0, 0.6, 0.2),  # Default orange
				"explosion_duration": 1.0,
				"debris_count": 75
			})
	
	return base_params

## Create engine effect parameters for different thruster types
static func create_engine_shader_params(engine_type: String, intensity: float = 1.0, 
                                       color: Color = Color.CYAN) -> Dictionary:
	var base_params: Dictionary = {
		"trail_color": Vector3(color.r, color.g, color.b),
		"trail_intensity": intensity
	}
	
	match engine_type.to_lower():
		"afterburner":
			base_params.merge({
				"scroll_speed": 4.0,
				"flicker_rate": 12.0,
				"heat_distortion": 0.3,
				"trail_width": 1.5
			})
		"thruster":
			base_params.merge({
				"scroll_speed": 2.0,
				"flicker_rate": 8.0,
				"heat_distortion": 0.1,
				"trail_width": 1.0
			})
		"ion_drive":
			base_params.merge({
				"scroll_speed": 1.0,
				"flicker_rate": 3.0,
				"heat_distortion": 0.05,
				"trail_width": 0.8
			})
		_:
			base_params.merge({
				"scroll_speed": 2.0,
				"flicker_rate": 8.0,
				"heat_distortion": 0.1,
				"trail_width": 1.0
			})
	
	return base_params

## Get quality-adjusted parameters for a given quality level
static func get_quality_adjusted_params(base_params: Dictionary, quality_level: int) -> Dictionary:
	var adjusted_params: Dictionary = base_params.duplicate()
	
	match quality_level:
		0, 1:  # Low quality
			if "particle_count" in adjusted_params:
				adjusted_params["particle_count"] = int(adjusted_params["particle_count"] * 0.5)
			if "detail_level" in adjusted_params:
				adjusted_params["detail_level"] = adjusted_params["detail_level"] * 0.3
			if "effect_complexity" in adjusted_params:
				adjusted_params["effect_complexity"] = 0.5
		2:     # Medium quality
			if "particle_count" in adjusted_params:
				adjusted_params["particle_count"] = int(adjusted_params["particle_count"] * 0.75)
			if "detail_level" in adjusted_params:
				adjusted_params["detail_level"] = adjusted_params["detail_level"] * 0.6
			if "effect_complexity" in adjusted_params:
				adjusted_params["effect_complexity"] = 0.75
		3, 4:  # High/Ultra quality
			# Use full parameters
			if "effect_complexity" in adjusted_params:
				adjusted_params["effect_complexity"] = 1.0
	
	return adjusted_params

## Private method to create all shader definitions
static func _create_shader_definitions() -> void:
	shader_definitions = {
		# Material Shaders
		"ship_hull": {
			"path": "res://shaders/materials/ship_hull.gdshader",
			"category": "material",
			"supports_damage": true,
			"supports_rim_lighting": true,
			"default_params": {
				"damage_level": 0.0,
				"hull_metallic": 0.3,
				"hull_roughness": 0.7,
				"hull_tint": Vector3(1.0, 1.0, 1.0),
				"fresnel_power": 2.0
			}
		},
		
		"cockpit_glass": {
			"path": "res://shaders/materials/cockpit_glass.gdshader",
			"category": "material",
			"supports_transparency": true,
			"supports_reflections": true,
			"default_params": {
				"glass_opacity": 0.3,
				"reflection_strength": 0.7,
				"fresnel_power": 1.5,
				"tint_color": Vector3(0.8, 0.9, 1.0)
			}
		},
		
		# Weapon Shaders
		"laser_beam": {
			"path": "res://shaders/weapons/laser_beam.gdshader",
			"category": "weapon",
			"supports_animation": true,
			"supports_noise": true,
			"default_params": {
				"beam_intensity": 2.0,
				"beam_color": Vector3(1.0, 0.0, 0.0),
				"beam_width": 1.0,
				"flicker_speed": 5.0,
				"energy_variation": 0.2
			}
		},
		
		"plasma_bolt": {
			"path": "res://shaders/weapons/plasma_bolt.gdshader",
			"category": "weapon",
			"supports_animation": true,
			"supports_core_glow": true,
			"default_params": {
				"plasma_color": Vector3(0.0, 1.0, 0.0),
				"plasma_intensity": 1.5,
				"energy_core_size": 0.6,
				"plasma_flicker": 0.3
			}
		},
		
		"missile_trail": {
			"path": "res://shaders/weapons/missile_trail.gdshader",
			"category": "weapon",
			"supports_heat_distortion": true,
			"supports_particles": true,
			"default_params": {
				"trail_color": Vector3(1.0, 0.5, 0.0),
				"exhaust_intensity": 1.0,
				"heat_distortion": 0.1,
				"particle_density": 0.8
			}
		},
		
		"weapon_impact": {
			"path": "res://shaders/weapons/weapon_impact.gdshader",
			"category": "weapon",
			"supports_sparks": true,
			"supports_flash": true,
			"default_params": {
				"impact_intensity": 2.0,
				"spark_count": 100,
				"flash_duration": 0.1,
				"impact_color": Vector3(1.0, 0.8, 0.0)
			}
		},
		
		# Effect Shaders
		"energy_shield": {
			"path": "res://shaders/effects/energy_shield.gdshader",
			"category": "effect",
			"supports_fresnel": true,
			"supports_impact_ripples": true,
			"default_params": {
				"shield_strength": 1.0,
				"shield_color": Vector3(0.0, 0.5, 1.0),
				"pulse_speed": 3.0,
				"hexagon_scale": 8.0
			}
		},
		
		"engine_trail": {
			"path": "res://shaders/effects/engine_trail.gdshader",
			"category": "effect",
			"supports_scrolling": true,
			"supports_flicker": true,
			"default_params": {
				"trail_color": Vector3(0.0, 0.8, 1.0),
				"trail_intensity": 1.0,
				"scroll_speed": 2.0,
				"flicker_rate": 8.0
			}
		},
		
		"explosion_core": {
			"path": "res://shaders/effects/explosion_core.gdshader",
			"category": "effect",
			"supports_expansion": true,
			"supports_multi_stage": true,
			"default_params": {
				"explosion_scale": 1.0,
				"explosion_intensity": 2.0,
				"explosion_color": Vector3(1.0, 0.5, 0.0)
			}
		},
		
		"explosion_debris": {
			"path": "res://shaders/effects/explosion_debris.gdshader",
			"category": "effect",
			"supports_fragments": true,
			"supports_scattering": true,
			"default_params": {
				"debris_count": 75,
				"scatter_velocity": 5.0,
				"fragment_size": 0.1,
				"debris_color": Vector3(0.8, 0.4, 0.1)
			}
		},
		
		# Environment Shaders
		"nebula": {
			"path": "res://shaders/environment/nebula.gdshader",
			"category": "environment",
			"supports_volumetric": true,
			"supports_density_mapping": true,
			"default_params": {
				"nebula_density": 0.5,
				"color_variation": 0.3,
				"depth_fade": 2.0,
				"nebula_color": Vector3(0.5, 0.3, 0.8)
			}
		},
		
		"space_dust": {
			"path": "res://shaders/environment/space_dust.gdshader",
			"category": "environment",
			"supports_movement": true,
			"supports_depth_sorting": true,
			"default_params": {
				"dust_density": 0.3,
				"movement_speed": 1.0,
				"particle_size": 0.02,
				"dust_color": Vector3(0.8, 0.8, 0.9)
			}
		},
		
		# Post-processing Shaders
		"bloom_filter": {
			"path": "res://shaders/post_processing/bloom_filter.gdshader",
			"category": "post_processing",
			"supports_hdr": true,
			"supports_threshold": true,
			"default_params": {
				"bloom_threshold": 1.0,
				"bloom_intensity": 0.8,
				"bloom_radius": 2.0
			}
		},
		
		"motion_blur": {
			"path": "res://shaders/post_processing/motion_blur.gdshader",
			"category": "post_processing",
			"supports_velocity_mapping": true,
			"supports_quality_scaling": true,
			"default_params": {
				"blur_strength": 0.5,
				"sample_count": 8,
				"velocity_scale": 1.0
			}
		}
	}

## Private method to create effect templates
static func _create_effect_templates() -> void:
	effect_templates = {
		# Weapon Effect Templates
		"laser_red": {
			"shader": "laser_beam",
			"params": create_weapon_shader_params("laser", Color.RED, 2.0)
		},
		
		"laser_green": {
			"shader": "laser_beam", 
			"params": create_weapon_shader_params("laser", Color.GREEN, 1.8)
		},
		
		"laser_blue": {
			"shader": "laser_beam",
			"params": create_weapon_shader_params("laser", Color.BLUE, 2.2)
		},
		
		"plasma_heavy": {
			"shader": "plasma_bolt",
			"params": create_weapon_shader_params("plasma", Color.ORANGE, 2.5)
		},
		
		"plasma_light": {
			"shader": "plasma_bolt",
			"params": create_weapon_shader_params("plasma", Color.YELLOW, 1.2)
		},
		
		"missile_standard": {
			"shader": "missile_trail",
			"params": create_weapon_shader_params("missile", Color.ORANGE, 1.5)
		},
		
		"missile_torpedo": {
			"shader": "missile_trail",
			"params": create_weapon_shader_params("missile", Color.WHITE, 2.0)
		},
		
		# Shield Effect Templates
		"shield_standard": {
			"shader": "energy_shield",
			"params": create_shield_shader_params(1.0, Color.CYAN)
		},
		
		"shield_heavy": {
			"shader": "energy_shield",
			"params": create_shield_shader_params(1.5, Color.BLUE)
		},
		
		"shield_light": {
			"shader": "energy_shield",
			"params": create_shield_shader_params(0.7, Color.GREEN)
		},
		
		# Engine Effect Templates
		"engine_afterburner": {
			"shader": "engine_trail",
			"params": create_engine_shader_params("afterburner", 2.0, Color.CYAN)
		},
		
		"engine_thruster": {
			"shader": "engine_trail",
			"params": create_engine_shader_params("thruster", 1.0, Color.BLUE)
		},
		
		"engine_ion": {
			"shader": "engine_trail",
			"params": create_engine_shader_params("ion_drive", 0.8, Color.WHITE)
		},
		
		# Explosion Effect Templates
		"explosion_fighter": {
			"shader": "explosion_core",
			"params": create_explosion_shader_params("small", 1.0)
		},
		
		"explosion_capital": {
			"shader": "explosion_core",
			"params": create_explosion_shader_params("large", 3.0)
		},
		
		"explosion_nuclear": {
			"shader": "explosion_core",
			"params": create_explosion_shader_params("nuclear", 5.0)
		},
		
		# Material Effect Templates
		"hull_damaged": {
			"shader": "ship_hull",
			"params": {
				"damage_level": 0.7,
				"hull_metallic": 0.4,
				"hull_roughness": 0.8,
				"hull_tint": Vector3(0.8, 0.6, 0.6),
				"fresnel_power": 1.5
			}
		},
		
		"hull_pristine": {
			"shader": "ship_hull",
			"params": {
				"damage_level": 0.0,
				"hull_metallic": 0.6,
				"hull_roughness": 0.3,
				"hull_tint": Vector3(1.0, 1.0, 1.0),
				"fresnel_power": 2.0
			}
		},
		
		"cockpit_clear": {
			"shader": "cockpit_glass",
			"params": {
				"glass_opacity": 0.2,
				"reflection_strength": 0.8,
				"fresnel_power": 1.2,
				"tint_color": Vector3(0.9, 0.95, 1.0)
			}
		},
		
		"cockpit_tinted": {
			"shader": "cockpit_glass",
			"params": {
				"glass_opacity": 0.4,
				"reflection_strength": 0.6,
				"fresnel_power": 1.8,
				"tint_color": Vector3(0.7, 0.8, 0.9)
			}
		}
	}

## Get shader category for a given shader name
static func get_shader_category(shader_name: String) -> String:
	var definition: Dictionary = get_shader_definition(shader_name)
	return definition.get("category", "unknown")

## Check if shader supports a specific feature
static func shader_supports_feature(shader_name: String, feature: String) -> bool:
	var definition: Dictionary = get_shader_definition(shader_name)
	return definition.get("supports_" + feature, false)

## Get default parameters for a shader
static func get_default_shader_params(shader_name: String) -> Dictionary:
	var definition: Dictionary = get_shader_definition(shader_name)
	return definition.get("default_params", {})

## Create a customized effect template
static func create_custom_template(template_name: String, shader_name: String, 
                                 custom_params: Dictionary) -> void:
	var base_params: Dictionary = get_default_shader_params(shader_name)
	base_params.merge(custom_params)
	
	effect_templates[template_name] = {
		"shader": shader_name,
		"params": base_params
	}
	
	print("WCSShaderLibrary: Created custom template '%s' for shader '%s'" % [template_name, shader_name])