class_name PlayerStats
extends Resource
## Comprehensive player scoring and statistics, matching legacy scoring_struct.

# Core scoring
@export var score: int = 0
@export var rank_index: int = 0 # 0=Ensign through 9=Admiral

# Kill statistics
@export var kills: int = 0 # Total valid kills
@export var assists: int = 0

# Weapon accuracy - Primary
@export var p_shots_fired: int = 0
@export var p_shots_hit: int = 0

# Weapon accuracy - Secondary
@export var s_shots_fired: int = 0
@export var s_shots_hit: int = 0

# Friendly fire tracking
@export var bonehead_hits: int = 0
@export var bonehead_kills: int = 0

# Flight statistics
@export var missions_flown: int = 0
@export var total_flight_time: float = 0.0 # In seconds

# Typed collections instead of Dictionary
@export var earned_medals: Array[PlayerMedalEntry] = []
@export var kills_by_ship: Array[ShipKillEntry] = []

# Mission history (per-mission stats storage)
@export var mission_history: Array[MissionStats] = []


## Calculate primary weapon accuracy percentage.
func get_primary_accuracy() -> float:
	if p_shots_fired == 0:
		return 0.0
	return float(p_shots_hit) / float(p_shots_fired) * 100.0


## Calculate secondary weapon accuracy percentage.
func get_secondary_accuracy() -> float:
	if s_shots_fired == 0:
		return 0.0
	return float(s_shots_hit) / float(s_shots_fired) * 100.0


## Calculate overall weapon accuracy.
func get_overall_accuracy() -> float:
	var total_fired := p_shots_fired + s_shots_fired
	if total_fired == 0:
		return 0.0
	var total_hit := p_shots_hit + s_shots_hit
	return float(total_hit) / float(total_fired) * 100.0


## Get formatted flight time as hours:minutes.
func get_flight_time_formatted() -> String:
	var hours := int(total_flight_time / 3600.0)
	var minutes := int(fmod(total_flight_time, 3600.0) / 60.0)
	return "%d:%02d" % [hours, minutes]


## Add kills for a ship class.
func add_ship_kill(ship_class_id: String, count: int = 1) -> void:
	for entry in kills_by_ship:
		if entry.ship_class_id == ship_class_id:
			entry.kill_count += count
			kills += count
			return

	# New ship class
	var new_entry := ShipKillEntry.new()
	new_entry.ship_class_id = ship_class_id
	new_entry.kill_count = count
	kills_by_ship.append(new_entry)
	kills += count


## Award a medal to the player.
func award_medal(medal_resource: Resource) -> void:
	for entry in earned_medals:
		if entry.medal == medal_resource:
			entry.count += 1
			return

	# First time earning this medal
	var new_entry := PlayerMedalEntry.new()
	new_entry.medal = medal_resource
	new_entry.count = 1
	new_entry.date_awarded = Time.get_date_string_from_system()
	earned_medals.append(new_entry)


# ============================================================================
# Mission History Functions
# ============================================================================


## Get stats for a specific mission, or null if not found.
func get_mission_stats(mission_id: String) -> MissionStats:
	for entry in mission_history:
		if entry.mission_id == mission_id:
			return entry
	return null


## Save or update mission stats (overwrites if exists).
func save_mission_stats(stats: MissionStats) -> void:
	for i in range(mission_history.size()):
		if mission_history[i].mission_id == stats.mission_id:
			mission_history[i] = stats
			return
	mission_history.append(stats)


## Commit mission stats to alltime totals (called from debriefing on accept).
func commit_mission_to_alltime(stats: MissionStats) -> void:
	score += stats.score
	kills += stats.kills
	assists += stats.assists
	p_shots_fired += stats.primary_shots_fired
	p_shots_hit += stats.primary_shots_hit
	s_shots_fired += stats.secondary_shots_fired
	s_shots_hit += stats.secondary_shots_hit
	bonehead_hits += stats.bonehead_hits
	bonehead_kills += stats.bonehead_kills
	missions_flown += 1

	# Merge per-ship kills
	for ship_kill in stats.kills_by_ship:
		add_ship_kill(ship_kill.ship_class_id, ship_kill.kill_count)
