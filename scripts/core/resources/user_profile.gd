class_name UserProfile
extends Resource
## Player profile resource containing identity, statistics, and campaign progress.
## Settings (audio, video, controls) are managed by GlobalSettings.gd.

# Rank calculation thresholds (matching legacy scoring.h)
const RANK_THRESHOLDS: Array[int] = [0, 200, 600, 1500, 3000, 6000, 12000, 50000, 100000, 200000]
const RANK_NAMES: Array[String] = [
	"Ensign",
	"Lt. Junior",
	"Lieutenant",
	"Lt. Commander",
	"Commander",
	"Captain",
	"Commodore",
	"Rear Admiral",
	"Vice Admiral",
	"Admiral"
]

# Identity
@export var callsign: String = "Maverick"
@export var short_callsign: String = "Mav" # Truncated for display
@export var pilot_image: Texture2D # Pilot portrait
@export var squad_image: Texture2D # Squadron logo
@export var squad_name: String = "TCS Tiger's Claw"
@export var current_campaign_id: String = ""

# Player statistics (embedded resource)
@export var stats: PlayerStats

# Campaign progress: campaign_id -> { "active_mission": String, "state": String }
@export var campaign_progress: Dictionary = {}

# Profile-specific preferences
@export var active_timeline_year: int = 2654
@export var flags: int = 0


func _init() -> void:
	if stats == null:
		stats = PlayerStats.new()


## Calculate and update rank based on score.
func calculate_rank() -> void:
	if stats == null:
		return
	for i in range(RANK_THRESHOLDS.size() - 1, -1, -1):
		if stats.score >= RANK_THRESHOLDS[i]:
			stats.rank_index = i
			return


## Get the localized rank name.
func get_rank_name() -> String:
	if stats == null:
		return RANK_NAMES[0]
	return RANK_NAMES[clampi(stats.rank_index, 0, RANK_NAMES.size() - 1)]


## Get total kills.
func get_kills() -> int:
	if stats == null:
		return 0
	return stats.kills


## Get score points required for next rank.
func get_points_to_next_rank() -> int:
	if stats == null:
		return RANK_THRESHOLDS[1]
	var next_rank := stats.rank_index + 1
	if next_rank >= RANK_THRESHOLDS.size():
		return 0 # Already max rank
	return RANK_THRESHOLDS[next_rank] - stats.score


## Create a deep copy of this profile.
func duplicate_profile() -> UserProfile:
	var copy := UserProfile.new()
	copy.callsign = callsign
	copy.short_callsign = short_callsign
	copy.pilot_image = pilot_image
	copy.squad_image = squad_image
	copy.squad_name = squad_name
	copy.current_campaign_id = current_campaign_id
	copy.active_timeline_year = active_timeline_year
	copy.flags = flags
	copy.campaign_progress = campaign_progress.duplicate(true)

	# Deep copy stats
	if stats:
		copy.stats = PlayerStats.new()
		copy.stats.score = stats.score
		copy.stats.rank_index = stats.rank_index
		copy.stats.kills = stats.kills
		copy.stats.assists = stats.assists
		copy.stats.p_shots_fired = stats.p_shots_fired
		copy.stats.p_shots_hit = stats.p_shots_hit
		copy.stats.s_shots_fired = stats.s_shots_fired
		copy.stats.s_shots_hit = stats.s_shots_hit
		copy.stats.bonehead_hits = stats.bonehead_hits
		copy.stats.bonehead_kills = stats.bonehead_kills
		copy.stats.missions_flown = stats.missions_flown
		copy.stats.total_flight_time = stats.total_flight_time
		# Copy typed arrays
		for medal_entry in stats.earned_medals:
			var entry_copy := PlayerMedalEntry.new()
			entry_copy.medal = medal_entry.medal
			entry_copy.count = medal_entry.count
			entry_copy.date_awarded = medal_entry.date_awarded
			copy.stats.earned_medals.append(entry_copy)
		for kill_entry in stats.kills_by_ship:
			var entry_copy := ShipKillEntry.new()
			entry_copy.ship_class_id = kill_entry.ship_class_id
			entry_copy.kill_count = kill_entry.kill_count
			copy.stats.kills_by_ship.append(entry_copy)

	return copy
