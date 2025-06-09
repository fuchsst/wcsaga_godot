class_name TargetClassification
extends Node

## HUD-008 Component 5: Target Classification and Identification System
## Advanced contact identification using multiple sensors and classification databases
## Provides real-time target classification with confidence assessment and IFF integration

signal target_classified(target: Node, classification: String)
signal classification_changed(target: Node, old_classification: String, new_classification: String)
signal unknown_contact_detected(target: Node, sensor_data: Dictionary)
signal iff_response_received(target: Node, iff_data: Dictionary)
signal classification_confidence_updated(target: Node, confidence: float)

# Classification parameters
@export var auto_classification_enabled: bool = true
@export var classification_update_frequency: float = 5.0  # 5Hz classification updates
@export var confidence_threshold: float = 0.6  # Minimum confidence for classification
@export var use_iff_system: bool = true
@export var use_visual_recognition: bool = true
@export var use_signature_analysis: bool = true

# Classification database and systems
var classification_database: ClassificationDatabase
var iff_system: IFFSystem
var visual_recognizer: VisualRecognizer
var signature_analyzer: SignatureAnalyzer
var multi_sensor_fusion: MultiSensorFusion

# Current classifications
var target_classifications: Dictionary = {}  # target -> ClassificationData
var classification_history: Dictionary = {}  # target -> Array[ClassificationRecord]
var unknown_contacts: Array[Node] = []

# Classification categories
var classification_types: Dictionary = {
	"ship_classes": [
		"fighter", "bomber", "interceptor", "assault", "scout",
		"corvette", "frigate", "destroyer", "cruiser", "battleship",
		"dreadnought", "carrier", "transport", "cargo", "tanker",
		"medical", "science", "command", "stealth"
	],
	"ordnance_types": [
		"missile", "torpedo", "bomb", "mine", "probe", "drone",
		"countermeasure", "beacon", "buoy"
	],
	"debris_types": [
		"wreckage", "asteroid", "debris_field", "space_junk",
		"derelict", "hulk"
	],
	"special_types": [
		"jump_node", "nav_buoy", "sensor_array", "comm_relay",
		"defense_platform", "station", "installation"
	]
}

# Classification data structure
class ClassificationData:
	var target_node: Node
	var primary_classification: String = "unknown"
	var sub_classification: String = ""
	var confidence: float = 0.0
	var classification_source: String = "unknown"  # iff, visual, signature, database
	var alternative_classifications: Array[Dictionary] = []  # Other possibilities
	var visual_signature: Dictionary = {}
	var radar_signature: Dictionary = {}
	var iff_data: Dictionary = {}
	var sensor_readings: Dictionary = {}
	var size_class: String = "medium"  # tiny, small, medium, large, huge
	var threat_classification: String = "unknown"  # friendly, hostile, neutral, unknown
	var first_classified: float = 0.0
	var last_updated: float = 0.0
	var classification_locked: bool = false  # Manual override
	
	func _init(target: Node):
		target_node = target
		first_classified = Time.get_ticks_usec() / 1000000.0
		last_updated = first_classified

# Classification record for history tracking
class ClassificationRecord:
	var timestamp: float
	var classification: String
	var confidence: float
	var source: String
	var reason: String
	
	func _init(cls: String, conf: float, src: String, rsn: String = ""):
		timestamp = Time.get_ticks_usec() / 1000000.0
		classification = cls
		confidence = conf
		source = src
		reason = rsn

# Classification database system
class ClassificationDatabase:
	var ship_database: Dictionary = {}
	var signature_database: Dictionary = {}
	var known_configurations: Dictionary = {}
	
	func _init():
		_load_classification_database()
	
	func classify_by_database(sensor_data: Dictionary) -> Dictionary:
		var classification = {
			"type": "unknown",
			"confidence": 0.0,
			"source": "database",
			"matches": []
		}
		
		# Check against known signatures
		var best_match = _find_best_signature_match(sensor_data)
		if best_match.confidence > 0.5:
			classification.type = best_match.classification
			classification.confidence = best_match.confidence
			classification.matches = [best_match]
		
		return classification
	
	func _find_best_signature_match(sensor_data: Dictionary) -> Dictionary:
		var best_match = {
			"classification": "unknown",
			"confidence": 0.0,
			"signature_id": ""
		}
		
		for signature_id in signature_database.keys():
			var signature = signature_database[signature_id]
			var match_confidence = _calculate_signature_match(sensor_data, signature)
			
			if match_confidence > best_match.confidence:
				best_match.classification = signature.classification
				best_match.confidence = match_confidence
				best_match.signature_id = signature_id
		
		return best_match
	
	func _calculate_signature_match(sensor_data: Dictionary, signature: Dictionary) -> float:
		var match_score = 0.0
		var factors_checked = 0
		
		# Check radar cross section
		if sensor_data.has("radar_cross_section") and signature.has("rcs_range"):
			var rcs = sensor_data.radar_cross_section
			var rcs_range = signature.rcs_range
			if rcs >= rcs_range[0] and rcs <= rcs_range[1]:
				match_score += 0.3
			factors_checked += 1
		
		# Check size/dimensions
		if sensor_data.has("estimated_size") and signature.has("size_range"):
			var size = sensor_data.estimated_size
			var size_range = signature.size_range
			if size >= size_range[0] and size <= size_range[1]:
				match_score += 0.2
			factors_checked += 1
		
		# Check speed capabilities
		if sensor_data.has("max_speed") and signature.has("speed_range"):
			var speed = sensor_data.max_speed
			var speed_range = signature.speed_range
			if speed >= speed_range[0] and speed <= speed_range[1]:
				match_score += 0.2
			factors_checked += 1
		
		# Check energy signature
		if sensor_data.has("energy_signature") and signature.has("energy_pattern"):
			var sig_similarity = _compare_energy_signatures(
				sensor_data.energy_signature, 
				signature.energy_pattern
			)
			match_score += sig_similarity * 0.3
			factors_checked += 1
		
		return match_score if factors_checked > 0 else 0.0
	
	func _compare_energy_signatures(signature1: Dictionary, signature2: Dictionary) -> float:
		# Simplified energy signature comparison
		var similarity = 0.5  # Base similarity
		
		if signature1.has("power_output") and signature2.has("power_output"):
			var power_diff = abs(signature1.power_output - signature2.power_output)
			var power_similarity = 1.0 - clamp(power_diff / 1000.0, 0.0, 1.0)
			similarity = (similarity + power_similarity) / 2.0
		
		return similarity
	
	func _load_classification_database() -> void:
		# Load ship classifications
		ship_database = {
			"fighter_light": {
				"classification": "fighter",
				"rcs_range": [50.0, 150.0],
				"size_range": [10.0, 25.0],
				"speed_range": [200.0, 600.0],
				"typical_weapons": ["laser", "missile"]
			},
			"fighter_heavy": {
				"classification": "assault",
				"rcs_range": [100.0, 300.0],
				"size_range": [20.0, 40.0],
				"speed_range": [150.0, 400.0],
				"typical_weapons": ["plasma", "torpedo"]
			},
			"bomber": {
				"classification": "bomber",
				"rcs_range": [200.0, 800.0],
				"size_range": [30.0, 80.0],
				"speed_range": [100.0, 300.0],
				"typical_weapons": ["torpedo", "bomb"]
			},
			"capital_light": {
				"classification": "corvette",
				"rcs_range": [1000.0, 5000.0],
				"size_range": [100.0, 300.0],
				"speed_range": [50.0, 200.0],
				"typical_weapons": ["beam", "flak"]
			},
			"capital_heavy": {
				"classification": "cruiser",
				"rcs_range": [5000.0, 50000.0],
				"size_range": [500.0, 2000.0],
				"speed_range": [20.0, 100.0],
				"typical_weapons": ["beam", "torpedo"]
			}
		}

# IFF (Identify Friend or Foe) system
class IFFSystem:
	var iff_enabled: bool = true
	var iff_codes: Dictionary = {}
	var interrogation_frequency: float = 2.0  # Interrogate every 2 seconds
	
	func interrogate_target(target: Node) -> Dictionary:
		var iff_response = {
			"has_response": false,
			"iff_code": "",
			"classification": "unknown",
			"allegiance": "unknown",
			"authenticity": 0.0
		}
		
		if not iff_enabled:
			return iff_response
		
		# Check if target responds to IFF
		if target.has_method("respond_to_iff"):
			var response = target.respond_to_iff()
			iff_response.has_response = true
			iff_response.iff_code = response.get("code", "")
			iff_response.authenticity = response.get("authenticity", 0.0)
			
			# Look up classification
			var classification_data = _lookup_iff_code(iff_response.iff_code)
			iff_response.classification = classification_data.classification
			iff_response.allegiance = classification_data.allegiance
		
		return iff_response
	
	func _lookup_iff_code(code: String) -> Dictionary:
		return iff_codes.get(code, {
			"classification": "unknown",
			"allegiance": "unknown"
		})
	
	func load_iff_codes(codes: Dictionary) -> void:
		iff_codes = codes

# Visual recognition system
class VisualRecognizer:
	var visual_database: Dictionary = {}
	var recognition_range: float = 2000.0
	
	func recognize_target(target: Node, distance: float) -> Dictionary:
		var recognition = {
			"classification": "unknown",
			"confidence": 0.0,
			"source": "visual",
			"features_detected": []
		}
		
		# Check if target is within visual recognition range
		if distance > recognition_range:
			return recognition
		
		# Get visual features
		var visual_features = _extract_visual_features(target)
		
		# Match against database
		var match = _match_visual_features(visual_features)
		recognition.classification = match.classification
		recognition.confidence = match.confidence
		recognition.features_detected = visual_features
		
		return recognition
	
	func _extract_visual_features(target: Node) -> Array:
		var features: Array = []
		
		# This would integrate with 3D model analysis
		if target.has_method("get_visual_signature"):
			var signature = target.get_visual_signature()
			features = signature.get("features", [])
		else:
			# Estimate features based on node properties
			features = ["generic_ship"]
		
		return features
	
	func _match_visual_features(features: Array) -> Dictionary:
		var best_match = {
			"classification": "unknown",
			"confidence": 0.0
		}
		
		# Match features against visual database
		for classification in visual_database.keys():
			var known_features = visual_database[classification]
			var match_score = _calculate_feature_match(features, known_features)
			
			if match_score > best_match.confidence:
				best_match.classification = classification
				best_match.confidence = match_score
		
		return best_match
	
	func _calculate_feature_match(features: Array, known_features: Array) -> float:
		var matches = 0
		for feature in features:
			if feature in known_features:
				matches += 1
		
		return float(matches) / max(1, features.size())

# Signature analysis system
class SignatureAnalyzer:
	var signature_patterns: Dictionary = {}
	
	func analyze_signatures(sensor_data: Dictionary) -> Dictionary:
		var analysis = {
			"classification": "unknown",
			"confidence": 0.0,
			"source": "signature",
			"signature_type": "composite"
		}
		
		# Analyze radar signature
		var radar_analysis = _analyze_radar_signature(sensor_data)
		
		# Analyze thermal signature
		var thermal_analysis = _analyze_thermal_signature(sensor_data)
		
		# Analyze electromagnetic signature
		var em_analysis = _analyze_em_signature(sensor_data)
		
		# Combine analyses
		var combined_confidence = (radar_analysis.confidence + 
								  thermal_analysis.confidence + 
								  em_analysis.confidence) / 3.0
		
		if combined_confidence > analysis.confidence:
			analysis.classification = radar_analysis.classification  # Use best analysis
			analysis.confidence = combined_confidence
		
		return analysis
	
	func _analyze_radar_signature(sensor_data: Dictionary) -> Dictionary:
		var analysis = {
			"classification": "unknown",
			"confidence": 0.0
		}
		
		if sensor_data.has("radar_cross_section"):
			var rcs = sensor_data.radar_cross_section
			
			# Classify based on radar cross section
			if rcs < 10.0:
				analysis.classification = "missile"
				analysis.confidence = 0.7
			elif rcs < 100.0:
				analysis.classification = "fighter"
				analysis.confidence = 0.6
			elif rcs < 1000.0:
				analysis.classification = "bomber"
				analysis.confidence = 0.6
			elif rcs < 10000.0:
				analysis.classification = "corvette"
				analysis.confidence = 0.7
			else:
				analysis.classification = "capital"
				analysis.confidence = 0.8
		
		return analysis
	
	func _analyze_thermal_signature(sensor_data: Dictionary) -> Dictionary:
		var analysis = {
			"classification": "unknown",
			"confidence": 0.0
		}
		
		# Thermal signature analysis would go here
		return analysis
	
	func _analyze_em_signature(sensor_data: Dictionary) -> Dictionary:
		var analysis = {
			"classification": "unknown",
			"confidence": 0.0
		}
		
		# Electromagnetic signature analysis would go here
		return analysis

# Multi-sensor fusion system
class MultiSensorFusion:
	func fuse_classifications(classifications: Array[Dictionary]) -> Dictionary:
		var fused = {
			"classification": "unknown",
			"confidence": 0.0,
			"sources": [],
			"fusion_method": "weighted_average"
		}
		
		if classifications.is_empty():
			return fused
		
		# Group classifications by type
		var classification_groups: Dictionary = {}
		var total_weight = 0.0
		
		for classification in classifications:
			var type = classification.get("type", "unknown")
			var confidence = classification.get("confidence", 0.0)
			var source = classification.get("source", "unknown")
			
			if not classification_groups.has(type):
				classification_groups[type] = {
					"total_confidence": 0.0,
					"sources": [],
					"count": 0
				}
			
			# Weight sources differently
			var source_weight = _get_source_weight(source)
			classification_groups[type].total_confidence += confidence * source_weight
			classification_groups[type].sources.append(source)
			classification_groups[type].count += 1
			total_weight += source_weight
		
		# Find best classification
		var best_type = "unknown"
		var best_confidence = 0.0
		
		for type in classification_groups.keys():
			var group = classification_groups[type]
			var weighted_confidence = group.total_confidence / group.count
			
			if weighted_confidence > best_confidence:
				best_confidence = weighted_confidence
				best_type = type
				fused.sources = group.sources
		
		fused.classification = best_type
		fused.confidence = best_confidence
		
		return fused
	
	func _get_source_weight(source: String) -> float:
		# Weight different sources
		match source:
			"iff":
				return 1.0      # Highest weight - most reliable
			"visual":
				return 0.8      # High weight for close range
			"database":
				return 0.9      # High weight for known signatures
			"signature":
				return 0.7      # Good weight for sensor analysis
			_:
				return 0.5      # Default weight

func _ready() -> void:
	_initialize_target_classification()

func _initialize_target_classification() -> void:
	print("TargetClassification: Initializing target classification system...")
	
	# Create component instances
	classification_database = ClassificationDatabase.new()
	iff_system = IFFSystem.new()
	visual_recognizer = VisualRecognizer.new()
	signature_analyzer = SignatureAnalyzer.new()
	multi_sensor_fusion = MultiSensorFusion.new()
	
	# Load classification database
	load_classification_database()
	
	# Setup classification timer
	if auto_classification_enabled:
		var classification_timer = Timer.new()
		classification_timer.wait_time = 1.0 / classification_update_frequency
		classification_timer.timeout.connect(_on_classification_timer)
		classification_timer.autostart = true
		add_child(classification_timer)
	
	print("TargetClassification: Classification system initialized")

## Load classification database
func load_classification_database() -> void:
	# Load IFF codes
	var iff_codes = {
		"FREN001": {"classification": "fighter", "allegiance": "friendly"},
		"FREN002": {"classification": "bomber", "allegiance": "friendly"},
		"HOST001": {"classification": "fighter", "allegiance": "hostile"},
		"HOST002": {"classification": "cruiser", "allegiance": "hostile"},
		"MERC001": {"classification": "transport", "allegiance": "neutral"}
	}
	iff_system.load_iff_codes(iff_codes)

## Classify target using all available methods
func classify_target(target: Node, sensor_data: Dictionary) -> void:
	if not target or not is_instance_valid(target):
		return
	
	var classifications: Array[Dictionary] = []
	
	# IFF classification
	if use_iff_system:
		var iff_classification = _perform_iff_classification(target)
		if iff_classification.confidence > 0.0:
			classifications.append(iff_classification)
	
	# Visual classification
	if use_visual_recognition:
		var visual_classification = _perform_visual_classification(target, sensor_data)
		if visual_classification.confidence > 0.0:
			classifications.append(visual_classification)
	
	# Signature analysis
	if use_signature_analysis:
		var signature_classification = _perform_signature_classification(sensor_data)
		if signature_classification.confidence > 0.0:
			classifications.append(signature_classification)
	
	# Database lookup
	var database_classification = _perform_database_classification(sensor_data)
	if database_classification.confidence > 0.0:
		classifications.append(database_classification)
	
	# Fuse all classifications
	var final_classification = multi_sensor_fusion.fuse_classifications(classifications)
	
	# Store and update classification
	_update_target_classification(target, final_classification, sensor_data)

func _perform_iff_classification(target: Node) -> Dictionary:
	var iff_response = iff_system.interrogate_target(target)
	
	var classification = {
		"type": iff_response.classification,
		"confidence": iff_response.authenticity,
		"source": "iff"
	}
	
	if iff_response.has_response:
		iff_response_received.emit(target, iff_response)
	
	return classification

func _perform_visual_classification(target: Node, sensor_data: Dictionary) -> Dictionary:
	var distance = sensor_data.get("distance", 10000.0)
	return visual_recognizer.recognize_target(target, distance)

func _perform_signature_classification(sensor_data: Dictionary) -> Dictionary:
	return signature_analyzer.analyze_signatures(sensor_data)

func _perform_database_classification(sensor_data: Dictionary) -> Dictionary:
	return classification_database.classify_by_database(sensor_data)

func _update_target_classification(target: Node, classification: Dictionary, sensor_data: Dictionary) -> void:
	var old_classification = "unknown"
	var classification_data: ClassificationData
	
	# Get or create classification data
	if target_classifications.has(target):
		classification_data = target_classifications[target]
		old_classification = classification_data.primary_classification
	else:
		classification_data = ClassificationData.new(target)
		target_classifications[target] = classification_data
	
	# Check if classification is locked (manual override)
	if classification_data.classification_locked:
		return
	
	# Update classification if confidence is high enough
	var new_classification = classification.get("type", "unknown")
	var new_confidence = classification.get("confidence", 0.0)
	
	if new_confidence >= confidence_threshold:
		classification_data.primary_classification = new_classification
		classification_data.confidence = new_confidence
		classification_data.classification_source = classification.get("source", "unknown")
		classification_data.last_updated = Time.get_ticks_usec() / 1000000.0
		
		# Update additional data
		_update_classification_details(classification_data, sensor_data)
		
		# Record history
		_record_classification_history(target, new_classification, new_confidence, classification_data.classification_source)
		
		# Emit signals
		if old_classification != new_classification:
			if old_classification == "unknown":
				target_classified.emit(target, new_classification)
			else:
				classification_changed.emit(target, old_classification, new_classification)
		
		classification_confidence_updated.emit(target, new_confidence)
	
	# Handle unknown contacts
	if new_classification == "unknown" and target not in unknown_contacts:
		unknown_contacts.append(target)
		unknown_contact_detected.emit(target, sensor_data)

func _update_classification_details(classification_data: ClassificationData, sensor_data: Dictionary) -> void:
	# Update size classification
	if sensor_data.has("radar_cross_section"):
		var rcs = sensor_data.radar_cross_section
		if rcs < 50.0:
			classification_data.size_class = "tiny"
		elif rcs < 200.0:
			classification_data.size_class = "small"
		elif rcs < 2000.0:
			classification_data.size_class = "medium"
		elif rcs < 20000.0:
			classification_data.size_class = "large"
		else:
			classification_data.size_class = "huge"
	
	# Update threat classification
	classification_data.threat_classification = _determine_threat_classification(classification_data.target_node)
	
	# Store sensor readings
	classification_data.sensor_readings = sensor_data.duplicate()

func _determine_threat_classification(target: Node) -> String:
	var player_ship = _get_player_ship()
	if not player_ship:
		return "unknown"
	
	if target.has_method("is_hostile_to_ship"):
		if target.is_hostile_to_ship(player_ship):
			return "hostile"
		elif target.has_method("is_friendly_to_ship") and target.is_friendly_to_ship(player_ship):
			return "friendly"
		else:
			return "neutral"
	
	# Check groups
	if target.is_in_group("hostile"):
		return "hostile"
	elif target.is_in_group("friendly"):
		return "friendly"
	elif target.is_in_group("neutral"):
		return "neutral"
	
	return "unknown"

## Get target classification
func get_target_classification(target: Node) -> String:
	if target_classifications.has(target):
		return target_classifications[target].primary_classification
	return "unknown"

## Get detailed classification data
func get_target_classification_data(target: Node) -> Dictionary:
	if target_classifications.has(target):
		var data = target_classifications[target]
		return {
			"primary_classification": data.primary_classification,
			"sub_classification": data.sub_classification,
			"confidence": data.confidence,
			"source": data.classification_source,
			"size_class": data.size_class,
			"threat_classification": data.threat_classification,
			"first_classified": data.first_classified,
			"last_updated": data.last_updated,
			"classification_locked": data.classification_locked
		}
	
	return {}

## Set manual classification override
func set_manual_classification(target: Node, classification: String, lock: bool = true) -> void:
	var classification_data: ClassificationData
	
	if target_classifications.has(target):
		classification_data = target_classifications[target]
	else:
		classification_data = ClassificationData.new(target)
		target_classifications[target] = classification_data
	
	var old_classification = classification_data.primary_classification
	classification_data.primary_classification = classification
	classification_data.classification_locked = lock
	classification_data.confidence = 1.0
	classification_data.classification_source = "manual"
	classification_data.last_updated = Time.get_ticks_usec() / 1000000.0
	
	# Record history
	_record_classification_history(target, classification, 1.0, "manual")
	
	# Emit signals
	if old_classification != classification:
		classification_changed.emit(target, old_classification, classification)

## Get all classifications
func get_all_classifications() -> Dictionary:
	var all_classifications: Dictionary = {}
	
	for target in target_classifications.keys():
		var data = target_classifications[target]
		all_classifications[target] = {
			"classification": data.primary_classification,
			"confidence": data.confidence,
			"source": data.classification_source,
			"threat_type": data.threat_classification
		}
	
	return all_classifications

## Get unknown contacts
func get_unknown_contacts() -> Array[Node]:
	return unknown_contacts.duplicate()

## Remove target classification
func remove_target_classification(target: Node) -> void:
	target_classifications.erase(target)
	classification_history.erase(target)
	unknown_contacts.erase(target)

## Clear all classifications
func clear_all_classifications() -> void:
	target_classifications.clear()
	classification_history.clear()
	unknown_contacts.clear()

## Classification timer callback
func _on_classification_timer() -> void:
	if not auto_classification_enabled:
		return
	
	# Perform periodic classification updates
	_update_classification_confidence()
	_cleanup_old_classifications()

func _update_classification_confidence() -> void:
	# Update confidence for existing classifications
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	for target in target_classifications.keys():
		var data = target_classifications[target]
		var age = current_time - data.last_updated
		
		# Decay confidence over time if not updated
		if age > 10.0:  # 10 seconds
			var decay_factor = 1.0 - (age - 10.0) / 60.0  # Decay over 1 minute
			data.confidence *= max(0.1, decay_factor)
			
			if data.confidence < confidence_threshold / 2.0:
				data.primary_classification = "unknown"

func _cleanup_old_classifications() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	var max_age = 300.0  # 5 minutes
	var targets_to_remove: Array[Node] = []
	
	for target in target_classifications.keys():
		if not is_instance_valid(target):
			targets_to_remove.append(target)
			continue
		
		var data = target_classifications[target]
		var age = current_time - data.last_updated
		
		if age > max_age and not data.classification_locked:
			targets_to_remove.append(target)
	
	# Remove old classifications
	for target in targets_to_remove:
		remove_target_classification(target)

## History management

func _record_classification_history(target: Node, classification: String, confidence: float, source: String) -> void:
	if not classification_history.has(target):
		classification_history[target] = []
	
	var history = classification_history[target]
	var record = ClassificationRecord.new(classification, confidence, source)
	history.append(record)
	
	# Keep only recent history (last 50 records)
	if history.size() > 50:
		history.pop_front()

## Get classification history for target
func get_target_classification_history(target: Node) -> Array[Dictionary]:
	if not classification_history.has(target):
		return []
	
	var history_array: Array[Dictionary] = []
	for record in classification_history[target]:
		history_array.append({
			"timestamp": record.timestamp,
			"classification": record.classification,
			"confidence": record.confidence,
			"source": record.source,
			"reason": record.reason
		})
	
	return history_array

## Utility functions

func _get_player_ship() -> Node:
	var player_ships = get_tree().get_nodes_in_group("player_ships")
	return player_ships[0] if not player_ships.is_empty() else null

## Configuration management

## Update classification settings
func update_classification_settings(settings: Dictionary) -> void:
	if settings.has("confidence_threshold"):
		confidence_threshold = settings.confidence_threshold
	
	if settings.has("use_iff_system"):
		use_iff_system = settings.use_iff_system
	
	if settings.has("use_visual_recognition"):
		use_visual_recognition = settings.use_visual_recognition
	
	if settings.has("use_signature_analysis"):
		use_signature_analysis = settings.use_signature_analysis

## Status and debugging

## Get classification system status
func get_classification_status() -> Dictionary:
	return {
		"auto_classification_enabled": auto_classification_enabled,
		"classification_frequency": classification_update_frequency,
		"confidence_threshold": confidence_threshold,
		"use_iff": use_iff_system,
		"use_visual": use_visual_recognition,
		"use_signature": use_signature_analysis,
		"classified_targets": target_classifications.size(),
		"unknown_contacts": unknown_contacts.size()
	}

## Get classification statistics
func get_classification_statistics() -> Dictionary:
	var stats = {
		"total_classified": target_classifications.size(),
		"unknown_contacts": unknown_contacts.size(),
		"classification_breakdown": {},
		"confidence_distribution": {},
		"source_breakdown": {}
	}
	
	# Count classifications by type
	var type_counts: Dictionary = {}
	var confidence_ranges: Dictionary = {"low": 0, "medium": 0, "high": 0}
	var source_counts: Dictionary = {}
	
	for data in target_classifications.values():
		# Count by type
		var type = data.primary_classification
		type_counts[type] = type_counts.get(type, 0) + 1
		
		# Count by confidence
		if data.confidence < 0.4:
			confidence_ranges.low += 1
		elif data.confidence < 0.7:
			confidence_ranges.medium += 1
		else:
			confidence_ranges.high += 1
		
		# Count by source
		var source = data.classification_source
		source_counts[source] = source_counts.get(source, 0) + 1
	
	stats.classification_breakdown = type_counts
	stats.confidence_distribution = confidence_ranges
	stats.source_breakdown = source_counts
	
	return stats
