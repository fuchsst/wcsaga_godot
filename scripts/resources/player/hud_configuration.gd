class_name HUDConfiguration
extends Resource

## HUD configuration resource for storing player interface preferences.
## Controls layout, visibility, and behavior of all HUD elements.

# --- HUD Display Settings ---
@export_group("HUD Display")
@export var hud_scale: float = 1.0              ## Overall HUD scale factor
@export var hud_opacity: float = 1.0            ## HUD transparency (0.0-1.0)
@export var show_hud: bool = true               ## Master HUD visibility toggle
@export var show_fps: bool = false              ## Show FPS counter
@export var hud_color_scheme: int = 0           ## Color scheme index

# --- Radar Configuration ---
@export_group("Radar")
@export var radar_enabled: bool = true          ## Show radar
@export var radar_size: float = 1.0             ## Radar scale factor
@export var radar_position: Vector2 = Vector2(-1, -1) ## Custom radar position (or -1,-1 for default)
@export var radar_range: int = 0                ## Default radar range setting
@export var radar_auto_center: bool = true      ## Auto-center radar on player
@export var show_radar_background: bool = true  ## Show radar background disc

# --- Target Display ---
@export_group("Target Display")
@export var show_target_box: bool = true        ## Show target selection box
@export var show_target_info: bool = true       ## Show target info panel
@export var show_target_lead_indicator: bool = true ## Show lead indicator
@export var show_target_distance: bool = true   ## Show distance to target
@export var target_info_position: Vector2 = Vector2(-1, -1) ## Custom position

# --- Weapons Display ---  
@export_group("Weapons")
@export var show_weapon_info: bool = true       ## Show weapon status
@export var show_secondary_count: bool = true   ## Show secondary weapon count
@export var show_weapon_energy: bool = true     ## Show weapon energy bars
@export var weapon_info_position: Vector2 = Vector2(-1, -1) ## Custom position

# --- Shield and Hull Display ---
@export_group("Shield and Hull")
@export var show_shields: bool = true           ## Show shield display
@export var show_hull_integrity: bool = true    ## Show hull integrity
@export var show_subsystem_status: bool = true  ## Show subsystem damage
@export var shields_position: Vector2 = Vector2(-1, -1) ## Custom position

# --- Communications ---
@export_group("Communications")
@export var show_messages: bool = true          ## Show communication messages
@export var message_timeout: float = 10.0       ## Message display duration
@export var max_messages: int = 5               ## Maximum messages on screen
@export var message_position: Vector2 = Vector2(-1, -1) ## Custom position

# --- Mission Information ---
@export_group("Mission Information")
@export var show_objectives: bool = true        ## Show mission objectives
@export var show_mission_timer: bool = true     ## Show mission time
@export var show_throttle: bool = true          ## Show throttle indicator
@export var show_speed: bool = true             ## Show current speed
@export var objectives_position: Vector2 = Vector2(-1, -1) ## Custom position

# --- Squad Display ---
@export_group("Squad Display")
@export var show_wingman_status: bool = true    ## Show wingman status
@export var show_wingman_orders: bool = true    ## Show current wingman orders
@export var wingman_info_detail: int = 2        ## Detail level: 0=minimal, 1=normal, 2=detailed
@export var wingman_status_position: Vector2 = Vector2(-1, -1) ## Custom position

# --- Debug and Development ---
@export_group("Debug")
@export var show_debug_info: bool = false       ## Show debug information
@export var show_collision_debug: bool = false  ## Show collision shapes
@export var show_ai_debug: bool = false         ## Show AI debug info
@export var debug_text_size: float = 1.0        ## Debug text scale

# --- Accessibility ---
@export_group("Accessibility") 
@export var high_contrast_mode: bool = false    ## High contrast for visibility
@export var colorblind_friendly: bool = false   ## Colorblind-friendly colors
@export var large_text_mode: bool = false       ## Larger text for readability
@export var reduced_motion: bool = false        ## Reduce motion effects
@export var text_scale: float = 1.0             ## Global text scale factor

func _init() -> void:
	_initialize_default_settings()

## Initialize default HUD settings
func _initialize_default_settings() -> void:
	hud_scale = 1.0
	hud_opacity = 1.0
	show_hud = true
	show_fps = false
	hud_color_scheme = 0
	
	radar_enabled = true
	radar_size = 1.0
	radar_range = 0
	radar_auto_center = true
	show_radar_background = true
	
	show_target_box = true
	show_target_info = true
	show_target_lead_indicator = true
	show_target_distance = true
	
	show_weapon_info = true
	show_secondary_count = true
	show_weapon_energy = true
	
	show_shields = true
	show_hull_integrity = true
	show_subsystem_status = true
	
	show_messages = true
	message_timeout = 10.0
	max_messages = 5
	
	show_objectives = true
	show_mission_timer = true
	show_throttle = true
	show_speed = true
	
	show_wingman_status = true
	show_wingman_orders = true
	wingman_info_detail = 2

## Validate all configuration values
func validate_configuration() -> bool:
	var is_valid: bool = true
	
	# Clamp scale and opacity values
	hud_scale = clampf(hud_scale, 0.5, 2.0)
	hud_opacity = clampf(hud_opacity, 0.1, 1.0)
	radar_size = clampf(radar_size, 0.5, 2.0)
	text_scale = clampf(text_scale, 0.5, 2.0)
	debug_text_size = clampf(debug_text_size, 0.5, 2.0)
	
	# Validate message settings
	message_timeout = clampf(message_timeout, 1.0, 60.0)
	max_messages = clampi(max_messages, 1, 10)
	
	# Validate radar range
	radar_range = clampi(radar_range, 0, 5)
	
	# Validate wingman detail level
	wingman_info_detail = clampi(wingman_info_detail, 0, 2)
	
	# Validate color scheme
	hud_color_scheme = clampi(hud_color_scheme, 0, 3)
	
	return is_valid

## Reset to default configuration
func reset_to_defaults() -> void:
	_initialize_default_settings()
	# Reset all custom positions
	radar_position = Vector2(-1, -1)
	target_info_position = Vector2(-1, -1)
	weapon_info_position = Vector2(-1, -1)
	shields_position = Vector2(-1, -1)
	message_position = Vector2(-1, -1)
	objectives_position = Vector2(-1, -1)
	wingman_status_position = Vector2(-1, -1)

## Get HUD visibility settings summary
func get_visibility_summary() -> Dictionary:
	return {
		"hud_enabled": show_hud,
		"radar": radar_enabled,
		"target_info": show_target_info,
		"weapons": show_weapon_info,
		"shields": show_shields,
		"messages": show_messages,
		"objectives": show_objectives,
		"wingman_status": show_wingman_status,
		"debug_mode": show_debug_info
	}

## Apply accessibility settings
func apply_accessibility_settings() -> void:
	if high_contrast_mode:
		# This would trigger high contrast mode in the actual HUD system
		pass
	
	if large_text_mode and text_scale < 1.2:
		text_scale = 1.2
	
	# Additional accessibility settings would be applied here

## Get color scheme name
func get_color_scheme_name() -> String:
	match hud_color_scheme:
		0: return "Default Blue"
		1: return "Classic Green"
		2: return "Amber"
		3: return "High Contrast"
		_: return "Unknown"

## Check if position is custom (not default)
func is_custom_position(position: Vector2) -> bool:
	return position.x >= 0 and position.y >= 0

## Get effective radar position (custom or default)
func get_effective_radar_position() -> Vector2:
	if is_custom_position(radar_position):
		return radar_position
	return Vector2(50, 50)  # Default radar position

## Export configuration for external tools
func export_configuration() -> Dictionary:
	return {
		"display": {
			"hud_scale": hud_scale,
			"hud_opacity": hud_opacity,
			"show_hud": show_hud,
			"color_scheme": get_color_scheme_name()
		},
		"radar": {
			"enabled": radar_enabled,
			"size": radar_size,
			"range": radar_range,
			"auto_center": radar_auto_center
		},
		"accessibility": {
			"high_contrast": high_contrast_mode,
			"large_text": large_text_mode,
			"text_scale": text_scale,
			"reduced_motion": reduced_motion
		},
		"visibility": get_visibility_summary()
	}