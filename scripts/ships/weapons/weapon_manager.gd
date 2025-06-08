class_name WeaponManager
extends Node

## Central weapon system coordinator for BaseShip
## Manages primary/secondary weapon banks, energy/ammunition tracking, and firing coordination
## Implementation of SHIP-005: Weapon Manager and Firing System

# EPIC-002 Asset Core Integration
const WeaponData = preload("res://addons/wcs_asset_core/structures/weapon_data.gd")
const WeaponBankType = preload("res://addons/wcs_asset_core/constants/weapon_bank_types.gd")
const WeaponBankConfig = preload("res://addons/wcs_asset_core/resources/ship/weapon_bank_config.gd")

# SHIP-005 Weapon System Components
const FiringController = preload("res://scripts/ships/weapons/firing_controller.gd")
const WeaponBank = preload("res://scripts/ships/weapons/weapon_bank.gd")
const WeaponSelectionManager = preload("res://scripts/ships/weapons/weapon_selection_manager.gd")
const TargetingSystem = preload("res://scripts/ships/weapons/targeting_system.gd")

# Weapon manager signals (SHIP-005 AC1, AC2)
signal weapon_fired(bank_type: WeaponBankType.Type, weapon_name: String, projectiles: Array[WeaponBase])
signal weapon_selection_changed(bank_type: WeaponBankType.Type, weapon_index: int)
signal ammunition_depleted(bank_type: WeaponBankType.Type, bank_index: int)
signal weapon_energy_changed(current_energy: float, max_energy: float)
signal weapon_overheated(bank_type: WeaponBankType.Type, bank_index: int)
signal target_acquired(target: Node3D, target_subsystem: Node)
signal target_lost()

# Ship integration
var ship: BaseShip
var ship_class: ShipClass

# Weapon system components
var firing_controller: FiringController
var selection_manager: WeaponSelectionManager
var targeting_system: TargetingSystem

# Weapon banks (SHIP-005 AC1)
var primary_weapon_banks: Array[WeaponBank] = []
var secondary_weapon_banks: Array[WeaponBank] = []
var beam_weapon_banks: Array[WeaponBank] = []
var turret_weapon_banks: Array[WeaponBank] = []

# Energy and ammunition tracking (SHIP-005 AC3, AC4)
var weapon_energy_consumption_rate: float = 0.0
var last_energy_regeneration_time: float = 0.0

# Weapon state tracking
var is_firing_primary: bool = false
var is_firing_secondary: bool = false
var can_fire_weapons: bool = true

# Current target
var current_target: Node3D = null
var current_target_subsystem: Node = null

func _ready() -> void:
	# Initialize weapon system components
	firing_controller = FiringController.new()
	add_child(firing_controller)
	
	selection_manager = WeaponSelectionManager.new()
	add_child(selection_manager)
	
	targeting_system = TargetingSystem.new()
	add_child(targeting_system)
	
	# Connect component signals
	_connect_component_signals()
	
	# Start energy regeneration timer
	last_energy_regeneration_time = Time.get_time_dict_from_system()

func _physics_process(delta: float) -> void:
	if not ship:
		return
	
	# Update weapon energy regeneration (SHIP-005 AC3)
	_process_weapon_energy_regeneration(delta)
	
	# Update firing state and timing
	_process_weapon_firing(delta)
	
	# Update targeting system
	targeting_system.update_targeting(delta)

## Initialize weapon manager with ship reference (SHIP-005 AC1)
func initialize_weapon_manager(parent_ship: BaseShip) -> void:
	ship = parent_ship
	ship_class = ship.ship_class
	
	if not ship_class:
		push_error("WeaponManager: Cannot initialize without valid ship class")
		return
	
	# Initialize weapon banks from ship class configuration
	_initialize_weapon_banks()
	
	# Configure firing controller
	firing_controller.initialize_firing_controller(ship)
	
	# Configure targeting system
	targeting_system.initialize_targeting_system(ship)
	
	# Configure weapon selection
	selection_manager.initialize_selection_manager(primary_weapon_banks, secondary_weapon_banks)

## Initialize weapon banks from ship class configuration (SHIP-005 AC1)
func _initialize_weapon_banks() -> void:
	# Clear existing banks
	primary_weapon_banks.clear()
	secondary_weapon_banks.clear()
	beam_weapon_banks.clear()
	turret_weapon_banks.clear()
	
	# Initialize primary weapon banks
	for i in range(ship_class.primary_weapon_slots.size()):
		var weapon_slot: String = ship_class.primary_weapon_slots[i]
		if not weapon_slot.is_empty():
			var weapon_bank: WeaponBank = _create_weapon_bank(WeaponBankType.Type.PRIMARY, i, weapon_slot)
			if weapon_bank:
				primary_weapon_banks.append(weapon_bank)
				add_child(weapon_bank)
	
	# Initialize secondary weapon banks
	for i in range(ship_class.secondary_weapon_slots.size()):
		var weapon_slot: String = ship_class.secondary_weapon_slots[i]
		if not weapon_slot.is_empty():
			var weapon_bank: WeaponBank = _create_weapon_bank(WeaponBankType.Type.SECONDARY, i, weapon_slot)
			if weapon_bank:
				secondary_weapon_banks.append(weapon_bank)
				add_child(weapon_bank)
	
	# Initialize beam weapon banks
	for i in range(ship_class.beam_weapon_slots.size()):
		var weapon_slot: String = ship_class.beam_weapon_slots[i]
		if not weapon_slot.is_empty():
			var weapon_bank: WeaponBank = _create_weapon_bank(WeaponBankType.Type.BEAM, i, weapon_slot)
			if weapon_bank:
				beam_weapon_banks.append(weapon_bank)
				add_child(weapon_bank)
	
	# Initialize turret weapon banks
	for i in range(ship_class.turret_weapon_slots.size()):
		var weapon_slot: String = ship_class.turret_weapon_slots[i]
		if not weapon_slot.is_empty():
			var weapon_bank: WeaponBank = _create_weapon_bank(WeaponBankType.Type.TURRET, i, weapon_slot)
			if weapon_bank:
				turret_weapon_banks.append(weapon_bank)
				add_child(weapon_bank)

## Create weapon bank from configuration (SHIP-005 AC1)
func _create_weapon_bank(bank_type: WeaponBankType.Type, bank_index: int, weapon_resource_path: String) -> WeaponBank:
	var weapon_data: WeaponData = load(weapon_resource_path)
	if not weapon_data:
		push_error("WeaponManager: Failed to load weapon data from %s" % weapon_resource_path)
		return null
	
	var weapon_bank: WeaponBank = WeaponBank.new()
	weapon_bank.initialize_weapon_bank(bank_type, bank_index, weapon_data, ship)
	
	# Connect weapon bank signals
	weapon_bank.weapon_fired.connect(_on_weapon_bank_fired)
	weapon_bank.ammunition_depleted.connect(_on_weapon_bank_ammunition_depleted)
	weapon_bank.weapon_overheated.connect(_on_weapon_bank_overheated)
	
	return weapon_bank

## Connect component signals for coordination
func _connect_component_signals() -> void:
	# Firing controller signals
	firing_controller.firing_sequence_started.connect(_on_firing_sequence_started)
	firing_controller.firing_sequence_completed.connect(_on_firing_sequence_completed)
	
	# Selection manager signals
	selection_manager.weapon_selection_changed.connect(_on_weapon_selection_changed)
	
	# Targeting system signals
	targeting_system.target_acquired.connect(_on_target_acquired)
	targeting_system.target_lost.connect(_on_target_lost)

## Fire primary weapons (SHIP-005 AC2, AC5)
func fire_primary_weapons() -> bool:
	if not can_fire_weapons or is_firing_primary:
		return false
	
	# Check weapon energy availability (SHIP-005 AC3)
	var energy_required: float = _calculate_primary_energy_cost()
	if ship.current_weapon_energy < energy_required:
		return false
	
	# Get selected primary weapon banks
	var selected_banks: Array[int] = selection_manager.get_selected_primary_banks()
	if selected_banks.is_empty():
		return false
	
	# Fire selected weapon banks
	var fired_successfully: bool = false
	for bank_index in selected_banks:
		if bank_index < primary_weapon_banks.size():
			var weapon_bank: WeaponBank = primary_weapon_banks[bank_index]
			if weapon_bank.can_fire():
				var firing_data: Dictionary = _prepare_firing_data(WeaponBankType.Type.PRIMARY)
				if firing_controller.fire_weapon_bank(weapon_bank, firing_data):
					fired_successfully = true
	
	# Consume weapon energy
	if fired_successfully:
		ship.consume_weapon_energy(energy_required)
		is_firing_primary = true
	
	return fired_successfully

## Fire secondary weapons (SHIP-005 AC2, AC4)
func fire_secondary_weapons() -> bool:
	if not can_fire_weapons or is_firing_secondary:
		return false
	
	# Get selected secondary weapon banks
	var selected_banks: Array[int] = selection_manager.get_selected_secondary_banks()
	if selected_banks.is_empty():
		return false
	
	# Fire selected weapon banks
	var fired_successfully: bool = false
	for bank_index in selected_banks:
		if bank_index < secondary_weapon_banks.size():
			var weapon_bank: WeaponBank = secondary_weapon_banks[bank_index]
			if weapon_bank.can_fire():
				var firing_data: Dictionary = _prepare_firing_data(WeaponBankType.Type.SECONDARY)
				if firing_controller.fire_weapon_bank(weapon_bank, firing_data):
					fired_successfully = true
	
	if fired_successfully:
		is_firing_secondary = true
	
	return fired_successfully

## Prepare firing data for weapon bank (SHIP-005 AC6)
func _prepare_firing_data(bank_type: WeaponBankType.Type) -> Dictionary:
	var firing_data: Dictionary = {}
	
	# Add target information
	firing_data["target"] = current_target
	firing_data["target_subsystem"] = current_target_subsystem
	
	# Add ship velocity for ballistics calculation
	firing_data["ship_velocity"] = ship.get_linear_velocity() if ship.has_method("get_linear_velocity") else Vector3.ZERO
	
	# Add targeting solution from targeting system
	var targeting_solution: Dictionary = targeting_system.get_firing_solution(current_target)
	firing_data["firing_solution"] = targeting_solution
	
	# Add convergence distance
	firing_data["convergence_distance"] = selection_manager.get_convergence_distance(bank_type)
	
	return firing_data

## Calculate primary weapon energy cost (SHIP-005 AC3)
func _calculate_primary_energy_cost() -> float:
	var total_cost: float = 0.0
	var selected_banks: Array[int] = selection_manager.get_selected_primary_banks()
	
	for bank_index in selected_banks:
		if bank_index < primary_weapon_banks.size():
			var weapon_bank: WeaponBank = primary_weapon_banks[bank_index]
			total_cost += weapon_bank.get_energy_cost()
	
	return total_cost

## Process weapon energy regeneration (SHIP-005 AC3)
func _process_weapon_energy_regeneration(delta: float) -> void:
	if not ship:
		return
	
	# Get weapon energy allocation from ETS
	var weapon_allocation: float = ship.get_weapon_energy_allocation()
	
	# Calculate regeneration rate based on ETS allocation
	var base_regeneration_rate: float = ship.weapon_energy_regeneration_rate
	var actual_regeneration_rate: float = base_regeneration_rate * weapon_allocation
	
	# Apply regeneration
	var energy_to_add: float = actual_regeneration_rate * delta
	ship.add_weapon_energy(energy_to_add)
	
	# Update energy consumption tracking
	weapon_energy_consumption_rate = weapon_energy_consumption_rate * 0.9  # Decay consumption rate

## Process weapon firing state updates (SHIP-005 AC2)
func _process_weapon_firing(delta: float) -> void:
	# Update firing states based on rate limiting
	if is_firing_primary:
		var can_continue_primary: bool = true
		var selected_banks: Array[int] = selection_manager.get_selected_primary_banks()
		for bank_index in selected_banks:
			if bank_index < primary_weapon_banks.size():
				var weapon_bank: WeaponBank = primary_weapon_banks[bank_index]
				if not weapon_bank.is_rate_limited():
					can_continue_primary = false
					break
		is_firing_primary = can_continue_primary
	
	if is_firing_secondary:
		var can_continue_secondary: bool = true
		var selected_banks: Array[int] = selection_manager.get_selected_secondary_banks()
		for bank_index in selected_banks:
			if bank_index < secondary_weapon_banks.size():
				var weapon_bank: WeaponBank = secondary_weapon_banks[bank_index]
				if not weapon_bank.is_rate_limited():
					can_continue_secondary = false
					break
		is_firing_secondary = can_continue_secondary

## Set weapon target (SHIP-005 AC6)
func set_weapon_target(target: Node3D, target_subsystem: Node = null) -> void:
	current_target = target
	current_target_subsystem = target_subsystem
	
	# Update targeting system
	targeting_system.set_target(target, target_subsystem)
	
	# Emit target change signal
	if target:
		target_acquired.emit(target, target_subsystem)
	else:
		target_lost.emit()

## Select weapon bank (SHIP-005 AC5)
func select_weapon_bank(bank_type: WeaponBankType.Type, bank_index: int) -> bool:
	return selection_manager.select_weapon_bank(bank_type, bank_index)

## Cycle weapon selection (SHIP-005 AC5)
func cycle_weapon_selection(bank_type: WeaponBankType.Type, forward: bool = true) -> bool:
	return selection_manager.cycle_weapon_selection(bank_type, forward)

## Set weapon linking mode (SHIP-005 AC5)
func set_weapon_linking_mode(bank_type: WeaponBankType.Type, linked: bool) -> void:
	selection_manager.set_weapon_linking_mode(bank_type, linked)

## Get weapon status information
func get_weapon_status() -> Dictionary:
	var status: Dictionary = {}
	
	# Primary weapon status
	status["primary_weapons"] = []
	for i in range(primary_weapon_banks.size()):
		var bank: WeaponBank = primary_weapon_banks[i]
		status["primary_weapons"].append(bank.get_weapon_status())
	
	# Secondary weapon status
	status["secondary_weapons"] = []
	for i in range(secondary_weapon_banks.size()):
		var bank: WeaponBank = secondary_weapon_banks[i]
		status["secondary_weapons"].append(bank.get_weapon_status())
	
	# Current target
	status["current_target"] = current_target.get_instance_id() if current_target else -1
	status["has_target_lock"] = targeting_system.has_target_lock() if targeting_system else false
	
	# Weapon energy
	status["weapon_energy"] = ship.current_weapon_energy if ship else 0.0
	status["max_weapon_energy"] = ship.max_weapon_energy if ship else 0.0
	status["weapon_energy_percent"] = (ship.current_weapon_energy / ship.max_weapon_energy) * 100.0 if ship and ship.max_weapon_energy > 0.0 else 0.0
	
	return status

## Enable/disable weapon systems (SHIP-005 AC7)
func set_weapons_enabled(enabled: bool) -> void:
	can_fire_weapons = enabled
	
	# Propagate to weapon banks
	for bank in primary_weapon_banks:
		bank.set_enabled(enabled)
	for bank in secondary_weapon_banks:
		bank.set_enabled(enabled)
	for bank in beam_weapon_banks:
		bank.set_enabled(enabled)
	for bank in turret_weapon_banks:
		bank.set_enabled(enabled)

## Signal handlers
func _on_weapon_bank_fired(bank_type: WeaponBankType.Type, weapon_name: String, projectiles: Array[WeaponBase]) -> void:
	# Emit weapon fired signal
	weapon_fired.emit(bank_type, weapon_name, projectiles)
	
	# Update energy consumption tracking
	var energy_consumed: float = 0.0
	for projectile in projectiles:
		if projectile.weapon_data:
			energy_consumed += projectile.weapon_data.energy_consumed
	weapon_energy_consumption_rate += energy_consumed

func _on_weapon_bank_ammunition_depleted(bank_type: WeaponBankType.Type, bank_index: int) -> void:
	ammunition_depleted.emit(bank_type, bank_index)

func _on_weapon_bank_overheated(bank_type: WeaponBankType.Type, bank_index: int) -> void:
	weapon_overheated.emit(bank_type, bank_index)

func _on_firing_sequence_started(bank_type: WeaponBankType.Type) -> void:
	# Update firing state
	match bank_type:
		WeaponBankType.Type.PRIMARY:
			is_firing_primary = true
		WeaponBankType.Type.SECONDARY:
			is_firing_secondary = true

func _on_firing_sequence_completed(bank_type: WeaponBankType.Type) -> void:
	# Update firing state
	match bank_type:
		WeaponBankType.Type.PRIMARY:
			is_firing_primary = false
		WeaponBankType.Type.SECONDARY:
			is_firing_secondary = false

func _on_weapon_selection_changed(bank_type: WeaponBankType.Type, weapon_index: int) -> void:
	weapon_selection_changed.emit(bank_type, weapon_index)

func _on_target_acquired(target: Node3D, target_subsystem: Node) -> void:
	current_target = target
	current_target_subsystem = target_subsystem
	target_acquired.emit(target, target_subsystem)

func _on_target_lost() -> void:
	current_target = null
	current_target_subsystem = null
	target_lost.emit()

## Debug information
func get_debug_info() -> String:
	var info: String = "WeaponManager Debug Info:\n"
	info += "  Primary Banks: %d\n" % primary_weapon_banks.size()
	info += "  Secondary Banks: %d\n" % secondary_weapon_banks.size()
	info += "  Current Target: %s\n" % (current_target.name if current_target else "None")
	info += "  Can Fire: %s\n" % can_fire_weapons
	info += "  Weapon Energy: %.1f / %.1f\n" % [ship.current_weapon_energy if ship else 0.0, ship.max_weapon_energy if ship else 0.0]
	return info