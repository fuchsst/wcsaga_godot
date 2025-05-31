@tool
class_name WeaponLoadoutsController
extends Control

## Weapon loadouts controller for GFRED2-009 Advanced Ship Configuration.
## Scene-based UI controller for managing ship weapon configurations.
## Scene: addons/gfred2/scenes/dialogs/ship_editor/weapon_loadouts_panel.tscn
## Integrates with WCS Asset Core weapon data structures.

signal weapon_config_updated(slot_type: String, slot_index: int, weapon_config: WeaponSlotConfig)
signal weapon_slot_cleared(slot_type: String, slot_index: int)
signal loadout_template_applied(template_name: String)
signal validation_status_changed(is_valid: bool, errors: Array[String])

# Current weapon configurations
var primary_weapons: Array[WeaponSlotConfig] = []
var secondary_weapons: Array[WeaponSlotConfig] = []
var current_ship_class: String = ""
var current_ship_data: ShipData = null

# Asset system integration
var asset_registry: RegistryManager = null
var available_primary_weapons: Dictionary = {}  # weapon_class -> WeaponData
var available_secondary_weapons: Dictionary = {}  # weapon_class -> WeaponData

# Scene node references (populated by .tscn file)
@onready var primary_weapons_tree: Tree = $VBoxContainer/PrimaryWeapons/WeaponsTree
@onready var add_primary_button: Button = $VBoxContainer/PrimaryWeapons/AddPrimaryButton
@onready var remove_primary_button: Button = $VBoxContainer/PrimaryWeapons/RemovePrimaryButton
@onready var clear_primary_button: Button = $VBoxContainer/PrimaryWeapons/ClearPrimaryButton

@onready var secondary_weapons_tree: Tree = $VBoxContainer/SecondaryWeapons/WeaponsTree
@onready var add_secondary_button: Button = $VBoxContainer/SecondaryWeapons/AddSecondaryButton
@onready var remove_secondary_button: Button = $VBoxContainer/SecondaryWeapons/RemoveSecondaryButton
@onready var clear_secondary_button: Button = $VBoxContainer/SecondaryWeapons/ClearSecondaryButton

@onready var weapon_selector_dialog: AcceptDialog = $WeaponSelectorDialog
@onready var weapon_list: ItemList = $WeaponSelectorDialog/VBoxContainer/WeaponList
@onready var weapon_info_label: RichTextLabel = $WeaponSelectorDialog/VBoxContainer/WeaponInfoLabel
@onready var ammunition_spin: SpinBox = $WeaponSelectorDialog/VBoxContainer/AmmunitionContainer/AmmunitionSpin
@onready var dual_fire_check: CheckBox = $WeaponSelectorDialog/VBoxContainer/OptionsContainer/DualFireCheck
@onready var locked_check: CheckBox = $WeaponSelectorDialog/VBoxContainer/OptionsContainer/LockedCheck

@onready var loadout_template_option: OptionButton = $VBoxContainer/LoadoutTemplates/TemplateOption
@onready var apply_template_button: Button = $VBoxContainer/LoadoutTemplates/ApplyTemplateButton
@onready var save_template_button: Button = $VBoxContainer/LoadoutTemplates/SaveTemplateButton

# Weapon selection state
var current_selection_type: String = ""  # "primary" or "secondary"
var current_selection_slot: int = -1
var editing_existing_slot: bool = false

# Validation state
var is_valid: bool = true
var validation_errors: Array[String] = []

# Weapon loadout templates
var loadout_templates: Dictionary = {
	"Fighter Standard": {
		"primary": ["Subach HL-7", "Prometheus R"],
		"secondary": ["Rockeye", "Tempest"]
	},
	"Bomber Heavy": {
		"primary": ["Prometheus R", "Maxim"],
		"secondary": ["Tsunami", "Stiletto II", "Hornet"]
	},
	"Interceptor": {
		"primary": ["Subach HL-7", "Avenger"],
		"secondary": ["Tempest", "Harpoon"]
	},
	"Escort": {
		"primary": ["Prometheus R", "Kayser"],
		"secondary": ["Stiletto II", "Trebuchet"]
	}
}

func _ready() -> void:
	name = "WeaponLoadoutsController"
	
	# Initialize asset system integration
	asset_registry = WCSAssetRegistry
	
	# Load weapon data from asset system
	_load_weapon_data()
	
	# Setup weapon trees
	_setup_weapon_trees()
	
	# Setup loadout templates
	_populate_loadout_templates()
	
	# Connect UI signals
	_connect_ui_signals()
	
	print("WeaponLoadoutsController: Controller initialized with WCS Asset Core integration")

## Updates the panel with weapon configurations
func update_with_weapon_config(primary_config: Array[WeaponSlotConfig], secondary_config: Array[WeaponSlotConfig]) -> void:
	primary_weapons = primary_config.duplicate()
	secondary_weapons = secondary_config.duplicate()
	
	# Update weapon trees
	_populate_primary_weapons_tree()
	_populate_secondary_weapons_tree()
	
	# Validate weapon configurations
	_validate_weapon_configurations()

## Updates ship class context for weapon validation
func update_ship_class_context(ship_class: String, ship_data: ShipData) -> void:
	current_ship_class = ship_class
	current_ship_data = ship_data
	
	# Revalidate weapons with new ship context
	_validate_weapon_configurations()

## Loads weapon data from WCS Asset Core
func _load_weapon_data() -> void:
	if not asset_registry:
		print("WeaponLoadoutsController: Asset registry not available")
		return
	
	# Load primary weapons
	var primary_weapon_paths: Array[String] = asset_registry.get_asset_paths_by_type(AssetTypes.Type.PRIMARY_WEAPON)
	for weapon_path in primary_weapon_paths:
		var weapon_data: WeaponData = WCSAssetLoader.load_asset(weapon_path)
		if weapon_data and weapon_data.is_primary_weapon():
			available_primary_weapons[weapon_data.weapon_class] = weapon_data
	
	# Load secondary weapons
	var secondary_weapon_paths: Array[String] = asset_registry.get_asset_paths_by_type(AssetTypes.Type.SECONDARY_WEAPON)
	for weapon_path in secondary_weapon_paths:
		var weapon_data: WeaponData = WCSAssetLoader.load_asset(weapon_path)
		if weapon_data and weapon_data.is_secondary_weapon():
			available_secondary_weapons[weapon_data.weapon_class] = weapon_data
	
	print("WeaponLoadoutsController: Loaded %d primary and %d secondary weapons" % [
		available_primary_weapons.size(), available_secondary_weapons.size()
	])

## Sets up weapon tree columns and headers
func _setup_weapon_trees() -> void:
	# Primary weapons tree
	primary_weapons_tree.columns = 5
	primary_weapons_tree.set_column_title(0, "Slot")
	primary_weapons_tree.set_column_title(1, "Weapon")
	primary_weapons_tree.set_column_title(2, "Ammo")
	primary_weapons_tree.set_column_title(3, "Dual Fire")
	primary_weapons_tree.set_column_title(4, "Locked")
	
	primary_weapons_tree.set_column_expand(0, false)
	primary_weapons_tree.set_column_expand(1, true)
	primary_weapons_tree.set_column_expand(2, false)
	primary_weapons_tree.set_column_expand(3, false)
	primary_weapons_tree.set_column_expand(4, false)
	
	# Secondary weapons tree
	secondary_weapons_tree.columns = 5
	secondary_weapons_tree.set_column_title(0, "Slot")
	secondary_weapons_tree.set_column_title(1, "Weapon")
	secondary_weapons_tree.set_column_title(2, "Ammo")
	secondary_weapons_tree.set_column_title(3, "Dual Fire")
	secondary_weapons_tree.set_column_title(4, "Locked")
	
	secondary_weapons_tree.set_column_expand(0, false)
	secondary_weapons_tree.set_column_expand(1, true)
	secondary_weapons_tree.set_column_expand(2, false)
	secondary_weapons_tree.set_column_expand(3, false)
	secondary_weapons_tree.set_column_expand(4, false)

## Populates primary weapons tree
func _populate_primary_weapons_tree() -> void:
	primary_weapons_tree.clear()
	
	var root: TreeItem = primary_weapons_tree.create_item()
	
	for i in range(primary_weapons.size()):
		var weapon_slot: WeaponSlotConfig = primary_weapons[i]
		var item: TreeItem = primary_weapons_tree.create_item(root)
		
		item.set_text(0, str(i + 1))
		item.set_text(1, weapon_slot.weapon_class if not weapon_slot.weapon_class.is_empty() else "(Empty)")
		item.set_text(2, str(weapon_slot.ammunition) if weapon_slot.ammunition > 0 else "Unlimited")
		item.set_text(3, "Yes" if weapon_slot.is_dual_fire else "No")
		item.set_text(4, "Yes" if weapon_slot.is_locked else "No")
		
		item.set_metadata(0, i)  # Store slot index
		
		# Color coding for different states
		if weapon_slot.weapon_class.is_empty():
			item.set_custom_color(1, Color.GRAY)
		elif weapon_slot.is_locked:
			item.set_custom_color(4, Color.ORANGE)

## Populates secondary weapons tree
func _populate_secondary_weapons_tree() -> void:
	secondary_weapons_tree.clear()
	
	var root: TreeItem = secondary_weapons_tree.create_item()
	
	for i in range(secondary_weapons.size()):
		var weapon_slot: WeaponSlotConfig = secondary_weapons[i]
		var item: TreeItem = secondary_weapons_tree.create_item(root)
		
		item.set_text(0, str(i + 1))
		item.set_text(1, weapon_slot.weapon_class if not weapon_slot.weapon_class.is_empty() else "(Empty)")
		item.set_text(2, str(weapon_slot.ammunition) if weapon_slot.ammunition > 0 else "Unlimited")
		item.set_text(3, "Yes" if weapon_slot.is_dual_fire else "No")
		item.set_text(4, "Yes" if weapon_slot.is_locked else "No")
		
		item.set_metadata(0, i)  # Store slot index
		
		# Color coding for different states
		if weapon_slot.weapon_class.is_empty():
			item.set_custom_color(1, Color.GRAY)
		elif weapon_slot.is_locked:
			item.set_custom_color(4, Color.ORANGE)

## Populates loadout template options
func _populate_loadout_templates() -> void:
	loadout_template_option.clear()
	loadout_template_option.add_item("(Select Template)", 0)
	
	var template_names: Array = loadout_templates.keys()
	template_names.sort()
	
	for i in range(template_names.size()):
		loadout_template_option.add_item(template_names[i], i + 1)

## Connects all UI signal handlers
func _connect_ui_signals() -> void:
	# Primary weapons signals
	add_primary_button.pressed.connect(_on_add_primary_pressed)
	remove_primary_button.pressed.connect(_on_remove_primary_pressed)
	clear_primary_button.pressed.connect(_on_clear_primary_pressed)
	primary_weapons_tree.item_selected.connect(_on_primary_weapon_selected)
	primary_weapons_tree.item_activated.connect(_on_primary_weapon_activated)
	
	# Secondary weapons signals
	add_secondary_button.pressed.connect(_on_add_secondary_pressed)
	remove_secondary_button.pressed.connect(_on_remove_secondary_pressed)
	clear_secondary_button.pressed.connect(_on_clear_secondary_pressed)
	secondary_weapons_tree.item_selected.connect(_on_secondary_weapon_selected)
	secondary_weapons_tree.item_activated.connect(_on_secondary_weapon_activated)
	
	# Template signals
	apply_template_button.pressed.connect(_on_apply_template_pressed)
	save_template_button.pressed.connect(_on_save_template_pressed)
	
	# Weapon selector dialog signals
	weapon_list.item_selected.connect(_on_weapon_list_selected)
	weapon_selector_dialog.confirmed.connect(_on_weapon_selector_confirmed)

## Validates weapon configurations
func _validate_weapon_configurations() -> void:
	validation_errors.clear()
	
	# Validate primary weapons
	for i in range(primary_weapons.size()):
		var weapon_slot: WeaponSlotConfig = primary_weapons[i]
		if not weapon_slot.weapon_class.is_empty():
			_validate_weapon_slot("Primary", i + 1, weapon_slot)
	
	# Validate secondary weapons
	for i in range(secondary_weapons.size()):
		var weapon_slot: WeaponSlotConfig = secondary_weapons[i]
		if not weapon_slot.weapon_class.is_empty():
			_validate_weapon_slot("Secondary", i + 1, weapon_slot)
	
	# Check ship class compatibility if ship data is available
	if current_ship_data:
		if primary_weapons.size() > current_ship_data.primary_weapon_slots:
			validation_errors.append("Too many primary weapon slots for ship class '%s' (max: %d)" % [
				current_ship_class, current_ship_data.primary_weapon_slots
			])
		
		if secondary_weapons.size() > current_ship_data.secondary_weapon_slots:
			validation_errors.append("Too many secondary weapon slots for ship class '%s' (max: %d)" % [
				current_ship_class, current_ship_data.secondary_weapon_slots
			])
	
	is_valid = validation_errors.is_empty()
	validation_status_changed.emit(is_valid, validation_errors)

## Validates individual weapon slot
func _validate_weapon_slot(slot_type: String, slot_number: int, weapon_slot: WeaponSlotConfig) -> void:
	var weapon_data: WeaponData = null
	
	# Get weapon data based on type
	if slot_type == "Primary":
		weapon_data = available_primary_weapons.get(weapon_slot.weapon_class)
	else:
		weapon_data = available_secondary_weapons.get(weapon_slot.weapon_class)
	
	if not weapon_data:
		validation_errors.append("%s Slot %d: Unknown weapon class '%s'" % [
			slot_type, slot_number, weapon_slot.weapon_class
		])
		return
	
	# Validate ammunition
	if weapon_slot.ammunition < 0:
		validation_errors.append("%s Slot %d: Ammunition cannot be negative" % [slot_type, slot_number])
	
	# Validate weapon type compatibility
	if slot_type == "Primary" and weapon_data.is_secondary_weapon():
		validation_errors.append("%s Slot %d: '%s' is not a primary weapon" % [
			slot_type, slot_number, weapon_slot.weapon_class
		])
	elif slot_type == "Secondary" and weapon_data.is_primary_weapon():
		validation_errors.append("%s Slot %d: '%s' is not a secondary weapon" % [
			slot_type, slot_number, weapon_slot.weapon_class
		])

## Shows weapon selector dialog
func _show_weapon_selector(weapon_type: String, slot_index: int, existing_config: WeaponSlotConfig = null) -> void:
	current_selection_type = weapon_type
	current_selection_slot = slot_index
	editing_existing_slot = existing_config != null
	
	# Populate weapon list based on type
	weapon_list.clear()
	var weapons: Dictionary = available_primary_weapons if weapon_type == "primary" else available_secondary_weapons
	
	var weapon_names: Array = weapons.keys()
	weapon_names.sort()
	
	for weapon_name in weapon_names:
		weapon_list.add_item(weapon_name)
	
	# Set existing configuration if editing
	if existing_config:
		ammunition_spin.value = existing_config.ammunition
		dual_fire_check.button_pressed = existing_config.is_dual_fire
		locked_check.button_pressed = existing_config.is_locked
		
		# Select current weapon in list
		for i in range(weapon_list.get_item_count()):
			if weapon_list.get_item_text(i) == existing_config.weapon_class:
				weapon_list.select(i)
				_on_weapon_list_selected(i)
				break
	else:
		ammunition_spin.value = 0
		dual_fire_check.button_pressed = false
		locked_check.button_pressed = false
		weapon_info_label.text = "Select a weapon to view details"
	
	weapon_selector_dialog.title = "Select %s Weapon - Slot %d" % [weapon_type.capitalize(), slot_index + 1]
	weapon_selector_dialog.popup_centered(Vector2i(600, 500))

## Signal handlers

func _on_add_primary_pressed() -> void:
	# Find next available slot or add new slot
	var slot_index: int = primary_weapons.size()
	
	# Check ship weapon slot limits
	if current_ship_data and slot_index >= current_ship_data.primary_weapon_slots:
		print("WeaponLoadoutsController: Cannot add more primary weapons (max: %d)" % current_ship_data.primary_weapon_slots)
		return
	
	_show_weapon_selector("primary", slot_index)

func _on_remove_primary_pressed() -> void:
	var selected: TreeItem = primary_weapons_tree.get_selected()
	if not selected:
		return
	
	var slot_index: int = selected.get_metadata(0)
	if slot_index >= 0 and slot_index < primary_weapons.size():
		primary_weapons.remove_at(slot_index)
		_populate_primary_weapons_tree()
		weapon_slot_cleared.emit("primary", slot_index)

func _on_clear_primary_pressed() -> void:
	primary_weapons.clear()
	_populate_primary_weapons_tree()
	for i in range(10):  # Clear up to 10 slots
		weapon_slot_cleared.emit("primary", i)

func _on_add_secondary_pressed() -> void:
	var slot_index: int = secondary_weapons.size()
	
	# Check ship weapon slot limits
	if current_ship_data and slot_index >= current_ship_data.secondary_weapon_slots:
		print("WeaponLoadoutsController: Cannot add more secondary weapons (max: %d)" % current_ship_data.secondary_weapon_slots)
		return
	
	_show_weapon_selector("secondary", slot_index)

func _on_remove_secondary_pressed() -> void:
	var selected: TreeItem = secondary_weapons_tree.get_selected()
	if not selected:
		return
	
	var slot_index: int = selected.get_metadata(0)
	if slot_index >= 0 and slot_index < secondary_weapons.size():
		secondary_weapons.remove_at(slot_index)
		_populate_secondary_weapons_tree()
		weapon_slot_cleared.emit("secondary", slot_index)

func _on_clear_secondary_pressed() -> void:
	secondary_weapons.clear()
	_populate_secondary_weapons_tree()
	for i in range(10):  # Clear up to 10 slots
		weapon_slot_cleared.emit("secondary", i)

func _on_primary_weapon_selected() -> void:
	remove_primary_button.disabled = primary_weapons_tree.get_selected() == null

func _on_primary_weapon_activated() -> void:
	var selected: TreeItem = primary_weapons_tree.get_selected()
	if not selected:
		return
	
	var slot_index: int = selected.get_metadata(0)
	if slot_index >= 0 and slot_index < primary_weapons.size():
		_show_weapon_selector("primary", slot_index, primary_weapons[slot_index])

func _on_secondary_weapon_selected() -> void:
	remove_secondary_button.disabled = secondary_weapons_tree.get_selected() == null

func _on_secondary_weapon_activated() -> void:
	var selected: TreeItem = secondary_weapons_tree.get_selected()
	if not selected:
		return
	
	var slot_index: int = selected.get_metadata(0)
	if slot_index >= 0 and slot_index < secondary_weapons.size():
		_show_weapon_selector("secondary", slot_index, secondary_weapons[slot_index])

func _on_weapon_list_selected(index: int) -> void:
	var weapon_name: String = weapon_list.get_item_text(index)
	var weapons: Dictionary = available_primary_weapons if current_selection_type == "primary" else available_secondary_weapons
	var weapon_data: WeaponData = weapons.get(weapon_name)
	
	if weapon_data:
		# Display weapon information
		var info_text: String = "[b]%s[/b]\n\n" % weapon_data.weapon_name
		info_text += "Damage: %.1f\n" % weapon_data.damage
		info_text += "Speed: %.1f\n" % weapon_data.max_speed
		info_text += "Range: %.1f\n" % weapon_data.get_range_effectiveness()
		info_text += "DPS: %.1f\n" % weapon_data.get_dps()
		info_text += "Fire Rate: %.2fs\n" % weapon_data.fire_wait
		
		if weapon_data.is_homing_weapon():
			info_text += "Homing: Yes\n"
			info_text += "Tracking: %.2f\n" % weapon_data.get_tracking_ability()
		
		if weapon_data.energy_consumed > 0:
			info_text += "Energy: %.1f\n" % weapon_data.energy_consumed
		
		weapon_info_label.text = info_text

func _on_weapon_selector_confirmed() -> void:
	if weapon_list.get_selected_items().is_empty():
		return
	
	var selected_index: int = weapon_list.get_selected_items()[0]
	var weapon_name: String = weapon_list.get_item_text(selected_index)
	
	# Create weapon slot configuration
	var weapon_config: WeaponSlotConfig = WeaponSlotConfig.new()
	weapon_config.slot_index = current_selection_slot
	weapon_config.weapon_class = weapon_name
	weapon_config.ammunition = int(ammunition_spin.value)
	weapon_config.is_dual_fire = dual_fire_check.button_pressed
	weapon_config.is_locked = locked_check.button_pressed
	
	# Update weapon arrays
	if current_selection_type == "primary":
		if editing_existing_slot and current_selection_slot < primary_weapons.size():
			primary_weapons[current_selection_slot] = weapon_config
		else:
			while primary_weapons.size() <= current_selection_slot:
				primary_weapons.append(WeaponSlotConfig.new())
			primary_weapons[current_selection_slot] = weapon_config
		
		_populate_primary_weapons_tree()
	else:
		if editing_existing_slot and current_selection_slot < secondary_weapons.size():
			secondary_weapons[current_selection_slot] = weapon_config
		else:
			while secondary_weapons.size() <= current_selection_slot:
				secondary_weapons.append(WeaponSlotConfig.new())
			secondary_weapons[current_selection_slot] = weapon_config
		
		_populate_secondary_weapons_tree()
	
	weapon_config_updated.emit(current_selection_type, current_selection_slot, weapon_config)
	_validate_weapon_configurations()

func _on_apply_template_pressed() -> void:
	var selected_index: int = loadout_template_option.selected
	if selected_index <= 0:
		return
	
	var template_name: String = loadout_template_option.get_item_text(selected_index)
	var template: Dictionary = loadout_templates.get(template_name, {})
	
	if template.is_empty():
		return
	
	# Apply primary weapons from template
	if template.has("primary"):
		primary_weapons.clear()
		var primary_list: Array = template["primary"]
		for i in range(primary_list.size()):
			var weapon_class: String = primary_list[i]
			if available_primary_weapons.has(weapon_class):
				var weapon_config: WeaponSlotConfig = WeaponSlotConfig.new()
				weapon_config.slot_index = i
				weapon_config.weapon_class = weapon_class
				weapon_config.ammunition = 0  # Unlimited by default
				primary_weapons.append(weapon_config)
	
	# Apply secondary weapons from template
	if template.has("secondary"):
		secondary_weapons.clear()
		var secondary_list: Array = template["secondary"]
		for i in range(secondary_list.size()):
			var weapon_class: String = secondary_list[i]
			if available_secondary_weapons.has(weapon_class):
				var weapon_config: WeaponSlotConfig = WeaponSlotConfig.new()
				weapon_config.slot_index = i
				weapon_config.weapon_class = weapon_class
				weapon_config.ammunition = 100  # Default ammo for missiles
				secondary_weapons.append(weapon_config)
	
	# Update UI
	_populate_primary_weapons_tree()
	_populate_secondary_weapons_tree()
	_validate_weapon_configurations()
	
	loadout_template_applied.emit(template_name)
	print("WeaponLoadoutsController: Applied loadout template: %s" % template_name)

func _on_save_template_pressed() -> void:
	# TODO: Implement custom template saving functionality
	print("WeaponLoadoutsController: Save template functionality not yet implemented")

## Public API

## Gets current primary weapon configurations
func get_primary_weapons() -> Array[WeaponSlotConfig]:
	return primary_weapons.duplicate()

## Gets current secondary weapon configurations
func get_secondary_weapons() -> Array[WeaponSlotConfig]:
	return secondary_weapons.duplicate()

## Checks if weapon configuration is valid
func is_weapon_config_valid() -> bool:
	return is_valid

## Gets validation errors
func get_validation_errors() -> Array[String]:
	return validation_errors.duplicate()

## Clears all weapon configurations
func clear_all_weapons() -> void:
	primary_weapons.clear()
	secondary_weapons.clear()
	_populate_primary_weapons_tree()
	_populate_secondary_weapons_tree()
	_validate_weapon_configurations()

## Gets weapon loadout summary
func get_loadout_summary() -> Dictionary:
	var summary: Dictionary = {}
	
	summary["primary_count"] = primary_weapons.size()
	summary["secondary_count"] = secondary_weapons.size()
	summary["total_weapons"] = primary_weapons.size() + secondary_weapons.size()
	
	# Calculate total DPS from primary weapons
	var total_dps: float = 0.0
	for weapon_slot in primary_weapons:
		if not weapon_slot.weapon_class.is_empty():
			var weapon_data: WeaponData = available_primary_weapons.get(weapon_slot.weapon_class)
			if weapon_data:
				total_dps += weapon_data.get_dps()
	
	summary["primary_dps"] = total_dps
	
	# Calculate total ammunition
	var total_ammunition: int = 0
	for weapon_slot in secondary_weapons:
		if weapon_slot.ammunition > 0:
			total_ammunition += weapon_slot.ammunition
	
	summary["secondary_ammunition"] = total_ammunition
	
	return summary