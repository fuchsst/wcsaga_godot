class_name ShipSelectionController
extends Control

## Ship selection interface controller for WCS-Godot conversion.
## Manages ship browsing, 3D preview, and weapon loadout configuration.
## Works with ship_selection.tscn scene for UI structure.

signal ship_selection_confirmed(ship_class: String, loadout: Dictionary)
signal ship_selection_cancelled()
signal ship_changed(ship_class: String)
signal loadout_modified(ship_class: String, loadout: Dictionary)

# UI Components (from scene)
@onready var main_container: VBoxContainer = $MainContainer
@onready var selection_title_label: Label = $MainContainer/HeaderContainer/SelectionTitleLabel
@onready var pilot_info_label: Label = $MainContainer/HeaderContainer/PilotInfoLabel

# Ship list components
@onready var ship_search_box: LineEdit = $MainContainer/ContentContainer/LeftPanel/ShipListGroup/ShipListContainer/ShipSearchBox
@onready var ship_list: VBoxContainer = $MainContainer/ContentContainer/LeftPanel/ShipListGroup/ShipListContainer/ShipListScroll/ShipList
@onready var recommendations_list: VBoxContainer = $MainContainer/ContentContainer/LeftPanel/RecommendationsGroup/RecommendationsScroll/RecommendationsList

# Ship preview components
@onready var ship_viewport: SubViewport = $MainContainer/ContentContainer/MiddlePanel/ShipPreviewGroup/PreviewContainer/ShipViewport
@onready var ship_scene: Node3D = $MainContainer/ContentContainer/MiddlePanel/ShipPreviewGroup/PreviewContainer/ShipViewport/ShipScene
@onready var ship_camera: Camera3D = $MainContainer/ContentContainer/MiddlePanel/ShipPreviewGroup/PreviewContainer/ShipViewport/ShipScene/ShipCamera

# Preview controls
@onready var rotate_left_button: Button = $MainContainer/ContentContainer/MiddlePanel/ShipPreviewGroup/PreviewControls/RotateLeftButton
@onready var rotate_right_button: Button = $MainContainer/ContentContainer/MiddlePanel/ShipPreviewGroup/PreviewControls/RotateRightButton
@onready var zoom_slider: HSlider = $MainContainer/ContentContainer/MiddlePanel/ShipPreviewGroup/PreviewControls/ZoomSlider
@onready var reset_view_button: Button = $MainContainer/ContentContainer/MiddlePanel/ShipPreviewGroup/PreviewControls/ResetViewButton

# Ship details
@onready var ship_details_panel: VBoxContainer = $MainContainer/ContentContainer/MiddlePanel/ShipDetailsGroup/DetailsScroll/ShipDetailsPanel

# Weapon loadout components
@onready var primary_weapons_panel: VBoxContainer = $MainContainer/ContentContainer/RightPanel/LoadoutGroup/LoadoutContainer/PrimaryWeaponsGroup/PrimaryWeaponsPanel
@onready var secondary_weapons_panel: VBoxContainer = $MainContainer/ContentContainer/RightPanel/LoadoutGroup/LoadoutContainer/SecondaryWeaponsGroup/SecondaryWeaponsPanel
@onready var validation_panel: VBoxContainer = $MainContainer/ContentContainer/RightPanel/LoadoutValidationGroup/ValidationScroll/ValidationPanel

# Action buttons
@onready var reset_loadout_button: Button = $MainContainer/ActionContainer/ResetLoadoutButton
@onready var back_button: Button = $MainContainer/ActionContainer/ActionButtons/BackButton
@onready var confirm_selection_button: Button = $MainContainer/ActionContainer/ActionButtons/ConfirmSelectionButton

# Data management
var ship_data_manager: ShipSelectionDataManager = null
var current_pilot_data: PlayerProfile = null
var current_mission_data: MissionData = null

# Current state
var available_ships: Array[ShipData] = []
var current_selected_ship: String = ""
var current_ship_model: Node3D = null

# 3D preview control
var camera_rotation: float = 0.0
var camera_distance: float = 100.0
var rotation_speed: float = 90.0  # degrees per second
var ship_rotation_tween: Tween = null

# UI theme manager
var ui_theme_manager: UIThemeManager = null

# Configuration
@export var enable_ship_rotation: bool = true
@export var enable_auto_rotation: bool = false
@export var auto_rotation_speed: float = 30.0
@export var camera_smooth_time: float = 0.5

func _ready() -> void:
	"""Initialize ship selection controller."""
	_setup_dependencies()
	_setup_signal_connections()
	_apply_theme()

func _setup_dependencies() -> void:
	"""Setup required dependencies."""
	# Create data manager
	ship_data_manager = ShipSelectionDataManager.create_ship_selection_data_manager()
	add_child(ship_data_manager)
	
	# Find UI theme manager
	var theme_nodes: Array[Node] = get_tree().get_nodes_in_group("ui_theme_manager")
	if not theme_nodes.is_empty():
		ui_theme_manager = theme_nodes[0] as UIThemeManager

func _setup_signal_connections() -> void:
	"""Setup signal connections with scene nodes."""
	# Data manager signals
	if ship_data_manager:
		ship_data_manager.ship_data_loaded.connect(_on_ship_data_loaded)
		ship_data_manager.loadout_changed.connect(_on_loadout_changed)
		ship_data_manager.loadout_validated.connect(_on_loadout_validated)
		ship_data_manager.pilot_restrictions_updated.connect(_on_pilot_restrictions_updated)
	
	# Ship search
	ship_search_box.text_changed.connect(_on_ship_search_changed)
	
	# Preview controls
	rotate_left_button.pressed.connect(_on_rotate_left_pressed)
	rotate_right_button.pressed.connect(_on_rotate_right_pressed)
	zoom_slider.value_changed.connect(_on_zoom_changed)
	reset_view_button.pressed.connect(_on_reset_view_pressed)
	
	# Action buttons
	reset_loadout_button.pressed.connect(_on_reset_loadout_pressed)
	back_button.pressed.connect(_on_back_pressed)
	confirm_selection_button.pressed.connect(_on_confirm_selection_pressed)

func _apply_theme() -> void:
	"""Apply WCS theme to UI components."""
	if ui_theme_manager:
		ui_theme_manager.apply_wcs_theme_to_node(self)

func _process(delta: float) -> void:
	"""Handle per-frame updates."""
	if enable_auto_rotation and current_ship_model:
		current_ship_model.rotation_degrees.y += auto_rotation_speed * delta

# ============================================================================
# PUBLIC API
# ============================================================================

func show_ship_selection(mission_data: MissionData, pilot_data: PlayerProfile) -> void:
	"""Show ship selection for the specified mission and pilot."""
	if not mission_data or not pilot_data:
		push_error("Missing mission or pilot data")
		return
	
	current_mission_data = mission_data
	current_pilot_data = pilot_data
	
	# Update UI
	_update_pilot_info_display()
	
	# Load ship data
	if ship_data_manager and not ship_data_manager.load_ship_data_for_mission(mission_data, pilot_data):
		push_error("Failed to load ship data for mission")
		return
	
	show()

func get_current_selection() -> Dictionary:
	"""Get current ship and loadout selection."""
	if current_selected_ship.is_empty():
		return {}
	
	return {
		"ship_class": current_selected_ship,
		"loadout": ship_data_manager.get_ship_loadout(current_selected_ship) if ship_data_manager else {}
	}

func set_selected_ship(ship_class: String) -> void:
	"""Set the currently selected ship."""
	if current_selected_ship == ship_class:
		return
	
	current_selected_ship = ship_class
	_update_ship_display()
	_update_ship_preview()
	_update_loadout_display()
	_update_validation_display()
	
	ship_changed.emit(ship_class)

func close_ship_selection() -> void:
	"""Close the ship selection interface."""
	_cleanup_ship_preview()
	hide()

# ============================================================================
# SHIP LIST MANAGEMENT
# ============================================================================

func _update_ship_list_display(ships: Array[ShipData]) -> void:
	"""Update ship list display with ship data."""
	# Clear existing list
	for child in ship_list.get_children():
		child.queue_free()
	
	# Add ship entries
	for ship_data in ships:
		var ship_entry: Control = _create_ship_list_entry(ship_data)
		ship_list.add_child(ship_entry)

func _create_ship_list_entry(ship_data: ShipData) -> Control:
	"""Create a ship list entry control."""
	var entry_container: HBoxContainer = HBoxContainer.new()
	
	# Ship selection button
	var ship_button: Button = Button.new()
	ship_button.text = ship_data.ship_name
	ship_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_button.pressed.connect(_on_ship_selected.bind(ship_data.ship_name))
	entry_container.add_child(ship_button)
	
	# Ship class indicator
	var class_label: Label = Label.new()
	class_label.text = ship_data.short_name if not ship_data.short_name.is_empty() else ship_data.ship_name
	class_label.custom_minimum_size = Vector2(80, 0)
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.add_theme_font_size_override("font_size", 12)
	entry_container.add_child(class_label)
	
	# Availability indicator
	var availability_label: Label = Label.new()
	if _is_ship_available_to_pilot(ship_data):
		availability_label.text = "✓"
		availability_label.modulate = Color.GREEN
	else:
		availability_label.text = "✗"
		availability_label.modulate = Color.RED
		ship_button.disabled = true
	
	availability_label.custom_minimum_size = Vector2(30, 0)
	availability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_container.add_child(availability_label)
	
	return entry_container

func _update_recommendations_display() -> void:
	"""Update ship recommendations display."""
	if not ship_data_manager:
		return
	
	# Clear existing recommendations
	for child in recommendations_list.get_children():
		child.queue_free()
	
	# Get recommendations
	var recommendations: Array[Dictionary] = ship_data_manager.generate_ship_recommendations()
	
	# Add recommendation entries
	for recommendation in recommendations:
		var rec_entry: Control = _create_recommendation_entry(recommendation)
		recommendations_list.add_child(rec_entry)

func _create_recommendation_entry(recommendation: Dictionary) -> Control:
	"""Create a recommendation entry control."""
	var entry_container: VBoxContainer = VBoxContainer.new()
	
	# Header with ship name and stars
	var header_container: HBoxContainer = HBoxContainer.new()
	entry_container.add_child(header_container)
	
	var ship_button: Button = Button.new()
	ship_button.text = recommendation.ship_class
	ship_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_button.pressed.connect(_on_ship_selected.bind(recommendation.ship_class))
	header_container.add_child(ship_button)
	
	var priority_label: Label = Label.new()
	priority_label.text = "★".repeat(recommendation.priority)
	priority_label.modulate = Color.GOLD
	header_container.add_child(priority_label)
	
	# Reason
	var reason_label: Label = Label.new()
	reason_label.text = recommendation.reason
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.add_theme_font_size_override("font_size", 12)
	reason_label.modulate = Color.LIGHT_GRAY
	entry_container.add_child(reason_label)
	
	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	entry_container.add_child(spacer)
	
	return entry_container

func _filter_ship_list(search_text: String) -> void:
	"""Filter ship list based on search text."""
	var filtered_ships: Array[ShipData] = []
	
	if search_text.is_empty():
		filtered_ships = available_ships
	else:
		var search_lower: String = search_text.to_lower()
		for ship_data in available_ships:
			if ship_data.ship_name.to_lower().contains(search_lower) or \
			   ship_data.short_name.to_lower().contains(search_lower) or \
			   ship_data.manufacturer.to_lower().contains(search_lower):
				filtered_ships.append(ship_data)
	
	_update_ship_list_display(filtered_ships)

# ============================================================================
# SHIP PREVIEW MANAGEMENT
# ============================================================================

func _update_ship_preview() -> void:
	"""Update 3D ship preview."""
	if current_selected_ship.is_empty():
		_clear_ship_preview()
		return
	
	# Get ship data
	var ship_data: ShipData = _get_ship_data_by_class(current_selected_ship)
	if not ship_data:
		_clear_ship_preview()
		return
	
	# Load ship model
	_load_ship_model(ship_data)

func _load_ship_model(ship_data: ShipData) -> void:
	"""Load 3D model for ship preview."""
	# Clear existing model
	_clear_ship_preview()
	
	# Create placeholder model (actual POF loading would be implemented later)
	var model_instance: MeshInstance3D = MeshInstance3D.new()
	model_instance.name = "ShipModel"
	
	# Create a basic mesh based on ship type
	var mesh: Mesh = _create_ship_placeholder_mesh(ship_data)
	model_instance.mesh = mesh
	
	# Create material
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color.CYAN
	material.emission_enabled = true
	material.emission = Color.BLUE * 0.2
	model_instance.material_override = material
	
	# Add to scene
	current_ship_model = model_instance
	ship_scene.add_child(current_ship_model)
	
	# Reset camera position
	_reset_camera_view()

func _create_ship_placeholder_mesh(ship_data: ShipData) -> Mesh:
	"""Create placeholder mesh for ship preview."""
	var ship_type: String = _get_ship_type_from_data(ship_data)
	
	match ship_type:
		"bomber":
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(15, 5, 25)
			return box
		"heavy_fighter":
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(12, 4, 20)
			return box
		"interceptor":
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(8, 3, 15)
			return box
		_:  # fighter
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(10, 3, 18)
			return box

func _clear_ship_preview() -> void:
	"""Clear current ship preview."""
	if current_ship_model:
		current_ship_model.queue_free()
		current_ship_model = null

func _cleanup_ship_preview() -> void:
	"""Cleanup ship preview resources."""
	_clear_ship_preview()
	
	if ship_rotation_tween:
		ship_rotation_tween.kill()
		ship_rotation_tween = null

func _reset_camera_view() -> void:
	"""Reset camera to default position."""
	camera_rotation = 0.0
	camera_distance = 100.0
	
	_update_camera_position()
	
	# Reset zoom slider
	zoom_slider.value = 1.0

func _update_camera_position() -> void:
	"""Update camera position based on rotation and distance."""
	var angle_rad: float = deg_to_rad(camera_rotation)
	var x: float = cos(angle_rad) * camera_distance
	var z: float = sin(angle_rad) * camera_distance
	
	ship_camera.position = Vector3(x, 50, z)
	ship_camera.look_at(Vector3.ZERO, Vector3.UP)

# ============================================================================
# SHIP DETAILS DISPLAY
# ============================================================================

func _update_ship_display() -> void:
	"""Update ship details display."""
	if not ship_data_manager or current_selected_ship.is_empty():
		_clear_ship_details()
		return
	
	var specifications: Dictionary = ship_data_manager.get_ship_specifications(current_selected_ship)
	if specifications.is_empty():
		_clear_ship_details()
		return
	
	# Clear existing details
	_clear_ship_details()
	
	# Add ship information
	_add_ship_detail("Name", specifications.get("name", "Unknown"))
	_add_ship_detail("Class", specifications.get("class", "Unknown"))
	_add_ship_detail("Manufacturer", specifications.get("manufacturer", "Unknown"))
	_add_ship_detail("Length", specifications.get("length", "Unknown"))
	
	# Add separator
	_add_ship_detail_separator()
	
	# Add performance specs
	_add_ship_detail("Max Speed", "%.1f m/s" % specifications.get("max_speed", 0.0))
	_add_ship_detail("Afterburner", "%.1f m/s" % specifications.get("afterburner_speed", 0.0))
	_add_ship_detail("Hull Strength", "%.0f" % specifications.get("hull_strength", 0.0))
	_add_ship_detail("Shield Strength", "%.0f" % specifications.get("shield_strength", 0.0))
	
	# Add separator
	_add_ship_detail_separator()
	
	# Add weapon info
	_add_ship_detail("Primary Banks", str(specifications.get("primary_banks", 0)))
	_add_ship_detail("Secondary Banks", str(specifications.get("secondary_banks", 0)))
	_add_ship_detail("Cargo Capacity", str(specifications.get("cargo_capacity", 0)))
	
	# Add description
	if not specifications.get("description", "").is_empty():
		_add_ship_detail_separator()
		_add_ship_description(specifications.description)

func _clear_ship_details() -> void:
	"""Clear ship details display."""
	for child in ship_details_panel.get_children():
		child.queue_free()

func _add_ship_detail(label_text: String, value_text: String) -> void:
	"""Add a ship detail row."""
	var detail_container: HBoxContainer = HBoxContainer.new()
	ship_details_panel.add_child(detail_container)
	
	var label: Label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(100, 0)
	label.add_theme_font_size_override("font_size", 12)
	detail_container.add_child(label)
	
	var value: Label = Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_size_override("font_size", 12)
	value.modulate = Color.LIGHT_GRAY
	detail_container.add_child(value)

func _add_ship_detail_separator() -> void:
	"""Add a separator line."""
	var separator: HSeparator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 5)
	ship_details_panel.add_child(separator)

func _add_ship_description(description: String) -> void:
	"""Add ship description text."""
	var desc_label: RichTextLabel = RichTextLabel.new()
	desc_label.text = description
	desc_label.fit_content = true
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override("normal_font_size", 12)
	ship_details_panel.add_child(desc_label)

# ============================================================================
# WEAPON LOADOUT MANAGEMENT
# ============================================================================

func _update_loadout_display() -> void:
	"""Update weapon loadout display."""
	if not ship_data_manager or current_selected_ship.is_empty():
		_clear_loadout_display()
		return
	
	var bank_info: Dictionary = ship_data_manager.get_weapon_bank_info(current_selected_ship)
	if bank_info.is_empty():
		_clear_loadout_display()
		return
	
	# Update primary weapons
	_update_primary_weapons_display(bank_info.get("primary_banks", []))
	
	# Update secondary weapons
	_update_secondary_weapons_display(bank_info.get("secondary_banks", []))

func _clear_loadout_display() -> void:
	"""Clear weapon loadout display."""
	for child in primary_weapons_panel.get_children():
		child.queue_free()
	for child in secondary_weapons_panel.get_children():
		child.queue_free()

func _update_primary_weapons_display(primary_banks: Array) -> void:
	"""Update primary weapons display."""
	for child in primary_weapons_panel.get_children():
		child.queue_free()
	
	for i in range(primary_banks.size()):
		var bank_data: Dictionary = primary_banks[i]
		var weapon_selector: Control = _create_weapon_selector(i, bank_data, true)
		primary_weapons_panel.add_child(weapon_selector)

func _update_secondary_weapons_display(secondary_banks: Array) -> void:
	"""Update secondary weapons display."""
	for child in secondary_weapons_panel.get_children():
		child.queue_free()
	
	for i in range(secondary_banks.size()):
		var bank_data: Dictionary = secondary_banks[i]
		var weapon_selector: Control = _create_weapon_selector(i, bank_data, false)
		secondary_weapons_panel.add_child(weapon_selector)

func _create_weapon_selector(bank_index: int, bank_data: Dictionary, is_primary: bool) -> Control:
	"""Create weapon selector for a bank."""
	var selector_container: VBoxContainer = VBoxContainer.new()
	
	# Bank header
	var header_label: Label = Label.new()
	header_label.text = "%s Bank %d" % ["Primary" if is_primary else "Secondary", bank_index + 1]
	header_label.add_theme_font_size_override("font_size", 14)
	selector_container.add_child(header_label)
	
	# Weapon dropdown
	var weapon_dropdown: OptionButton = OptionButton.new()
	weapon_dropdown.add_item("(No Weapon)")
	
	var available_weapons: Array = bank_data.get("available_weapons", [])
	for weapon_name in available_weapons:
		weapon_dropdown.add_item(weapon_name)
	
	weapon_dropdown.item_selected.connect(_on_weapon_selected.bind(bank_index, is_primary))
	selector_container.add_child(weapon_dropdown)
	
	return selector_container

func _update_validation_display() -> void:
	"""Update loadout validation display."""
	if not ship_data_manager or current_selected_ship.is_empty():
		_clear_validation_display()
		return
	
	var validation_result: Dictionary = ship_data_manager.validate_ship_loadout(current_selected_ship)
	
	# Clear existing validation
	_clear_validation_display()
	
	# Add validation status
	var status_label: Label = Label.new()
	if validation_result.is_valid:
		status_label.text = "✓ Loadout Valid"
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "✗ Loadout Invalid"
		status_label.modulate = Color.RED
	
	status_label.add_theme_font_size_override("font_size", 14)
	validation_panel.add_child(status_label)
	
	# Add errors
	var errors: Array = validation_result.get("errors", [])
	for error in errors:
		var error_label: Label = Label.new()
		error_label.text = "• " + error
		error_label.modulate = Color.RED
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_label.add_theme_font_size_override("font_size", 12)
		validation_panel.add_child(error_label)
	
	# Add warnings
	var warnings: Array = validation_result.get("warnings", [])
	for warning in warnings:
		var warning_label: Label = Label.new()
		warning_label.text = "• " + warning
		warning_label.modulate = Color.YELLOW
		warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning_label.add_theme_font_size_override("font_size", 12)
		validation_panel.add_child(warning_label)
	
	# Update confirm button state
	confirm_selection_button.disabled = not validation_result.is_valid

func _clear_validation_display() -> void:
	"""Clear validation display."""
	for child in validation_panel.get_children():
		child.queue_free()

# ============================================================================
# HELPER METHODS
# ============================================================================

func _update_pilot_info_display() -> void:
	"""Update pilot information display."""
	if current_pilot_data:
		var pilot_name: String = current_pilot_data.get_pilot_name() if current_pilot_data.has_method("get_pilot_name") else "Unknown Pilot"
		var rank: String = current_pilot_data.get_rank_name() if current_pilot_data.has_method("get_rank_name") else "Pilot"
		pilot_info_label.text = "%s: %s" % [rank, pilot_name]
	else:
		pilot_info_label.text = "Pilot: Unknown"

func _get_ship_data_by_class(ship_class: String) -> ShipData:
	"""Get ship data by class name."""
	for ship_data in available_ships:
		if ship_data.ship_name == ship_class:
			return ship_data
	return null

func _is_ship_available_to_pilot(ship_data: ShipData) -> bool:
	"""Check if ship is available to current pilot."""
	if not ship_data_manager or not current_pilot_data:
		return true
	
	# This would be implemented with proper pilot restriction checking
	return true

func _get_ship_type_from_data(ship_data: ShipData) -> String:
	"""Get ship type classification from ship data."""
	var name: String = ship_data.ship_name.to_upper()
	
	if "BOMBER" in name or "GTB" in name or "GVB" in name:
		return "bomber"
	elif "INTERCEPTOR" in name or "SCOUT" in name:
		return "interceptor"
	elif "HEAVY" in name or "ASSAULT" in name:
		return "heavy_fighter"
	else:
		return "fighter"

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_ship_data_loaded(ships: Array[ShipData]) -> void:
	"""Handle ship data loaded event."""
	available_ships = ships
	_update_ship_list_display(ships)
	_update_recommendations_display()
	
	# Select first ship by default
	if not ships.is_empty():
		set_selected_ship(ships[0].ship_name)

func _on_loadout_changed(ship_class: String, loadout: Dictionary) -> void:
	"""Handle loadout changed event."""
	if ship_class == current_selected_ship:
		_update_loadout_display()
		_update_validation_display()
	
	loadout_modified.emit(ship_class, loadout)

func _on_loadout_validated(ship_class: String, is_valid: bool, errors: Array[String]) -> void:
	"""Handle loadout validation event."""
	if ship_class == current_selected_ship:
		_update_validation_display()

func _on_pilot_restrictions_updated(available_ships_list: Array[String]) -> void:
	"""Handle pilot restrictions updated event."""
	_update_ship_list_display(available_ships)

func _on_ship_search_changed(new_text: String) -> void:
	"""Handle ship search text change."""
	_filter_ship_list(new_text)

func _on_ship_selected(ship_class: String) -> void:
	"""Handle ship selection."""
	set_selected_ship(ship_class)

func _on_rotate_left_pressed() -> void:
	"""Handle rotate left button press."""
	if enable_ship_rotation:
		camera_rotation -= 15.0
		_update_camera_position()

func _on_rotate_right_pressed() -> void:
	"""Handle rotate right button press."""
	if enable_ship_rotation:
		camera_rotation += 15.0
		_update_camera_position()

func _on_zoom_changed(value: float) -> void:
	"""Handle zoom slider change."""
	camera_distance = 100.0 * value
	_update_camera_position()

func _on_reset_view_pressed() -> void:
	"""Handle reset view button press."""
	_reset_camera_view()

func _on_weapon_selected(bank_index: int, is_primary: bool, item_index: int) -> void:
	"""Handle weapon selection for a bank."""
	if not ship_data_manager or current_selected_ship.is_empty():
		return
	
	var current_loadout: Dictionary = ship_data_manager.get_ship_loadout(current_selected_ship)
	if current_loadout.is_empty():
		return
	
	# Get weapon name from selection
	var weapon_name: String = ""
	if item_index > 0:  # Index 0 is "(No Weapon)"
		var bank_info: Dictionary = ship_data_manager.get_weapon_bank_info(current_selected_ship)
		var banks: Array = bank_info.get("primary_banks" if is_primary else "secondary_banks", [])
		if bank_index < banks.size():
			var available_weapons: Array = banks[bank_index].get("available_weapons", [])
			if item_index - 1 < available_weapons.size():
				weapon_name = available_weapons[item_index - 1]
	
	# Update loadout
	var weapons_key: String = "primary_weapons" if is_primary else "secondary_weapons"
	if not current_loadout.has(weapons_key):
		current_loadout[weapons_key] = []
	
	var weapons_array: Array = current_loadout[weapons_key]
	while weapons_array.size() <= bank_index:
		weapons_array.append("")
	
	weapons_array[bank_index] = weapon_name
	
	# Set updated loadout
	ship_data_manager.set_ship_loadout(current_selected_ship, current_loadout)

func _on_reset_loadout_pressed() -> void:
	"""Handle reset loadout button press."""
	if not ship_data_manager or current_selected_ship.is_empty():
		return
	
	# Reset to default loadout
	var ship_data: ShipData = _get_ship_data_by_class(current_selected_ship)
	if ship_data:
		var default_loadout: Dictionary = ship_data_manager._create_default_loadout(ship_data)
		ship_data_manager.set_ship_loadout(current_selected_ship, default_loadout)

func _on_back_pressed() -> void:
	"""Handle back button press."""
	ship_selection_cancelled.emit()
	close_ship_selection()

func _on_confirm_selection_pressed() -> void:
	"""Handle confirm selection button press."""
	if current_selected_ship.is_empty():
		return
	
	var selection: Dictionary = get_current_selection()
	if not selection.is_empty():
		ship_selection_confirmed.emit(selection.ship_class, selection.loadout)
		close_ship_selection()

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_ship_selection_controller() -> ShipSelectionController:
	"""Create a new ship selection controller instance from scene."""
	var scene: PackedScene = preload("res://scenes/menus/ship_selection/ship_selection.tscn")
	var controller: ShipSelectionController = scene.instantiate() as ShipSelectionController
	return controller