class_name WeaponSelectionManager
extends Node

## Weapon selection and linking manager for weapon banks
## Handles bank cycling, weapon linking, dual-fire modes, and selection validation
## Implementation of SHIP-005: Weapon Selection component

# EPIC-002 Asset Core Integration
const WeaponBankType = preload("res://addons/wcs_asset_core/constants/weapon_bank_types.gd")

# Weapon selection signals
signal weapon_selection_changed(bank_type: WeaponBankType.Type, weapon_index: int)
signal weapon_linking_changed(bank_type: WeaponBankType.Type, linked: bool)
signal dual_fire_mode_changed(enabled: bool)

# Weapon bank references
var primary_weapon_banks: Array[WeaponBank] = []
var secondary_weapon_banks: Array[WeaponBank] = []

# Primary weapon selection state (SHIP-005 AC5)
var selected_primary_bank: int = 0
var selected_primary_banks: Array[int] = []
var primary_weapons_linked: bool = false
var primary_dual_fire_mode: bool = false

# Secondary weapon selection state (SHIP-005 AC5)
var selected_secondary_bank: int = 0
var selected_secondary_banks: Array[int] = []
var secondary_weapons_linked: bool = false
var secondary_dual_fire_mode: bool = false

# Convergence settings
var primary_convergence_distance: float = 500.0
var secondary_convergence_distance: float = 1000.0

# Selection validation
var allow_empty_selection: bool = false
var auto_select_available: bool = true

func _ready() -> void:
	pass

## Initialize selection manager with weapon banks (SHIP-005 AC5)
func initialize_selection_manager(primary_banks: Array[WeaponBank], secondary_banks: Array[WeaponBank]) -> void:
	primary_weapon_banks = primary_banks
	secondary_weapon_banks = secondary_banks
	
	# Initialize selection state
	_initialize_primary_selection()
	_initialize_secondary_selection()

## Initialize primary weapon selection
func _initialize_primary_selection() -> void:
	if primary_weapon_banks.is_empty():
		selected_primary_bank = -1
		selected_primary_banks.clear()
		return
	
	# Select first available primary weapon
	for i in range(primary_weapon_banks.size()):
		var weapon_bank: WeaponBank = primary_weapon_banks[i]
		if weapon_bank and weapon_bank.can_fire():
			selected_primary_bank = i
			selected_primary_banks = [i]
			weapon_selection_changed.emit(WeaponBankType.Type.PRIMARY, i)
			return
	
	# No available weapons, select first anyway
	selected_primary_bank = 0
	selected_primary_banks = [0]
	weapon_selection_changed.emit(WeaponBankType.Type.PRIMARY, 0)

## Initialize secondary weapon selection
func _initialize_secondary_selection() -> void:
	if secondary_weapon_banks.is_empty():
		selected_secondary_bank = -1
		selected_secondary_banks.clear()
		return
	
	# Select first available secondary weapon
	for i in range(secondary_weapon_banks.size()):
		var weapon_bank: WeaponBank = secondary_weapon_banks[i]
		if weapon_bank and weapon_bank.can_fire():
			selected_secondary_bank = i
			selected_secondary_banks = [i]
			weapon_selection_changed.emit(WeaponBankType.Type.SECONDARY, i)
			return
	
	# No available weapons, select first anyway
	selected_secondary_bank = 0
	selected_secondary_banks = [0]
	weapon_selection_changed.emit(WeaponBankType.Type.SECONDARY, 0)

## Select specific weapon bank (SHIP-005 AC5)
func select_weapon_bank(bank_type: WeaponBankType.Type, bank_index: int) -> bool:
	match bank_type:
		WeaponBankType.Type.PRIMARY:
			return _select_primary_weapon_bank(bank_index)
		WeaponBankType.Type.SECONDARY:
			return _select_secondary_weapon_bank(bank_index)
		_:
			push_error("WeaponSelectionManager: Unsupported bank type for selection: %s" % bank_type)
			return false

## Select primary weapon bank
func _select_primary_weapon_bank(bank_index: int) -> bool:
	if bank_index < 0 or bank_index >= primary_weapon_banks.size():
		return false
	
	var weapon_bank: WeaponBank = primary_weapon_banks[bank_index]
	if not weapon_bank:
		return false
	
	# Validate selection
	if not _validate_weapon_selection(weapon_bank):
		if not allow_empty_selection:
			return false
	
	# Update selection
	selected_primary_bank = bank_index
	
	# Update selected banks based on linking mode
	if primary_weapons_linked:
		selected_primary_banks = _get_linked_primary_banks()
	else:
		selected_primary_banks = [bank_index]
	
	weapon_selection_changed.emit(WeaponBankType.Type.PRIMARY, bank_index)
	return true

## Select secondary weapon bank
func _select_secondary_weapon_bank(bank_index: int) -> bool:
	if bank_index < 0 or bank_index >= secondary_weapon_banks.size():
		return false
	
	var weapon_bank: WeaponBank = secondary_weapon_banks[bank_index]
	if not weapon_bank:
		return false
	
	# Validate selection
	if not _validate_weapon_selection(weapon_bank):
		if not allow_empty_selection:
			return false
	
	# Update selection
	selected_secondary_bank = bank_index
	
	# Update selected banks based on linking mode
	if secondary_weapons_linked:
		selected_secondary_banks = _get_linked_secondary_banks()
	else:
		selected_secondary_banks = [bank_index]
	
	weapon_selection_changed.emit(WeaponBankType.Type.SECONDARY, bank_index)
	return true

## Cycle weapon selection (SHIP-005 AC5)
func cycle_weapon_selection(bank_type: WeaponBankType.Type, forward: bool = true) -> bool:
	match bank_type:
		WeaponBankType.Type.PRIMARY:
			return _cycle_primary_weapon_selection(forward)
		WeaponBankType.Type.SECONDARY:
			return _cycle_secondary_weapon_selection(forward)
		_:
			push_error("WeaponSelectionManager: Unsupported bank type for cycling: %s" % bank_type)
			return false

## Cycle primary weapon selection
func _cycle_primary_weapon_selection(forward: bool) -> bool:
	if primary_weapon_banks.is_empty():
		return false
	
	var start_index: int = selected_primary_bank
	var current_index: int = start_index
	var direction: int = 1 if forward else -1
	
	# Find next available weapon
	for i in range(primary_weapon_banks.size()):
		current_index = (current_index + direction) % primary_weapon_banks.size()
		if current_index < 0:
			current_index = primary_weapon_banks.size() - 1
		
		# Check if this weapon is available
		var weapon_bank: WeaponBank = primary_weapon_banks[current_index]
		if weapon_bank and (allow_empty_selection or _validate_weapon_selection(weapon_bank)):
			return _select_primary_weapon_bank(current_index)
	
	# No available weapons found
	return false

## Cycle secondary weapon selection
func _cycle_secondary_weapon_selection(forward: bool) -> bool:
	if secondary_weapon_banks.is_empty():
		return false
	
	var start_index: int = selected_secondary_bank
	var current_index: int = start_index
	var direction: int = 1 if forward else -1
	
	# Find next available weapon
	for i in range(secondary_weapon_banks.size()):
		current_index = (current_index + direction) % secondary_weapon_banks.size()
		if current_index < 0:
			current_index = secondary_weapon_banks.size() - 1
		
		# Check if this weapon is available
		var weapon_bank: WeaponBank = secondary_weapon_banks[current_index]
		if weapon_bank and (allow_empty_selection or _validate_weapon_selection(weapon_bank)):
			return _select_secondary_weapon_bank(current_index)
	
	# No available weapons found
	return false

## Set weapon linking mode (SHIP-005 AC5)
func set_weapon_linking_mode(bank_type: WeaponBankType.Type, linked: bool) -> void:
	match bank_type:
		WeaponBankType.Type.PRIMARY:
			_set_primary_linking_mode(linked)
		WeaponBankType.Type.SECONDARY:
			_set_secondary_linking_mode(linked)
		_:
			push_error("WeaponSelectionManager: Unsupported bank type for linking: %s" % bank_type)

## Set primary weapon linking mode
func _set_primary_linking_mode(linked: bool) -> void:
	if primary_weapons_linked == linked:
		return
	
	primary_weapons_linked = linked
	
	# Update selected banks based on new linking mode
	if linked:
		selected_primary_banks = _get_linked_primary_banks()
	else:
		selected_primary_banks = [selected_primary_bank] if selected_primary_bank >= 0 else []
	
	weapon_linking_changed.emit(WeaponBankType.Type.PRIMARY, linked)

## Set secondary weapon linking mode
func _set_secondary_linking_mode(linked: bool) -> void:
	if secondary_weapons_linked == linked:
		return
	
	secondary_weapons_linked = linked
	
	# Update selected banks based on new linking mode
	if linked:
		selected_secondary_banks = _get_linked_secondary_banks()
	else:
		selected_secondary_banks = [selected_secondary_bank] if selected_secondary_bank >= 0 else []
	
	weapon_linking_changed.emit(WeaponBankType.Type.SECONDARY, linked)

## Set dual fire mode (fires both primary and secondary together)
func set_dual_fire_mode(enabled: bool) -> void:
	if primary_dual_fire_mode == enabled and secondary_dual_fire_mode == enabled:
		return
	
	primary_dual_fire_mode = enabled
	secondary_dual_fire_mode = enabled
	
	dual_fire_mode_changed.emit(enabled)

## Get linked primary weapon banks
func _get_linked_primary_banks() -> Array[int]:
	var linked_banks: Array[int] = []
	
	# Find all primary banks with the same weapon type as selected bank
	if selected_primary_bank >= 0 and selected_primary_bank < primary_weapon_banks.size():
		var selected_weapon: WeaponBank = primary_weapon_banks[selected_primary_bank]
		var selected_weapon_data = selected_weapon.get_weapon_data()
		
		for i in range(primary_weapon_banks.size()):
			var weapon_bank: WeaponBank = primary_weapon_banks[i]
			if weapon_bank and weapon_bank.get_weapon_data() == selected_weapon_data:
				linked_banks.append(i)
	
	return linked_banks

## Get linked secondary weapon banks
func _get_linked_secondary_banks() -> Array[int]:
	var linked_banks: Array[int] = []
	
	# Find all secondary banks with the same weapon type as selected bank
	if selected_secondary_bank >= 0 and selected_secondary_bank < secondary_weapon_banks.size():
		var selected_weapon: WeaponBank = secondary_weapon_banks[selected_secondary_bank]
		var selected_weapon_data = selected_weapon.get_weapon_data()
		
		for i in range(secondary_weapon_banks.size()):
			var weapon_bank: WeaponBank = secondary_weapon_banks[i]
			if weapon_bank and weapon_bank.get_weapon_data() == selected_weapon_data:
				linked_banks.append(i)
	
	return linked_banks

## Validate weapon selection
func _validate_weapon_selection(weapon_bank: WeaponBank) -> bool:
	if not weapon_bank:
		return false
	
	# Check if weapon bank can fire
	if auto_select_available and not weapon_bank.can_fire():
		return false
	
	# Check if weapon bank is enabled
	if not weapon_bank.is_enabled:
		return false
	
	return true

## Get selected primary weapon banks (SHIP-005 AC5)
func get_selected_primary_banks() -> Array[int]:
	return selected_primary_banks.duplicate()

## Get selected secondary weapon banks (SHIP-005 AC5)
func get_selected_secondary_banks() -> Array[int]:
	return selected_secondary_banks.duplicate()

## Get currently selected primary weapon bank index
func get_selected_primary_bank() -> int:
	return selected_primary_bank

## Get currently selected secondary weapon bank index
func get_selected_secondary_bank() -> int:
	return selected_secondary_bank

## Check if primary weapons are linked
func is_primary_weapons_linked() -> bool:
	return primary_weapons_linked

## Check if secondary weapons are linked
func is_secondary_weapons_linked() -> bool:
	return secondary_weapons_linked

## Check if dual fire mode is enabled
func is_dual_fire_mode_enabled() -> bool:
	return primary_dual_fire_mode and secondary_dual_fire_mode

## Set convergence distance for weapon type
func set_convergence_distance(bank_type: WeaponBankType.Type, distance: float) -> void:
	match bank_type:
		WeaponBankType.Type.PRIMARY:
			primary_convergence_distance = distance
		WeaponBankType.Type.SECONDARY:
			secondary_convergence_distance = distance

## Get convergence distance for weapon type
func get_convergence_distance(bank_type: WeaponBankType.Type) -> float:
	match bank_type:
		WeaponBankType.Type.PRIMARY:
			return primary_convergence_distance
		WeaponBankType.Type.SECONDARY:
			return secondary_convergence_distance
		_:
			return 500.0

## Get weapon selection status
func get_selection_status() -> Dictionary:
	var status: Dictionary = {}
	
	# Primary weapon status
	status["primary_selected_bank"] = selected_primary_bank
	status["primary_selected_banks"] = selected_primary_banks.duplicate()
	status["primary_weapons_linked"] = primary_weapons_linked
	status["primary_convergence_distance"] = primary_convergence_distance
	
	# Secondary weapon status
	status["secondary_selected_bank"] = selected_secondary_bank
	status["secondary_selected_banks"] = selected_secondary_banks.duplicate()
	status["secondary_weapons_linked"] = secondary_weapons_linked
	status["secondary_convergence_distance"] = secondary_convergence_distance
	
	# Dual fire mode
	status["dual_fire_mode"] = is_dual_fire_mode_enabled()
	
	# Available weapons count
	status["primary_banks_count"] = primary_weapon_banks.size()
	status["secondary_banks_count"] = secondary_weapon_banks.size()
	
	return status

## Get available weapon names for bank type
func get_available_weapon_names(bank_type: WeaponBankType.Type) -> Array[String]:
	var weapon_names: Array[String] = []
	
	match bank_type:
		WeaponBankType.Type.PRIMARY:
			for weapon_bank in primary_weapon_banks:
				if weapon_bank and weapon_bank.get_weapon_data():
					weapon_names.append(weapon_bank.get_weapon_data().weapon_name)
				else:
					weapon_names.append("Empty")
		WeaponBankType.Type.SECONDARY:
			for weapon_bank in secondary_weapon_banks:
				if weapon_bank and weapon_bank.get_weapon_data():
					weapon_names.append(weapon_bank.get_weapon_data().weapon_name)
				else:
					weapon_names.append("Empty")
	
	return weapon_names

## Force refresh selection based on current state
func refresh_selection() -> void:
	# Re-validate current selections
	if selected_primary_bank >= 0 and selected_primary_bank < primary_weapon_banks.size():
		var weapon_bank: WeaponBank = primary_weapon_banks[selected_primary_bank]
		if not _validate_weapon_selection(weapon_bank) and auto_select_available:
			# Try to find a new valid selection
			if not _cycle_primary_weapon_selection(true):
				# No valid weapons available
				if allow_empty_selection:
					selected_primary_banks.clear()
	
	if selected_secondary_bank >= 0 and selected_secondary_bank < secondary_weapon_banks.size():
		var weapon_bank: WeaponBank = secondary_weapon_banks[selected_secondary_bank]
		if not _validate_weapon_selection(weapon_bank) and auto_select_available:
			# Try to find a new valid selection
			if not _cycle_secondary_weapon_selection(true):
				# No valid weapons available
				if allow_empty_selection:
					selected_secondary_banks.clear()

## Configure selection behavior
func configure_selection_behavior(allow_empty: bool, auto_select: bool) -> void:
	allow_empty_selection = allow_empty
	auto_select_available = auto_select
	
	# Refresh selection with new behavior
	refresh_selection()

## Debug information
func get_debug_info() -> String:
	var info: String = "WeaponSelectionManager Debug Info:\n"
	info += "  Primary: Bank %d (Banks: %s)\n" % [selected_primary_bank, selected_primary_banks]
	info += "  Primary Linked: %s\n" % primary_weapons_linked
	info += "  Secondary: Bank %d (Banks: %s)\n" % [selected_secondary_bank, selected_secondary_banks]
	info += "  Secondary Linked: %s\n" % secondary_weapons_linked
	info += "  Dual Fire: %s\n" % is_dual_fire_mode_enabled()
	info += "  Available: P=%d, S=%d\n" % [primary_weapon_banks.size(), secondary_weapon_banks.size()]
	return info