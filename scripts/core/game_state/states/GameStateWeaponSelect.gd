class_name GameStateWeaponSelect
extends LimboState

## Weapon Selection State - Pre-mission weapon loadout
## Allows player to configure weapon banks

signal loadout_confirmed

const WEAPON_SELECT_SCENE := "res://scenes/ui/loadout/weapon_selection.tscn"

var _weapon_select_scene: Control = null
var _selected_bank: int = 0
var _weapon_banks: Array = []  # Array of weapon names
var _available_weapons: Array = []
var _mission: Resource = null


func _enter() -> void:
	print("Entering Weapon Selection State")

	var mm := _get_mission_manager()
	if mm and mm.current_mission:
		_mission = mm.current_mission
		_load_available_weapons()
		_load_default_loadout()

	_setup_weapon_select_scene()


func _exit() -> void:
	print("Exiting Weapon Selection State")
	_cleanup_scene()


func _update(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_confirm_loadout()
	elif Input.is_action_just_pressed("ui_cancel"):
		_go_back()


func _load_available_weapons() -> void:
	_available_weapons.clear()

	if not _mission:
		return

	# Get weapons from mission weaponry pool
	if "weaponry_pool" in _mission:
		for item in _mission.weaponry_pool:
			if "weapon_class" in item:
				_available_weapons.append(item.weapon_class)

	# Fallback: load from weapons manifest
	if _available_weapons.is_empty():
		var weapons_path := "res://assets/weapons/weapons.tres"
		if ResourceLoader.exists(weapons_path):
			var manifest := load(weapons_path)
			if manifest and "weapons" in manifest:
				for weapon_name in manifest.weapons.keys():
					_available_weapons.append(weapon_name)


func _load_default_loadout() -> void:
	_weapon_banks.clear()
	# Default to 4 empty banks
	for i in range(4):
		_weapon_banks.append("")

	# Load defaults from mission if available
	if _mission and "player" in _mission:
		var player_data = _mission.player
		if "weapons" in player_data:
			for i in range(min(player_data.weapons.size(), _weapon_banks.size())):
				_weapon_banks[i] = player_data.weapons[i]


func _setup_weapon_select_scene() -> bool:
	if ResourceLoader.exists(WEAPON_SELECT_SCENE):
		var scene := load(WEAPON_SELECT_SCENE)
		if scene:
			_weapon_select_scene = scene.instantiate()
			get_tree().root.add_child(_weapon_select_scene)
			_connect_signals()
			_populate_ui()
			return true

	_create_fallback_ui()
	return true


func _create_fallback_ui() -> void:
	_weapon_select_scene = Control.new()
	_weapon_select_scene.name = "WeaponSelectOverlay"
	_weapon_select_scene.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.15, 0.2, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weapon_select_scene.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(600, 400)
	_weapon_select_scene.add_child(vbox)

	var title := Label.new()
	title.text = "WEAPON LOADOUT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Weapon banks container
	var banks_hbox := HBoxContainer.new()
	banks_hbox.name = "BanksContainer"
	banks_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	banks_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(banks_hbox)

	for i in range(4):
		var bank_panel := PanelContainer.new()
		bank_panel.name = "Bank%d" % i
		bank_panel.custom_minimum_size = Vector2(120, 150)
		banks_hbox.add_child(bank_panel)

		var bank_vbox := VBoxContainer.new()
		bank_panel.add_child(bank_vbox)

		var bank_label := Label.new()
		bank_label.text = "Bank %d" % (i + 1)
		bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bank_vbox.add_child(bank_label)

		var weapon_btn := OptionButton.new()
		weapon_btn.name = "WeaponOption%d" % i
		weapon_btn.add_item("Empty", 0)
		for j in range(_available_weapons.size()):
			weapon_btn.add_item(_available_weapons[j], j + 1)
		weapon_btn.item_selected.connect(_on_weapon_selected.bind(i))
		bank_vbox.add_child(weapon_btn)

	# Buttons
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "Back"
	back_btn.pressed.connect(_go_back)
	btn_container.add_child(back_btn)

	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmButton"
	confirm_btn.text = "Launch Mission"
	confirm_btn.pressed.connect(_confirm_loadout)
	btn_container.add_child(confirm_btn)

	get_tree().root.add_child(_weapon_select_scene)
	_populate_ui()


func _connect_signals() -> void:
	if not _weapon_select_scene:
		return

	var confirm_btn := _weapon_select_scene.find_child("ConfirmButton", true, false)
	if confirm_btn and confirm_btn.has_signal("pressed"):
		if not confirm_btn.pressed.is_connected(_confirm_loadout):
			confirm_btn.pressed.connect(_confirm_loadout)

	var back_btn := _weapon_select_scene.find_child("BackButton", true, false)
	if back_btn and back_btn.has_signal("pressed"):
		if not back_btn.pressed.is_connected(_go_back):
			back_btn.pressed.connect(_go_back)


func _populate_ui() -> void:
	for i in range(_weapon_banks.size()):
		var option_btn: OptionButton = _weapon_select_scene.find_child(
			"WeaponOption%d" % i, true, false
		)
		if option_btn:
			var weapon_name: String = _weapon_banks[i]
			if weapon_name.is_empty():
				option_btn.select(0)
			else:
				var idx := _available_weapons.find(weapon_name)
				if idx >= 0:
					option_btn.select(idx + 1)


func _on_weapon_selected(item_index: int, bank_index: int) -> void:
	if item_index == 0:
		_weapon_banks[bank_index] = ""
	elif item_index - 1 < _available_weapons.size():
		_weapon_banks[bank_index] = _available_weapons[item_index - 1]


func _confirm_loadout() -> void:
	print("Weapon loadout confirmed: %s" % str(_weapon_banks))

	# Store loadout in MissionManager
	var mm := _get_mission_manager()
	if mm and mm.has_method("set_player_weapons"):
		mm.set_player_weapons(_weapon_banks)

	loadout_confirmed.emit()

	# Transition to gameplay
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"start_game")


func _go_back() -> void:
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_ship_select")


func _cleanup_scene() -> void:
	if _weapon_select_scene and is_instance_valid(_weapon_select_scene):
		_weapon_select_scene.queue_free()
		_weapon_select_scene = null


func _get_mission_manager() -> Node:
	if Engine.has_singleton("MissionManager"):
		return Engine.get_singleton("MissionManager")
	return get_node_or_null("/root/MissionManager")
