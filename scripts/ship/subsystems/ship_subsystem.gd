# scripts/ship/subsystems/ship_subsystem.gd
extends Node
class_name ShipSubsystem

# References
var ship_base: ShipBase # Reference to the parent ship
var subsystem_definition: ShipData.SubsystemDefinition # Loaded definition from ShipData

# Runtime State
var current_hits: float = 100.0
var max_hits: float = 100.0
var is_destroyed: bool = false
var is_disrupted: bool = false
var disruption_timer: float = 0.0 # How long disruption lasts
var subsys_guardian_threshold: int = 0 # ship_subsys.subsys_guardian_threshold

# Flags (mapped from SSF_*, SSSF_*)
var flags: int = 0 # Consider using specific booleans instead

# Targeting Info (Primarily for Turrets, but might be useful for others)
var target_node: Node3D = null # Current target Node3D
var target_signature: int = 0 # Signature of the target object
var targeted_subsystem: ShipSubsystem = null # Specific subsystem targeted on the target node

# Sound State
var subsys_snd_flags: int = 0 # SSSF_* flags for sound management

# Signals
signal health_changed(new_health: float, max_health: float)
signal destroyed
signal disrupted
signal disruption_ended


func _ready():
	if get_parent() is ShipBase: # Or potentially a sub-node within ShipBase hierarchy
		ship_base = get_parent() # Adjust if subsystems are nested differently
		# Find the corresponding definition in ship_base.ship_data.subsystems
		# based on node name or an exported variable.
		# initialize_from_definition(found_definition)
	else:
		printerr("ShipSubsystem expects a ShipBase ancestor.")


func initialize_from_definition(definition: ShipData.SubsystemDefinition):
	subsystem_definition = definition
	max_hits = definition.max_hits
	current_hits = max_hits
	# subsys_guardian_threshold = definition.subsys_guardian_threshold # Add this to SubsystemDefinition resource
	# armor_type_idx = definition.armor_type_idx # Add this
	# flags = ... # Initialize based on definition flags if needed
	emit_signal("health_changed", current_hits, max_hits)
	# Connect the destroyed signal to a handler in DamageSystem or ShipBase
	destroyed.connect(Callable(ship_base.damage_system, "_on_subsystem_destroyed").bind(self)) # Example connection


func _process(delta):
	if is_disrupted:
		disruption_timer -= delta
		if disruption_timer <= 0.0:
			is_disrupted = false
			disruption_timer = 0.0
			emit_signal("disruption_ended")
			# TODO: Stop disruption sound/effect
			# _stop_sound(subsystem_definition.disruption_snd) # Example

	# TODO: Handle rotation sounds based on SSSF_ROTATE flag and actual rotation
	# TODO: Handle turret rotation sounds based on SSSF_TURRET_ROTATION flag


# Takes damage and returns the amount actually absorbed.
func take_damage(amount: float, damage_type_key = -1) -> float:
	if is_destroyed or amount <= 0.0:
		return 0.0 # Cannot damage a destroyed subsystem

	# Apply subsystem armor if defined in subsystem_definition
	var effective_damage = amount
	if subsystem_definition and subsystem_definition.armor_type_idx >= 0:
		var armor_data: ArmorData = load(GlobalConstants.ARMOR_DATA_PATH + GlobalConstants.armor_list[subsystem_definition.armor_type_idx]) # Placeholder
		effective_damage = amount * armor_data.get_damage_multiplier(damage_type_key)
		# TODO: Handle piercing logic if necessary - Needs ArmorData access
		# var armor_data: ArmorData = GlobalConstants.get_armor_data(subsystem_definition.armor_type_idx) # Placeholder
		# if armor_data:
		#     effective_damage = amount * armor_data.get_damage_multiplier(damage_type_key)

	# Apply guardian threshold
	if subsys_guardian_threshold > 0:
		var min_strength = 0.01 * subsys_guardian_threshold * max_hits
		if (current_hits - effective_damage) < min_strength:
			effective_damage = current_hits - min_strength
			effective_damage = max(0.0, effective_damage)

	var actual_damage_taken = min(current_hits, effective_damage)
	current_hits -= actual_damage_taken

	emit_signal("health_changed", current_hits, max_hits)

	if current_hits <= 0.0:
		current_hits = 0.0
		destroy_subsystem()

	# Return the amount of damage absorbed by this subsystem
	return actual_damage_taken


func disrupt(duration_ms: int):
	if is_destroyed:
		return

	var duration_sec = float(duration_ms) / 1000.0
	if duration_sec > disruption_timer:
		disruption_timer = duration_sec
		if not is_disrupted:
			is_disrupted = true
			emit_signal("disrupted")
			# TODO: Play disruption sound/start effect


func destroy_subsystem():
	if is_destroyed:
		return

	is_destroyed = true
	current_hits = 0.0
	is_disrupted = false # Destruction overrides disruption
	disruption_timer = 0.0
	emit_signal("destroyed")
	emit_signal("health_changed", current_hits, max_hits) # Ensure health shows 0

	# --- Trigger visual destruction effects ---
	# This is likely handled by the system connected to the 'destroyed' signal (e.g., DamageSystem)
	# It would look up the subsystem's position and spawn effects.
	# Example (if handled here, less ideal):
	# EffectManager.create_subsystem_explosion(global_position, subsystem_definition.radius)
	# EffectManager.create_subsystem_debris(global_position, ...)

	# --- Sound Management ---
	if subsys_snd_flags & GlobalConstants.SSSF_ALIVE:
		# _stop_sound(subsystem_definition.alive_snd) # Placeholder
		subsys_snd_flags &= ~GlobalConstants.SSSF_ALIVE
		print("Stopping alive sound for ", subsystem_definition.subobj_name if subsystem_definition else "Unknown Subsystem")
	if subsys_snd_flags & GlobalConstants.SSSF_TURRET_ROTATION:
		# _stop_sound(subsystem_definition.turret_base_rotation_snd)
		# _stop_sound(subsystem_definition.turret_gun_rotation_snd)
		subsys_snd_flags &= ~GlobalConstants.SSSF_TURRET_ROTATION
		print("Stopping turret rotation sounds for ", subsystem_definition.subobj_name if subsystem_definition else "Unknown Subsystem")
	if subsys_snd_flags & GlobalConstants.SSSF_ROTATE:
		# _stop_sound(subsystem_definition.rotation_snd)
		subsys_snd_flags &= ~GlobalConstants.SSSF_ROTATE
		print("Stopping rotation sound for ", subsystem_definition.subobj_name if subsystem_definition else "Unknown Subsystem")

	if subsystem_definition and subsystem_definition.dead_snd != -1 and not (subsys_snd_flags & GlobalConstants.SSSF_DEAD):
		# _play_sound(subsystem_definition.dead_snd, true) # Play looping dead sound
		subsys_snd_flags |= GlobalConstants.SSSF_DEAD
		print("Playing dead sound for ", subsystem_definition.subobj_name)

	# --- Update parent ship's aggregate subsystem info ---
	# This requires ShipBase to have a structure similar to ship.subsys_info
	# ship_base.update_aggregate_subsystem_health(subsystem_definition.type) # Example call

	# --- Handle Cargo Reveal ---
	if subsystem_definition and subsystem_definition.flags & GlobalConstants.MSS_FLAG_CARRY_NO_DAMAGE: # Check flag
		if not (flags & GlobalConstants.SSF_CARGO_REVEALED):
			flags |= GlobalConstants.SSF_CARGO_REVEALED
			# TODO: Trigger cargo reveal logic/event
			print("Cargo revealed for ", subsystem_definition.subobj_name)


func get_health_percentage() -> float:
	if max_hits <= 0.0:
		return 1.0 if not is_destroyed else 0.0
	return current_hits / max_hits


func is_functional() -> bool:
	return not is_destroyed and not is_disrupted


func get_world_position() -> Vector3:
	"""Calculates and returns the current world position of the subsystem."""
	if not is_instance_valid(ship_base) or not subsystem_definition:
		# Fallback to node's global position if references are missing
		printerr("ShipSubsystem: Cannot calculate world position - missing ship_base or definition.")
		return global_position

	# Get the offset from the definition
	var local_offset = subsystem_definition.pnt

	# Transform the local offset by the ship's current global transform
	return ship_base.global_transform * local_offset
