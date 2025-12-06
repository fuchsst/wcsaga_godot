class_name ShipEntity
extends CharacterBody3D

# --- Configuration ---
@export var stats: ShipStats:
	set(value):
		stats = value
		if is_inside_tree():
			_initialize_from_stats()

# --- Components ---
# These will be referenced or instantiated based on stats
var model_node: Node3D
# var ai_controller: AIController # To be implemented
var subsystems: Dictionary = {} # Map of subsystem name to Subsystem node/object

# --- State ---
var current_speed: float = 0.0
var desired_speed: float = 0.0
var current_hull: float = 100.0
var current_shields: float = 100.0
var weapon_energy: float = 100.0
var afterburner_fuel: float = 100.0

# --- Physics State ---
var throttle_percent: float = 0.0 # 0.0 to 1.0 (or -1.0 for reverse)


func _ready() -> void:
	if stats:
		_initialize_from_stats()
	else:
		push_warning("ShipEntity initialized without ShipStats!")

func _physics_process(delta: float) -> void:
	_process_movement(delta)
	_process_energy(delta)
	move_and_slide()

# --- Initialization ---
func _initialize_from_stats() -> void:
	if not stats:
		return
		
	# Initialize State
	current_hull = stats.hull_hitpoints
	current_shields = stats.shield_strength
	weapon_energy = stats.max_weapon_energy
	afterburner_fuel = stats.max_afterburner_fuel
	
	# Initialize Physics properties
	# (CharacterBody3D doesn't use mass for movement in the same way `RigidBody` does,
	# but we can use it for collisions if we handle them)
	
	# Setup Subsystems (This would ideally create nodes or logic objects)
	_setup_subsystems()

func _setup_subsystems() -> void:
	# Example: Create logical representations of subsystems defined in stats
	subsystems.clear()
	for engine in stats.engine_subsystems:
		subsystems[engine.subsystem_name] = {"health": engine.hitpoints, "type": "engine"}
	# ... handle weapons, turrets, etc.

# --- Core Mechanics ---

func _process_movement(delta: float) -> void:
	if not stats:
		return
		
	# Simple flight model based on Wing Commander mechanics (Newtonian-ish but simplified)
	# Target speed based on throttle
	var target_speed = throttle_percent * stats.max_velocity.z
	
	# Acceleration/Deceleration
	# Use forward_acceleration if available, else 10.0 default
	var accel = stats.forward_acceleration if stats.forward_acceleration > 0 else 10.0
	var decel = stats.forward_deceleration if stats.forward_deceleration > 0 else 10.0
	
	accel = accel if target_speed > current_speed else decel
	
	current_speed = move_toward(current_speed, target_speed, accel * delta)
	
	# Apply velocity (Z-forward is negative in Godot usually, but let's check basis)
	# Using local -Z as forward
	velocity = - basis.z * current_speed

func _process_energy(delta: float) -> void:
	if not stats:
		return
		
	# Regen Weapon Energy
	if weapon_energy < stats.max_weapon_energy:
		weapon_energy = min(weapon_energy + (stats.max_weapon_energy * stats.weapon_energy_regen_rate * delta), stats.max_weapon_energy)
		
	# Regen Shields
	if current_shields < stats.shield_strength:
		# TODO: Add delay logic
		current_shields = min(current_shields + (stats.shield_strength * stats.shield_regen_rate * delta), stats.shield_strength)

# --- Public API ---

func set_throttle(percent: float) -> void:
	throttle_percent = clampf(percent, -0.3, 1.0) # Assuming -30% for reverse?

func take_damage(amount: float, type: String = "generic") -> void:
	# Basic stub
	# TODO: Armor calculations
	if current_shields > 0:
		current_shields -= amount
		if current_shields < 0:
			current_hull += current_shields # Overflow to hull
			current_shields = 0
	else:
		current_hull -= amount
		
	if current_hull <= 0:
		die()

func die() -> void:
	# TODO: Explosion effect, cleanup
	queue_free()
