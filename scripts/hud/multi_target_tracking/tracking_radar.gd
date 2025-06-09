class_name TrackingRadar
extends Node

## HUD-008 Component 3: Tracking Radar System
## Advanced radar system for contact detection, tracking, and signal processing
## Provides multi-mode radar scanning with jamming resistance and target classification

signal contact_detected(contact_data: Dictionary)
signal contact_lost(contact_data: Dictionary)
signal contact_updated(contact_data: Dictionary)
signal radar_mode_changed(old_mode: RadarMode, new_mode: RadarMode)
signal jamming_detected(jamming_source: Node, strength: float)
signal radar_sweep_completed(contacts_found: int, sweep_time_ms: float)

# Radar operation parameters
@export var tracking_range: float = 50000.0
@export var update_frequency: float = 30.0  # 30Hz radar update
@export var sweep_angle: float = 360.0      # Full 360-degree sweep
@export var radar_resolution: float = 50.0   # Minimum separation distance
@export var detection_threshold: float = 0.3 # Minimum signal strength for detection

# Radar modes and capabilities
var radar_mode: RadarMode = RadarMode.SEARCH
var radar_config: Dictionary = {}
var is_radar_active: bool = true
var is_passive_mode: bool = false

# Contact tracking
var tracked_contacts: Dictionary = {}  # contact_id -> ContactData
var contact_counter: int = 0
var last_sweep_time: float = 0.0
var sweep_interval: float = 0.033  # ~30Hz

# Signal processing
var signal_processor: RadarSignalProcessor
var jamming_detector: JammingDetector
var target_classifier: RadarTargetClassifier

# Performance optimization
var sweep_sectors: Array[SweepSector] = []
var current_sector: int = 0
var contacts_per_frame_limit: int = 16
var radar_performance_budget_ms: float = 2.0

# Radar signature database
var signature_database: Dictionary = {}

enum RadarMode {
	SEARCH,          # Wide-area search mode
	TRACK,           # Track-while-scan mode
	LOCK,            # Single target lock mode
	PASSIVE,         # Passive detection only
	STEALTH,         # Low emission mode
	COMBAT,          # Combat-optimized mode
	INTERCEPT,       # High-resolution intercept mode
	DEFENSIVE        # Missile warning emphasis
}

# Contact data structure
class ContactData:
	var contact_id: int
	var target_node: Node
	var position: Vector3
	var velocity: Vector3
	var acceleration: Vector3
	var bearing: float
	var elevation: float
	var distance: float
	var signal_strength: float
	var radar_cross_section: float
	var first_detected: float
	var last_detected: float
	var track_quality: float
	var classification: String
	var confidence: float
	var jamming_strength: float
	var is_friendly: bool
	var is_hostile: bool
	var velocity_history: Array[Vector3] = []
	var position_history: Array[Vector3] = []
	
	func _init(id: int, target: Node):
		contact_id = id
		target_node = target
		first_detected = Time.get_ticks_usec() / 1000000.0
		last_detected = first_detected
		track_quality = 1.0
		classification = "unknown"
		confidence = 0.5

# Sector-based scanning for performance
class SweepSector:
	var start_angle: float
	var end_angle: float
	var priority: int
	var last_sweep: float
	var contacts_in_sector: Array[int] = []
	
	func _init(start: float, end: float, prio: int = 50):
		start_angle = start
		end_angle = end
		priority = prio
		last_sweep = 0.0

# Signal processing component
class RadarSignalProcessor:
	var detection_algorithms: Dictionary = {}
	var noise_filter: NoiseFilter
	var doppler_processor: DopplerProcessor
	var clutter_filter: ClutterFilter
	
	func _init():
		noise_filter = NoiseFilter.new()
		doppler_processor = DopplerProcessor.new()
		clutter_filter = ClutterFilter.new()
	
	func process_return(raw_signal: Dictionary) -> Dictionary:
		# Apply noise filtering
		var filtered_signal = noise_filter.filter_signal(raw_signal)
		
		# Process Doppler shift
		var doppler_data = doppler_processor.calculate_doppler(filtered_signal)
		
		# Remove clutter
		var clean_signal = clutter_filter.remove_clutter(doppler_data)
		
		return clean_signal
	
	class NoiseFilter:
		func filter_signal(input_signal: Dictionary) -> Dictionary:
			# Implement noise filtering
			var filtered = input_signal.duplicate()
			var noise_level = input_signal.get("noise_level", 0.1)
			filtered["signal_strength"] = max(0.0, filtered.get("signal_strength", 0.0) - noise_level)
			return filtered
	
	class DopplerProcessor:
		func calculate_doppler(input_signal: Dictionary) -> Dictionary:
			# Calculate Doppler shift for velocity determination
			var processed = input_signal.duplicate()
			# Doppler calculation would go here
			return processed
	
	class ClutterFilter:
		func remove_clutter(input_signal: Dictionary) -> Dictionary:
			# Remove ground/space clutter
			var filtered = input_signal.duplicate()
			# Clutter filtering would go here
			return filtered

# Jamming detection component
class JammingDetector:
	var jamming_threshold: float = 0.8
	var known_jammers: Array[Node] = []
	
	func detect_jamming(input_signal: Dictionary) -> Dictionary:
		var jamming_data = {
			"is_jammed": false,
			"jamming_strength": 0.0,
			"jamming_source": null,
			"jamming_type": "none"
		}
		
		var noise_to_signal_ratio = input_signal.get("noise_level", 0.0) / max(0.01, input_signal.get("signal_strength", 0.01))
		
		if noise_to_signal_ratio > jamming_threshold:
			jamming_data.is_jammed = true
			jamming_data.jamming_strength = noise_to_signal_ratio
			jamming_data.jamming_type = _identify_jamming_type(input_signal)
		
		return jamming_data
	
	func _identify_jamming_type(input_signal: Dictionary) -> String:
		# Analyze jamming patterns
		return "noise"  # Default type

# Target classification component
class RadarTargetClassifier:
	var classification_rules: Dictionary = {}
	
	func _init():
		_load_classification_rules()
	
	func classify_contact(contact: ContactData) -> Dictionary:
		var classification = {
			"type": "unknown",
			"subtype": "",
			"confidence": 0.0,
			"size_class": "medium"
		}
		
		# Classify based on radar cross section
		if contact.radar_cross_section > 10000.0:
			classification.type = "capital"
			classification.size_class = "large"
		elif contact.radar_cross_section > 1000.0:
			classification.type = "cruiser"
			classification.size_class = "medium"
		elif contact.radar_cross_section > 100.0:
			classification.type = "fighter"
			classification.size_class = "small"
		elif contact.radar_cross_section > 10.0:
			classification.type = "missile"
			classification.size_class = "tiny"
		
		# Classify based on velocity
		var speed = contact.velocity.length()
		if speed > 800.0 and classification.type == "unknown":
			classification.type = "missile"
		elif speed > 400.0 and classification.type == "fighter":
			classification.subtype = "interceptor"
		elif speed < 100.0 and classification.type == "capital":
			classification.subtype = "heavy"
		
		# Calculate confidence
		classification.confidence = _calculate_classification_confidence(contact, classification)
		
		return classification
	
	func _load_classification_rules() -> void:
		# Load classification rules from database
		classification_rules = {
			"size_thresholds": {
				"capital": 10000.0,
				"cruiser": 1000.0,
				"fighter": 100.0,
				"missile": 10.0
			},
			"speed_thresholds": {
				"missile": 800.0,
				"interceptor": 400.0,
				"bomber": 200.0,
				"capital": 100.0
			}
		}
	
	func _calculate_classification_confidence(contact: ContactData, classification: Dictionary) -> float:
		var confidence = 0.5  # Base confidence
		
		# Increase confidence with track quality
		confidence += contact.track_quality * 0.3
		
		# Increase confidence with signal strength
		confidence += contact.signal_strength * 0.2
		
		# Increase confidence with time tracked
		var track_time = contact.last_detected - contact.first_detected
		confidence += min(0.3, track_time / 10.0)  # Max 0.3 bonus for 10+ seconds
		
		return clamp(confidence, 0.0, 1.0)

func _ready() -> void:
	_initialize_tracking_radar()

func _initialize_tracking_radar() -> void:
	print("TrackingRadar: Initializing radar tracking system...")
	
	# Initialize signal processing components
	signal_processor = RadarSignalProcessor.new()
	jamming_detector = JammingDetector.new()
	target_classifier = RadarTargetClassifier.new()
	
	# Setup radar configuration
	_configure_radar_system()
	
	# Initialize sweep sectors
	_initialize_sweep_sectors()
	
	# Load radar signature database
	_load_signature_database()
	
	# Calculate sweep interval
	sweep_interval = 1.0 / update_frequency
	
	print("TrackingRadar: Radar system initialized with %d sweep sectors" % sweep_sectors.size())

func _configure_radar_system() -> void:
	radar_config = {
		"max_range": tracking_range,
		"min_range": 100.0,
		"azimuth_resolution": 1.0,    # Degrees
		"elevation_resolution": 2.0,  # Degrees
		"range_resolution": radar_resolution,
		"doppler_resolution": 5.0,    # m/s
		"power_output": 1.0,          # Normalized power
		"antenna_gain": 35.0,         # dB
		"receiver_sensitivity": -110.0, # dBm
		"pulse_repetition_frequency": 1000.0,  # Hz
		"pulse_width": 0.001,         # seconds
		"beam_width": 2.0             # degrees
	}

func _initialize_sweep_sectors() -> void:
	# Create 8 sectors for 360-degree coverage
	var sector_count = 8
	var sector_angle = 360.0 / sector_count
	
	for i in range(sector_count):
		var start_angle = i * sector_angle
		var end_angle = (i + 1) * sector_angle
		var priority = 50  # Default priority
		
		# Higher priority for forward sectors
		if i == 0 or i == 1 or i == 7:  # Forward-facing sectors
			priority = 70
		
		var sector = SweepSector.new(start_angle, end_angle, priority)
		sweep_sectors.append(sector)

func _load_signature_database() -> void:
	signature_database = {
		"fighter": {
			"rcs_range": [50.0, 200.0],
			"speed_range": [100.0, 600.0],
			"acceleration_range": [50.0, 200.0]
		},
		"bomber": {
			"rcs_range": [200.0, 800.0],
			"speed_range": [80.0, 300.0],
			"acceleration_range": [20.0, 100.0]
		},
		"capital": {
			"rcs_range": [5000.0, 50000.0],
			"speed_range": [10.0, 150.0],
			"acceleration_range": [5.0, 50.0]
		},
		"missile": {
			"rcs_range": [5.0, 50.0],
			"speed_range": [200.0, 1200.0],
			"acceleration_range": [100.0, 1000.0]
		}
	}

## Set tracking range
func set_tracking_range(range: float) -> void:
	tracking_range = range
	radar_config.max_range = range

## Set update frequency
func set_update_frequency(frequency: float) -> void:
	update_frequency = frequency
	sweep_interval = 1.0 / frequency

## Perform radar sweep
func perform_radar_sweep() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	# Check if it's time for a sweep
	if current_time - last_sweep_time < sweep_interval:
		return
	
	var start_time = Time.get_ticks_usec()
	var contacts_found = 0
	
	# Perform sectored sweep
	if radar_mode == RadarMode.SEARCH:
		contacts_found = _perform_search_sweep()
	elif radar_mode == RadarMode.TRACK:
		contacts_found = _perform_track_while_scan()
	elif radar_mode == RadarMode.LOCK:
		contacts_found = _perform_lock_mode_sweep()
	elif radar_mode == RadarMode.PASSIVE:
		contacts_found = _perform_passive_detection()
	else:
		contacts_found = _perform_standard_sweep()
	
	# Update sector tracking
	_update_current_sector()
	
	# Clean up old contacts
	_cleanup_old_contacts()
	
	# Performance measurement
	var sweep_time = (Time.get_ticks_usec() - start_time) / 1000.0
	last_sweep_time = current_time
	
	# Emit completion signal
	radar_sweep_completed.emit(contacts_found, sweep_time)

func _perform_search_sweep() -> int:
	# Wide-area search mode - scan all sectors
	var contacts_found = 0
	
	for sector in sweep_sectors:
		contacts_found += _scan_sector(sector)
		
		# Respect frame budget
		if contacts_found >= contacts_per_frame_limit:
			break
	
	return contacts_found

func _perform_track_while_scan() -> int:
	# Track existing contacts while searching for new ones
	var contacts_found = 0
	
	# Update existing contacts first
	contacts_found += _update_existing_contacts()
	
	# Scan one new sector per frame
	if current_sector < sweep_sectors.size():
		contacts_found += _scan_sector(sweep_sectors[current_sector])
	
	return contacts_found

func _perform_lock_mode_sweep() -> int:
	# Focus on specific target area
	# In a real implementation, this would track a specific target
	return _update_existing_contacts()

func _perform_passive_detection() -> int:
	# Passive detection - listen for emissions
	var contacts_found = 0
	
	# Scan for active emitters (simplified)
	var potential_targets = _find_potential_targets()
	
	for target in potential_targets:
		if _is_target_emitting(target):
			var contact_data = _process_passive_detection(target)
			if contact_data:
				_add_or_update_contact(contact_data)
				contacts_found += 1
	
	return contacts_found

func _perform_standard_sweep() -> int:
	# Standard radar sweep
	return _scan_sector(sweep_sectors[current_sector])

func _scan_sector(sector: SweepSector) -> int:
	var contacts_found = 0
	var potential_targets = _find_targets_in_sector(sector)
	
	for target in potential_targets:
		var contact_data = _process_radar_return(target, sector)
		
		if contact_data and contact_data.signal_strength >= detection_threshold:
			_add_or_update_contact(contact_data)
			contacts_found += 1
	
	sector.last_sweep = Time.get_ticks_usec() / 1000000.0
	return contacts_found

func _find_targets_in_sector(sector: SweepSector) -> Array[Node]:
	var targets: Array[Node] = []
	var player_position = _get_player_position()
	
	# Find all potential targets in game world
	var all_objects = _get_all_trackable_objects()
	
	for obj in all_objects:
		if not obj or not is_instance_valid(obj):
			continue
		
		var obj_position = _get_object_position(obj)
		var distance = player_position.distance_to(obj_position)
		
		# Check range
		if distance > tracking_range:
			continue
		
		# Check if in sector
		var bearing = _calculate_bearing(player_position, obj_position)
		if _is_bearing_in_sector(bearing, sector):
			targets.append(obj)
	
	return targets

func _process_radar_return(target: Node, sector: SweepSector) -> ContactData:
	var player_position = _get_player_position()
	var target_position = _get_object_position(target)
	var distance = player_position.distance_to(target_position)
	
	# Calculate raw signal data
	var raw_signal = _calculate_raw_radar_return(target, distance)
	
	# Process signal through radar processor
	var processed_signal = signal_processor.process_return(raw_signal)
	
	# Check for jamming
	var jamming_data = jamming_detector.detect_jamming(processed_signal)
	
	# Create contact data if signal is strong enough
	if processed_signal.signal_strength >= detection_threshold:
		contact_counter += 1
		var contact = ContactData.new(contact_counter, target)
		
		# Fill contact data
		contact.position = target_position
		contact.velocity = _get_object_velocity(target)
		contact.distance = distance
		contact.bearing = _calculate_bearing(player_position, target_position)
		contact.elevation = _calculate_elevation(player_position, target_position)
		contact.signal_strength = processed_signal.signal_strength
		contact.radar_cross_section = raw_signal.radar_cross_section
		contact.jamming_strength = jamming_data.jamming_strength
		contact.track_quality = _calculate_track_quality(processed_signal, jamming_data)
		
		# Classify contact
		var classification = target_classifier.classify_contact(contact)
		contact.classification = classification.type
		contact.confidence = classification.confidence
		
		# Determine relationship
		contact.is_friendly = _is_target_friendly(target)
		contact.is_hostile = _is_target_hostile(target)
		
		return contact
	
	return null

func _calculate_raw_radar_return(target: Node, distance: float) -> Dictionary:
	# Calculate radar cross section
	var rcs = _get_target_radar_cross_section(target)
	
	# Calculate signal strength using radar equation
	var power_density = radar_config.power_output * radar_config.antenna_gain / (4.0 * PI * distance * distance)
	var reflected_power = power_density * rcs / (4.0 * PI * distance * distance)
	var received_power = reflected_power * radar_config.antenna_gain
	
	# Normalize signal strength
	var signal_strength = clamp(received_power * 1000.0, 0.0, 1.0)
	
	# Add atmospheric and environmental effects
	signal_strength *= _calculate_atmospheric_attenuation(distance)
	signal_strength *= _calculate_environmental_effects(target)
	
	# Add noise
	var noise_level = 0.05 + randf() * 0.05  # Base noise + random
	
	return {
		"signal_strength": signal_strength,
		"noise_level": noise_level,
		"radar_cross_section": rcs,
		"distance": distance,
		"doppler_shift": _calculate_doppler_shift(target)
	}

func _calculate_track_quality(input_signal: Dictionary, jamming: Dictionary) -> float:
	var quality = input_signal.signal_strength
	
	# Reduce quality for jamming
	if jamming.is_jammed:
		quality *= (1.0 - jamming.jamming_strength * 0.5)
	
	# Reduce quality for weak signals
	if input_signal.signal_strength < 0.5:
		quality *= input_signal.signal_strength * 2.0
	
	return clamp(quality, 0.0, 1.0)

func _add_or_update_contact(contact_data: ContactData) -> void:
	var existing_contact = _find_existing_contact(contact_data.target_node)
	
	if existing_contact:
		# Update existing contact
		_update_contact_data(existing_contact, contact_data)
		contact_updated.emit(_contact_to_dictionary(existing_contact))
	else:
		# Add new contact
		tracked_contacts[contact_data.contact_id] = contact_data
		contact_detected.emit(_contact_to_dictionary(contact_data))

func _find_existing_contact(target_node: Node) -> ContactData:
	for contact in tracked_contacts.values():
		if contact.target_node == target_node:
			return contact
	return null

func _update_contact_data(existing: ContactData, new_data: ContactData) -> void:
	# Update position with history
	existing.position_history.append(existing.position)
	if existing.position_history.size() > 10:
		existing.position_history.pop_front()
	
	# Update velocity with history
	existing.velocity_history.append(existing.velocity)
	if existing.velocity_history.size() > 10:
		existing.velocity_history.pop_front()
	
	# Update data
	existing.position = new_data.position
	existing.velocity = new_data.velocity
	existing.distance = new_data.distance
	existing.bearing = new_data.bearing
	existing.elevation = new_data.elevation
	existing.signal_strength = new_data.signal_strength
	existing.track_quality = new_data.track_quality
	existing.last_detected = Time.get_ticks_usec() / 1000000.0
	
	# Calculate acceleration from velocity history
	if existing.velocity_history.size() >= 2:
		var old_velocity = existing.velocity_history[-2]
		var time_delta = 0.1  # Approximate time between updates
		existing.acceleration = (existing.velocity - old_velocity) / time_delta

func _update_existing_contacts() -> int:
	var contacts_updated = 0
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	for contact in tracked_contacts.values():
		# Update contact position prediction
		var time_delta = current_time - contact.last_detected
		if time_delta < 1.0:  # Only update recent contacts
			_update_contact_prediction(contact, time_delta)
			contacts_updated += 1
	
	return contacts_updated

func _update_contact_prediction(contact: ContactData, time_delta: float) -> void:
	# Update predicted position based on velocity and acceleration
	contact.position += contact.velocity * time_delta
	contact.position += 0.5 * contact.acceleration * time_delta * time_delta
	
	# Update distance and bearing
	var player_position = _get_player_position()
	contact.distance = player_position.distance_to(contact.position)
	contact.bearing = _calculate_bearing(player_position, contact.position)
	contact.elevation = _calculate_elevation(player_position, contact.position)

func _cleanup_old_contacts() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	var max_age = 5.0  # 5 seconds without update
	var contacts_to_remove: Array[int] = []
	
	for contact_id in tracked_contacts.keys():
		var contact = tracked_contacts[contact_id]
		var age = current_time - contact.last_detected
		
		if age > max_age:
			contacts_to_remove.append(contact_id)
	
	# Remove old contacts
	for contact_id in contacts_to_remove:
		var contact = tracked_contacts[contact_id]
		tracked_contacts.erase(contact_id)
		contact_lost.emit(_contact_to_dictionary(contact))

func _update_current_sector() -> void:
	current_sector = (current_sector + 1) % sweep_sectors.size()

## Utility functions

func _get_all_trackable_objects() -> Array[Node]:
	var objects: Array[Node] = []
	
	# Get objects from various groups
	objects.append_array(get_tree().get_nodes_in_group("ships"))
	objects.append_array(get_tree().get_nodes_in_group("missiles"))
	objects.append_array(get_tree().get_nodes_in_group("debris"))
	objects.append_array(get_tree().get_nodes_in_group("asteroids"))
	
	return objects

func _get_object_position(obj: Node) -> Vector3:
	if obj.has_method("get_global_position"):
		return obj.get_global_position()
	elif obj.has_property("global_position"):
		return obj.global_position
	else:
		return Vector3.ZERO

func _get_object_velocity(obj: Node) -> Vector3:
	if obj.has_method("get_velocity"):
		return obj.get_velocity()
	elif obj.has_property("velocity"):
		return obj.velocity
	else:
		return Vector3.ZERO

func _get_target_radar_cross_section(target: Node) -> float:
	if target.has_method("get_radar_cross_section"):
		return target.get_radar_cross_section()
	elif target.has_property("radar_cross_section"):
		return target.radar_cross_section
	else:
		# Estimate based on object type
		if target.is_in_group("missiles"):
			return 10.0
		elif target.is_in_group("fighters"):
			return 100.0
		elif target.is_in_group("capital"):
			return 10000.0
		else:
			return 50.0  # Default

func _calculate_bearing(from: Vector3, to: Vector3) -> float:
	var direction = to - from
	return atan2(direction.x, direction.z)

func _calculate_elevation(from: Vector3, to: Vector3) -> float:
	var direction = to - from
	var horizontal_distance = Vector2(direction.x, direction.z).length()
	return atan2(direction.y, horizontal_distance)

func _calculate_doppler_shift(target: Node) -> float:
	var target_velocity = _get_object_velocity(target)
	var player_position = _get_player_position()
	var target_position = _get_object_position(target)
	
	# Calculate radial velocity
	var range_vector = (target_position - player_position).normalized()
	var radial_velocity = target_velocity.dot(range_vector)
	
	# Calculate Doppler shift (simplified)
	var frequency_shift = radial_velocity / 299792458.0  # Speed of light
	return frequency_shift

func _calculate_atmospheric_attenuation(distance: float) -> float:
	# Simplified atmospheric attenuation
	var attenuation_factor = exp(-distance / 100000.0)  # 100km atmospheric scale
	return clamp(attenuation_factor, 0.1, 1.0)

func _calculate_environmental_effects(target: Node) -> float:
	var effect = 1.0
	
	# Check for stealth
	if target.has_method("is_stealthed") and target.is_stealthed():
		effect *= 0.1  # 90% reduction for stealth
	
	# Check for ECM
	if target.has_method("get_ecm_strength"):
		var ecm = target.get_ecm_strength()
		effect *= (1.0 - ecm * 0.5)  # Up to 50% reduction
	
	return clamp(effect, 0.01, 1.0)

func _is_bearing_in_sector(bearing: float, sector: SweepSector) -> bool:
	# Normalize bearing to 0-360
	while bearing < 0.0:
		bearing += 2.0 * PI
	while bearing >= 2.0 * PI:
		bearing -= 2.0 * PI
	
	var bearing_degrees = rad_to_deg(bearing)
	
	# Handle sector wrap-around
	if sector.end_angle > 360.0:
		return bearing_degrees >= sector.start_angle or bearing_degrees <= (sector.end_angle - 360.0)
	else:
		return bearing_degrees >= sector.start_angle and bearing_degrees <= sector.end_angle

func _is_target_friendly(target: Node) -> bool:
	var player_ship = _get_player_ship()
	if not player_ship:
		return false
	
	if target.has_method("is_friendly_to_ship"):
		return target.is_friendly_to_ship(player_ship)
	
	return target.is_in_group("friendly")

func _is_target_hostile(target: Node) -> bool:
	var player_ship = _get_player_ship()
	if not player_ship:
		return false
	
	if target.has_method("is_hostile_to_ship"):
		return target.is_hostile_to_ship(player_ship)
	
	return target.is_in_group("hostile")

func _is_target_emitting(target: Node) -> bool:
	# Check if target is actively emitting radio signals
	if target.has_method("is_actively_emitting"):
		return target.is_actively_emitting()
	
	# Default assumption for active targets
	return true

func _process_passive_detection(target: Node) -> ContactData:
	# Simplified passive detection
	var player_position = _get_player_position()
	var target_position = _get_object_position(target)
	var distance = player_position.distance_to(target_position)
	
	if distance <= tracking_range:
		contact_counter += 1
		var contact = ContactData.new(contact_counter, target)
		
		contact.position = target_position
		contact.velocity = _get_object_velocity(target)
		contact.distance = distance
		contact.bearing = _calculate_bearing(player_position, target_position)
		contact.signal_strength = 0.3  # Lower strength for passive
		contact.track_quality = 0.6    # Lower quality for passive
		
		return contact
	
	return null

func _find_potential_targets() -> Array[Node]:
	# Find targets that might be emitting
	return _get_all_trackable_objects()

func _contact_to_dictionary(contact: ContactData) -> Dictionary:
	return {
		"contact_id": contact.contact_id,
		"target_node": contact.target_node,
		"position": contact.position,
		"velocity": contact.velocity,
		"acceleration": contact.acceleration,
		"distance": contact.distance,
		"bearing": contact.bearing,
		"elevation": contact.elevation,
		"signal_strength": contact.signal_strength,
		"track_quality": contact.track_quality,
		"classification": contact.classification,
		"confidence": contact.confidence,
		"is_friendly": contact.is_friendly,
		"is_hostile": contact.is_hostile,
		"jamming_strength": contact.jamming_strength,
		"first_detected": contact.first_detected,
		"last_detected": contact.last_detected
	}

func _get_player_position() -> Vector3:
	var player_ship = _get_player_ship()
	return player_ship.global_position if player_ship else Vector3.ZERO

func _get_player_ship() -> Node:
	var player_ships = get_tree().get_nodes_in_group("player_ships")
	return player_ships[0] if not player_ships.is_empty() else null

## Mode management

## Set radar mode
func set_radar_mode(mode: RadarMode) -> void:
	var old_mode = radar_mode
	radar_mode = mode
	
	# Adjust parameters based on mode
	match mode:
		RadarMode.SEARCH:
			update_frequency = 30.0
			detection_threshold = 0.3
		RadarMode.TRACK:
			update_frequency = 60.0
			detection_threshold = 0.2
		RadarMode.LOCK:
			update_frequency = 120.0
			detection_threshold = 0.1
		RadarMode.PASSIVE:
			is_passive_mode = true
			detection_threshold = 0.5
		RadarMode.STEALTH:
			update_frequency = 10.0
			detection_threshold = 0.4
		RadarMode.COMBAT:
			update_frequency = 60.0
			detection_threshold = 0.2
	
	radar_mode_changed.emit(old_mode, mode)

## Get current contacts
func get_tracked_contacts() -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	for contact in tracked_contacts.values():
		contacts.append(_contact_to_dictionary(contact))
	return contacts

## Get contact by ID
func get_contact(contact_id: int) -> Dictionary:
	if tracked_contacts.has(contact_id):
		return _contact_to_dictionary(tracked_contacts[contact_id])
	return {}

## Status and debugging

## Get radar status
func get_radar_status() -> Dictionary:
	return {
		"is_active": is_radar_active,
		"radar_mode": RadarMode.keys()[radar_mode],
		"is_passive": is_passive_mode,
		"tracking_range": tracking_range,
		"update_frequency": update_frequency,
		"active_contacts": tracked_contacts.size(),
		"current_sector": current_sector,
		"total_sectors": sweep_sectors.size(),
		"detection_threshold": detection_threshold
	}

## Get performance statistics
func get_performance_stats() -> Dictionary:
	return {
		"contacts_tracked": tracked_contacts.size(),
		"contacts_per_frame_limit": contacts_per_frame_limit,
		"radar_budget_ms": radar_performance_budget_ms,
		"sweep_interval": sweep_interval,
		"last_sweep_time": last_sweep_time
	}
