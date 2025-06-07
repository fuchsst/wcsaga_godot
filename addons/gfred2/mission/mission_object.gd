@tool
extends Resource
class_name MissionObject

enum Type {
	SHIP,
	WING,
	WAYPOINT,
	JUMP_NODE,
	START,  # Player start points
	DEBRIS,
	CARGO,
	NAV_BUOY,
	SENTRY_GUN
}

enum LocationType {
	AT_LOCATION,
	HYPERSPACE,
	DOCKING_BAY,
	IN_FRONT_OF_SHIP
}

# Arrival properties
@export var arrival_location: LocationType = LocationType.AT_LOCATION
@export var arrival_target := ""
@export var arrival_distance := 0
@export var arrival_delay := 0
@export var arrival_paths: Array[String] = []
@export var arrival_cue := ""

# Departure properties  
@export var departure_location: LocationType = LocationType.HYPERSPACE
@export var departure_target := ""
@export var departure_delay := 0
@export var departure_paths: Array[String] = []
@export var departure_cue := ""

# Object properties
@export var id := ""  # Unique identifier
@export var name := ""  # Display name
@export var type: Type
@export var team := 0  # Team number

# Wing properties
@export var special_ship_index := 0
@export var num_waves := 1
@export var threshold := 0
@export var ignore_count := false
@export var reinforcement := false
@export var no_arrival_music := false
@export var no_arrival_warp := false
@export var no_departure_warp := false
@export var no_arrival_log := false
@export var no_departure_log := false
@export var no_dynamic := false

# Transform
@export var position := Vector3.ZERO
@export var rotation := Vector3.ZERO
@export var scale := Vector3.ONE

# Weapon loadout
class WeaponBank:
	var weapon_index := -1  # Index into weapon info array
	var ammo_pct := 100.0  # Ammo percentage (0-100)

var primary_banks: Array[WeaponBank] = []
var secondary_banks: Array[WeaponBank] = []

# AI properties
class MissionAIGoal:
	enum Type {
		WAYPOINTS,
		WAYPOINTS_ONCE,
		WARP,
		DESTROY_SUBSYSTEM,
		CHASE,
		CHASE_WING,
		DOCK,
		UNDOCK,
		GUARD,
		GUARD_WING,
		CHASE_ANY,
		DISABLE_SHIP,
		DISARM_SHIP,
		IGNORE,
		IGNORE_NEW,
		EVADE_SHIP,
		STAY_NEAR_SHIP,
		KEEP_SAFE_DISTANCE,
		STAY_STILL,
		PLAY_DEAD
	}
	
	var type: Type
	var priority := 50
	var target_name := ""  # Ship/wing name
	var docker_point := ""  # For docking
	var dockee_point := ""  # For docking
	var subsystem_name := ""  # For destroy subsystem

var ai_goals: Array[MissionAIGoal] = []
var ai_class := -1  # -1 means use default AI class

# Object flags  
@export var destroy_before_mission := false
@export var destroy_delay := 0.0
@export var scannable := false
@export var cargo_known := false
@export var protect_ship := false
@export var beam_protect_ship := false
@export var invulnerable := false
@export var hidden_from_sensors := false
@export var primitive_sensors := false
@export var no_dynamic_goals := false
@export var escort_ship := false
@export var no_shields := false
@export var escort_priority := 0
@export var respawn_priority := 0
@export var kamikaze_damage := 0

# Subsystems
class MissionSubsystem:
	var name := ""
	var current_hits := -1.0  # -1 means use default health
	var cargo_name := ""
	
	# For turrets
	var ai_class := -1  # -1 means use default AI class
	var primary_banks: Array[int] = []  # Weapon indices
	var secondary_banks: Array[int] = []
	var bank_capacities: Array[float] = []  # Ammo percentages (0-100)

var subsystems: Array[MissionSubsystem] = []

# Hierarchy
var parent: MissionObject = null
var children: Array[MissionObject] = []

func _init():
	# Generate unique ID if not set
	if id.is_empty():
		id = str(Time.get_unix_time_from_system()) + "_" + str(randi())

func add_child(child: MissionObject) -> void:
	if child.parent:
		child.parent.remove_child(child)
	child.parent = self
	children.append(child)

func remove_child(child: MissionObject) -> void:
	child.parent = null
	children.erase(child)

func get_global_transform() -> Transform3D:
	var transform = Transform3D()
	transform.origin = position
	transform.basis = Basis.from_euler(rotation) * Basis().scaled(scale)
	
	if parent:
		return parent.get_global_transform() * transform
	return transform

func set_global_transform(global_transform: Transform3D) -> void:
	if parent:
		var local_transform = parent.get_global_transform().inverse() * global_transform
		position = local_transform.origin
		rotation = local_transform.basis.get_euler()
		scale = local_transform.basis.get_scale()
	else:
		position = global_transform.origin
		rotation = global_transform.basis.get_euler()
		scale = global_transform.basis.get_scale()

func add_subsystem(name: String) -> MissionSubsystem:
	var subsystem = MissionSubsystem.new()
	subsystem.name = name
	subsystems.append(subsystem)
	return subsystem

func get_subsystem(name: String) -> MissionSubsystem:
	for subsystem in subsystems:
		if subsystem.name == name:
			return subsystem
	return null

func add_primary_bank(weapon_index: int, ammo_pct := 100.0) -> void:
	var bank = WeaponBank.new()
	bank.weapon_index = weapon_index
	bank.ammo_pct = ammo_pct
	primary_banks.append(bank)

func add_secondary_bank(weapon_index: int, ammo_pct := 100.0) -> void:
	var bank = WeaponBank.new()
	bank.weapon_index = weapon_index
	bank.ammo_pct = ammo_pct
	secondary_banks.append(bank)

func add_ai_goal(goal_type: MissionAIGoal.Type, target := "", priority := 50) -> MissionAIGoal:
	var goal = MissionAIGoal.new()
	goal.type = goal_type
	goal.target_name = target
	goal.priority = priority
	ai_goals.append(goal)
	return goal

func validate() -> Array:
	var errors := []
	
	# Check required fields
	if name.is_empty():
		errors.append("Object '%s' requires a name" % id)
	
	# Check type-specific requirements
	match type:
		Type.SHIP:
			if team < 0:
				errors.append("Ship '%s' requires a valid team" % name)
			
			# Validate weapon banks
			for bank in primary_banks:
				if bank.weapon_index < 0:
					errors.append("Ship '%s' has invalid primary weapon" % name)
				if bank.ammo_pct < 0 or bank.ammo_pct > 100:
					errors.append("Ship '%s' has invalid primary weapon ammo" % name)
					
			for bank in secondary_banks:
				if bank.weapon_index < 0:
					errors.append("Ship '%s' has invalid secondary weapon" % name)
				if bank.ammo_pct < 0 or bank.ammo_pct > 100:
					errors.append("Ship '%s' has invalid secondary weapon ammo" % name)
			
			# Validate AI goals
			for goal in ai_goals:
				match goal.type:
					MissionAIGoal.Type.DOCK, MissionAIGoal.Type.UNDOCK:
						if goal.docker_point.is_empty() or goal.dockee_point.is_empty():
							errors.append("Ship '%s' has dock goal with missing dock points" % name)
					MissionAIGoal.Type.DESTROY_SUBSYSTEM:
						if goal.subsystem_name.is_empty():
							errors.append("Ship '%s' has destroy subsystem goal with no target" % name)
					MissionAIGoal.Type.CHASE, MissionAIGoal.Type.GUARD, MissionAIGoal.Type.EVADE_SHIP, MissionAIGoal.Type.STAY_NEAR_SHIP:
						if goal.target_name.is_empty():
							errors.append("Ship '%s' has AI goal with no target ship" % name)
					MissionAIGoal.Type.CHASE_WING, MissionAIGoal.Type.GUARD_WING:
						if goal.target_name.is_empty():
							errors.append("Ship '%s' has AI goal with no target wing" % name)
			
			# Validate subsystems
			for subsystem in subsystems:
				if subsystem.name.is_empty():
					errors.append("Ship '%s' has subsystem with no name" % name)
				if subsystem.current_hits > 100:
					errors.append("Ship '%s' subsystem '%s' has invalid health value" % [name, subsystem.name])
				
				# Validate turret weapon banks
				if !subsystem.primary_banks.is_empty() or !subsystem.secondary_banks.is_empty():
					for bank in subsystem.primary_banks:
						if bank < 0:
							errors.append("Ship '%s' turret '%s' has invalid primary weapon" % [name, subsystem.name])
					for bank in subsystem.secondary_banks:
						if bank < 0:
							errors.append("Ship '%s' turret '%s' has invalid secondary weapon" % [name, subsystem.name])
					for capacity in subsystem.bank_capacities:
						if capacity < 0 or capacity > 100:
							errors.append("Ship '%s' turret '%s' has invalid ammo capacity" % [name, subsystem.name])
		Type.WING:
			if children.is_empty():
				errors.append("Wing '%s' must contain at least one ship" % name)
	
	# Check children
	for child in children:
		var child_errors = child.validate()
		if !child_errors.is_empty():
			errors.append_array(child_errors)
	
	return errors
