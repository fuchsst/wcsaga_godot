class_name PilotStatistics
extends Resource

## Comprehensive pilot statistics resource.
## Consolidates scoring_struct and player statistics from WCS.

# --- Combat Statistics ---
@export_group("Combat Statistics")
@export var score: int = 0                     ## Overall mission score
@export var rank: int = 0                      ## Current rank index
@export var medals: Array[int] = []            ## Medal counts (indexed by medal type)
@export var kills: Array[int] = []             ## Kill counts per ship class
@export var assists: int = 0                   ## Total assists
@export var kill_count: int = 0                ## Total confirmed kills
@export var kill_count_ok: int = 0             ## Valid kills for stats/badges

# --- Weapon Statistics ---
@export_group("Weapon Statistics") 
@export var primary_shots_fired: int = 0       ## Primary weapon shots fired
@export var secondary_shots_fired: int = 0     ## Secondary weapon shots fired
@export var primary_shots_hit: int = 0         ## Primary weapon hits
@export var secondary_shots_hit: int = 0       ## Secondary weapon hits
@export var primary_friendly_hits: int = 0     ## Primary friendly fire hits
@export var secondary_friendly_hits: int = 0   ## Secondary friendly fire hits
@export var friendly_kills: int = 0            ## Friendly fire kills

# --- Mission Statistics ---
@export_group("Mission Statistics")
@export var missions_flown: int = 0             ## Total missions completed
@export var flight_time: int = 0               ## Total flight time in seconds
@export var last_flown: int = 0                ## Unix timestamp of last mission
@export var last_backup: int = 0               ## Unix timestamp of previous mission

# --- Performance Metrics ---
@export_group("Performance Metrics")
@export var primary_accuracy: float = 0.0      ## Primary weapon accuracy percentage
@export var secondary_accuracy: float = 0.0    ## Secondary weapon accuracy percentage
@export var missions_per_kill: float = 0.0     ## Average missions per kill
@export var score_per_mission: float = 0.0     ## Average score per mission

# --- Multiplayer Statistics ---
@export_group("Multiplayer Statistics")
@export var mp_kills_total: int = 0             ## Total MP kills
@export var mp_assists_total: int = 0           ## Total MP assists  
@export var mp_deaths_total: int = 0            ## Total MP deaths
@export var mp_missions_flown: int = 0          ## Total MP missions

func _init() -> void:
	# Initialize arrays with proper sizes
	medals.resize(GlobalConstants.MAX_MEDALS)
	medals.fill(0)
	kills.resize(GlobalConstants.MAX_SHIP_CLASSES)
	kills.fill(0)
	_update_calculated_stats()

## Update calculated statistics
func _update_calculated_stats() -> void:
	# Calculate accuracy percentages
	if primary_shots_fired > 0:
		primary_accuracy = (float(primary_shots_hit) / float(primary_shots_fired)) * 100.0
	else:
		primary_accuracy = 0.0
		
	if secondary_shots_fired > 0:
		secondary_accuracy = (float(secondary_shots_hit) / float(secondary_shots_fired)) * 100.0
	else:
		secondary_accuracy = 0.0
	
	# Calculate performance metrics
	if missions_flown > 0:
		score_per_mission = float(score) / float(missions_flown)
		if kill_count > 0:
			missions_per_kill = float(missions_flown) / float(kill_count)
		else:
			missions_per_kill = float(missions_flown)
	else:
		score_per_mission = 0.0
		missions_per_kill = 0.0

## Add a kill for specific ship class
func add_kill(ship_class_index: int, valid_for_stats: bool = true) -> void:
	if ship_class_index >= 0 and ship_class_index < kills.size():
		kills[ship_class_index] += 1
		kill_count += 1
		if valid_for_stats:
			kill_count_ok += 1
		_update_calculated_stats()

## Add an assist
func add_assist() -> void:
	assists += 1
	_update_calculated_stats()

## Add medal count
func add_medal(medal_index: int, count: int = 1) -> void:
	if medal_index >= 0 and medal_index < medals.size():
		medals[medal_index] += count

## Record weapon fire
func record_weapon_fire(is_primary: bool, shots: int, hits: int, friendly_hits: int = 0) -> void:
	if is_primary:
		primary_shots_fired += shots
		primary_shots_hit += hits
		primary_friendly_hits += friendly_hits
	else:
		secondary_shots_fired += shots
		secondary_shots_hit += hits
		secondary_friendly_hits += friendly_hits
	_update_calculated_stats()

## Complete a mission
func complete_mission(mission_score: int, flight_duration: int) -> void:
	missions_flown += 1
	score += mission_score
	flight_time += flight_duration
	last_backup = last_flown
	last_flown = Time.get_unix_time_from_system()
	_update_calculated_stats()

## Get total accuracy (combined primary and secondary)
func get_total_accuracy() -> float:
	var total_shots: int = primary_shots_fired + secondary_shots_fired
	var total_hits: int = primary_shots_hit + secondary_shots_hit
	
	if total_shots > 0:
		return (float(total_hits) / float(total_shots)) * 100.0
	return 0.0

## Get kill/death ratio for multiplayer
func get_mp_kd_ratio() -> float:
	if mp_deaths_total > 0:
		return float(mp_kills_total) / float(mp_deaths_total)
	return float(mp_kills_total)

## Get rank name (requires GlobalConstants access)
func get_rank_name() -> String:
	if GlobalConstants and rank >= 0:
		# Assume rank lookup method exists in GlobalConstants
		return "Rank " + str(rank)  # Placeholder - implement proper rank lookup
	return "Unknown"

## Reset statistics (for new pilot or campaign)
func reset_stats() -> void:
	score = 0
	assists = 0
	kill_count = 0
	kill_count_ok = 0
	primary_shots_fired = 0
	secondary_shots_fired = 0
	primary_shots_hit = 0
	secondary_shots_hit = 0
	primary_friendly_hits = 0
	secondary_friendly_hits = 0
	friendly_kills = 0
	missions_flown = 0
	flight_time = 0
	medals.fill(0)
	kills.fill(0)
	mp_kills_total = 0
	mp_assists_total = 0
	mp_deaths_total = 0
	mp_missions_flown = 0
	_update_calculated_stats()