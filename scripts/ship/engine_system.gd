# scripts/ship/engine_system.gd
extends Node
class_name EngineSystem

# References
var ship_base: ShipBase # Reference to the parent ship

# Configuration (Loaded from ShipData)
var has_afterburner: bool = false
var afterburner_fuel_capacity: float = 100.0
var afterburner_burn_rate: float = 10.0 # Units per second
var afterburner_recover_rate: float = 5.0 # Units per second
var afterburner_forward_accel: float = 100.0
var afterburner_max_vel: Vector3 = Vector3(200, 200, 200)
# TODO: Add afterburner reverse properties if needed

# Runtime State
var afterburner_fuel: float = 100.0
var afterburner_on: bool = false
var afterburner_locked: bool = false # Corresponds to SF2_AFTERBURNER_LOCKED

# Constants
const MIN_FUEL_TO_ENGAGE = 10.0 # ship/afterburner.cpp MIN_AFTERBURNER_FUEL_TO_ENGAGE

# Signals
signal afterburner_engaged
signal afterburner_disengaged
signal afterburner_fuel_updated(current_fuel: float, capacity: float)


func _ready():
	if get_parent() is ShipBase:
		ship_base = get_parent()
	else:
		printerr("EngineSystem must be a child of a ShipBase node.")


func initialize_from_ship_data(ship_data: ShipData):
	has_afterburner = ship_data.flags & GlobalConstants.SIF_AFTERBURNER
	afterburner_fuel_capacity = ship_data.afterburner_fuel_capacity
	afterburner_burn_rate = ship_data.afterburner_burn_rate
	afterburner_recover_rate = ship_data.afterburner_recover_rate
	afterburner_forward_accel = ship_data.afterburner_forward_accel
	afterburner_max_vel = ship_data.afterburner_max_vel
	# Initialize fuel
	afterburner_fuel = afterburner_fuel_capacity
	emit_signal("afterburner_fuel_updated", afterburner_fuel, afterburner_fuel_capacity)


#func _process(delta):
	# Afterburner fuel recharge is now driven by the ETS system in ShipBase calling the recharge() method.
	# Fuel consumption still happens here when the afterburner is active.
#	if not has_afterburner:
#		return
#
#	if afterburner_on:
#		# Consume fuel
#		afterburner_fuel -= afterburner_burn_rate * delta
#		if afterburner_fuel <= 0.0:
#			afterburner_fuel = 0.0
#			stop_afterburner() # Automatically stop if fuel runs out
#		emit_signal("afterburner_fuel_updated", afterburner_fuel, afterburner_fuel_capacity)


# Called by the ETS system in ShipBase to provide energy for recharging afterburner fuel.
func recharge(energy_amount: float):
	if not has_afterburner or afterburner_on or afterburner_fuel >= afterburner_fuel_capacity:
		return # Don't recharge if off, active, or full

	if energy_amount <= 0.0: return

	# Convert energy to fuel (assuming 1:1 for now, adjust if needed)
	var recharge_fuel = energy_amount
	var old_fuel = afterburner_fuel

	afterburner_fuel += recharge_fuel
	if afterburner_fuel > afterburner_fuel_capacity:
		afterburner_fuel = afterburner_fuel_capacity

	if abs(afterburner_fuel - old_fuel) > 0.01: # Only signal if changed significantly
		emit_signal("afterburner_fuel_updated", afterburner_fuel, afterburner_fuel_capacity)


func start_afterburner():
	if not has_afterburner or afterburner_on or afterburner_locked:
		return

	# Check if gliding (original code prevents AB while gliding)
	# if ship_base.physics_flags & GlobalConstants.PF_GLIDING:
	#     return

	if afterburner_fuel < MIN_FUEL_TO_ENGAGE:
		# TODO: Play failure sound (SND_ABURN_FAIL)
		print("Afterburner fuel too low to engage!")
		return

	afterburner_on = true
	ship_base.physics_flags |= GlobalConstants.PF_AFTERBURNER_ON
	emit_signal("afterburner_engaged")
	# TODO: Play engage sound (SND_ABURN_ENGAGE)
	# TODO: Start engine trail/glow effects
	# TODO: Handle player-specific logic (joy_ff_afterburn_on, loop sounds)


func stop_afterburner(key_released: bool = false):
	if not afterburner_on:
		return

	afterburner_on = false
	ship_base.physics_flags &= ~GlobalConstants.PF_AFTERBURNER_ON
	emit_signal("afterburner_disengaged")
	# TODO: Stop engine trail/glow effects
	# TODO: Handle player-specific logic (joy_ff_afterburn_off, stop loop sounds)
	# TODO: Play disengage sound? (Original doesn't seem to have one explicitly, maybe part of loop stop)


func get_afterburner_fuel_pct() -> float:
	if afterburner_fuel_capacity <= 0.0:
		return 0.0
	return afterburner_fuel / afterburner_fuel_capacity
