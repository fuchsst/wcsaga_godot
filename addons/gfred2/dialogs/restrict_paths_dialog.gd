@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

var is_arrival := true
var path_mask := 0
var ship_class := -1

@onready var path_list: ItemList = get_content_container().get_node("PathList")
@onready var select_all_button: Button = get_content_container().get_node("ButtonContainer/SelectAllButton")
@onready var clear_button: Button = get_content_container().get_node("ButtonContainer/ClearButton")
@onready var invert_button: Button = get_content_container().get_node("ButtonContainer/InvertButton")

func _ready():
	super._ready()
	title = "Restrict " + ("Arrival" if is_arrival else "Departure") + " Paths"
	
	# Connect signals
	select_all_button.pressed.connect(_on_select_all_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	invert_button.pressed.connect(_on_invert_pressed)
	path_list.item_selected.connect(_on_path_selected)
	path_list.item_deselected.connect(_on_path_deselected)
	
	# Populate paths
	_populate_paths()

func _populate_paths():
	path_list.clear()
	
	# Get paths from ship class
	if ship_class >= 0:
		# TODO: Get actual paths from ship class
		# For now just add test paths
		for i in range(8):
			var path_name = "Path %d" % (i + 1)
			path_list.add_item(path_name)
			
			# Check if path is enabled in mask
			if path_mask & (1 << i):
				path_list.select(i)

func _on_select_all_pressed():
	for i in range(path_list.item_count):
		path_list.select(i)
		path_mask |= (1 << i)

func _on_clear_pressed():
	path_list.deselect_all()
	path_mask = 0

func _on_invert_pressed():
	for i in range(path_list.item_count):
		if path_list.is_selected(i):
			path_list.deselect(i)
			path_mask &= ~(1 << i)
		else:
			path_list.select(i)
			path_mask |= (1 << i)

func _on_path_selected(index: int):
	path_mask |= (1 << index)

func _on_path_deselected(index: int):
	path_mask &= ~(1 << index)
