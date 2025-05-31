@tool
class_name ShipConfigurationManager
extends RefCounted

## Ship configuration manager for GFRED2-009 Advanced Ship Configuration.
## Handles ship configuration operations, batch editing, and asset integration.

signal configuration_updated(ship_config: ShipConfigurationData)
signal batch_edit_started(ship_configs: Array[ShipConfigurationData])
signal batch_edit_completed()
signal validation_status_changed(is_valid: bool, errors: Array[String])

# Ship configuration storage
var active_configurations: Dictionary = {}  # ship_id -> ShipConfigurationData
var batch_edit_configs: Array[ShipConfigurationData] = []
var is_batch_editing: bool = false

# Asset system integration
var asset_registry: RegistryManager = null
var ship_class_cache: Dictionary = {}  # ship_class -> ShipData

# Configuration templates
var configuration_templates: Dictionary = {}

## Initializes the ship configuration manager
func _init() -> void:
	_initialize_asset_integration()
	_load_configuration_templates()

## Initializes asset system integration
func _initialize_asset_integration() -> void:
	# Connect to WCS asset system for ship class data
	asset_registry = WCSAssetRegistry  # This is the autoload from WCS Asset Core
	if asset_registry:
		_cache_ship_classes()
	else:
		print("ShipConfigurationManager: WCS Asset system not available")

## Caches ship class data for performance
func _cache_ship_classes() -> void:
	if not asset_registry:
		return
	
	var ship_paths: Array[String] = asset_registry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
	for ship_path in ship_paths:
		var ship_data: ShipData = WCSAssetLoader.load_asset(ship_path)
		if ship_data:
			ship_class_cache[ship_data.ship_class] = ship_data

## Loads configuration templates
func _load_configuration_templates() -> void:
	# Load predefined ship configuration templates
	configuration_templates["fighter"] = _create_fighter_template()
	configuration_templates["bomber"] = _create_bomber_template()
	configuration_templates["capital"] = _create_capital_template()
	configuration_templates["transport"] = _create_transport_template()

## Creates a new ship configuration
func create_ship_configuration(ship_id: String, ship_class: String = "") -> ShipConfigurationData:
	var config: ShipConfigurationData = ShipConfigurationData.new()
	config.ship_name = ship_id
	config.ship_class = ship_class
	
	# Apply ship class defaults if available
	if not ship_class.is_empty() and ship_class_cache.has(ship_class):
		_apply_ship_class_defaults(config, ship_class_cache[ship_class])
	
	active_configurations[ship_id] = config
	config.configuration_changed.connect(_on_configuration_changed.bind(config))
	
	configuration_updated.emit(config)
	return config

## Applies ship class defaults to configuration
func _apply_ship_class_defaults(config: ShipConfigurationData, ship_data: ShipData) -> void:
	# Set basic properties from ship class
	config.initial_hull = ship_data.max_hull_strength
	config.initial_shields = ship_data.max_shield_strength
	
	# Configure weapon slots based on ship class
	config.primary_weapons.clear()
	config.secondary_weapons.clear()
	
	for i in range(ship_data.primary_weapon_slots):
		var weapon_slot: WeaponSlotConfig = WeaponSlotConfig.new()
		weapon_slot.slot_index = i
		config.primary_weapons.append(weapon_slot)
	
	for i in range(ship_data.secondary_weapon_slots):
		var weapon_slot: WeaponSlotConfig = WeaponSlotConfig.new()
		weapon_slot.slot_index = i
		config.secondary_weapons.append(weapon_slot)
	
	# Apply hitpoint configuration
	if config.hitpoint_config:
		config.hitpoint_config.hull_strength = ship_data.max_hull_strength
		config.hitpoint_config.shield_strength = ship_data.max_shield_strength

## Gets ship configuration by ID
func get_ship_configuration(ship_id: String) -> ShipConfigurationData:
	return active_configurations.get(ship_id)

## Updates ship configuration
func update_ship_configuration(ship_id: String, config: ShipConfigurationData) -> void:
	if active_configurations.has(ship_id):
		active_configurations[ship_id] = config
		config.configuration_changed.connect(_on_configuration_changed.bind(config))
		configuration_updated.emit(config)
		_validate_configuration(config)

## Removes ship configuration
func remove_ship_configuration(ship_id: String) -> void:
	if active_configurations.has(ship_id):
		var config: ShipConfigurationData = active_configurations[ship_id]
		if config.configuration_changed.is_connected(_on_configuration_changed):
			config.configuration_changed.disconnect(_on_configuration_changed)
		active_configurations.erase(ship_id)

## Starts batch editing mode for multiple ships
func start_batch_edit(ship_ids: Array[String]) -> void:
	if is_batch_editing:
		print("ShipConfigurationManager: Already in batch edit mode")
		return
	
	batch_edit_configs.clear()
	
	# Create batch configurations
	for ship_id in ship_ids:
		if active_configurations.has(ship_id):
			var config: ShipConfigurationData = active_configurations[ship_id]
			var batch_config: ShipConfigurationData = config.duplicate_for_batch_edit()
			batch_config.ship_name = ship_id  # Keep original ID for reference
			batch_edit_configs.append(batch_config)
	
	if batch_edit_configs.size() > 0:
		is_batch_editing = true
		batch_edit_started.emit(batch_edit_configs)
		print("ShipConfigurationManager: Started batch edit for %d ships" % batch_edit_configs.size())

## Applies batch edit changes to all selected ships
func apply_batch_edit(template_config: ShipConfigurationData, property_mask: Dictionary) -> void:
	if not is_batch_editing:
		print("ShipConfigurationManager: Not in batch edit mode")
		return
	
	for batch_config in batch_edit_configs:
		var ship_id: String = batch_config.ship_name
		var original_config: ShipConfigurationData = active_configurations.get(ship_id)
		
		if original_config:
			# Apply only selected properties from template
			for property_name in property_mask:
				if property_mask[property_name]:
					var value: Variant = template_config.get(property_name)
					original_config.set_property(property_name, value)
			
			_validate_configuration(original_config)

## Ends batch editing mode
func end_batch_edit() -> void:
	if not is_batch_editing:
		return
	
	is_batch_editing = false
	batch_edit_configs.clear()
	batch_edit_completed.emit()
	print("ShipConfigurationManager: Ended batch edit mode")

## Applies configuration template to ship
func apply_template(ship_id: String, template_name: String) -> void:
	if not configuration_templates.has(template_name):
		print("ShipConfigurationManager: Unknown template: %s" % template_name)
		return
	
	var config: ShipConfigurationData = get_ship_configuration(ship_id)
	if not config:
		print("ShipConfigurationManager: Ship not found: %s" % ship_id)
		return
	
	var template: ShipConfigurationData = configuration_templates[template_name]
	_merge_template_configuration(config, template)
	
	configuration_updated.emit(config)
	_validate_configuration(config)

## Merges template configuration into ship configuration
func _merge_template_configuration(config: ShipConfigurationData, template: ShipConfigurationData) -> void:
	# Merge AI behavior
	if template.ai_behavior:
		config.ai_behavior = template.ai_behavior.duplicate()
	
	# Merge weapon loadouts
	if template.weapon_loadouts.size() > 0:
		config.weapon_loadouts = template.weapon_loadouts.duplicate(true)
	
	# Merge ship flags
	if template.ship_flags:
		config.ship_flags = template.ship_flags.duplicate()
	
	# Merge other template properties as needed
	print("ShipConfigurationManager: Applied template configuration")

## Validates ship configuration
func _validate_configuration(config: ShipConfigurationData) -> void:
	var errors: Array[String] = config.validate_configuration()
	
	# Additional validation with asset system
	if asset_registry and not config.ship_class.is_empty():
		if not ship_class_cache.has(config.ship_class):
			errors.append("Invalid ship class: %s" % config.ship_class)
	
	# Validate weapon assignments
	for weapon_slot in config.primary_weapons:
		if not weapon_slot.weapon_class.is_empty():
			if not _is_valid_weapon_class(weapon_slot.weapon_class):
				errors.append("Invalid primary weapon class: %s" % weapon_slot.weapon_class)
	
	for weapon_slot in config.secondary_weapons:
		if not weapon_slot.weapon_class.is_empty():
			if not _is_valid_weapon_class(weapon_slot.weapon_class):
				errors.append("Invalid secondary weapon class: %s" % weapon_slot.weapon_class)
	
	validation_status_changed.emit(errors.is_empty(), errors)

## Checks if weapon class is valid
func _is_valid_weapon_class(weapon_class: String) -> bool:
	if not asset_registry:
		return true  # Skip validation if asset system not available
	
	var weapon_paths: Array[String] = asset_registry.get_asset_paths_by_type(AssetTypes.Type.WEAPON)
	for weapon_path in weapon_paths:
		var weapon_data: WeaponData = WCSAssetLoader.load_asset(weapon_path)
		if weapon_data and weapon_data.weapon_class == weapon_class:
			return true
	
	return false

## Gets available ship classes from asset system
func get_available_ship_classes() -> Array[String]:
	var ship_classes: Array[String] = []
	for ship_class in ship_class_cache:
		ship_classes.append(ship_class)
	return ship_classes

## Gets available weapon classes from asset system
func get_available_weapon_classes(weapon_type: String = "") -> Array[String]:
	var weapon_classes: Array[String] = []
	
	if not asset_registry:
		return weapon_classes
	
	var weapon_paths: Array[String] = asset_registry.get_asset_paths_by_type(AssetTypes.Type.WEAPON)
	for weapon_path in weapon_paths:
		var weapon_data: WeaponData = WCSAssetLoader.load_asset(weapon_path)
		if weapon_data:
			# Filter by weapon type if specified
			if weapon_type.is_empty() or weapon_data.weapon_type == weapon_type:
				weapon_classes.append(weapon_data.weapon_class)
	
	return weapon_classes

## Gets ship configuration export data
func export_ship_configuration(ship_id: String) -> Dictionary:
	var config: ShipConfigurationData = get_ship_configuration(ship_id)
	if not config:
		return {}
	
	var export_data: Dictionary = {}
	export_data["ship_name"] = config.ship_name
	export_data["ship_class"] = config.ship_class
	export_data["team"] = config.team
	export_data["position"] = var_to_str(config.position)
	export_data["orientation"] = var_to_str(config.orientation)
	export_data["initial_hull"] = config.initial_hull
	export_data["initial_shields"] = config.initial_shields
	
	# Export AI behavior
	if config.ai_behavior:
		export_data["ai_behavior"] = {
			"ai_class": config.ai_behavior.ai_class,
			"combat_behavior": config.ai_behavior.combat_behavior,
			"aggressiveness": config.ai_behavior.aggressiveness
		}
	
	# Export weapon loadouts
	var weapons: Array[Dictionary] = []
	for weapon_slot in config.primary_weapons:
		weapons.append({
			"slot_type": "primary",
			"slot_index": weapon_slot.slot_index,
			"weapon_class": weapon_slot.weapon_class,
			"ammunition": weapon_slot.ammunition
		})
	
	for weapon_slot in config.secondary_weapons:
		weapons.append({
			"slot_type": "secondary",
			"slot_index": weapon_slot.slot_index,
			"weapon_class": weapon_slot.weapon_class,
			"ammunition": weapon_slot.ammunition
		})
	
	export_data["weapons"] = weapons
	
	# Export ship flags
	if config.ship_flags:
		export_data["flags"] = {
			"protect_ship": config.ship_flags.protect_ship,
			"escort": config.ship_flags.escort,
			"invulnerable": config.ship_flags.invulnerable,
			"stealth": config.ship_flags.stealth,
			"guardian": config.ship_flags.guardian,
			"kamikaze": config.ship_flags.kamikaze
		}
	
	return export_data

## Signal handlers
func _on_configuration_changed(config: ShipConfigurationData, property_name: String, old_value: Variant, new_value: Variant) -> void:
	# Handle configuration changes
	_validate_configuration(config)
	configuration_updated.emit(config)
	
	print("ShipConfigurationManager: Configuration changed - %s: %s -> %s" % [property_name, str(old_value), str(new_value)])

## Template creation methods

func _create_fighter_template() -> ShipConfigurationData:
	var template: ShipConfigurationData = ShipConfigurationData.new()
	template.ship_name = "Fighter Template"
	
	# Fighter AI behavior
	template.ai_behavior.combat_behavior = "aggressive"
	template.ai_behavior.aggressiveness = 7.0
	template.ai_behavior.accuracy = 6.0
	template.ai_behavior.evasion = 8.0
	
	# Fighter flags
	template.ship_flags.no_dynamic = false
	template.ship_flags.escort = false
	
	return template

func _create_bomber_template() -> ShipConfigurationData:
	var template: ShipConfigurationData = ShipConfigurationData.new()
	template.ship_name = "Bomber Template"
	
	# Bomber AI behavior
	template.ai_behavior.combat_behavior = "defensive"
	template.ai_behavior.aggressiveness = 4.0
	template.ai_behavior.accuracy = 8.0
	template.ai_behavior.evasion = 5.0
	
	# Bomber flags
	template.ship_flags.beam_protect_ship = true
	
	return template

func _create_capital_template() -> ShipConfigurationData:
	var template: ShipConfigurationData = ShipConfigurationData.new()
	template.ship_name = "Capital Ship Template"
	
	# Capital ship AI behavior
	template.ai_behavior.combat_behavior = "static"
	template.ai_behavior.aggressiveness = 3.0
	template.ai_behavior.accuracy = 9.0
	template.ai_behavior.evasion = 2.0
	
	# Capital ship flags
	template.ship_flags.guardian = true
	template.ship_flags.protect_ship = true
	
	return template

func _create_transport_template() -> ShipConfigurationData:
	var template: ShipConfigurationData = ShipConfigurationData.new()
	template.ship_name = "Transport Template"
	
	# Transport AI behavior
	template.ai_behavior.combat_behavior = "evasive"
	template.ai_behavior.aggressiveness = 1.0
	template.ai_behavior.accuracy = 3.0
	template.ai_behavior.evasion = 9.0
	
	# Transport flags
	template.ship_flags.no_dynamic = true
	template.ship_flags.ignore_count = true
	
	return template