# scripts/ship/damage_system.gd
extends Node
class_name DamageSystem

# References
var ship_base: ShipBase
var shield_system: ShieldSystem

# Configuration (Loaded from ShipData)
var max_hull_strength: float = 100.0
var armor_type_idx: int = -1 # Index into ArmorData for hull armor

# Runtime State
# Note: Current hull strength is likely managed directly in ShipBase for easier access
# var current_hull_strength: float = 100.0

# Damage Tracking (for scoring/analysis)
var total_damage_received: float = 0.0
# Dictionary to store damage dealt by each attacker's object ID (signature)
# { killer_obj_id: damage_amount }
var damage_sources: Dictionary = {}
const MAX_DAMAGE_SLOTS = 32 # Mirroring C++ MAX_DAMAGE_SLOTS

# Signals
signal hull_damaged(damage_amount: float, new_hull_strength: float, killer_obj_id: int)
signal hull_destroyed(killer_obj_id: int) # Pass killer object ID or relevant info
signal subsystem_damaged(subsystem_node: Node, damage_amount: float)
signal subsystem_destroyed(subsystem_node: Node)


func _ready():
	if get_parent() is ShipBase:
		ship_base = get_parent()
		# Find sibling ShieldSystem node
		shield_system = ship_base.get_node_or_null("ShieldSystem")
		if not shield_system:
			printerr("DamageSystem could not find ShieldSystem sibling.")
	else:
		printerr("DamageSystem must be a child of a ShipBase node.")


func initialize_from_ship_data(ship_data: ShipData):
	max_hull_strength = ship_data.max_hull_strength
	armor_type_idx = ship_data.armor_type_idx
	# current_hull_strength = max_hull_strength # Initial hull strength set in ShipBase


# Applies damage locally, considering shields and armor.
# hit_pos is in global coordinates.
# damage_type_key can be an index (int) or name (String) for ArmorData lookup.
func apply_local_damage(hit_pos: Vector3, damage: float, killer_obj_id: int = -1, damage_type_key = -1, hit_subsystem: Node = null):
	if ship_base.hull_strength <= 0.0:
		return # Already destroyed

	var damage_after_shields = damage
	var quadrant = -1

	# 1. Check Shields
	if shield_system and not (ship_base.flags & GlobalConstants.OF_NO_SHIELDS):
		var local_hit_pos = ship_base.global_transform.affine_inverse() * hit_pos
		quadrant = shield_system.get_quadrant_from_local_pos(local_hit_pos)
		damage_after_shields = shield_system.absorb_damage(quadrant, damage, damage_type_key)

	if damage_after_shields <= 0.0:
		return # Shield absorbed all damage

	# 2. Distribute Damage to Subsystems
	var apply_hull_armor = true # Can be set to false by subsystem armor
	var damage_to_hull = _apply_subsystem_damage(hit_pos, damage_after_shields, damage_type_key, hit_subsystem, apply_hull_armor)

	# 3. Apply Hull Armor (if not overridden by subsystem armor)
	if apply_hull_armor and armor_type_idx >= 0:
		var armor_data: ArmorData = GlobalConstants.get_armor_data(armor_type_idx) # Placeholder
		if armor_data:
			damage_to_hull *= armor_data.get_damage_multiplier(damage_type_key)
		else:
			printerr("Could not load ArmorData for hull index: ", armor_type_idx)

	# 4. Apply Remaining Damage to Hull (Managed by ShipBase)
	if damage_to_hull > 0.0:
		# Apply guardian threshold if applicable
		if ship_base.ship_guardian_threshold > 0:
			var min_hull_strength = 0.01 * ship_base.ship_guardian_threshold * max_hull_strength
			if (ship_base.hull_strength - damage_to_hull) < min_hull_strength:
				damage_to_hull = ship_base.hull_strength - min_hull_strength
				damage_to_hull = max(0.0, damage_to_hull)

		ship_base.hull_strength -= damage_to_hull
		total_damage_received += damage_to_hull # Track total damage

		# Record damage source for scoring
		_record_damage_source(killer_obj_id, damage_to_hull)

		emit_signal("hull_damaged", damage_to_hull, ship_base.hull_strength, killer_obj_id)

		if ship_base.hull_strength <= 0.0:
			ship_base.hull_strength = 0.0 # Ensure not negative
			# The signal connection in ShipBase's _ready() should trigger destruction
			emit_signal("hull_destroyed", killer_obj_id)


# Applies damage globally, bypassing local shield quadrants but potentially affected by overall shield strength?
# FS2 logic seems to distribute global damage differently. Revisit this based on ship_apply_global_damage.
# For now, assume it bypasses shields and hits hull/subsystems directly.
func apply_global_damage(damage: float, killer_obj_id: int = -1, damage_type_key = -1):
	if ship_base.hull_strength <= 0.0:
		return

	var damage_to_hull = damage

	# Apply Hull Armor
	if armor_type_idx >= 0:
		var armor_data: ArmorData = GlobalConstants.get_armor_data(armor_type_idx) # Placeholder
		if armor_data:
			damage_to_hull *= armor_data.get_damage_multiplier(damage_type_key)
		else:
			printerr("Could not load ArmorData for hull index: ", armor_type_idx)

	# TODO: Distribute global damage to subsystems based on some logic (FS2 might just hit hull?)
	# For now, apply directly to hull.

	if damage_to_hull > 0.0:
		# Apply guardian threshold
		if ship_base.ship_guardian_threshold > 0:
			var min_hull_strength = 0.01 * ship_base.ship_guardian_threshold * max_hull_strength
			if (ship_base.hull_strength - damage_to_hull) < min_hull_strength:
				damage_to_hull = ship_base.hull_strength - min_hull_strength
				damage_to_hull = max(0.0, damage_to_hull)

		ship_base.hull_strength -= damage_to_hull
		total_damage_received += damage_to_hull

		# Record damage source
		_record_damage_source(killer_obj_id, damage_to_hull)

		emit_signal("hull_damaged", damage_to_hull, ship_base.hull_strength, killer_obj_id)

		if ship_base.hull_strength <= 0.0:
			ship_base.hull_strength = 0.0
			emit_signal("hull_destroyed", killer_obj_id)


# Distributes damage to subsystems near the hit location.
# Returns a Dictionary: { "damage_left": float, "apply_hull_armor": bool }
func _apply_subsystem_damage(hit_pos_global: Vector3, damage: float, damage_type_key, hit_subsystem_direct: Node, apply_hull_armor_initially: bool) -> Dictionary:
	var damage_left = damage
	var apply_hull_armor = apply_hull_armor_initially
	var subsystems_in_range = []

	# 1. Find nearby subsystems
	# Assuming subsystems are children with ShipSubsystem script attached
	# TODO: This needs a more robust way to find subsystems, potentially using groups or a dedicated parent node.
	for child in ship_base.get_children():
		if child is ShipSubsystem:
			var subsys: ShipSubsystem = child
			if subsys.is_destroyed or not is_instance_valid(subsys.subsystem_definition):
				continue

			# Get subsystem world position (assuming the node itself represents the position)
			# TODO: This needs refinement - should use the position defined in subsystem_definition relative to ship center.
			var subsys_pos_global = subsys.global_position # Placeholder
			var dist = hit_pos_global.distance_to(subsys_pos_global)

			# Determine hit range (simplified based on radius)
			# TODO: Implement subsys_get_range logic from C++ (depends on weapon type, shockwave, etc.)
			var range = subsys.subsystem_definition.radius * 2.0 # Simple range
			if subsys.subsystem_definition.type == GlobalConstants.SubsystemType.TURRET:
				range *= 1.5 # Turrets might have slightly larger hit range

			if dist < range:
				subsystems_in_range.append({"node": subsys, "dist": dist, "range": range})

	# 2. Sort subsystems by distance (closest first)
	subsystems_in_range.sort_custom(func(a, b): return a.dist < b.dist)

	# 3. Iterate and apply damage
	var original_damage_pool = damage # Track damage that *could* reach hull
	var damage_applied_to_subsystems = 0.0

	for i in range(subsystems_in_range.size()):
		if damage_left <= 0.01: break # No more damage to distribute

		var item = subsystems_in_range[i]
		var subsys: ShipSubsystem = item.node
		var dist: float = item.dist
		var range: float = item.range
		var damage_to_apply = 0.0
		var current_damage_portion = damage_left # Max damage this subsystem could take from remaining pool

		# Apply subsystem armor first (if it exists)
		var subsys_armor_idx = subsys.subsystem_definition.armor_type_idx
		if subsys_armor_idx >= 0:
			var armor_data: ArmorData = GlobalConstants.get_armor_data(subsys_armor_idx) # Placeholder
			if armor_data:
				current_damage_portion *= armor_data.get_damage_multiplier(damage_type_key)
				# If the first subsystem hit has armor, don't apply hull armor later (unless ship flag overrides)
				if i == 0 and not (ship_base.ship_data and ship_base.ship_data.flags & GlobalConstants.SAF_IGNORE_SS_ARMOR):
					apply_hull_armor = false
			else:
				printerr("Could not load ArmorData for subsystem index: ", subsys_armor_idx)

		# Calculate damage based on distance/range (linear falloff)
		if range > 0.0:
			# Full damage within half range, linear falloff beyond
			if dist < range / 2.0:
				damage_to_apply = current_damage_portion
			else:
				damage_to_apply = current_damage_portion * (1.0 - (dist - range / 2.0) / (range / 2.0))
		else: # Point blank? Apply full damage
			damage_to_apply = current_damage_portion

		damage_to_apply = max(0.0, damage_to_apply) # Ensure non-negative

		if damage_to_apply > 0.01: # Apply if damage is significant
			# Call the subsystem's take_damage method
			var absorbed = subsys.take_damage(damage_to_apply, damage_type_key)
			damage_applied_to_subsystems += absorbed
			damage_left -= absorbed # Reduce remaining damage pool

			# Handle MSS_FLAG_CARRY_NO_DAMAGE - reduce the original damage pool that could reach hull
			if subsys.subsystem_definition.flags & GlobalConstants.MSS_FLAG_CARRY_NO_DAMAGE:
				# TODO: Check shockwave flag if needed (MSS_FLAG_CARRY_SHOCKWAVE)
				# Reduce the original damage amount that could potentially reach the hull
				# This prevents damage passing through "shield" subsystems to the hull
				original_damage_pool -= absorbed

	# Return remaining damage (from original pool, considering CARRY_NO_DAMAGE) and hull armor flag
	return { "damage_left": max(0.0, original_damage_pool - damage_applied_to_subsystems), "apply_hull_armor": apply_hull_armor }


# Called when a subsystem's 'destroyed' signal is emitted
func _on_subsystem_destroyed(subsystem_node: ShipSubsystem):
	if not is_instance_valid(subsystem_node) or not is_instance_valid(subsystem_node.subsystem_definition):
		return

	print("Subsystem destroyed: ", subsystem_node.subsystem_definition.subobj_name)
	emit_signal("subsystem_destroyed", subsystem_node)

	# TODO: Trigger visual/audio effects for subsystem destruction (e.g., using an EffectManager singleton)
	# EffectManager.create_subsystem_explosion(subsystem_node.global_position, subsystem_node.subsystem_definition.radius)
	# SoundManager.play_3d(sound_id, subsystem_node.global_position) # e.g., SND_SUBSYS_EXPLODE or system_info.dead_snd

	# Check if all subsystems of this type are destroyed and apply ship-wide effects
	_check_critical_subsystems(subsystem_node.subsystem_definition.type)


# Records damage dealt by a specific attacker object ID.
func _record_damage_source(killer_obj_id: int, damage: float):
	if killer_obj_id == -1 or damage <= 0.0:
		return

	if damage_sources.has(killer_obj_id):
		damage_sources[killer_obj_id] += damage
	else:
		# Limit the number of tracked damage sources (like C++ MAX_DAMAGE_SLOTS)
		if damage_sources.size() < MAX_DAMAGE_SLOTS:
			damage_sources[killer_obj_id] = damage
		else:
			# Optional: Replace the source with the least damage if full?
			# For simplicity, just don't add new sources if full for now.
			printerr("DamageSystem: Max damage sources reached for ship %s" % ship_base.ship_name)


# Returns the dictionary of damage sources {killer_obj_id: damage_amount}
func get_damage_sources() -> Dictionary:
	return damage_sources


# Checks if all subsystems of a given type are destroyed and applies ship-wide effects
func _check_critical_subsystems(destroyed_type: int):
	var all_destroyed = true
	var found_any = false
	for child in ship_base.get_children():
		if child is ShipSubsystem:
			var subsys: ShipSubsystem = child
			if subsys.subsystem_definition and subsys.subsystem_definition.type == destroyed_type:
				found_any = true
				if not subsys.is_destroyed:
					all_destroyed = false
					break # No need to check further for this type

	if found_any and all_destroyed:
		print("All subsystems of type %s destroyed!" % GlobalConstants.SubsystemType.keys()[destroyed_type])
		match destroyed_type:
			GlobalConstants.SubsystemType.ENGINE:
				if not (ship_base.flags & GlobalConstants.SF_DISABLED):
					ship_base.flags |= GlobalConstants.SF_DISABLED # Disable the ship
					# TODO: Log mission event LOG_SHIP_DISABLED
					# MissionLog.add_entry(LOG_SHIP_DISABLED, ship_base.ship_name, null)
					print("%s disabled!" % ship_base.ship_name)
			GlobalConstants.SubsystemType.WEAPONS:
				if not (ship_base.flags2 & (GlobalConstants.SF2_PRIMARIES_LOCKED | GlobalConstants.SF2_SECONDARIES_LOCKED)):
					ship_base.flags2 |= GlobalConstants.SF2_PRIMARIES_LOCKED | GlobalConstants.SF2_SECONDARIES_LOCKED
					# TODO: Log mission event LOG_SHIP_DISARMED
					# MissionLog.add_entry(LOG_SHIP_DISARMED, ship_base.ship_name, null)
					print("%s disarmed!" % ship_base.ship_name)
			# Add cases for other critical types if needed (SENSORS, NAVIGATION, COMMUNICATION, WARPDRIVE)
			GlobalConstants.SubsystemType.SENSORS:
				# TODO: Implement sensor degradation/failure effects (e.g., reduced radar range, targeting issues)
				print("%s sensors destroyed!" % ship_base.ship_name)
			GlobalConstants.SubsystemType.WARPDRIVE:
				if not (ship_base.flags & GlobalConstants.SF_WARP_BROKEN):
					ship_base.flags |= GlobalConstants.SF_WARP_BROKEN
					print("%s warp drive destroyed!" % ship_base.ship_name)


# TODO: Implement logic for critical hits (random chance on hit?).
