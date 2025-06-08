class_name EnginePowerSystem
extends Node

## Engine power system that affects ship speed, maneuverability, and afterburner
## Provides linear scaling based on ETS allocation and subsystem damage
## Implementation of SHIP-008 AC4: Engine power system

# EPIC-002 Asset Core Integration
const ShipData = preload("res://addons/wcs_asset_core/structures/ship_data.gd")
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Engine power signals (SHIP-008 AC4)
signal engine_power_changed(power_level: float)
signal speed_scaling_updated(max_speed: float, afterburner_speed: float)
signal maneuverability_changed(turn_rate: float, acceleration: float)
signal afterburner_efficiency_changed(efficiency: float)

# Engine performance states
enum PowerState {
	FULL_POWER = 0,       # 100% power output
	HIGH_POWER = 1,       # 75-99% power output
	NORMAL_POWER = 2,     # 50-74% power output
	LOW_POWER = 3,        # 25-49% power output
	MINIMAL_POWER = 4,    # 1-24% power output
	NO_POWER = 5          # 0% power output (engine failure)
}

# Engine system state
var ship: BaseShip
var ets_manager: ETSManager

# Base performance characteristics (from ship class)
var base_max_speed: float = 100.0
var base_afterburner_speed: float = 150.0
var base_acceleration: float = 50.0
var base_turn_rate: float = 2.0
var base_afterburner_fuel_consumption: float = 10.0

# Current performance values
var current_max_speed: float = 100.0
var current_afterburner_speed: float = 150.0
var current_acceleration: float = 50.0
var current_turn_rate: float = 2.0
var current_afterburner_efficiency: float = 1.0

# Power system state
var engine_power_level: float = 1.0           # Overall engine power (0.0 to 1.0)
var ets_power_allocation: float = 0.333       # ETS engine allocation
var subsystem_efficiency: float = 1.0         # Engine subsystem health efficiency
var damage_modifier: float = 1.0              # Engine damage modifier
var power_state: PowerState = PowerState.FULL_POWER

# Performance modifiers
var speed_scaling_curve: Curve                # Speed scaling curve for power levels
var acceleration_scaling_curve: Curve         # Acceleration scaling curve
var turn_rate_scaling_curve: Curve           # Turn rate scaling curve
var afterburner_efficiency_curve: Curve      # Afterburner efficiency curve

# Performance tracking
var total_power_adjustments: int = 0
var power_state_history: Array[PowerState] = []
var performance_efficiency_tracking: Array[float] = []

## Initialize engine power system
func initialize_engine_power_system(target_ship: BaseShip) -> void:
	"""Initialize engine power system for ship.
	
	Args:
		target_ship: Ship to manage engine power for
	"""
	ship = target_ship
	
	# Get reference to ETS manager
	if ship.has_node("ETSManager"):
		ets_manager = ship.get_node("ETSManager")
	elif ship.has_method("get_ets_manager"):
		ets_manager = ship.get_ets_manager()
	
	# Load engine configuration from ship class
	if ship.ship_class:
		_load_engine_configuration()
	
	# Initialize performance curves
	_initialize_performance_curves()
	
	# Set initial performance values
	_update_engine_performance()

## Load engine configuration from ship class
func _load_engine_configuration() -> void:
	"""Load engine performance configuration from ship class."""
	var ship_data = ship.ship_class
	
	# Set base performance characteristics
	base_max_speed = ship_data.max_velocity
	base_afterburner_speed = ship_data.max_afterburner_velocity
	base_acceleration = ship_data.acceleration if ship_data.acceleration > 0 else 50.0
	base_turn_rate = ship_data.rotation_damping if ship_data.rotation_damping > 0 else 2.0
	base_afterburner_fuel_consumption = ship_data.afterburner_fuel_capacity * 0.1  # 10% per second
	
	# Initialize current values
	current_max_speed = base_max_speed
	current_afterburner_speed = base_afterburner_speed
	current_acceleration = base_acceleration
	current_turn_rate = base_turn_rate
	current_afterburner_efficiency = 1.0

## Initialize performance scaling curves
func _initialize_performance_curves() -> void:
	"""Initialize performance scaling curves for power levels."""
	# Speed scaling curve (linear with slight boost at high power)
	speed_scaling_curve = Curve.new()
	speed_scaling_curve.add_point(Vector2(0.0, 0.1))   # 10% speed at 0% power
	speed_scaling_curve.add_point(Vector2(0.25, 0.4))  # 40% speed at 25% power
	speed_scaling_curve.add_point(Vector2(0.5, 0.7))   # 70% speed at 50% power
	speed_scaling_curve.add_point(Vector2(0.75, 0.9))  # 90% speed at 75% power
	speed_scaling_curve.add_point(Vector2(1.0, 1.0))   # 100% speed at 100% power
	
	# Acceleration scaling curve (more dramatic at low power)
	acceleration_scaling_curve = Curve.new()
	acceleration_scaling_curve.add_point(Vector2(0.0, 0.05))  # 5% acceleration at 0% power
	acceleration_scaling_curve.add_point(Vector2(0.25, 0.3))  # 30% acceleration at 25% power
	acceleration_scaling_curve.add_point(Vector2(0.5, 0.6))   # 60% acceleration at 50% power
	acceleration_scaling_curve.add_point(Vector2(0.75, 0.85)) # 85% acceleration at 75% power
	acceleration_scaling_curve.add_point(Vector2(1.0, 1.0))   # 100% acceleration at 100% power
	
	# Turn rate scaling curve (less affected by power)
	turn_rate_scaling_curve = Curve.new()
	turn_rate_scaling_curve.add_point(Vector2(0.0, 0.3))   # 30% turn rate at 0% power
	turn_rate_scaling_curve.add_point(Vector2(0.25, 0.5))  # 50% turn rate at 25% power
	turn_rate_scaling_curve.add_point(Vector2(0.5, 0.75))  # 75% turn rate at 50% power
	turn_rate_scaling_curve.add_point(Vector2(0.75, 0.9))  # 90% turn rate at 75% power
	turn_rate_scaling_curve.add_point(Vector2(1.0, 1.0))   # 100% turn rate at 100% power
	
	# Afterburner efficiency curve (requires high power for efficiency)
	afterburner_efficiency_curve = Curve.new()
	afterburner_efficiency_curve.add_point(Vector2(0.0, 0.0))   # 0% efficiency at 0% power
	afterburner_efficiency_curve.add_point(Vector2(0.25, 0.2))  # 20% efficiency at 25% power
	afterburner_efficiency_curve.add_point(Vector2(0.5, 0.5))   # 50% efficiency at 50% power
	afterburner_efficiency_curve.add_point(Vector2(0.75, 0.8))  # 80% efficiency at 75% power
	afterburner_efficiency_curve.add_point(Vector2(1.0, 1.0))   # 100% efficiency at 100% power

## Process engine power updates
func _process(delta: float) -> void:
	"""Process engine power system updates."""
	if not ship or not ets_manager:
		return
	
	# Update ETS power allocation
	var new_ets_allocation: float = ets_manager.get_effective_power_allocation(ETSManager.SystemType.ENGINES)
	if abs(new_ets_allocation - ets_power_allocation) > 0.01:
		ets_power_allocation = new_ets_allocation
		_update_engine_performance()
	
	# Update performance tracking
	_update_performance_tracking()

## Update engine performance based on power level
func _update_engine_performance() -> void:
	"""Update engine performance values based on current power level."""
	# Calculate overall engine power level
	var old_power_level: float = engine_power_level
	engine_power_level = ets_power_allocation * subsystem_efficiency * damage_modifier
	
	# Update power state
	var old_power_state: PowerState = power_state
	power_state = _calculate_power_state(engine_power_level)
	
	# Calculate performance scaling
	var speed_multiplier: float = speed_scaling_curve.sample(engine_power_level)
	var acceleration_multiplier: float = acceleration_scaling_curve.sample(engine_power_level)
	var turn_rate_multiplier: float = turn_rate_scaling_curve.sample(engine_power_level)
	var afterburner_multiplier: float = afterburner_efficiency_curve.sample(engine_power_level)
	
	# Update current performance values
	current_max_speed = base_max_speed * speed_multiplier
	current_afterburner_speed = base_afterburner_speed * speed_multiplier * (1.0 + afterburner_multiplier * 0.5)
	current_acceleration = base_acceleration * acceleration_multiplier
	current_turn_rate = base_turn_rate * turn_rate_multiplier
	current_afterburner_efficiency = afterburner_multiplier
	
	# Track power adjustments
	if abs(engine_power_level - old_power_level) > 0.01:
		total_power_adjustments += 1
		engine_power_changed.emit(engine_power_level)
	
	# Emit performance change signals
	if power_state != old_power_state:
		power_state_history.append(power_state)
		if power_state_history.size() > 100:  # Keep last 100 state changes
			power_state_history.pop_front()
	
	speed_scaling_updated.emit(current_max_speed, current_afterburner_speed)
	maneuverability_changed.emit(current_turn_rate, current_acceleration)
	afterburner_efficiency_changed.emit(current_afterburner_efficiency)

## Calculate power state from power level
func _calculate_power_state(power_level: float) -> PowerState:
	"""Calculate power state from power level.
	
	Args:
		power_level: Engine power level (0.0 to 1.0)
		
	Returns:
		Corresponding power state
	"""
	if power_level <= 0.0:
		return PowerState.NO_POWER
	elif power_level < 0.25:
		return PowerState.MINIMAL_POWER
	elif power_level < 0.5:
		return PowerState.LOW_POWER
	elif power_level < 0.75:
		return PowerState.NORMAL_POWER
	elif power_level < 1.0:
		return PowerState.HIGH_POWER
	else:
		return PowerState.FULL_POWER

## Set engine subsystem efficiency (from damage)
func set_engine_subsystem_efficiency(efficiency: float) -> void:
	"""Set engine subsystem efficiency from damage.
	
	Args:
		efficiency: Efficiency multiplier (0.0 to 1.0)
	"""
	subsystem_efficiency = clamp(efficiency, 0.0, 1.0)
	_update_engine_performance()

## Set engine damage modifier
func set_engine_damage_modifier(modifier: float) -> void:
	"""Set engine damage modifier from hull damage.
	
	Args:
		modifier: Damage modifier (0.0 to 1.0)
	"""
	damage_modifier = clamp(modifier, 0.0, 1.0)
	_update_engine_performance()

## Get current engine performance
func get_engine_performance() -> Dictionary:
	"""Get current engine performance values.
	
	Returns:
		Dictionary with engine performance data
	"""
	return {
		"engine_power_level": engine_power_level,
		"ets_allocation": ets_power_allocation,
		"subsystem_efficiency": subsystem_efficiency,
		"damage_modifier": damage_modifier,
		"power_state": power_state,
		"power_state_name": _get_power_state_name(power_state),
		"current_max_speed": current_max_speed,
		"current_afterburner_speed": current_afterburner_speed,
		"current_acceleration": current_acceleration,
		"current_turn_rate": current_turn_rate,
		"current_afterburner_efficiency": current_afterburner_efficiency,
		"base_max_speed": base_max_speed,
		"base_afterburner_speed": base_afterburner_speed,
		"base_acceleration": base_acceleration,
		"base_turn_rate": base_turn_rate
	}

## Get speed scaling information
func get_speed_scaling() -> Dictionary:
	"""Get speed scaling information.
	
	Returns:
		Dictionary with speed scaling data
	"""
	var speed_percentage: float = (current_max_speed / base_max_speed) * 100.0 if base_max_speed > 0 else 0.0
	var afterburner_percentage: float = (current_afterburner_speed / base_afterburner_speed) * 100.0 if base_afterburner_speed > 0 else 0.0
	
	return {
		"speed_scaling_percentage": speed_percentage,
		"afterburner_scaling_percentage": afterburner_percentage,
		"acceleration_scaling_percentage": (current_acceleration / base_acceleration) * 100.0 if base_acceleration > 0 else 0.0,
		"turn_rate_scaling_percentage": (current_turn_rate / base_turn_rate) * 100.0 if base_turn_rate > 0 else 0.0,
		"afterburner_efficiency_percentage": current_afterburner_efficiency * 100.0,
		"overall_efficiency": engine_power_level * 100.0
	}

## Calculate afterburner fuel consumption rate
func get_afterburner_fuel_consumption_rate() -> float:
	"""Get current afterburner fuel consumption rate.
	
	Returns:
		Fuel consumption rate per second
	"""
	# Base consumption modified by efficiency and power level
	var consumption_modifier: float = 2.0 - current_afterburner_efficiency  # Less efficient = more consumption
	return base_afterburner_fuel_consumption * consumption_modifier

## Check if afterburner is viable
func is_afterburner_viable() -> bool:
	"""Check if afterburner can be used effectively.
	
	Returns:
		true if afterburner has reasonable efficiency
	"""
	return current_afterburner_efficiency > 0.2 and engine_power_level > 0.1

## Apply emergency power boost
func apply_emergency_power_boost(boost_multiplier: float, duration: float) -> void:
	"""Apply temporary emergency power boost.
	
	Args:
		boost_multiplier: Power boost multiplier (e.g., 1.5 for 50% boost)
		duration: Duration of boost in seconds
	"""
	var original_damage_modifier: float = damage_modifier
	damage_modifier = min(1.0, damage_modifier * boost_multiplier)
	_update_engine_performance()
	
	# Create timer to restore normal power
	var timer: Timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func(): _restore_emergency_power(original_damage_modifier))
	add_child(timer)
	timer.start()

## Restore power after emergency boost
func _restore_emergency_power(original_modifier: float) -> void:
	"""Restore normal power after emergency boost.
	
	Args:
		original_modifier: Original damage modifier to restore
	"""
	damage_modifier = original_modifier
	_update_engine_performance()

## Update performance tracking
func _update_performance_tracking() -> void:
	"""Update engine performance tracking and history."""
	if Engine.get_process_frames() % 60 == 0:  # Update every second
		performance_efficiency_tracking.append(engine_power_level)
		if performance_efficiency_tracking.size() > 300:  # Keep 5 minutes of history
			performance_efficiency_tracking.pop_front()

## Get engine performance statistics
func get_engine_stats() -> Dictionary:
	"""Get engine performance statistics.
	
	Returns:
		Dictionary with engine metrics
	"""
	var avg_efficiency: float = 0.0
	if performance_efficiency_tracking.size() > 0:
		for efficiency in performance_efficiency_tracking:
			avg_efficiency += efficiency
		avg_efficiency /= performance_efficiency_tracking.size()
	
	var speed_scaling: Dictionary = get_speed_scaling()
	
	return {
		"total_power_adjustments": total_power_adjustments,
		"current_power_level": engine_power_level,
		"average_efficiency": avg_efficiency,
		"power_state_changes": power_state_history.size(),
		"current_power_state": power_state,
		"speed_efficiency": speed_scaling["speed_scaling_percentage"],
		"afterburner_efficiency": speed_scaling["afterburner_efficiency_percentage"],
		"fuel_consumption_rate": get_afterburner_fuel_consumption_rate()
	}

## Get power state name
func _get_power_state_name(state: PowerState) -> String:
	"""Get human-readable name for power state.
	
	Args:
		state: Power state enum
		
	Returns:
		State name string
	"""
	match state:
		PowerState.FULL_POWER:
			return "Full Power"
		PowerState.HIGH_POWER:
			return "High Power"
		PowerState.NORMAL_POWER:
			return "Normal Power"
		PowerState.LOW_POWER:
			return "Low Power"
		PowerState.MINIMAL_POWER:
			return "Minimal Power"
		PowerState.NO_POWER:
			return "No Power"
		_:
			return "Unknown"

## Get debug information
func get_debug_info() -> String:
	"""Get debug information about engine power system.
	
	Returns:
		Formatted debug information string
	"""
	var performance: Dictionary = get_engine_performance()
	var scaling: Dictionary = get_speed_scaling()
	var info: Array[String] = []
	
	info.append("=== Engine Power System ===")
	info.append("Power Level: %.1f%% (%s)" % [performance["engine_power_level"] * 100.0, performance["power_state_name"]])
	info.append("ETS Allocation: %.1f%%" % [performance["ets_allocation"] * 100.0])
	info.append("Subsystem Efficiency: %.2f" % performance["subsystem_efficiency"])
	info.append("Damage Modifier: %.2f" % performance["damage_modifier"])
	
	info.append("\\nPerformance Scaling:")
	info.append("  Speed: %.1f km/h (%.1f%%)" % [performance["current_max_speed"], scaling["speed_scaling_percentage"]])
	info.append("  Afterburner: %.1f km/h (%.1f%%)" % [performance["current_afterburner_speed"], scaling["afterburner_scaling_percentage"]])
	info.append("  Acceleration: %.1f (%.1f%%)" % [performance["current_acceleration"], scaling["acceleration_scaling_percentage"]])
	info.append("  Turn Rate: %.2f (%.1f%%)" % [performance["current_turn_rate"], scaling["turn_rate_scaling_percentage"]])
	info.append("  Afterburner Efficiency: %.1f%%" % scaling["afterburner_efficiency_percentage"])
	
	info.append("\\nFuel Consumption:")
	info.append("  Afterburner Rate: %.1f per second" % get_afterburner_fuel_consumption_rate())
	info.append("  Afterburner Viable: %s" % ("Yes" if is_afterburner_viable() else "No"))
	
	return "\\n".join(info)