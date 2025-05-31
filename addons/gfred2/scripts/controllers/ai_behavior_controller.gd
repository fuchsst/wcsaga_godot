@tool
class_name AIBehaviorController
extends Control

## AI behavior controller for GFRED2-009 Advanced Ship Configuration.
## Scene-based UI controller for configuring ship AI behavior and goals.
## Scene: addons/gfred2/scenes/dialogs/ship_editor/ai_behavior_panel.tscn
## Integrates with WCS Asset Core and SEXP addon data structures.

signal ai_config_updated(property_name: String, new_value: Variant)
signal ai_goal_added(goal: AIGoalConfig)
signal ai_goal_removed(index: int)
signal sexp_validation_changed(expression: String, is_valid: bool, errors: Array[String])

# Current AI configuration
var current_ai_config: AIBehaviorConfig = null
var asset_registry: RegistryManager = null

# Scene node references (populated by .tscn file)
@onready var ai_class_option: OptionButton = $VBoxContainer/AISettings/AIClassOption
@onready var combat_behavior_option: OptionButton = $VBoxContainer/AISettings/CombatBehaviorOption
@onready var formation_behavior_option: OptionButton = $VBoxContainer/AISettings/FormationBehaviorOption

@onready var aggressiveness_slider: HSlider = $VBoxContainer/Attributes/AggressivenessSlider
@onready var aggressiveness_spin: SpinBox = $VBoxContainer/Attributes/AggressivenessSpin
@onready var accuracy_slider: HSlider = $VBoxContainer/Attributes/AccuracySlider
@onready var accuracy_spin: SpinBox = $VBoxContainer/Attributes/AccuracySpin
@onready var evasion_slider: HSlider = $VBoxContainer/Attributes/EvasionSlider
@onready var evasion_spin: SpinBox = $VBoxContainer/Attributes/EvasionSpin
@onready var courage_slider: HSlider = $VBoxContainer/Attributes/CourageSlider
@onready var courage_spin: SpinBox = $VBoxContainer/Attributes/CourageSpin

@onready var goals_tree: Tree = $VBoxContainer/Goals/GoalsTree
@onready var add_goal_button: Button = $VBoxContainer/Goals/AddGoalButton
@onready var remove_goal_button: Button = $VBoxContainer/Goals/RemoveGoalButton
@onready var edit_goal_button: Button = $VBoxContainer/Goals/EditGoalButton

@onready var goal_type_option: OptionButton = $VBoxContainer/Goals/GoalEditor/GoalTypeOption
@onready var goal_target_edit: LineEdit = $VBoxContainer/Goals/GoalEditor/GoalTargetEdit
@onready var goal_priority_spin: SpinBox = $VBoxContainer/Goals/GoalEditor/GoalPrioritySpin
@onready var goal_sexp_edit: TextEdit = $VBoxContainer/Goals/GoalEditor/GoalSexpEdit
@onready var validate_sexp_button: Button = $VBoxContainer/Goals/GoalEditor/ValidateSexpButton
@onready var sexp_validation_label: Label = $VBoxContainer/Goals/GoalEditor/SexpValidationLabel

# AI Classes and behaviors (from WCS Asset Core)
var ai_classes: Array[String] = [
	"none", "fighter", "bomber", "stealth", "escort", "capital",
	"interceptor", "scout", "transport", "cargo", "support"
]

var combat_behaviors: Array[String] = [
	"default", "aggressive", "defensive", "evasive", "passive", "static",
	"kamikaze", "patrol", "guard", "avoid"
]

var formation_behaviors: Array[String] = [
	"default", "tight", "loose", "echelon", "diamond", "line_abreast",
	"vic", "wedge", "trail", "spread"
]

# AI Goal types (integrating with SEXP system)
var ai_goal_types: Array[String] = [
	"ai-destroy-subsys", "ai-disable-ship", "ai-disarm-ship", "ai-attack-ship",
	"ai-dock", "ai-undock", "ai-guard", "ai-guard-wing", "ai-waypoints",
	"ai-waypoints-once", "ai-evade-ship", "ai-ignore", "ai-ignore-new",
	"ai-stay-near-ship", "ai-keep-safe-distance", "ai-rearm", "ai-fly-to-ship"
]

# Validation state
var is_valid: bool = true
var validation_errors: Array[String] = []

func _ready() -> void:
	name = "AIBehaviorController"
	
	# Initialize asset system integration
	asset_registry = WCSAssetRegistry
	
	# Setup dropdowns
	_populate_ai_options()
	
	# Setup goals tree
	_setup_goals_tree()
	
	# Connect UI signals
	_connect_ui_signals()
	
	# Setup slider synchronization
	_setup_slider_synchronization()
	
	print("AIBehaviorController: Controller initialized with WCS Asset Core and SEXP integration")

## Updates the panel with AI behavior configuration
func update_with_ai_config(ai_config: AIBehaviorConfig) -> void:
	if not ai_config:
		return
	
	current_ai_config = ai_config
	
	# Update AI settings
	_set_option_selection(ai_class_option, ai_config.ai_class)
	_set_option_selection(combat_behavior_option, ai_config.combat_behavior)
	_set_option_selection(formation_behavior_option, ai_config.formation_behavior)
	
	# Update attributes
	aggressiveness_slider.value = ai_config.aggressiveness
	aggressiveness_spin.value = ai_config.aggressiveness
	accuracy_slider.value = ai_config.accuracy
	accuracy_spin.value = ai_config.accuracy
	evasion_slider.value = ai_config.evasion
	evasion_spin.value = ai_config.evasion
	courage_slider.value = ai_config.courage
	courage_spin.value = ai_config.courage
	
	# Update goals tree
	_populate_goals_tree()
	
	# Validate configuration
	_validate_ai_configuration()

## Populates AI option dropdowns
func _populate_ai_options() -> void:
	# Populate AI classes
	ai_class_option.clear()
	ai_class_option.add_item("(Default)", 0)
	for i in range(ai_classes.size()):
		ai_class_option.add_item(ai_classes[i].capitalize(), i + 1)
	
	# Populate combat behaviors
	combat_behavior_option.clear()
	for behavior in combat_behaviors:
		combat_behavior_option.add_item(behavior.capitalize())
	
	# Populate formation behaviors
	formation_behavior_option.clear()
	for behavior in formation_behaviors:
		formation_behavior_option.add_item(behavior.capitalize())
	
	# Populate goal types
	goal_type_option.clear()
	for goal_type in ai_goal_types:
		goal_type_option.add_item(goal_type.replace("ai-", "").replace("-", " ").capitalize())

## Sets option button selection by text
func _set_option_selection(option_button: OptionButton, value: String) -> void:
	for i in range(option_button.get_item_count()):
		var item_text: String = option_button.get_item_text(i).to_lower()
		if item_text == value.to_lower() or (value.is_empty() and i == 0):
			option_button.selected = i
			return

## Sets up goals tree columns and headers
func _setup_goals_tree() -> void:
	goals_tree.columns = 4
	goals_tree.set_column_title(0, "Goal Type")
	goals_tree.set_column_title(1, "Target")
	goals_tree.set_column_title(2, "Priority")
	goals_tree.set_column_title(3, "Condition")
	
	goals_tree.set_column_expand(0, true)
	goals_tree.set_column_expand(1, true)
	goals_tree.set_column_expand(2, false)
	goals_tree.set_column_expand(3, true)

## Populates goals tree with current AI goals
func _populate_goals_tree() -> void:
	goals_tree.clear()
	
	if not current_ai_config:
		return
	
	var root: TreeItem = goals_tree.create_item()
	
	for i in range(current_ai_config.ai_goals.size()):
		var goal: AIGoalConfig = current_ai_config.ai_goals[i]
		var item: TreeItem = goals_tree.create_item(root)
		
		item.set_text(0, goal.goal_type)
		item.set_text(1, goal.target)
		item.set_text(2, str(goal.priority))
		
		# Show condition/SEXP if available
		var condition: String = ""
		if goal.flags.size() > 0:
			condition = goal.flags[0]  # First flag as condition indicator
		item.set_text(3, condition)
		
		item.set_metadata(0, i)  # Store goal index

## Connects all UI signal handlers
func _connect_ui_signals() -> void:
	# AI settings signals
	ai_class_option.item_selected.connect(_on_ai_class_selected)
	combat_behavior_option.item_selected.connect(_on_combat_behavior_selected)
	formation_behavior_option.item_selected.connect(_on_formation_behavior_selected)
	
	# Attribute signals (sliders and spin boxes are synchronized)
	aggressiveness_slider.value_changed.connect(_on_aggressiveness_changed)
	accuracy_slider.value_changed.connect(_on_accuracy_changed)
	evasion_slider.value_changed.connect(_on_evasion_changed)
	courage_slider.value_changed.connect(_on_courage_changed)
	
	# Goals management signals
	add_goal_button.pressed.connect(_on_add_goal_pressed)
	remove_goal_button.pressed.connect(_on_remove_goal_pressed)
	edit_goal_button.pressed.connect(_on_edit_goal_pressed)
	goals_tree.item_selected.connect(_on_goal_selected)
	
	# Goal editor signals
	validate_sexp_button.pressed.connect(_on_validate_sexp_pressed)

## Sets up slider and spin box synchronization
func _setup_slider_synchronization() -> void:
	# Aggressiveness
	aggressiveness_slider.min_value = 0.0
	aggressiveness_slider.max_value = 10.0
	aggressiveness_slider.step = 0.1
	aggressiveness_spin.min_value = 0.0
	aggressiveness_spin.max_value = 10.0
	aggressiveness_spin.step = 0.1
	
	# Accuracy
	accuracy_slider.min_value = 0.0
	accuracy_slider.max_value = 10.0
	accuracy_slider.step = 0.1
	accuracy_spin.min_value = 0.0
	accuracy_spin.max_value = 10.0
	accuracy_spin.step = 0.1
	
	# Evasion
	evasion_slider.min_value = 0.0
	evasion_slider.max_value = 10.0
	evasion_slider.step = 0.1
	evasion_spin.min_value = 0.0
	evasion_spin.max_value = 10.0
	evasion_spin.step = 0.1
	
	# Courage
	courage_slider.min_value = 0.0
	courage_slider.max_value = 10.0
	courage_slider.step = 0.1
	courage_spin.min_value = 0.0
	courage_spin.max_value = 10.0
	courage_spin.step = 0.1
	
	# Synchronize sliders with spin boxes
	aggressiveness_spin.value_changed.connect(func(value: float): aggressiveness_slider.value = value)
	accuracy_spin.value_changed.connect(func(value: float): accuracy_slider.value = value)
	evasion_spin.value_changed.connect(func(value: float): evasion_slider.value = value)
	courage_spin.value_changed.connect(func(value: float): courage_slider.value = value)

## Validates current AI configuration
func _validate_ai_configuration() -> void:
	validation_errors.clear()
	
	if not current_ai_config:
		validation_errors.append("No AI configuration loaded")
		is_valid = false
		return
	
	# Validate attribute ranges
	if current_ai_config.aggressiveness < 0.0 or current_ai_config.aggressiveness > 10.0:
		validation_errors.append("Aggressiveness must be between 0.0 and 10.0")
	
	if current_ai_config.accuracy < 0.0 or current_ai_config.accuracy > 10.0:
		validation_errors.append("Accuracy must be between 0.0 and 10.0")
	
	if current_ai_config.evasion < 0.0 or current_ai_config.evasion > 10.0:
		validation_errors.append("Evasion must be between 0.0 and 10.0")
	
	if current_ai_config.courage < 0.0 or current_ai_config.courage > 10.0:
		validation_errors.append("Courage must be between 0.0 and 10.0")
	
	# Validate AI goals if SEXP system is available
	for i in range(current_ai_config.ai_goals.size()):
		var goal: AIGoalConfig = current_ai_config.ai_goals[i]
		
		if goal.goal_type.is_empty():
			validation_errors.append("AI Goal %d: Goal type cannot be empty" % (i + 1))
		
		if goal.priority < 0 or goal.priority > 200:
			validation_errors.append("AI Goal %d: Priority must be between 0 and 200" % (i + 1))
		
		# Validate SEXP expressions if present in flags
		for flag in goal.flags:
			if flag.begins_with("(") and flag.ends_with(")"):
				# This looks like a SEXP expression, validate it
				_validate_sexp_expression(flag, i + 1)
	
	is_valid = validation_errors.is_empty()

## Validates SEXP expression using SEXP addon (if available)
func _validate_sexp_expression(expression: String, goal_index: int = -1) -> void:
	# Check if SEXP system is available
	if not Engine.has_singleton("SexpManager"):
		print("AIBehaviorController: SEXP system not available for validation")
		return
	
	var sexp_manager = Engine.get_singleton("SexpManager")
	
	# Validate SEXP syntax
	var is_valid_sexp: bool = sexp_manager.validate_syntax(expression)
	
	if not is_valid_sexp:
		var sexp_errors: Array[String] = sexp_manager.get_validation_errors(expression)
		for error in sexp_errors:
			if goal_index > 0:
				validation_errors.append("AI Goal %d SEXP: %s" % [goal_index, error])
			else:
				validation_errors.append("SEXP Error: %s" % error)
		
		sexp_validation_changed.emit(expression, false, sexp_errors)
	else:
		sexp_validation_changed.emit(expression, true, [])

## Updates AI configuration property and emits signal
func _update_ai_property(property_name: String, new_value: Variant) -> void:
	if not current_ai_config:
		return
	
	current_ai_config.set(property_name, new_value)
	ai_config_updated.emit(property_name, new_value)
	
	# Revalidate after property change
	_validate_ai_configuration()

## Signal handlers

func _on_ai_class_selected(index: int) -> void:
	var ai_class: String = ai_classes[index - 1] if index > 0 else ""
	_update_ai_property("ai_class", ai_class)

func _on_combat_behavior_selected(index: int) -> void:
	var behavior: String = combat_behaviors[index]
	_update_ai_property("combat_behavior", behavior)

func _on_formation_behavior_selected(index: int) -> void:
	var behavior: String = formation_behaviors[index]
	_update_ai_property("formation_behavior", behavior)

func _on_aggressiveness_changed(value: float) -> void:
	aggressiveness_spin.value = value
	_update_ai_property("aggressiveness", value)

func _on_accuracy_changed(value: float) -> void:
	accuracy_spin.value = value
	_update_ai_property("accuracy", value)

func _on_evasion_changed(value: float) -> void:
	evasion_spin.value = value
	_update_ai_property("evasion", value)

func _on_courage_changed(value: float) -> void:
	courage_spin.value = value
	_update_ai_property("courage", value)

func _on_add_goal_pressed() -> void:
	if not current_ai_config:
		return
	
	var new_goal: AIGoalConfig = AIGoalConfig.new()
	new_goal.goal_type = ai_goal_types[0]  # Default to first goal type
	new_goal.priority = 89  # Default priority
	
	current_ai_config.ai_goals.append(new_goal)
	_populate_goals_tree()
	ai_goal_added.emit(new_goal)
	
	print("AIBehaviorController: Added new AI goal")

func _on_remove_goal_pressed() -> void:
	var selected: TreeItem = goals_tree.get_selected()
	if not selected or not current_ai_config:
		return
	
	var goal_index: int = selected.get_metadata(0)
	if goal_index >= 0 and goal_index < current_ai_config.ai_goals.size():
		current_ai_config.ai_goals.remove_at(goal_index)
		_populate_goals_tree()
		ai_goal_removed.emit(goal_index)
		
		print("AIBehaviorController: Removed AI goal at index %d" % goal_index)

func _on_edit_goal_pressed() -> void:
	var selected: TreeItem = goals_tree.get_selected()
	if not selected or not current_ai_config:
		return
	
	var goal_index: int = selected.get_metadata(0)
	if goal_index >= 0 and goal_index < current_ai_config.ai_goals.size():
		var goal: AIGoalConfig = current_ai_config.ai_goals[goal_index]
		
		# Populate goal editor with selected goal
		_set_option_selection(goal_type_option, goal.goal_type.replace("ai-", ""))
		goal_target_edit.text = goal.target
		goal_priority_spin.value = goal.priority
		
		# Show SEXP condition if available
		if goal.flags.size() > 0:
			goal_sexp_edit.text = goal.flags[0]
		else:
			goal_sexp_edit.text = ""

func _on_goal_selected() -> void:
	var selected: TreeItem = goals_tree.get_selected()
	remove_goal_button.disabled = selected == null
	edit_goal_button.disabled = selected == null

func _on_validate_sexp_pressed() -> void:
	var expression: String = goal_sexp_edit.text.strip_edges()
	
	if expression.is_empty():
		sexp_validation_label.text = "No expression to validate"
		sexp_validation_label.modulate = Color.YELLOW
		return
	
	# Validate using SEXP system
	_validate_sexp_expression(expression)
	
	# Update validation label
	if Engine.has_singleton("SexpManager"):
		var sexp_manager = Engine.get_singleton("SexpManager")
		var is_valid_sexp: bool = sexp_manager.validate_syntax(expression)
		
		if is_valid_sexp:
			sexp_validation_label.text = "✓ Valid SEXP expression"
			sexp_validation_label.modulate = Color.GREEN
		else:
			var errors: Array[String] = sexp_manager.get_validation_errors(expression)
			sexp_validation_label.text = "✗ Invalid: %s" % errors[0] if errors.size() > 0 else "Invalid expression"
			sexp_validation_label.modulate = Color.RED
	else:
		sexp_validation_label.text = "SEXP system not available"
		sexp_validation_label.modulate = Color.YELLOW

## Public API

## Gets current AI configuration
func get_current_ai_config() -> AIBehaviorConfig:
	return current_ai_config

## Checks if AI configuration is valid
func is_ai_config_valid() -> bool:
	return is_valid

## Gets validation errors
func get_validation_errors() -> Array[String]:
	return validation_errors.duplicate()

## Resets AI configuration to defaults
func reset_to_defaults() -> void:
	if not current_ai_config:
		return
	
	current_ai_config.ai_class = ""
	current_ai_config.combat_behavior = "default"
	current_ai_config.formation_behavior = "default"
	current_ai_config.aggressiveness = 1.0
	current_ai_config.accuracy = 1.0
	current_ai_config.evasion = 1.0
	current_ai_config.courage = 1.0
	current_ai_config.ai_goals.clear()
	
	# Update UI to reflect changes
	update_with_ai_config(current_ai_config)
	
	print("AIBehaviorController: AI configuration reset to defaults")

## Applies AI template configuration
func apply_ai_template(template_name: String) -> void:
	if not current_ai_config:
		return
	
	match template_name.to_lower():
		"fighter":
			current_ai_config.combat_behavior = "aggressive"
			current_ai_config.aggressiveness = 7.0
			current_ai_config.accuracy = 6.0
			current_ai_config.evasion = 8.0
			current_ai_config.courage = 7.0
		
		"bomber":
			current_ai_config.combat_behavior = "defensive"
			current_ai_config.aggressiveness = 4.0
			current_ai_config.accuracy = 8.0
			current_ai_config.evasion = 5.0
			current_ai_config.courage = 6.0
		
		"capital":
			current_ai_config.combat_behavior = "static"
			current_ai_config.aggressiveness = 3.0
			current_ai_config.accuracy = 9.0
			current_ai_config.evasion = 2.0
			current_ai_config.courage = 9.0
		
		"transport":
			current_ai_config.combat_behavior = "evasive"
			current_ai_config.aggressiveness = 1.0
			current_ai_config.accuracy = 3.0
			current_ai_config.evasion = 9.0
			current_ai_config.courage = 3.0
	
	# Update UI to reflect template changes
	update_with_ai_config(current_ai_config)
	
	print("AIBehaviorController: Applied AI template: %s" % template_name)