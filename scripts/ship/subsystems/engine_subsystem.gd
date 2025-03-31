# scripts/ship/subsystems/engine_subsystem.gd
extends ShipSubsystem
class_name EngineSubsystem

# Engine-specific properties (from model_subsystem if applicable)
# e.g., thruster point references, effect parameters

# References to effect nodes (GPUParticles3D, etc.) - Assign in editor or find dynamically
@onready var engine_glow_particles: GPUParticles3D = $EngineGlow # Example node name
@onready var contrail_particles: GPUParticles3D = $Contrail # Example node name
@onready var afterburner_particles: GPUParticles3D = $AfterburnerEffect # Example

func _ready():
	super._ready()
	# Ensure particle systems are initially off or configured correctly
	if engine_glow_particles: engine_glow_particles.emitting = false
	if contrail_particles: contrail_particles.emitting = false
	if afterburner_particles: afterburner_particles.emitting = false


func initialize_from_definition(definition: ShipData.SubsystemDefinition):
	super.initialize_from_definition(definition)
	# Initialize engine-specific properties from definition if needed


func _process(delta):
	super._process(delta) # Handle disruption

	if is_destroyed:
		# Ensure effects are off if destroyed
		if engine_glow_particles: engine_glow_particles.emitting = false
		if contrail_particles: contrail_particles.emitting = false
		if afterburner_particles: afterburner_particles.emitting = false
		return

	if is_disrupted:
		# Handle disruption effects (e.g., sputtering particles, reduced glow)
		if engine_glow_particles: engine_glow_particles.emitting = false # Simple off for now
		# TODO: Implement sputtering effect
		return

	# --- Update Engine Effects based on Ship State ---
	if not ship_base: return

	var is_engine_on = ship_base.flags & GlobalConstants.SF_ENGINES_ON
	var is_afterburner_on = ship_base.physics_flags & GlobalConstants.PF_AFTERBURNER_ON
	var current_thrust = 0.0 # TODO: Get actual thrust percentage from ShipBase/Input/AI

	# Engine Glow
	if engine_glow_particles:
		if is_engine_on and current_thrust > 0.01: # Only glow if thrusting
			engine_glow_particles.emitting = true
			# TODO: Adjust glow intensity/scale based on thrust/afterburner
		else:
			engine_glow_particles.emitting = false

	# Afterburner Effect
	if afterburner_particles:
		afterburner_particles.emitting = is_afterburner_on

	# Contrails (Based on speed threshold?)
	if contrail_particles:
		# TODO: Implement contrail logic (e.g., enable above a certain speed threshold)
		# var speed_threshold = 50.0 # Example
		# contrail_particles.emitting = ship_base.linear_velocity.length() > speed_threshold
		pass


func destroy_subsystem():
	super.destroy_subsystem()
	# Ensure effects are stopped immediately on destruction
	if engine_glow_particles: engine_glow_particles.emitting = false
	if contrail_particles: contrail_particles.emitting = false
	if afterburner_particles: afterburner_particles.emitting = false
