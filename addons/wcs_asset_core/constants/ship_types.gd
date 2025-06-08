class_name ShipTypes
extends RefCounted

## Ship type constants for WCS-Godot conversion
## Defines ship classification types and related utility functions
## Based on WCS ship types and categories

# Ship type enumeration
enum Type {
	NONE = 0,
	FIGHTER = 1,
	BOMBER = 2,
	TRANSPORT = 3,
	CRUISER = 4,
	FRIGATE = 5,
	CAPITAL = 6,
	SUPER_CAPITAL = 7,
	SENTRY_GUN = 8,
	ESCAPE_POD = 9,
	CARGO = 10,
	NAVBUOY = 11,
	REPAIR_REARM = 12,
	UNKNOWN = 13
}

# Ship size categories
enum Size {
	FIGHTER_BOMBER = 0,
	CORVETTE = 1,
	CRUISER = 2,
	CAPITAL = 3,
	SUPER_CAPITAL = 4
}

# Ship capability flags
enum Capability {
	HAS_AFTERBURNER = 1 << 0,
	HAS_SHIELDS = 1 << 1,
	CAN_WARP = 1 << 2,
	STEALTH_CAPABLE = 1 << 3,
	REPAIR_REARM_CAPABLE = 1 << 4,
	CARGO_CAPABLE = 1 << 5,
	FIGHTER_BAY_CAPABLE = 1 << 6,
	BEAM_WEAPONS_CAPABLE = 1 << 7
}

# Ship team classifications
enum Team {
	UNKNOWN = -1,
	HOSTILE = 0,
	FRIENDLY = 1,
	NEUTRAL = 2,
	TRAITOR = 3
}

## Get display name for ship type
static func get_type_name(ship_type: Type) -> String:
	match ship_type:
		Type.NONE: return "None"
		Type.FIGHTER: return "Fighter"
		Type.BOMBER: return "Bomber"
		Type.TRANSPORT: return "Transport"
		Type.CRUISER: return "Cruiser"
		Type.FRIGATE: return "Frigate"
		Type.CAPITAL: return "Capital"
		Type.SUPER_CAPITAL: return "Super Capital"
		Type.SENTRY_GUN: return "Sentry Gun"
		Type.ESCAPE_POD: return "Escape Pod"
		Type.CARGO: return "Cargo"
		Type.NAVBUOY: return "Nav Buoy"
		Type.REPAIR_REARM: return "Repair/Rearm"
		Type.UNKNOWN: return "Unknown"
		_: return "Invalid"

## Get size category for ship type
static func get_size_category(ship_type: Type) -> Size:
	match ship_type:
		Type.FIGHTER, Type.BOMBER, Type.ESCAPE_POD:
			return Size.FIGHTER_BOMBER
		Type.TRANSPORT, Type.SENTRY_GUN:
			return Size.CORVETTE
		Type.CRUISER, Type.FRIGATE:
			return Size.CRUISER
		Type.CAPITAL:
			return Size.CAPITAL
		Type.SUPER_CAPITAL:
			return Size.SUPER_CAPITAL
		_:
			return Size.FIGHTER_BOMBER

## Check if ship type is a fighter-class vessel
static func is_fighter_type(ship_type: Type) -> bool:
	return ship_type == Type.FIGHTER or ship_type == Type.BOMBER

## Check if ship type is a capital-class vessel
static func is_capital_type(ship_type: Type) -> bool:
	return ship_type == Type.CAPITAL or ship_type == Type.SUPER_CAPITAL or ship_type == Type.CRUISER or ship_type == Type.FRIGATE

## Check if ship type is a support vessel
static func is_support_type(ship_type: Type) -> bool:
	return ship_type == Type.REPAIR_REARM or ship_type == Type.TRANSPORT or ship_type == Type.CARGO

## Check if ship type is a static object
static func is_static_type(ship_type: Type) -> bool:
	return ship_type == Type.SENTRY_GUN or ship_type == Type.NAVBUOY

## Get default capabilities for ship type
static func get_default_capabilities(ship_type: Type) -> int:
	var capabilities: int = 0
	
	match ship_type:
		Type.FIGHTER:
			capabilities |= Capability.HAS_AFTERBURNER
			capabilities |= Capability.HAS_SHIELDS
			capabilities |= Capability.CAN_WARP
		Type.BOMBER:
			capabilities |= Capability.HAS_AFTERBURNER
			capabilities |= Capability.HAS_SHIELDS
			capabilities |= Capability.CAN_WARP
		Type.TRANSPORT:
			capabilities |= Capability.HAS_SHIELDS
			capabilities |= Capability.CAN_WARP
			capabilities |= Capability.CARGO_CAPABLE
		Type.CRUISER, Type.FRIGATE:
			capabilities |= Capability.HAS_SHIELDS
			capabilities |= Capability.CAN_WARP
			capabilities |= Capability.BEAM_WEAPONS_CAPABLE
		Type.CAPITAL, Type.SUPER_CAPITAL:
			capabilities |= Capability.HAS_SHIELDS
			capabilities |= Capability.CAN_WARP
			capabilities |= Capability.BEAM_WEAPONS_CAPABLE
			capabilities |= Capability.FIGHTER_BAY_CAPABLE
		Type.REPAIR_REARM:
			capabilities |= Capability.HAS_SHIELDS
			capabilities |= Capability.CAN_WARP
			capabilities |= Capability.REPAIR_REARM_CAPABLE
		Type.ESCAPE_POD:
			pass  # No special capabilities
		Type.SENTRY_GUN:
			capabilities |= Capability.HAS_SHIELDS
		Type.NAVBUOY:
			pass  # No special capabilities
	
	return capabilities

## Check if ship type has specific capability
static func has_capability(ship_type: Type, capability: Capability) -> bool:
	var default_caps: int = get_default_capabilities(ship_type)
	return (default_caps & capability) != 0

## Get team name
static func get_team_name(team: Team) -> String:
	match team:
		Team.UNKNOWN: return "Unknown"
		Team.HOSTILE: return "Hostile"
		Team.FRIENDLY: return "Friendly"
		Team.NEUTRAL: return "Neutral"
		Team.TRAITOR: return "Traitor"
		_: return "Invalid"

## Check if team is enemy to player
static func is_enemy_team(team: Team) -> bool:
	return team == Team.HOSTILE or team == Team.TRAITOR

## Check if team is friendly to player
static func is_friendly_team(team: Team) -> bool:
	return team == Team.FRIENDLY

## Get size display name
static func get_size_name(size: Size) -> String:
	match size:
		Size.FIGHTER_BOMBER: return "Fighter/Bomber"
		Size.CORVETTE: return "Corvette"
		Size.CRUISER: return "Cruiser"
		Size.CAPITAL: return "Capital Ship"
		Size.SUPER_CAPITAL: return "Super Capital"
		_: return "Unknown Size"

## Get recommended collision shape for ship type
static func get_collision_shape_type(ship_type: Type) -> String:
	if is_fighter_type(ship_type):
		return "convex_hull"  # Fast collision for fighters
	elif is_capital_type(ship_type):
		return "trimesh"      # Accurate collision for capitals
	else:
		return "sphere"       # Simple collision for others