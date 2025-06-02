class_name PilotDataCoordinator
extends Node

## Central coordinator for pilot management and statistics
## Integrates existing PlayerProfile and PilotStatistics resources with enhanced tracking
## Coordinates between SaveGameManager, AchievementManager, and PilotPerformanceTracker

signal pilot_profile_created(pilot_profile: PlayerProfile)
signal pilot_profile_loaded(pilot_profile: PlayerProfile)
signal pilot_profile_saved(pilot_profile: PlayerProfile, save_slot: int)
signal statistics_updated(pilot_profile: PlayerProfile, mission_result: Dictionary)
signal achievement_system_updated(pilot_profile: PlayerProfile, new_achievements: Array[String], new_medals: Array[String])
signal pilot_performance_analyzed(pilot_profile: PlayerProfile, performance_summary: Dictionary)

# Component managers
var achievement_manager: AchievementManager
var performance_tracker: PilotPerformanceTracker

# Configuration
@export var auto_save_enabled: bool = true
@export var enable_achievement_checking: bool = true
@export var enable_performance_tracking: bool = true
@export var statistics_update_interval: float = 1.0  # Seconds between statistics updates

# State management
var current_pilot_profile: PlayerProfile
var active_save_slot: int = -1
var statistics_update_timer: Timer
var is_mission_active: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_coordinator()

## Initialize pilot data coordinator
func _initialize_coordinator() -> void:
	print("PilotDataCoordinator: Initializing pilot data coordination system...")
	
	# Initialize component managers
	_setup_component_managers()
	
	# Setup statistics update timer
	_setup_statistics_timer()
	
	# Connect to GameStateManager signals for mission tracking
	_connect_game_state_signals()
	
	print("PilotDataCoordinator: Pilot data coordinator initialized")

## Setup component managers
func _setup_component_managers() -> void:
	# Create achievement manager
	achievement_manager = AchievementManager.new()
	achievement_manager.name = "AchievementManager"
	add_child(achievement_manager)
	
	# Create performance tracker
	performance_tracker = PilotPerformanceTracker.new()
	performance_tracker.name = "PilotPerformanceTracker"
	add_child(performance_tracker)
	
	# Connect signals
	_connect_component_signals()

## Connect component manager signals
func _connect_component_signals() -> void:
	# Achievement manager signals
	if achievement_manager:
		achievement_manager.achievement_earned.connect(_on_achievement_earned)
		achievement_manager.medal_awarded.connect(_on_medal_awarded)
		achievement_manager.rank_promoted.connect(_on_rank_promoted)
	
	# Performance tracker signals
	if performance_tracker:
		performance_tracker.performance_updated.connect(_on_performance_updated)
		performance_tracker.milestone_reached.connect(_on_milestone_reached)
		performance_tracker.performance_trend_changed.connect(_on_performance_trend_changed)

## Setup statistics update timer
func _setup_statistics_timer() -> void:
	statistics_update_timer = Timer.new()
	statistics_update_timer.wait_time = statistics_update_interval
	statistics_update_timer.timeout.connect(_on_statistics_update_timer_timeout)
	statistics_update_timer.one_shot = false
	add_child(statistics_update_timer)

## Connect to GameStateManager signals
func _connect_game_state_signals() -> void:
	if GameStateManager:
		GameStateManager.state_changed.connect(_on_game_state_changed)

## Create new pilot profile with comprehensive initialization
func create_pilot_profile(callsign: String, save_slot: int = -1) -> PlayerProfile:
	if callsign.is_empty():
		push_error("PilotDataCoordinator: Cannot create pilot with empty callsign")
		return null
	
	print("PilotDataCoordinator: Creating new pilot profile: %s" % callsign)
	
	# Create new PlayerProfile using existing resource
	var pilot_profile: PlayerProfile = PlayerProfile.new()
	
	# Set callsign using existing validation method
	if not pilot_profile.set_callsign(callsign):
		push_error("PilotDataCoordinator: Invalid callsign: %s" % callsign)
		return null
	
	# The PlayerProfile constructor automatically initializes:
	# - pilot_stats (PilotStatistics resource)
	# - campaigns (Array of CampaignInfo)
	# - keyed_targets (Array of HotkeyTarget)
	# - control_config (ControlConfiguration)
	# - hud_config (HUDConfiguration)
	
	# Validate profile using existing method
	var validation_result: Dictionary = pilot_profile.validate_profile()
	if not validation_result.is_valid:
		push_error("PilotDataCoordinator: Pilot profile validation failed: %s" % validation_result.errors)
		return null
	
	# Save profile using existing SaveGameManager
	var target_slot: int = save_slot
	if target_slot == -1:
		# Find available slot
		target_slot = _find_available_save_slot()
		if target_slot == -1:
			push_error("PilotDataCoordinator: No available save slots")
			return null
	
	# Save using existing SaveGameManager
	var save_success: bool = SaveGameManager.save_player_profile(pilot_profile, target_slot, SaveGameManager.SaveSlotInfo.SaveType.MANUAL)
	if not save_success:
		push_error("PilotDataCoordinator: Failed to save pilot profile: %s" % callsign)
		return null
	
	# Set as current pilot
	current_pilot_profile = pilot_profile
	active_save_slot = target_slot
	
	# Emit creation signal
	pilot_profile_created.emit(pilot_profile)
	
	print("PilotDataCoordinator: Pilot profile created successfully: %s (Slot: %d)" % [callsign, target_slot])
	return pilot_profile

## Load pilot profile from save slot
func load_pilot_profile(save_slot: int) -> PlayerProfile:
	print("PilotDataCoordinator: Loading pilot profile from slot: %d" % save_slot)
	
	# Use existing SaveGameManager to load PlayerProfile
	var pilot_profile: PlayerProfile = SaveGameManager.load_player_profile(save_slot)
	if not pilot_profile:
		push_error("PilotDataCoordinator: Failed to load pilot profile from slot: %d" % save_slot)
		return null
	
	# Validate loaded profile using existing method
	var validation_result: Dictionary = pilot_profile.validate_profile()
	if not validation_result.is_valid:
		push_error("PilotDataCoordinator: Loaded pilot profile validation failed: %s" % validation_result.errors)
		return null
	
	# Set as current pilot
	current_pilot_profile = pilot_profile
	active_save_slot = save_slot
	
	# Emit loaded signal
	pilot_profile_loaded.emit(pilot_profile)
	
	print("PilotDataCoordinator: Pilot profile loaded successfully: %s" % pilot_profile.callsign)
	return pilot_profile

## Save current pilot profile
func save_current_pilot_profile() -> bool:
	if not current_pilot_profile:
		push_warning("PilotDataCoordinator: No current pilot profile to save")
		return false
	
	if active_save_slot == -1:
		push_error("PilotDataCoordinator: No active save slot for current pilot")
		return false
	
	# Use existing SaveGameManager for atomic save operations
	var success: bool = SaveGameManager.save_player_profile(current_pilot_profile, active_save_slot, SaveGameManager.SaveSlotInfo.SaveType.MANUAL)
	if success:
		pilot_profile_saved.emit(current_pilot_profile, active_save_slot)
		print("PilotDataCoordinator: Pilot profile saved successfully: %s" % current_pilot_profile.callsign)
	else:
		push_error("PilotDataCoordinator: Failed to save pilot profile: %s" % current_pilot_profile.callsign)
	
	return success

## Update pilot statistics from mission results
func update_pilot_statistics(mission_result: Dictionary) -> void:
	if not current_pilot_profile or not current_pilot_profile.pilot_stats:
		push_warning("PilotDataCoordinator: No current pilot profile or statistics available")
		return
	
	print("PilotDataCoordinator: Updating pilot statistics for: %s" % current_pilot_profile.callsign)
	
	# Update performance tracking if enabled
	if enable_performance_tracking and performance_tracker:
		performance_tracker.record_mission_performance(current_pilot_profile, mission_result)
	
	# Check achievements if enabled
	var new_achievements: Array[String] = []
	var new_medals: Array[String] = []
	
	if enable_achievement_checking and achievement_manager:
		new_achievements = achievement_manager.check_pilot_achievements(current_pilot_profile)
		new_medals = achievement_manager.check_pilot_medals(current_pilot_profile)
		
		# Check rank progression
		achievement_manager.check_rank_progression(current_pilot_profile)
	
	# Auto-save if enabled
	if auto_save_enabled:
		save_current_pilot_profile()
	
	# Emit update signals
	statistics_updated.emit(current_pilot_profile, mission_result)
	
	if not new_achievements.is_empty() or not new_medals.is_empty():
		achievement_system_updated.emit(current_pilot_profile, new_achievements, new_medals)

## Get comprehensive pilot summary
func get_pilot_summary(pilot_profile: PlayerProfile = null) -> Dictionary:
	var target_profile: PlayerProfile = pilot_profile if pilot_profile else current_pilot_profile
	if not target_profile:
		return {}
	
	var summary: Dictionary = {
		"basic_info": target_profile.get_profile_summary(),
		"statistics": _get_statistics_summary(target_profile),
		"achievements": _get_achievement_summary(target_profile),
		"performance": _get_performance_summary(target_profile),
		"recent_activity": _get_recent_activity_summary(target_profile)
	}
	
	return summary

## Get statistics summary
func _get_statistics_summary(pilot_profile: PlayerProfile) -> Dictionary:
	if not pilot_profile.pilot_stats:
		return {}
	
	var stats: PilotStatistics = pilot_profile.pilot_stats
	
	return {
		"score": stats.score,
		"rank": stats.rank,
		"rank_name": stats.get_rank_name(),
		"missions_flown": stats.missions_flown,
		"kill_count": stats.kill_count,
		"primary_accuracy": stats.primary_accuracy,
		"secondary_accuracy": stats.secondary_accuracy,
		"overall_accuracy": stats.get_total_accuracy(),
		"flight_time_hours": float(stats.flight_time) / 3600.0,
		"campaigns_completed": pilot_profile.campaigns.size(),
		"last_flown": Time.get_datetime_string_from_unix_time(stats.last_flown) if stats.last_flown > 0 else "Never"
	}

## Get achievement summary
func _get_achievement_summary(pilot_profile: PlayerProfile) -> Dictionary:
	if not achievement_manager:
		return {}
	
	return achievement_manager.get_pilot_achievement_summary(pilot_profile)

## Get performance summary
func _get_performance_summary(pilot_profile: PlayerProfile) -> Dictionary:
	if not enable_performance_tracking or not performance_tracker:
		return {}
	
	return performance_tracker.get_detailed_performance_summary(pilot_profile)

## Get recent activity summary
func _get_recent_activity_summary(pilot_profile: PlayerProfile) -> Dictionary:
	var recent_activity: Dictionary = {
		"last_played": Time.get_datetime_string_from_unix_time(pilot_profile.last_played),
		"profile_age_days": (Time.get_unix_time_from_system() - pilot_profile.created_time) / 86400,
		"recent_achievements": [],
		"recent_medals": [],
		"current_campaign": pilot_profile.current_campaign
	}
	
	# Get recent achievements (placeholder - would need achievement timestamps)
	var achievements: Array = pilot_profile.get_meta("achievements", [])
	if achievements.size() > 0:
		recent_activity.recent_achievements = achievements.slice(-3, achievements.size()) # Last 3
	
	# Get recent medals (placeholder - would need medal timestamps)
	var medals: Array = pilot_profile.get_meta("medals", [])
	if medals.size() > 0:
		recent_activity.recent_medals = medals.slice(-3, medals.size()) # Last 3
	
	return recent_activity

## Start mission tracking
func start_mission_tracking() -> void:
	is_mission_active = true
	if statistics_update_timer:
		statistics_update_timer.start()
	
	print("PilotDataCoordinator: Mission tracking started")

## Stop mission tracking
func stop_mission_tracking() -> void:
	is_mission_active = false
	if statistics_update_timer:
		statistics_update_timer.stop()
	
	print("PilotDataCoordinator: Mission tracking stopped")

## Find available save slot
func _find_available_save_slot() -> int:
	# Use SaveGameManager to find available slot
	for i in range(SaveGameManager.max_save_slots):
		var slot_info = SaveGameManager.get_save_slot_info(i)
		if slot_info == null:
			return i
	return -1

## Get list of existing pilot profiles
func get_pilot_list() -> Array[Dictionary]:
	var pilot_list: Array[Dictionary] = []
	var save_slots: Array = SaveGameManager.get_save_slots()
	
	for slot_info in save_slots:
		if slot_info and slot_info.pilot_callsign:
			var pilot_info: Dictionary = {
				"callsign": slot_info.pilot_callsign,
				"save_slot": slot_info.slot_number,
				"last_played": Time.get_datetime_string_from_unix_time(slot_info.last_save_time),
				"missions_completed": slot_info.missions_completed,
				"current_campaign": slot_info.campaign_name,
				"rank": slot_info.pilot_rank,
				"score": slot_info.total_score
			}
			pilot_list.append(pilot_info)
	
	# Sort by last played time (most recent first)
	pilot_list.sort_custom(_sort_pilots_by_last_played)
	
	return pilot_list

## Sort pilots by last played time
func _sort_pilots_by_last_played(a: Dictionary, b: Dictionary) -> bool:
	# This would need actual timestamp comparison
	return a.get("last_played", "") > b.get("last_played", "")

## Delete pilot profile
func delete_pilot_profile(save_slot: int) -> bool:
	print("PilotDataCoordinator: Deleting pilot profile from slot: %d" % save_slot)
	
	# Clear current pilot if it's the one being deleted
	if active_save_slot == save_slot:
		current_pilot_profile = null
		active_save_slot = -1
	
	# Use SaveGameManager to delete slot
	var success: bool = SaveGameManager.delete_save_slot(save_slot)
	
	if success:
		print("PilotDataCoordinator: Pilot profile deleted successfully from slot: %d" % save_slot)
	else:
		push_error("PilotDataCoordinator: Failed to delete pilot profile from slot: %d" % save_slot)
	
	return success

## Export pilot data for backup or sharing
func export_pilot_data(pilot_profile: PlayerProfile = null) -> String:
	var target_profile: PlayerProfile = pilot_profile if pilot_profile else current_pilot_profile
	if not target_profile:
		return ""
	
	# Use existing PlayerProfile export method
	var export_data: String = target_profile.export_to_json()
	
	# Add additional coordinator data
	var coordinator_data: Dictionary = {
		"pilot_export": JSON.parse_string(export_data),
		"achievements": target_profile.get_meta("achievements", []),
		"medals": target_profile.get_meta("medals", []),
		"performance_data": performance_tracker.export_performance_data(target_profile.callsign) if performance_tracker else {},
		"export_timestamp": Time.get_unix_time_from_system(),
		"coordinator_version": "1.0"
	}
	
	return JSON.stringify(coordinator_data, "  ")

## Signal handlers

## Handle achievement earned
func _on_achievement_earned(achievement_id: String, pilot_profile: PlayerProfile) -> void:
	print("PilotDataCoordinator: Achievement earned - %s by %s" % [achievement_id, pilot_profile.callsign])
	# Achievement notification handling could be added here

## Handle medal awarded
func _on_medal_awarded(medal_id: String, pilot_profile: PlayerProfile) -> void:
	print("PilotDataCoordinator: Medal awarded - %s to %s" % [medal_id, pilot_profile.callsign])
	# Medal ceremony handling could be added here

## Handle rank promotion
func _on_rank_promoted(new_rank: int, pilot_profile: PlayerProfile) -> void:
	print("PilotDataCoordinator: Rank promotion - %s promoted to rank %d" % [pilot_profile.callsign, new_rank])
	# Rank promotion ceremony handling could be added here

## Handle performance update
func _on_performance_updated(pilot_profile: PlayerProfile, performance_data: Dictionary) -> void:
	pilot_performance_analyzed.emit(pilot_profile, performance_data)

## Handle milestone reached
func _on_milestone_reached(milestone_type: String, milestone_value: int, pilot_profile: PlayerProfile) -> void:
	print("PilotDataCoordinator: Milestone reached - %s: %d by %s" % [milestone_type, milestone_value, pilot_profile.callsign])

## Handle performance trend change
func _on_performance_trend_changed(trend_type: String, trend_direction: String, pilot_profile: PlayerProfile) -> void:
	print("PilotDataCoordinator: Performance trend changed - %s: %s for %s" % [trend_type, trend_direction, pilot_profile.callsign])

## Handle game state changes
func _on_game_state_changed(old_state: GameStateManager.GameState, new_state: GameStateManager.GameState) -> void:
	match new_state:
		GameStateManager.GameState.MISSION:
			start_mission_tracking()
		GameStateManager.GameState.DEBRIEF, GameStateManager.GameState.MISSION_COMPLETE:
			stop_mission_tracking()

## Handle statistics update timer
func _on_statistics_update_timer_timeout() -> void:
	if is_mission_active and current_pilot_profile:
		# Real-time statistics update during mission would be implemented here
		# This could track ongoing mission performance
		pass

## Get current pilot profile
func get_current_pilot_profile() -> PlayerProfile:
	return current_pilot_profile

## Check if pilot is loaded
func has_current_pilot() -> bool:
	return current_pilot_profile != null

## Get current pilot callsign
func get_current_pilot_callsign() -> String:
	if current_pilot_profile:
		return current_pilot_profile.callsign
	return ""

## Get active save slot
func get_active_save_slot() -> int:
	return active_save_slot

## Enable/disable auto-save
func set_auto_save_enabled(enabled: bool) -> void:
	auto_save_enabled = enabled

## Enable/disable achievement checking
func set_achievement_checking_enabled(enabled: bool) -> void:
	enable_achievement_checking = enabled
	if achievement_manager:
		achievement_manager.set_achievement_checks_enabled(enabled)

## Enable/disable performance tracking
func set_performance_tracking_enabled(enabled: bool) -> void:
	enable_performance_tracking = enabled