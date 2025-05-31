@tool
class_name ReinforcementEditorPanel
extends Control

## Reinforcement management system for GFRED2-010 Mission Component Editors.
## Scene-based UI controller for configuring mission reinforcements.
## Scene: addons/gfred2/scenes/dialogs/component_editors/reinforcement_editor_panel.tscn

signal component_updated(reinforcement_data: ReinforcementData)
signal validation_changed(is_valid: bool, errors: Array[String])
signal reinforcement_selected(reinforcement_id: String)

# Current mission and reinforcement data
var current_mission_data: MissionData = null
var reinforcement_list: Array[ReinforcementData] = []

# Scene node references
@onready var reinforcement_tree: Tree = $VBoxContainer/ReinforcementList/ReinforcementTree
@onready var add_reinforcement_button: Button = $VBoxContainer/ReinforcementList/ButtonContainer/AddButton
@onready var remove_reinforcement_button: Button = $VBoxContainer/ReinforcementList/ButtonContainer/RemoveButton
@onready var duplicate_reinforcement_button: Button = $VBoxContainer/ReinforcementList/ButtonContainer/DuplicateButton

@onready var properties_container: VBoxContainer = $VBoxContainer/PropertiesContainer
@onready var reinforcement_name_edit: LineEdit = $VBoxContainer/PropertiesContainer/NameContainer/NameEdit
@onready var wave_count_spin: SpinBox = $VBoxContainer/PropertiesContainer/WaveContainer/WaveCountSpin
@onready var arrival_delay_spin: SpinBox = $VBoxContainer/PropertiesContainer/ArrivalContainer/ArrivalDelaySpin
@onready var arrival_cue_edit: SexpPropertyEditor = $VBoxContainer/PropertiesContainer/ArrivalCueContainer/ArrivalCueEdit

@onready var ship_selection_container: VBoxContainer = $VBoxContainer/PropertiesContainer/ShipSelectionContainer
@onready var ship_class_option: OptionButton = $VBoxContainer/PropertiesContainer/ShipSelectionContainer/ShipClassOption
@onready var ship_count_spin: SpinBox = $VBoxContainer/PropertiesContainer/ShipSelectionContainer/ShipCountSpin
@onready var priority_spin: SpinBox = $VBoxContainer/PropertiesContainer/PriorityContainer/PrioritySpin

# Current selected reinforcement
var selected_reinforcement: ReinforcementData = null

func _ready() -> void:
	name = "ReinforcementEditorPanel"
	
	# Setup UI components
	_setup_reinforcement_tree()
	_setup_property_editors()
	_setup_ship_selection()
	_connect_signals()
	
	# Initialize empty state
	_update_properties_display()
	
	print("ReinforcementEditorPanel: Reinforcement editor initialized")

## Initializes the editor with mission data
func initialize_with_mission(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	current_mission_data = mission_data
	
	# Load existing reinforcements from mission data
	if mission_data.has_method("get_reinforcements"):
		reinforcement_list = mission_data.get_reinforcements()
	else:
		reinforcement_list = []
	
	# Populate reinforcement tree
	_populate_reinforcement_tree()
	
	# Update ship class options
	_update_ship_class_options()
	
	print("ReinforcementEditorPanel: Initialized with %d reinforcements" % reinforcement_list.size())

## Sets up the reinforcement tree
func _setup_reinforcement_tree() -> void:
	if not reinforcement_tree:
		return
	
	reinforcement_tree.columns = 4
	reinforcement_tree.set_column_title(0, "Name")
	reinforcement_tree.set_column_title(1, "Ships")
	reinforcement_tree.set_column_title(2, "Waves")
	reinforcement_tree.set_column_title(3, "Priority")
	
	reinforcement_tree.set_column_expand(0, true)
	reinforcement_tree.set_column_expand(1, false)
	reinforcement_tree.set_column_expand(2, false)
	reinforcement_tree.set_column_expand(3, false)
	
	reinforcement_tree.item_selected.connect(_on_reinforcement_selected)

func _setup_property_editors() -> void:
	# Setup numeric inputs
	if wave_count_spin:
		wave_count_spin.min_value = 1
		wave_count_spin.max_value = 99
		wave_count_spin.value_changed.connect(_on_wave_count_changed)
	
	if arrival_delay_spin:
		arrival_delay_spin.min_value = 0.0
		arrival_delay_spin.max_value = 3600.0  # 1 hour max
		arrival_delay_spin.step = 1.0
		arrival_delay_spin.suffix = "s"
		arrival_delay_spin.value_changed.connect(_on_arrival_delay_changed)
	
	if ship_count_spin:
		ship_count_spin.min_value = 1
		ship_count_spin.max_value = 20
		ship_count_spin.value_changed.connect(_on_ship_count_changed)
	
	if priority_spin:
		priority_spin.min_value = 1
		priority_spin.max_value = 100
		priority_spin.value_changed.connect(_on_priority_changed)
	
	# Setup text inputs
	if reinforcement_name_edit:
		reinforcement_name_edit.text_changed.connect(_on_name_changed)
	
	# Setup SEXP editor
	if arrival_cue_edit:
		arrival_cue_edit.sexp_changed.connect(_on_arrival_cue_changed)

func _setup_ship_selection() -> void:
	if not ship_class_option:
		return
	
	# This will be populated when mission data is available
	ship_class_option.item_selected.connect(_on_ship_class_selected)

func _connect_signals() -> void:
	if add_reinforcement_button:
		add_reinforcement_button.pressed.connect(_on_add_reinforcement_pressed)
	
	if remove_reinforcement_button:
		remove_reinforcement_button.pressed.connect(_on_remove_reinforcement_pressed)
	
	if duplicate_reinforcement_button:
		duplicate_reinforcement_button.pressed.connect(_on_duplicate_reinforcement_pressed)

## Populates the reinforcement tree with current data
func _populate_reinforcement_tree() -> void:
	if not reinforcement_tree:
		return
	
	reinforcement_tree.clear()
	var root: TreeItem = reinforcement_tree.create_item()
	
	for i in range(reinforcement_list.size()):
		var reinforcement: ReinforcementData = reinforcement_list[i]
		var item: TreeItem = reinforcement_tree.create_item(root)
		
		item.set_text(0, reinforcement.reinforcement_name)
		item.set_text(1, str(reinforcement.ship_count))
		item.set_text(2, str(reinforcement.wave_count))
		item.set_text(3, str(reinforcement.priority))
		item.set_metadata(0, i)  # Store index for selection

func _update_ship_class_options() -> void:
	if not ship_class_option or not current_mission_data:
		return
	
	ship_class_option.clear()
	
	# Get available ship classes from WCS Asset Core
	var asset_registry: RegistryManager = WCSAssetRegistry
	if asset_registry and asset_registry.has_method("get_ship_classes"):
		var ship_classes: Array = asset_registry.get_ship_classes()
		for ship_class in ship_classes:
			ship_class_option.add_item(ship_class)
	else:
		# Fallback ship classes for testing
		ship_class_option.add_item("GTF Ulysses")
		ship_class_option.add_item("GTF Hercules")
		ship_class_option.add_item("GTB Medusa")
		ship_class_option.add_item("GTC Fenris")

func _update_properties_display() -> void:
	var has_selection: bool = selected_reinforcement != null
	
	# Enable/disable property controls
	properties_container.modulate = Color.WHITE if has_selection else Color(0.5, 0.5, 0.5)
	
	if not has_selection:
		# Clear all inputs when no selection
		if reinforcement_name_edit:
			reinforcement_name_edit.text = ""
		if wave_count_spin:
			wave_count_spin.value = 1
		if arrival_delay_spin:
			arrival_delay_spin.value = 0.0
		if ship_count_spin:
			ship_count_spin.value = 1
		if priority_spin:
			priority_spin.value = 1
		if ship_class_option:
			ship_class_option.selected = -1
		return
	
	# Update inputs with selected reinforcement data
	if reinforcement_name_edit:
		reinforcement_name_edit.text = selected_reinforcement.reinforcement_name
	
	if wave_count_spin:
		wave_count_spin.value = selected_reinforcement.wave_count
	
	if arrival_delay_spin:
		arrival_delay_spin.value = selected_reinforcement.arrival_delay
	
	if ship_count_spin:
		ship_count_spin.value = selected_reinforcement.ship_count
	
	if priority_spin:
		priority_spin.value = selected_reinforcement.priority
	
	if ship_class_option:
		# Find and select the appropriate ship class
		for i in range(ship_class_option.get_item_count()):
			if ship_class_option.get_item_text(i) == selected_reinforcement.ship_class:
				ship_class_option.selected = i
				break
	
	if arrival_cue_edit and selected_reinforcement.arrival_cue:
		arrival_cue_edit.set_sexp_node(selected_reinforcement.arrival_cue)

## Signal handlers

func _on_reinforcement_selected() -> void:
	var selected_item: TreeItem = reinforcement_tree.get_selected()
	if not selected_item:
		selected_reinforcement = null
		_update_properties_display()
		return
	
	var reinforcement_index: int = selected_item.get_metadata(0)
	if reinforcement_index >= 0 and reinforcement_index < reinforcement_list.size():
		selected_reinforcement = reinforcement_list[reinforcement_index]
		_update_properties_display()
		reinforcement_selected.emit(selected_reinforcement.reinforcement_id if selected_reinforcement else "")

func _on_add_reinforcement_pressed() -> void:
	var new_reinforcement: ReinforcementData = ReinforcementData.new()
	new_reinforcement.reinforcement_name = "New Reinforcement %d" % (reinforcement_list.size() + 1)
	new_reinforcement.reinforcement_id = "reinforce_%d" % (reinforcement_list.size() + 1)
	new_reinforcement.ship_class = "GTF Ulysses"
	new_reinforcement.ship_count = 4
	new_reinforcement.wave_count = 1
	new_reinforcement.priority = 50
	new_reinforcement.arrival_delay = 30.0
	
	reinforcement_list.append(new_reinforcement)
	_populate_reinforcement_tree()
	
	# Select the new reinforcement
	var root: TreeItem = reinforcement_tree.get_root()
	if root:
		var last_item: TreeItem = root.get_child(reinforcement_list.size() - 1)
		if last_item:
			last_item.select(0)
			_on_reinforcement_selected()
	
	component_updated.emit(new_reinforcement)

func _on_remove_reinforcement_pressed() -> void:
	if not selected_reinforcement:
		return
	
	var selected_item: TreeItem = reinforcement_tree.get_selected()
	if not selected_item:
		return
	
	var reinforcement_index: int = selected_item.get_metadata(0)
	if reinforcement_index >= 0 and reinforcement_index < reinforcement_list.size():
		reinforcement_list.remove_at(reinforcement_index)
		selected_reinforcement = null
		_populate_reinforcement_tree()
		_update_properties_display()

func _on_duplicate_reinforcement_pressed() -> void:
	if not selected_reinforcement:
		return
	
	var duplicated: ReinforcementData = selected_reinforcement.duplicate()
	duplicated.reinforcement_name += " Copy"
	duplicated.reinforcement_id += "_copy"
	
	reinforcement_list.append(duplicated)
	_populate_reinforcement_tree()
	
	component_updated.emit(duplicated)

func _on_name_changed(new_text: String) -> void:
	if selected_reinforcement:
		selected_reinforcement.reinforcement_name = new_text
		_populate_reinforcement_tree()  # Refresh display
		component_updated.emit(selected_reinforcement)

func _on_wave_count_changed(value: float) -> void:
	if selected_reinforcement:
		selected_reinforcement.wave_count = int(value)
		_populate_reinforcement_tree()
		component_updated.emit(selected_reinforcement)

func _on_arrival_delay_changed(value: float) -> void:
	if selected_reinforcement:
		selected_reinforcement.arrival_delay = value
		component_updated.emit(selected_reinforcement)

func _on_ship_count_changed(value: float) -> void:
	if selected_reinforcement:
		selected_reinforcement.ship_count = int(value)
		_populate_reinforcement_tree()
		component_updated.emit(selected_reinforcement)

func _on_priority_changed(value: float) -> void:
	if selected_reinforcement:
		selected_reinforcement.priority = int(value)
		_populate_reinforcement_tree()
		component_updated.emit(selected_reinforcement)

func _on_ship_class_selected(index: int) -> void:
	if selected_reinforcement and ship_class_option:
		selected_reinforcement.ship_class = ship_class_option.get_item_text(index)
		component_updated.emit(selected_reinforcement)

func _on_arrival_cue_changed(sexp_node: SexpNode) -> void:
	if selected_reinforcement:
		selected_reinforcement.arrival_cue = sexp_node
		component_updated.emit(selected_reinforcement)

## Validation and export methods

func validate_component() -> Dictionary:
	var errors: Array[String] = []
	
	# Validate each reinforcement
	for i in range(reinforcement_list.size()):
		var reinforcement: ReinforcementData = reinforcement_list[i]
		
		if reinforcement.reinforcement_name.is_empty():
			errors.append("Reinforcement %d: Name cannot be empty" % (i + 1))
		
		if reinforcement.ship_class.is_empty():
			errors.append("Reinforcement %d: Ship class must be selected" % (i + 1))
		
		if reinforcement.ship_count <= 0:
			errors.append("Reinforcement %d: Ship count must be greater than 0" % (i + 1))
		
		if reinforcement.wave_count <= 0:
			errors.append("Reinforcement %d: Wave count must be greater than 0" % (i + 1))
		
		if reinforcement.priority < 1 or reinforcement.priority > 100:
			errors.append("Reinforcement %d: Priority must be between 1 and 100" % (i + 1))
		
		# Validate arrival cue if present
		if reinforcement.arrival_cue and reinforcement.arrival_cue.has_method("validate"):
			var cue_result: ValidationResult = reinforcement.arrival_cue.validate()
			if not cue_result.is_valid():
				for error in cue_result.get_errors():
					errors.append("Reinforcement %d arrival cue: %s" % [(i + 1), error])
	
	var is_valid: bool = errors.is_empty()
	validation_changed.emit(is_valid, errors)
	
	return {"is_valid": is_valid, "errors": errors}

func apply_changes(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	# Apply reinforcement list to mission data
	if mission_data.has_method("set_reinforcements"):
		mission_data.set_reinforcements(reinforcement_list)
	
	print("ReinforcementEditorPanel: Applied %d reinforcements to mission" % reinforcement_list.size())

func export_component() -> Dictionary:
	return {
		"reinforcements": reinforcement_list,
		"count": reinforcement_list.size()
	}

## Gets current reinforcement list
func get_reinforcements() -> Array[ReinforcementData]:
	return reinforcement_list

## Gets selected reinforcement
func get_selected_reinforcement() -> ReinforcementData:
	return selected_reinforcement