class_name TeamTypes
extends RefCounted

## Team and faction type constants for WCS-Godot conversion
## Defines team assignments, relationships, and faction management (SHIP-004)

# Ship team assignments (matching WCS team enum)
enum Team {
	FRIENDLY = 0,              # Player and allied forces
	HOSTILE = 1,               # Enemy forces
	NEUTRAL = 2,               # Non-combatant forces
	UNKNOWN = 3,               # Unidentified forces
	ALL = 4                    # All teams (for targeting filters)
}

# Team relationship types
enum Relationship {
	FRIENDLY = 0,              # Ships cooperate and don't target each other
	HOSTILE = 1,               # Ships are enemies and will target each other
	NEUTRAL = 2                # Ships ignore each other
}

# Default team names
const TEAM_NAMES: Array[String] = [
	"Friendly",
	"Hostile", 
	"Neutral",
	"Unknown",
	"All"
]

# Default team colors for UI display
const TEAM_COLORS: Array[Color] = [
	Color.GREEN,               # Friendly - green
	Color.RED,                 # Hostile - red
	Color.YELLOW,              # Neutral - yellow
	Color.GRAY,                # Unknown - gray
	Color.WHITE                # All - white
]

## Get team name
static func get_team_name(team: int) -> String:
	"""Get human-readable name for team."""
	if team >= 0 and team < TEAM_NAMES.size():
		return TEAM_NAMES[team]
	return "Invalid"

## Get team color
static func get_team_color(team: int) -> Color:
	"""Get display color for team."""
	if team >= 0 and team < TEAM_COLORS.size():
		return TEAM_COLORS[team]
	return Color.WHITE

## Check if team is valid
static func is_valid_team(team: int) -> bool:
	"""Check if team value is valid."""
	return team >= 0 and team < Team.size()

## Get team relationship
static func get_team_relationship(team1: int, team2: int) -> int:
	"""Get relationship between two teams.
	
	Args:
		team1: First team
		team2: Second team
		
	Returns:
		Relationship value
	"""
	if not is_valid_team(team1) or not is_valid_team(team2):
		return Relationship.HOSTILE  # Safe default
	
	# Same team is always friendly
	if team1 == team2:
		return Relationship.FRIENDLY
	
	# Default relationship matrix
	var relationship_matrix: Array[Array] = [
		# FRIENDLY, HOSTILE, NEUTRAL, UNKNOWN
		[Relationship.FRIENDLY, Relationship.HOSTILE, Relationship.NEUTRAL, Relationship.HOSTILE],  # FRIENDLY
		[Relationship.HOSTILE, Relationship.FRIENDLY, Relationship.HOSTILE, Relationship.HOSTILE],  # HOSTILE
		[Relationship.NEUTRAL, Relationship.HOSTILE, Relationship.NEUTRAL, Relationship.NEUTRAL],   # NEUTRAL
		[Relationship.HOSTILE, Relationship.HOSTILE, Relationship.NEUTRAL, Relationship.NEUTRAL]    # UNKNOWN
	]
	
	return relationship_matrix[team1][team2]

## Check if teams are hostile
static func are_teams_hostile(team1: int, team2: int) -> bool:
	"""Check if two teams are hostile to each other."""
	return get_team_relationship(team1, team2) == Relationship.HOSTILE

## Check if teams are friendly
static func are_teams_friendly(team1: int, team2: int) -> bool:
	"""Check if two teams are friendly to each other."""
	return get_team_relationship(team1, team2) == Relationship.FRIENDLY

## Check if teams are neutral
static func are_teams_neutral(team1: int, team2: int) -> bool:
	"""Check if two teams are neutral to each other."""
	return get_team_relationship(team1, team2) == Relationship.NEUTRAL

## Get relationship name
static func get_relationship_name(relationship: int) -> String:
	"""Get human-readable name for relationship."""
	match relationship:
		Relationship.FRIENDLY:
			return "Friendly"
		Relationship.HOSTILE:
			return "Hostile"
		Relationship.NEUTRAL:
			return "Neutral"
		_:
			return "Unknown"

## Convert team name to team value
static func get_team_from_name(team_name: String) -> int:
	"""Convert team name to team enum value.
	
	Args:
		team_name: Team name (case insensitive)
		
	Returns:
		Team enum value or -1 if invalid
	"""
	var normalized_name: String = team_name.to_lower()
	
	for i in range(TEAM_NAMES.size()):
		if TEAM_NAMES[i].to_lower() == normalized_name:
			return i
	
	return -1  # Invalid team name

## Get all team names
static func get_all_team_names() -> Array[String]:
	"""Get array of all team names."""
	return TEAM_NAMES.duplicate()

## Get all valid team values
static func get_all_team_values() -> Array[int]:
	"""Get array of all valid team values."""
	var teams: Array[int] = []
	for i in range(Team.size()):
		teams.append(i)
	return teams