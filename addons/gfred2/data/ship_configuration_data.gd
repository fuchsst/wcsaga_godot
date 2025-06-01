@tool
class_name ShipConfigurationData
extends Resource

## Advanced ship configuration data for GFRED2-009 Advanced Ship Configuration.
## Provides comprehensive ship editing capabilities with AI behavior, weapons, and advanced properties.
## Integrates with WCS Asset Core structures for proper asset management.

signal configuration_changed(property_name: String, old_value: Variant, new_value: Variant)

# Basic ship properties
@export var ship_name: String = ""
@export var ship_class: String = ""
@export var alt_class: String = ""  # Alternative ship class
@export var team: int = 0
@export var hotkey: int = -1
@export var persona: int = -1
@export var cargo: String = ""
@export var alt_name: String = ""
@export var callsign: String = ""

# Advanced AI behavior configuration
@export var ai_behavior: AIBehaviorConfig = null
@export var wing_formation: WingFormationConfig = null

# Weapon loadout configuration
@export var weapon_loadouts: Array[WeaponLoadoutConfig] = []
@export var primary_weapons: Array[WeaponSlotConfig] = []
@export var secondary_weapons: Array[WeaponSlotConfig] = []

# Custom damage system
@export var damage_config: DamageSystemConfig = null

# Advanced hitpoint management
@export var hitpoint_config: HitpointConfig = null

# Ship textures and visual customization
@export var texture_config: TextureReplacementConfig = null

# Ship flags with behavior modifiers
@export var ship_flags: ShipFlagConfig = null

# Position and orientation
@export var position: Vector3 = Vector3.ZERO
@export var orientation: Vector3 = Vector3.ZERO

# Status settings
@export var initial_hull: float = 100.0
@export var initial_shields: float = 100.0
@export var initial_velocity: Vector3 = Vector3.ZERO

# Arrival and departure
@export var arrival_config: ArrivalDepartureConfig = null
@export var departure_config: ArrivalDepartureConfig = null

# Multi-ship batch editing support
@export var is_batch_edit: bool = false
@export var batch_edit_mask: Dictionary = {}  # Tracks which properties are batch-edited

## Initializes ship configuration with default values
func _init() -> void:
	ai_behavior = AIBehaviorConfig.new()
	wing_formation = WingFormationConfig.new()
	damage_config = DamageSystemConfig.new()
	hitpoint_config = HitpointConfig.new()
	texture_config = TextureReplacementConfig.new()
	ship_flags = ShipFlagConfig.new()
	arrival_config = ArrivalDepartureConfig.new()
	departure_config = ArrivalDepartureConfig.new()

## Sets a property value and emits change signal
func set_property(property_name: String, value: Variant) -> void:
	var old_value: Variant = get(property_name)
	if old_value != value:
		set(property_name, value)
		configuration_changed.emit(property_name, old_value, value)

## Validates ship configuration
func validate_configuration() -> Array[String]:
	var errors: Array[String] = []
	
	# Basic validation
	if ship_name.is_empty():
		errors.append("Ship name cannot be empty")
	
	if ship_class.is_empty():
		errors.append("Ship class must be selected")
	
	if team < 0 or team > 99:
		errors.append("Team must be between 0 and 99")
	
	# AI behavior validation
	if ai_behavior:
		var ai_errors: Array[String] = ai_behavior.validate()
		errors.append_array(ai_errors)
	
	# Weapon loadout validation
	for loadout in weapon_loadouts:
		var loadout_errors: Array[String] = loadout.validate()
		errors.append_array(loadout_errors)
	
	# Damage system validation
	if damage_config:
		var damage_errors: Array[String] = damage_config.validate()
		errors.append_array(damage_errors)
	
	# Hitpoint validation
	if hitpoint_config:
		var hitpoint_errors: Array[String] = hitpoint_config.validate()
		errors.append_array(hitpoint_errors)
	
	return errors

## Clones the configuration for multi-ship editing
func duplicate_for_batch_edit() -> ShipConfigurationData:
	var duplicate_config: ShipConfigurationData = ShipConfigurationData.new()
	
	# Copy all properties
	duplicate_config.ship_name = ship_name
	duplicate_config.ship_class = ship_class
	duplicate_config.alt_class = alt_class
	duplicate_config.team = team
	duplicate_config.hotkey = hotkey
	duplicate_config.persona = persona
	duplicate_config.cargo = cargo
	duplicate_config.alt_name = alt_name
	duplicate_config.callsign = callsign
	
	# Deep copy complex objects
	if ai_behavior:
		duplicate_config.ai_behavior = ai_behavior.duplicate()
	if wing_formation:
		duplicate_config.wing_formation = wing_formation.duplicate()
	if damage_config:
		duplicate_config.damage_config = damage_config.duplicate()
	if hitpoint_config:
		duplicate_config.hitpoint_config = hitpoint_config.duplicate()
	if texture_config:
		duplicate_config.texture_config = texture_config.duplicate()
	if ship_flags:
		duplicate_config.ship_flags = ship_flags.duplicate()
	if arrival_config:
		duplicate_config.arrival_config = arrival_config.duplicate()
	if departure_config:
		duplicate_config.departure_config = departure_config.duplicate()
	
	# Copy arrays
	duplicate_config.weapon_loadouts = weapon_loadouts.duplicate(true)
	duplicate_config.primary_weapons = primary_weapons.duplicate(true)
	duplicate_config.secondary_weapons = secondary_weapons.duplicate(true)
	
	# Copy other properties
	duplicate_config.position = position
	duplicate_config.orientation = orientation
	duplicate_config.initial_hull = initial_hull
	duplicate_config.initial_shields = initial_shields
	duplicate_config.initial_velocity = initial_velocity
	
	duplicate_config.is_batch_edit = true
	duplicate_config.batch_edit_mask = batch_edit_mask.duplicate()
	
	return duplicate_config

## Gets ship configuration summary for display
func get_configuration_summary() -> Dictionary:
	var summary: Dictionary = {}
	
	summary["ship_name"] = ship_name
	summary["ship_class"] = ship_class
	summary["team"] = team
	summary["weapon_count"] = primary_weapons.size() + secondary_weapons.size()
	summary["has_custom_ai"] = ai_behavior != null and ai_behavior.has_custom_behavior()
	summary["has_custom_damage"] = damage_config != null and damage_config.has_custom_damage()
	summary["has_texture_replacements"] = texture_config != null and texture_config.has_replacements()
	summary["flag_count"] = ship_flags.get_active_flag_count() if ship_flags else 0
	
	return summary

## AI Behavior Configuration
class AIBehaviorConfig extends Resource:

	@export var ai_class: String = ""
	@export var ai_goals: Array[AIGoalConfig] = []
	@export var combat_behavior: String = "default"
	@export var formation_behavior: String = "default"
	@export var aggressiveness: float = 1.0
	@export var accuracy: float = 1.0
	@export var evasion: float = 1.0
	@export var courage: float = 1.0

	func has_custom_behavior() -> bool:
		return ai_class != "" or ai_goals.size() > 0 or combat_behavior != "default"

	func validate() -> Array[String]:
		var errors: Array[String] = []
		
		if aggressiveness < 0.0 or aggressiveness > 10.0:
			errors.append("Aggressiveness must be between 0.0 and 10.0")
		
		if accuracy < 0.0 or accuracy > 10.0:
			errors.append("Accuracy must be between 0.0 and 10.0")
		
		return errors

	func duplicate() -> AIBehaviorConfig:
		var new_config: AIBehaviorConfig = AIBehaviorConfig.new()
		new_config.ai_class = ai_class
		new_config.ai_goals = ai_goals.duplicate(true)
		new_config.combat_behavior = combat_behavior
		new_config.formation_behavior = formation_behavior
		new_config.aggressiveness = aggressiveness
		new_config.accuracy = accuracy
		new_config.evasion = evasion
		new_config.courage = courage
		return new_config

## Wing Formation Configuration
class WingFormationConfig extends Resource:

	@export var formation_type: String = "default"
	@export var formation_distance: float = 100.0
	@export var formation_spread: float = 50.0
	@export var leader_ship: String = ""
	@export var formation_flags: Array[String] = []

	func duplicate() -> WingFormationConfig:
		var new_config: WingFormationConfig = WingFormationConfig.new()
		new_config.formation_type = formation_type
		new_config.formation_distance = formation_distance
		new_config.formation_spread = formation_spread
		new_config.leader_ship = leader_ship
		new_config.formation_flags = formation_flags.duplicate()
		return new_config

## Weapon Loadout Configuration
class WeaponLoadoutConfig extends Resource:

	@export var weapon_name: String = ""
	@export var weapon_class: String = ""
	@export var ammunition: int = 0
	@export var is_locked: bool = false

	func validate() -> Array[String]:
		var errors: Array[String] = []
		
		if weapon_name.is_empty():
			errors.append("Weapon name cannot be empty")
		
		if ammunition < 0:
			errors.append("Ammunition cannot be negative")
		
		return errors

## Weapon Slot Configuration
class WeaponSlotConfig extends Resource:

	@export var slot_index: int = 0
	@export var weapon_class: String = ""
	@export var ammunition: int = 0
	@export var is_dual_fire: bool = false
	@export var is_locked: bool = false

## Damage System Configuration
class DamageSystemConfig extends Resource:

	@export var damage_multiplier: float = 1.0
	@export var special_explosion_index: int = -1
	@export var subsystem_damage: Dictionary = {}  # subsystem_name -> damage_multiplier
	@export var invulnerable_subsystems: Array[String] = []

	func has_custom_damage() -> bool:
		return damage_multiplier != 1.0 or special_explosion_index != -1 or not subsystem_damage.is_empty()

	func validate() -> Array[String]:
		var errors: Array[String] = []
		
		if damage_multiplier < 0.0:
			errors.append("Damage multiplier cannot be negative")
		
		return errors

	func duplicate() -> DamageSystemConfig:
		var new_config: DamageSystemConfig = DamageSystemConfig.new()
		new_config.damage_multiplier = damage_multiplier
		new_config.special_explosion_index = special_explosion_index
		new_config.subsystem_damage = subsystem_damage.duplicate()
		new_config.invulnerable_subsystems = invulnerable_subsystems.duplicate()
		return new_config

## Hitpoint Configuration
class HitpointConfig extends Resource:

	@export var hull_strength: float = 100.0
	@export var shield_strength: float = 100.0
	@export var subsystem_hitpoints: Dictionary = {}  # subsystem_name -> hitpoints
	@export var shield_recharge_rate: float = 1.0
	@export var shield_regeneration: bool = true

	func validate() -> Array[String]:
		var errors: Array[String] = []
		
		if hull_strength <= 0.0:
			errors.append("Hull strength must be positive")
		
		if shield_strength < 0.0:
			errors.append("Shield strength cannot be negative")
		
		return errors

	func duplicate() -> HitpointConfig:
		var new_config: HitpointConfig = HitpointConfig.new()
		new_config.hull_strength = hull_strength
		new_config.shield_strength = shield_strength
		new_config.subsystem_hitpoints = subsystem_hitpoints.duplicate()
		new_config.shield_recharge_rate = shield_recharge_rate
		new_config.shield_regeneration = shield_regeneration
		return new_config

## Texture Replacement Configuration
class TextureReplacementConfig extends Resource:

	@export var texture_replacements: Dictionary = {}  # original_texture -> replacement_texture
	@export var detail_textures: Dictionary = {}       # detail_slot -> texture_path
	@export var glow_textures: Dictionary = {}         # glow_slot -> texture_path

	func has_replacements() -> bool:
		return not texture_replacements.is_empty() or not detail_textures.is_empty()

	func duplicate() -> TextureReplacementConfig:
		var new_config: TextureReplacementConfig = TextureReplacementConfig.new()
		new_config.texture_replacements = texture_replacements.duplicate()
		new_config.detail_textures = detail_textures.duplicate()
		new_config.glow_textures = glow_textures.duplicate()
		return new_config

## Ship Flag Configuration
class ShipFlagConfig extends Resource:

	@export var protect_ship: bool = false
	@export var beam_protect_ship: bool = false
	@export var escort: bool = false
	@export var invulnerable: bool = false
	@export var guardian: bool = false
	@export var vaporize: bool = false
	@export var stealth: bool = false
	@export var hidden_from_sensors: bool = false
	@export var scannable: bool = false
	@export var kamikaze: bool = false
	@export var no_dynamic: bool = false
	@export var red_alert_carry: bool = false
	@export var no_arrival_music: bool = false
	@export var no_arrival_warp: bool = false
	@export var no_departure_warp: bool = false
	@export var locked: bool = false
	@export var ignore_count: bool = false
	@export var escort_priority: int = 0
	@export var kamikaze_damage: int = 0
	@export var respawn_priority: int = 0

	func get_active_flag_count() -> int:
		var count: int = 0
		
		if protect_ship: count += 1
		if beam_protect_ship: count += 1
		if escort: count += 1
		if invulnerable: count += 1
		if guardian: count += 1
		if vaporize: count += 1
		if stealth: count += 1
		if hidden_from_sensors: count += 1
		if scannable: count += 1
		if kamikaze: count += 1
		if no_dynamic: count += 1
		if red_alert_carry: count += 1
		if no_arrival_music: count += 1
		if no_arrival_warp: count += 1
		if no_departure_warp: count += 1
		if locked: count += 1
		if ignore_count: count += 1
		
		return count

	func duplicate() -> ShipFlagConfig:
		var new_config: ShipFlagConfig = ShipFlagConfig.new()
		new_config.protect_ship = protect_ship
		new_config.beam_protect_ship = beam_protect_ship
		new_config.escort = escort
		new_config.invulnerable = invulnerable
		new_config.guardian = guardian
		new_config.vaporize = vaporize
		new_config.stealth = stealth
		new_config.hidden_from_sensors = hidden_from_sensors
		new_config.scannable = scannable
		new_config.kamikaze = kamikaze
		new_config.no_dynamic = no_dynamic
		new_config.red_alert_carry = red_alert_carry
		new_config.no_arrival_music = no_arrival_music
		new_config.no_arrival_warp = no_arrival_warp
		new_config.no_departure_warp = no_departure_warp
		new_config.locked = locked
		new_config.ignore_count = ignore_count
		new_config.escort_priority = escort_priority
		new_config.kamikaze_damage = kamikaze_damage
		new_config.respawn_priority = respawn_priority
		return new_config

## Arrival/Departure Configuration
class ArrivalDepartureConfig extends Resource:

	@export var location_type: String = "hyperspace"  # hyperspace, docking_bay, near_ship, etc.
	@export var target_ship: String = ""
	@export var distance: float = 1000.0
	@export var delay: float = 0.0
	@export var cue_expression: String = ""
	@export var path_mask: int = 0

	func duplicate() -> ArrivalDepartureConfig:
		var new_config: ArrivalDepartureConfig = ArrivalDepartureConfig.new()
		new_config.location_type = location_type
		new_config.target_ship = target_ship
		new_config.distance = distance
		new_config.delay = delay
		new_config.cue_expression = cue_expression
		new_config.path_mask = path_mask
		return new_config

## AI Goal Configuration
class AIGoalConfig extends Resource:

	@export var goal_type: String = ""
	@export var target: String = ""
	@export var priority: int = 89
	@export var flags: Array[String] = []
