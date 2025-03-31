# scripts/ship/subsystems/sensor_subsystem.gd
extends ShipSubsystem
class_name SensorSubsystem

# Sensor/AWACS Properties (Loaded from SubsystemDefinition)
var awacs_radius: float = 0.0
var awacs_intensity: float = 0.0 # How much this subsystem contributes to overall AWACS level

# Runtime State
# (Potentially track detected targets, signal strength, etc.)


func _ready():
	super._ready()


func initialize_from_definition(definition: ShipData.SubsystemDefinition):
	super.initialize_from_definition(definition)
	awacs_radius = definition.awacs_radius
	awacs_intensity = definition.awacs_intensity


func _process(delta):
	super._process(delta) # Handle disruption

	if is_destroyed or is_disrupted:
		# Sensors are non-functional
		# TODO: Potentially reduce ship_base's overall sensor range/capability
		return

	# TODO: Implement sensor logic if needed (e.g., passive detection updates)
	# TODO: Implement AWACS contribution logic (might be handled globally by an AWACSManager)


# Calculates the AWACS level provided by this specific subsystem at a target position
# Based on awacs_get_level logic
func get_awacs_level_at_pos(target_pos: Vector3) -> float:
	if not is_functional():
		return 0.0

	# TODO: Need the subsystem's world position accurately
	var subsys_pos_global = global_position # Placeholder

	var dist_sq = subsys_pos_global.distance_squared_to(target_pos)
	var radius_sq = awacs_radius * awacs_radius

	if dist_sq >= radius_sq:
		return 0.0

	# Simple linear falloff based on FS2's awacs_get_level
	var level = awacs_intensity * (1.0 - sqrt(dist_sq) / awacs_radius)
	return max(0.0, level)


func destroy_subsystem():
	super.destroy_subsystem()
	# TODO: Update ship's overall sensor capabilities when destroyed
