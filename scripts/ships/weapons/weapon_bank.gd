class_name WeaponBank
extends Node3D

## Individual weapon bank implementation managing weapon mounting, ammunition, and firing state
## Handles weapon-specific behavior including energy consumption, ammunition tracking, and mount positioning
## Implementation of SHIP-005: Weapon Bank component

# EPIC-002 Asset Core Integration
const WeaponData = preload("res://addons/wcs_asset_core/structures/weapon_data.gd")
const WeaponBankType = preload("res://addons/wcs_asset_core/constants/weapon_bank_types.gd")

# Basic weapon projectile system
const WeaponBase = preload("res://scripts/object/weapon_base.gd")

# Weapon bank signals
signal weapon_fired(bank_type: WeaponBankType.Type, weapon_name: String, projectiles: Array[WeaponBase])
signal ammunition_depleted(bank_type: WeaponBankType.Type, bank_index: int)
signal weapon_overheated(bank_type: WeaponBankType.Type, bank_index: int)
signal ammunition_changed(current_ammo: int, max_ammo: int)
signal weapon_enabled_changed(enabled: bool)

# Weapon bank configuration
var bank_type: WeaponBankType.Type
var bank_index: int
var weapon_data: WeaponData
var ship: BaseShip

# Weapon mounting configuration
var mount_position: Vector3 = Vector3.ZERO
var mount_orientation: Vector3 = Vector3.ZERO
var convergence_distance: float = 500.0

# Ammunition tracking (SHIP-005 AC4)
var current_ammunition: int = -1  # -1 for unlimited (energy weapons)
var max_ammunition: int = -1
var ammunition_type: String = ""

# Weapon state
var is_enabled: bool = true
var is_overheated: bool = false
var overheat_level: float = 0.0
var last_fire_time: float = 0.0
var heat_dissipation_rate: float = 1.0

# Burst fire tracking
var burst_shots_remaining: int = 0
var last_burst_shot_time: float = 0.0

# Visual mount point marker
var mount_marker: Node3D

func _ready() -> void:
	# Create visual mount point marker for debugging
	_create_mount_marker()
	
	# Start heat dissipation processing
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	# Process weapon heat dissipation
	_process_heat_dissipation(delta)

## Initialize weapon bank with configuration (SHIP-005 AC1)
func initialize_weapon_bank(type: WeaponBankType.Type, index: int, data: WeaponData, parent_ship: BaseShip) -> void:
	bank_type = type
	bank_index = index
	weapon_data = data
	ship = parent_ship
	
	if not weapon_data:
		push_error("WeaponBank: Cannot initialize without valid weapon data")
		return
	
	# Configure ammunition based on weapon type
	_configure_ammunition()
	
	# Configure heat management
	_configure_heat_management()
	
	# Configure mount position (will be set by ship configuration)
	_configure_mount_position()

## Configure ammunition based on weapon type (SHIP-005 AC4)
func _configure_ammunition() -> void:
	if not weapon_data:
		return
	
	# Primary weapons (energy) have unlimited ammunition
	if bank_type == WeaponBankType.Type.PRIMARY:
		current_ammunition = -1
		max_ammunition = -1
		ammunition_type = "energy"
	# Secondary weapons (missiles) have limited ammunition
	elif bank_type == WeaponBankType.Type.SECONDARY:
		max_ammunition = weapon_data.cargo_size if weapon_data.has("cargo_size") else 10
		current_ammunition = max_ammunition
		ammunition_type = "missile"
	# Beam weapons have unlimited ammunition but high energy cost
	elif bank_type == WeaponBankType.Type.BEAM:
		current_ammunition = -1
		max_ammunition = -1
		ammunition_type = "energy"
	# Turret weapons depend on weapon type
	elif bank_type == WeaponBankType.Type.TURRET:
		if weapon_data.subtype == 0:  # Primary-type turret
			current_ammunition = -1
			max_ammunition = -1
			ammunition_type = "energy"
		else:  # Secondary-type turret
			max_ammunition = weapon_data.cargo_size if weapon_data.has("cargo_size") else 20
			current_ammunition = max_ammunition
			ammunition_type = "missile"

## Configure heat management system
func _configure_heat_management() -> void:
	if not weapon_data:
		return
	
	# Set heat dissipation rate based on weapon type
	match bank_type:
		WeaponBankType.Type.PRIMARY:
			heat_dissipation_rate = 2.0  # Fast cooling for energy weapons
		WeaponBankType.Type.SECONDARY:
			heat_dissipation_rate = 1.0  # Standard cooling for missiles
		WeaponBankType.Type.BEAM:
			heat_dissipation_rate = 0.5  # Slow cooling for beam weapons
		WeaponBankType.Type.TURRET:
			heat_dissipation_rate = 1.5  # Moderate cooling for turrets

## Configure mount position from ship configuration
func _configure_mount_position() -> void:
	# Mount position will be set by ship configuration
	# Default to origin until configured
	mount_position = Vector3.ZERO
	mount_orientation = Vector3.ZERO
	
	# Update mount marker position
	if mount_marker:
		mount_marker.position = mount_position

## Check if weapon bank can fire (SHIP-005 AC2)
func can_fire() -> bool:
	if not is_enabled or not weapon_data:
		return false
	
	# Check overheat state
	if is_overheated:
		return false
	
	# Check ammunition availability
	if current_ammunition == 0:
		return false
	
	# Check rate limiting
	if _is_rate_limited():
		return false
	
	# Check burst fire state
	if burst_shots_remaining > 0:
		return _can_continue_burst()
	
	return true

## Check if weapon is rate limited
func _is_rate_limited() -> bool:
	if not weapon_data:
		return true
	
	var current_time: float = Time.get_ticks_msec()
	var time_since_last_fire: float = current_time - last_fire_time
	
	# Calculate required interval based on fire rate (in milliseconds)
	var fire_rate: float = weapon_data.fire_rate if weapon_data.has("fire_rate") else 1.0
	var required_interval: float = (1000.0 / fire_rate) if fire_rate > 0.0 else 1000.0
	
	return time_since_last_fire < required_interval

## Check if burst fire can continue
func _can_continue_burst() -> bool:
	if burst_shots_remaining <= 0:
		return false
	
	var current_time: float = Time.get_ticks_msec()
	var time_since_last_burst_shot: float = current_time - last_burst_shot_time
	
	# Get burst delay from weapon data (convert to milliseconds)
	var burst_delay: float = weapon_data.burst_delay if weapon_data.has("burst_delay") else 0.1
	var burst_delay_ms: float = burst_delay * 1000.0
	
	return time_since_last_burst_shot >= burst_delay_ms

## Consume shot (ammunition or energy) (SHIP-005 AC3, AC4)
func consume_shot() -> bool:
	if not can_fire():
		return false
	
	# Update fire time
	last_fire_time = Time.get_ticks_msec()
	
	# Consume ammunition if limited
	if current_ammunition > 0:
		current_ammunition -= 1
		ammunition_changed.emit(current_ammunition, max_ammunition)
		
		# Check for ammunition depletion
		if current_ammunition == 0:
			ammunition_depleted.emit(bank_type, bank_index)
	
	# Add heat generation
	var heat_generated: float = weapon_data.heat_generated if weapon_data.has("heat_generated") else 0.1
	overheat_level += heat_generated
	
	# Check for overheat
	var overheat_threshold: float = weapon_data.overheat_threshold if weapon_data.has("overheat_threshold") else 1.0
	if overheat_level >= overheat_threshold:
		is_overheated = true
		weapon_overheated.emit(bank_type, bank_index)
	
	# Handle burst fire
	if weapon_data.has("burst_shots") and weapon_data.burst_shots > 1:
		if burst_shots_remaining <= 0:
			burst_shots_remaining = weapon_data.burst_shots - 1  # Already fired one
		else:
			burst_shots_remaining -= 1
		last_burst_shot_time = Time.get_ticks_msec()
	
	return true

## Get energy cost for firing this weapon (SHIP-005 AC3)
func get_energy_cost() -> float:
	if not weapon_data:
		return 0.0
	
	# Energy weapons consume weapon energy
	if ammunition_type == "energy":
		return weapon_data.energy_consumed if weapon_data.has("energy_consumed") else 1.0
	
	# Missile weapons may have small energy cost for launching
	return weapon_data.energy_consumed * 0.1 if weapon_data.has("energy_consumed") else 0.1

## Process heat dissipation
func _process_heat_dissipation(delta: float) -> void:
	if overheat_level > 0.0:
		overheat_level -= heat_dissipation_rate * delta
		overheat_level = max(0.0, overheat_level)
		
		# Check if weapon has cooled down enough to stop overheating
		if is_overheated:
			var cooldown_threshold: float = 0.3  # Cool down to 30% before allowing firing
			var overheat_threshold: float = weapon_data.overheat_threshold if weapon_data and weapon_data.has("overheat_threshold") else 1.0
			if overheat_level <= overheat_threshold * cooldown_threshold:
				is_overheated = false

## Reload/rearm weapon bank (SHIP-005 AC4)
func reload_ammunition(amount: int = -1) -> bool:
	# Cannot reload energy weapons
	if ammunition_type == "energy":
		return false
	
	if amount < 0:
		# Full reload
		current_ammunition = max_ammunition
	else:
		# Partial reload
		current_ammunition = min(current_ammunition + amount, max_ammunition)
	
	ammunition_changed.emit(current_ammunition, max_ammunition)
	return true

## Set weapon bank mount position and orientation
func set_mount_configuration(position: Vector3, orientation: Vector3, convergence: float = 500.0) -> void:
	mount_position = position
	mount_orientation = orientation
	convergence_distance = convergence
	
	# Update visual position
	self.position = mount_position
	self.rotation_degrees = mount_orientation
	
	# Update mount marker
	if mount_marker:
		mount_marker.position = Vector3.ZERO  # Relative to weapon bank

## Enable/disable weapon bank (SHIP-005 AC7)
func set_enabled(enabled: bool) -> void:
	is_enabled = enabled
	weapon_enabled_changed.emit(enabled)

## Get weapon status information
func get_weapon_status() -> Dictionary:
	var status: Dictionary = {}
	
	# Basic information
	status["weapon_name"] = weapon_data.weapon_name if weapon_data else "Unknown"
	status["bank_type"] = WeaponBankType.Type.keys()[bank_type]
	status["bank_index"] = bank_index
	status["is_enabled"] = is_enabled
	
	# Ammunition status
	status["current_ammunition"] = current_ammunition
	status["max_ammunition"] = max_ammunition
	status["ammunition_type"] = ammunition_type
	status["ammunition_percent"] = (float(current_ammunition) / float(max_ammunition)) * 100.0 if max_ammunition > 0 else 100.0
	
	# Heat status
	status["overheat_level"] = overheat_level
	status["is_overheated"] = is_overheated
	status["heat_percent"] = (overheat_level / (weapon_data.overheat_threshold if weapon_data and weapon_data.has("overheat_threshold") else 1.0)) * 100.0
	
	# Firing status
	status["can_fire"] = can_fire()
	status["is_rate_limited"] = _is_rate_limited()
	status["burst_shots_remaining"] = burst_shots_remaining
	
	# Mount configuration
	status["mount_position"] = mount_position
	status["mount_orientation"] = mount_orientation
	status["convergence_distance"] = convergence_distance
	
	return status

## Get weapon data reference
func get_weapon_data() -> WeaponData:
	return weapon_data

## Get bank type
func get_bank_type() -> WeaponBankType.Type:
	return bank_type

## Get bank index
func get_bank_index() -> int:
	return bank_index

## Get mount position
func get_mount_position() -> Vector3:
	return mount_position

## Get mount orientation
func get_mount_orientation() -> Vector3:
	return mount_orientation

## Check if weapon bank is rate limited
func is_rate_limited() -> bool:
	return _is_rate_limited()

## Create visual mount marker for debugging
func _create_mount_marker() -> void:
	# Create a small sphere to mark the weapon mount point
	mount_marker = MeshInstance3D.new()
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.1
	sphere_mesh.height = 0.2
	mount_marker.mesh = sphere_mesh
	
	# Create basic material
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.emission_enabled = true
	material.emission = Color.YELLOW * 0.3
	mount_marker.material_override = material
	
	add_child(mount_marker)
	
	# Hide marker by default (can be enabled for debugging)
	mount_marker.visible = false

## Enable/disable mount marker visibility for debugging
func set_mount_marker_visible(visible: bool) -> void:
	if mount_marker:
		mount_marker.visible = visible

## Get weapon performance rating for AI use
func get_weapon_performance_rating() -> float:
	if not weapon_data:
		return 0.0
	
	var rating: float = 1.0
	
	# Reduce rating based on ammunition depletion
	if max_ammunition > 0:
		rating *= float(current_ammunition) / float(max_ammunition)
	
	# Reduce rating based on overheat level
	var overheat_threshold: float = weapon_data.overheat_threshold if weapon_data.has("overheat_threshold") else 1.0
	rating *= 1.0 - (overheat_level / overheat_threshold)
	
	# Reduce rating if disabled
	if not is_enabled:
		rating = 0.0
	
	return clamp(rating, 0.0, 1.0)

## Get weapon effective range
func get_effective_range() -> float:
	if not weapon_data:
		return 500.0
	
	# Calculate effective range based on weapon speed and lifetime
	var max_speed: float = weapon_data.max_speed if weapon_data.has("max_speed") else 100.0
	var lifetime: float = weapon_data.lifetime if weapon_data.has("lifetime") else 5.0
	
	return max_speed * lifetime

## Get weapon damage per second rating
func get_dps_rating() -> float:
	if not weapon_data:
		return 0.0
	
	var damage: float = weapon_data.damage if weapon_data.has("damage") else 10.0
	var fire_rate: float = weapon_data.fire_rate if weapon_data.has("fire_rate") else 1.0
	
	return damage * fire_rate

## Debug information
func get_debug_info() -> String:
	var info: String = "WeaponBank Debug Info:\n"
	info += "  Weapon: %s\n" % (weapon_data.weapon_name if weapon_data else "None")
	info += "  Type: %s[%d]\n" % [WeaponBankType.Type.keys()[bank_type], bank_index]
	info += "  Ammunition: %s / %s\n" % [current_ammunition if current_ammunition >= 0 else "∞", max_ammunition if max_ammunition >= 0 else "∞"]
	info += "  Heat: %.2f (Overheated: %s)\n" % [overheat_level, is_overheated]
	info += "  Can Fire: %s\n" % can_fire()
	info += "  Mount: %s\n" % mount_position
	return info