@tool
class_name AssetPattern
extends Resource

## Asset pattern library entry for standard ship configurations and weapon loadouts.
## Provides reusable asset combinations with tactical roles and specifications.

signal pattern_modified()

enum PatternType {
	SHIP_LOADOUT,
	WING_FORMATION,
	WEAPON_CONFIG,
	FLEET_COMPOSITION,
	SQUADRON_SETUP,
	TACTICAL_GROUP,
	DEFENSE_GRID,
	SUPPORT_PACKAGE
}

enum TacticalRole {
	FIGHTER,
	BOMBER,
	INTERCEPTOR,
	ASSAULT,
	SUPPORT,
	RECONNAISSANCE,
	ESCORT,
	HEAVY_ASSAULT,
	POINT_DEFENSE,
	CAPITAL_SHIP
}

enum Faction {
	TERRAN,
	VASUDAN,
	SHIVAN,
	PIRATE,
	CIVILIAN,
	UNKNOWN,
	CUSTOM
}

# Pattern metadata
@export var pattern_id: String = ""
@export var pattern_name: String = ""
@export var pattern_type: PatternType = PatternType.SHIP_LOADOUT
@export var tactical_role: TacticalRole = TacticalRole.FIGHTER
@export var faction: Faction = Faction.TERRAN
@export var description: String = ""
@export var usage_notes: String = ""
@export var author: String = ""
@export var version: String = "1.0.0"

# Asset specifications
@export var ship_class: String = ""
@export var primary_weapons: Array[String] = []
@export var secondary_weapons: Array[String] = []
@export var weapon_loadout: Dictionary = {}

# Formation and tactical data
@export var wing_size: int = 4
@export var formation_type: String = "standard"
@export var ai_behavior: String = "default"
@export var difficulty_modifier: float = 1.0

# Pattern requirements and restrictions
@export var required_assets: Array[String] = []
@export var faction_restrictions: Array[String] = []
@export var mission_type_compatibility: Array[String] = []

# Community features
@export var tags: Array[String] = []
@export var is_community_pattern: bool = false
@export var effectiveness_rating: float = 0.0
@export var usage_count: int = 0
@export var created_date: String = ""

func _init() -> void:
	pattern_id = _generate_unique_id()
	created_date = Time.get_datetime_string_from_system()

func _generate_unique_id() -> String:
	return "asset_pattern_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)

## Applies pattern to create mission objects
func create_mission_objects(parameters: Dictionary = {}) -> Array[MissionObject]:
	var objects: Array[MissionObject] = []
	
	match pattern_type:
		PatternType.SHIP_LOADOUT:
			var ship: MissionObject = _create_configured_ship(parameters)
			if ship:
				objects.append(ship)
		
		PatternType.WING_FORMATION:
			var wing_objects: Array[MissionObject] = _create_wing_formation(parameters)
			objects.append_array(wing_objects)
		
		PatternType.FLEET_COMPOSITION:
			var fleet_objects: Array[MissionObject] = _create_fleet_composition(parameters)
			objects.append_array(fleet_objects)
		
		PatternType.DEFENSE_GRID:
			var defense_objects: Array[MissionObject] = _create_defense_grid(parameters)
			objects.append_array(defense_objects)
	
	return objects

## Creates a single ship with configured loadout
func _create_configured_ship(parameters: Dictionary) -> MissionObject:
	var ship: MissionObject = MissionObject.new()
	ship.type = MissionObject.Type.SHIP
	ship.name = parameters.get("ship_name", pattern_name + " Ship")
	ship.id = "ship_" + str(Time.get_unix_time_from_system())
	
	# Apply ship class
	var final_ship_class: String = parameters.get("ship_class", ship_class)
	ship.set_property("ship_class", final_ship_class)
	
	# Apply weapon loadout
	var final_loadout: Dictionary = weapon_loadout.duplicate()
	if parameters.has("weapon_overrides"):
		final_loadout.merge(parameters.weapon_overrides)
	
	for weapon_bank in final_loadout.keys():
		ship.set_property("weapon_" + str(weapon_bank), final_loadout[weapon_bank])
	
	# Apply AI behavior
	ship.set_property("ai_behavior", parameters.get("ai_behavior", ai_behavior))
	ship.set_property("team", parameters.get("team", _get_faction_team()))
	
	return ship

## Creates a wing formation with multiple ships
func _create_wing_formation(parameters: Dictionary) -> Array[MissionObject]:
	var objects: Array[MissionObject] = []
	
	# Create wing object
	var wing: MissionObject = MissionObject.new()
	wing.type = MissionObject.Type.WING
	wing.name = parameters.get("wing_name", pattern_name + " Wing")
	wing.id = "wing_" + str(Time.get_unix_time_from_system())
	wing.set_property("formation", parameters.get("formation", formation_type))
	wing.set_property("team", parameters.get("team", _get_faction_team()))
	objects.append(wing)
	
	# Create ships in the wing
	var actual_wing_size: int = parameters.get("wing_size", wing_size)
	for i in actual_wing_size:
		var ship: MissionObject = _create_configured_ship({
			"ship_name": wing.name + " " + str(i + 1),
			"team": wing.get_property("team")
		})
		ship.set_property("wing_id", wing.id)
		objects.append(ship)
	
	return objects

## Creates a complete fleet composition
func _create_fleet_composition(parameters: Dictionary) -> Array[MissionObject]:
	var objects: Array[MissionObject] = []
	
	# Create capital ships if specified
	if weapon_loadout.has("capital_ships"):
		var capital_count: int = weapon_loadout.capital_ships.get("count", 1)
		var capital_class: String = weapon_loadout.capital_ships.get("class", "Destroyer")
		
		for i in capital_count:
			var capital: MissionObject = MissionObject.new()
			capital.type = MissionObject.Type.SHIP
			capital.name = parameters.get("fleet_name", "Fleet") + " Capital " + str(i + 1)
			capital.id = "capital_" + str(Time.get_unix_time_from_system()) + "_" + str(i)
			capital.set_property("ship_class", capital_class)
			capital.set_property("team", parameters.get("team", _get_faction_team()))
			objects.append(capital)
	
	# Create escort wings
	if weapon_loadout.has("escort_wings"):
		var escort_count: int = weapon_loadout.escort_wings.get("count", 2)
		for i in escort_count:
			var escort_wing: Array[MissionObject] = _create_wing_formation({
				"wing_name": parameters.get("fleet_name", "Fleet") + " Escort " + str(i + 1),
				"team": parameters.get("team", _get_faction_team())
			})
			objects.append_array(escort_wing)
	
	return objects

## Creates a defensive grid pattern
func _create_defense_grid(parameters: Dictionary) -> Array[MissionObject]:
	var objects: Array[MissionObject] = []
	
	# Create sentry guns
	if weapon_loadout.has("sentry_guns"):
		var gun_count: int = weapon_loadout.sentry_guns.get("count", 4)
		var gun_type: String = weapon_loadout.sentry_guns.get("type", "Sentry Gun")
		
		for i in gun_count:
			var sentry: MissionObject = MissionObject.new()
			sentry.type = MissionObject.Type.SENTRY_GUN
			sentry.name = "Defense Grid Gun " + str(i + 1)
			sentry.id = "sentry_" + str(Time.get_unix_time_from_system()) + "_" + str(i)
			sentry.set_property("sentry_type", gun_type)
			sentry.set_property("team", parameters.get("team", _get_faction_team()))
			objects.append(sentry)
	
	# Create patrol wings
	if weapon_loadout.has("patrol_wings"):
		var patrol_count: int = weapon_loadout.patrol_wings.get("count", 2)
		for i in patrol_count:
			var patrol_wing: Array[MissionObject] = _create_wing_formation({
				"wing_name": "Defense Patrol " + str(i + 1),
				"team": parameters.get("team", _get_faction_team()),
				"ai_behavior": "patrol"
			})
			objects.append_array(patrol_wing)
	
	return objects

## Gets default team number for faction
func _get_faction_team() -> int:
	match faction:
		Faction.TERRAN:
			return 1
		Faction.VASUDAN:
			return 2
		Faction.SHIVAN:
			return 3
		Faction.PIRATE:
			return 4
		Faction.CIVILIAN:
			return 5
		_:
			return 1

## Validates pattern requirements against current asset system
func validate_pattern() -> Array[String]:
	var errors: Array[String] = []
	
	# Check basic pattern data
	if pattern_name.is_empty():
		errors.append("Pattern name is required")
	if ship_class.is_empty() and pattern_type == PatternType.SHIP_LOADOUT:
		errors.append("Ship class is required for ship loadout patterns")
	
	# Check required assets
	for asset_path in required_assets:
		if not WCSAssetRegistry.asset_exists(asset_path):
			errors.append("Required asset not found: " + asset_path)
	
	# Validate ship class exists
	if not ship_class.is_empty():
		var ship_assets: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
		var ship_found: bool = false
		for ship_path in ship_assets:
			var ship_data: ShipData = WCSAssetLoader.load_asset(ship_path)
			if ship_data and ship_data.ship_name == ship_class:
				ship_found = true
				break
		if not ship_found:
			errors.append("Ship class not found in asset registry: " + ship_class)
	
	# Validate weapons exist
	for weapon in primary_weapons + secondary_weapons:
		var weapon_assets: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.WEAPON)
		var weapon_found: bool = false
		for weapon_path in weapon_assets:
			var weapon_data: WeaponData = WCSAssetLoader.load_asset(weapon_path)
			if weapon_data and weapon_data.weapon_name == weapon:
				weapon_found = true
				break
		if not weapon_found:
			errors.append("Weapon not found in asset registry: " + weapon)
	
	return errors

## Creates standard fighter loadout patterns
static func create_interceptor_pattern() -> AssetPattern:
	var pattern: AssetPattern = AssetPattern.new()
	pattern.pattern_name = "Standard Interceptor"
	pattern.pattern_type = PatternType.SHIP_LOADOUT
	pattern.tactical_role = TacticalRole.INTERCEPTOR
	pattern.faction = Faction.TERRAN
	pattern.description = "Fast, agile fighter optimized for dogfighting"
	
	pattern.ship_class = "Apollo"
	pattern.primary_weapons = ["Subach HL-7", "Prometheus R"]
	pattern.secondary_weapons = ["Tempest", "Harpoon"]
	pattern.weapon_loadout = {
		"primary_1": "Subach HL-7",
		"primary_2": "Prometheus R",
		"secondary_1": "Tempest",
		"secondary_2": "Harpoon"
	}
	pattern.ai_behavior = "interceptor"
	pattern.tags = ["fighter", "interceptor", "dogfight"]
	
	return pattern

static func create_bomber_pattern() -> AssetPattern:
	var pattern: AssetPattern = AssetPattern.new()
	pattern.pattern_name = "Heavy Bomber"
	pattern.pattern_type = PatternType.SHIP_LOADOUT
	pattern.tactical_role = TacticalRole.BOMBER
	pattern.faction = Faction.TERRAN
	pattern.description = "Heavy assault bomber for capital ship attacks"
	
	pattern.ship_class = "Ursa"
	pattern.primary_weapons = ["Maxim", "Prometheus S"]
	pattern.secondary_weapons = ["Cyclops", "Helios"]
	pattern.weapon_loadout = {
		"primary_1": "Maxim",
		"primary_2": "Prometheus S",
		"secondary_1": "Cyclops",
		"secondary_2": "Helios"
	}
	pattern.ai_behavior = "bomber"
	pattern.tags = ["bomber", "heavy", "capital-attack"]
	
	return pattern

static func create_escort_wing_pattern() -> AssetPattern:
	var pattern: AssetPattern = AssetPattern.new()
	pattern.pattern_name = "Escort Wing Formation"
	pattern.pattern_type = PatternType.WING_FORMATION
	pattern.tactical_role = TacticalRole.ESCORT
	pattern.faction = Faction.TERRAN
	pattern.description = "Balanced wing formation for escort missions"
	
	pattern.ship_class = "Hercules Mark II"
	pattern.wing_size = 4
	pattern.formation_type = "diamond"
	pattern.ai_behavior = "escort"
	pattern.weapon_loadout = {
		"primary_1": "Subach HL-7",
		"primary_2": "Adv Disruptor",
		"secondary_1": "Harpoon",
		"secondary_2": "Tempest"
	}
	pattern.tags = ["escort", "formation", "balanced"]
	
	return pattern

## Exports pattern for community sharing
func export_pattern() -> Dictionary:
	return {
		"pattern_id": pattern_id,
		"pattern_name": pattern_name,
		"pattern_type": pattern_type,
		"tactical_role": tactical_role,
		"faction": faction,
		"description": description,
		"usage_notes": usage_notes,
		"author": author,
		"version": version,
		"ship_class": ship_class,
		"primary_weapons": primary_weapons,
		"secondary_weapons": secondary_weapons,
		"weapon_loadout": weapon_loadout,
		"wing_size": wing_size,
		"formation_type": formation_type,
		"ai_behavior": ai_behavior,
		"difficulty_modifier": difficulty_modifier,
		"required_assets": required_assets,
		"faction_restrictions": faction_restrictions,
		"mission_type_compatibility": mission_type_compatibility,
		"tags": tags,
		"created_date": created_date
	}

## Imports pattern from community sharing format
static func import_pattern(pattern_data: Dictionary) -> AssetPattern:
	var pattern: AssetPattern = AssetPattern.new()
	
	pattern.pattern_id = pattern_data.get("pattern_id", "")
	pattern.pattern_name = pattern_data.get("pattern_name", "")
	pattern.pattern_type = pattern_data.get("pattern_type", PatternType.SHIP_LOADOUT)
	pattern.tactical_role = pattern_data.get("tactical_role", TacticalRole.FIGHTER)
	pattern.faction = pattern_data.get("faction", Faction.TERRAN)
	pattern.description = pattern_data.get("description", "")
	pattern.usage_notes = pattern_data.get("usage_notes", "")
	pattern.author = pattern_data.get("author", "")
	pattern.version = pattern_data.get("version", "1.0.0")
	pattern.ship_class = pattern_data.get("ship_class", "")
	pattern.primary_weapons = pattern_data.get("primary_weapons", [])
	pattern.secondary_weapons = pattern_data.get("secondary_weapons", [])
	pattern.weapon_loadout = pattern_data.get("weapon_loadout", {})
	pattern.wing_size = pattern_data.get("wing_size", 4)
	pattern.formation_type = pattern_data.get("formation_type", "standard")
	pattern.ai_behavior = pattern_data.get("ai_behavior", "default")
	pattern.difficulty_modifier = pattern_data.get("difficulty_modifier", 1.0)
	pattern.required_assets = pattern_data.get("required_assets", [])
	pattern.faction_restrictions = pattern_data.get("faction_restrictions", [])
	pattern.mission_type_compatibility = pattern_data.get("mission_type_compatibility", [])
	pattern.tags = pattern_data.get("tags", [])
	pattern.created_date = pattern_data.get("created_date", "")
	pattern.is_community_pattern = true
	
	return pattern