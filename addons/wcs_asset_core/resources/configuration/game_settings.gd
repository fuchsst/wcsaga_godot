class_name GameSettings
extends Resource

## Game-specific settings resource for gameplay configuration.
## Controls difficulty, gameplay options, and game-specific preferences.

signal setting_changed(setting_name: String, old_value: Variant, new_value: Variant)

# --- Difficulty and Gameplay ---
@export_group("Difficulty and Gameplay")
@export var difficulty_level: int = 2           ## 0=Very Easy, 1=Easy, 2=Medium, 3=Hard, 4=Insane
@export var auto_targeting: bool = true         ## Enable auto-targeting system
@export var auto_speed_matching: bool = false   ## Auto-match target speed
@export var auto_pilot_enabled: bool = true     ## Enable autopilot functionality
@export var collision_warnings: bool = true     ## Show collision warnings
@export var damage_flash: bool = true           ## Flash screen on damage

# --- HUD and Interface ---
@export_group("HUD and Interface")
@export var show_damage_popup: bool = true      ## Show damage pop-up text
@export var show_subsystem_targeting: bool = true ## Show subsystem targeting brackets
@export var show_kill_messages: bool = true     ## Show kill confirmation messages
@export var show_mission_messages: bool = true  ## Show mission event messages
@export var briefing_voice_enabled: bool = true ## Enable briefing voice acting
@export var debriefing_voice_enabled: bool = true ## Enable debriefing voice acting

# --- Combat Assistance ---
@export_group("Combat Assistance")
@export var leading_indicator: bool = true      ## Show weapons leading indicator  
@export var auto_target_subsystems: bool = false ## Auto-target damaged subsystems
@export var weapon_autofire: bool = false       ## Enable weapon autofire
@export var missile_lock_warning: bool = true   ## Show missile lock warnings
@export var afterburner_ramping: bool = true    ## Smooth afterburner acceleration

# --- Flight Model ---
@export_group("Flight Model")
@export var flight_assist: bool = true          ## Enable flight assistance
@export var inertia_dampening: bool = true      ## Enable inertia dampening
@export var sliding_enabled: bool = true        ## Enable ship sliding physics
@export var newtonian_physics: bool = false     ## Use Newtonian physics model
@export var realistic_weapon_physics: bool = false ## Use realistic weapon ballistics

# --- Campaign and Progress ---
@export_group("Campaign and Progress")
@export var campaign_persistent_ships: bool = true ## Ships carry between missions
@export var permadeath_wingmen: bool = false    ## Wingmen deaths are permanent
@export var skip_training_missions: bool = false ## Skip training missions in campaigns
@export var auto_advance_briefings: bool = false ## Auto-advance briefing stages

# --- Accessibility ---
@export_group("Accessibility")
@export var colorblind_friendly_ui: bool = false ## Use colorblind-friendly colors
@export var high_contrast_hud: bool = false     ## High contrast HUD elements
@export var large_text_mode: bool = false       ## Use larger text sizes
@export var reduced_screen_effects: bool = false ## Reduce screen shake/flash effects
@export var subtitle_enabled: bool = true       ## Show subtitles for dialogue

# --- Debug and Development ---
@export_group("Debug and Development")
@export var debug_mode_enabled: bool = false    ## Enable debug features
@export var show_fps_counter: bool = false      ## Show FPS counter
@export var show_performance_stats: bool = false ## Show performance statistics
@export var enable_cheats: bool = false         ## Enable cheat commands
@export var log_level: int = 1                  ## 0=Error, 1=Warning, 2=Info, 3=Debug

func _init() -> void:
	_initialize_defaults()

## Initialize with WCS-compatible default values
func _initialize_defaults() -> void:
	difficulty_level = 2
	auto_targeting = true
	auto_speed_matching = false
	auto_pilot_enabled = true
	collision_warnings = true
	damage_flash = true
	
	show_damage_popup = true
	show_subsystem_targeting = true
	show_kill_messages = true
	show_mission_messages = true
	briefing_voice_enabled = true
	debriefing_voice_enabled = true
	
	leading_indicator = true
	auto_target_subsystems = false
	weapon_autofire = false
	missile_lock_warning = true
	afterburner_ramping = true
	
	flight_assist = true
	inertia_dampening = true
	sliding_enabled = true
	newtonian_physics = false
	realistic_weapon_physics = false
	
	campaign_persistent_ships = true
	permadeath_wingmen = false
	skip_training_missions = false
	auto_advance_briefings = false
	
	colorblind_friendly_ui = false
	high_contrast_hud = false
	large_text_mode = false
	reduced_screen_effects = false
	subtitle_enabled = true
	
	debug_mode_enabled = false
	show_fps_counter = false
	show_performance_stats = false
	enable_cheats = false
	log_level = 1

## Set difficulty level with validation
func set_difficulty_level(level: int) -> bool:
	if level < 0 or level > 4:
		return false
	
	var old_value: int = difficulty_level
	difficulty_level = level
	setting_changed.emit("difficulty_level", old_value, level)
	return true

## Get difficulty level name
func get_difficulty_name() -> String:
	match difficulty_level:
		0: return "Very Easy"
		1: return "Easy"
		2: return "Medium"
		3: return "Hard"
		4: return "Insane"
		_: return "Unknown"

## Set log level with validation
func set_log_level(level: int) -> bool:
	if level < 0 or level > 3:
		return false
	
	var old_value: int = log_level
	log_level = level
	setting_changed.emit("log_level", old_value, level)
	return true

## Get log level name
func get_log_level_name() -> String:
	match log_level:
		0: return "Error Only"
		1: return "Warnings"
		2: return "Information"
		3: return "Debug"
		_: return "Unknown"

## Validate all settings and correct invalid values
func validate_settings() -> Dictionary:
	var validation_result: Dictionary = {
		"is_valid": true,
		"corrections": [],
		"warnings": []
	}
	
	# Validate difficulty level
	if difficulty_level < 0 or difficulty_level > 4:
		validation_result.corrections.append("Difficulty level corrected to Medium")
		difficulty_level = 2
		validation_result.is_valid = false
	
	# Validate log level
	if log_level < 0 or log_level > 3:
		validation_result.corrections.append("Log level corrected to Warning")
		log_level = 1
		validation_result.is_valid = false
	
	# Check for conflicting settings
	if newtonian_physics and flight_assist:
		validation_result.warnings.append("Newtonian physics with flight assist may feel inconsistent")
	
	if weapon_autofire and auto_targeting:
		validation_result.warnings.append("Autofire with auto-targeting may be overpowered")
	
	if debug_mode_enabled and not enable_cheats:
		validation_result.warnings.append("Debug mode enabled but cheats disabled")
	
	return validation_result

## Reset all settings to defaults
func reset_to_defaults() -> void:
	_initialize_defaults()
	setting_changed.emit("reset_all", null, null)

## Reset specific category to defaults
func reset_category_to_defaults(category: String) -> void:
	match category:
		"difficulty":
			difficulty_level = 2
			auto_targeting = true
			auto_speed_matching = false
			auto_pilot_enabled = true
			collision_warnings = true
			damage_flash = true
		
		"hud":
			show_damage_popup = true
			show_subsystem_targeting = true
			show_kill_messages = true
			show_mission_messages = true
			briefing_voice_enabled = true
			debriefing_voice_enabled = true
		
		"combat":
			leading_indicator = true
			auto_target_subsystems = false
			weapon_autofire = false
			missile_lock_warning = true
			afterburner_ramping = true
		
		"flight":
			flight_assist = true
			inertia_dampening = true
			sliding_enabled = true
			newtonian_physics = false
			realistic_weapon_physics = false
		
		"campaign":
			campaign_persistent_ships = true
			permadeath_wingmen = false
			skip_training_missions = false
			auto_advance_briefings = false
		
		"accessibility":
			colorblind_friendly_ui = false
			high_contrast_hud = false
			large_text_mode = false
			reduced_screen_effects = false
			subtitle_enabled = true
		
		"debug":
			debug_mode_enabled = false
			show_fps_counter = false
			show_performance_stats = false
			enable_cheats = false
			log_level = 1
	
	setting_changed.emit("reset_category", category, null)

## Get all settings as dictionary for export
func get_settings_dictionary() -> Dictionary:
	return {
		"difficulty_gameplay": {
			"difficulty_level": difficulty_level,
			"auto_targeting": auto_targeting,
			"auto_speed_matching": auto_speed_matching,
			"auto_pilot_enabled": auto_pilot_enabled,
			"collision_warnings": collision_warnings,
			"damage_flash": damage_flash
		},
		"hud_interface": {
			"show_damage_popup": show_damage_popup,
			"show_subsystem_targeting": show_subsystem_targeting,
			"show_kill_messages": show_kill_messages,
			"show_mission_messages": show_mission_messages,
			"briefing_voice_enabled": briefing_voice_enabled,
			"debriefing_voice_enabled": debriefing_voice_enabled
		},
		"combat_assistance": {
			"leading_indicator": leading_indicator,
			"auto_target_subsystems": auto_target_subsystems,
			"weapon_autofire": weapon_autofire,
			"missile_lock_warning": missile_lock_warning,
			"afterburner_ramping": afterburner_ramping
		},
		"flight_model": {
			"flight_assist": flight_assist,
			"inertia_dampening": inertia_dampening,
			"sliding_enabled": sliding_enabled,
			"newtonian_physics": newtonian_physics,
			"realistic_weapon_physics": realistic_weapon_physics
		},
		"campaign_progress": {
			"campaign_persistent_ships": campaign_persistent_ships,
			"permadeath_wingmen": permadeath_wingmen,
			"skip_training_missions": skip_training_missions,
			"auto_advance_briefings": auto_advance_briefings
		},
		"accessibility": {
			"colorblind_friendly_ui": colorblind_friendly_ui,
			"high_contrast_hud": high_contrast_hud,
			"large_text_mode": large_text_mode,
			"reduced_screen_effects": reduced_screen_effects,
			"subtitle_enabled": subtitle_enabled
		},
		"debug": {
			"debug_mode_enabled": debug_mode_enabled,
			"show_fps_counter": show_fps_counter,
			"show_performance_stats": show_performance_stats,
			"enable_cheats": enable_cheats,
			"log_level": log_level
		}
	}

## Import settings from dictionary with validation
func import_settings_dictionary(settings: Dictionary) -> bool:
	var success: bool = true
	
	for category in settings.keys():
		var category_settings: Dictionary = settings[category]
		for setting_name in category_settings.keys():
			var value: Variant = category_settings[setting_name]
			
			# Apply setting with validation
			if not _set_setting_by_name(setting_name, value):
				printerr("Failed to import setting: ", setting_name, " = ", value)
				success = false
	
	var validation: Dictionary = validate_settings()
	if not validation.is_valid:
		success = false
	
	return success

## Set setting by name (internal helper)
func _set_setting_by_name(setting_name: String, value: Variant) -> bool:
	match setting_name:
		"difficulty_level": return set_difficulty_level(value)
		"log_level": return set_log_level(value)
		_:
			# Use reflection for other boolean/simple settings
			if setting_name in self:
				var old_value: Variant = get(setting_name)
				set(setting_name, value)
				setting_changed.emit(setting_name, old_value, value)
				return true
			return false

## Check if setting is enabled for accessibility
func is_accessibility_mode_active() -> bool:
	return colorblind_friendly_ui or high_contrast_hud or large_text_mode or reduced_screen_effects

## Get gameplay difficulty modifiers
func get_difficulty_modifiers() -> Dictionary:
	return {
		"enemy_accuracy_multiplier": 0.5 + (difficulty_level * 0.2),  # 0.5 to 1.3
		"enemy_damage_multiplier": 0.7 + (difficulty_level * 0.15),   # 0.7 to 1.3
		"player_damage_resistance": 1.3 - (difficulty_level * 0.15),  # 1.3 to 0.7
		"mission_time_limit_multiplier": 1.2 - (difficulty_level * 0.05) # 1.2 to 1.0
	}