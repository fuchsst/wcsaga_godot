@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

signal mission_selected(mission_data: MissionData)

var file_list: ItemList
var preview: TextEdit
var open_button: Button

var missions: Array[MissionData] = []

func _ready():
	super._ready()
	
	# Get node references
	file_list = $MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/FileList
	preview = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/Preview
	open_button = $MarginContainer/VBoxContainer/ButtonContainer/OpenButton
	
	# Connect signals
	file_list.item_selected.connect(_on_file_selected)
	open_button.pressed.connect(_on_ok_pressed)
	$MarginContainer/VBoxContainer/ButtonContainer/CancelButton.pressed.connect(_on_cancel_pressed)

func show_dialog(minsize: Vector2 = Vector2(800, 500)):
	# Clear previous state
	file_list.clear()
	preview.text = ""
	open_button.disabled = true
	missions.clear()
	
	# Load available missions
	var dir = DirAccess.open("res://assets/hermes_core")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".fs2"):
				var result = FS2Parser.parse_file("res://assets/hermes_core/" + file_name)
				if result.success:
					missions.append(result.mission)
					file_list.add_item(result.mission.name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	super.show_dialog(minsize)

func _on_file_selected(index: int):
	if index >= 0 and index < missions.size():
		var mission = missions[index]
		
		# Update preview
		var preview_text = ""
		preview_text += "Name: " + (mission.name if mission.name else "") + "\n"
		preview_text += "Title: " + (mission.title if mission.title else "") + "\n"
		preview_text += "Author: " + (mission.author if mission.author else "") + "\n"
		preview_text += "\nDescription:\n" + (mission.description if mission.description else "")
		
		preview.text = preview_text
		open_button.disabled = false

func _on_ok_pressed():
	var selected = file_list.get_selected_items()
	if selected.size() > 0:
		mission_selected.emit(missions[selected[0]])
	super._on_ok_pressed()

func _on_cancel_pressed():
	super._on_cancel_pressed()
