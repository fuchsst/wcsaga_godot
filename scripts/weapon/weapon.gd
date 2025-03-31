# scripts/weapon/weapon.gd
extends Node # Or Node3D if it needs position/orientation directly
class_name WeaponInstance

# References
var weapon_system: WeaponSystem # Parent weapon system
var weapon_data: WeaponData # Static data for this weapon type
var hardpoint_node: Node3D # The Node3D representing the firing point

# Runtime State
var cooldown_timer: float = 0.0 # Time remaining until next shot
var is_ready: bool = true # Can this weapon fire?
var burst_shots_left: int = 0 # For burst-fire weapons

# Signals
signal fired(projectile_scene: PackedScene, fire_pos: Vector3, fire_dir: Vector3) # Or similar data
signal ready_to_fire


func _ready():
	# Get references, potentially from parent WeaponSystem or exported variables
	# weapon_system = get_parent() # Assuming direct child
	# hardpoint_node = get_parent() # If attached directly to hardpoint Node3D
	pass


func initialize(w_system: WeaponSystem, w_data: WeaponData, h_point: Node3D):
	weapon_system = w_system
	weapon_data = w_data
	hardpoint_node = h_point
	is_ready = true
	cooldown_timer = 0.0
	burst_shots_left = 0


func _process(delta):
	if not is_ready:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			is_ready = true
			cooldown_timer = 0.0
			emit_signal("ready_to_fire")


# Called by WeaponSystem to fire this specific weapon instance
func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool:
	if not is_ready or not weapon_data:
		return false

	# --- Firing Logic ---
	# 1. Determine firing position and direction from hardpoint_node
	var fire_pos = hardpoint_node.global_position
	var fire_dir = -hardpoint_node.global_transform.basis.z # Assuming -Z is forward

	# 2. Instantiate projectile scene (defined in weapon_data)
	#    var projectile_scene = load(weapon_data.pof_file) # Or laser/beam logic
	#    var projectile = projectile_scene.instantiate()

	# 3. Set projectile properties (velocity, lifetime, target, parent, etc.)
	#    projectile.global_position = fire_pos
	#    projectile.look_at(fire_pos + fire_dir) # Orient it
	#    projectile.linear_velocity = fire_dir * weapon_data.max_speed
	#    projectile.setup(weapon_data, weapon_system.ship_base, target) # Pass necessary info

	# 4. Add projectile to the scene tree (e.g., get_tree().root.add_child(projectile))

	# 5. Handle cooldown
	is_ready = false
	cooldown_timer = weapon_data.fire_wait
	# TODO: Handle burst fire logic (burst_shots_left, burst_delay)

	# 6. Emit signal or directly notify WeaponSystem
	# emit_signal("fired", projectile_scene, fire_pos, fire_dir)
	print("WeaponInstance fired: ", weapon_data.weapon_name) # Placeholder

	# TODO: Trigger muzzle flash effect
	# TODO: Trigger firing sound

	return true
