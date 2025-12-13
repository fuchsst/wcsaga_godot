class_name WeaponSelection
extends Control

## Weapon Selection UI
##
## Allows player to configure weapon loadout for their ship.

signal loadout_confirmed(weapons: Array)
signal back_pressed

const WEAPON_STATS_PATH := "res://assets/weapons/weapons.tres"

@export var num_primary_banks: int = 2
@export var num_secondary_banks: int = 2

var _weapon_manifest: Resource = null
var _available_primaries: Array[String] = []
var _available_secondaries: Array[String] = []
var _primary_loadout: Array[String] = []
var _secondary_loadout: Array[String] = []

@onready
var primary_container: VBoxContainer = $HSplitContainer/LoadoutPanel/PrimarySection/BankContainer
@onready
var secondary_container: VBoxContainer = $HSplitContainer/LoadoutPanel/SecondarySection/BankContainer
@onready var weapon_list: ItemList = $HSplitContainer/WeaponPool/WeaponList
@onready var stats_label: RichTextLabel = $HSplitContainer/WeaponPool/StatsPanel/StatsLabel
@onready var confirm_button: Button = $HSplitContainer/LoadoutPanel/ButtonContainer/ConfirmButton
@onready var back_button: Button = $HSplitContainer/LoadoutPanel/ButtonContainer/BackButton


func _ready() -> void:
	_load_weapon_manifest()
	_setup_connections()
	_initialize_loadout()
	_populate_weapon_list()
	_create_bank_slots()


func _setup_connections() -> void:
	if weapon_list:
		weapon_list.item_selected.connect(_on_weapon_selected)
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _load_weapon_manifest() -> void:
	if ResourceLoader.exists(WEAPON_STATS_PATH):
		_weapon_manifest = load(WEAPON_STATS_PATH)
		if _weapon_manifest and "weapons" in _weapon_manifest:
			for weapon_name: String in _weapon_manifest.weapons.keys():
				var weapon: Resource = _weapon_manifest.weapons[weapon_name]
				if weapon and "weapon_type" in weapon:
					# 0 = primary, 1 = secondary
					if weapon.weapon_type == 0:
						_available_primaries.append(weapon_name)
					else:
						_available_secondaries.append(weapon_name)


func _initialize_loadout() -> void:
	_primary_loadout.clear()
	_secondary_loadout.clear()
	for i in range(num_primary_banks):
		_primary_loadout.append("")
	for i in range(num_secondary_banks):
		_secondary_loadout.append("")


func set_ship_banks(primaries: int, secondaries: int) -> void:
	num_primary_banks = primaries
	num_secondary_banks = secondaries
	_initialize_loadout()
	_create_bank_slots()


func set_available_weapons(primaries: Array, secondaries: Array) -> void:
	_available_primaries.clear()
	_available_secondaries.clear()
	for w in primaries:
		if w is String:
			_available_primaries.append(w)
	for w in secondaries:
		if w is String:
			_available_secondaries.append(w)
	_populate_weapon_list()


func _populate_weapon_list() -> void:
	if not weapon_list:
		return

	weapon_list.clear()

	# Add primaries
	for weapon_name: String in _available_primaries:
		weapon_list.add_item("[P] " + weapon_name)

	# Add secondaries
	for weapon_name: String in _available_secondaries:
		weapon_list.add_item("[S] " + weapon_name)


func _create_bank_slots() -> void:
	# Create primary bank option buttons
	if primary_container:
		for child in primary_container.get_children():
			child.queue_free()

		for i in range(num_primary_banks):
			var hbox := HBoxContainer.new()
			var label := Label.new()
			label.text = "Bank %d:" % (i + 1)
			label.custom_minimum_size.x = 60
			hbox.add_child(label)

			var option := OptionButton.new()
			option.name = "PrimaryBank%d" % i
			option.add_item("Empty", 0)
			for j in range(_available_primaries.size()):
				option.add_item(_available_primaries[j], j + 1)
			option.item_selected.connect(_on_primary_bank_changed.bind(i))
			hbox.add_child(option)

			primary_container.add_child(hbox)

	# Create secondary bank option buttons
	if secondary_container:
		for child in secondary_container.get_children():
			child.queue_free()

		for i in range(num_secondary_banks):
			var hbox := HBoxContainer.new()
			var label := Label.new()
			label.text = "Bank %d:" % (i + 1)
			label.custom_minimum_size.x = 60
			hbox.add_child(label)

			var option := OptionButton.new()
			option.name = "SecondaryBank%d" % i
			option.add_item("Empty", 0)
			for j in range(_available_secondaries.size()):
				option.add_item(_available_secondaries[j], j + 1)
			option.item_selected.connect(_on_secondary_bank_changed.bind(i))
			hbox.add_child(option)

			secondary_container.add_child(hbox)


func _on_weapon_selected(index: int) -> void:
	var weapon_name := ""

	if index < _available_primaries.size():
		weapon_name = _available_primaries[index]
	else:
		var sec_index := index - _available_primaries.size()
		if sec_index < _available_secondaries.size():
			weapon_name = _available_secondaries[sec_index]

	_update_stats_display(weapon_name)


func _update_stats_display(weapon_name: String) -> void:
	if not stats_label or weapon_name.is_empty():
		if stats_label:
			stats_label.text = "Select a weapon to view stats"
		return

	var text := "[b]%s[/b]\n\n" % weapon_name

	if _weapon_manifest and "weapons" in _weapon_manifest:
		if weapon_name in _weapon_manifest.weapons:
			var weapon: Resource = _weapon_manifest.weapons[weapon_name]
			if weapon:
				text += "[u]Stats[/u]\n"
				if "damage" in weapon:
					text += "Damage: %.0f\n" % weapon.damage
				if "fire_wait" in weapon:
					text += "Fire Rate: %.1f/s\n" % (1.0 / weapon.fire_wait)
				if "velocity" in weapon:
					text += "Velocity: %.0f m/s\n" % weapon.velocity
				if "lifetime" in weapon:
					var range_val: float = (
						weapon.velocity * weapon.lifetime if "velocity" in weapon else 0
					)
					text += "Range: %.0f m\n" % range_val
				if "energy_consumed" in weapon:
					text += "Energy: %.1f\n" % weapon.energy_consumed

	stats_label.text = text


func _on_primary_bank_changed(item_index: int, bank_index: int) -> void:
	if bank_index < _primary_loadout.size():
		if item_index == 0:
			_primary_loadout[bank_index] = ""
		elif item_index - 1 < _available_primaries.size():
			_primary_loadout[bank_index] = _available_primaries[item_index - 1]


func _on_secondary_bank_changed(item_index: int, bank_index: int) -> void:
	if bank_index < _secondary_loadout.size():
		if item_index == 0:
			_secondary_loadout[bank_index] = ""
		elif item_index - 1 < _available_secondaries.size():
			_secondary_loadout[bank_index] = _available_secondaries[item_index - 1]


func _on_confirm_pressed() -> void:
	var full_loadout: Array = []
	full_loadout.append_array(_primary_loadout)
	full_loadout.append_array(_secondary_loadout)
	loadout_confirmed.emit(full_loadout)


func _on_back_pressed() -> void:
	back_pressed.emit()


func get_loadout() -> Dictionary:
	return {
		"primaries": _primary_loadout.duplicate(), "secondaries": _secondary_loadout.duplicate()
	}
