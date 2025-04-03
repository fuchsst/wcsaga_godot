# scripts/player/player_autopilot_controller.gd
extends Node
class_name PlayerAutopilotController

## Controls the player ship's movement and orientation during autopilot.
## This node/script is typically disabled and enabled by AutopilotManager.

# --- Node References ---
@onready var navigation_agent: NavigationAgent3D = get_parent().get_node_or_null("NavigationAgent3D")
@onready var ship_base: ShipBase = get_parent() # Assuming this script is a child of the ShipBase node

# --- State ---
var target_nav_point: NavPointData = null
var target_position: Vector3 = Vector3.ZERO
var _active: bool = false

# --- Parameters ---
# TODO: Expose parameters like arrival distance, speed limits, etc.
var arrival_distance: float = 50.0 # How close to get before considering arrived (adjust based on ship size?)
var speed_cap: float = -1.0 # Max speed during autopilot, -1 for ship's max

func _ready():
	if not navigation_agent:
		printerr("PlayerAutopilotController: NavigationAgent3D node not found as sibling!")
	if not ship_base:
		printerr("PlayerAutopilotController: Parent node is not ShipBase!")
	set_process(false) # Disabled by default


func _physics_process(delta: float):
	if not _active or not navigation_agent or not ship_base or target_nav_point == null:
		return

	# 1. Update Target Position (in case the target moves, e.g., a ship)
	target_position = target_nav_point.get_target_position()
	navigation_agent.target_position = target_position

	# 2. Check if navigation path is finished
	if navigation_agent.is_navigation_finished():
		# TODO: Potentially signal AutopilotManager or handle arrival logic
		# For now, just stop moving
		ship_base.physics_controller.set_linear_input(Vector3.ZERO)
		ship_base.physics_controller.set_angular_input(Vector3.ZERO)
		# Maybe call AutopilotManager.end_autopilot() here? Needs careful state management.
		printerr("PlayerAutopilotController: Navigation finished, but arrival logic not implemented.")
		set_active(false) # Deactivate self for now
		return

	# 3. Get next path position and calculate direction
	var current_agent_position: Vector3 = ship_base.global_transform.origin
	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var direction: Vector3 = (next_path_position - current_agent_position).normalized()

	# 4. Calculate steering and velocity
	# Simple approach: steer directly towards the next path point
	# More advanced: Use NavigationAgent's velocity computation if available/suitable
	# For now, basic steering:
	var desired_velocity = direction * ship_base.get_max_speed() # Use ship's max speed or speed_cap
	if speed_cap > 0:
		desired_velocity = direction * speed_cap

	# Apply velocity/steering input to the ship's physics controller
	# This depends heavily on how ShipBase/PhysicsController is implemented
	# Example: Assuming PhysicsController has methods like set_linear_input/set_angular_input
	# Or directly manipulate phys_info if that's the pattern
	ship_base.physics_controller.set_linear_input(direction) # Move forward

	# Basic orientation towards the target direction
	var target_basis = Basis.looking_at(direction, ship_base.global_transform.basis.y) # Keep current up
	var current_basis = ship_base.global_transform.basis
	var rotation_delta = current_basis.slerp(target_basis, delta * ship_base.get_turn_rate()) # Adjust turn speed
	# ship_base.global_transform.basis = rotation_delta # Apply rotation directly or via physics controller

	# TODO: Refine steering logic (use NavigationAgent velocity, apply turn rates properly)
	# ship_base.physics_controller.set_angular_input(...)


func set_active(active: bool):
	_active = active
	set_process_input(active)
	set_physics_process(active)
	if not active:
		# Reset any movement input when deactivated
		if ship_base and ship_base.physics_controller:
			ship_base.physics_controller.set_linear_input(Vector3.ZERO)
			ship_base.physics_controller.set_angular_input(Vector3.ZERO)
		target_nav_point = null


func set_target_nav_point(nav_point: NavPointData):
	target_nav_point = nav_point
	if target_nav_point != null:
		target_position = target_nav_point.get_target_position()
		if navigation_agent:
			navigation_agent.target_position = target_position
	else:
		if navigation_agent:
			# Stop the agent if the target is cleared
			navigation_agent.target_position = ship_base.global_position if ship_base else Vector3.ZERO


func set_speed_cap(cap: float):
	speed_cap = cap
