## WCS Lighting Configuration Resource
## Holds Wing Commander Saga-specific lighting parameters extracted from legacy C++ code
## See source/code/lighting/lighting.cpp for original values

class_name WCSLightingConfig
extends Resource

# ==============================================================================
# AMBIENT LIGHTING
# ==============================================================================

## Base ambient light level (legacy: AMBIENT_LIGHT_DEFAULT = 0.15)
@export_range(0.0, 1.0) var ambient_light: float = 0.15

## Material reflectiveness (legacy: REFLECTIVE_LIGHT_DEFAULT = 0.75)
@export_range(0.0, 1.0) var reflective_light: float = 0.75

# ==============================================================================
# LIGHT TYPE MULTIPLIERS
# ==============================================================================

## Directional/sun light intensity multiplier (legacy: static_light_factor = 3.0)
## This is the "Wing Commander Saga look" enhancement
@export_range(0.1, 10.0) var sun_light_factor: float = 3.0

## Point light intensity multiplier (legacy: static_point_factor = 8.6)
## Higher value for explosions and weapon flashes
@export_range(0.1, 20.0) var point_light_factor: float = 8.6

## Tube light intensity multiplier (legacy: static_tube_factor = 1.0)
## Used for beam weapons
@export_range(0.1, 10.0) var tube_light_factor: float = 1.0

# ==============================================================================
# SPECULAR SETTINGS
# ==============================================================================

## Specular exponent (legacy: specular_exponent_value = 16.0)
@export_range(1.0, 128.0) var specular_exponent: float = 16.0

# ==============================================================================
# LIGHT ATTENUATION
# ==============================================================================

## Minimum light threshold below which lights are ignored
## (legacy: MIN_LIGHT = 0.03 or 1/32)
@export_range(0.001, 0.1) var min_light_threshold: float = 0.03

# ==============================================================================
# SHADOW SETTINGS
# ==============================================================================

## Enable shadow casting for primary sun
@export var sun_shadows_enabled: bool = true

## Shadow bias to reduce artifacts
@export_range(0.0, 0.1) var shadow_bias: float = 0.02

# ==============================================================================
# HELPER METHODS
# ==============================================================================


## Apply ambient light to a WorldEnvironment
func apply_to_environment(env: Environment) -> void:
	if not env:
		return
	env.ambient_light_energy = ambient_light


## Calculate effective sun energy
func get_sun_energy(base_intensity: float = 1.0) -> float:
	return base_intensity * sun_light_factor * reflective_light


## Calculate effective point light energy
func get_point_light_energy(base_intensity: float = 1.0) -> float:
	return base_intensity * point_light_factor


## Calculate effective tube light energy
func get_tube_light_energy(base_intensity: float = 1.0) -> float:
	return base_intensity * tube_light_factor


## Create default WCS lighting config
static func create_default() -> WCSLightingConfig:
	var config := WCSLightingConfig.new()
	# All defaults are set via @export, just return
	return config
