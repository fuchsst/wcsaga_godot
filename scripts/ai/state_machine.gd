extends Node
class_name AIStateMachine

# AI States
enum State {
	IDLE,
	ATTACK,
	EVADE,
	WAYPOINT,
	DOCK,
	FORM
}

# AI Sub-states
enum AttackState {
	CHASE,           # Basic pursuit
	HEAD_ON,         # Head-to-head attack
	BREAK_ATTACK,    # Break and attack pattern
	STRAFE,         # Strafing run
	SANDWICH,        # Coordinated multi-ship attack
	ROPE_A_DOPE     # Vertical climb and dive attack
}

enum EvadeState {
	BREAK_AWAY,     # Basic evasion
	MISSILE_EVADE,  # Specific missile evasion
	JINK,          # Random direction changes
	BARREL_ROLL    # Rolling evasion
}

enum FormationState {
	WING,           # Basic wing formation
	DELTA,          # Delta/triangle formation
	BOX,            # Box formation
	SPREAD         # Spread out formation
}

# Current states
var current_state: State = State.IDLE
var current_attack_state: AttackState = AttackState.CHASE
var current_evade_state: EvadeState = EvadeState.BREAK_AWAY
var current_formation_state: FormationState = FormationState.WING

# Ship reference
var ship: ShipBase

# Target info
var current_target: ShipBase = null
var last_known_target_pos: Vector3
var time_since_last_sight: float = 0.0

# Combat parameters
var attack_min_distance: float = 100.0
var attack_max_distance: float = 1000.0
var evade_distance: float = 300.0
var formation_spacing: float = 50.0

# Behavior flags
var aggressive: bool = true
var formation_strict: bool = false
var missile_evade_chance: float = 0.7

func _ready():
	ship = get_parent() as ShipBase
	
func _physics_process(delta: float):
	match current_state:
		State.IDLE:
			process_idle(delta)
		State.ATTACK:
			process_attack(delta)
		State.EVADE:
			process_evade(delta)
		State.WAYPOINT:
			process_waypoint(delta)
		State.DOCK:
			process_dock(delta)
		State.FORM:
			process_formation(delta)
			
func process_idle(delta: float):
	# Look for targets or wait for orders
	if current_target:
		set_state(State.ATTACK)
		
func process_attack(delta: float):
	if not current_target or not is_target_valid():
		set_state(State.IDLE)
		return
		
	match current_attack_state:
		AttackState.CHASE:
			process_chase_attack(delta)
		AttackState.HEAD_ON:
			process_head_on_attack(delta)
		AttackState.BREAK_ATTACK:
			process_break_attack(delta)
		AttackState.STRAFE:
			process_strafe_attack(delta)
		AttackState.SANDWICH:
			process_sandwich_attack(delta)
		AttackState.ROPE_A_DOPE:
			process_rope_a_dope(delta)
			
func process_evade(delta: float):
	match current_evade_state:
		EvadeState.BREAK_AWAY:
			process_break_away(delta)
		EvadeState.MISSILE_EVADE:
			process_missile_evade(delta)
		EvadeState.JINK:
			process_jink(delta)
		EvadeState.BARREL_ROLL:
			process_barrel_roll(delta)
			
func process_waypoint(delta: float):
	# Follow assigned waypoints
	pass
	
func process_dock(delta: float):
	# Handle docking procedures
	pass
	
func process_formation(delta: float):
	match current_formation_state:
		FormationState.WING:
			process_wing_formation(delta)
		FormationState.DELTA:
			process_delta_formation(delta)
		FormationState.BOX:
			process_box_formation(delta)
		FormationState.SPREAD:
			process_spread_formation(delta)

# Attack behaviors
func process_chase_attack(delta: float):
	if not current_target:
		return
		
	var target_pos = current_target.global_transform.origin
	var direction = target_pos - ship.global_transform.origin
	var distance = direction.length()
	
	# Basic pursuit logic
	if distance > attack_max_distance:
		ship.accelerate(delta)
	elif distance < attack_min_distance:
		ship.decelerate(delta)
		
	# Aim at target
	var target_rotation = get_target_rotation(target_pos)
	ship.rotate_ship(target_rotation, delta)
	
	# Fire weapons when in range and aimed
	if distance < attack_max_distance and is_target_in_sights():
		ship.fire_weapon(0)  # Primary weapon

func process_head_on_attack(delta: float):
	# Head-to-head attack pattern
	pass
	
func process_break_attack(delta: float):
	# Break and attack pattern
	pass
	
func process_strafe_attack(delta: float):
	# Strafing run pattern
	pass
	
func process_sandwich_attack(delta: float):
	# Coordinated multi-ship attack
	pass
	
func process_rope_a_dope(delta: float):
	# Vertical climb and dive attack
	pass

# Evasion behaviors
func process_break_away(delta: float):
	if not current_target:
		return
		
	var away_vector = ship.global_transform.origin - current_target.global_transform.origin
	away_vector = away_vector.normalized()
	
	# Rotate away from threat
	var target_rotation = get_target_rotation(ship.global_transform.origin + away_vector)
	ship.rotate_ship(target_rotation, delta)
	
	# Accelerate away
	ship.accelerate(delta)

func process_missile_evade(delta: float):
	# Missile specific evasion
	pass
	
func process_jink(delta: float):
	# Random direction changes
	pass
	
func process_barrel_roll(delta: float):
	# Rolling evasion maneuver
	pass

# Formation behaviors
func process_wing_formation(delta: float):
	# Basic wing formation
	pass
	
func process_delta_formation(delta: float):
	# Delta/triangle formation
	pass
	
func process_box_formation(delta: float):
	# Box formation
	pass
	
func process_spread_formation(delta: float):
	# Spread formation
	pass

# Helper functions
func set_state(new_state: State):
	current_state = new_state
	
func set_attack_state(new_state: AttackState):
	current_attack_state = new_state
	
func set_evade_state(new_state: EvadeState):
	current_evade_state = new_state
	
func set_formation_state(new_state: FormationState):
	current_formation_state = new_state
	
func set_target(target: ShipBase):
	current_target = target
	if target:
		last_known_target_pos = target.global_transform.origin
		time_since_last_sight = 0.0
		
func is_target_valid() -> bool:
	if not current_target:
		return false
	# Add additional validity checks (destroyed, out of range, etc)
	return true
	
func is_target_in_sights() -> bool:
	if not current_target:
		return false
	# Check if target is within weapon arc
	return true
	
func get_target_rotation(target_pos: Vector3) -> Vector3:
	# Calculate required rotation to face target
	# This is a simplified version - would need proper rotation calculations
	var direction = target_pos - ship.global_transform.origin
	return direction.normalized()
	
func update_target_info(delta: float):
	if current_target:
		if has_line_of_sight():
			last_known_target_pos = current_target.global_transform.origin
			time_since_last_sight = 0.0
		else:
			time_since_last_sight += delta
			
func has_line_of_sight() -> bool:
	# Raycast check for line of sight
	return true
