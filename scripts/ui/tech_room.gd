class_name TechRoom
extends Control

## Tech Room Scene Controller
##
## Database viewer for ships, weapons, and intel files.
## Uses target/assets for ship/weapon data, campaigns/fiction for intel.

signal item_selected(category: String, item_name: String)

enum Category { SHIPS, WEAPONS, INTEL }

const SHIP_MANIFEST_PATH := "res://assets/ships/ships.tres"
const WEAPON_MANIFEST_PATH := "res://assets/weapons/weapons.tres"

var _current_category: Category = Category.SHIPS
var _current_item_name: String = ""

# UI Nodes
var _category_tabs: TabBar = null
var _item_list: ItemList = null
var _info_panel: RichTextLabel = null
var _model_viewport: SubViewport = null
var _model_container: Node3D = null
var _back_button: Button = null

# Data
var _ships: Dictionary = {}
var _weapons: Dictionary = {}
var _intel: Dictionary = {}


func _ready() -> void:
	_setup_ui()
	_load_data()
	_populate_list()


func _setup_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_hbox)

	# Left panel - List
	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size.x = 300
	main_hbox.add_child(left_panel)

	_category_tabs = TabBar.new()
	_category_tabs.add_tab("Ships")
	_category_tabs.add_tab("Weapons")
	_category_tabs.add_tab("Intel")
	_category_tabs.tab_changed.connect(_on_category_changed)
	left_panel.add_child(_category_tabs)

	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	left_panel.add_child(_item_list)

	_back_button = Button.new()
	_back_button.text = "Back to Main Hall"
	_back_button.pressed.connect(_on_back_pressed)
	left_panel.add_child(_back_button)

	# Right panel - Details
	var right_panel := VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_panel)

	# 3D Model viewer (using SubViewportContainer)
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(400, 300)
	viewport_container.stretch = true
	right_panel.add_child(viewport_container)

	_model_viewport = SubViewport.new()
	_model_viewport.size = Vector2i(400, 300)
	_model_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(_model_viewport)

	# Setup 3D scene in viewport
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 5)
	_model_viewport.add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	_model_viewport.add_child(light)

	_model_container = Node3D.new()
	_model_container.name = "ModelContainer"
	_model_viewport.add_child(_model_container)

	# Info text
	var info_scroll := ScrollContainer.new()
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(info_scroll)

	_info_panel = RichTextLabel.new()
	_info_panel.bbcode_enabled = true
	_info_panel.fit_content = true
	_info_panel.custom_minimum_size.x = 400
	info_scroll.add_child(_info_panel)


func _load_data() -> void:
	_load_ships()
	_load_weapons()
	_load_intel()


func _load_ships() -> void:
	_ships.clear()
	if ResourceLoader.exists(SHIP_MANIFEST_PATH):
		var manifest := load(SHIP_MANIFEST_PATH)
		if manifest and "ships" in manifest:
			_ships = manifest.ships


func _load_weapons() -> void:
	_weapons.clear()
	if ResourceLoader.exists(WEAPON_MANIFEST_PATH):
		var manifest := load(WEAPON_MANIFEST_PATH)
		if manifest and "weapons" in manifest:
			_weapons = manifest.weapons


func _load_intel() -> void:
	_intel.clear()

	# Load from campaigns/hermes/fiction
	var intel_dirs := ["intel_file", "ace", "carrier", "star_system"]
	for dir_name in intel_dirs:
		var dir_path := "res://campaigns/hermes/fiction/%s" % dir_name
		_scan_intel_directory(dir_path, dir_name)


func _scan_intel_directory(path: String, category: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource_path := path + "/" + file_name
			if ResourceLoader.exists(resource_path):
				var intel_data := load(resource_path)
				if intel_data:
					var key := file_name.get_basename()
					_intel[key] = {"data": intel_data, "category": category, "path": resource_path}
		file_name = dir.get_next()
	dir.list_dir_end()


func _populate_list() -> void:
	_item_list.clear()

	match _current_category:
		Category.SHIPS:
			for ship_name in _ships.keys():
				_item_list.add_item(ship_name)
		Category.WEAPONS:
			for weapon_name in _weapons.keys():
				_item_list.add_item(weapon_name)
		Category.INTEL:
			for intel_name in _intel.keys():
				_item_list.add_item(intel_name)


func _on_category_changed(tab_index: int) -> void:
	_current_category = tab_index as Category
	_populate_list()
	_clear_details()


func _on_item_selected(index: int) -> void:
	var item_name := _item_list.get_item_text(index)
	_current_item_name = item_name
	item_selected.emit(_get_category_name(), item_name)
	_show_item_details(item_name)


func _get_category_name() -> String:
	match _current_category:
		Category.SHIPS:
			return "ships"
		Category.WEAPONS:
			return "weapons"
		Category.INTEL:
			return "intel"
	return ""


func _show_item_details(item_name: String) -> void:
	match _current_category:
		Category.SHIPS:
			_show_ship_details(item_name)
		Category.WEAPONS:
			_show_weapon_details(item_name)
		Category.INTEL:
			_show_intel_details(item_name)


func _show_ship_details(ship_name: String) -> void:
	if not ship_name in _ships:
		return

	var ship_data = _ships[ship_name]
	var text := "[b]%s[/b]\n\n" % ship_name

	if "description" in ship_data:
		text += ship_data.description + "\n\n"

	text += "[b]Specifications[/b]\n"
	if "max_speed" in ship_data:
		text += "Max Speed: %.0f\n" % ship_data.max_speed
	if "max_hull_strength" in ship_data:
		text += "Hull Strength: %.0f\n" % ship_data.max_hull_strength
	if "max_shield_strength" in ship_data:
		text += "Shield Strength: %.0f\n" % ship_data.max_shield_strength
	if "afterburner_max_speed" in ship_data:
		text += "Afterburner Speed: %.0f\n" % ship_data.afterburner_max_speed

	_info_panel.text = text
	_load_model(ship_name, "ships")


func _show_weapon_details(weapon_name: String) -> void:
	if not weapon_name in _weapons:
		return

	var weapon_data = _weapons[weapon_name]
	var text := "[b]%s[/b]\n\n" % weapon_name

	if "description" in weapon_data:
		text += weapon_data.description + "\n\n"

	text += "[b]Specifications[/b]\n"
	if "damage" in weapon_data:
		text += "Damage: %.0f\n" % weapon_data.damage
	if "fire_rate" in weapon_data:
		text += "Fire Rate: %.1f/s\n" % weapon_data.fire_rate
	if "velocity" in weapon_data:
		text += "Velocity: %.0f m/s\n" % weapon_data.velocity
	if "range" in weapon_data:
		text += "Range: %.0f m\n" % weapon_data.range

	_info_panel.text = text
	_load_model(weapon_name, "weapons")


func _show_intel_details(intel_name: String) -> void:
	if not intel_name in _intel:
		return

	var intel_entry: Dictionary = _intel[intel_name]
	var intel_data: Resource = intel_entry.data

	var text := "[b]%s[/b]\n\n" % intel_name

	if "description" in intel_data:
		text += intel_data.description + "\n\n"

	if "content" in intel_data:
		text += intel_data.content

	_info_panel.text = text
	_clear_model()


func _load_model(item_name: String, category: String) -> void:
	_clear_model()

	var model_path := (
		"res://assets/%s/%s/%s.glb" % [category, item_name.to_lower(), item_name.to_lower()]
	)

	if not ResourceLoader.exists(model_path):
		model_path = (
			"res://assets/%s/%s/%s.tscn" % [category, item_name.to_lower(), item_name.to_lower()]
		)

	if ResourceLoader.exists(model_path):
		var model_scene := load(model_path)
		if model_scene:
			var model_instance: Node3D = model_scene.instantiate()
			_model_container.add_child(model_instance)

			# Auto-rotate model
			var tween := create_tween().set_loops()
			tween.tween_property(model_instance, "rotation:y", TAU, 10.0)


func _clear_model() -> void:
	for child in _model_container.get_children():
		child.queue_free()


func _clear_details() -> void:
	_info_panel.text = "Select an item to view details."
	_clear_model()


func _on_back_pressed() -> void:
	var gsm := get_node_or_null("/root/GameStateMachine")
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_main_menu")
