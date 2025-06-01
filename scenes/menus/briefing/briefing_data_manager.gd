class_name BriefingDataManager
extends Node

## Mission briefing data management and processing for WCS-Godot conversion.
## Handles briefing content loading, SEXP evaluation, and dynamic content generation.
## Manages mission objectives, narrative text, and tactical information presentation.

signal briefing_loaded(mission_data: MissionData)
signal briefing_stage_changed(stage_index: int, stage_data: BriefingStageData)
signal objectives_updated(objectives: Array[Dictionary])
signal ship_recommendations_updated(recommendations: Array[Dictionary])
signal briefing_error(error_message: String)

# Mission and briefing data
var current_mission_data: MissionData = null
var current_briefing_data: BriefingData = null
var current_stage_index: int = 0
var current_team_index: int = 0

# SEXP integration
var sexp_manager: SEXPManager = null

# Processed briefing content
var processed_objectives: Array[Dictionary] = []
var processed_narrative: Array[Dictionary] = []
var ship_recommendations: Array[Dictionary] = []

# Performance tracking
var content_processing_time: float = 0.0
var last_content_hash: String = ""

# Configuration
@export var enable_dynamic_objectives: bool = true
@export var enable_ship_recommendations: bool = true
@export var enable_narrative_processing: bool = true
@export var enable_sexp_evaluation: bool = true

func _ready() -> void:
	"""Initialize briefing data manager."""
	_setup_sexp_integration()
	name = "BriefingDataManager"

func _setup_sexp_integration() -> void:
	"""Setup SEXP manager integration for dynamic content."""
	# Find SEXP manager in the scene tree
	var sexp_nodes: Array[Node] = get_tree().get_nodes_in_group("sexp_manager")
	if not sexp_nodes.is_empty():
		sexp_manager = sexp_nodes[0] as SEXPManager

# ============================================================================
# BRIEFING LOADING AND PROCESSING
# ============================================================================

func load_mission_briefing(mission_data: MissionData, team_index: int = 0) -> bool:
	"""Load briefing data for the specified mission and team."""
	if not mission_data:
		briefing_error.emit("No mission data provided")
		return false
	
	current_mission_data = mission_data
	current_team_index = team_index
	current_stage_index = 0
	
	# Get briefing data for the team
	if team_index >= mission_data.briefings.size():
		briefing_error.emit("Invalid team index: %d" % team_index)
		return false
	
	current_briefing_data = mission_data.briefings[team_index] as BriefingData
	if not current_briefing_data:
		briefing_error.emit("No briefing data for team %d" % team_index)
		return false
	
	# Process briefing content
	var start_time: float = Time.get_time_dict_from_system()["unix"]
	
	_process_mission_objectives()
	_process_narrative_content()
	_generate_ship_recommendations()
	
	content_processing_time = Time.get_time_dict_from_system()["unix"] - start_time
	
	briefing_loaded.emit(mission_data)
	
	# Emit first stage
	if current_briefing_data.stages.size() > 0:
		briefing_stage_changed.emit(0, current_briefing_data.stages[0])
	
	return true

func _process_mission_objectives() -> void:
	"""Process mission objectives into display format."""
	processed_objectives.clear()
	
	if not current_mission_data:
		return
	
	for i in range(current_mission_data.goals.size()):
		var goal: MissionObjectiveData = current_mission_data.goals[i] as MissionObjectiveData
		if not goal:
			continue
		
		var objective: Dictionary = {
			"index": i,
			"name": goal.objective_text if not goal.objective_text.is_empty() else "Objective %d" % (i + 1),
			"description": goal.objective_text,
			"type": _get_objective_type(goal),
			"priority": _get_objective_priority(goal),
			"is_visible": _is_objective_visible(goal),
			"is_completed": false,  # Will be set during mission
			"completion_text": goal.objective_key_text,
			"sexp_condition": goal.formula_sexp
		}
		
		processed_objectives.append(objective)
	
	objectives_updated.emit(processed_objectives)

func _get_objective_type(goal: MissionObjectiveData) -> String:
	"""Determine objective type from goal data."""
	if not goal.formula_sexp:
		return "unknown"
	
	# Analyze SEXP to determine objective type
	var sexp_text: String = str(goal.formula_sexp)
	
	if "destroy" in sexp_text.to_lower() or "killed" in sexp_text.to_lower():
		return "destroy"
	elif "protect" in sexp_text.to_lower() or "survive" in sexp_text.to_lower():
		return "protect"
	elif "waypoint" in sexp_text.to_lower() or "dock" in sexp_text.to_lower():
		return "navigate"
	elif "cargo" in sexp_text.to_lower() or "scan" in sexp_text.to_lower():
		return "scan"
	else:
		return "general"

func _get_objective_priority(goal: MissionObjectiveData) -> String:
	"""Determine objective priority."""
	# Check goal flags or naming conventions
	var text: String = goal.objective_text.to_lower()
	
	if "primary" in text or "main" in text:
		return "primary"
	elif "secondary" in text or "bonus" in text:
		return "secondary"
	elif "hidden" in text or "secret" in text:
		return "hidden"
	else:
		return "primary"  # Default to primary

func _is_objective_visible(goal: MissionObjectiveData) -> bool:
	"""Check if objective should be visible based on SEXP conditions."""
	if not enable_sexp_evaluation or not sexp_manager or not goal.formula_sexp:
		return true
	
	# Evaluate SEXP condition for visibility
	# This would need actual SEXP evaluation implementation
	return true  # Default to visible

func _process_narrative_content() -> void:
	"""Process narrative content for the briefing."""
	processed_narrative.clear()
	
	if not current_briefing_data or not enable_narrative_processing:
		return
	
	for i in range(current_briefing_data.stages.size()):
		var stage: BriefingStageData = current_briefing_data.stages[i]
		if not stage:
			continue
		
		# Check if stage should be visible based on SEXP
		if not _is_stage_visible(stage):
			continue
		
		var narrative_entry: Dictionary = {
			"stage_index": i,
			"text": stage.text,
			"voice_path": stage.voice_path,
			"camera_position": stage.camera_pos,
			"camera_orientation": stage.camera_orient,
			"camera_time": stage.camera_time_ms,
			"is_cutscene": (stage.flags & 1) != 0,  # BS_FORWARD_CUT
			"characters": _extract_characters_from_text(stage.text),
			"duration_estimate": _estimate_narrative_duration(stage)
		}
		
		processed_narrative.append(narrative_entry)

func _is_stage_visible(stage: BriefingStageData) -> bool:
	"""Check if briefing stage should be visible based on SEXP conditions."""
	if not enable_sexp_evaluation or not sexp_manager or not stage.formula_sexp:
		return true
	
	# Evaluate SEXP condition for stage visibility
	# This would need actual SEXP evaluation implementation
	return true  # Default to visible

func _extract_characters_from_text(text: String) -> Array[String]:
	"""Extract character names from briefing text."""
	var characters: Array[String] = []
	
	# Look for character dialogue patterns like "Name: dialogue"
	var lines: PackedStringArray = text.split("\n")
	for line in lines:
		var colon_pos: int = line.find(":")
		if colon_pos > 0 and colon_pos < 20:  # Reasonable character name length
			var character_name: String = line.substr(0, colon_pos).strip_edges()
			if not character_name.is_empty() and not characters.has(character_name):
				characters.append(character_name)
	
	return characters

func _estimate_narrative_duration(stage: BriefingStageData) -> float:
	"""Estimate duration of narrative stage in seconds."""
	if not stage.voice_path.is_empty():
		# If we have voice, try to get actual audio duration
		# For now, estimate based on text length
		return max(5.0, stage.text.length() * 0.05)  # ~50ms per character
	else:
		# Text reading time estimation (200 WPM average)
		var word_count: int = stage.text.split(" ").size()
		return max(3.0, word_count / 3.33)  # 200 words per minute

func _generate_ship_recommendations() -> void:
	"""Generate ship recommendations based on mission analysis."""
	ship_recommendations.clear()
	
	if not current_mission_data or not enable_ship_recommendations:
		return
	
	# Analyze mission for ship recommendations
	var enemy_analysis: Dictionary = _analyze_enemy_threat()
	var mission_type: String = _determine_mission_type()
	var recommended_ships: Array[Dictionary] = _get_ship_recommendations_for_mission_type(mission_type, enemy_analysis)
	
	ship_recommendations = recommended_ships
	ship_recommendations_updated.emit(ship_recommendations)

func _analyze_enemy_threat() -> Dictionary:
	"""Analyze enemy ships to determine threat level and types."""
	var threat_analysis: Dictionary = {
		"fighters": 0,
		"bombers": 0,
		"capitals": 0,
		"total_threat_level": 0.0,
		"primary_threats": [],
		"special_threats": []
	}
	
	if not current_mission_data:
		return threat_analysis
	
	for ship_data in current_mission_data.ships:
		var ship: ShipInstanceData = ship_data as ShipInstanceData
		if not ship or ship.team == 0:  # Skip friendly ships (assuming team 0 is friendly)
			continue
		
		# Categorize enemy ships
		var ship_class: String = ship.ship_class_name.to_lower()
		if "fighter" in ship_class:
			threat_analysis.fighters += 1
		elif "bomber" in ship_class:
			threat_analysis.bombers += 1
		elif "capital" in ship_class or "cruiser" in ship_class or "destroyer" in ship_class:
			threat_analysis.capitals += 1
		
		# Add to threat level calculation
		threat_analysis.total_threat_level += _get_ship_threat_rating(ship.ship_class_name)
	
	return threat_analysis

func _get_ship_threat_rating(ship_class: String) -> float:
	"""Get threat rating for a ship class."""
	var class_lower: String = ship_class.to_lower()
	
	# Basic threat ratings (would be loaded from ship data in full implementation)
	if "fighter" in class_lower:
		return 1.0
	elif "bomber" in class_lower:
		return 2.0
	elif "cruiser" in class_lower:
		return 5.0
	elif "destroyer" in class_lower:
		return 8.0
	elif "capital" in class_lower:
		return 10.0
	else:
		return 1.0

func _determine_mission_type() -> String:
	"""Determine mission type from objectives and ship composition."""
	if processed_objectives.is_empty():
		return "patrol"
	
	var destroy_count: int = 0
	var protect_count: int = 0
	var navigate_count: int = 0
	var scan_count: int = 0
	
	for objective in processed_objectives:
		match objective.type:
			"destroy":
				destroy_count += 1
			"protect":
				protect_count += 1
			"navigate":
				navigate_count += 1
			"scan":
				scan_count += 1
	
	if destroy_count > protect_count and destroy_count > navigate_count:
		return "assault"
	elif protect_count > destroy_count:
		return "defense"
	elif navigate_count > 0 or scan_count > 0:
		return "reconnaissance"
	else:
		return "patrol"

func _get_ship_recommendations_for_mission_type(mission_type: String, threat_analysis: Dictionary) -> Array[Dictionary]:
	"""Get ship recommendations based on mission type and threat analysis."""
	var recommendations: Array[Dictionary] = []
	
	match mission_type:
		"assault":
			recommendations.append(_create_ship_recommendation("Heavy Fighter", "High armor and firepower for assault missions", "gtf_hercules", 5))
			recommendations.append(_create_ship_recommendation("Bomber", "Anti-capital ship capabilities", "gtb_ursa", 4))
		
		"defense":
			recommendations.append(_create_ship_recommendation("Interceptor", "Fast response to incoming threats", "gtf_ulysses", 5))
			recommendations.append(_create_ship_recommendation("Heavy Fighter", "Sustained combat capability", "gtf_hercules", 4))
		
		"reconnaissance":
			recommendations.append(_create_ship_recommendation("Scout Fighter", "Speed and sensors for reconnaissance", "gtf_ulysses", 5))
			recommendations.append(_create_ship_recommendation("Light Fighter", "Stealth and maneuverability", "gtf_apollo", 4))
		
		_:  # patrol or default
			recommendations.append(_create_ship_recommendation("Multi-role Fighter", "Balanced capabilities for patrol", "gtf_hercules", 4))
			recommendations.append(_create_ship_recommendation("Interceptor", "Fast response capability", "gtf_ulysses", 3))
	
	# Adjust recommendations based on threat level
	if threat_analysis.total_threat_level > 20.0:
		for recommendation in recommendations:
			recommendation.priority = min(5, recommendation.priority + 1)
			recommendation.reason += " (High threat environment)"
	
	return recommendations

func _create_ship_recommendation(ship_type: String, reason: String, ship_class: String, priority: int) -> Dictionary:
	"""Create a ship recommendation entry."""
	return {
		"ship_type": ship_type,
		"reason": reason,
		"ship_class": ship_class,
		"priority": priority,
		"confidence": 0.8  # Would be calculated based on data quality
	}

# ============================================================================
# BRIEFING NAVIGATION
# ============================================================================

func get_current_stage() -> BriefingStageData:
	"""Get the current briefing stage."""
	if not current_briefing_data or current_stage_index < 0 or current_stage_index >= current_briefing_data.stages.size():
		return null
	
	return current_briefing_data.stages[current_stage_index]

func advance_to_next_stage() -> bool:
	"""Advance to the next briefing stage."""
	if not current_briefing_data:
		return false
	
	var next_index: int = current_stage_index + 1
	if next_index >= current_briefing_data.stages.size():
		return false
	
	current_stage_index = next_index
	briefing_stage_changed.emit(current_stage_index, current_briefing_data.stages[current_stage_index])
	return true

func go_to_previous_stage() -> bool:
	"""Go to the previous briefing stage."""
	if not current_briefing_data:
		return false
	
	var prev_index: int = current_stage_index - 1
	if prev_index < 0:
		return false
	
	current_stage_index = prev_index
	briefing_stage_changed.emit(current_stage_index, current_briefing_data.stages[current_stage_index])
	return true

func go_to_stage(stage_index: int) -> bool:
	"""Go to a specific briefing stage."""
	if not current_briefing_data or stage_index < 0 or stage_index >= current_briefing_data.stages.size():
		return false
	
	current_stage_index = stage_index
	briefing_stage_changed.emit(current_stage_index, current_briefing_data.stages[current_stage_index])
	return true

func get_stage_count() -> int:
	"""Get the total number of briefing stages."""
	if not current_briefing_data:
		return 0
	
	return current_briefing_data.stages.size()

func is_first_stage() -> bool:
	"""Check if currently on the first stage."""
	return current_stage_index == 0

func is_last_stage() -> bool:
	"""Check if currently on the last stage."""
	if not current_briefing_data:
		return true
	
	return current_stage_index >= current_briefing_data.stages.size() - 1

# ============================================================================
# DATA ACCESS
# ============================================================================

func get_mission_objectives() -> Array[Dictionary]:
	"""Get processed mission objectives."""
	return processed_objectives

func get_narrative_content() -> Array[Dictionary]:
	"""Get processed narrative content."""
	return processed_narrative

func get_ship_recommendations() -> Array[Dictionary]:
	"""Get ship recommendations for the mission."""
	return ship_recommendations

func get_briefing_statistics() -> Dictionary:
	"""Get briefing processing statistics."""
	return {
		"total_stages": get_stage_count(),
		"current_stage": current_stage_index,
		"total_objectives": processed_objectives.size(),
		"primary_objectives": processed_objectives.filter(func(obj): return obj.priority == "primary").size(),
		"secondary_objectives": processed_objectives.filter(func(obj): return obj.priority == "secondary").size(),
		"processing_time": content_processing_time,
		"ship_recommendations": ship_recommendations.size(),
		"narrative_duration": processed_narrative.reduce(func(total, entry): return total + entry.duration_estimate, 0.0)
	}

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_briefing_manager() -> BriefingDataManager:
	"""Create a new briefing data manager instance."""
	var manager: BriefingDataManager = BriefingDataManager.new()
	manager.name = "BriefingDataManager"
	return manager