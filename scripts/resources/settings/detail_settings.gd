class_name DetailSettings
extends Resource
## Global graphics/detail settings (shared across all profiles).
## Mirrors legacy detail_levels_struct from options menu.

## Detail preset: 0=Low, 1=Medium, 2=High, 3=Very High, 4=Custom
@export_range(0, 4) var preset: int = 2

## Model LOD detail level (0-4)
@export_range(0, 4) var model_detail: int = 4

## Nebula/volumetric detail (0-4)
@export_range(0, 4) var nebula_detail: int = 4

## Texture quality/filtering (0-4)
@export_range(0, 4) var texture_quality: int = 4

## Particle count multiplier (0-4)
@export_range(0, 4) var particle_count: int = 4

## Debris/shard count (0-4)
@export_range(0, 4) var debris_count: int = 4

## Shield hit effect quality (0-4)
@export_range(0, 4) var shield_effects: int = 4

## Star/background density (0-4)
@export_range(0, 4) var star_count: int = 4

## Lighting quality (0-4)
@export_range(0, 4) var lighting_quality: int = 4

## Render planets and backgrounds
@export var planets_enabled: bool = true

## Render 3D target view in HUD
@export var target_view_render: bool = true

## Extra weapon visual effects (trails, glow)
@export var weapon_extras: bool = true


## Apply a preset level (0-3), sets preset to 4 (Custom) if manual.
func apply_preset(level: int) -> void:
	preset = level
	model_detail = level + 1
	nebula_detail = level + 1
	texture_quality = level + 1
	particle_count = level + 1
	debris_count = level + 1
	shield_effects = level + 1
	star_count = level + 1
	lighting_quality = level + 1

	match level:
		0: # Low
			planets_enabled = false
			target_view_render = false
			weapon_extras = false
		1: # Medium
			planets_enabled = true
			target_view_render = false
			weapon_extras = false
		2: # High
			planets_enabled = true
			target_view_render = true
			weapon_extras = false
		3, 4: # Very High / Custom
			planets_enabled = true
			target_view_render = true
			weapon_extras = true


## Get preset name.
static func get_preset_name(level: int) -> String:
	match level:
		0: return "Low"
		1: return "Medium"
		2: return "High"
		3: return "Very High"
		4: return "Custom"
		_: return "Unknown"
