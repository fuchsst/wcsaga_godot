@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

var mission_data: MissionData

var name_edit: LineEdit
var title_edit: LineEdit
var author_edit: LineEdit
var description_edit: TextEdit

func _ready():
	super._ready()
	
	# Get node references
	name_edit = $MarginContainer/VBoxContainer/GridContainer/NameEdit
	title_edit = $MarginContainer/VBoxContainer/GridContainer/TitleEdit
	author_edit = $MarginContainer/VBoxContainer/GridContainer/AuthorEdit
	description_edit = $MarginContainer/VBoxContainer/GridContainer/DescriptionEdit
	
	# Connect button signals
	var save_button = $MarginContainer/VBoxContainer/ButtonContainer/SaveButton
	var cancel_button = $MarginContainer/VBoxContainer/ButtonContainer/CancelButton
	
	save_button.pressed.connect(_on_ok_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

func show_dialog_with_mission(mission: MissionData):
	mission_data = mission
	
	# Populate fields
	name_edit.text = mission.name if mission.name else ""
	title_edit.text = mission.title if mission.title else ""
	author_edit.text = mission.author if mission.author else ""
	description_edit.text = mission.description if mission.description else ""
	
	show_dialog(Vector2(500, 400))

func _on_ok_pressed():
	# Update mission data
	mission_data.name = name_edit.text
	mission_data.title = title_edit.text
	mission_data.author = author_edit.text
	mission_data.description = description_edit.text
	
	super._on_ok_pressed()

func _on_cancel_pressed():
	super._on_cancel_pressed()
