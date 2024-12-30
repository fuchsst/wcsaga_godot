@tool
extends Node

signal file_menu_item_selected(id: int)
signal edit_menu_item_selected(id: int)
signal view_menu_item_selected(id: int)
signal editors_menu_item_selected(id: int)

var menu_bar: Control

func setup_menus(menu_bar_node: Control):
	menu_bar = menu_bar_node
	_setup_file_menu()
	_setup_edit_menu()
	_setup_view_menu()
	_setup_editors_menu()

func _setup_file_menu():
	var file_menu = menu_bar.get_node("FileMenu")
	var popup = file_menu.get_popup()
	popup.clear()
	
	popup.add_item("New Mission", 0)
	popup.add_item("Open Mission...", 1)
	popup.add_separator()
	popup.add_item("Save Mission", 2)
	popup.add_item("Save Mission As...", 3)
	popup.add_separator()
	popup.add_item("Import FreeSpace Mission...", 4)
	popup.add_separator()
	popup.add_item("Exit", 5)
	
	popup.id_pressed.connect(_on_file_menu_item_selected)

func _setup_edit_menu():
	var edit_menu = menu_bar.get_node("EditMenu")
	var popup = edit_menu.get_popup()
	popup.clear()
	
	popup.add_item("Undo", 0)
	popup.add_item("Redo", 1)
	popup.add_separator()
	popup.add_item("Cut", 2)
	popup.add_item("Copy", 3)
	popup.add_item("Paste", 4)
	popup.add_item("Delete", 5)
	popup.add_separator()
	popup.add_item("Select All", 6)
	popup.add_item("Deselect All", 7)
	
	popup.id_pressed.connect(_on_edit_menu_item_selected)

func _setup_view_menu():
	var view_menu = menu_bar.get_node("ViewMenu")
	var popup = view_menu.get_popup()
	popup.clear()
	
	popup.add_check_item("Show Grid", 0)
	popup.add_check_item("Show Ships", 1)
	popup.add_check_item("Show Waypoints", 2)
	popup.add_check_item("Show Coordinates", 3)
	popup.add_check_item("Show Distances", 4)
	popup.add_check_item("Show Outlines", 5)
	popup.add_separator()
	popup.add_item("Top View", 6)
	popup.add_item("Front View", 7)
	popup.add_item("Side View", 8)
	popup.add_item("Perspective View", 9)
	
	popup.id_pressed.connect(_on_view_menu_item_selected)

func _setup_editors_menu():
	var editors_menu = menu_bar.get_node("EditorsMenu")
	var popup = editors_menu.get_popup()
	popup.clear()
	
	popup.add_item("Mission Specs", 0)
	popup.add_item("Ship Editor", 1)
	popup.add_item("Wing Editor", 2)
	popup.add_item("Event Editor", 3)
	popup.add_item("Message Editor", 4)
	popup.add_item("Briefing Editor", 5)
	popup.add_item("Debriefing Editor", 6)
	popup.add_item("Background Editor", 7)
	popup.add_item("Asteroid Field Editor", 8)
	
	popup.id_pressed.connect(_on_editors_menu_item_selected)

func _on_file_menu_item_selected(id: int):
	file_menu_item_selected.emit(id)

func _on_edit_menu_item_selected(id: int):
	edit_menu_item_selected.emit(id)

func _on_view_menu_item_selected(id: int):
	view_menu_item_selected.emit(id)

func _on_editors_menu_item_selected(id: int):
	editors_menu_item_selected.emit(id)
