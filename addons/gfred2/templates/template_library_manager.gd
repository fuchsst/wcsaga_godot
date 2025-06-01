@tool
class_name TemplateLibraryManager
extends RefCounted

## Mission template library manager for GFRED2 Template and Pattern Library.
## Manages loading, saving, and organizing mission templates and patterns.

signal template_library_changed()
signal pattern_library_changed() 
signal template_created(template: MissionTemplate)
signal pattern_created(pattern: SexpPattern)
signal asset_pattern_created(pattern: AssetPattern)

# Library storage paths
const TEMPLATES_PATH: String = "user://gfred2_templates/"
const PATTERNS_PATH: String = "user://gfred2_patterns/"
const ASSET_PATTERNS_PATH: String = "user://gfred2_asset_patterns/"
const COMMUNITY_PATH: String = "user://gfred2_community/"

# Library collections
var mission_templates: Dictionary = {}
var sexp_patterns: Dictionary = {}
var asset_patterns: Dictionary = {}

# Community templates
var community_templates: Dictionary = {}
var community_patterns: Dictionary = {}
var community_asset_patterns: Dictionary = {}

# Cache for performance
var template_categories: Dictionary = {}
var pattern_categories: Dictionary = {}
var asset_pattern_categories: Dictionary = {}

func _init() -> void:
	_ensure_directories_exist()
	_initialize_default_libraries()

## Ensures all required directories exist
func _ensure_directories_exist() -> void:
	var directories: Array[String] = [
		TEMPLATES_PATH,
		PATTERNS_PATH, 
		ASSET_PATTERNS_PATH,
		COMMUNITY_PATH,
		COMMUNITY_PATH + "templates/",
		COMMUNITY_PATH + "patterns/",
		COMMUNITY_PATH + "asset_patterns/"
	]
	
	for dir_path in directories:
		if not DirAccess.dir_exists_absolute(dir_path):
			var error: Error = DirAccess.open("user://").make_dir_recursive(dir_path.replace("user://", ""))
			if error != OK:
				push_error("Failed to create directory: %s (Error: %d)" % [dir_path, error])

## Initializes default template and pattern libraries
func _initialize_default_libraries() -> void:
	print("TemplateLibraryManager: Initializing default libraries...")
	
	# Load existing templates and patterns
	load_all_templates()
	load_all_patterns()
	load_all_asset_patterns()
	
	# Create default templates if none exist
	if mission_templates.is_empty():
		_create_default_mission_templates()
	
	# Create default SEXP patterns if none exist
	if sexp_patterns.is_empty():
		_create_default_sexp_patterns()
	
	# Create default asset patterns if none exist
	if asset_patterns.is_empty():
		_create_default_asset_patterns()
	
	print("TemplateLibraryManager: Initialized with %d templates, %d SEXP patterns, %d asset patterns" % [
		mission_templates.size(), sexp_patterns.size(), asset_patterns.size()
	])

## Creates default mission templates for common scenarios
func _create_default_mission_templates() -> void:
	print("Creating default mission templates...")
	
	# Escort Mission Template
	var escort_template: MissionTemplate = MissionTemplate.new()
	escort_template.template_name = "Standard Escort Mission"
	escort_template.template_type = MissionTemplate.TemplateType.ESCORT
	escort_template.description = "Escort convoy ships through dangerous space"
	escort_template.category = "Combat"
	escort_template.difficulty = MissionTemplate.Difficulty.MEDIUM
	escort_template.estimated_duration_minutes = 20
	escort_template.tags = ["escort", "convoy", "combat"]
	escort_template.parameters = {
		"convoy_ship_count": 3,
		"escort_distance": 1000.0,
		"enemy_wing_count": 2,
		"mission_title": "Convoy Escort",
		"difficulty_multiplier": 1.0
	}
	escort_template.template_mission_data = _create_escort_mission_data()
	add_mission_template(escort_template)
	
	# Patrol Mission Template
	var patrol_template: MissionTemplate = MissionTemplate.new()
	patrol_template.template_name = "Standard Patrol Mission"
	patrol_template.template_type = MissionTemplate.TemplateType.PATROL
	patrol_template.description = "Patrol designated area and investigate contacts"
	patrol_template.category = "Reconnaissance"
	patrol_template.difficulty = MissionTemplate.Difficulty.EASY
	patrol_template.estimated_duration_minutes = 15
	patrol_template.tags = ["patrol", "reconnaissance", "investigation"]
	patrol_template.parameters = {
		"patrol_waypoint_count": 5,
		"patrol_area_size": 10000.0,
		"contact_probability": 0.7,
		"mission_title": "Sector Patrol"
	}
	patrol_template.template_mission_data = _create_patrol_mission_data()
	add_mission_template(patrol_template)
	
	# Assault Mission Template
	var assault_template: MissionTemplate = MissionTemplate.new()
	assault_template.template_name = "Capital Ship Assault"
	assault_template.template_type = MissionTemplate.TemplateType.ASSAULT
	assault_template.description = "Assault heavily defended capital ship"
	assault_template.category = "Combat"
	assault_template.difficulty = MissionTemplate.Difficulty.HARD
	assault_template.estimated_duration_minutes = 25
	assault_template.tags = ["assault", "capital", "heavy-combat"]
	assault_template.parameters = {
		"target_ship_class": "Destroyer",
		"enemy_wing_count": 4,
		"support_ship_allowed": true,
		"mission_title": "Capital Assault"
	}
	assault_template.template_mission_data = _create_assault_mission_data()
	add_mission_template(assault_template)
	
	# Defense Mission Template
	var defense_template: MissionTemplate = MissionTemplate.new()
	defense_template.template_name = "Base Defense"
	defense_template.template_type = MissionTemplate.TemplateType.DEFENSE
	defense_template.description = "Defend friendly installation from enemy attack"
	defense_template.category = "Defense"
	defense_template.difficulty = MissionTemplate.Difficulty.MEDIUM
	defense_template.estimated_duration_minutes = 18
	defense_template.tags = ["defense", "waves", "installation"]
	defense_template.parameters = {
		"defense_target": "Station",
		"attack_wave_count": 3,
		"wave_interval": 120,
		"mission_title": "Station Defense"
	}
	defense_template.template_mission_data = _create_defense_mission_data()
	add_mission_template(defense_template)
	
	# Training Mission Template
	var training_template: MissionTemplate = MissionTemplate.new()
	training_template.template_name = "Basic Flight Training"
	training_template.template_type = MissionTemplate.TemplateType.TRAINING
	training_template.description = "Basic flight controls and combat training"
	training_template.category = "Training"
	training_template.difficulty = MissionTemplate.Difficulty.EASY
	training_template.estimated_duration_minutes = 10
	training_template.tags = ["training", "tutorial", "basic"]
	training_template.parameters = {
		"exercise_count": 5,
		"instructor_messages": true,
		"failure_tolerance": true,
		"mission_title": "Flight Training"
	}
	training_template.template_mission_data = _create_training_mission_data()
	add_mission_template(training_template)

## Creates basic mission data for escort template
func _create_escort_mission_data() -> MissionData:
	var mission: MissionData = MissionData.new()
	mission.title = "Convoy Escort"
	mission.description = "Escort the convoy ships to their destination"
	mission.mission_type = MissionData.MissionType.SINGLE_PLAYER
	
	# Create basic convoy ship
	var convoy_ship: MissionObject = MissionObject.new()
	convoy_ship.id = "convoy_1"
	convoy_ship.name = "Convoy 1"
	convoy_ship.type = MissionObject.Type.SHIP
	convoy_ship.team = 1
	mission.add_object(convoy_ship)
	
	# Create basic escort wing
	var escort_wing: MissionObject = MissionObject.new()
	escort_wing.id = "escort_wing"
	escort_wing.name = "Alpha Wing"
	escort_wing.type = MissionObject.Type.WING
	escort_wing.team = 1
	mission.add_object(escort_wing)
	
	# Create primary goal
	var goal: MissionGoal = MissionGoal.new()
	goal.goal_name = "Protect Convoy"
	goal.description = "Ensure convoy ships reach their destination"
	goal.type = MissionGoal.Type.PRIMARY
	mission.add_goal(goal)
	
	return mission

## Creates basic mission data for patrol template
func _create_patrol_mission_data() -> MissionData:
	var mission: MissionData = MissionData.new()
	mission.title = "Sector Patrol"
	mission.description = "Patrol the designated sector and investigate contacts"
	mission.mission_type = MissionData.MissionType.SINGLE_PLAYER
	
	# Create patrol wing
	var patrol_wing: MissionObject = MissionObject.new()
	patrol_wing.id = "patrol_wing"
	patrol_wing.name = "Alpha Wing"
	patrol_wing.type = MissionObject.Type.WING
	patrol_wing.team = 1
	mission.add_object(patrol_wing)
	
	# Create patrol waypoints
	for i in 5:
		var waypoint: MissionObject = MissionObject.new()
		waypoint.id = "patrol_wp_" + str(i + 1)
		waypoint.name = "Patrol " + str(i + 1)
		waypoint.type = MissionObject.Type.WAYPOINT
		mission.add_object(waypoint)
	
	# Create goal
	var goal: MissionGoal = MissionGoal.new()
	goal.goal_name = "Complete Patrol"
	goal.description = "Visit all patrol waypoints"
	goal.type = MissionGoal.Type.PRIMARY
	mission.add_goal(goal)
	
	return mission

## Creates basic mission data for assault template
func _create_assault_mission_data() -> MissionData:
	var mission: MissionData = MissionData.new()
	mission.title = "Capital Assault"
	mission.description = "Destroy the enemy capital ship"
	mission.mission_type = MissionData.MissionType.SINGLE_PLAYER
	
	# Create assault wing
	var assault_wing: MissionObject = MissionObject.new()
	assault_wing.id = "assault_wing"
	assault_wing.name = "Alpha Wing"
	assault_wing.type = MissionObject.Type.WING
	assault_wing.team = 1
	mission.add_object(assault_wing)
	
	# Create target capital ship
	var target_ship: MissionObject = MissionObject.new()
	target_ship.id = "target_capital"
	target_ship.name = "Enemy Destroyer"
	target_ship.type = MissionObject.Type.SHIP
	target_ship.team = 2
	mission.add_object(target_ship)
	
	# Create goal
	var goal: MissionGoal = MissionGoal.new()
	goal.goal_name = "Destroy Target"
	goal.description = "Destroy the enemy capital ship"
	goal.type = MissionGoal.Type.PRIMARY
	mission.add_goal(goal)
	
	return mission

## Creates basic mission data for defense template
func _create_defense_mission_data() -> MissionData:
	var mission: MissionData = MissionData.new()
	mission.title = "Station Defense"
	mission.description = "Defend the station from enemy attack waves"
	mission.mission_type = MissionData.MissionType.SINGLE_PLAYER
	
	# Create defense wing
	var defense_wing: MissionObject = MissionObject.new()
	defense_wing.id = "defense_wing"
	defense_wing.name = "Alpha Wing"
	defense_wing.type = MissionObject.Type.WING
	defense_wing.team = 1
	mission.add_object(defense_wing)
	
	# Create station to defend
	var station: MissionObject = MissionObject.new()
	station.id = "defense_station"
	station.name = "Allied Station"
	station.type = MissionObject.Type.SHIP
	station.team = 1
	mission.add_object(station)
	
	# Create goal
	var goal: MissionGoal = MissionGoal.new()
	goal.goal_name = "Defend Station"
	goal.description = "Prevent the station from being destroyed"
	goal.type = MissionGoal.Type.PRIMARY
	mission.add_goal(goal)
	
	return mission

## Creates basic mission data for training template
func _create_training_mission_data() -> MissionData:
	var mission: MissionData = MissionData.new()
	mission.title = "Flight Training"
	mission.description = "Complete basic flight training exercises"
	mission.mission_type = MissionData.MissionType.TRAINING
	mission.is_training = true
	
	# Create training ship
	var training_ship: MissionObject = MissionObject.new()
	training_ship.id = "training_ship"
	training_ship.name = "Training Ship"
	training_ship.type = MissionObject.Type.SHIP
	training_ship.team = 1
	mission.add_object(training_ship)
	
	# Create training waypoints
	for i in 3:
		var waypoint: MissionObject = MissionObject.new()
		waypoint.id = "training_wp_" + str(i + 1)
		waypoint.name = "Exercise " + str(i + 1)
		waypoint.type = MissionObject.Type.WAYPOINT
		mission.add_object(waypoint)
	
	# Create goal
	var goal: MissionGoal = MissionGoal.new()
	goal.goal_name = "Complete Training"
	goal.description = "Complete all training exercises"
	goal.type = MissionGoal.Type.PRIMARY
	mission.add_goal(goal)
	
	return mission

## Creates default SEXP patterns
func _create_default_sexp_patterns() -> void:
	print("Creating default SEXP patterns...")
	
	# Add pre-created patterns
	add_sexp_pattern(SexpPattern.create_escort_trigger_pattern())
	add_sexp_pattern(SexpPattern.create_patrol_waypoint_pattern())
	add_sexp_pattern(SexpPattern.create_objective_complete_pattern())
	add_sexp_pattern(SexpPattern.create_difficulty_scaling_pattern())
	add_sexp_pattern(SexpPattern.create_timer_event_pattern())
	
	# Create additional common patterns
	var wave_trigger: SexpPattern = SexpPattern.new()
	wave_trigger.pattern_name = "Attack Wave Trigger"
	wave_trigger.category = SexpPattern.PatternCategory.TRIGGER
	wave_trigger.description = "Triggers next attack wave when previous wave is defeated"
	wave_trigger.sexp_expression = "(when (< (num-ships-in-wing \"{previous_wave}\") 1) (ship-create \"{next_wave}\"))"
	wave_trigger.parameter_placeholders = {
		"previous_wave": {"type": "string", "default": "Wave 1", "description": "Previous wave name"},
		"next_wave": {"type": "string", "default": "Wave 2", "description": "Next wave to spawn"}
	}
	wave_trigger.required_functions = ["num-ships-in-wing", "ship-create"]
	wave_trigger.tags = ["waves", "spawning", "sequential"]
	add_sexp_pattern(wave_trigger)

## Creates default asset patterns
func _create_default_asset_patterns() -> void:
	print("Creating default asset patterns...")
	
	# Add pre-created patterns
	add_asset_pattern(AssetPattern.create_interceptor_pattern())
	add_asset_pattern(AssetPattern.create_bomber_pattern())
	add_asset_pattern(AssetPattern.create_escort_wing_pattern())
	
	# Create additional patterns
	var support_pattern: AssetPattern = AssetPattern.new()
	support_pattern.pattern_name = "Support Ship Package"
	support_pattern.pattern_type = AssetPattern.PatternType.SUPPORT_PACKAGE
	support_pattern.tactical_role = AssetPattern.TacticalRole.SUPPORT
	support_pattern.description = "Standard support ship with repair capabilities"
	support_pattern.ship_class = "Omega"
	support_pattern.tags = ["support", "repair", "logistics"]
	add_asset_pattern(support_pattern)

## Template Management Functions

## Adds a mission template to the library
func add_mission_template(template: MissionTemplate) -> bool:
	if template.template_id.is_empty():
		push_error("Template ID cannot be empty")
		return false
	
	mission_templates[template.template_id] = template
	_update_template_categories()
	
	# Save to disk
	save_mission_template(template)
	
	template_created.emit(template)
	template_library_changed.emit()
	return true

## Gets a mission template by ID
func get_mission_template(template_id: String) -> MissionTemplate:
	return mission_templates.get(template_id, null)

## Gets all mission templates
func get_all_mission_templates() -> Array[MissionTemplate]:
	var templates: Array[MissionTemplate] = []
	for template in mission_templates.values():
		templates.append(template)
	return templates

## Gets mission templates by type
func get_mission_templates_by_type(template_type: MissionTemplate.TemplateType) -> Array[MissionTemplate]:
	var filtered: Array[MissionTemplate] = []
	for template in mission_templates.values():
		if template.template_type == template_type:
			filtered.append(template)
	return filtered

## Gets mission templates by category
func get_mission_templates_by_category(category: String) -> Array[MissionTemplate]:
	return template_categories.get(category, [])

## Removes a mission template
func remove_mission_template(template_id: String) -> bool:
	if not mission_templates.has(template_id):
		return false
	
	var template: MissionTemplate = mission_templates[template_id]
	mission_templates.erase(template_id)
	_update_template_categories()
	
	# Remove from disk
	var file_path: String = TEMPLATES_PATH + template_id + ".tres"
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	
	template_library_changed.emit()
	return true

## SEXP Pattern Management Functions

## Adds a SEXP pattern to the library
func add_sexp_pattern(pattern: SexpPattern) -> bool:
	if pattern.pattern_id.is_empty():
		push_error("Pattern ID cannot be empty")
		return false
	
	sexp_patterns[pattern.pattern_id] = pattern
	_update_pattern_categories()
	
	# Save to disk
	save_sexp_pattern(pattern)
	
	pattern_created.emit(pattern)
	pattern_library_changed.emit()
	return true

## Gets a SEXP pattern by ID
func get_sexp_pattern(pattern_id: String) -> SexpPattern:
	return sexp_patterns.get(pattern_id, null)

## Gets all SEXP patterns
func get_all_sexp_patterns() -> Array[SexpPattern]:
	var patterns: Array[SexpPattern] = []
	for pattern in sexp_patterns.values():
		patterns.append(pattern)
	return patterns

## Gets SEXP patterns by category
func get_sexp_patterns_by_category(category: SexpPattern.PatternCategory) -> Array[SexpPattern]:
	var filtered: Array[SexpPattern] = []
	for pattern in sexp_patterns.values():
		if pattern.category == category:
			filtered.append(pattern)
	return filtered

## Asset Pattern Management Functions

## Adds an asset pattern to the library
func add_asset_pattern(pattern: AssetPattern) -> bool:
	if pattern.pattern_id.is_empty():
		push_error("Pattern ID cannot be empty")
		return false
	
	asset_patterns[pattern.pattern_id] = pattern
	_update_asset_pattern_categories()
	
	# Save to disk
	save_asset_pattern(pattern)
	
	asset_pattern_created.emit(pattern)
	pattern_library_changed.emit()
	return true

## Gets an asset pattern by ID
func get_asset_pattern(pattern_id: String) -> AssetPattern:
	return asset_patterns.get(pattern_id, null)

## Gets all asset patterns
func get_all_asset_patterns() -> Array[AssetPattern]:
	var patterns: Array[AssetPattern] = []
	for pattern in asset_patterns.values():
		patterns.append(pattern)
	return patterns

## Gets asset patterns by type
func get_asset_patterns_by_type(pattern_type: AssetPattern.PatternType) -> Array[AssetPattern]:
	var filtered: Array[AssetPattern] = []
	for pattern in asset_patterns.values():
		if pattern.pattern_type == pattern_type:
			filtered.append(pattern)
	return filtered

## Storage and Loading Functions

## Saves a mission template to disk
func save_mission_template(template: MissionTemplate) -> Error:
	var file_path: String = TEMPLATES_PATH + template.template_id + ".tres"
	return ResourceSaver.save(template, file_path)

## Loads all mission templates from disk
func load_all_templates() -> void:
	var dir: DirAccess = DirAccess.open(TEMPLATES_PATH)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var template: MissionTemplate = load(TEMPLATES_PATH + file_name) as MissionTemplate
			if template:
				mission_templates[template.template_id] = template
		file_name = dir.get_next()
	
	_update_template_categories()

## Saves a SEXP pattern to disk
func save_sexp_pattern(pattern: SexpPattern) -> Error:
	var file_path: String = PATTERNS_PATH + pattern.pattern_id + ".tres"
	return ResourceSaver.save(pattern, file_path)

## Loads all SEXP patterns from disk
func load_all_patterns() -> void:
	var dir: DirAccess = DirAccess.open(PATTERNS_PATH)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var pattern: SexpPattern = load(PATTERNS_PATH + file_name) as SexpPattern
			if pattern:
				sexp_patterns[pattern.pattern_id] = pattern
		file_name = dir.get_next()
	
	_update_pattern_categories()

## Saves an asset pattern to disk
func save_asset_pattern(pattern: AssetPattern) -> Error:
	var file_path: String = ASSET_PATTERNS_PATH + pattern.pattern_id + ".tres"
	return ResourceSaver.save(pattern, file_path)

## Loads all asset patterns from disk
func load_all_asset_patterns() -> void:
	var dir: DirAccess = DirAccess.open(ASSET_PATTERNS_PATH)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var pattern: AssetPattern = load(ASSET_PATTERNS_PATH + file_name) as AssetPattern
			if pattern:
				asset_patterns[pattern.pattern_id] = pattern
		file_name = dir.get_next()
	
	_update_asset_pattern_categories()

## Updates template category cache
func _update_template_categories() -> void:
	template_categories.clear()
	for template in mission_templates.values():
		var category: String = template.category
		if not template_categories.has(category):
			template_categories[category] = []
		template_categories[category].append(template)

## Updates pattern category cache
func _update_pattern_categories() -> void:
	pattern_categories.clear()
	for pattern in sexp_patterns.values():
		var category: SexpPattern.PatternCategory = pattern.category
		if not pattern_categories.has(category):
			pattern_categories[category] = []
		pattern_categories[category].append(pattern)

## Updates asset pattern category cache
func _update_asset_pattern_categories() -> void:
	asset_pattern_categories.clear()
	for pattern in asset_patterns.values():
		var pattern_type: AssetPattern.PatternType = pattern.pattern_type
		if not asset_pattern_categories.has(pattern_type):
			asset_pattern_categories[pattern_type] = []
		asset_pattern_categories[pattern_type].append(pattern)

## Community Features

## Exports template for community sharing
func export_template_for_community(template_id: String, export_path: String) -> Error:
	var template: MissionTemplate = get_mission_template(template_id)
	if not template:
		return ERR_DOES_NOT_EXIST
	
	var export_data: Dictionary = template.export_template()
	var json: JSON = JSON.new()
	var json_string: String = json.stringify(export_data, "\t")
	
	var file: FileAccess = FileAccess.open(export_path, FileAccess.WRITE)
	if not file:
		return ERR_FILE_CANT_WRITE
	
	file.store_string(json_string)
	file.close()
	return OK

## Imports template from community sharing
func import_template_from_community(import_path: String) -> MissionTemplate:
	var file: FileAccess = FileAccess.open(import_path, FileAccess.READ)
	if not file:
		return null
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		return null
	
	var template_data: Dictionary = json.data
	var template: MissionTemplate = MissionTemplate.import_template(template_data)
	
	# Add to community templates
	community_templates[template.template_id] = template
	return template

## Gets library statistics
func get_library_statistics() -> Dictionary:
	return {
		"mission_templates": mission_templates.size(),
		"sexp_patterns": sexp_patterns.size(),
		"asset_patterns": asset_patterns.size(),
		"community_templates": community_templates.size(),
		"community_patterns": community_patterns.size(),
		"template_categories": template_categories.size(),
		"pattern_categories": pattern_categories.size()
	}