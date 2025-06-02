class_name AchievementManager
extends Node

## Achievement and medal system for pilot progression tracking
## Integrates with existing PlayerProfile and PilotStatistics resources
## Provides comprehensive achievement tracking and award ceremonies

# Achievement tracking signals
signal achievement_earned(achievement_id: String, pilot_profile: PlayerProfile)
signal medal_awarded(medal_id: String, pilot_profile: PlayerProfile)
signal rank_promoted(new_rank: int, pilot_profile: PlayerProfile)
signal achievement_progress_updated(achievement_id: String, progress: float, pilot_profile: PlayerProfile)

# Achievement definitions
enum AchievementType {
	COMBAT,          # Combat-related achievements (kills, accuracy)
	MISSION,         # Mission completion achievements
	CAMPAIGN,        # Campaign progression achievements  
	SPECIAL,         # Special accomplishments
	SURVIVAL,        # Survival and defensive achievements
	TEAMWORK         # Wingman and squadron achievements
}

# Medal definitions
enum MedalType {
	DISTINGUISHED_FLYING_CROSS,    # Exceptional mission performance
	NEBULA_CAMPAIGN_VICTORY,       # Campaign completion medals
	VASUDAN_ALLIANCE_MEDAL,        # Cross-species cooperation
	GALACTIC_TERRAN_ALLIANCE,      # GTA service medals
	SPECIAL_OPERATIONS,            # Special mission accomplishments
	COMBAT_EXCELLENCE,             # Combat prowess medals
	FLIGHT_SAFETY,                 # Safety and survival awards
	MERITORIOUS_SERVICE           # General service recognition
}

# Configuration
@export var enable_achievement_notifications: bool = true
@export var enable_progressive_achievements: bool = true
@export var notification_display_time: float = 5.0

# Achievement definitions database
var achievement_definitions: Dictionary = {}
var medal_definitions: Dictionary = {}

# State tracking
var achievement_checks_enabled: bool = true
var notification_queue: Array[Dictionary] = []
var is_processing_notifications: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_achievement_system()

## Initialize achievement and medal system
func _initialize_achievement_system() -> void:
	print("AchievementManager: Initializing achievement system...")
	
	# Initialize achievement definitions
	_setup_achievement_definitions()
	_setup_medal_definitions()
	
	print("AchievementManager: Achievement system initialized with %d achievements and %d medals" % [achievement_definitions.size(), medal_definitions.size()])

## Setup achievement definitions with criteria and progression
func _setup_achievement_definitions() -> void:
	achievement_definitions = {
		# Combat Achievements
		"first_kill": {
			"type": AchievementType.COMBAT,
			"name": "First Blood",
			"description": "Destroy your first enemy ship",
			"criteria": {"kills": 1},
			"icon": "achievement_first_kill",
			"points": 50
		},
		
		"ace_pilot": {
			"type": AchievementType.COMBAT,
			"name": "Ace Pilot", 
			"description": "Destroy 5 enemy ships in a single mission",
			"criteria": {"mission_kills": 5},
			"icon": "achievement_ace",
			"points": 200
		},
		
		"centurion": {
			"type": AchievementType.COMBAT,
			"name": "Centurion",
			"description": "Destroy 100 enemy ships across all missions",
			"criteria": {"total_kills": 100},
			"icon": "achievement_centurion",
			"points": 500
		},
		
		"marksman": {
			"type": AchievementType.COMBAT,
			"name": "Marksman",
			"description": "Achieve 85% or higher weapon accuracy",
			"criteria": {"accuracy": 85.0},
			"icon": "achievement_marksman",
			"points": 300
		},
		
		# Mission Achievements
		"rookie_graduate": {
			"type": AchievementType.MISSION,
			"name": "Rookie Graduate",
			"description": "Complete your first mission",
			"criteria": {"missions_completed": 1},
			"icon": "achievement_rookie",
			"points": 25
		},
		
		"veteran_pilot": {
			"type": AchievementType.MISSION,
			"name": "Veteran Pilot",
			"description": "Complete 50 missions",
			"criteria": {"missions_completed": 50},
			"icon": "achievement_veteran",
			"points": 400
		},
		
		"perfect_mission": {
			"type": AchievementType.MISSION,
			"name": "Perfect Mission",
			"description": "Complete a mission with 100% objectives and no damage taken",
			"criteria": {"mission_perfect": true},
			"icon": "achievement_perfect",
			"points": 250
		},
		
		# Campaign Achievements
		"campaign_hero": {
			"type": AchievementType.CAMPAIGN,
			"name": "Campaign Hero",
			"description": "Complete your first campaign",
			"criteria": {"campaigns_completed": 1},
			"icon": "achievement_campaign",
			"points": 300
		},
		
		"saga_legend": {
			"type": AchievementType.CAMPAIGN,
			"name": "Saga Legend",
			"description": "Complete all available campaigns",
			"criteria": {"all_campaigns_completed": true},
			"icon": "achievement_legend",
			"points": 1000
		},
		
		# Survival Achievements
		"survivor": {
			"type": AchievementType.SURVIVAL,
			"name": "Survivor",
			"description": "Maintain 95% or higher mission survival rate",
			"criteria": {"survival_rate": 95.0},
			"icon": "achievement_survivor",
			"points": 350
		},
		
		"iron_man": {
			"type": AchievementType.SURVIVAL,
			"name": "Iron Man",
			"description": "Complete 10 consecutive missions without being destroyed",
			"criteria": {"consecutive_survivals": 10},
			"icon": "achievement_iron_man",
			"points": 400
		},
		
		# Special Achievements  
		"speed_demon": {
			"type": AchievementType.SPECIAL,
			"name": "Speed Demon",
			"description": "Complete a mission in record time",
			"criteria": {"mission_time_record": true},
			"icon": "achievement_speed",
			"points": 200
		},
		
		"fleet_defender": {
			"type": AchievementType.TEAMWORK,
			"name": "Fleet Defender",
			"description": "Protect allied ships from destruction for an entire mission",
			"criteria": {"allies_saved": true},
			"icon": "achievement_defender",
			"points": 250
		}
	}

## Setup medal definitions with award criteria
func _setup_medal_definitions() -> void:
	medal_definitions = {
		"distinguished_flying_cross": {
			"type": MedalType.DISTINGUISHED_FLYING_CROSS,
			"name": "Distinguished Flying Cross",
			"description": "Awarded for exceptional aerial achievement",
			"criteria": {"total_score": 25000, "missions_completed": 25},
			"icon": "medal_dfc",
			"prestige": 8
		},
		
		"vasudan_alliance_medal": {
			"type": MedalType.VASUDAN_ALLIANCE_MEDAL,
			"name": "Vasudan Alliance Medal",
			"description": "Awarded for service in joint Terran-Vasudan operations",
			"criteria": {"joint_missions": 10},
			"icon": "medal_vasudan",
			"prestige": 6
		},
		
		"combat_excellence_medal": {
			"type": MedalType.COMBAT_EXCELLENCE,
			"name": "Medal of Combat Excellence",
			"description": "Awarded for superior combat performance",
			"criteria": {"total_kills": 75, "accuracy": 80.0},
			"icon": "medal_combat",
			"prestige": 7
		},
		
		"nebula_campaign_victory": {
			"type": MedalType.NEBULA_CAMPAIGN_VICTORY,
			"name": "Nebula Campaign Victory Medal",
			"description": "Awarded for completing the Nebula Campaign",
			"criteria": {"specific_campaign": "Silent_Threat"},
			"icon": "medal_nebula",
			"prestige": 9
		},
		
		"flight_safety_award": {
			"type": MedalType.FLIGHT_SAFETY,
			"name": "Flight Safety Award",
			"description": "Awarded for maintaining exceptional safety record",
			"criteria": {"survival_rate": 98.0, "missions_completed": 30},
			"icon": "medal_safety",
			"prestige": 5
		},
		
		"meritorious_service_medal": {
			"type": MedalType.MERITORIOUS_SERVICE,
			"name": "Meritorious Service Medal",
			"description": "Awarded for outstanding dedication to duty",
			"criteria": {"flight_time": 36000, "campaigns_completed": 2}, # 10 hours
			"icon": "medal_service",
			"prestige": 6
		}
	}

## Check pilot achievements using existing PilotStatistics data
func check_pilot_achievements(pilot_profile: PlayerProfile) -> Array[String]:
	if not pilot_profile or not pilot_profile.pilot_stats or not achievement_checks_enabled:
		return []
	
	var new_achievements: Array[String] = []
	var stats: PilotStatistics = pilot_profile.pilot_stats
	var existing_achievements: Array = pilot_profile.get_meta("achievements", [])
	
	# Check each achievement definition
	for achievement_id: String in achievement_definitions:
		if achievement_id in existing_achievements:
			continue # Already earned
		
		var achievement: Dictionary = achievement_definitions[achievement_id]
		if _check_achievement_criteria(achievement, stats, pilot_profile):
			new_achievements.append(achievement_id)
			existing_achievements.append(achievement_id)
			
			# Update pilot profile
			pilot_profile.set_meta("achievements", existing_achievements)
			
			# Emit achievement earned signal
			achievement_earned.emit(achievement_id, pilot_profile)
			
			# Queue notification
			if enable_achievement_notifications:
				_queue_achievement_notification(achievement_id, achievement)
			
			print("AchievementManager: Achievement earned - %s: %s" % [achievement_id, achievement.name])
	
	return new_achievements

## Check pilot medals based on comprehensive performance
func check_pilot_medals(pilot_profile: PlayerProfile) -> Array[String]:
	if not pilot_profile or not pilot_profile.pilot_stats or not achievement_checks_enabled:
		return []
	
	var new_medals: Array[String] = []
	var stats: PilotStatistics = pilot_profile.pilot_stats
	var existing_medals: Array = pilot_profile.get_meta("medals", [])
	
	# Check each medal definition
	for medal_id: String in medal_definitions:
		if medal_id in existing_medals:
			continue # Already awarded
		
		var medal: Dictionary = medal_definitions[medal_id]
		if _check_medal_criteria(medal, stats, pilot_profile):
			new_medals.append(medal_id)
			existing_medals.append(medal_id)
			
			# Update pilot profile
			pilot_profile.set_meta("medals", existing_medals)
			
			# Emit medal awarded signal
			medal_awarded.emit(medal_id, pilot_profile)
			
			# Queue notification
			if enable_achievement_notifications:
				_queue_medal_notification(medal_id, medal)
			
			print("AchievementManager: Medal awarded - %s: %s" % [medal_id, medal.name])
	
	return new_medals

## Check achievement criteria against pilot statistics
func _check_achievement_criteria(achievement: Dictionary, stats: PilotStatistics, pilot_profile: PlayerProfile) -> bool:
	var criteria: Dictionary = achievement.criteria
	
	# Check kill-based criteria
	if criteria.has("kills") and stats.kill_count < criteria.kills:
		return false
	
	if criteria.has("total_kills") and stats.kill_count < criteria.total_kills:
		return false
	
	# Check accuracy criteria
	if criteria.has("accuracy"):
		var accuracy: float = 0.0
		if stats.primary_shots_fired > 0:
			accuracy = (float(stats.primary_shots_hit) / float(stats.primary_shots_fired)) * 100.0
		if accuracy < criteria.accuracy:
			return false
	
	# Check mission criteria
	if criteria.has("missions_completed") and stats.missions_flown < criteria.missions_completed:
		return false
	
	# Check survival rate criteria
	if criteria.has("survival_rate"):
		var survival_rate: float = 100.0
		if stats.missions_flown > 0:
			# Estimate survival rate (would need death tracking in extended stats)
			survival_rate = 95.0 # Placeholder calculation
		if survival_rate < criteria.survival_rate:
			return false
	
	# Check campaign criteria
	if criteria.has("campaigns_completed"):
		var completed_campaigns: int = pilot_profile.campaigns.size()
		if completed_campaigns < criteria.campaigns_completed:
			return false
	
	# Check special criteria (would need additional tracking)
	if criteria.has("mission_kills"):
		# This would require mission-specific tracking
		return false # Placeholder - needs mission-level statistics
	
	if criteria.has("mission_perfect"):
		# This would require perfect mission tracking
		return false # Placeholder - needs mission performance data
	
	if criteria.has("all_campaigns_completed"):
		# This would require checking against available campaigns
		return false # Placeholder - needs campaign registry
	
	if criteria.has("consecutive_survivals"):
		# This would require consecutive mission tracking
		return false # Placeholder - needs consecutive tracking
	
	if criteria.has("mission_time_record"):
		# This would require time tracking and records
		return false # Placeholder - needs time records
	
	if criteria.has("allies_saved"):
		# This would require allied protection tracking
		return false # Placeholder - needs ally tracking
	
	return true

## Check medal criteria against pilot statistics
func _check_medal_criteria(medal: Dictionary, stats: PilotStatistics, pilot_profile: PlayerProfile) -> bool:
	var criteria: Dictionary = medal.criteria
	
	# Check total score criteria
	if criteria.has("total_score") and stats.score < criteria.total_score:
		return false
	
	# Check missions completed criteria
	if criteria.has("missions_completed") and stats.missions_flown < criteria.missions_completed:
		return false
	
	# Check kill and accuracy criteria
	if criteria.has("total_kills") and stats.kill_count < criteria.total_kills:
		return false
	
	if criteria.has("accuracy"):
		var accuracy: float = 0.0
		if stats.primary_shots_fired > 0:
			accuracy = (float(stats.primary_shots_hit) / float(stats.primary_shots_fired)) * 100.0
		if accuracy < criteria.accuracy:
			return false
	
	# Check survival rate criteria
	if criteria.has("survival_rate"):
		var survival_rate: float = 100.0
		if stats.missions_flown > 0:
			# Estimate survival rate (would need death tracking)
			survival_rate = 95.0 # Placeholder calculation
		if survival_rate < criteria.survival_rate:
			return false
	
	# Check flight time criteria (in seconds)
	if criteria.has("flight_time") and stats.flight_time < criteria.flight_time:
		return false
	
	# Check campaign criteria
	if criteria.has("campaigns_completed"):
		var completed_campaigns: int = pilot_profile.campaigns.size()
		if completed_campaigns < criteria.campaigns_completed:
			return false
	
	# Check specific campaign criteria
	if criteria.has("specific_campaign"):
		var campaign_name: String = criteria.specific_campaign
		var campaign_found: bool = false
		for campaign_info in pilot_profile.campaigns:
			if campaign_info.campaign_filename.contains(campaign_name):
				campaign_found = true
				break
		if not campaign_found:
			return false
	
	# Check joint mission criteria (placeholder)
	if criteria.has("joint_missions"):
		# This would require tracking of joint Terran-Vasudan missions
		return false # Placeholder - needs mission type tracking
	
	return true

## Queue achievement notification
func _queue_achievement_notification(achievement_id: String, achievement: Dictionary) -> void:
	var notification: Dictionary = {
		"type": "achievement",
		"id": achievement_id,
		"name": achievement.name,
		"description": achievement.description,
		"icon": achievement.get("icon", ""),
		"points": achievement.get("points", 0)
	}
	
	notification_queue.append(notification)
	_process_notification_queue()

## Queue medal notification
func _queue_medal_notification(medal_id: String, medal: Dictionary) -> void:
	var notification: Dictionary = {
		"type": "medal",
		"id": medal_id,
		"name": medal.name,
		"description": medal.description,
		"icon": medal.get("icon", ""),
		"prestige": medal.get("prestige", 0)
	}
	
	notification_queue.append(notification)
	_process_notification_queue()

## Process notification queue
func _process_notification_queue() -> void:
	if is_processing_notifications or notification_queue.is_empty():
		return
	
	is_processing_notifications = true
	var notification: Dictionary = notification_queue.pop_front()
	
	# Display notification (would integrate with UI system)
	print("AchievementManager: Notification - %s: %s" % [notification.name, notification.description])
	
	# Wait for display time
	await get_tree().create_timer(notification_display_time).timeout
	
	is_processing_notifications = false
	
	# Process next notification if available
	if not notification_queue.is_empty():
		_process_notification_queue()

## Check rank progression based on score and experience
func check_rank_progression(pilot_profile: PlayerProfile) -> bool:
	if not pilot_profile or not pilot_profile.pilot_stats:
		return false
	
	var stats: PilotStatistics = pilot_profile.pilot_stats
	var current_rank: int = stats.rank
	var new_rank: int = _calculate_rank_from_performance(stats)
	
	if new_rank > current_rank:
		stats.rank = new_rank
		pilot_profile.mark_as_played() # Update modification time
		rank_promoted.emit(new_rank, pilot_profile)
		print("AchievementManager: Rank promotion - Rank %d achieved" % new_rank)
		return true
	
	return false

## Calculate rank based on performance metrics
func _calculate_rank_from_performance(stats: PilotStatistics) -> int:
	# Simplified rank calculation based on multiple factors
	var rank_score: float = 0.0
	
	# Base score contribution
	rank_score += stats.score * 0.001
	
	# Mission completion contribution
	rank_score += stats.missions_flown * 10.0
	
	# Combat effectiveness contribution
	if stats.missions_flown > 0:
		var kill_ratio: float = float(stats.kill_count) / float(stats.missions_flown)
		rank_score += kill_ratio * 50.0
	
	# Accuracy contribution
	if stats.primary_shots_fired > 0:
		var accuracy: float = (float(stats.primary_shots_hit) / float(stats.primary_shots_fired)) * 100.0
		rank_score += accuracy * 2.0
	
	# Convert to rank (0-10 scale)
	var new_rank: int = int(rank_score / 1000.0)
	return min(new_rank, 10) # Cap at maximum rank

## Get achievement progress for progressive achievements
func get_achievement_progress(achievement_id: String, pilot_profile: PlayerProfile) -> float:
	if not enable_progressive_achievements or not pilot_profile or not pilot_profile.pilot_stats:
		return 0.0
	
	if not achievement_definitions.has(achievement_id):
		return 0.0
	
	var achievement: Dictionary = achievement_definitions[achievement_id]
	var criteria: Dictionary = achievement.criteria
	var stats: PilotStatistics = pilot_profile.pilot_stats
	
	# Calculate progress based on criteria type
	if criteria.has("total_kills"):
		return min(float(stats.kill_count) / float(criteria.total_kills), 1.0)
	
	if criteria.has("missions_completed"):
		return min(float(stats.missions_flown) / float(criteria.missions_completed), 1.0)
	
	if criteria.has("total_score"):
		return min(float(stats.score) / float(criteria.total_score), 1.0)
	
	if criteria.has("accuracy"):
		var accuracy: float = 0.0
		if stats.primary_shots_fired > 0:
			accuracy = (float(stats.primary_shots_hit) / float(stats.primary_shots_fired)) * 100.0
		return min(accuracy / criteria.accuracy, 1.0)
	
	return 0.0

## Get pilot achievement summary
func get_pilot_achievement_summary(pilot_profile: PlayerProfile) -> Dictionary:
	if not pilot_profile:
		return {}
	
	var achievements: Array = pilot_profile.get_meta("achievements", [])
	var medals: Array = pilot_profile.get_meta("medals", [])
	
	var achievement_points: int = 0
	for achievement_id in achievements:
		if achievement_definitions.has(achievement_id):
			achievement_points += achievement_definitions[achievement_id].get("points", 0)
	
	var medal_prestige: int = 0
	for medal_id in medals:
		if medal_definitions.has(medal_id):
			medal_prestige += medal_definitions[medal_id].get("prestige", 0)
	
	return {
		"achievements_earned": achievements.size(),
		"total_achievements": achievement_definitions.size(),
		"achievement_completion": float(achievements.size()) / float(achievement_definitions.size()),
		"achievement_points": achievement_points,
		"medals_earned": medals.size(),
		"total_medals": medal_definitions.size(),
		"medal_completion": float(medals.size()) / float(medal_definitions.size()),
		"medal_prestige": medal_prestige,
		"overall_completion": (float(achievements.size() + medals.size()) / float(achievement_definitions.size() + medal_definitions.size()))
	}

## Enable/disable achievement checking
func set_achievement_checks_enabled(enabled: bool) -> void:
	achievement_checks_enabled = enabled

## Get achievement definition
func get_achievement_definition(achievement_id: String) -> Dictionary:
	return achievement_definitions.get(achievement_id, {})

## Get medal definition
func get_medal_definition(medal_id: String) -> Dictionary:
	return medal_definitions.get(medal_id, {})

## Get all achievement definitions
func get_all_achievement_definitions() -> Dictionary:
	return achievement_definitions.duplicate()

## Get all medal definitions
func get_all_medal_definitions() -> Dictionary:
	return medal_definitions.duplicate()