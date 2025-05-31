@tool
class_name MissionGoalsEditorPanel
extends Control

## Mission goals and objectives editor for GFRED2-010 Mission Component Editors.
## Scene-based UI controller for configuring mission goals with validation.
## Scene: addons/gfred2/scenes/dialogs/component_editors/mission_goals_editor_panel.tscn

signal goal_updated(goal_data: MissionGoal)
signal validation_changed(is_valid: bool, errors: Array[String])
signal goal_selected(goal_id: String)

# Current mission and goals data
var current_mission_data: MissionData = null
var goal_list: Array[MissionGoal] = []

# Scene node references
@onready var goals_tree: Tree = $VBoxContainer/GoalsList/GoalsTree
@onready var add_goal_button: Button = $VBoxContainer/GoalsList/ButtonContainer/AddButton
@onready var remove_goal_button: Button = $VBoxContainer/GoalsList/ButtonContainer/RemoveButton
@onready var duplicate_goal_button: Button = $VBoxContainer/GoalsList/ButtonContainer/DuplicateButton
@onready var move_up_button: Button = $VBoxContainer/GoalsList/ButtonContainer/MoveUpButton
@onready var move_down_button: Button = $VBoxContainer/GoalsList/ButtonContainer/MoveDownButton

@onready var properties_container: VBoxContainer = $VBoxContainer/PropertiesContainer
@onready var goal_name_edit: LineEdit = $VBoxContainer/PropertiesContainer/NameContainer/NameEdit
@onready var goal_type_option: OptionButton = $VBoxContainer/PropertiesContainer/TypeContainer/TypeOption
@onready var goal_message_edit: TextEdit = $VBoxContainer/PropertiesContainer/MessageContainer/MessageEdit
@onready var goal_formula_edit: SexpPropertyEditor = $VBoxContainer/PropertiesContainer/FormulaContainer/FormulaEdit

@onready var score_container: HBoxContainer = $VBoxContainer/PropertiesContainer/ScoreContainer
@onready var score_spin: SpinBox = $VBoxContainer/PropertiesContainer/ScoreContainer/ScoreSpin
@onready var team_option: OptionButton = $VBoxContainer/PropertiesContainer/TeamContainer/TeamOption
@onready var invalid_option: CheckBox = $VBoxContainer/PropertiesContainer/FlagsContainer/InvalidOption
@onready var no_music_option: CheckBox = $VBoxContainer/PropertiesContainer/FlagsContainer/NoMusicOption

# Current selected goal
var selected_goal: MissionGoal = null

# Goal type definitions
var goal_types: Array[Dictionary] = [
	{"name": "Primary", "value": "primary", "icon": "res://addons/gfred2/icons/primary_goal.png"},
	{"name": "Secondary", "value": "secondary", "icon": "res://addons/gfred2/icons/secondary_goal.png"},
	{"name": "Bonus", "value": "bonus", "icon": "res://addons/gfred2/icons/bonus_goal.png"}
]

func _ready() -> void:
	name = "MissionGoalsEditorPanel"
	
	# Setup UI components
	_setup_goals_tree()
	_setup_goal_type_options()
	_setup_team_options()
	_setup_property_editors()
	_connect_signals()
	
	# Initialize empty state
	_update_properties_display()
	
	print("MissionGoalsEditorPanel: Mission goals editor initialized")

## Initializes the editor with mission data
func initialize_with_mission(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	current_mission_data = mission_data
	
	# Load existing goals from mission data
	if mission_data.has_method("get_goals"):
		goal_list = mission_data.get_goals()
	else:
		goal_list = []
	
	# Populate goals tree
	_populate_goals_tree()
	
	print("MissionGoalsEditorPanel: Initialized with %d goals" % goal_list.size())

## Sets up the goals tree
func _setup_goals_tree() -> void:
	if not goals_tree:
		return
	
	goals_tree.columns = 4
	goals_tree.set_column_title(0, "Name")
	goals_tree.set_column_title(1, "Type")
	goals_tree.set_column_title(2, "Team")
	goals_tree.set_column_title(3, "Score")
	
	goals_tree.set_column_expand(0, true)
	goals_tree.set_column_expand(1, false)
	goals_tree.set_column_expand(2, false)
	goals_tree.set_column_expand(3, false)
	
	goals_tree.item_selected.connect(_on_goal_selected)

func _setup_goal_type_options() -> void:
	if not goal_type_option:
		return
	
	goal_type_option.clear()
	for goal_type in goal_types:
		goal_type_option.add_item(goal_type["name"])
		# TODO: Add icons when supported
	
	goal_type_option.item_selected.connect(_on_goal_type_selected)

func _setup_team_options() -> void:
	if not team_option:
		return
	
	team_option.clear()
	team_option.add_item("Friendly", 0)
	team_option.add_item("Hostile", 1)
	team_option.add_item("Neutral", 2)
	team_option.add_item("Unknown", 3)
	
	team_option.item_selected.connect(_on_team_selected)

func _setup_property_editors() -> void:
	# Setup text inputs
	if goal_name_edit:
		goal_name_edit.text_changed.connect(_on_name_changed)
	
	if goal_message_edit:
		goal_message_edit.text_changed.connect(_on_message_changed)
	
	# Setup numeric inputs
	if score_spin:
		score_spin.min_value = -1000
		score_spin.max_value = 10000
		score_spin.value_changed.connect(_on_score_changed)
	
	# Setup checkboxes
	if invalid_option:
		invalid_option.toggled.connect(_on_invalid_toggled)
	
	if no_music_option:
		no_music_option.toggled.connect(_on_no_music_toggled)
	
	# Setup SEXP editor
	if goal_formula_edit:
		goal_formula_edit.sexp_changed.connect(_on_formula_changed)

func _connect_signals() -> void:
	if add_goal_button:
		add_goal_button.pressed.connect(_on_add_goal_pressed)
	
	if remove_goal_button:
		remove_goal_button.pressed.connect(_on_remove_goal_pressed)
	
	if duplicate_goal_button:
		duplicate_goal_button.pressed.connect(_on_duplicate_goal_pressed)
	
	if move_up_button:
		move_up_button.pressed.connect(_on_move_up_pressed)
	
	if move_down_button:
		move_down_button.pressed.connect(_on_move_down_pressed)

## Populates the goals tree with current data
func _populate_goals_tree() -> void:
	if not goals_tree:
		return
	
	goals_tree.clear()
	var root: TreeItem = goals_tree.create_item()
	
	for i in range(goal_list.size()):
		var goal: MissionGoal = goal_list[i]
		var item: TreeItem = goals_tree.create_item(root)
		
		item.set_text(0, goal.goal_name)
		item.set_text(1, goal.goal_type.capitalize())
		item.set_text(2, _get_team_name(goal.team))
		item.set_text(3, str(goal.score))
		item.set_metadata(0, i)  # Store index for selection
		
		# Set icon based on goal type
		var icon_path: String = _get_goal_type_icon(goal.goal_type)
		if FileAccess.file_exists(icon_path):
			var icon: Texture2D = load(icon_path)
			if icon:
				item.set_icon(0, icon)

func _get_team_name(team_id: int) -> String:
	match team_id:
		0: return "Friendly"
		1: return "Hostile"
		2: return "Neutral"
		3: return "Unknown"
		_: return "Unknown"

func _get_goal_type_icon(goal_type: String) -> String:
	for type_info in goal_types:
		if type_info["value"] == goal_type:
			return type_info["icon"]
	return ""

func _update_properties_display() -> void:
	var has_selection: bool = selected_goal != null
	
	# Enable/disable property controls
	properties_container.modulate = Color.WHITE if has_selection else Color(0.5, 0.5, 0.5)
	
	if not has_selection:
		# Clear all inputs when no selection
		if goal_name_edit:
			goal_name_edit.text = ""
		if goal_message_edit:
			goal_message_edit.text = ""
		if goal_type_option:
			goal_type_option.selected = -1
		if score_spin:
			score_spin.value = 0
		if team_option:
			team_option.selected = 0
		if invalid_option:
			invalid_option.button_pressed = false
		if no_music_option:
			no_music_option.button_pressed = false
		return
	
	# Update inputs with selected goal data
	if goal_name_edit:
		goal_name_edit.text = selected_goal.goal_name
	
	if goal_message_edit:
		goal_message_edit.text = selected_goal.message_text
	
	if goal_type_option:
		# Find and select the appropriate goal type
		for i in range(goal_types.size()):
			if goal_types[i]["value"] == selected_goal.goal_type:
				goal_type_option.selected = i
				break
	
	if score_spin:
		score_spin.value = selected_goal.score
	
	if team_option:
		team_option.selected = selected_goal.team
	
	if invalid_option:
		invalid_option.button_pressed = selected_goal.invalid
	
	if no_music_option:
		no_music_option.button_pressed = selected_goal.no_music
	
	if goal_formula_edit and selected_goal.formula:
		goal_formula_edit.set_sexp_node(selected_goal.formula)

## Signal handlers

func _on_goal_selected() -> void:
	var selected_item: TreeItem = goals_tree.get_selected()
	if not selected_item:
		selected_goal = null
		_update_properties_display()
		return
	
	var goal_index: int = selected_item.get_metadata(0)
	if goal_index >= 0 and goal_index < goal_list.size():
		selected_goal = goal_list[goal_index]
		_update_properties_display()
		goal_selected.emit(selected_goal.goal_id if selected_goal else "")

func _on_add_goal_pressed() -> void:
	var new_goal: MissionGoal = MissionGoal.new()
	new_goal.goal_name = "New Goal %d" % (goal_list.size() + 1)
	new_goal.goal_id = "goal_%d" % (goal_list.size() + 1)
	new_goal.goal_type = "primary"
	new_goal.message_text = "Complete objective %d" % (goal_list.size() + 1)
	new_goal.score = 10
	new_goal.team = 0  # Friendly
	
	goal_list.append(new_goal)
	_populate_goals_tree()
	
	# Select the new goal
	var root: TreeItem = goals_tree.get_root()
	if root:
		var last_item: TreeItem = root.get_child(goal_list.size() - 1)
		if last_item:
			last_item.select(0)
			_on_goal_selected()
	
	goal_updated.emit(new_goal)

func _on_remove_goal_pressed() -> void:
	if not selected_goal:
		return
	
	var selected_item: TreeItem = goals_tree.get_selected()
	if not selected_item:
		return
	
	var goal_index: int = selected_item.get_metadata(0)
	if goal_index >= 0 and goal_index < goal_list.size():
		goal_list.remove_at(goal_index)
		selected_goal = null
		_populate_goals_tree()
		_update_properties_display()

func _on_duplicate_goal_pressed() -> void:
	if not selected_goal:
		return
	
	var duplicated: MissionGoal = selected_goal.duplicate()
	duplicated.goal_name += " Copy"
	duplicated.goal_id += "_copy"
	
	goal_list.append(duplicated)
	_populate_goals_tree()
	
	goal_updated.emit(duplicated)

func _on_move_up_pressed() -> void:
	if not selected_goal:
		return
	
	var selected_item: TreeItem = goals_tree.get_selected()
	if not selected_item:
		return
	
	var goal_index: int = selected_item.get_metadata(0)
	if goal_index > 0:
		var temp: MissionGoal = goal_list[goal_index]
		goal_list[goal_index] = goal_list[goal_index - 1]
		goal_list[goal_index - 1] = temp
		_populate_goals_tree()
		
		# Reselect the moved goal
		var root: TreeItem = goals_tree.get_root()
		if root:
			var moved_item: TreeItem = root.get_child(goal_index - 1)
			if moved_item:
				moved_item.select(0)

func _on_move_down_pressed() -> void:
	if not selected_goal:
		return
	
	var selected_item: TreeItem = goals_tree.get_selected()
	if not selected_item:
		return
	
	var goal_index: int = selected_item.get_metadata(0)
	if goal_index < goal_list.size() - 1:
		var temp: MissionGoal = goal_list[goal_index]
		goal_list[goal_index] = goal_list[goal_index + 1]
		goal_list[goal_index + 1] = temp
		_populate_goals_tree()
		
		# Reselect the moved goal
		var root: TreeItem = goals_tree.get_root()
		if root:
			var moved_item: TreeItem = root.get_child(goal_index + 1)
			if moved_item:
				moved_item.select(0)

func _on_name_changed(new_text: String) -> void:
	if selected_goal:
		selected_goal.goal_name = new_text
		_populate_goals_tree()  # Refresh display
		goal_updated.emit(selected_goal)

func _on_message_changed() -> void:
	if selected_goal and goal_message_edit:
		selected_goal.message_text = goal_message_edit.text
		goal_updated.emit(selected_goal)

func _on_goal_type_selected(index: int) -> void:
	if selected_goal and index >= 0 and index < goal_types.size():
		selected_goal.goal_type = goal_types[index]["value"]
		_populate_goals_tree()
		goal_updated.emit(selected_goal)

func _on_score_changed(value: float) -> void:
	if selected_goal:
		selected_goal.score = int(value)
		_populate_goals_tree()
		goal_updated.emit(selected_goal)

func _on_team_selected(index: int) -> void:
	if selected_goal:
		selected_goal.team = index
		_populate_goals_tree()
		goal_updated.emit(selected_goal)

func _on_invalid_toggled(enabled: bool) -> void:
	if selected_goal:
		selected_goal.invalid = enabled
		goal_updated.emit(selected_goal)

func _on_no_music_toggled(enabled: bool) -> void:
	if selected_goal:
		selected_goal.no_music = enabled
		goal_updated.emit(selected_goal)

func _on_formula_changed(sexp_node: SexpNode) -> void:
	if selected_goal:
		selected_goal.formula = sexp_node
		goal_updated.emit(selected_goal)

## Validation and export methods

func validate_component() -> Dictionary:
	var errors: Array[String] = []
	
	# Check for at least one primary goal
	var has_primary_goal: bool = false
	for goal in goal_list:
		if goal.goal_type == "primary":
			has_primary_goal = true
			break
	
	if not has_primary_goal:
		errors.append("Mission must have at least one primary goal")
	
	# Validate each goal
	for i in range(goal_list.size()):
		var goal: MissionGoal = goal_list[i]
		
		if goal.goal_name.is_empty():
			errors.append("Goal %d: Name cannot be empty" % (i + 1))
		
		if goal.message_text.is_empty():
			errors.append("Goal %d: Message text cannot be empty" % (i + 1))
		
		if not goal.goal_type in ["primary", "secondary", "bonus"]:
			errors.append("Goal %d: Invalid goal type" % (i + 1))
		
		# Validate formula if present
		if goal.formula and goal.formula.has_method("validate"):
			var formula_result: ValidationResult = goal.formula.validate()
			if not formula_result.is_valid():
				for error in formula_result.get_errors():
					errors.append("Goal %d formula: %s" % [(i + 1), error])
	
	var is_valid: bool = errors.is_empty()
	validation_changed.emit(is_valid, errors)
	
	return {"is_valid": is_valid, "errors": errors}

func apply_changes(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	# Apply goal list to mission data
	if mission_data.has_method("set_goals"):
		mission_data.set_goals(goal_list)
	
	print("MissionGoalsEditorPanel: Applied %d goals to mission" % goal_list.size())

func export_component() -> Dictionary:
	return {
		"goals": goal_list,
		"count": goal_list.size(),
		"primary_count": goal_list.filter(func(g): return g.goal_type == "primary").size(),
		"secondary_count": goal_list.filter(func(g): return g.goal_type == "secondary").size(),
		"bonus_count": goal_list.filter(func(g): return g.goal_type == "bonus").size()
	}

## Gets current goal list
func get_goals() -> Array[MissionGoal]:
	return goal_list

## Gets selected goal
func get_selected_goal() -> MissionGoal:
	return selected_goal

## Gets goals by type
func get_goals_by_type(goal_type: String) -> Array[MissionGoal]:
	return goal_list.filter(func(goal): return goal.goal_type == goal_type)