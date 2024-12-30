@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

# Mission data reference
var mission_data: MissionData

# Currently selected goal
var current_goal: MissionGoal

func _ready():
	super._ready()
	
	# Get node references
	var goal_type = %GoalType
	var team = %Team
	
	# Setup goal types
	goal_type.clear()
	goal_type.add_item("Primary", MissionGoal.Type.PRIMARY)
	goal_type.add_item("Secondary", MissionGoal.Type.SECONDARY) 
	goal_type.add_item("Hidden", MissionGoal.Type.HIDDEN)
	
	# Setup teams
	team.clear()
	team.add_item("Friendly", 0)
	team.add_item("Hostile", 1)
	team.add_item("Neutral", 2)
	team.add_item("Unknown", 3)
	
	# Connect signals
	%GoalList.item_selected.connect(_on_goal_selected)
	%GoalType.item_selected.connect(_on_goal_type_changed)
	%GoalName.text_changed.connect(_on_goal_name_changed)
	%GoalDesc.text_changed.connect(_on_goal_desc_changed)
	%GoalScore.value_changed.connect(_on_goal_score_changed)
	%Team.item_selected.connect(_on_team_changed)
	%GoalInvalid.toggled.connect(_on_goal_invalid_toggled)
	%NoMusic.toggled.connect(_on_no_music_toggled)

func show_dialog_with_mission(mission: MissionData):
	mission_data = mission
	
	# Clear and populate goal list
	%GoalList.clear()
	
	# Add primary goals
	for goal in mission_data.primary_goals:
		%GoalList.add_item(goal.name)
		
	# Add secondary goals
	for goal in mission_data.secondary_goals:
		%GoalList.add_item(goal.name)
		
	# Add hidden goals
	for goal in mission_data.hidden_goals:
		%GoalList.add_item(goal.name)
	
	# Select first goal if any exist
	if %GoalList.item_count > 0:
		%GoalList.select(0)
		_on_goal_selected(0)
	else:
		_clear_goal_properties()
		
	show_dialog()

func _clear_goal_properties():
	current_goal = null
	%GoalType.selected = -1
	%GoalName.text = ""
	%GoalDesc.text = ""
	%GoalScore.value = 0
	%Team.selected = 0
	%GoalInvalid.button_pressed = false
	%NoMusic.button_pressed = false
	
	# Disable property controls
	%GoalType.disabled = true
	%GoalName.editable = false
	%GoalDesc.editable = false
	%GoalScore.editable = false
	%Team.disabled = true
	%GoalInvalid.disabled = true
	%NoMusic.disabled = true

func _update_goal_properties():
	if !current_goal:
		_clear_goal_properties()
		return
		
	# Enable property controls
	%GoalType.disabled = false
	%GoalName.editable = true
	%GoalDesc.editable = true
	%GoalScore.editable = true
	%Team.disabled = false
	%GoalInvalid.disabled = false
	%NoMusic.disabled = false
	
	# Update values
	%GoalType.selected = current_goal.type
	%GoalName.text = current_goal.name
	%GoalDesc.text = current_goal.text
	%GoalScore.value = current_goal.score
	%Team.selected = current_goal.team
	%GoalInvalid.button_pressed = current_goal.status == MissionGoal.Status.INVALID
	%NoMusic.button_pressed = current_goal.no_music

func _on_goal_selected(index: int):
	# Find selected goal
	var goal_name = %GoalList.get_item_text(index)
	
	# Search in all goal lists
	for goal in mission_data.primary_goals:
		if goal.name == goal_name:
			current_goal = goal
			break
			
	for goal in mission_data.secondary_goals:
		if goal.name == goal_name:
			current_goal = goal
			break
			
	for goal in mission_data.hidden_goals:
		if goal.name == goal_name:
			current_goal = goal
			break
	
	_update_goal_properties()

func _on_add_goal_pressed():
	# Create new goal
	var goal = MissionGoal.new()
	goal.name = "New Goal"
	goal.type = MissionGoal.Type.PRIMARY
	
	# Add to mission
	mission_data.primary_goals.append(goal)
	
	# Add to list and select
	%GoalList.add_item(goal.name)
	%GoalList.select(%GoalList.item_count - 1)
	_on_goal_selected(%GoalList.item_count - 1)

func _on_delete_goal_pressed():
	if !current_goal:
		return
		
	# Remove from appropriate list
	match current_goal.type:
		MissionGoal.Type.PRIMARY:
			mission_data.primary_goals.erase(current_goal)
		MissionGoal.Type.SECONDARY:
			mission_data.secondary_goals.erase(current_goal)
		MissionGoal.Type.HIDDEN:
			mission_data.hidden_goals.erase(current_goal)
	
	# Remove from list
	var selected = %GoalList.get_selected_items()[0]
	%GoalList.remove_item(selected)
	
	# Select next item if any
	if %GoalList.item_count > 0:
		var next_index = min(selected, %GoalList.item_count - 1)
		%GoalList.select(next_index)
		_on_goal_selected(next_index)
	else:
		_clear_goal_properties()

func _on_goal_type_changed(index: int):
	if !current_goal:
		return
		
	# Remove from old list
	match current_goal.type:
		MissionGoal.Type.PRIMARY:
			mission_data.primary_goals.erase(current_goal)
		MissionGoal.Type.SECONDARY:
			mission_data.secondary_goals.erase(current_goal)
		MissionGoal.Type.HIDDEN:
			mission_data.hidden_goals.erase(current_goal)
	
	# Update type
	current_goal.type = index
	
	# Add to new list
	match current_goal.type:
		MissionGoal.Type.PRIMARY:
			mission_data.primary_goals.append(current_goal)
		MissionGoal.Type.SECONDARY:
			mission_data.secondary_goals.append(current_goal)
		MissionGoal.Type.HIDDEN:
			mission_data.hidden_goals.append(current_goal)

func _on_goal_name_changed(new_text: String):
	if !current_goal:
		return
		
	current_goal.name = new_text
	
	# Update list item
	var selected = %GoalList.get_selected_items()[0]
	%GoalList.set_item_text(selected, new_text)

func _on_goal_desc_changed():
	if !current_goal:
		return
		
	current_goal.text = %GoalDesc.text

func _on_goal_score_changed(value: float):
	if !current_goal:
		return
		
	current_goal.score = int(value)

func _on_team_changed(index: int):
	if !current_goal:
		return
		
	current_goal.team = index

func _on_goal_invalid_toggled(button_pressed: bool):
	if !current_goal:
		return
		
	if button_pressed:
		current_goal.status = MissionGoal.Status.INVALID
	else:
		current_goal.status = MissionGoal.Status.INCOMPLETE

func _on_no_music_toggled(button_pressed: bool):
	if !current_goal:
		return
		
	current_goal.no_music = button_pressed

func _on_ok_pressed():
	# Validate goals
	var errors = []
	
	for goal in mission_data.primary_goals + mission_data.secondary_goals + mission_data.hidden_goals:
		var goal_errors = goal.validate()
		if !goal_errors.is_empty():
			errors.append_array(goal_errors)
	
	if !errors.is_empty():
		# Show error dialog
		var error_text = "The following errors were found:\n\n"
		for error in errors:
			error_text += "- " + error + "\n"
		
		var dialog = AcceptDialog.new()
		dialog.dialog_text = error_text
		add_child(dialog)
		dialog.popup_centered()
		await dialog.confirmed
		dialog.queue_free()
		return
	
	super._on_ok_pressed()

func _on_cancel_pressed():
	super._on_cancel_pressed()
