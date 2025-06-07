class_name AIMissionReporter
extends Node

## AI Mission Reporting System
##
## Provides comprehensive feedback to the mission system about AI status, objectives,
## and completion. Enables mission scripts to query AI state, track goal progress,
## and receive notifications about AI behavior changes and achievements.

signal ai_status_reported(agent_name: String, status_data: Dictionary)
signal objective_progress_updated(objective_id: String, progress_data: Dictionary)
signal goal_completion_reported(agent_name: String, goal_id: String, completion_data: Dictionary)
signal formation_status_changed(formation_id: String, status_data: Dictionary)
signal tactical_situation_reported(situation_data: Dictionary)

## Report categories for different types of AI feedback
enum ReportCategory {
	STATUS_REPORT,        # General AI agent status
	OBJECTIVE_PROGRESS,   # Mission objective progress
	GOAL_COMPLETION,      # Individual goal completion
	FORMATION_UPDATE,     # Formation status changes
	TACTICAL_ANALYSIS,    # Tactical situation assessment
	PERFORMANCE_METRICS,  # AI performance statistics
	ERROR_REPORT,         # AI errors and failures
	BEHAVIOR_CHANGE      # Behavioral adaptations
}

## Report priority levels
enum ReportPriority {
	EMERGENCY = 5,    # Critical situations requiring immediate attention
	HIGH = 4,         # Important status changes
	NORMAL = 3,       # Standard operational reports
	LOW = 2,          # Informational updates
	DEBUG = 1         # Detailed debug information
}

## AI status tracking for all agents
var agent_status_registry: Dictionary = {}
var objective_progress_registry: Dictionary = {}
var formation_status_registry: Dictionary = {}
var tactical_reports: Array[Dictionary] = []

## Reporting configuration
var reporting_enabled: bool = true
var report_frequency: float = 2.0  # Default 2 seconds
var max_report_history: int = 100
var filter_by_priority: ReportPriority = ReportPriority.LOW

## Report history and analytics
var report_history: Array[Dictionary] = []
var performance_analytics: Dictionary = {}
var error_tracking: Dictionary = {}

## Mission system integration
var mission_event_manager: Node
var sexp_manager: Node

func _ready() -> void:
	_initialize_reporting_system()
	_connect_to_mission_systems()
	_start_periodic_reporting()

func _initialize_reporting_system() -> void:
	performance_analytics = {
		"total_reports": 0,
		"reports_by_category": {},
		"reports_by_priority": {},
		"average_report_interval": 0.0,
		"last_report_time": 0.0
	}
	
	error_tracking = {
		"total_errors": 0,
		"error_types": {},
		"critical_failures": 0,
		"recovery_successes": 0
	}
	
	# Initialize category counters
	for category in ReportCategory:
		performance_analytics["reports_by_category"][ReportCategory.keys()[category]] = 0
	
	for priority in ReportPriority:
		performance_analytics["reports_by_priority"][ReportPriority.keys()[priority]] = 0

func _connect_to_mission_systems() -> void:
	# Connect to mission event manager
	mission_event_manager = get_node_or_null("/root/MissionEventManager")
	if mission_event_manager:
		mission_event_manager.mission_objective_assigned.connect(_on_objective_assigned)
		mission_event_manager.mission_phase_changed.connect(_on_mission_phase_changed)
	
	# Connect to SEXP manager
	sexp_manager = get_node_or_null("/root/SexpManager")
	if sexp_manager:
		sexp_manager.expression_evaluated.connect(_on_sexp_expression_evaluated)
	
	# Connect to AI manager
	var ai_manager: Node = get_node_or_null("/root/AIManager")
	if ai_manager:
		ai_manager.ai_agent_registered.connect(_on_ai_agent_registered)
		ai_manager.ai_agent_deregistered.connect(_on_ai_agent_deregistered)

func _start_periodic_reporting() -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = report_frequency
	timer.timeout.connect(_generate_periodic_reports)
	timer.autostart = true
	add_child(timer)

## Core Reporting Interface
func report_ai_status(agent_name: String, status_data: Dictionary, priority: ReportPriority = ReportPriority.NORMAL) -> void:
	if not reporting_enabled or priority < filter_by_priority:
		return
	
	var report: Dictionary = _create_base_report(ReportCategory.STATUS_REPORT, priority)
	report["agent_name"] = agent_name
	report["status_data"] = status_data
	report["timestamp"] = Time.get_ticks_msec()
	
	# Update agent registry
	agent_status_registry[agent_name] = status_data
	
	# Store in history
	_add_to_report_history(report)
	
	# Emit signal for mission system
	ai_status_reported.emit(agent_name, status_data)
	
	# Update analytics
	_update_analytics(report)

func report_objective_progress(objective_id: String, progress_data: Dictionary, priority: ReportPriority = ReportPriority.NORMAL) -> void:
	if not reporting_enabled or priority < filter_by_priority:
		return
	
	var report: Dictionary = _create_base_report(ReportCategory.OBJECTIVE_PROGRESS, priority)
	report["objective_id"] = objective_id
	report["progress_data"] = progress_data
	report["timestamp"] = Time.get_ticks_msec()
	
	# Update objective registry
	objective_progress_registry[objective_id] = progress_data
	
	# Store in history
	_add_to_report_history(report)
	
	# Emit signal for mission system
	objective_progress_updated.emit(objective_id, progress_data)
	
	# Update analytics
	_update_analytics(report)

func report_goal_completion(agent_name: String, goal_id: String, completion_data: Dictionary, priority: ReportPriority = ReportPriority.HIGH) -> void:
	if not reporting_enabled or priority < filter_by_priority:
		return
	
	var report: Dictionary = _create_base_report(ReportCategory.GOAL_COMPLETION, priority)
	report["agent_name"] = agent_name
	report["goal_id"] = goal_id
	report["completion_data"] = completion_data
	report["timestamp"] = Time.get_ticks_msec()
	
	# Store in history
	_add_to_report_history(report)
	
	# Emit signal for mission system
	goal_completion_reported.emit(agent_name, goal_id, completion_data)
	
	# Update analytics
	_update_analytics(report)
	
	# Handle goal completion consequences
	_process_goal_completion(agent_name, goal_id, completion_data)

func report_formation_status(formation_id: String, status_data: Dictionary, priority: ReportPriority = ReportPriority.NORMAL) -> void:
	if not reporting_enabled or priority < filter_by_priority:
		return
	
	var report: Dictionary = _create_base_report(ReportCategory.FORMATION_UPDATE, priority)
	report["formation_id"] = formation_id
	report["status_data"] = status_data
	report["timestamp"] = Time.get_ticks_msec()
	
	# Update formation registry
	formation_status_registry[formation_id] = status_data
	
	# Store in history
	_add_to_report_history(report)
	
	# Emit signal for mission system
	formation_status_changed.emit(formation_id, status_data)
	
	# Update analytics
	_update_analytics(report)

func report_tactical_situation(situation_data: Dictionary, priority: ReportPriority = ReportPriority.HIGH) -> void:
	if not reporting_enabled or priority < filter_by_priority:
		return
	
	var report: Dictionary = _create_base_report(ReportCategory.TACTICAL_ANALYSIS, priority)
	report["situation_data"] = situation_data
	report["timestamp"] = Time.get_ticks_msec()
	
	# Add to tactical reports (keep only recent ones)
	tactical_reports.append(situation_data)
	if tactical_reports.size() > 10:
		tactical_reports.remove_at(0)
	
	# Store in history
	_add_to_report_history(report)
	
	# Emit signal for mission system
	tactical_situation_reported.emit(situation_data)
	
	# Update analytics
	_update_analytics(report)

func report_performance_metrics(metrics_data: Dictionary, priority: ReportPriority = ReportPriority.LOW) -> void:
	if not reporting_enabled or priority < filter_by_priority:
		return
	
	var report: Dictionary = _create_base_report(ReportCategory.PERFORMANCE_METRICS, priority)
	report["metrics_data"] = metrics_data
	report["timestamp"] = Time.get_ticks_msec()
	
	# Store in history
	_add_to_report_history(report)
	
	# Update analytics
	_update_analytics(report)

func report_error(agent_name: String, error_type: String, error_data: Dictionary, priority: ReportPriority = ReportPriority.HIGH) -> void:
	var report: Dictionary = _create_base_report(ReportCategory.ERROR_REPORT, priority)
	report["agent_name"] = agent_name
	report["error_type"] = error_type
	report["error_data"] = error_data
	report["timestamp"] = Time.get_ticks_msec()
	
	# Update error tracking
	error_tracking["total_errors"] += 1
	if not error_tracking["error_types"].has(error_type):
		error_tracking["error_types"][error_type] = 0
	error_tracking["error_types"][error_type] += 1
	
	if priority >= ReportPriority.EMERGENCY:
		error_tracking["critical_failures"] += 1
	
	# Store in history
	_add_to_report_history(report)
	
	# Update analytics
	_update_analytics(report)
	
	# Log error for debugging
	push_error("AI Error [" + agent_name + "]: " + error_type + " - " + str(error_data))

func report_behavior_change(agent_name: String, old_behavior: String, new_behavior: String, reason: String, priority: ReportPriority = ReportPriority.NORMAL) -> void:
	if not reporting_enabled or priority < filter_by_priority:
		return
	
	var report: Dictionary = _create_base_report(ReportCategory.BEHAVIOR_CHANGE, priority)
	report["agent_name"] = agent_name
	report["old_behavior"] = old_behavior
	report["new_behavior"] = new_behavior
	report["reason"] = reason
	report["timestamp"] = Time.get_ticks_msec()
	
	# Store in history
	_add_to_report_history(report)
	
	# Update analytics
	_update_analytics(report)

## Query Interface for Mission System
func get_agent_status(agent_name: String) -> Dictionary:
	return agent_status_registry.get(agent_name, {})

func get_objective_progress(objective_id: String) -> Dictionary:
	return objective_progress_registry.get(objective_id, {})

func get_formation_status(formation_id: String) -> Dictionary:
	return formation_status_registry.get(formation_id, {})

func get_recent_tactical_reports(count: int = 5) -> Array[Dictionary]:
	var recent_count: int = min(count, tactical_reports.size())
	return tactical_reports.slice(-recent_count) if recent_count > 0 else []

func get_all_agent_statuses() -> Dictionary:
	return agent_status_registry.duplicate()

func get_agents_by_status(status_criteria: Dictionary) -> Array[String]:
	var matching_agents: Array[String] = []
	
	for agent_name in agent_status_registry:
		var agent_status: Dictionary = agent_status_registry[agent_name]
		var matches: bool = true
		
		for criteria_key in status_criteria:
			if not agent_status.has(criteria_key) or agent_status[criteria_key] != status_criteria[criteria_key]:
				matches = false
				break
		
		if matches:
			matching_agents.append(agent_name)
	
	return matching_agents

func get_objectives_by_progress(min_progress: float = 0.0, max_progress: float = 1.0) -> Array[String]:
	var matching_objectives: Array[String] = []
	
	for objective_id in objective_progress_registry:
		var progress_data: Dictionary = objective_progress_registry[objective_id]
		var progress: float = progress_data.get("progress", 0.0)
		
		if progress >= min_progress and progress <= max_progress:
			matching_objectives.append(objective_id)
	
	return matching_objectives

func get_formations_by_status(status_filter: String = "") -> Array[String]:
	var matching_formations: Array[String] = []
	
	for formation_id in formation_status_registry:
		var formation_status: Dictionary = formation_status_registry[formation_id]
		var status: String = formation_status.get("status", "")
		
		if status_filter.is_empty() or status == status_filter:
			matching_formations.append(formation_id)
	
	return matching_formations

## Analytics and Performance Tracking
func get_performance_analytics() -> Dictionary:
	return performance_analytics.duplicate()

func get_error_tracking_data() -> Dictionary:
	return error_tracking.duplicate()

func get_report_history(category: ReportCategory = ReportCategory.STATUS_REPORT, count: int = 10) -> Array[Dictionary]:
	var filtered_reports: Array[Dictionary] = []
	
	for report in report_history:
		if report.get("category", -1) == category:
			filtered_reports.append(report)
	
	# Return most recent reports
	var recent_count: int = min(count, filtered_reports.size())
	return filtered_reports.slice(-recent_count) if recent_count > 0 else []

func get_mission_summary_report() -> Dictionary:
	var summary: Dictionary = {
		"total_agents": agent_status_registry.size(),
		"active_objectives": objective_progress_registry.size(),
		"active_formations": formation_status_registry.size(),
		"recent_tactical_reports": tactical_reports.size(),
		"total_reports_generated": performance_analytics["total_reports"],
		"error_rate": _calculate_error_rate(),
		"agent_status_breakdown": _generate_agent_status_breakdown(),
		"objective_progress_summary": _generate_objective_progress_summary(),
		"formation_health_summary": _generate_formation_health_summary(),
		"timestamp": Time.get_ticks_msec()
	}
	
	return summary

## Periodic Reporting
func _generate_periodic_reports() -> void:
	if not reporting_enabled:
		return
	
	# Generate agent status reports for all active agents
	_generate_agent_status_reports()
	
	# Generate objective progress reports
	_generate_objective_progress_reports()
	
	# Generate formation status reports
	_generate_formation_status_reports()
	
	# Generate tactical situation report
	_generate_tactical_situation_report()

func _generate_agent_status_reports() -> void:
	var ai_agents: Array = get_tree().get_nodes_in_group("ai_agents")
	
	for agent in ai_agents:
		var status_data: Dictionary = _collect_agent_status(agent)
		report_ai_status(agent.name, status_data, ReportPriority.LOW)

func _collect_agent_status(agent: Node) -> Dictionary:
	var status: Dictionary = {
		"agent_name": agent.name,
		"health": _get_agent_health(agent),
		"current_goal": _get_agent_current_goal(agent),
		"target": _get_agent_target(agent),
		"formation_id": _get_agent_formation(agent),
		"behavior_state": _get_agent_behavior_state(agent),
		"position": agent.global_position if agent.has_method("global_position") else Vector3.ZERO,
		"velocity": _get_agent_velocity(agent),
		"alertness_level": agent.get("alertness_level", 0.5),
		"aggression_level": agent.get("aggression_level", 0.5),
		"ammunition_status": _get_agent_ammunition_status(agent),
		"fuel_status": _get_agent_fuel_status(agent),
		"system_status": _get_agent_system_status(agent)
	}
	
	return status

func _get_agent_health(agent: Node) -> float:
	if agent.has_method("get_health_percentage"):
		return agent.get_health_percentage()
	return 1.0

func _get_agent_current_goal(agent: Node) -> String:
	var goal_system: Node = agent.get_node_or_null("AIGoalSystem")
	if goal_system and goal_system.has_method("get_current_goal_type"):
		return goal_system.get_current_goal_type()
	return "none"

func _get_agent_target(agent: Node) -> String:
	if agent.has_property("current_target") and agent.current_target:
		return agent.current_target.name
	return "none"

func _get_agent_formation(agent: Node) -> String:
	if agent.has_property("formation_id"):
		return agent.formation_id
	return "none"

func _get_agent_behavior_state(agent: Node) -> String:
	if agent.has_property("current_ai_state"):
		return agent.current_ai_state
	return "unknown"

func _get_agent_velocity(agent: Node) -> Vector3:
	if agent.has_method("get_velocity"):
		return agent.get_velocity()
	return Vector3.ZERO

func _get_agent_ammunition_status(agent: Node) -> Dictionary:
	var weapon_system: Node = agent.get_node_or_null("WeaponSystem")
	if weapon_system and weapon_system.has_method("get_ammunition_status"):
		return weapon_system.get_ammunition_status()
	return {"primary": 1.0, "secondary": 1.0}

func _get_agent_fuel_status(agent: Node) -> float:
	if agent.has_method("get_fuel_percentage"):
		return agent.get_fuel_percentage()
	return 1.0

func _get_agent_system_status(agent: Node) -> Dictionary:
	return {
		"engines": 1.0,
		"weapons": 1.0,
		"shields": 1.0,
		"sensors": 1.0,
		"navigation": 1.0
	}

func _generate_objective_progress_reports() -> void:
	# Implementation would query mission objectives and calculate progress
	pass

func _generate_formation_status_reports() -> void:
	var formation_manager: Node = get_node_or_null("/root/AIManager/FormationManager")
	if not formation_manager:
		return
	
	var active_formations: Array = formation_manager.get_active_formations()
	for formation_id in active_formations:
		var status_data: Dictionary = formation_manager.get_formation_status(formation_id)
		report_formation_status(formation_id, status_data, ReportPriority.LOW)

func _generate_tactical_situation_report() -> void:
	var tactical_analyzer: Node = get_node_or_null("/root/TacticalAnalyzer")
	if tactical_analyzer and tactical_analyzer.has_method("get_current_situation"):
		var situation: Dictionary = tactical_analyzer.get_current_situation()
		report_tactical_situation(situation, ReportPriority.NORMAL)

## Utility Methods
func _create_base_report(category: ReportCategory, priority: ReportPriority) -> Dictionary:
	return {
		"id": _generate_report_id(),
		"category": category,
		"priority": priority,
		"timestamp": Time.get_ticks_msec(),
		"mission_time": _get_mission_time()
	}

func _generate_report_id() -> String:
	return "report_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)

func _get_mission_time() -> float:
	if mission_event_manager and mission_event_manager.has_method("get_mission_time"):
		return mission_event_manager.get_mission_time()
	return 0.0

func _add_to_report_history(report: Dictionary) -> void:
	report_history.append(report)
	
	# Limit history size
	if report_history.size() > max_report_history:
		report_history.remove_at(0)

func _update_analytics(report: Dictionary) -> void:
	performance_analytics["total_reports"] += 1
	
	var category_key: String = ReportCategory.keys()[report.get("category", 0)]
	performance_analytics["reports_by_category"][category_key] += 1
	
	var priority_key: String = ReportPriority.keys()[report.get("priority", 0)]
	performance_analytics["reports_by_priority"][priority_key] += 1
	
	# Update average report interval
	var current_time: int = Time.get_ticks_msec()
	var last_time: int = performance_analytics.get("last_report_time", current_time)
	var interval: float = (current_time - last_time) / 1000.0
	
	if performance_analytics["average_report_interval"] == 0.0:
		performance_analytics["average_report_interval"] = interval
	else:
		performance_analytics["average_report_interval"] = \
			(performance_analytics["average_report_interval"] + interval) / 2.0
	
	performance_analytics["last_report_time"] = current_time

func _process_goal_completion(agent_name: String, goal_id: String, completion_data: Dictionary) -> void:
	var success: bool = completion_data.get("success", false)
	var goal_type: String = completion_data.get("goal_type", "unknown")
	
	# Check if this completion affects mission objectives
	_check_objective_implications(agent_name, goal_type, success)
	
	# Update mission context based on goal completion
	_update_mission_context_from_goal(agent_name, goal_id, completion_data)

func _check_objective_implications(agent_name: String, goal_type: String, success: bool) -> void:
	# Implementation would check if goal completion affects mission objectives
	pass

func _update_mission_context_from_goal(agent_name: String, goal_id: String, completion_data: Dictionary) -> void:
	# Implementation would update mission context based on goal completion
	pass

func _calculate_error_rate() -> float:
	var total_reports: int = performance_analytics["total_reports"]
	if total_reports == 0:
		return 0.0
	
	var total_errors: int = error_tracking["total_errors"]
	return float(total_errors) / float(total_reports)

func _generate_agent_status_breakdown() -> Dictionary:
	var breakdown: Dictionary = {
		"healthy": 0,
		"damaged": 0,
		"critical": 0,
		"destroyed": 0,
		"active": 0,
		"idle": 0,
		"in_formation": 0,
		"independent": 0
	}
	
	for agent_name in agent_status_registry:
		var status: Dictionary = agent_status_registry[agent_name]
		var health: float = status.get("health", 1.0)
		var goal: String = status.get("current_goal", "none")
		var formation: String = status.get("formation_id", "none")
		
		# Health breakdown
		if health > 0.8:
			breakdown["healthy"] += 1
		elif health > 0.3:
			breakdown["damaged"] += 1
		elif health > 0.0:
			breakdown["critical"] += 1
		else:
			breakdown["destroyed"] += 1
		
		# Activity breakdown
		if goal != "none":
			breakdown["active"] += 1
		else:
			breakdown["idle"] += 1
		
		# Formation breakdown
		if formation != "none":
			breakdown["in_formation"] += 1
		else:
			breakdown["independent"] += 1
	
	return breakdown

func _generate_objective_progress_summary() -> Dictionary:
	var summary: Dictionary = {
		"total_objectives": objective_progress_registry.size(),
		"completed": 0,
		"in_progress": 0,
		"not_started": 0,
		"failed": 0,
		"average_progress": 0.0
	}
	
	var total_progress: float = 0.0
	
	for objective_id in objective_progress_registry:
		var progress_data: Dictionary = objective_progress_registry[objective_id]
		var status: String = progress_data.get("status", "not_started")
		var progress: float = progress_data.get("progress", 0.0)
		
		match status:
			"completed":
				summary["completed"] += 1
			"in_progress":
				summary["in_progress"] += 1
			"failed":
				summary["failed"] += 1
			_:
				summary["not_started"] += 1
		
		total_progress += progress
	
	if summary["total_objectives"] > 0:
		summary["average_progress"] = total_progress / summary["total_objectives"]
	
	return summary

func _generate_formation_health_summary() -> Dictionary:
	var summary: Dictionary = {
		"total_formations": formation_status_registry.size(),
		"intact": 0,
		"damaged": 0,
		"broken": 0,
		"average_integrity": 0.0
	}
	
	var total_integrity: float = 0.0
	
	for formation_id in formation_status_registry:
		var status_data: Dictionary = formation_status_registry[formation_id]
		var integrity: float = status_data.get("integrity", 1.0)
		var status: String = status_data.get("status", "unknown")
		
		if integrity > 0.8:
			summary["intact"] += 1
		elif integrity > 0.3:
			summary["damaged"] += 1
		else:
			summary["broken"] += 1
		
		total_integrity += integrity
	
	if summary["total_formations"] > 0:
		summary["average_integrity"] = total_integrity / summary["total_formations"]
	
	return summary

## Event Handlers
func _on_objective_assigned(objective_id: String, objective_data: Dictionary) -> void:
	# Initialize objective progress tracking
	objective_progress_registry[objective_id] = {
		"status": "assigned",
		"progress": 0.0,
		"assigned_time": Time.get_ticks_msec(),
		"objective_data": objective_data
	}

func _on_mission_phase_changed(old_phase: String, new_phase: String) -> void:
	# Report phase change impact on AI systems
	var phase_report: Dictionary = {
		"phase_change": {
			"old_phase": old_phase,
			"new_phase": new_phase
		},
		"agent_adaptation_required": true,
		"expected_behavior_changes": _get_expected_behavior_changes(new_phase)
	}
	
	report_tactical_situation(phase_report, ReportPriority.HIGH)

func _get_expected_behavior_changes(phase: String) -> Array[String]:
	match phase:
		"approach":
			return ["increased_alertness", "tactical_formation", "stealth_mode"]
		"engagement":
			return ["combat_ready", "aggressive_targeting", "formation_combat"]
		"extraction":
			return ["escort_priority", "defensive_posture", "speed_emphasis"]
		_:
			return ["standard_behavior"]

func _on_sexp_expression_evaluated(expression: String, result: Variant) -> void:
	# Track SEXP expressions that affect AI
	if expression.begins_with("ai-"):
		var sexp_report: Dictionary = {
			"expression": expression,
			"result": result,
			"ai_impact": true,
			"evaluation_time": Time.get_ticks_msec()
		}
		
		report_performance_metrics(sexp_report, ReportPriority.NORMAL)

func _on_ai_agent_registered(agent: Node) -> void:
	# Initialize status tracking for new agent
	var initial_status: Dictionary = _collect_agent_status(agent)
	agent_status_registry[agent.name] = initial_status
	
	report_ai_status(agent.name, initial_status, ReportPriority.NORMAL)

func _on_ai_agent_deregistered(agent: Node) -> void:
	# Remove agent from tracking
	agent_status_registry.erase(agent.name)
	
	var deregistration_report: Dictionary = {
		"agent_name": agent.name,
		"reason": "deregistered",
		"final_status": _collect_agent_status(agent)
	}
	
	report_ai_status(agent.name, deregistration_report, ReportPriority.NORMAL)

## Configuration Interface
func set_reporting_enabled(enabled: bool) -> void:
	reporting_enabled = enabled

func set_report_frequency(frequency: float) -> void:
	report_frequency = max(0.1, frequency)

func set_priority_filter(min_priority: ReportPriority) -> void:
	filter_by_priority = min_priority

func clear_report_history() -> void:
	report_history.clear()

func reset_analytics() -> void:
	_initialize_reporting_system()

## Export Interface for Mission Scripts
func export_mission_report(filename: String = "") -> Dictionary:
	var export_data: Dictionary = {
		"mission_summary": get_mission_summary_report(),
		"agent_statuses": get_all_agent_statuses(),
		"objective_progress": objective_progress_registry.duplicate(),
		"formation_statuses": formation_status_registry.duplicate(),
		"tactical_reports": get_recent_tactical_reports(10),
		"performance_analytics": get_performance_analytics(),
		"error_tracking": get_error_tracking_data(),
		"export_timestamp": Time.get_ticks_msec()
	}
	
	if not filename.is_empty():
		var file: FileAccess = FileAccess.open(filename, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(export_data, "\t"))
			file.close()
	
	return export_data