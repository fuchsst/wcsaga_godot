class_name GameStateShipSelect
extends LimboState

## Ship Selection State - Pre-mission ship loadout
## Allows player to choose ship and assign weapons

signal ship_selected(ship_class: String)
signal loadout_confirmed

const SHIP_SELECT_SCENE := "res://scenes/ui/loadout/ship_selection.tscn"

var _ship_select_scene: Control = null
var _selected_ship_index: int = 0
var _available_ships: Array = []
var _mission: Resource = null


func _enter() -> void:
	print("Entering Ship Selection State")

	var mm := _get_mission_manager()
	if mm and mm.current_mission:
		_mission = mm.current_mission
		_load_available_ships()

	_setup_ship_select_scene()


func _exit() -> void:
	print("Exiting Ship Selection State")
	_cleanup_scene()


func _update(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_confirm_selection()
	elif Input.is_action_just_pressed("ui_cancel"):
		_go_back()
	elif Input.is_action_just_pressed("ui_up"):
		_select_prev_ship()
	elif Input.is_action_just_pressed("ui_down"):
		_select_next_ship()


func _load_available_ships() -> void:
	_available_ships.clear()

	if not _mission:
		return

	# Get allowed ships from mission ship_choices
	if "ship_choices" in _mission:
		for choice in _mission.ship_choices:
			if "ship_class" in choice:
				_available_ships.append(choice.ship_class)

	# Fallback: load from ships manifest
	if _available_ships.is_empty():
		var ships_path := "res://assets/ships/ships.tres"
		if ResourceLoader.exists(ships_path):
			var manifest := load(ships_path)
			if manifest and "ships" in manifest:
				for ship_name in manifest.ships.keys():
					var ship: Resource = manifest.ships[ship_name]
					if ship and "flags" in ship:
						# Check if player-flyable
						if ship.flags & 1:  # PLAYER_FLYABLE flag
							_available_ships.append(ship_name)


func _setup_ship_select_scene() -> bool:
	if ResourceLoader.exists(SHIP_SELECT_SCENE):
		var scene := load(SHIP_SELECT_SCENE)
		if scene:
			_ship_select_scene = scene.instantiate()
			get_tree().root.add_child(_ship_select_scene)
			_connect_signals()
			_populate_ship_list()
			return true

	# Fallback UI
	_create_fallback_ui()
	return true


func _create_fallback_ui() -> void:
	_ship_select_scene = Control.new()
	_ship_select_scene.name = "ShipSelectOverlay"
	_ship_select_scene.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.2, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ship_select_scene.add_child(bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)
	_ship_select_scene.add_child(hbox)

	# Ship list panel
	var list_panel := PanelContainer.new()
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.custom_minimum_size.x = 300
	hbox.add_child(list_panel)

	var list_vbox := VBoxContainer.new()
	list_panel.add_child(list_vbox)

	var list_title := Label.new()
	list_title.text = "SELECT SHIP"
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_vbox.add_child(list_title)

	var item_list := ItemList.new()
	item_list.name = "ShipList"
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.item_selected.connect(_on_ship_item_selected)
	list_vbox.add_child(item_list)

	# Stats panel
	var stats_panel := PanelContainer.new()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(stats_panel)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.name = "StatsContainer"
	stats_panel.add_child(stats_vbox)

	var stats_title := Label.new()
	stats_title.text = "SHIP STATS"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_vbox.add_child(stats_title)

	var stats_label := Label.new()
	stats_label.name = "StatsLabel"
	stats_label.text = "Select a ship to view stats"
	stats_vbox.add_child(stats_label)

	# Buttons
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	list_vbox.add_child(btn_container)

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "Back"
	back_btn.pressed.connect(_go_back)
	btn_container.add_child(back_btn)

	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmButton"
	confirm_btn.text = "Confirm"
	confirm_btn.pressed.connect(_confirm_selection)
	btn_container.add_child(confirm_btn)

	get_tree().root.add_child(_ship_select_scene)
	_populate_ship_list()


func _connect_signals() -> void:
	if not _ship_select_scene:
		return

	var confirm_btn := _ship_select_scene.find_child("ConfirmButton", true, false)
	if confirm_btn and confirm_btn.has_signal("pressed"):
		if not confirm_btn.pressed.is_connected(_confirm_selection):
			confirm_btn.pressed.connect(_confirm_selection)

	var back_btn := _ship_select_scene.find_child("BackButton", true, false)
	if back_btn and back_btn.has_signal("pressed"):
		if not back_btn.pressed.is_connected(_go_back):
			back_btn.pressed.connect(_go_back)

	var ship_list := _ship_select_scene.find_child("ShipList", true, false)
	if ship_list and ship_list.has_signal("item_selected"):
		if not ship_list.item_selected.is_connected(_on_ship_item_selected):
			ship_list.item_selected.connect(_on_ship_item_selected)


func _populate_ship_list() -> void:
	var ship_list: ItemList = _ship_select_scene.find_child("ShipList", true, false)
	if not ship_list:
		return

	ship_list.clear()
	for ship_name in _available_ships:
		ship_list.add_item(ship_name)

	if not _available_ships.is_empty():
		ship_list.select(0)
		_on_ship_item_selected(0)


func _on_ship_item_selected(index: int) -> void:
	_selected_ship_index = index
	if index < _available_ships.size():
		var ship_name: String = _available_ships[index]
		ship_selected.emit(ship_name)
		_update_ship_stats(ship_name)


func _update_ship_stats(ship_name: String) -> void:
	var stats_label: Label = _ship_select_scene.find_child("StatsLabel", true, false)
	if not stats_label:
		return

	# Try to load ship stats
	var ship_path := "res://assets/ships/%s/%s.tres" % [ship_name.to_lower(), ship_name.to_lower()]
	if ResourceLoader.exists(ship_path):
		var ship_data := load(ship_path)
		if ship_data:
			var text := "Name: %s\n" % ship_name
			if "max_speed" in ship_data:
				text += "Max Speed: %.0f\n" % ship_data.max_speed
			if "max_hull_strength" in ship_data:
				text += "Hull: %.0f\n" % ship_data.max_hull_strength
			if "max_shield_strength" in ship_data:
				text += "Shields: %.0f\n" % ship_data.max_shield_strength
			stats_label.text = text
			return

	stats_label.text = "Ship: %s\n(Stats not available)" % ship_name


func _select_next_ship() -> void:
	if _available_ships.is_empty():
		return
	_selected_ship_index = (_selected_ship_index + 1) % _available_ships.size()
	var ship_list: ItemList = _ship_select_scene.find_child("ShipList", true, false)
	if ship_list:
		ship_list.select(_selected_ship_index)
	_on_ship_item_selected(_selected_ship_index)


func _select_prev_ship() -> void:
	if _available_ships.is_empty():
		return
	_selected_ship_index = (
		(_selected_ship_index - 1 + _available_ships.size()) % _available_ships.size()
	)
	var ship_list: ItemList = _ship_select_scene.find_child("ShipList", true, false)
	if ship_list:
		ship_list.select(_selected_ship_index)
	_on_ship_item_selected(_selected_ship_index)


func _confirm_selection() -> void:
	if _selected_ship_index < _available_ships.size():
		var ship_name: String = _available_ships[_selected_ship_index]
		print("Ship selected: %s" % ship_name)

		# Store selection in MissionManager
		var mm := _get_mission_manager()
		if mm and mm.has_method("set_player_ship"):
			mm.set_player_ship(ship_name)

		loadout_confirmed.emit()

		# Transition to weapon select
		var gsm := get_parent()
		if gsm and gsm.has_method("dispatch"):
			gsm.dispatch(&"to_weapon_select")


func _go_back() -> void:
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_briefing")


func _cleanup_scene() -> void:
	if _ship_select_scene and is_instance_valid(_ship_select_scene):
		_ship_select_scene.queue_free()
		_ship_select_scene = null


func _get_mission_manager() -> Node:
	if Engine.has_singleton("MissionManager"):
		return Engine.get_singleton("MissionManager")
	return get_node_or_null("/root/MissionManager")
