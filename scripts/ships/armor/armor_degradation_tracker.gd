class_name ArmorDegradationTracker
extends Node

## SHIP-011 AC5: Armor Degradation System
## Handles progressive armor weakening from repeated impacts and accumulated damage
## Implements WCS-authentic armor fatigue and structural integrity mechanics

# EPIC-002 Asset Core Integration
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Signals
signal armor_degraded(zone_name: String, degradation_level: float)
signal armor_fatigue_increased(zone_name: String, fatigue_level: float)
signal structural_integrity_compromised(zone_name: String, integrity_level: float)
signal armor_failure_predicted(zone_name: String, estimated_time: float)
signal degradation_threshold_exceeded(zone_name: String, threshold_type: String)

# Degradation tracking data
var armor_degradation_data: Dictionary = {}
var impact_history: Dictionary = {}
var fatigue_accumulation: Dictionary = {}
var structural_integrity: Dictionary = {}

# Ship references
var owner_ship: Node = null
var armor_configuration: ShipArmorConfiguration = null

# Configuration
@export var enable_fatigue_mechanics: bool = true
@export var enable_structural_failure: bool = true
@export var enable_repair_degradation: bool = true
@export var debug_degradation_logging: bool = false

# Degradation parameters
@export var base_degradation_rate: float = 0.01      # 1% per impact
@export var fatigue_threshold: float = 0.3           # 30% fatigue = structural concern
@export var failure_threshold: float = 0.7          # 70% degradation = failure risk
@export var repair_efficiency_loss: float = 0.1     # 10% efficiency loss per repair cycle

# Physics parameters
@export var stress_concentration_factor: float = 2.0  # Stress concentration at damage sites
@export var crack_propagation_rate: float = 0.05     # How fast cracks spread
@export var temperature_degradation_factor: float = 0.02  # Heat damage factor

# Performance settings
@export var degradation_update_frequency: float = 1.0  # Update every second
@export var max_impact_history: int = 100             # Maximum impacts to track per zone

# Internal state
var degradation_timer: float = 0.0
var failure_predictions: Dictionary = {}

func _ready() -> void:
	_setup_degradation_tracking()

## Initialize degradation tracker for a ship
func initialize_for_ship(ship: Node) -> void:
	owner_ship = ship
	
	# Find armor configuration component
	armor_configuration = ship.get_node_or_null("ShipArmorConfiguration")
	if not armor_configuration:
		push_warning("ArmorDegradationTracker: ShipArmorConfiguration not found on ship")
		return
	
	# Initialize degradation data for all armor zones
	_initialize_armor_zones()
	
	if debug_degradation_logging:
		print("ArmorDegradationTracker: Initialized for ship %s" % ship.name)

## Apply degradation from impact damage
func apply_impact_degradation(
	zone_name: String,
	damage_amount: float,
	damage_type: int,
	impact_conditions: Dictionary = {}
) -> Dictionary:
	
	if not armor_degradation_data.has(zone_name):
		_initialize_zone_degradation(zone_name)
	
	var zone_data = armor_degradation_data[zone_name]
	var degradation_result = _calculate_impact_degradation(zone_data, damage_amount, damage_type, impact_conditions)
	
	# Apply degradation
	zone_data["total_degradation"] += degradation_result["degradation_amount"]
	zone_data["fatigue_level"] += degradation_result["fatigue_increase"]
	zone_data["impact_count"] += 1
	zone_data["last_impact_time"] = Time.get_unix_time_from_system()
	
	# Update structural integrity
	_update_structural_integrity(zone_name)
	
	# Record impact in history
	_record_impact_history(zone_name, damage_amount, damage_type, impact_conditions)
	
	# Check for threshold violations
	_check_degradation_thresholds(zone_name)
	
	# Update failure predictions
	_update_failure_predictions(zone_name)
	
	# Emit signals
	armor_degraded.emit(zone_name, zone_data["total_degradation"])
	if zone_data["fatigue_level"] > fatigue_threshold:
		armor_fatigue_increased.emit(zone_name, zone_data["fatigue_level"])
	
	if debug_degradation_logging:
		print("ArmorDegradationTracker: %s degradation: %.1f%% (fatigue: %.1f%%)" % [
			zone_name, zone_data["total_degradation"] * 100, zone_data["fatigue_level"] * 100
		])
	
	return degradation_result

## Apply thermal degradation from heat exposure
func apply_thermal_degradation(zone_name: String, temperature: float, exposure_time: float) -> float:
	if not armor_degradation_data.has(zone_name):
		_initialize_zone_degradation(zone_name)
	
	var zone_data = armor_degradation_data[zone_name]
	
	# Calculate thermal degradation based on temperature and time
	var thermal_stress = max(0.0, temperature - 100.0)  # Damage above 100°C
	var thermal_degradation = thermal_stress * exposure_time * temperature_degradation_factor
	
	zone_data["thermal_degradation"] += thermal_degradation
	zone_data["total_degradation"] = min(1.0, zone_data["total_degradation"] + thermal_degradation)
	
	_update_structural_integrity(zone_name)
	
	return thermal_degradation

## Apply repair-induced degradation
func apply_repair_degradation(zone_name: String, repair_quality: float = 1.0) -> float:
	if not enable_repair_degradation:
		return 0.0
	
	if not armor_degradation_data.has(zone_name):
		_initialize_zone_degradation(zone_name)
	
	var zone_data = armor_degradation_data[zone_name]
	
	# Each repair cycle reduces material integrity slightly
	var repair_degradation = repair_efficiency_loss * (1.0 - repair_quality)
	zone_data["repair_cycles"] += 1
	zone_data["repair_degradation"] += repair_degradation
	zone_data["total_degradation"] = min(1.0, zone_data["total_degradation"] + repair_degradation)
	
	# Reduce fatigue based on repair quality
	var fatigue_reduction = 0.5 * repair_quality
	zone_data["fatigue_level"] = max(0.0, zone_data["fatigue_level"] - fatigue_reduction)
	
	_update_structural_integrity(zone_name)
	
	return repair_degradation

## Get degradation status for armor zone
func get_degradation_status(zone_name: String) -> Dictionary:
	if not armor_degradation_data.has(zone_name):
		return {}
	
	var zone_data = armor_degradation_data[zone_name]
	var integrity = structural_integrity.get(zone_name, 1.0)
	var prediction = failure_predictions.get(zone_name, {})
	
	return {
		"zone_name": zone_name,
		"total_degradation": zone_data["total_degradation"],
		"fatigue_level": zone_data["fatigue_level"],
		"structural_integrity": integrity,
		"impact_degradation": zone_data["impact_degradation"],
		"thermal_degradation": zone_data["thermal_degradation"],
		"repair_degradation": zone_data["repair_degradation"],
		"impact_count": zone_data["impact_count"],
		"repair_cycles": zone_data["repair_cycles"],
		"failure_risk": _calculate_failure_risk(zone_data),
		"estimated_remaining_life": prediction.get("estimated_time", -1.0),
		"degradation_rate": _calculate_current_degradation_rate(zone_name),
		"condition_rating": _get_condition_rating(zone_data["total_degradation"])
	}

## Get comprehensive degradation report
func get_comprehensive_degradation_report() -> Dictionary:
	var total_zones = armor_degradation_data.size()
	var degraded_zones = 0
	var critical_zones = 0
	var average_degradation = 0.0
	var zones_at_risk: Array[String] = []
	
	for zone_name in armor_degradation_data.keys():
		var zone_data = armor_degradation_data[zone_name]
		var degradation = zone_data["total_degradation"]
		
		average_degradation += degradation
		
		if degradation > 0.1:  # 10% degradation threshold
			degraded_zones += 1
		
		if degradation > failure_threshold:
			critical_zones += 1
			zones_at_risk.append(zone_name)
	
	if total_zones > 0:
		average_degradation /= total_zones
	
	return {
		"total_zones": total_zones,
		"degraded_zones": degraded_zones,
		"critical_zones": critical_zones,
		"average_degradation": average_degradation,
		"zones_at_risk": zones_at_risk,
		"overall_condition": _get_overall_condition_rating(),
		"maintenance_priority": _get_maintenance_priorities(),
		"estimated_overhaul_time": _estimate_overhaul_requirement(),
		"report_timestamp": Time.get_unix_time_from_system()
	}

## Setup degradation tracking system
func _setup_degradation_tracking() -> void:
	armor_degradation_data.clear()
	impact_history.clear()
	fatigue_accumulation.clear()
	structural_integrity.clear()
	failure_predictions.clear()

## Initialize armor zones for degradation tracking
func _initialize_armor_zones() -> void:
	if not armor_configuration:
		return
	
	# Get all armor zones from configuration
	var coverage_analysis = armor_configuration.get_armor_coverage_analysis()
	
	# Initialize default zones if none found
	if coverage_analysis.get("armor_zone_count", 0) == 0:
		_initialize_zone_degradation("hull")
	else:
		# Initialize zones from armor configuration
		var armor_zones = armor_configuration.armor_zones
		for zone_name in armor_zones.keys():
			_initialize_zone_degradation(zone_name)

## Initialize degradation data for a zone
func _initialize_zone_degradation(zone_name: String) -> void:
	armor_degradation_data[zone_name] = {
		"total_degradation": 0.0,
		"impact_degradation": 0.0,
		"thermal_degradation": 0.0,
		"repair_degradation": 0.0,
		"fatigue_level": 0.0,
		"impact_count": 0,
		"repair_cycles": 0,
		"creation_time": Time.get_unix_time_from_system(),
		"last_impact_time": 0.0,
		"last_repair_time": 0.0
	}
	
	structural_integrity[zone_name] = 1.0
	impact_history[zone_name] = []
	fatigue_accumulation[zone_name] = []

## Calculate impact degradation
func _calculate_impact_degradation(
	zone_data: Dictionary,
	damage_amount: float,
	damage_type: int,
	impact_conditions: Dictionary
) -> Dictionary:
	
	# Base degradation from damage
	var base_degradation = damage_amount * base_degradation_rate
	
	# Damage type modifiers
	var damage_modifier = _get_damage_type_degradation_modifier(damage_type)
	
	# Repeated impact stress concentration
	var stress_concentration = _calculate_stress_concentration(zone_data)
	
	# Impact velocity/energy effects
	var velocity = impact_conditions.get("velocity", 100.0)
	var velocity_modifier = 1.0 + (velocity / 1000.0)  # Higher velocity = more degradation
	
	# Temperature effects
	var temperature = impact_conditions.get("temperature", 20.0)
	var temperature_modifier = 1.0 + max(0.0, (temperature - 100.0) / 500.0)
	
	# Calculate final degradation
	var degradation_amount = base_degradation * damage_modifier * stress_concentration * velocity_modifier * temperature_modifier
	degradation_amount = clamp(degradation_amount, 0.0, 0.1)  # Maximum 10% per impact
	
	# Calculate fatigue increase
	var fatigue_increase = degradation_amount * 0.5  # Fatigue accumulates slower
	if enable_fatigue_mechanics:
		fatigue_increase *= _calculate_fatigue_multiplier(zone_data)
	
	return {
		"degradation_amount": degradation_amount,
		"fatigue_increase": fatigue_increase,
		"base_degradation": base_degradation,
		"damage_modifier": damage_modifier,
		"stress_concentration": stress_concentration,
		"velocity_modifier": velocity_modifier,
		"temperature_modifier": temperature_modifier
	}

## Get damage type degradation modifier
func _get_damage_type_degradation_modifier(damage_type: int) -> float:
	match damage_type:
		DamageTypes.Type.KINETIC:
			return 1.2  # Kinetic impacts cause structural stress
		DamageTypes.Type.ENERGY:
			return 0.8  # Energy damage less structural
		DamageTypes.Type.EXPLOSIVE:
			return 1.5  # Explosives cause maximum structural damage
		DamageTypes.Type.PLASMA:
			return 1.1  # Plasma causes thermal and structural damage
		_:
			return 1.0

## Calculate stress concentration from previous impacts
func _calculate_stress_concentration(zone_data: Dictionary) -> float:
	var impact_count = zone_data.get("impact_count", 0)
	var fatigue_level = zone_data.get("fatigue_level", 0.0)
	
	# Stress increases with impact count and fatigue
	var stress_factor = 1.0 + (impact_count * 0.1) + (fatigue_level * stress_concentration_factor)
	
	return min(stress_factor, 3.0)  # Maximum 3x stress concentration

## Calculate fatigue multiplier
func _calculate_fatigue_multiplier(zone_data: Dictionary) -> float:
	var current_fatigue = zone_data.get("fatigue_level", 0.0)
	
	# Fatigue accelerates as material weakens
	return 1.0 + (current_fatigue * 2.0)

## Update structural integrity for zone
func _update_structural_integrity(zone_name: String) -> void:
	var zone_data = armor_degradation_data.get(zone_name, {})
	var total_degradation = zone_data.get("total_degradation", 0.0)
	var fatigue_level = zone_data.get("fatigue_level", 0.0)
	
	# Structural integrity decreases with degradation and fatigue
	var base_integrity = 1.0 - total_degradation
	var fatigue_penalty = fatigue_level * 0.3  # Fatigue reduces integrity
	var integrity = clamp(base_integrity - fatigue_penalty, 0.0, 1.0)
	
	var old_integrity = structural_integrity.get(zone_name, 1.0)
	structural_integrity[zone_name] = integrity
	
	# Emit signal if integrity dropped significantly
	if integrity < old_integrity - 0.1:
		structural_integrity_compromised.emit(zone_name, integrity)

## Record impact in history
func _record_impact_history(zone_name: String, damage: float, damage_type: int, conditions: Dictionary) -> void:
	var history = impact_history.get(zone_name, [])
	
	var impact_record: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"damage_amount": damage,
		"damage_type": damage_type,
		"conditions": conditions
	}
	
	history.append(impact_record)
	
	# Limit history size
	if history.size() > max_impact_history:
		history.pop_front()
	
	impact_history[zone_name] = history

## Check degradation thresholds
func _check_degradation_thresholds(zone_name: String) -> void:
	var zone_data = armor_degradation_data.get(zone_name, {})
	var degradation = zone_data.get("total_degradation", 0.0)
	var fatigue = zone_data.get("fatigue_level", 0.0)
	
	# Check fatigue threshold
	if fatigue > fatigue_threshold:
		degradation_threshold_exceeded.emit(zone_name, "fatigue")
	
	# Check failure threshold
	if degradation > failure_threshold:
		degradation_threshold_exceeded.emit(zone_name, "failure_risk")
	
	# Check structural integrity
	var integrity = structural_integrity.get(zone_name, 1.0)
	if integrity < 0.3:
		degradation_threshold_exceeded.emit(zone_name, "structural_failure")

## Update failure predictions
func _update_failure_predictions(zone_name: String) -> void:
	var zone_data = armor_degradation_data.get(zone_name, {})
	var current_degradation = zone_data.get("total_degradation", 0.0)
	var degradation_rate = _calculate_current_degradation_rate(zone_name)
	
	if degradation_rate > 0.0:
		var remaining_degradation = 1.0 - current_degradation
		var estimated_time = remaining_degradation / degradation_rate
		
		failure_predictions[zone_name] = {
			"estimated_time": estimated_time,
			"confidence": _calculate_prediction_confidence(zone_name),
			"degradation_rate": degradation_rate
		}
		
		# Emit warning if failure predicted soon
		if estimated_time < 3600.0:  # Less than 1 hour
			armor_failure_predicted.emit(zone_name, estimated_time)

## Calculate current degradation rate
func _calculate_current_degradation_rate(zone_name: String) -> float:
	var history = impact_history.get(zone_name, [])
	if history.size() < 2:
		return 0.0
	
	# Calculate rate based on recent history
	var recent_impacts = history.slice(-10)  # Last 10 impacts
	var time_span = recent_impacts[-1]["timestamp"] - recent_impacts[0]["timestamp"]
	
	if time_span <= 0.0:
		return 0.0
	
	var total_degradation = 0.0
	for impact in recent_impacts:
		total_degradation += impact["damage_amount"] * base_degradation_rate
	
	return total_degradation / time_span

## Calculate failure risk
func _calculate_failure_risk(zone_data: Dictionary) -> float:
	var degradation = zone_data.get("total_degradation", 0.0)
	var fatigue = zone_data.get("fatigue_level", 0.0)
	var integrity = structural_integrity.get("", 1.0)
	
	# Risk increases exponentially near failure threshold
	var degradation_risk = pow(degradation / failure_threshold, 2.0)
	var fatigue_risk = fatigue / fatigue_threshold
	var integrity_risk = 1.0 - integrity
	
	return clamp(max(degradation_risk, fatigue_risk, integrity_risk), 0.0, 1.0)

## Get condition rating
func _get_condition_rating(degradation: float) -> String:
	if degradation < 0.1:
		return "Excellent"
	elif degradation < 0.3:
		return "Good"
	elif degradation < 0.5:
		return "Fair"
	elif degradation < 0.7:
		return "Poor"
	else:
		return "Critical"

## Calculate prediction confidence
func _calculate_prediction_confidence(zone_name: String) -> float:
	var history = impact_history.get(zone_name, [])
	var history_size = history.size()
	
	# Confidence based on historical data availability
	return clamp(float(history_size) / 50.0, 0.1, 1.0)

## Get overall condition rating
func _get_overall_condition_rating() -> String:
	var report = get_comprehensive_degradation_report()
	var average_degradation = report["average_degradation"]
	
	return _get_condition_rating(average_degradation)

## Get maintenance priorities
func _get_maintenance_priorities() -> Array[Dictionary]:
	var priorities: Array[Dictionary] = []
	
	for zone_name in armor_degradation_data.keys():
		var status = get_degradation_status(zone_name)
		var risk = status["failure_risk"]
		
		if risk > 0.3:  # 30% risk threshold
			priorities.append({
				"zone_name": zone_name,
				"risk_level": risk,
				"condition": status["condition_rating"],
				"priority": _calculate_maintenance_priority(status)
			})
	
	# Sort by priority (highest first)
	priorities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["priority"] > b["priority"]
	)
	
	return priorities

## Calculate maintenance priority
func _calculate_maintenance_priority(status: Dictionary) -> float:
	var risk = status["failure_risk"]
	var degradation = status["total_degradation"]
	var integrity = status["structural_integrity"]
	
	return risk * 0.5 + degradation * 0.3 + (1.0 - integrity) * 0.2

## Estimate overhaul requirement
func _estimate_overhaul_requirement() -> float:
	var report = get_comprehensive_degradation_report()
	var critical_zones = report["critical_zones"]
	var total_zones = report["total_zones"]
	
	if total_zones == 0:
		return -1.0
	
	var critical_percentage = float(critical_zones) / float(total_zones)
	
	# Recommend overhaul if 30% of zones are critical
	if critical_percentage >= 0.3:
		return 0.0  # Immediate overhaul needed
	elif critical_percentage >= 0.15:
		return 24.0 * 3600.0  # 24 hours
	else:
		return -1.0  # No overhaul needed

## Process frame updates
func _process(delta: float) -> void:
	degradation_timer += delta
	if degradation_timer >= degradation_update_frequency:
		degradation_timer = 0.0
		_update_degradation_progression()

## Update degradation progression over time
func _update_degradation_progression() -> void:
	if not enable_fatigue_mechanics:
		return
	
	# Update crack propagation and fatigue accumulation
	for zone_name in armor_degradation_data.keys():
		var zone_data = armor_degradation_data[zone_name]
		var current_degradation = zone_data["total_degradation"]
		
		# Gradual crack propagation in damaged areas
		if current_degradation > 0.1:
			var propagation = crack_propagation_rate * current_degradation * degradation_update_frequency
			zone_data["total_degradation"] = min(1.0, current_degradation + propagation)
			
			_update_structural_integrity(zone_name)
			_update_failure_predictions(zone_name)