# scripts/ship/shield_system.gd
extends Node
class_name ShieldSystem

# References
var ship_base: ShipBase # Reference to the parent ship

# Shield Configuration (Loaded from ShipData)
var max_shield_strength: float = 100.0 # Total shield strength
var shield_regen_rate: float = 10.0 # Per second, ship_info.max_shield_regen_per_second
var shield_armor_type_idx: int = -1 # Index into ArmorData

# Runtime Shield State
var shield_quadrants: Array[float] = [0.0, 0.0, 0.0, 0.0] # Current strength per quadrant (Front, Right, Back, Left)
var shield_recharge_timer: float = 0.0 # Timer for recharge ticks
var shield_recharge_index: int = 0 # Index for energy scaling (if applicable)

# Constants
const NUM_QUADRANTS = 4
const RECHARGE_INTERVAL = 0.1 # How often to apply recharge logic (in seconds)

# Signals
signal shield_hit(quadrant: int, damage_absorbed: float)
signal shield_strength_changed(quadrant: int, new_strength: float)
signal shield_depleted(quadrant: int)
signal shield_fully_recharged()

# Recharge state (managed by ETS)
# var shield_recharge_timer: float = 0.0 # Timer for recharge ticks - No longer needed here
# var shield_recharge_index: int = 0 # Index for energy scaling (if applicable) - Stored in ShipBase

# Constants
const NUM_QUADRANTS = 4
# const RECHARGE_INTERVAL = 0.1 # How often to apply recharge logic (in seconds) - ETS interval used instead

func _ready():
	if get_parent() is ShipBase:
		ship_base = get_parent()
	else:
		printerr("ShieldSystem must be a child of a ShipBase node.")


func initialize_from_ship_data(ship_data: ShipData):
	max_shield_strength = ship_data.max_shield_strength
	shield_regen_rate = ship_data.max_shield_regen_per_second
	shield_armor_type_idx = ship_data.shield_armor_type_idx
	# Initialize quadrants to max strength (divided equally)
	var strength_per_quad = max_shield_strength / NUM_QUADRANTS
	for i in range(NUM_QUADRANTS):
		shield_quadrants[i] = strength_per_quad
		emit_signal("shield_strength_changed", i, shield_quadrants[i])


#func _process(delta):
	# Shield recharge is now driven by the ETS system in ShipBase calling the recharge() method.
	# The old _process logic is removed.


# Called by the ETS system in ShipBase to provide energy for recharging.
func recharge(energy_amount: float):
	if energy_amount <= 0.0: return

	var total_current_strength = get_total_strength()
	if total_current_strength >= max_shield_strength:
		return # Already full

	# Convert energy to shield strength (assuming 1:1 for now, adjust if needed)
	var recharge_strength = energy_amount
	var strength_per_quad = get_max_strength_per_quadrant()
	var amount_per_quad = recharge_strength / float(NUM_QUADRANTS) # Distribute evenly
	var recharged_fully = true

	for i in range(NUM_QUADRANTS):
		if shield_quadrants[i] < strength_per_quad:
			var old_strength = shield_quadrants[i]
			shield_quadrants[i] += amount_per_quad
			if shield_quadrants[i] > strength_per_quad:
				shield_quadrants[i] = strength_per_quad

			if abs(shield_quadrants[i] - old_strength) > 0.01: # Only signal if changed significantly
				emit_signal("shield_strength_changed", i, shield_quadrants[i])

			if shield_quadrants[i] < strength_per_quad * 0.999: # Check if this quad is still not full
				recharged_fully = false
		else:
			# This quadrant is already full
			pass

	# Check if *all* quadrants are now full
	if recharged_fully and get_total_strength() >= max_shield_strength * 0.999:
		emit_signal("shield_fully_recharged")


# Called by DamageSystem or projectile collision handler
# Returns the amount of damage that penetrated the shield
func absorb_damage(quadrant: int, damage: float, damage_type_key = -1) -> float:
	if quadrant < 0 or quadrant >= NUM_QUADRANTS:
		printerr("Invalid shield quadrant: ", quadrant)
		return damage # No shield to absorb

	if shield_quadrants[quadrant] <= 0.0:
		return damage # Shield already down

	var damage_to_apply = damage
	var damage_piercing_direct = 0.0 # Damage that bypasses shields entirely due to piercing %

	# Apply armor resistance and piercing logic if applicable
	if shield_armor_type_idx >= 0:
		var armor_data: ArmorData = GlobalConstants.get_armor_data(shield_armor_type_idx) # Placeholder
		if armor_data:
			# Check for direct piercing percentage
			var pierce_pct = armor_data.get_shield_pierce_percentage(damage_type_key)
			if pierce_pct > 0.0:
				damage_piercing_direct = damage * pierce_pct
				damage_to_apply = damage * (1.0 - pierce_pct) # Only apply remaining damage to shields

			# Apply resistance to the damage that hits the shield
			damage_to_apply *= armor_data.get_damage_multiplier(damage_type_key)
		else:
			printerr("Could not load ArmorData for shield index: ", shield_armor_type_idx)

	var damage_absorbed = min(shield_quadrants[quadrant], damage_to_apply)
	var damage_penetrated_after_armor = damage_to_apply - damage_absorbed

	shield_quadrants[quadrant] -= damage_absorbed

	emit_signal("shield_hit", quadrant, damage_absorbed)
	emit_signal("shield_strength_changed", quadrant, shield_quadrants[quadrant])

	# TODO: Play shield hit sound (SND_SHIELD_HIT or SND_SHIELD_HIT_YOU) based on ship_base == PlayerShip
	# SoundManager.play_3d(sound_id, hit_pos) # Need hit_pos passed in or calculated
	# Placeholder - Need hit position passed into absorb_damage
	# var sound_id = GlobalConstants.SND_SHIELD_HIT_YOU if ship_base == PlayerShip else GlobalConstants.SND_SHIELD_HIT
	# SoundManager.play_3d(sound_id, hit_pos_placeholder)

	# TODO: Trigger shield hit visual effect at hit position
	# EffectManager.create_shield_impact(hit_pos, hit_normal, quadrant) # Need hit_pos/normal passed in

	if shield_quadrants[quadrant] <= 0.0:
		shield_quadrants[quadrant] = 0.0 # Ensure it doesn't go negative
		emit_signal("shield_depleted", quadrant)
		# TODO: Play shield down sound

	# Calculate total damage getting through to the hull
	# This includes damage that wasn't absorbed after armor, plus direct piercing damage
	var total_damage_penetrated = 0.0
	if damage_to_apply > 0: # Avoid division by zero if armor made damage 0
		# Calculate the proportion of original damage that penetrated after armor
		total_damage_penetrated = (damage * (1.0 - pierce_pct)) * (damage_penetrated_after_armor / damage_to_apply)
	total_damage_penetrated += damage_piercing_direct

	return total_damage_penetrated


func get_quadrant_strength(quadrant: int) -> float:
	if quadrant < 0 or quadrant >= NUM_QUADRANTS:
		return 0.0
	return shield_quadrants[quadrant]


func get_total_strength() -> float:
	var total = 0.0
	for strength in shield_quadrants:
		total += strength
	return total


func get_max_strength_per_quadrant() -> float:
	return max_shield_strength / NUM_QUADRANTS


func is_quadrant_up(quadrant: int) -> bool:
	# Define a threshold for being "up" (e.g., > 1% or a small fixed value)
	var threshold = max(2.0, 0.01 * get_max_strength_per_quadrant())
	return get_quadrant_strength(quadrant) > threshold


func get_quadrant_from_local_pos(local_pos: Vector3) -> int:
	# Simplified quadrant calculation based on FS2 logic (get_quadrant)
	# Assumes Z is forward, X is right
	var quadrant = 0
	if local_pos.x < local_pos.z: # Right half?
		quadrant |= 1
	if local_pos.x < -local_pos.z: # Back half?
		quadrant |= 2
	# Quadrant mapping: 0=Front, 1=Right, 2=Left, 3=Rear (FS2 seems different, adjust if needed)
	# FS2: 0=Front, 1=Right, 2=Rear, 3=Left
	# Let's map to FS2 standard:
	match quadrant:
		0: return GlobalConstants.SHIELD_QUADRANT_FRONT # Front
		1: return GlobalConstants.SHIELD_QUADRANT_RIGHT # Right
		2: return GlobalConstants.SHIELD_QUADRANT_LEFT  # Left
		3: return GlobalConstants.SHIELD_QUADRANT_REAR  # Rear
	return GlobalConstants.SHIELD_QUADRANT_FRONT # Default fallback
