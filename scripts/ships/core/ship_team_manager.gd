class_name ShipTeamManager
extends RefCounted

## Ship team and IFF management system implementing WCS faction relationships and combat targeting
## Handles team assignment, faction relationships, and combat targeting rules (SHIP-004)

# EPIC-002 Asset Core Integration
const TeamTypes = preload("res://addons/wcs_asset_core/constants/team_types.gd")

# Team management signals
signal team_changed(ship: BaseShip, old_team: int, new_team: int)
signal faction_relationship_changed(faction1: String, faction2: String, new_relationship: int)
signal iff_code_changed(ship: BaseShip, old_iff: String, new_iff: String)
signal observed_team_changed(ship: BaseShip, observed_team: int)

# Ship team data
class ShipTeamData:
	var ship: BaseShip
	var team: int = TeamTypes.Team.FRIENDLY
	var observed_team: int = TeamTypes.Team.FRIENDLY  # What others observe
	var faction_name: String = ""
	var iff_code: String = ""
	var original_team: int = TeamTypes.Team.FRIENDLY  # For restoration
	var team_change_count: int = 0
	var last_team_change_time: float = 0.0
	
	func _init(target_ship: BaseShip) -> void:
		ship = target_ship
		team = target_ship.team if target_ship else TeamTypes.Team.FRIENDLY
		observed_team = team
		original_team = team

# Faction relationship system
class FactionRelationship:
	var faction1: String
	var faction2: String
	var relationship: int = TeamTypes.Relationship.NEUTRAL
	var is_permanent: bool = false  # Cannot be changed during mission
	var change_time: float = 0.0
	
	func _init(f1: String, f2: String, rel: int = TeamTypes.Relationship.NEUTRAL) -> void:
		faction1 = f1
		faction2 = f2
		relationship = rel
		change_time = Time.get_ticks_msec() * 0.001

# Team manager state
var ship_teams: Dictionary = {}  # BaseShip -> ShipTeamData
var faction_relationships: Dictionary = {}  # String -> Dictionary[String, FactionRelationship]
var team_compositions: Dictionary = {}  # int -> Array[BaseShip]
var iff_registry: Dictionary = {}  # String -> Array[BaseShip]

# Global faction definitions
var faction_definitions: Dictionary = {}  # String -> FactionData
var default_team_relationships: Array[Array] = []

# Combat targeting rules
var targeting_rules: Dictionary = {}
var ignore_list: Dictionary = {}  # Ship -> Array[Ship] (ships to ignore)

# Mission-specific team data
var mission_team_overrides: Dictionary = {}
var red_alert_team_preservation: Dictionary = {}

func _init() -> void:
	"""Initialize team management system."""
	_initialize_default_factions()
	_initialize_default_relationships()
	_initialize_targeting_rules()

## Initialize default faction definitions (SHIP-004 AC5)
func _initialize_default_factions() -> void:
	"""Initialize default WCS faction definitions."""
	faction_definitions = {
		"Terran": {
			"display_name": "Galactic Terran Alliance",
			"default_team": TeamTypes.Team.FRIENDLY,
			"player_faction": true,
			"color": Color.BLUE,
			"description": "Human faction"
		},
		"Vasudan": {
			"display_name": "Parliamentary Vasudan Republic",
			"default_team": TeamTypes.Team.FRIENDLY,
			"player_faction": false,
			"color": Color.GREEN,
			"description": "Allied alien faction"
		},
		"Shivan": {
			"display_name": "Shivan Empire",
			"default_team": TeamTypes.Team.HOSTILE,
			"player_faction": false,
			"color": Color.RED,
			"description": "Hostile alien faction"
		},
		"Pirate": {
			"display_name": "Space Pirates",
			"default_team": TeamTypes.Team.HOSTILE,
			"player_faction": false,
			"color": Color.ORANGE,
			"description": "Hostile human faction"
		},
		"Unknown": {
			"display_name": "Unknown Faction",
			"default_team": TeamTypes.Team.UNKNOWN,
			"player_faction": false,
			"color": Color.GRAY,
			"description": "Unidentified forces"
		}
	}

## Initialize default faction relationships (SHIP-004 AC5)
func _initialize_default_relationships() -> void:
	"""Initialize default WCS faction relationships."""
	# Set up default relationship matrix
	default_team_relationships = [
		# FRIENDLY, HOSTILE, NEUTRAL, UNKNOWN
		[TeamTypes.Relationship.FRIENDLY, TeamTypes.Relationship.HOSTILE, TeamTypes.Relationship.NEUTRAL, TeamTypes.Relationship.HOSTILE],  # FRIENDLY
		[TeamTypes.Relationship.HOSTILE, TeamTypes.Relationship.FRIENDLY, TeamTypes.Relationship.HOSTILE, TeamTypes.Relationship.HOSTILE],  # HOSTILE
		[TeamTypes.Relationship.NEUTRAL, TeamTypes.Relationship.HOSTILE, TeamTypes.Relationship.NEUTRAL, TeamTypes.Relationship.NEUTRAL],   # NEUTRAL
		[TeamTypes.Relationship.HOSTILE, TeamTypes.Relationship.HOSTILE, TeamTypes.Relationship.NEUTRAL, TeamTypes.Relationship.NEUTRAL]    # UNKNOWN
	]
	
	# Initialize faction-specific relationships
	_set_faction_relationship("Terran", "Vasudan", TeamTypes.Relationship.FRIENDLY, true)
	_set_faction_relationship("Terran", "Shivan", TeamTypes.Relationship.HOSTILE, true)
	_set_faction_relationship("Vasudan", "Shivan", TeamTypes.Relationship.HOSTILE, true)
	_set_faction_relationship("Terran", "Pirate", TeamTypes.Relationship.HOSTILE, false)
	_set_faction_relationship("Vasudan", "Pirate", TeamTypes.Relationship.HOSTILE, false)

## Initialize targeting rules for combat (SHIP-004 AC5)
func _initialize_targeting_rules() -> void:
	"""Initialize combat targeting rules based on team relationships."""
	targeting_rules = {
		"auto_target_hostiles": true,
		"ignore_neutral_targets": true,
		"priority_target_closest": false,
		"respect_escort_flags": true,
		"avoid_friendly_fire": true,
		"stealth_affects_targeting": true
	}

# ============================================================================
# SHIP TEAM MANAGEMENT API (SHIP-004 AC5)
# ============================================================================

## Register ship with team management system (SHIP-004 AC5)
func register_ship(ship: BaseShip, initial_team: int = TeamTypes.Team.FRIENDLY, faction: String = "", iff_code: String = "") -> bool:
	"""Register ship with team management system.
	
	Args:
		ship: Ship to register
		initial_team: Initial team assignment
		faction: Faction name (optional)
		iff_code: IFF identifier (optional)
		
	Returns:
		true if registration successful
	"""
	if not ship or ship_teams.has(ship):
		return false
	
	# Create team data
	var team_data: ShipTeamData = ShipTeamData.new(ship)
	team_data.team = initial_team
	team_data.observed_team = initial_team
	team_data.faction_name = faction
	team_data.iff_code = iff_code
	
	# Register ship
	ship_teams[ship] = team_data
	
	# Add to team composition
	_add_ship_to_team_composition(ship, initial_team)
	
	# Register IFF if provided
	if iff_code != "":
		_register_iff_code(ship, iff_code)
	
	# Update ship's team property
	ship.team = initial_team
	
	return true

## Unregister ship from team management
func unregister_ship(ship: BaseShip) -> bool:
	"""Unregister ship from team management system.
	
	Args:
		ship: Ship to unregister
		
	Returns:
		true if unregistration successful
	"""
	if not ship or not ship_teams.has(ship):
		return false
	
	var team_data: ShipTeamData = ship_teams[ship]
	
	# Remove from team composition
	_remove_ship_from_team_composition(ship, team_data.team)
	
	# Unregister IFF
	if team_data.iff_code != "":
		_unregister_iff_code(ship, team_data.iff_code)
	
	# Remove from ignore lists
	_remove_from_ignore_lists(ship)
	
	# Remove team data
	ship_teams.erase(ship)
	
	return true

## Set ship team with validation (SHIP-004 AC5)
func set_ship_team(ship: BaseShip, new_team: int, change_reason: String = "") -> bool:
	"""Set ship team with validation and side effects.
	
	Args:
		ship: Ship to change team for
		new_team: New team assignment
		change_reason: Reason for team change (for logging)
		
	Returns:
		true if team change successful
	"""
	if not ship or not ship_teams.has(ship):
		return false
	
	if not TeamTypes.is_valid_team(new_team):
		push_error("ShipTeamManager: Invalid team %d" % new_team)
		return false
	
	var team_data: ShipTeamData = ship_teams[ship]
	var old_team: int = team_data.team
	
	if old_team == new_team:
		return true  # No change needed
	
	# Update team data
	team_data.team = new_team
	team_data.observed_team = new_team  # Default to same as actual team
	team_data.team_change_count += 1
	team_data.last_team_change_time = Time.get_ticks_msec() * 0.001
	
	# Update team compositions
	_remove_ship_from_team_composition(ship, old_team)
	_add_ship_to_team_composition(ship, new_team)
	
	# Update ship's team property
	ship.team = new_team
	
	# Handle team change side effects
	_handle_team_change_side_effects(ship, old_team, new_team, change_reason)
	
	# Emit team change signal
	team_changed.emit(ship, old_team, new_team)
	
	return true

## Get ship team
func get_ship_team(ship: BaseShip) -> int:
	"""Get ship's current team assignment."""
	if not ship or not ship_teams.has(ship):
		return TeamTypes.Team.UNKNOWN
	
	return ship_teams[ship].team

## Set observed team color (for stealth/deception) (SHIP-004 AC5)
func set_ship_observed_team(ship: BaseShip, observed_team: int) -> bool:
	"""Set team color that other ships observe (for stealth/deception).
	
	Args:
		ship: Ship to set observed team for
		observed_team: Team that others will observe
		
	Returns:
		true if observed team was set successfully
	"""
	if not ship or not ship_teams.has(ship):
		return false
	
	if not TeamTypes.is_valid_team(observed_team):
		return false
	
	var team_data: ShipTeamData = ship_teams[ship]
	team_data.observed_team = observed_team
	
	# Emit observed team change signal
	observed_team_changed.emit(ship, observed_team)
	
	return true

## Get observed team color
func get_ship_observed_team(ship: BaseShip) -> int:
	"""Get team color that other ships observe."""
	if not ship or not ship_teams.has(ship):
		return TeamTypes.Team.UNKNOWN
	
	return ship_teams[ship].observed_team

## Set ship IFF code (SHIP-004 AC5)
func set_ship_iff_code(ship: BaseShip, new_iff_code: String) -> bool:
	"""Set ship IFF identifier code.
	
	Args:
		ship: Ship to set IFF for
		new_iff_code: IFF identifier string
		
	Returns:
		true if IFF code was set successfully
	"""
	if not ship or not ship_teams.has(ship):
		return false
	
	var team_data: ShipTeamData = ship_teams[ship]
	var old_iff_code: String = team_data.iff_code
	
	# Unregister old IFF
	if old_iff_code != "":
		_unregister_iff_code(ship, old_iff_code)
	
	# Set new IFF
	team_data.iff_code = new_iff_code
	
	# Register new IFF
	if new_iff_code != "":
		_register_iff_code(ship, new_iff_code)
	
	# Emit IFF change signal
	iff_code_changed.emit(ship, old_iff_code, new_iff_code)
	
	return true

## Get ship IFF code
func get_ship_iff_code(ship: BaseShip) -> String:
	"""Get ship's IFF identifier code."""
	if not ship or not ship_teams.has(ship):
		return ""
	
	return ship_teams[ship].iff_code

# ============================================================================
# TEAM RELATIONSHIP API (SHIP-004 AC5)
# ============================================================================

## Get team relationship (SHIP-004 AC5)
func get_team_relationship(team1: int, team2: int) -> int:
	"""Get relationship between two teams.
	
	Args:
		team1: First team
		team2: Second team
		
	Returns:
		TeamTypes.Relationship value
	"""
	if not TeamTypes.is_valid_team(team1) or not TeamTypes.is_valid_team(team2):
		return TeamTypes.Relationship.HOSTILE
	
	# Same team is always friendly
	if team1 == team2:
		return TeamTypes.Relationship.FRIENDLY
	
	# Use default relationship matrix
	if team1 < default_team_relationships.size() and team2 < default_team_relationships[team1].size():
		return default_team_relationships[team1][team2]
	
	# Default to hostile for safety
	return TeamTypes.Relationship.HOSTILE

## Get ship relationship (SHIP-004 AC5)
func get_ship_relationship(ship1: BaseShip, ship2: BaseShip) -> int:
	"""Get relationship between two ships based on observed teams.
	
	Args:
		ship1: First ship
		ship2: Second ship
		
	Returns:
		TeamTypes.Relationship value
	"""
	if not ship1 or not ship2:
		return TeamTypes.Relationship.HOSTILE
	
	var team1: int = get_ship_observed_team(ship1)
	var team2: int = get_ship_observed_team(ship2)
	
	return get_team_relationship(team1, team2)

## Check if ships are hostile (SHIP-004 AC5)
func are_ships_hostile(ship1: BaseShip, ship2: BaseShip) -> bool:
	"""Check if two ships are hostile to each other."""
	var relationship: int = get_ship_relationship(ship1, ship2)
	return relationship == TeamTypes.Relationship.HOSTILE

## Check if ships are friendly (SHIP-004 AC5)
func are_ships_friendly(ship1: BaseShip, ship2: BaseShip) -> bool:
	"""Check if two ships are friendly to each other."""
	var relationship: int = get_ship_relationship(ship1, ship2)
	return relationship == TeamTypes.Relationship.FRIENDLY

## Set faction relationship
func set_faction_relationship(faction1: String, faction2: String, relationship: int, permanent: bool = false) -> bool:
	"""Set relationship between two factions.
	
	Args:
		faction1: First faction name
		faction2: Second faction name
		relationship: TeamTypes.Relationship value
		permanent: Whether relationship cannot be changed
		
	Returns:
		true if relationship was set successfully
	"""
	return _set_faction_relationship(faction1, faction2, relationship, permanent)

# ============================================================================
# TARGETING AND COMBAT INTEGRATION (SHIP-004 AC5)
# ============================================================================

## Check if ship can target another ship (SHIP-004 AC5)
func can_target_ship(attacker: BaseShip, target: BaseShip) -> bool:
	"""Check if attacker can target another ship based on team rules.
	
	Args:
		attacker: Ship attempting to target
		target: Potential target ship
		
	Returns:
		true if targeting is allowed
	"""
	if not attacker or not target:
		return false
	
	# Ships cannot target themselves
	if attacker == target:
		return false
	
	# Check ignore list
	if _is_ship_ignored(attacker, target):
		return false
	
	# Check if target is in friendly fire avoidance
	if targeting_rules.get("avoid_friendly_fire", true):
		if are_ships_friendly(attacker, target):
			return false
	
	# Check stealth effects
	if targeting_rules.get("stealth_affects_targeting", true):
		if _is_ship_stealthed_from(target, attacker):
			return false
	
	# Check escort flags
	if targeting_rules.get("respect_escort_flags", true):
		if _is_ship_escorted(target):
			# TODO: Check if attacker is hostile to escorts
			pass
	
	return true

## Get valid targets for ship (SHIP-004 AC5)
func get_valid_targets(attacker: BaseShip, target_teams: Array[int] = []) -> Array[BaseShip]:
	"""Get list of valid targets for attacking ship.
	
	Args:
		attacker: Ship looking for targets
		target_teams: Specific teams to target (empty for all hostile)
		
	Returns:
		Array of valid target ships
	"""
	var valid_targets: Array[BaseShip] = []
	
	if not attacker:
		return valid_targets
	
	# Use all hostile teams if none specified
	if target_teams.is_empty():
		target_teams = _get_hostile_teams_for_ship(attacker)
	
	# Check all ships in specified teams
	for team: int in target_teams:
		if team_compositions.has(team):
			var team_ships: Array[BaseShip] = team_compositions[team]
			for ship: BaseShip in team_ships:
				if can_target_ship(attacker, ship):
					valid_targets.append(ship)
	
	return valid_targets

## Add ship to ignore list
func add_ship_to_ignore_list(attacker: BaseShip, target: BaseShip) -> bool:
	"""Add ship to attacker's ignore list.
	
	Args:
		attacker: Ship that should ignore target
		target: Ship to ignore
		
	Returns:
		true if added successfully
	"""
	if not attacker or not target:
		return false
	
	if not ignore_list.has(attacker):
		ignore_list[attacker] = []
	
	var ignore_array: Array = ignore_list[attacker]
	if target not in ignore_array:
		ignore_array.append(target)
	
	return true

## Remove ship from ignore list
func remove_ship_from_ignore_list(attacker: BaseShip, target: BaseShip) -> bool:
	"""Remove ship from attacker's ignore list.
	
	Args:
		attacker: Ship that should stop ignoring target
		target: Ship to stop ignoring
		
	Returns:
		true if removed successfully
	"""
	if not attacker or not target or not ignore_list.has(attacker):
		return false
	
	var ignore_array: Array = ignore_list[attacker]
	if target in ignore_array:
		ignore_array.erase(target)
	
	return true

# ============================================================================
# INTERNAL TEAM MANAGEMENT
# ============================================================================

## Add ship to team composition
func _add_ship_to_team_composition(ship: BaseShip, team: int) -> void:
	"""Add ship to team composition tracking."""
	if not team_compositions.has(team):
		team_compositions[team] = []
	
	var team_ships: Array[BaseShip] = team_compositions[team]
	if ship not in team_ships:
		team_ships.append(ship)

## Remove ship from team composition
func _remove_ship_from_team_composition(ship: BaseShip, team: int) -> void:
	"""Remove ship from team composition tracking."""
	if not team_compositions.has(team):
		return
	
	var team_ships: Array[BaseShip] = team_compositions[team]
	if ship in team_ships:
		team_ships.erase(ship)

## Register IFF code
func _register_iff_code(ship: BaseShip, iff_code: String) -> void:
	"""Register ship with IFF code."""
	if not iff_registry.has(iff_code):
		iff_registry[iff_code] = []
	
	var iff_ships: Array[BaseShip] = iff_registry[iff_code]
	if ship not in iff_ships:
		iff_ships.append(ship)

## Unregister IFF code
func _unregister_iff_code(ship: BaseShip, iff_code: String) -> void:
	"""Unregister ship from IFF code."""
	if not iff_registry.has(iff_code):
		return
	
	var iff_ships: Array[BaseShip] = iff_registry[iff_code]
	if ship in iff_ships:
		iff_ships.erase(ship)

## Set faction relationship (internal)
func _set_faction_relationship(faction1: String, faction2: String, relationship: int, permanent: bool = false) -> bool:
	"""Internal method to set faction relationship."""
	if not faction_definitions.has(faction1) or not faction_definitions.has(faction2):
		return false
	
	# Ensure both directions exist
	if not faction_relationships.has(faction1):
		faction_relationships[faction1] = {}
	if not faction_relationships.has(faction2):
		faction_relationships[faction2] = {}
	
	# Create relationship objects
	var rel1: FactionRelationship = FactionRelationship.new(faction1, faction2, relationship)
	rel1.is_permanent = permanent
	var rel2: FactionRelationship = FactionRelationship.new(faction2, faction1, relationship)
	rel2.is_permanent = permanent
	
	faction_relationships[faction1][faction2] = rel1
	faction_relationships[faction2][faction1] = rel2
	
	# Emit relationship change signal
	faction_relationship_changed.emit(faction1, faction2, relationship)
	
	return true

## Handle team change side effects
func _handle_team_change_side_effects(ship: BaseShip, old_team: int, new_team: int, change_reason: String) -> void:
	"""Handle side effects of team changes."""
	# Clear ignore lists involving this ship
	_clear_ignore_lists_for_ship(ship)
	
	# TODO: Update AI targeting for affected ships
	# TODO: Update mission objective tracking
	# TODO: Update HUD team indicators
	
	# Log team change for mission system
	if change_reason != "":
		print("Ship %s changed team from %s to %s: %s" % [
			ship.ship_name,
			TeamTypes.get_team_name(old_team),
			TeamTypes.get_team_name(new_team),
			change_reason
		])

## Check if ship is ignored by attacker
func _is_ship_ignored(attacker: BaseShip, target: BaseShip) -> bool:
	"""Check if target ship is in attacker's ignore list."""
	if not ignore_list.has(attacker):
		return false
	
	var ignore_array: Array = ignore_list[attacker]
	return target in ignore_array

## Check if ship is stealthed from observer
func _is_ship_stealthed_from(target: BaseShip, observer: BaseShip) -> bool:
	"""Check if target ship is stealthed from observer."""
	# TODO: Implement stealth detection logic
	# This would check ship flags, distance, sensor capabilities, etc.
	return false

## Check if ship is escorted
func _is_ship_escorted(ship: BaseShip) -> bool:
	"""Check if ship has escort protection."""
	# TODO: Implement escort flag checking
	return false

## Get hostile teams for ship
func _get_hostile_teams_for_ship(ship: BaseShip) -> Array[int]:
	"""Get list of teams that are hostile to ship."""
	var hostile_teams: Array[int] = []
	var ship_team: int = get_ship_observed_team(ship)
	
	for team: int in TeamTypes.Team.values():
		if get_team_relationship(ship_team, team) == TeamTypes.Relationship.HOSTILE:
			hostile_teams.append(team)
	
	return hostile_teams

## Remove ship from all ignore lists
func _remove_from_ignore_lists(ship: BaseShip) -> void:
	"""Remove ship from all ignore lists."""
	# Remove ship as target
	for attacker: BaseShip in ignore_list.keys():
		var ignore_array: Array = ignore_list[attacker]
		if ship in ignore_array:
			ignore_array.erase(ship)
	
	# Remove ship as attacker
	if ignore_list.has(ship):
		ignore_list.erase(ship)

## Clear ignore lists for ship
func _clear_ignore_lists_for_ship(ship: BaseShip) -> void:
	"""Clear ignore lists involving ship (both directions)."""
	_remove_from_ignore_lists(ship)

# ============================================================================
# SAVE/LOAD INTEGRATION (SHIP-004 AC7)
# ============================================================================

## Get save data for team management
func get_save_data() -> Dictionary:
	"""Get team management save data for persistence."""
	var save_data: Dictionary = {
		"ship_teams": {},
		"faction_relationships": {},
		"mission_team_overrides": mission_team_overrides.duplicate(),
		"red_alert_team_preservation": red_alert_team_preservation.duplicate()
	}
	
	# Save ship team data
	for ship: BaseShip in ship_teams.keys():
		var team_data: ShipTeamData = ship_teams[ship]
		save_data["ship_teams"][ship.ship_name] = {
			"team": team_data.team,
			"observed_team": team_data.observed_team,
			"faction_name": team_data.faction_name,
			"iff_code": team_data.iff_code,
			"original_team": team_data.original_team,
			"team_change_count": team_data.team_change_count
		}
	
	# Save faction relationships (non-permanent only)
	for faction1: String in faction_relationships.keys():
		save_data["faction_relationships"][faction1] = {}
		for faction2: String in faction_relationships[faction1].keys():
			var rel: FactionRelationship = faction_relationships[faction1][faction2]
			if not rel.is_permanent:
				save_data["faction_relationships"][faction1][faction2] = {
					"relationship": rel.relationship,
					"change_time": rel.change_time
				}
	
	return save_data

## Load save data for team management
func load_save_data(save_data: Dictionary, ship_registry: Dictionary) -> bool:
	"""Load team management save data from persistence.
	
	Args:
		save_data: Dictionary containing saved data
		ship_registry: Dictionary mapping ship names to BaseShip instances
		
	Returns:
		true if data loaded successfully
	"""
	if not save_data:
		return false
	
	# Load mission team overrides
	mission_team_overrides = save_data.get("mission_team_overrides", {})
	red_alert_team_preservation = save_data.get("red_alert_team_preservation", {})
	
	# Load ship team data
	if save_data.has("ship_teams"):
		var saved_ship_teams: Dictionary = save_data["ship_teams"]
		for ship_name: String in saved_ship_teams.keys():
			if ship_registry.has(ship_name):
				var ship: BaseShip = ship_registry[ship_name]
				var saved_team_data: Dictionary = saved_ship_teams[ship_name]
				
				# Register ship if not already registered
				if not ship_teams.has(ship):
					register_ship(ship, saved_team_data.get("team", TeamTypes.Team.FRIENDLY))
				
				# Update team data
				var team_data: ShipTeamData = ship_teams[ship]
				team_data.team = saved_team_data.get("team", TeamTypes.Team.FRIENDLY)
				team_data.observed_team = saved_team_data.get("observed_team", team_data.team)
				team_data.faction_name = saved_team_data.get("faction_name", "")
				team_data.iff_code = saved_team_data.get("iff_code", "")
				team_data.original_team = saved_team_data.get("original_team", team_data.team)
				team_data.team_change_count = saved_team_data.get("team_change_count", 0)
				
				# Update ship's team property
				ship.team = team_data.team
	
	# Load faction relationships
	if save_data.has("faction_relationships"):
		var saved_relationships: Dictionary = save_data["faction_relationships"]
		for faction1: String in saved_relationships.keys():
			for faction2: String in saved_relationships[faction1].keys():
				var rel_data: Dictionary = saved_relationships[faction1][faction2]
				_set_faction_relationship(
					faction1,
					faction2,
					rel_data.get("relationship", TeamTypes.Relationship.NEUTRAL),
					false  # Loaded relationships are not permanent
				)
	
	return true

# ============================================================================
# DEBUG AND INFORMATION
# ============================================================================

## Get team statistics
func get_team_statistics() -> Dictionary:
	"""Get comprehensive team management statistics."""
	var stats: Dictionary = {
		"total_ships": ship_teams.size(),
		"team_composition": {},
		"faction_count": faction_definitions.size(),
		"relationship_count": 0,
		"iff_codes": iff_registry.size()
	}
	
	# Count ships per team
	for team: int in team_compositions.keys():
		var team_name: String = TeamTypes.get_team_name(team)
		stats["team_composition"][team_name] = team_compositions[team].size()
	
	# Count faction relationships
	for faction1: String in faction_relationships.keys():
		stats["relationship_count"] += faction_relationships[faction1].size()
	
	return stats

## Get debug information string
func debug_info() -> String:
	"""Get debug information string."""
	var ship_count: int = ship_teams.size()
	var faction_count: int = faction_definitions.size()
	var relationship_count: int = 0
	
	for faction1: String in faction_relationships.keys():
		relationship_count += faction_relationships[faction1].size()
	
	return "[TeamMgr Ships:%d Factions:%d Relations:%d]" % [ship_count, faction_count, relationship_count]