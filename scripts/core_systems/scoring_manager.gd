# scripts/core_systems/scoring_manager.gd
# Singleton (Autoload) responsible for handling scoring, rank, and medal evaluation.
# Corresponds to scoring.cpp, medals.cpp, rank.cpp, stats.cpp logic.
class_name ScoringManager
extends Node

# --- Dependencies ---
# Needs access to PilotData, RankInfo, MedalInfo, potentially MissionData/AIProfile
# Assuming RankInfo/MedalInfo are loaded into a global GameData singleton or similar.

# --- Constants ---
# Loaded from AIProfile or GameSettings at runtime
var kill_percentage: float = 0.30
var assist_percentage: float = 0.15
var assist_award_percentage: float = 0.35 # Example default

func _ready():
	print("ScoringManager initialized.")
	# TODO: Load scoring parameters (kill_percentage, assist_percentage) from the active AIProfile or GameSettings
	# Example: kill_percentage = GameSettings.get_kill_percentage_scale(GameSettings.skill_level)
	# Example: assist_percentage = GameSettings.get_assist_percentage_scale(GameSettings.skill_level)
	# Example: assist_award_percentage = GameSettings.get_assist_award_percentage_scale(GameSettings.skill_level)


# --- Public Methods ---

# Called when a ship is confirmed destroyed
func evaluate_kill(killed_ship_obj: Node, killer_signature: int, is_multiplayer: bool) -> void:
	if not is_instance_valid(killed_ship_obj) or not killed_ship_obj is ShipBase:
		printerr("ScoringManager: Invalid killed_ship_obj in evaluate_kill.")
		return

	var dead_ship_script = killed_ship_obj as ShipBase
	var dead_ship_data = dead_ship_script.ship_data # Assuming ShipBase has ShipData resource

	if dead_ship_data == null:
		printerr("ScoringManager: Killed ship %s has no ShipData." % killed_ship_obj.name)
		return

	# Check if the killer is a player
	var killer_pilot_data: PilotData = _get_pilot_data_from_signature(killer_signature)
	if killer_pilot_data == null:
		# Killer wasn't a player or couldn't be found
		# Evaluate assists only if killer wasn't a player? (Check C++ logic)
		evaluate_assists(dead_ship_script, killer_signature, is_multiplayer)
		return

	# --- Calculate Kill Score ---
	var kill_score = 0
	var is_bonehead = false
	var killer_team = killer_pilot_data.get_team() # Assuming PilotData has team or we get it from player node
	var killed_team = dead_ship_script.get_team()

	if killer_team == killed_team and not is_multiplayer: # TODO: Add dogfight check for MP
		# Bonehead kill
		is_bonehead = true
		# TODO: Check MISSION_FLAG_NO_TRAITOR
		killer_pilot_data.bonehead_kills += 1 # Add to all-time stats directly for now
		# Apply score penalty based on dead ship's score value
		kill_score = -int(dead_ship_data.score * _get_scoring_scale_factor(is_multiplayer))
		# TODO: Send friendly kill message
	else:
		# Valid kill
		var si_index = dead_ship_data.get_ship_class_index() # Assuming ShipData has this helper
		if si_index != -1:
			killer_pilot_data.add_kill(si_index) # Add to specific kill type stat
		else:
			killer_pilot_data.kill_count += 1 # Add to generic kill count
			killer_pilot_data.kill_count_ok += 1

		# Calculate score based on damage dealt by killer (if enabled)
		var scoring_scale_by_damage = 1.0
		# TODO: Check AIPF_KILL_SCORING_SCALES_WITH_DAMAGE flag
		# if _should_scale_score_by_damage():
		#	 var damage_dealt = dead_ship_script.get_damage_from_attacker(killer_signature) # Needs method on ShipBase
		#	 var total_damage = dead_ship_script.get_total_damage_received() # Needs method on ShipBase
		#	 if total_damage > 0:
		#		 scoring_scale_by_damage = damage_dealt / total_damage

		kill_score = int(dead_ship_data.score * _get_scoring_scale_factor(is_multiplayer) * scoring_scale_by_damage)
		# TODO: Handle multiplayer dogfight scoring separately if needed

		# TODO: Trigger kill popup/message
		# HUDManager.show_kill_popup(...)

	killer_pilot_data.score += kill_score
	# TODO: Update mission-specific stats (m_*) if tracking separately

	print("ScoringManager: Pilot %s scored %d points for killing %s." % [killer_pilot_data.callsign, kill_score, killed_ship_obj.name])

	# Evaluate assists after confirming the kill
	evaluate_assists(dead_ship_script, killer_signature, is_multiplayer)

	# Check for rank promotion and badges based on the kill (or accumulated stats)
	evaluate_rank(killer_pilot_data)
	evaluate_badges(killer_pilot_data)


func evaluate_assists(killed_ship_script: ShipBase, killer_signature: int, is_multiplayer: bool):
	if killed_ship_script == null or not killed_ship_script.has_method("get_damage_data"):
		return

	var damage_data: Dictionary = killed_ship_script.get_damage_data() # Needs method returning {signature: damage}
	var total_damage = killed_ship_script.get_total_damage_received() # Needs method
	var killed_ship_data = killed_ship_script.ship_data

	if total_damage <= 0 or killed_ship_data == null:
		return

	for attacker_sig in damage_data:
		if attacker_sig == killer_signature: # Killer doesn't get an assist
			continue

		var damage_dealt = damage_data[attacker_sig]
		var damage_pct = damage_dealt / total_damage

		# Check if damage meets assist threshold
		var meets_threshold = damage_pct >= assist_percentage
		var scale_by_damage = false # TODO: Check AIPF_ASSIST_SCORING_SCALES_WITH_DAMAGE

		if meets_threshold or scale_by_damage:
			var assist_pilot: PilotData = _get_pilot_data_from_signature(attacker_sig)
			if assist_pilot != null:
				# Check IFF - don't award assist if attacker is hostile to killed ship's team
				var attacker_team = assist_pilot.get_team() # Needs method/property
				var killed_team = killed_ship_script.get_team()
				if Engine.has_singleton("IFFManager") and IFFManager.iff_x_attacks_y(attacker_team, killed_team):
					if meets_threshold:
						assist_pilot.add_assist()

					# Calculate assist score
					var assist_score = 0
					var scoring_scale_factor = _get_scoring_scale_factor(is_multiplayer)
					if scale_by_damage:
						assist_score = int(killed_ship_data.score * scoring_scale_factor * damage_pct)
					elif meets_threshold:
						# TODO: Get assist_score_pct from ship data or default
						var assist_score_pct = 0.5 # Placeholder
						assist_score = int(killed_ship_data.score * assist_score_pct * scoring_scale_factor)

					assist_pilot.score += assist_score
					# TODO: Update mission-specific stats (m_*)
					print("ScoringManager: Pilot %s scored %d points for assist on %s." % [assist_pilot.callsign, assist_score, killed_ship_script.name])

					# Check rank/badges for assist pilot
					evaluate_rank(assist_pilot)
					evaluate_badges(assist_pilot)


func evaluate_rank(pilot_data: PilotData):
	if pilot_data == null: return

	var old_rank = pilot_data.rank
	var new_rank = old_rank
	var current_score = pilot_data.score # Use all-time score

	# TODO: Check PilotFlags.PROMOTED if promotions are handled externally

	# Check if score meets requirements for next ranks
	# Assumes GameData.Ranks is an array of RankInfo sorted by points
	if Engine.has_singleton("GameData"):
		for i in range(old_rank + 1, GlobalConstants.NUM_RANKS):
			if current_score >= GameData.Ranks[i].points_required:
				new_rank = i
			else:
				break # Stop checking once requirement not met

	if new_rank > old_rank:
		pilot_data.rank = new_rank
		# TODO: Store promotion earned for debriefing (m_promotion_earned) if tracking mission stats separately
		print("ScoringManager: Pilot %s promoted to %s!" % [pilot_data.callsign, pilot_data.get_rank_name()])
		# TODO: Trigger promotion message/voice


func evaluate_badges(pilot_data: PilotData):
	if pilot_data == null: return

	var total_kills = pilot_data.kill_count_ok # Use all-time valid kills

	var best_badge_index = -1
	var highest_kills_needed = -1

	# Find the highest badge the player qualifies for based on kills
	# Assumes GameData.Medals is an array of MedalInfo
	if Engine.has_singleton("GameData"):
		for i in range(GameData.Medals.size()):
			var medal_info: MedalInfo = GameData.Medals[i]
			if medal_info.kills_needed > 0: # It's a badge
				if total_kills >= medal_info.kills_needed:
					if medal_info.kills_needed > highest_kills_needed:
						highest_kills_needed = medal_info.kills_needed
						best_badge_index = i

	if best_badge_index != -1:
		# Check if this specific badge hasn't been awarded yet
		if pilot_data.medals[best_badge_index] <= 0:
			pilot_data.medals[best_badge_index] = 1 # Award the badge
			# TODO: Store badge earned for debriefing (m_badge_earned)
			print("ScoringManager: Pilot %s earned badge: %s!" % [pilot_data.callsign, GameData.Medals[best_badge_index].medal_name])
			# TODO: Trigger badge message/voice


func evaluate_medal(pilot_data: PilotData, medal_index: int):
	# Award a specific medal (usually triggered by mission events/goals)
	if pilot_data == null or medal_index < 0 or medal_index >= GlobalConstants.MAX_MEDALS:
		return

	pilot_data.medals[medal_index] += 1
	# TODO: Store medal earned for debriefing (m_medal_earned)
	if Engine.has_singleton("GameData"):
		print("ScoringManager: Pilot %s awarded medal: %s!" % [pilot_data.callsign, GameData.Medals[medal_index].medal_name])
	# TODO: Trigger medal message/voice


func add_mission_score(pilot_data: PilotData, points: int):
	if pilot_data != null:
		pilot_data.score += points
		# TODO: Update mission-specific score (m_score)
		evaluate_rank(pilot_data) # Check if score change triggers promotion


# --- Internal Helpers ---

func _get_pilot_data_from_signature(signature: int) -> PilotData:
	# Helper to find the PilotData associated with a given object signature
	if signature == -1: return null

	# Check if it's the local player first
	if Engine.has_singleton("GameState") and GameState.active_pilot != null:
		# Need a way to get the player's current ship signature
		var player_ship = GameState.get_player_ship() # Assuming method exists
		if is_instance_valid(player_ship) and player_ship.get_signature() == signature:
			return GameState.active_pilot

	# Check multiplayer players
	if Engine.has_singleton("MultiplayerManager"): # Assuming MP manager singleton
		var net_player = MultiplayerManager.find_player_by_signature(signature) # Assuming method exists
		if net_player != null and net_player.m_player != null:
			return net_player.m_player # Assuming m_player holds PilotData

	# If not found among players, return null
	return null


func _get_scoring_scale_factor(is_multiplayer: bool) -> float:
	# Helper to get the score scaling based on skill level (single player only)
	if is_multiplayer:
		return 1.0
	else:
		# Assuming GameSettings singleton holds skill level
		var skill = 0
		if Engine.has_singleton("GameSettings"):
			skill = GameSettings.skill_level
		# TODO: Load Scoring_scale_factors from a resource or define here
		var scale_factors = [0.2, 0.4, 0.7, 1.0, 1.25] # From scoring.cpp
		return scale_factors[clamp(skill, 0, scale_factors.size() - 1)]

# func _should_scale_score_by_damage() -> bool:
#	 # Helper to check AIPF_KILL_SCORING_SCALES_WITH_DAMAGE / AIPF_ASSIST_SCORING_SCALES_WITH_DAMAGE
#	 # Needs access to the mission's AIProfile
#	 return false # Placeholder
