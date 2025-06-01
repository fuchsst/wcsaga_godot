class_name WingEditorDialogController
extends AcceptDialog

## Wing Editor Dialog Controller
##
## Provides comprehensive wing editing functionality for the GFRED2 Mission Editor,
## supporting all WCS wing properties including arrival/departure conditions,
## wave management, SEXP integration, and advanced options.
##
## Based on analysis of source/code/fred2/wing_editor.cpp from the original WCS codebase.

# Wing data currently being edited
var current_wing: WingInstanceData = null
var current_wing_index: int = -1
var mission_data: MissionData = null

# UI element references
@onready var wing_name_edit: LineEdit = $VBoxContainer/BasicInfoGroup/BasicInfoContainer/WingNameEdit
@onready var special_ship_option: OptionButton = $VBoxContainer/BasicInfoGroup/BasicInfoContainer/SpecialShipOption
@onready var hotkey_option: OptionButton = $VBoxContainer/BasicInfoGroup/BasicInfoContainer/HotkeyOption
@onready var squad_logo_edit: LineEdit = $VBoxContainer/BasicInfoGroup/BasicInfoContainer/SquadLogoContainer/SquadLogoEdit
@onready var squad_logo_browse: Button = $VBoxContainer/BasicInfoGroup/BasicInfoContainer/SquadLogoContainer/SquadLogoBrowse

@onready var waves_spin: SpinBox = $VBoxContainer/WaveManagementGroup/WaveContainer/WavesSpin
@onready var threshold_spin: SpinBox = $VBoxContainer/WaveManagementGroup/WaveContainer/ThresholdSpin

# Arrival controls
@onready var arrival_location_option: OptionButton = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalSettingsContainer/ArrivalLocationOption
@onready var arrival_target_option: OptionButton = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalSettingsContainer/ArrivalTargetOption
@onready var arrival_delay_spin: SpinBox = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalSettingsContainer/ArrivalDelaySpin
@onready var arrival_distance_spin: SpinBox = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalSettingsContainer/ArrivalDistanceSpin
@onready var arrival_delay_min_spin: SpinBox = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalSettingsContainer/ArrivalDelayRangeContainer/ArrivalDelayMinSpin
@onready var arrival_delay_max_spin: SpinBox = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalSettingsContainer/ArrivalDelayRangeContainer/ArrivalDelayMaxSpin

@onready var no_arrival_music_check: CheckBox = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalFlagsContainer/NoArrivalMusicCheck
@onready var no_arrival_message_check: CheckBox = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalFlagsContainer/NoArrivalMessageCheck
@onready var no_arrival_warp_check: CheckBox = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalFlagsContainer/NoArrivalWarpCheck
@onready var no_arrival_log_check: CheckBox = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalFlagsContainer/NoArrivalLogCheck

@onready var arrival_sexp_tree: Tree = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalConditionContainer/ArrivalSexpTree
@onready var arrival_edit_sexp: Button = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalConditionContainer/ArrivalSexpButtons/ArrivalEditSexp
@onready var arrival_clear_sexp: Button = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Arrival/ArrivalVBox/ArrivalConditionContainer/ArrivalSexpButtons/ArrivalClearSexp

# Departure controls
@onready var departure_location_option: OptionButton = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Departure/DepartureVBox/DepartureSettingsContainer/DepartureLocationOption
@onready var departure_target_option: OptionButton = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Departure/DepartureVBox/DepartureSettingsContainer/DepartureTargetOption
@onready var departure_delay_spin: SpinBox = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Departure/DepartureVBox/DepartureSettingsContainer/DepartureDelaySpin

@onready var no_departure_warp_check: CheckBox = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Departure/DepartureVBox/DepartureFlagsContainer/NoDepartureWarpCheck
@onready var no_departure_log_check: CheckBox = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Departure/DepartureVBox/DepartureFlagsContainer/NoDepartureLogCheck

@onready var departure_sexp_tree: Tree = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Departure/DepartureVBox/DepartureConditionContainer/DepartureSexpTree
@onready var departure_edit_sexp: Button = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Departure/DepartureVBox/DepartureConditionContainer/DepartureSexpButtons/DepartureEditSexp
@onready var departure_clear_sexp: Button = $VBoxContainer/ArrivalDepartureGroup/ArrivalDepartureTab/Departure/DepartureVBox/DepartureConditionContainer/DepartureSexpButtons/DepartureClearSexp

# Additional options
@onready var reinforcement_check: CheckBox = $VBoxContainer/AdditionalOptionsGroup/AdditionalOptionsContainer/ReinforcementCheck
@onready var ignore_count_check: CheckBox = $VBoxContainer/AdditionalOptionsGroup/AdditionalOptionsContainer/IgnoreCountCheck
@onready var no_dynamic_check: CheckBox = $VBoxContainer/AdditionalOptionsGroup/AdditionalOptionsContainer/NoDynamicCheck

# Navigation buttons
@onready var prev_wing_button: Button = $VBoxContainer/DialogButtons/PrevWingButton
@onready var next_wing_button: Button = $VBoxContainer/DialogButtons/NextWingButton
@onready var delete_wing_button: Button = $VBoxContainer/DialogButtons/DeleteWingButton
@onready var disband_wing_button: Button = $VBoxContainer/DialogButtons/DisbandWingButton

@onready var squad_logo_file_dialog: FileDialog = $SquadLogoFileDialog

# Signals
signal wing_modified(wing: WingInstanceData)
signal wing_deleted(wing_index: int)
signal wing_disbanded(wing_index: int)
signal request_sexp_editor(initial_sexp: String, callback: Callable)

# Wing flag constants (from WCS source)
const WING_FLAG_REINFORCEMENT: int = 1 << 0
const WING_FLAG_IGNORE_COUNT: int = 1 << 1
const WING_FLAG_NO_ARRIVAL_MUSIC: int = 1 << 2
const WING_FLAG_NO_ARRIVAL_MESSAGE: int = 1 << 3
const WING_FLAG_NO_ARRIVAL_WARP: int = 1 << 4
const WING_FLAG_NO_DEPARTURE_WARP: int = 1 << 5
const WING_FLAG_NO_ARRIVAL_LOG: int = 1 << 6
const WING_FLAG_NO_DEPARTURE_LOG: int = 1 << 7
const WING_FLAG_NO_DYNAMIC: int = 1 << 8

# Constants for location and target options
const ARRIVAL_LOCATIONS: Array[String] = [
	"Hyperspace",
	"Near Ship",
	"In Front of Ship",
	"Behind Ship",
	"Above Ship",
	"Below Ship",
	"To Left of Ship",
	"To Right of Ship",
	"Docking Bay"
]

const DEPARTURE_LOCATIONS: Array[String] = [
	"Hyperspace",
	"Docking Bay"
]

const HOTKEY_OPTIONS: Array[String] = [
	"F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"
]

# State tracking
var modified: bool = false
var bypass_errors: bool = false

func _ready() -> void:
	_setup_ui()
	_connect_signals()

## Sets up the user interface
func _setup_ui() -> void:
	# Setup arrival location options
	for location in ARRIVAL_LOCATIONS:
		arrival_location_option.add_item(location)
	
	# Setup departure location options  
	for location in DEPARTURE_LOCATIONS:
		departure_location_option.add_item(location)
	
	# Setup hotkey options
	hotkey_option.add_item("None")
	for hotkey in HOTKEY_OPTIONS:
		hotkey_option.add_item(hotkey)
	
	# Setup SEXP tree columns
	arrival_sexp_tree.set_column_title(0, "Operator/Data")
	arrival_sexp_tree.set_column_title(1, "Type")
	departure_sexp_tree.set_column_title(0, "Operator/Data")
	departure_sexp_tree.set_column_title(1, "Type")
	
	# Initialize UI state
	_update_navigation_buttons()

## Connects all UI signals
func _connect_signals() -> void:
	# Basic info signals
	wing_name_edit.text_changed.connect(_on_wing_name_changed)
	special_ship_option.item_selected.connect(_on_special_ship_changed)
	hotkey_option.item_selected.connect(_on_hotkey_changed)
	squad_logo_browse.pressed.connect(_on_squad_logo_browse)
	
	# Wave management signals
	waves_spin.value_changed.connect(_on_waves_changed)
	threshold_spin.value_changed.connect(_on_threshold_changed)
	
	# Arrival signals
	arrival_location_option.item_selected.connect(_on_arrival_location_changed)
	arrival_target_option.item_selected.connect(_on_arrival_target_changed)
	arrival_delay_spin.value_changed.connect(_on_arrival_delay_changed)
	arrival_distance_spin.value_changed.connect(_on_arrival_distance_changed)
	arrival_delay_min_spin.value_changed.connect(_on_arrival_delay_min_changed)
	arrival_delay_max_spin.value_changed.connect(_on_arrival_delay_max_changed)
	
	no_arrival_music_check.toggled.connect(_on_no_arrival_music_toggled)
	no_arrival_message_check.toggled.connect(_on_no_arrival_message_toggled)
	no_arrival_warp_check.toggled.connect(_on_no_arrival_warp_toggled)
	no_arrival_log_check.toggled.connect(_on_no_arrival_log_toggled)
	
	arrival_edit_sexp.pressed.connect(_on_arrival_edit_sexp)
	arrival_clear_sexp.pressed.connect(_on_arrival_clear_sexp)
	
	# Departure signals
	departure_location_option.item_selected.connect(_on_departure_location_changed)
	departure_target_option.item_selected.connect(_on_departure_target_changed)
	departure_delay_spin.value_changed.connect(_on_departure_delay_changed)
	
	no_departure_warp_check.toggled.connect(_on_no_departure_warp_toggled)
	no_departure_log_check.toggled.connect(_on_no_departure_log_toggled)
	
	departure_edit_sexp.pressed.connect(_on_departure_edit_sexp)
	departure_clear_sexp.pressed.connect(_on_departure_clear_sexp)
	
	# Additional options signals
	reinforcement_check.toggled.connect(_on_reinforcement_toggled)
	ignore_count_check.toggled.connect(_on_ignore_count_toggled)
	no_dynamic_check.toggled.connect(_on_no_dynamic_toggled)
	
	# Navigation signals
	prev_wing_button.pressed.connect(_on_prev_wing)
	next_wing_button.pressed.connect(_on_next_wing)
	delete_wing_button.pressed.connect(_on_delete_wing)
	disband_wing_button.pressed.connect(_on_disband_wing)
	
	# File dialog signals
	squad_logo_file_dialog.file_selected.connect(_on_squad_logo_selected)

## Shows the wing editor dialog for a specific wing
func show_wing_editor(wing: WingInstanceData, wing_index: int, mission: MissionData) -> void:
	current_wing = wing
	current_wing_index = wing_index
	mission_data = mission
	
	if current_wing:
		_load_wing_data()
		_populate_target_options()
		_populate_special_ship_options()
		
	popup_centered()

## Loads wing data into the UI
func _load_wing_data() -> void:
	if not current_wing:
		return
	
	modified = false
	
	# Basic info
	wing_name_edit.text = current_wing.wing_name
	special_ship_option.selected = current_wing.special_ship_index + 1  # +1 for "<none>" option
	hotkey_option.selected = current_wing.hotkey + 1 if current_wing.hotkey >= 0 else 0  # +1 for "<none>" option
	squad_logo_edit.text = current_wing.squad_logo_filename
	
	# Wave management
	waves_spin.value = current_wing.num_waves
	threshold_spin.value = current_wing.wave_threshold
	
	# Arrival settings
	arrival_location_option.selected = current_wing.arrival_location
	arrival_delay_spin.value = current_wing.arrival_delay_ms / 1000.0  # Convert ms to seconds
	arrival_distance_spin.value = current_wing.arrival_distance
	arrival_delay_min_spin.value = current_wing.wave_delay_min / 1000.0  # Convert ms to seconds
	arrival_delay_max_spin.value = current_wing.wave_delay_max / 1000.0  # Convert ms to seconds
	
	# Arrival flags - extracted from wing flags bitfield
	var wing_flags := current_wing.flags
	no_arrival_music_check.button_pressed = (wing_flags & WING_FLAG_NO_ARRIVAL_MUSIC) != 0
	no_arrival_message_check.button_pressed = (wing_flags & WING_FLAG_NO_ARRIVAL_MESSAGE) != 0
	no_arrival_warp_check.button_pressed = (wing_flags & WING_FLAG_NO_ARRIVAL_WARP) != 0
	no_arrival_log_check.button_pressed = (wing_flags & WING_FLAG_NO_ARRIVAL_LOG) != 0
	
	# Departure settings
	departure_location_option.selected = current_wing.departure_location
	departure_delay_spin.value = current_wing.departure_delay_ms / 1000.0  # Convert ms to seconds
	
	# Departure flags - extracted from wing flags bitfield
	no_departure_warp_check.button_pressed = (wing_flags & WING_FLAG_NO_DEPARTURE_WARP) != 0
	no_departure_log_check.button_pressed = (wing_flags & WING_FLAG_NO_DEPARTURE_LOG) != 0
	
	# Additional options - extracted from wing flags bitfield
	reinforcement_check.button_pressed = (wing_flags & WING_FLAG_REINFORCEMENT) != 0
	ignore_count_check.button_pressed = (wing_flags & WING_FLAG_IGNORE_COUNT) != 0
	no_dynamic_check.button_pressed = (wing_flags & WING_FLAG_NO_DYNAMIC) != 0
	
	# Load SEXP trees
	_load_arrival_sexp()
	_load_departure_sexp()
	
	_update_navigation_buttons()

## Populates target option menus with available ships and objects
func _populate_target_options() -> void:
	if not mission_data:
		return
	
	# Clear existing options
	arrival_target_option.clear()
	departure_target_option.clear()
	
	# Add default option
	arrival_target_option.add_item("<none>")
	departure_target_option.add_item("<none>")
	
	# Add ships from mission
	for ship_resource in mission_data.ships:
		var ship_instance := ship_resource as ShipInstanceData
		if ship_instance:
			arrival_target_option.add_item(ship_instance.ship_name)
			departure_target_option.add_item(ship_instance.ship_name)
	
	# Add waypoint lists
	for waypoint_list_resource in mission_data.waypoint_lists:
		var waypoint_list := waypoint_list_resource as WaypointListData
		if waypoint_list:
			arrival_target_option.add_item(waypoint_list.name)
			departure_target_option.add_item(waypoint_list.name)

## Populates special ship options with ships in the wing
func _populate_special_ship_options() -> void:
	special_ship_option.clear()
	special_ship_option.add_item("<none>")
	
	# Add wing ships - placeholder implementation
	for i in range(4):  # Typical wing size
		special_ship_option.add_item("Ship %d" % (i + 1))

## Loads arrival SEXP into the tree
func _load_arrival_sexp() -> void:
	arrival_sexp_tree.clear()
	var root := arrival_sexp_tree.create_item()
	
	if current_wing and current_wing.arrival_cue_sexp:
		# Load actual SEXP data
		_populate_sexp_tree(arrival_sexp_tree, root, current_wing.arrival_cue_sexp)
	else:
		# Default to "true" condition
		var item := arrival_sexp_tree.create_item(root)
		item.set_text(0, "true")
		item.set_text(1, "boolean")

## Loads departure SEXP into the tree  
func _load_departure_sexp() -> void:
	departure_sexp_tree.clear()
	var root := departure_sexp_tree.create_item()
	
	if current_wing and current_wing.departure_cue_sexp:
		# Load actual SEXP data
		_populate_sexp_tree(departure_sexp_tree, root, current_wing.departure_cue_sexp)
	else:
		# Default to "false" condition
		var item := departure_sexp_tree.create_item(root)
		item.set_text(0, "false")
		item.set_text(1, "boolean")

## Populates a SEXP tree from a SexpExpression resource
func _populate_sexp_tree(tree: Tree, parent: TreeItem, sexp: Resource) -> void:
	if not sexp:
		return
	
	# This is a placeholder - in full implementation, this would parse the SEXP structure
	# and create appropriate tree items based on the expression data
	var item := tree.create_item(parent)
	
	# For now, display a simplified representation
	if sexp.has_method("get_expression_string"):
		item.set_text(0, sexp.get_expression_string())
	else:
		item.set_text(0, "Complex Expression")
	item.set_text(1, "sexp")

## Updates navigation button states
func _update_navigation_buttons() -> void:
	if not mission_data:
		prev_wing_button.disabled = true
		next_wing_button.disabled = true
		return
	
	prev_wing_button.disabled = current_wing_index <= 0
	next_wing_button.disabled = current_wing_index >= mission_data.wings.size() - 1

## Saves current wing data
func _save_wing_data() -> void:
	if not current_wing:
		return
	
	# Save basic info
	current_wing.wing_name = wing_name_edit.text
	current_wing.special_ship_index = special_ship_option.selected - 1  # -1 for "<none>" option
	current_wing.hotkey = hotkey_option.selected - 1 if hotkey_option.selected > 0 else -1  # -1 for "<none>" option
	current_wing.squad_logo_filename = squad_logo_edit.text
	
	# Save wave management
	current_wing.num_waves = int(waves_spin.value)
	current_wing.wave_threshold = int(threshold_spin.value)
	
	# Save arrival settings
	current_wing.arrival_location = arrival_location_option.selected
	current_wing.arrival_delay_ms = int(arrival_delay_spin.value * 1000)  # Convert seconds to ms
	current_wing.arrival_distance = int(arrival_distance_spin.value)
	current_wing.wave_delay_min = int(arrival_delay_min_spin.value * 1000)  # Convert seconds to ms
	current_wing.wave_delay_max = int(arrival_delay_max_spin.value * 1000)  # Convert seconds to ms
	
	# Save departure settings
	current_wing.departure_location = departure_location_option.selected
	current_wing.departure_delay_ms = int(departure_delay_spin.value * 1000)  # Convert seconds to ms
	
	# Build wing flags bitfield
	var wing_flags := 0
	if reinforcement_check.button_pressed:
		wing_flags |= WING_FLAG_REINFORCEMENT
	if ignore_count_check.button_pressed:
		wing_flags |= WING_FLAG_IGNORE_COUNT
	if no_arrival_music_check.button_pressed:
		wing_flags |= WING_FLAG_NO_ARRIVAL_MUSIC
	if no_arrival_message_check.button_pressed:
		wing_flags |= WING_FLAG_NO_ARRIVAL_MESSAGE
	if no_arrival_warp_check.button_pressed:
		wing_flags |= WING_FLAG_NO_ARRIVAL_WARP
	if no_departure_warp_check.button_pressed:
		wing_flags |= WING_FLAG_NO_DEPARTURE_WARP
	if no_arrival_log_check.button_pressed:
		wing_flags |= WING_FLAG_NO_ARRIVAL_LOG
	if no_departure_log_check.button_pressed:
		wing_flags |= WING_FLAG_NO_DEPARTURE_LOG
	if no_dynamic_check.button_pressed:
		wing_flags |= WING_FLAG_NO_DYNAMIC
	
	current_wing.flags = wing_flags
	
	# Save target references (arrival/departure anchors)
	if arrival_target_option.selected > 0:
		current_wing.arrival_anchor_name = arrival_target_option.get_item_text(arrival_target_option.selected)
	else:
		current_wing.arrival_anchor_name = ""
	
	if departure_target_option.selected > 0:
		current_wing.departure_anchor_name = departure_target_option.get_item_text(departure_target_option.selected)
	else:
		current_wing.departure_anchor_name = ""
	
	# Emit signal that wing was modified
	wing_modified.emit(current_wing)

## Signal handlers

func _on_wing_name_changed(new_name: String) -> void:
	_mark_modified()

func _on_special_ship_changed(index: int) -> void:
	_mark_modified()

func _on_hotkey_changed(index: int) -> void:
	_mark_modified()

func _on_squad_logo_browse() -> void:
	squad_logo_file_dialog.popup_centered(Vector2i(800, 600))

func _on_squad_logo_selected(path: String) -> void:
	squad_logo_edit.text = path.get_file()
	_mark_modified()

func _on_waves_changed(value: float) -> void:
	_mark_modified()

func _on_threshold_changed(value: float) -> void:
	_mark_modified()

func _on_arrival_location_changed(index: int) -> void:
	_mark_modified()

func _on_arrival_target_changed(index: int) -> void:
	_mark_modified()

func _on_arrival_delay_changed(value: float) -> void:
	_mark_modified()

func _on_arrival_distance_changed(value: float) -> void:
	_mark_modified()

func _on_arrival_delay_min_changed(value: float) -> void:
	_mark_modified()

func _on_arrival_delay_max_changed(value: float) -> void:
	_mark_modified()

func _on_no_arrival_music_toggled(pressed: bool) -> void:
	_mark_modified()

func _on_no_arrival_message_toggled(pressed: bool) -> void:
	_mark_modified()

func _on_no_arrival_warp_toggled(pressed: bool) -> void:
	_mark_modified()

func _on_no_arrival_log_toggled(pressed: bool) -> void:
	_mark_modified()

func _on_arrival_edit_sexp() -> void:
	# Get current SEXP as string - placeholder implementation
	var current_sexp := "true"
	request_sexp_editor.emit(current_sexp, _on_arrival_sexp_edited)

func _on_arrival_clear_sexp() -> void:
	_load_arrival_sexp()  # Reset to default
	_mark_modified()

func _on_arrival_sexp_edited(new_sexp: String) -> void:
	# Update arrival SEXP with new expression
	# This would integrate with the SEXP editor system
	_mark_modified()

func _on_departure_location_changed(index: int) -> void:
	_mark_modified()

func _on_departure_target_changed(index: int) -> void:
	_mark_modified()

func _on_departure_delay_changed(value: float) -> void:
	_mark_modified()

func _on_no_departure_warp_toggled(pressed: bool) -> void:
	_mark_modified()

func _on_no_departure_log_toggled(pressed: bool) -> void:
	_mark_modified()

func _on_departure_edit_sexp() -> void:
	# Get current SEXP as string - placeholder implementation
	var current_sexp := "false"
	request_sexp_editor.emit(current_sexp, _on_departure_sexp_edited)

func _on_departure_clear_sexp() -> void:
	_load_departure_sexp()  # Reset to default
	_mark_modified()

func _on_departure_sexp_edited(new_sexp: String) -> void:
	# Update departure SEXP with new expression  
	# This would integrate with the SEXP editor system
	_mark_modified()

func _on_reinforcement_toggled(pressed: bool) -> void:
	_mark_modified()

func _on_ignore_count_toggled(pressed: bool) -> void:
	_mark_modified()

func _on_no_dynamic_toggled(pressed: bool) -> void:
	_mark_modified()

func _on_prev_wing() -> void:
	if current_wing_index > 0:
		_save_wing_data()
		var prev_wing := mission_data.wings[current_wing_index - 1] as WingInstanceData
		show_wing_editor(prev_wing, current_wing_index - 1, mission_data)

func _on_next_wing() -> void:
	if current_wing_index < mission_data.wings.size() - 1:
		_save_wing_data()
		var next_wing := mission_data.wings[current_wing_index + 1] as WingInstanceData
		show_wing_editor(next_wing, current_wing_index + 1, mission_data)

func _on_delete_wing() -> void:
	var confirmation := ConfirmationDialog.new()
	confirmation.dialog_text = "Are you sure you want to delete wing '%s'?" % current_wing.wing_name
	add_child(confirmation)
	confirmation.confirmed.connect(_confirm_delete_wing)
	confirmation.popup_centered()

func _confirm_delete_wing() -> void:
	wing_deleted.emit(current_wing_index)
	hide()

func _on_disband_wing() -> void:
	var confirmation := ConfirmationDialog.new()
	confirmation.dialog_text = "Are you sure you want to disband wing '%s'? Ships will become individual objects." % current_wing.wing_name
	add_child(confirmation)
	confirmation.confirmed.connect(_confirm_disband_wing)
	confirmation.popup_centered()

func _confirm_disband_wing() -> void:
	wing_disbanded.emit(current_wing_index)
	hide()

func _mark_modified() -> void:
	if not modified:
		modified = true
		# Update window title to indicate modification
		if not title.ends_with(" *"):
			title += " *"

## Dialog overrides

func _on_confirmed() -> void:
	if modified:
		_save_wing_data()
	super._on_confirmed()

func _on_canceled() -> void:
	if modified:
		var confirmation := ConfirmationDialog.new()
		confirmation.dialog_text = "Discard changes to wing '%s'?" % current_wing.wing_name
		add_child(confirmation)
		confirmation.confirmed.connect(func(): super._on_canceled())
		confirmation.popup_centered()
	else:
		super._on_canceled()