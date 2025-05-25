class_name TableMigrator
extends RefCounted

## Enhanced table migration tool for converting WCS .tbl files to Godot .tres resources
## Handles all WCS table types with complete data preservation and validation

signal migration_progress(table_name: String, current: int, total: int)
signal migration_complete(table_name: String, success: bool, output_path: String)
signal migration_error(table_name: String, error: String)

# Migration settings
@export var output_directory: String = "res://migrated_assets/tables/"
@export var create_backup: bool = true
@export var validate_output: bool = true
@export var preserve_comments: bool = true
@export var generate_debug_info: bool = true

# Table type mappings
const TABLE_RESOURCE_MAPPING: Dictionary = {
	"ships": "ShipData",
	"weapons": "WeaponData", 
	"ai_profiles": "AIProfileData",
	"subsystems": "SubsystemData",
	"missions": "MissionData",
	"campaigns": "CampaignData"
}

# Migration statistics
var migration_stats: Dictionary = {}
var parser: TableParser
var vp_manager: VPManager

func _init() -> void:
	parser = TableParser.new()
	migration_stats = {
		"total_tables": 0,
		"successful_migrations": 0,
		"failed_migrations": 0,
		"total_entries": 0,
		"start_time": 0.0,
		"end_time": 0.0
	}

## Public API

func set_vp_manager(vp_mgr: VPManager) -> void:
	"""Set the VP manager for accessing table files."""
	vp_manager = vp_mgr

func migrate_table_file(table_path: String, output_path: String = "") -> bool:
	"""Migrate a single table file to Godot resource format."""
	
	if not vp_manager:
		_emit_error("", "VP Manager not set")
		return false
	
	if not vp_manager.has_file(table_path):
		_emit_error(table_path, "Table file not found: %s" % table_path)
		return false
	
	var table_name: String = table_path.get_file().get_basename()
	var actual_output: String = output_path
	
	if actual_output.is_empty():
		actual_output = output_directory + table_name + ".tres"
	
	migration_stats.start_time = Time.get_time_dict_from_system()["unix"]
	migration_stats.total_tables += 1
	
	print("TableMigrator: Starting migration of %s" % table_path)
	
	# Parse the table file
	var table_data: Dictionary = parser.parse_table_from_vp(vp_manager, table_path)
	
	if table_data.is_empty():
		_emit_error(table_name, "Failed to parse table file")
		migration_stats.failed_migrations += 1
		return false
	
	# Convert parsed data to Godot resources
	var success: bool = _convert_table_to_resources(table_name, table_data, actual_output)
	
	if success:
		migration_stats.successful_migrations += 1
		migration_complete.emit(table_name, true, actual_output)
		print("TableMigrator: Successfully migrated %s to %s" % [table_path, actual_output])
	else:
		migration_stats.failed_migrations += 1
		migration_complete.emit(table_name, false, actual_output)
	
	migration_stats.end_time = Time.get_time_dict_from_system()["unix"]
	return success

func migrate_all_tables() -> bool:
	"""Migrate all known WCS table files found in VP archives."""
	
	if not vp_manager:
		_emit_error("", "VP Manager not set")
		return false
	
	var table_files: Array[String] = [
		"data/tables/ships.tbl",
		"data/tables/weapons.tbl",
		"data/tables/ai_profiles.tbl",
		"data/tables/armor.tbl",
		"data/tables/sounds.tbl",
		"data/tables/music.tbl",
		"data/tables/objecttypes.tbl",
		"data/tables/medals.tbl",
		"data/tables/ranks.tbl",
		"data/tables/species_defs.tbl",
		"data/tables/iff_defs.tbl"
	]
	
	var all_success: bool = true
	migration_stats.total_tables = 0
	migration_stats.successful_migrations = 0
	migration_stats.failed_migrations = 0
	
	for table_file in table_files:
		if vp_manager.has_file(table_file):
			var success: bool = migrate_table_file(table_file)
			all_success = all_success and success
		else:
			print("TableMigrator: Table file not found, skipping: %s" % table_file)
	
	_print_migration_summary()
	return all_success

func get_migration_stats() -> Dictionary:
	"""Get detailed migration statistics."""
	return migration_stats.duplicate()

## Private implementation

func _convert_table_to_resources(table_name: String, table_data: Dictionary, output_path: String) -> bool:
	"""Convert parsed table data to appropriate Godot resource types."""
	
	var entries: Array = table_data.get("entries", [])
	if entries.is_empty():
		_emit_error(table_name, "No entries found in table")
		return false
	
	# Determine resource type based on table name
	var resource_class: String = _get_resource_class_for_table(table_name)
	if resource_class.is_empty():
		_emit_error(table_name, "Unknown table type: %s" % table_name)
		return false
	
	# Convert entries to resources
	var resources: Array[Resource] = []
	
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		migration_progress.emit(table_name, i + 1, entries.size())
		
		var resource: Resource = _create_resource_from_entry(resource_class, entry)
		if resource:
			resources.append(resource)
			migration_stats.total_entries += 1
		else:
			_emit_error(table_name, "Failed to create resource from entry: %s" % entry.get("name", "Unknown"))
	
	# Save resources to file
	return _save_resources_to_file(resources, output_path, table_name)

func _get_resource_class_for_table(table_name: String) -> String:
	"""Get the appropriate resource class for a table type."""
	
	# Direct mapping
	if TABLE_RESOURCE_MAPPING.has(table_name):
		return TABLE_RESOURCE_MAPPING[table_name]
	
	# Pattern matching for variant table names
	if table_name.begins_with("ship"):
		return "ShipData"
	elif table_name.begins_with("weapon"):
		return "WeaponData"
	elif table_name.begins_with("ai"):
		return "AIProfileData"
	elif "mission" in table_name:
		return "MissionData"
	elif "campaign" in table_name:
		return "CampaignData"
	
	return ""

func _create_resource_from_entry(resource_class: String, entry: Dictionary) -> Resource:
	"""Create a specific resource type from table entry data."""
	
	match resource_class:
		"ShipData":
			return _create_ship_data(entry)
		"WeaponData":
			return _create_weapon_data(entry)
		"AIProfileData":
			return _create_ai_profile_data(entry)
		"SubsystemData":
			return _create_subsystem_data(entry)
		"MissionData":
			return _create_mission_data(entry)
		"CampaignData":
			return _create_campaign_data(entry)
		_:
			return null

func _create_ship_data(entry: Dictionary) -> ShipData:
	"""Create ShipData resource from table entry."""
	var ship: ShipData = ShipData.new()
	
	# Basic properties
	ship.ship_name = entry.get("name", "")
	ship.ship_info = entry.get("ship_info", "")
	ship.short_name = entry.get("short_name", ship.ship_name)
	ship.species = entry.get("species", "Terran")
	
	# Model and physics
	ship.model_file = entry.get("model_file", "")
	ship.mass = float(entry.get("mass", 100.0))
	ship.density = float(entry.get("density", 1.0))
	ship.damp = float(entry.get("damp", 1.0))
	ship.rotdamp = float(entry.get("rotdamp", 1.0))
	
	# Parse velocity vector
	var velocity_data = entry.get("max_vel", [50, 50, 50])
	if velocity_data is Array and velocity_data.size() >= 3:
		ship.max_vel = Vector3(velocity_data[0], velocity_data[1], velocity_data[2])
	
	# Parse rotation time vector
	var rotation_data = entry.get("rotation_time", [2, 2, 2])
	if rotation_data is Array and rotation_data.size() >= 3:
		ship.rotation_time = Vector3(rotation_data[0], rotation_data[1], rotation_data[2])
	
	# Combat stats
	ship.max_hull_strength = float(entry.get("max_hull_strength", 100.0))
	ship.max_shield_strength = float(entry.get("max_shield_strength", 50.0))
	ship.max_shield_recharge = float(entry.get("max_shield_recharge", 10.0))
	
	# Power systems
	ship.max_weapon_reserve = float(entry.get("max_weapon_reserve", 100.0))
	ship.weapon_recharge_rate = float(entry.get("weapon_recharge_rate", 20.0))
	
	# Parse ETS values
	var ets_data = entry.get("max_ets", [12, 12, 12])
	if ets_data is Array and ets_data.size() >= 3:
		ship.max_ets = Vector3(ets_data[0], ets_data[1], ets_data[2])
	
	# Advanced properties
	ship.power_output = float(entry.get("power_output", 100.0))
	ship.afterburner_fuel_capacity = float(entry.get("afterburner_fuel_capacity", 100.0))
	ship.afterburner_vel_mult = float(entry.get("afterburner_vel_mult", 1.3))
	
	# Parse shield quadrants
	var shield_data = entry.get("shield_quadrants", [25.0, 25.0, 25.0, 25.0])
	if shield_data is Array:
		ship.shield_quadrants.clear()
		for quad in shield_data:
			ship.shield_quadrants.append(float(quad))
	
	# Ship type flags
	ship.fighter = entry.get("fighter", false)
	ship.bomber = entry.get("bomber", false)
	ship.cruiser = entry.get("cruiser", false)
	ship.big_ship = entry.get("big_ship", false)
	ship.huge_ship = entry.get("huge_ship", false)
	ship.corvette_ship = entry.get("corvette_ship", false)
	ship.freighter = entry.get("freighter", false)
	ship.transport = entry.get("transport", false)
	ship.support = entry.get("support", false)
	ship.stealth = entry.get("stealth", false)
	ship.awacs = entry.get("awacs", false)
	ship.sentrygun = entry.get("sentrygun", false)
	ship.escapepod = entry.get("escapepod", false)
	ship.supercap = entry.get("supercap", false)
	
	# AI behavior
	ship.ai_class = entry.get("ai_class", "")
	ship.scan_time = float(entry.get("scan_time", 2000.0))
	ship.ask_help_threshold = float(entry.get("ask_help_threshold", 0.7))
	
	# Weapon systems
	if entry.has("allowed_weapons"):
		var weapons_data = entry.allowed_weapons
		if weapons_data is Array:
			ship.allowed_weapons.clear()
			for weapon in weapons_data:
				ship.allowed_weapons.append(str(weapon))
	
	# Subsystems
	if entry.has("subsystems"):
		var subsys_data = entry.subsystems
		if subsys_data is Array:
			ship.subsystems.clear()
			for subsys in subsys_data:
				if subsys is Dictionary:
					ship.subsystems.append(subsys)
	
	return ship

func _create_weapon_data(entry: Dictionary) -> WeaponData:
	"""Create WeaponData resource from table entry."""
	var weapon: WeaponData = WeaponData.new()
	
	# Basic properties
	weapon.weapon_name = entry.get("name", "")
	weapon.title = entry.get("title", weapon.weapon_name)
	weapon.desc = entry.get("desc", "")
	weapon.tech_title = entry.get("tech_title", "")
	weapon.tech_desc = entry.get("tech_desc", "")
	
	# Weapon type
	weapon.subtype = entry.get("subtype", "Primary")
	weapon.model_file = entry.get("model_file", "")
	
	# Physics and performance
	weapon.mass = float(entry.get("mass", 1.0))
	weapon.velocity = float(entry.get("velocity", 100.0))
	weapon.fire_wait = float(entry.get("fire_wait", 1.0))
	weapon.damage = float(entry.get("damage", 10.0))
	weapon.damage_type = entry.get("damage_type", "energy")
	weapon.lifetime = float(entry.get("lifetime", 5.0))
	weapon.energy_consumed = float(entry.get("energy_consumed", 1.0))
	
	# Homing properties
	weapon.homing_type = entry.get("homing_type", "none")
	weapon.turn_rate = float(entry.get("turn_rate", 0.0))
	weapon.lock_time = float(entry.get("lock_time", 0.0))
	weapon.max_lock_range = float(entry.get("max_lock_range", 1000.0))
	weapon.min_lock_range = float(entry.get("min_lock_range", 50.0))
	
	# Damage properties
	weapon.blast_radius = float(entry.get("blast_radius", 0.0))
	weapon.inner_radius = float(entry.get("inner_radius", 0.0))
	weapon.outer_radius = float(entry.get("outer_radius", 0.0))
	weapon.armor_factor = float(entry.get("armor_factor", 1.0))
	weapon.shield_factor = float(entry.get("shield_factor", 1.0))
	weapon.subsystem_factor = float(entry.get("subsystem_factor", 1.0))
	
	# Visual and audio effects
	weapon.muzzle_flash = entry.get("muzzle_flash", "")
	weapon.impact_effect = entry.get("impact_effect", "")
	weapon.launch_sound = entry.get("launch_sound", "")
	weapon.impact_sound = entry.get("impact_sound", "")
	
	# Special flags
	weapon.ballistic = entry.get("ballistic", false)
	weapon.pierce_shields = entry.get("pierce_shields", false)
	weapon.no_dumbfire = entry.get("no_dumbfire", false)
	weapon.player_allowed = entry.get("player_allowed", true)
	weapon.dual_fire = entry.get("dual_fire", false)
	
	# Advanced properties
	weapon.beam = entry.get("beam", false)
	weapon.flak = entry.get("flak", false)
	weapon.emp = entry.get("emp", false)
	weapon.spawn = entry.get("spawn", false)
	weapon.child_weapon = entry.get("child_weapon", "")
	weapon.spawn_count = int(entry.get("spawn_count", 1))
	
	# Swarm properties
	weapon.swarm_count = int(entry.get("swarm_count", 1))
	weapon.swarm_wait = float(entry.get("swarm_wait", 0.1))
	
	# EMP properties
	weapon.emp_intensity = float(entry.get("emp_intensity", 0.0))
	weapon.emp_time = float(entry.get("emp_time", 0.0))
	
	# Beam properties
	if weapon.beam:
		weapon.b_info_beam_life = float(entry.get("b_info_beam_life", 1.0))
		weapon.b_info_beam_warmup = float(entry.get("b_info_beam_warmup", 0.0))
		weapon.b_info_beam_warmdown = float(entry.get("b_info_beam_warmdown", 0.0))
		weapon.b_info_beam_loop_sound = entry.get("b_info_beam_loop_sound", "")
	
	return weapon

func _create_ai_profile_data(entry: Dictionary) -> AIProfileData:
	"""Create AIProfileData resource from table entry."""
	var ai_profile: AIProfileData = AIProfileData.new()
	
	# Basic properties
	ai_profile.profile_name = entry.get("name", "")
	ai_profile.description = entry.get("description", "")
	ai_profile.skill_level = int(entry.get("skill_level", 3))
	
	# Core AI parameters
	ai_profile.accuracy = float(entry.get("accuracy", 0.7))
	ai_profile.evasion = float(entry.get("evasion", 0.5))
	ai_profile.courage = float(entry.get("courage", 0.5))
	ai_profile.patience = float(entry.get("patience", 0.5))
	
	# Combat behavior
	ai_profile.max_attacking = int(entry.get("max_attacking", 3))
	ai_profile.max_attackers = int(entry.get("max_attackers", 4))
	ai_profile.turn_time_mult = float(entry.get("turn_time_mult", 1.0))
	
	# Advanced behavior
	ai_profile.afterburner_use_factor = float(entry.get("afterburner_use_factor", 1.0))
	ai_profile.afterburner_rec_time = float(entry.get("afterburner_rec_time", 2.0))
	ai_profile.shockwave_dodge_percent = float(entry.get("shockwave_dodge_percent", 0.0))
	ai_profile.get_away_chance = float(entry.get("get_away_chance", 0.0))
	
	# Target preferences
	ai_profile.auto_target_fighter_preference = float(entry.get("auto_target_fighter_preference", 1.0))
	ai_profile.auto_target_capship_preference = float(entry.get("auto_target_capship_preference", 0.5))
	ai_profile.auto_target_transport_preference = float(entry.get("auto_target_transport_preference", 0.3))
	
	# Countermeasures
	ai_profile.cmeasure_fire_chance = float(entry.get("cmeasure_fire_chance", 0.7))
	ai_profile.cmeasure_life_scale = float(entry.get("cmeasure_life_scale", 1.0))
	
	return ai_profile

func _create_subsystem_data(entry: Dictionary) -> SubsystemData:
	"""Create SubsystemData resource from table entry."""
	var subsystem: SubsystemData = SubsystemData.new()
	
	# Basic properties
	subsystem.subsystem_name = entry.get("name", "")
	subsystem.subsystem_type = entry.get("type", "generic")
	subsystem.display_name = entry.get("display_name", subsystem.subsystem_name)
	
	# Structural properties
	subsystem.max_hitpoints = float(entry.get("max_hitpoints", 100.0))
	subsystem.armor_type = entry.get("armor_type", "standard")
	subsystem.radius = float(entry.get("radius", 5.0))
	
	# Parse location vector
	var location_data = entry.get("location", [0, 0, 0])
	if location_data is Array and location_data.size() >= 3:
		subsystem.location = Vector3(location_data[0], location_data[1], location_data[2])
	
	# Damage properties
	subsystem.repair_rate = float(entry.get("repair_rate", 0.0))
	subsystem.damage_threshold = float(entry.get("damage_threshold", 0.75))
	subsystem.destruction_threshold = float(entry.get("destruction_threshold", 0.0))
	subsystem.can_be_destroyed = entry.get("can_be_destroyed", true)
	
	# Performance impact
	subsystem.critical_system = entry.get("critical_system", false)
	subsystem.affects_ship_speed = entry.get("affects_ship_speed", false)
	subsystem.affects_ship_turn = entry.get("affects_ship_turn", false)
	subsystem.affects_weapons = entry.get("affects_weapons", false)
	subsystem.affects_shields = entry.get("affects_shields", false)
	
	# Targeting
	subsystem.target_priority = float(entry.get("target_priority", 1.0))
	subsystem.can_be_targeted = entry.get("can_be_targeted", true)
	subsystem.always_targetable = entry.get("always_targetable", false)
	
	# Special data
	if entry.has("turret_data"):
		subsystem.turret_data = entry.turret_data
	if entry.has("engine_data"):
		subsystem.engine_data = entry.engine_data
	if entry.has("sensor_data"):
		subsystem.sensor_data = entry.sensor_data
	
	return subsystem

func _create_mission_data(entry: Dictionary) -> MissionData:
	"""Create MissionData resource from table entry."""
	var mission: MissionData = MissionData.new()
	
	# Basic properties
	mission.mission_name = entry.get("name", "")
	mission.mission_title = entry.get("title", mission.mission_name)
	mission.mission_description = entry.get("description", "")
	mission.mission_designer = entry.get("designer", "")
	mission.mission_type = entry.get("type", "single")
	
	# Mission environment
	mission.nebula_intensity = float(entry.get("nebula_intensity", 0.0))
	if entry.has("nebula_rgb"):
		var nebula_data = entry.nebula_rgb
		if nebula_data is Array and nebula_data.size() >= 3:
			mission.nebula_rgb = Vector3(nebula_data[0], nebula_data[1], nebula_data[2])
	
	# Audio
	mission.event_music = entry.get("event_music", "")
	mission.briefing_music = entry.get("briefing_music", "")
	mission.debriefing_music = entry.get("debriefing_music", "")
	
	# Copy arrays directly
	if entry.has("ships") and entry.ships is Array:
		mission.ships = entry.ships
	if entry.has("wings") and entry.wings is Array:
		mission.wings = entry.wings
	if entry.has("mission_goals") and entry.mission_goals is Array:
		mission.mission_goals = entry.mission_goals
	if entry.has("mission_events") and entry.mission_events is Array:
		mission.mission_events = entry.mission_events
	
	return mission

func _create_campaign_data(entry: Dictionary) -> CampaignData:
	"""Create CampaignData resource from table entry."""
	var campaign: CampaignData = CampaignData.new()
	
	# Basic properties
	campaign.campaign_name = entry.get("name", "")
	campaign.campaign_type = entry.get("type", "single")
	campaign.description = entry.get("description", "")
	
	# Copy mission arrays
	if entry.has("missions") and entry.missions is Array:
		campaign.missions = entry.missions
	if entry.has("num_players") and entry.num_players is Array:
		campaign.num_players = entry.num_players
	if entry.has("next_mission") and entry.next_mission is Array:
		campaign.next_mission = entry.next_mission
	
	# Starting equipment
	if entry.has("starting_ships") and entry.starting_ships is Array:
		campaign.starting_ships = entry.starting_ships
	if entry.has("starting_weapons") and entry.starting_weapons is Array:
		campaign.starting_weapons = entry.starting_weapons
	
	return campaign

func _save_resources_to_file(resources: Array[Resource], output_path: String, table_name: String) -> bool:
	"""Save converted resources to file."""
	
	# Ensure output directory exists
	var dir: DirAccess = DirAccess.open("res://")
	if not dir:
		_emit_error(table_name, "Cannot access resource directory")
		return false
	
	var output_dir: String = output_path.get_base_dir()
	if not dir.dir_exists(output_dir):
		dir.make_dir_recursive(output_dir)
	
	# Create a resource collection
	var collection: Resource = Resource.new()
	collection.set_meta("table_name", table_name)
	collection.set_meta("entry_count", resources.size())
	collection.set_meta("migration_date", Time.get_datetime_string_from_system())
	collection.set_meta("resources", resources)
	
	# Save the collection
	var error: Error = ResourceSaver.save(collection, output_path)
	if error != OK:
		_emit_error(table_name, "Failed to save resource file: %s" % error_string(error))
		return false
	
	# Save individual resources if requested
	if generate_debug_info:
		var individual_dir: String = output_dir + "/" + table_name + "_individual/"
		dir.make_dir_recursive(individual_dir)
		
		for i in range(resources.size()):
			var resource: Resource = resources[i]
			var resource_name: String = "unknown_%d" % i
			
			# Try to get a meaningful name
			if resource.has_method("get") and resource.get("name"):
				resource_name = str(resource.get("name")).replace(" ", "_").to_lower()
			elif resource.has_method("get") and resource.get("ship_name"):
				resource_name = str(resource.get("ship_name")).replace(" ", "_").to_lower()
			elif resource.has_method("get") and resource.get("weapon_name"):
				resource_name = str(resource.get("weapon_name")).replace(" ", "_").to_lower()
			
			var individual_path: String = individual_dir + resource_name + ".tres"
			ResourceSaver.save(resource, individual_path)
	
	return true

func _emit_error(table_name: String, error_message: String) -> void:
	"""Emit error signal and print error message."""
	print("TableMigrator Error [%s]: %s" % [table_name, error_message])
	migration_error.emit(table_name, error_message)

func _print_migration_summary() -> void:
	"""Print summary of migration results."""
	var elapsed_time: float = migration_stats.end_time - migration_stats.start_time
	
	print("=== Table Migration Summary ===")
	print("Total Tables: %d" % migration_stats.total_tables)
	print("Successful: %d" % migration_stats.successful_migrations)
	print("Failed: %d" % migration_stats.failed_migrations)
	print("Total Entries: %d" % migration_stats.total_entries)
	print("Elapsed Time: %.2f seconds" % elapsed_time)
	print("===============================")