class_name AIFrameBudgetManager
extends Node

## AI Frame Time Budget Manager
## Enforces processing time limits to maintain consistent 60 FPS performance

signal budget_exceeded(agent: WCSAIAgent, budget_ms: float, actual_ms: float)
signal budget_exhausted(remaining_agents: int)
signal budget_critical(usage_percent: float)

# Budget Configuration
var total_frame_budget_ms: float = 5.0  # 5ms total for all AI per frame (at 60 FPS)
var emergency_budget_ms: float = 8.0    # Emergency budget when frame drops
var critical_threshold: float = 0.8     # Warn when 80% of budget used

# Current Frame State
var current_frame_usage_ms: float = 0.0
var current_frame_start_time: int = 0
var agents_processed_this_frame: int = 0
var agents_skipped_this_frame: int = 0
var frame_number: int = 0

# Budget Allocation
var agent_budgets: Dictionary = {}      # WCSAIAgent -> allocated budget
var agent_actual_usage: Dictionary = {} # WCSAIAgent -> actual usage
var priority_queue: Array[WCSAIAgent] = []

# Performance Tracking
var frame_history: Array[Dictionary] = []
var max_history_frames: int = 60  # Keep 1 second of history at 60 FPS
var budget_violations: int = 0
var frames_over_budget: int = 0
var adaptive_scaling: bool = true

# Emergency Management
var emergency_mode: bool = false
var emergency_frames: int = 0
var max_emergency_frames: int = 10

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	_start_new_frame()

func start_frame_budget() -> void:
	"""Call this at the start of each frame's AI processing"""
	current_frame_start_time = Time.get_time_dict_from_system()["unix"] * 1000000  # microseconds
	current_frame_usage_ms = 0.0
	agents_processed_this_frame = 0
	agents_skipped_this_frame = 0
	frame_number += 1
	
	_prepare_agent_priority_queue()

func finish_frame_budget() -> void:
	"""Call this at the end of each frame's AI processing"""
	var frame_data: Dictionary = {
		"frame": frame_number,
		"total_usage_ms": current_frame_usage_ms,
		"budget_ms": _get_current_budget(),
		"agents_processed": agents_processed_this_frame,
		"agents_skipped": agents_skipped_this_frame,
		"budget_utilization": current_frame_usage_ms / _get_current_budget(),
		"violations": budget_violations,
		"emergency_mode": emergency_mode
	}
	
	_record_frame_data(frame_data)
	_check_budget_warnings()
	_adjust_emergency_mode()

func allocate_budget_for_agent(agent: WCSAIAgent) -> float:
	"""Allocate processing budget for an AI agent this frame"""
	if not is_instance_valid(agent):
		return 0.0
	
	# Check if we have budget remaining
	var remaining_budget: float = _get_remaining_budget()
	if remaining_budget <= 0.0:
		agents_skipped_this_frame += 1
		return 0.0
	
	# Calculate agent's budget based on priority and LOD
	var agent_budget: float = _calculate_agent_budget(agent)
	var allocated_budget: float = min(agent_budget, remaining_budget)
	
	# Reserve the budget
	agent_budgets[agent] = allocated_budget
	current_frame_usage_ms += allocated_budget
	
	return allocated_budget

func start_agent_timing(agent: WCSAIAgent) -> int:
	"""Start timing an agent's processing - returns timing token"""
	if not is_instance_valid(agent):
		return -1
	
	return Time.get_time_dict_from_system()["unix"] * 1000000  # microseconds

func finish_agent_timing(agent: WCSAIAgent, timing_token: int) -> float:
	"""Finish timing an agent's processing - returns actual time used in ms"""
	if not is_instance_valid(agent) or timing_token == -1:
		return 0.0
	
	var end_time: int = Time.get_time_dict_from_system()["unix"] * 1000000
	var actual_time_ms: float = (end_time - timing_token) / 1000.0
	
	# Record actual usage
	agent_actual_usage[agent] = actual_time_ms
	agents_processed_this_frame += 1
	
	# Check for budget violations
	var allocated_budget: float = agent_budgets.get(agent, 0.0)
	if actual_time_ms > allocated_budget * 1.2:  # 20% tolerance
		budget_exceeded.emit(agent, allocated_budget, actual_time_ms)
		budget_violations += 1
	
	# Adjust current usage (we reserved budget, now record actual)
	current_frame_usage_ms -= allocated_budget
	current_frame_usage_ms += actual_time_ms
	
	return actual_time_ms

func can_process_agent(agent: WCSAIAgent) -> bool:
	"""Check if agent can be processed within current budget constraints"""
	var remaining_budget: float = _get_remaining_budget()
	var estimated_cost: float = _estimate_agent_cost(agent)
	
	return remaining_budget >= estimated_cost

func get_budget_statistics() -> Dictionary:
	"""Get current budget statistics for monitoring"""
	var current_budget: float = _get_current_budget()
	
	return {
		"frame_budget_ms": current_budget,
		"used_budget_ms": current_frame_usage_ms,
		"remaining_budget_ms": _get_remaining_budget(),
		"budget_utilization": current_frame_usage_ms / current_budget if current_budget > 0 else 0.0,
		"agents_processed": agents_processed_this_frame,
		"agents_skipped": agents_skipped_this_frame,
		"budget_violations": budget_violations,
		"frames_over_budget": frames_over_budget,
		"emergency_mode": emergency_mode,
		"emergency_frames": emergency_frames,
		"total_agents": agent_budgets.size()
	}

func get_frame_history() -> Array[Dictionary]:
	"""Get recent frame performance history"""
	return frame_history.duplicate()

func set_total_budget(budget_ms: float) -> void:
	"""Set the total AI processing budget per frame"""
	total_frame_budget_ms = clamp(budget_ms, 1.0, 16.0)  # Between 1ms and 16ms

func enable_adaptive_scaling(enabled: bool) -> void:
	"""Enable/disable adaptive budget scaling based on performance"""
	adaptive_scaling = enabled

func force_emergency_mode(enabled: bool) -> void:
	"""Manually control emergency mode"""
	emergency_mode = enabled
	if not enabled:
		emergency_frames = 0

# Private Methods

func _start_new_frame() -> void:
	"""Internal frame initialization"""
	start_frame_budget()

func _prepare_agent_priority_queue() -> void:
	"""Prepare agents for processing in priority order"""
	priority_queue.clear()
	
	# Get all registered agents from AI Manager
	if AIManager:
		var all_agents: Array = AIManager.get_all_ai_agents()
		
		# Sort by priority (critical agents first)
		priority_queue = all_agents.duplicate()
		priority_queue.sort_custom(_compare_agent_priority)

func _compare_agent_priority(a: WCSAIAgent, b: WCSAIAgent) -> bool:
	"""Compare agents for priority sorting"""
	# Get LOD levels (lower number = higher priority)
	var a_lod: int = AIManager.ai_lod_manager.get_agent_lod_level(a) if AIManager.ai_lod_manager else 2
	var b_lod: int = AIManager.ai_lod_manager.get_agent_lod_level(b) if AIManager.ai_lod_manager else 2
	
	return a_lod < b_lod

func _calculate_agent_budget(agent: WCSAIAgent) -> float:
	"""Calculate budget allocation for specific agent"""
	var base_budget: float = total_frame_budget_ms / max(1, priority_queue.size())
	
	# Adjust based on LOD level
	var lod_multipliers: Array[float] = [3.0, 2.0, 1.0, 0.5, 0.2]  # CRITICAL to MINIMAL
	var lod_level: int = AIManager.ai_lod_manager.get_agent_lod_level(agent) if AIManager.ai_lod_manager else 2
	var lod_multiplier: float = lod_multipliers[lod_level] if lod_level < lod_multipliers.size() else 1.0
	
	return base_budget * lod_multiplier

func _estimate_agent_cost(agent: WCSAIAgent) -> float:
	"""Estimate processing cost for agent based on history"""
	if agent in agent_actual_usage:
		return agent_actual_usage[agent]
	
	# Default estimate based on LOD level
	var lod_estimates: Array[float] = [2.0, 1.0, 0.5, 0.2, 0.1]  # CRITICAL to MINIMAL
	var lod_level: int = AIManager.ai_lod_manager.get_agent_lod_level(agent) if AIManager.ai_lod_manager else 2
	
	return lod_estimates[lod_level] if lod_level < lod_estimates.size() else 0.5

func _get_current_budget() -> float:
	"""Get current frame budget (may be emergency budget)"""
	return emergency_budget_ms if emergency_mode else total_frame_budget_ms

func _get_remaining_budget() -> float:
	"""Get remaining budget for this frame"""
	return max(0.0, _get_current_budget() - current_frame_usage_ms)

func _record_frame_data(frame_data: Dictionary) -> void:
	"""Record frame performance data"""
	frame_history.append(frame_data)
	
	if frame_history.size() > max_history_frames:
		frame_history.pop_front()

func _check_budget_warnings() -> void:
	"""Check for budget warnings and emit signals"""
	var budget_utilization: float = current_frame_usage_ms / _get_current_budget()
	
	if budget_utilization > 1.0:
		frames_over_budget += 1
		budget_exhausted.emit(agents_skipped_this_frame)
	
	if budget_utilization > critical_threshold:
		budget_critical.emit(budget_utilization)

func _adjust_emergency_mode() -> void:
	"""Adjust emergency mode based on performance"""
	if not adaptive_scaling:
		return
	
	var budget_utilization: float = current_frame_usage_ms / total_frame_budget_ms
	
	# Enter emergency mode if consistently over budget
	if budget_utilization > 1.2 and not emergency_mode:
		emergency_mode = true
		emergency_frames = 0
		push_warning("AI Budget Manager: Entering emergency mode due to performance issues")
	
	# Count emergency frames
	if emergency_mode:
		emergency_frames += 1
		
		# Exit emergency mode after stable performance
		if emergency_frames >= max_emergency_frames and budget_utilization < 0.8:
			emergency_mode = false
			emergency_frames = 0
			push_warning("AI Budget Manager: Exiting emergency mode - performance stabilized")

func _on_frame_complete() -> void:
	"""Called when frame processing is complete"""
	finish_frame_budget()