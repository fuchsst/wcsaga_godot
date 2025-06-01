@tool
class_name ReinforcementData
extends Resource

## Reinforcement data structure for GFRED2-010 Mission Component Editors.
## Defines reinforcement waves with arrival conditions and ship specifications.

signal data_changed(property_name: String, old_value: Variant, new_value: Variant)

# Basic reinforcement properties
@export var reinforcement_id: String = ""
@export var reinforcement_name: String = ""
@export var description: String = ""

# Ship configuration
@export var ship_class: String = ""
@export var ship_count: int = 4
@export var wing_formation: String = "default"
@export var ai_class: String = "default"

# Wave properties
@export var wave_count: int = 1
@export var wave_delay: float = 30.0  # Delay between waves in seconds
@export var priority: int = 50  # Priority for arrival (1-100)

# Arrival conditions
@export var arrival_delay: float = 0.0
@export var arrival_cue: SexpNode = null
@export var arrival_anchor: String = ""  # Reference point for arrival
@export var arrival_distance: float = 1000.0

# Advanced properties
@export var no_messages: bool = false
@export var flags: Array[String] = []
@export var hotkey: int = -1

# Ship customization
@export var custom_loadout: Array[String] = []  # Weapon loadout override
@export var ship_flags: Array[String] = []  # Per-ship flags
@export var custom_ai_goals: Array[String] = []  # AI behavior override

func _init() -> void:
	# Initialize with default values
	reinforcement_id = "reinforcement_" + str(randi() % 10000)
	reinforcement_name = "New Reinforcement"
	ship_class = "GTF Ulysses"
	ship_count = 4
	wave_count = 1
	priority = 50
	arrival_delay = 30.0

func _set(property: StringName, value: Variant) -> bool:
	var old_value: Variant = get(property)
	var result: bool = false
	
	match property:
		"reinforcement_id":
			reinforcement_id = value as String
			result = true
		"reinforcement_name":
			reinforcement_name = value as String
			result = true
		"description":
			description = value as String
			result = true
		"ship_class":
			ship_class = value as String
			result = true
		"ship_count":
			ship_count = max(1, value as int)
			result = true
		"wing_formation":
			wing_formation = value as String
			result = true
		"ai_class":
			ai_class = value as String
			result = true
		"wave_count":
			wave_count = max(1, value as int)
			result = true
		"wave_delay":
			wave_delay = max(0.0, value as float)
			result = true
		"priority":
			priority = clamp(value as int, 1, 100)
			result = true
		"arrival_delay":
			arrival_delay = max(0.0, value as float)
			result = true
		"arrival_cue":
			arrival_cue = value as SexpNode
			result = true
		"arrival_anchor":
			arrival_anchor = value as String
			result = true
		"arrival_distance":
			arrival_distance = max(0.0, value as float)
			result = true
		"no_messages":
			no_messages = value as bool
			result = true
		"flags":
			flags = value as Array[String]
			result = true
		"hotkey":
			hotkey = value as int
			result = true
		"custom_loadout":
			custom_loadout = value as Array[String]
			result = true
		"ship_flags":
			ship_flags = value as Array[String]
			result = true
		"custom_ai_goals":
			custom_ai_goals = value as Array[String]
			result = true
	
	if result:
		data_changed.emit(property, old_value, value)
	
	return result

## Validates the reinforcement data
func validate() -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	
	# Validate basic properties
	if reinforcement_id.is_empty():
		result.add_error("Reinforcement ID cannot be empty")
	
	if reinforcement_name.is_empty():
		result.add_error("Reinforcement name cannot be empty")
	
	if ship_class.is_empty():
		result.add_error("Ship class must be specified")
	
	# Validate numeric constraints
	if ship_count <= 0:
		result.add_error("Ship count must be greater than 0")
	
	if wave_count <= 0:
		result.add_error("Wave count must be greater than 0")
	
	if priority < 1 or priority > 100:
		result.add_error("Priority must be between 1 and 100")
	
	if arrival_delay < 0.0:
		result.add_error("Arrival delay cannot be negative")
	
	if wave_delay < 0.0:
		result.add_error("Wave delay cannot be negative")
	
	if arrival_distance < 0.0:
		result.add_error("Arrival distance cannot be negative")
	
	# Validate arrival cue if present
	if arrival_cue and arrival_cue.has_method("validate"):
		var cue_result: ValidationResult = arrival_cue.validate()
		if not cue_result.is_valid():
			for error in cue_result.get_errors():
				result.add_error("Arrival cue: %s" % error)
	
	return result

## Duplicates the reinforcement data
func duplicate(deep: bool = true) -> ReinforcementData:
	var copy: ReinforcementData = ReinforcementData.new()
	
	copy.reinforcement_id = reinforcement_id + "_copy"
	copy.reinforcement_name = reinforcement_name + " Copy"
	copy.description = description
	copy.ship_class = ship_class
	copy.ship_count = ship_count
	copy.wing_formation = wing_formation
	copy.ai_class = ai_class
	copy.wave_count = wave_count
	copy.wave_delay = wave_delay
	copy.priority = priority
	copy.arrival_delay = arrival_delay
	copy.arrival_anchor = arrival_anchor
	copy.arrival_distance = arrival_distance
	copy.no_messages = no_messages
	copy.hotkey = hotkey
	
	# Deep copy arrays
	copy.flags = flags.duplicate()
	copy.custom_loadout = custom_loadout.duplicate()
	copy.ship_flags = ship_flags.duplicate()
	copy.custom_ai_goals = custom_ai_goals.duplicate()
	
	# Deep copy arrival cue if present
	if arrival_cue and deep:
		copy.arrival_cue = arrival_cue.duplicate() if arrival_cue.has_method("duplicate") else arrival_cue
	
	return copy

## Exports to WCS mission format
func export_to_wcs() -> Dictionary:
	return {
		"name": reinforcement_name,
		"type": ship_class,
		"count": ship_count,
		"waves": wave_count,
		"wave_delay": wave_delay,
		"priority": priority,
		"arrival_delay": arrival_delay,
		"arrival_cue": arrival_cue.export_to_wcs() if arrival_cue and arrival_cue.has_method("export_to_wcs") else null,
		"arrival_anchor": arrival_anchor,
		"arrival_distance": arrival_distance,
		"flags": flags,
		"no_messages": no_messages,
		"hotkey": hotkey,
		"loadout": custom_loadout,
		"ship_flags": ship_flags,
		"ai_goals": custom_ai_goals
	}

## Gets a display string for UI representation
func get_display_string() -> String:
	return "%s (%s x%d, %d waves)" % [reinforcement_name, ship_class, ship_count, wave_count]

## Gets estimated total ship count (waves * ships per wave)
func get_total_ship_count() -> int:
	return wave_count * ship_count

## Checks if reinforcement has custom configuration
func has_custom_configuration() -> bool:
	return not custom_loadout.is_empty() or not ship_flags.is_empty() or not custom_ai_goals.is_empty()

## Gets reinforcement summary for tooltips/info
func get_summary() -> Dictionary:
	return {
		"name": reinforcement_name,
		"id": reinforcement_id,
		"ship_class": ship_class,
		"total_ships": get_total_ship_count(),
		"waves": wave_count,
		"priority": priority,
		"arrival_delay": arrival_delay,
		"has_arrival_cue": arrival_cue != null,
		"has_custom_config": has_custom_configuration(),
		"description": description
	}
