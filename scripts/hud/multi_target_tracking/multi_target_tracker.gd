class_name MultiTargetTracker
extends HUDElementBase

## HUD-008 Component 1: Multi-Target Tracking and Management System
## Central controller for tracking multiple targets simultaneously with prioritization and tactical awareness
## Supports tracking of 32+ targets with performance optimization and spatial partitioning

signal target_acquired(target: Node, track_id: int)
signal target_lost(track_id: int, reason: String)
signal target_priority_changed(track_id: int, old_priority: int, new_priority: int)
signal tracking_limit_reached(max_targets: int)
signal track_handoff_completed(track_id: int, from_system: String, to_system: String)
signal tracking_data_updated(active_tracks: Array[Dictionary])

# Core tracking parameters
@export var max_tracked_targets: int = 32
@export var tracking_range_limit: float = 50000.0  # Maximum tracking range
@export var tracking_update_frequency: float = 30.0  # 30Hz for balance of accuracy and performance
@export var spatial_partitioning_enabled: bool = true
@export var auto_priority_management: bool = true

# Component references
var target_priority_manager: TargetPriorityManager
var tracking_radar: TrackingRadar
var threat_assessment: ThreatAssessment
var target_classification: TargetClassification
var tracking_database: TrackingDatabase
var situational_awareness: SituationalAwareness
var target_handoff: TargetHandoff

# Active tracking data
var active_tracks: Dictionary = {}  # track_id -> TrackData
var track_counter: int = 0
var priority_sorted_tracks: Array[int] = []  # track_ids sorted by priority
var spatial_partition: SpatialPartition

# Performance and optimization
var frame_budget_ms: float = 1.0  # Maximum time per frame
var tracks_per_frame_limit: int = 8  # Maximum tracks to update per frame
var last_tracking_update_time: float = 0.0
var track_update_queue: Array[int] = []

# System state
var is_tracking_active: bool = false
var tracking_mode: TrackingMode = TrackingMode.STANDARD
var tracking_filter: TrackingFilter = TrackingFilter.ALL

# Configuration
var tracking_config: Dictionary = {
	"min_track_duration": 0.5,      # Minimum time to maintain track
	"max_track_age": 30.0,          # Maximum time without update before removal
	"position_update_threshold": 5.0,  # Minimum movement to update position
	"velocity_smoothing": 0.8,      # Velocity smoothing factor
	"prediction_time": 2.0,         # Seconds to predict ahead
	"range_fade_distance": 5000.0,  # Distance to start fading tracks
	"quality_threshold": 0.3        # Minimum quality to maintain track
}

enum TrackingMode {
	STANDARD,    # Normal tracking with all features
	COMBAT,      # Combat-focused with threat prioritization
	STEALTH,     # Reduced signature tracking
	SEARCH,      # Wide-area search mode
	INTERCEPT,   # Intercept-focused tracking
	DEFENSIVE    # Defensive posture with missile warning priority
}

enum TrackingFilter {
	ALL,         # Track all valid targets
	HOSTILE,     # Only hostile targets
	FRIENDLY,    # Only friendly targets
	NEUTRAL,     # Only neutral targets
	CAPITAL,     # Only capital ships
	FIGHTER,     # Only fighters
	MISSILE,     # Only missiles and ordnance
	UNKNOWN      # Only unidentified contacts
}

# Track data structure
class TrackData:
	var track_id: int
	var target_node: Node
	var target_type: String
	var classification: String
	var priority: int
	var threat_level: float
	var quality: float
	var position: Vector3
	var velocity: Vector3
	var acceleration: Vector3
	var heading: float
	var distance: float
	var bearing: float
	var elevation: float
	var first_detected: float
	var last_updated: float
	var prediction_position: Vector3
	var prediction_confidence: float
	var tracking_system: String = "radar"  # radar, visual, missile_lock, etc.
	var is_locked: bool = false
	var lock_strength: float = 0.0
	var jamming_strength: float = 0.0
	var stealth_factor: float = 1.0
	var relationship: String = "unknown"  # friendly, hostile, neutral, unknown
	var custom_data: Dictionary = {}
	
	func _init(id: int, target: Node):
		track_id = id
		target_node = target
		first_detected = Time.get_ticks_usec() / 1000000.0
		last_updated = first_detected
		quality = 1.0

# Spatial partitioning for performance optimization
class SpatialPartition:
	var cell_size: float = 10000.0  # 10km cells
	var cells: Dictionary = {}  # Vector3i -> Array[track_id]
	var track_cells: Dictionary = {}  # track_id -> Vector3i
	
	func add_track(track_id: int, position: Vector3) -> void:
		var cell = _get_cell(position)
		
		if not cells.has(cell):
			cells[cell] = []
		
		cells[cell].append(track_id)
		track_cells[track_id] = cell
	
	func remove_track(track_id: int) -> void:
		if track_cells.has(track_id):
			var cell = track_cells[track_id]
			if cells.has(cell):
				cells[cell].erase(track_id)
				if cells[cell].is_empty():
					cells.erase(cell)
			track_cells.erase(track_id)
	
	func update_track_position(track_id: int, new_position: Vector3) -> void:
		var new_cell = _get_cell(new_position)
		
		if track_cells.has(track_id):
			var old_cell = track_cells[track_id]
			if old_cell != new_cell:
				# Move to new cell
				if cells.has(old_cell):
					cells[old_cell].erase(track_id)
				
				if not cells.has(new_cell):
					cells[new_cell] = []
				
				cells[new_cell].append(track_id)
				track_cells[track_id] = new_cell
	
	func get_nearby_tracks(position: Vector3, radius: float) -> Array[int]:
		var nearby_tracks: Array[int] = []
		var center_cell = _get_cell(position)
		var cell_radius = int(radius / cell_size) + 1
		
		for x in range(-cell_radius, cell_radius + 1):
			for y in range(-cell_radius, cell_radius + 1):
				for z in range(-cell_radius, cell_radius + 1):
					var check_cell = center_cell + Vector3i(x, y, z)
					if cells.has(check_cell):
						nearby_tracks.append_array(cells[check_cell])
		
		return nearby_tracks
	
	func _get_cell(position: Vector3) -> Vector3i:
		return Vector3i(
			int(position.x / cell_size),
			int(position.y / cell_size),
			int(position.z / cell_size)
		)

func _ready() -> void:
	super._ready()
	_initialize_multi_target_tracker()

func _initialize_multi_target_tracker() -> void:
	print("MultiTargetTracker: Initializing multi-target tracking system...")
	
	# Initialize spatial partitioning
	if spatial_partitioning_enabled:
		spatial_partition = SpatialPartition.new()
	
	# Create component instances
	target_priority_manager = TargetPriorityManager.new()
	tracking_radar = TrackingRadar.new()
	threat_assessment = ThreatAssessment.new()
	target_classification = TargetClassification.new()
	tracking_database = TrackingDatabase.new()
	situational_awareness = SituationalAwareness.new()
	target_handoff = TargetHandoff.new()
	
	# Add components as children
	add_child(target_priority_manager)
	add_child(tracking_radar)
	add_child(threat_assessment)
	add_child(target_classification)
	add_child(tracking_database)
	add_child(situational_awareness)
	add_child(target_handoff)
	
	# Initialize components
	_initialize_components()
	
	# Connect component signals
	_connect_component_signals()
	
	# Configure HUD element
	element_id = "multi_target_tracker"
	container_type = "targeting"
	data_sources = ["targeting_data", "radar_contacts", "threat_data"]
	update_frequency = update_frequency
	
	# Start tracking system
	is_tracking_active = true
	print("MultiTargetTracker: Multi-target tracking system initialized with %d max targets" % max_tracked_targets)

func _initialize_components() -> void:
	# Initialize target priority manager
	if target_priority_manager:
		target_priority_manager.set_max_targets(max_tracked_targets)
		target_priority_manager.enable_auto_management(auto_priority_management)
	
	# Initialize tracking radar
	if tracking_radar:
		tracking_radar.set_tracking_range(tracking_range_limit)
		tracking_radar.set_update_frequency(update_frequency)
	
	# Initialize threat assessment
	if threat_assessment:
		threat_assessment.enable_real_time_assessment(true)
	
	# Initialize target classification
	if target_classification:
		target_classification.load_classification_database()
	
	# Initialize tracking database
	if tracking_database:
		tracking_database.set_retention_policy(tracking_config.max_track_age)
	
	# Initialize situational awareness
	if situational_awareness:
		situational_awareness.set_prediction_time(tracking_config.prediction_time)
	
	# Initialize target handoff
	if target_handoff:
		target_handoff.register_handoff_systems(["radar", "visual", "missile_lock", "beam_lock"])

func _connect_component_signals() -> void:
	# Target Priority Manager signals
	if target_priority_manager:
		target_priority_manager.priority_changed.connect(_on_target_priority_changed)
		target_priority_manager.priority_recalculated.connect(_on_priorities_recalculated)
	
	# Tracking Radar signals
	if tracking_radar:
		tracking_radar.contact_detected.connect(_on_radar_contact_detected)
		tracking_radar.contact_lost.connect(_on_radar_contact_lost)
		tracking_radar.contact_updated.connect(_on_radar_contact_updated)
	
	# Threat Assessment signals
	if threat_assessment:
		threat_assessment.threat_level_changed.connect(_on_threat_level_changed)
		threat_assessment.new_threat_detected.connect(_on_new_threat_detected)
	
	# Target Classification signals
	if target_classification:
		target_classification.target_classified.connect(_on_target_classified)
		target_classification.classification_changed.connect(_on_classification_changed)
	
	# Target Handoff signals
	if target_handoff:
		target_handoff.handoff_completed.connect(_on_handoff_completed)
		target_handoff.handoff_failed.connect(_on_handoff_failed)

## Main tracking update loop
func _element_update(delta: float) -> void:
	super._element_update(delta)
	
	if not is_tracking_active:
		return
	
	var start_time = Time.get_ticks_usec()
	
	# Update tracking system components
	_update_radar_tracking(delta)
	_update_target_priorities(delta)
	_update_threat_assessments(delta)
	_update_track_predictions(delta)
	_update_spatial_partitioning()
	_cleanup_expired_tracks(delta)
	
	# Update situational awareness
	if situational_awareness:
		situational_awareness.update_situational_analysis(get_all_track_data())
	
	# Emit tracking data update
	tracking_data_updated.emit(get_all_track_data())
	
	# Performance monitoring
	var frame_time = (Time.get_ticks_usec() - start_time) / 1000.0
	if frame_time > frame_budget_ms:
		_handle_performance_degradation(frame_time)

func _update_radar_tracking(delta: float) -> void:
	if tracking_radar:
		tracking_radar.perform_radar_sweep()

func _update_target_priorities(delta: float) -> void:
	if target_priority_manager and not active_tracks.is_empty():
		# Update priorities for active tracks
		var track_data_array: Array[Dictionary] = []
		for track_id in active_tracks.keys():
			var track = active_tracks[track_id]
			track_data_array.append({
				"track_id": track_id,
				"distance": track.distance,
				"threat_level": track.threat_level,
				"target_type": track.target_type,
				"relationship": track.relationship,
				"velocity": track.velocity.length()
			})
		
		target_priority_manager.update_priorities(track_data_array)

func _update_threat_assessments(delta: float) -> void:
	if threat_assessment:
		for track_id in active_tracks.keys():
			var track = active_tracks[track_id]
			threat_assessment.assess_target_threat(track.target_node, track)

func _update_track_predictions(delta: float) -> void:
	var prediction_time = tracking_config.prediction_time
	
	for track_id in active_tracks.keys():
		var track = active_tracks[track_id]
		
		# Update position prediction
		track.prediction_position = track.position + (track.velocity * prediction_time)
		track.prediction_position += 0.5 * track.acceleration * prediction_time * prediction_time
		
		# Calculate prediction confidence based on track quality and age
		var track_age = Time.get_ticks_usec() / 1000000.0 - track.last_updated
		track.prediction_confidence = track.quality * exp(-track_age * 0.1)

func _update_spatial_partitioning() -> void:
	if not spatial_partitioning_enabled or not spatial_partition:
		return
	
	# Update positions in spatial partition
	for track_id in active_tracks.keys():
		var track = active_tracks[track_id]
		spatial_partition.update_track_position(track_id, track.position)

func _cleanup_expired_tracks(delta: float) -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	var tracks_to_remove: Array[int] = []
	
	for track_id in active_tracks.keys():
		var track = active_tracks[track_id]
		var track_age = current_time - track.last_updated
		
		# Remove tracks that are too old or low quality
		if track_age > tracking_config.max_track_age or track.quality < tracking_config.quality_threshold:
			tracks_to_remove.append(track_id)
	
	# Remove expired tracks
	for track_id in tracks_to_remove:
		remove_track(track_id, "expired")

func _handle_performance_degradation(frame_time_ms: float) -> void:
	# Implement performance degradation handling
	print("MultiTargetTracker: Performance degradation detected: %.2f ms" % frame_time_ms)
	
	# Reduce update frequency for non-critical tracks
	if active_tracks.size() > tracks_per_frame_limit:
		tracks_per_frame_limit = max(4, tracks_per_frame_limit - 1)
	
	# Reduce tracking range if necessary
	if active_tracks.size() > max_tracked_targets * 0.8:
		tracking_range_limit *= 0.95

## Track management functions

## Add new target to tracking system
func add_target(target: Node, initial_priority: int = 50) -> int:
	if not target or not is_instance_valid(target):
		return -1
	
	# Check tracking limits
	if active_tracks.size() >= max_tracked_targets:
		if not _make_room_for_new_target(initial_priority):
			tracking_limit_reached.emit(max_tracked_targets)
			return -1
	
	# Create new track
	track_counter += 1
	var track_id = track_counter
	var track = TrackData.new(track_id, target)
	
	# Initialize track data
	_initialize_track_data(track, target)
	track.priority = initial_priority
	
	# Add to active tracks
	active_tracks[track_id] = track
	
	# Add to spatial partition
	if spatial_partitioning_enabled and spatial_partition:
		spatial_partition.add_track(track_id, track.position)
	
	# Classify target
	if target_classification:
		target_classification.classify_target(target, track)
	
	# Assess threat
	if threat_assessment:
		threat_assessment.assess_target_threat(target, track)
	
	# Store in database
	if tracking_database:
		tracking_database.store_track_data(track)
	
	# Update priority list
	_rebuild_priority_list()
	
	# Emit signal
	target_acquired.emit(target, track_id)
	
	print("MultiTargetTracker: Target acquired - Track ID %d (%s)" % [track_id, target.name])
	return track_id

func _initialize_track_data(track: TrackData, target: Node) -> void:
	# Get basic position and movement data
	if target.has_method("get_global_position"):
		track.position = target.get_global_position()
	elif target.has_property("global_position"):
		track.position = target.global_position
	
	if target.has_method("get_velocity"):
		track.velocity = target.get_velocity()
	elif target.has_property("velocity"):
		track.velocity = target.velocity
	
	# Calculate derived data
	var player_pos = _get_player_position()
	track.distance = player_pos.distance_to(track.position)
	track.bearing = _calculate_bearing(player_pos, track.position)
	track.elevation = _calculate_elevation(player_pos, track.position)
	
	# Get target type information
	if target.has_method("get_object_type"):
		track.target_type = target.get_object_type()
	elif target.has_property("object_type"):
		track.target_type = target.object_type
	else:
		track.target_type = "unknown"
	
	# Determine relationship
	track.relationship = _determine_target_relationship(target)

func _determine_target_relationship(target: Node) -> String:
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
	
	return "unknown"

func _make_room_for_new_target(new_priority: int) -> bool:
	# Find lowest priority track to replace
	var lowest_priority = 999
	var lowest_track_id = -1
	
	for track_id in active_tracks.keys():
		var track = active_tracks[track_id]
		if track.priority < lowest_priority and track.priority < new_priority:
			lowest_priority = track.priority
			lowest_track_id = track_id
	
	if lowest_track_id != -1:
		remove_track(lowest_track_id, "replaced")
		return true
	
	return false

## Remove target from tracking system
func remove_track(track_id: int, reason: String = "manual") -> void:
	if not active_tracks.has(track_id):
		return
	
	var track = active_tracks[track_id]
	
	# Remove from spatial partition
	if spatial_partitioning_enabled and spatial_partition:
		spatial_partition.remove_track(track_id)
	
	# Archive in database
	if tracking_database:
		tracking_database.archive_track(track)
	
	# Remove from active tracks
	active_tracks.erase(track_id)
	
	# Update priority list
	_rebuild_priority_list()
	
	# Emit signal
	target_lost.emit(track_id, reason)
	
	print("MultiTargetTracker: Track lost - ID %d, Reason: %s" % [track_id, reason])

## Update existing track data
func update_track(track_id: int, target_data: Dictionary) -> void:
	if not active_tracks.has(track_id):
		return
	
	var track = active_tracks[track_id]
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	# Update position if provided
	if target_data.has("position"):
		var new_position = target_data["position"]
		var position_delta = track.position.distance_to(new_position)
		
		if position_delta > tracking_config.position_update_threshold:
			track.position = new_position
			
			# Update derived data
			var player_pos = _get_player_position()
			track.distance = player_pos.distance_to(track.position)
			track.bearing = _calculate_bearing(player_pos, track.position)
			track.elevation = _calculate_elevation(player_pos, track.position)
	
	# Update velocity with smoothing
	if target_data.has("velocity"):
		var new_velocity = target_data["velocity"]
		track.velocity = track.velocity.lerp(new_velocity, 1.0 - tracking_config.velocity_smoothing)
	
	# Update other data
	if target_data.has("threat_level"):
		track.threat_level = target_data["threat_level"]
	
	if target_data.has("quality"):
		track.quality = target_data["quality"]
	
	if target_data.has("classification"):
		track.classification = target_data["classification"]
	
	# Update timestamp
	track.last_updated = current_time

## Get track by ID
func get_track(track_id: int) -> TrackData:
	return active_tracks.get(track_id, null)

## Get all active tracks
func get_all_tracks() -> Array[TrackData]:
	var tracks: Array[TrackData] = []
	for track in active_tracks.values():
		tracks.append(track)
	return tracks

## Get all track data as dictionaries
func get_all_track_data() -> Array[Dictionary]:
	var track_data_array: Array[Dictionary] = []
	
	for track_id in active_tracks.keys():
		var track = active_tracks[track_id]
		track_data_array.append({
			"track_id": track_id,
			"target_name": track.target_node.name if track.target_node else "Unknown",
			"target_type": track.target_type,
			"classification": track.classification,
			"priority": track.priority,
			"threat_level": track.threat_level,
			"quality": track.quality,
			"position": track.position,
			"velocity": track.velocity,
			"distance": track.distance,
			"bearing": track.bearing,
			"elevation": track.elevation,
			"prediction_position": track.prediction_position,
			"prediction_confidence": track.prediction_confidence,
			"relationship": track.relationship,
			"tracking_system": track.tracking_system,
			"is_locked": track.is_locked,
			"lock_strength": track.lock_strength,
			"age": Time.get_ticks_usec() / 1000000.0 - track.first_detected
		})
	
	return track_data_array

## Get tracks by filter
func get_filtered_tracks(filter: TrackingFilter) -> Array[TrackData]:
	var filtered_tracks: Array[TrackData] = []
	
	for track in active_tracks.values():
		if _track_matches_filter(track, filter):
			filtered_tracks.append(track)
	
	return filtered_tracks

func _track_matches_filter(track: TrackData, filter: TrackingFilter) -> bool:
	match filter:
		TrackingFilter.ALL:
			return true
		TrackingFilter.HOSTILE:
			return track.relationship == "hostile"
		TrackingFilter.FRIENDLY:
			return track.relationship == "friendly"
		TrackingFilter.NEUTRAL:
			return track.relationship == "neutral"
		TrackingFilter.CAPITAL:
			return track.target_type in ["capital", "cruiser", "destroyer", "carrier"]
		TrackingFilter.FIGHTER:
			return track.target_type in ["fighter", "bomber", "interceptor"]
		TrackingFilter.MISSILE:
			return track.target_type in ["missile", "torpedo", "bomb"]
		TrackingFilter.UNKNOWN:
			return track.relationship == "unknown"
	
	return false

## Get tracks in range
func get_tracks_in_range(center: Vector3, radius: float) -> Array[TrackData]:
	var tracks_in_range: Array[TrackData] = []
	
	if spatial_partitioning_enabled and spatial_partition:
		# Use spatial partitioning for efficiency
		var nearby_track_ids = spatial_partition.get_nearby_tracks(center, radius)
		
		for track_id in nearby_track_ids:
			if active_tracks.has(track_id):
				var track = active_tracks[track_id]
				if track.position.distance_to(center) <= radius:
					tracks_in_range.append(track)
	else:
		# Brute force search
		for track in active_tracks.values():
			if track.position.distance_to(center) <= radius:
				tracks_in_range.append(track)
	
	return tracks_in_range

## Get highest priority tracks
func get_priority_tracks(count: int) -> Array[TrackData]:
	var priority_tracks: Array[TrackData] = []
	var sorted_track_ids = priority_sorted_tracks.slice(0, min(count, priority_sorted_tracks.size()))
	
	for track_id in sorted_track_ids:
		if active_tracks.has(track_id):
			priority_tracks.append(active_tracks[track_id])
	
	return priority_tracks

func _rebuild_priority_list() -> void:
	priority_sorted_tracks.clear()
	
	# Create array of track IDs with priorities
	var track_priorities: Array[Dictionary] = []
	for track_id in active_tracks.keys():
		var track = active_tracks[track_id]
		track_priorities.append({
			"track_id": track_id,
			"priority": track.priority,
			"threat_level": track.threat_level
		})
	
	# Sort by priority (higher is better), then by threat level
	track_priorities.sort_custom(func(a, b): 
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.threat_level > b.threat_level
	)
	
	# Extract sorted track IDs
	for item in track_priorities:
		priority_sorted_tracks.append(item.track_id)

## Configuration and control functions

## Set tracking mode
func set_tracking_mode(mode: TrackingMode) -> void:
	tracking_mode = mode
	
	# Adjust tracking parameters based on mode
	match mode:
		TrackingMode.COMBAT:
			tracking_config.quality_threshold = 0.2  # Lower threshold for combat
			auto_priority_management = true
		TrackingMode.STEALTH:
			tracking_range_limit *= 0.7  # Reduced range
			update_frequency *= 0.5  # Lower update rate
		TrackingMode.SEARCH:
			tracking_range_limit *= 1.5  # Extended range
			tracking_config.quality_threshold = 0.1  # Very low threshold
		TrackingMode.DEFENSIVE:
			# Prioritize missile and incoming threats
			auto_priority_management = true

## Set tracking filter
func set_tracking_filter(filter: TrackingFilter) -> void:
	tracking_filter = filter

## Clear all tracks
func clear_all_tracks() -> void:
	var track_ids = active_tracks.keys()
	for track_id in track_ids:
		remove_track(track_id, "cleared")
	
	if spatial_partitioning_enabled and spatial_partition:
		spatial_partition = SpatialPartition.new()

## Signal handlers

func _on_target_priority_changed(track_id: int, old_priority: int, new_priority: int) -> void:
	if active_tracks.has(track_id):
		active_tracks[track_id].priority = new_priority
		_rebuild_priority_list()
		target_priority_changed.emit(track_id, old_priority, new_priority)

func _on_priorities_recalculated(priority_data: Array[Dictionary]) -> void:
	for data in priority_data:
		var track_id = data.track_id
		var new_priority = data.priority
		
		if active_tracks.has(track_id):
			active_tracks[track_id].priority = new_priority
	
	_rebuild_priority_list()

func _on_radar_contact_detected(contact_data: Dictionary) -> void:
	# Check if we already have this target
	var target_node = contact_data.get("target_node", null)
	if not target_node:
		return
	
	# Look for existing track
	var existing_track_id = -1
	for track_id in active_tracks.keys():
		if active_tracks[track_id].target_node == target_node:
			existing_track_id = track_id
			break
	
	if existing_track_id == -1:
		# New contact
		var initial_priority = _calculate_initial_priority(contact_data)
		add_target(target_node, initial_priority)
	else:
		# Update existing track
		update_track(existing_track_id, contact_data)

func _on_radar_contact_lost(contact_data: Dictionary) -> void:
	var target_node = contact_data.get("target_node", null)
	if not target_node:
		return
	
	# Find and remove track
	for track_id in active_tracks.keys():
		if active_tracks[track_id].target_node == target_node:
			remove_track(track_id, "radar_lost")
			break

func _on_radar_contact_updated(contact_data: Dictionary) -> void:
	var target_node = contact_data.get("target_node", null)
	if not target_node:
		return
	
	# Find and update track
	for track_id in active_tracks.keys():
		if active_tracks[track_id].target_node == target_node:
			update_track(track_id, contact_data)
			break

func _on_threat_level_changed(target: Node, threat_level: float) -> void:
	for track_id in active_tracks.keys():
		var track = active_tracks[track_id]
		if track.target_node == target:
			track.threat_level = threat_level
			break

func _on_new_threat_detected(target: Node, threat_data: Dictionary) -> void:
	# Automatically add high-threat targets
	if threat_data.get("threat_level", 0.0) > 0.7:
		var priority = int(threat_data.get("threat_level", 0.5) * 100)
		add_target(target, priority)

func _on_target_classified(target: Node, classification: String) -> void:
	for track_id in active_tracks.keys():
		var track = active_tracks[track_id]
		if track.target_node == target:
			track.classification = classification
			break

func _on_classification_changed(target: Node, old_class: String, new_class: String) -> void:
	_on_target_classified(target, new_class)

func _on_handoff_completed(track_id: int, from_system: String, to_system: String) -> void:
	if active_tracks.has(track_id):
		active_tracks[track_id].tracking_system = to_system
		track_handoff_completed.emit(track_id, from_system, to_system)

func _on_handoff_failed(track_id: int, from_system: String, to_system: String, reason: String) -> void:
	print("MultiTargetTracker: Handoff failed for track %d: %s" % [track_id, reason])

## Utility functions

func _calculate_initial_priority(contact_data: Dictionary) -> int:
	var priority = 50  # Base priority
	
	# Adjust based on distance (closer = higher priority)
	var distance = contact_data.get("distance", 10000.0)
	if distance < 1000.0:
		priority += 30
	elif distance < 5000.0:
		priority += 15
	
	# Adjust based on threat level
	var threat_level = contact_data.get("threat_level", 0.0)
	priority += int(threat_level * 50)
	
	# Adjust based on target type
	var target_type = contact_data.get("target_type", "unknown")
	match target_type:
		"missile", "torpedo":
			priority += 40  # High priority for incoming ordnance
		"fighter", "bomber":
			priority += 20
		"capital", "cruiser":
			priority += 10
	
	return clamp(priority, 1, 100)

func _calculate_bearing(from: Vector3, to: Vector3) -> float:
	var direction = to - from
	return atan2(direction.x, direction.z)

func _calculate_elevation(from: Vector3, to: Vector3) -> float:
	var direction = to - from
	var horizontal_distance = Vector2(direction.x, direction.z).length()
	return atan2(direction.y, horizontal_distance)

func _get_player_position() -> Vector3:
	var player_ship = _get_player_ship()
	return player_ship.global_position if player_ship else Vector3.ZERO

func _get_player_ship() -> Node:
	# Try to find player ship
	var player_ships = get_tree().get_nodes_in_group("player_ships")
	return player_ships[0] if not player_ships.is_empty() else null

## Status and debugging

## Get tracking system status
func get_tracking_status() -> Dictionary:
	return {
		"is_active": is_tracking_active,
		"tracking_mode": TrackingMode.keys()[tracking_mode],
		"tracking_filter": TrackingFilter.keys()[tracking_filter],
		"active_tracks": active_tracks.size(),
		"max_targets": max_tracked_targets,
		"tracking_range": tracking_range_limit,
		"spatial_partitioning": spatial_partitioning_enabled,
		"auto_priority": auto_priority_management,
		"update_frequency": update_frequency,
		"frame_budget_ms": frame_budget_ms,
		"track_counter": track_counter
	}

## Get performance statistics
func get_performance_stats() -> Dictionary:
	var stats = {
		"active_tracks": active_tracks.size(),
		"tracks_per_frame_limit": tracks_per_frame_limit,
		"last_update_time": last_update_time,
		"average_frame_time": get_average_performance()
	}
	
	# Add component performance data
	if target_priority_manager:
		stats["priority_manager"] = target_priority_manager.get_performance_stats()
	
	if tracking_radar:
		stats["tracking_radar"] = tracking_radar.get_performance_stats()
	
	return stats
