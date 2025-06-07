class_name AIBehaviorSexpFunctions
extends RefCounted

## SEXP AI Behavior Control Functions
##
## Provides mission-driven AI behavior control functions for the SEXP system.
## These functions allow missions to directly influence AI behavior, goals, and tactical parameters
## while maintaining authentic WCS AI responsiveness and natural behavior patterns.

const BaseSexpFunction = preload("res://addons/sexp/functions/base_sexp_function.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpArgumentValidator = preload("res://addons/sexp/functions/sexp_argument_validator.gd")

## Set AI Goal Function - Assigns new goal to AI ship
class SetAIGoalFunction extends BaseSexpFunction:
	func _init():
		super._init("ai-set-goal", "ai", "Set primary goal for AI ship")
		function_signature = "(ai-set-goal ship_name goal_type [target] [priority])"
		minimum_args = 2
		maximum_args = 4
		is_pure_function = false  # Changes AI state
		is_cacheable = false
		supported_argument_types = [SexpResult.ResultType.STRING]
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var ship_name: String = args[0].get_string_value()
		var goal_type: String = args[1].get_string_value()
		var target: String = ""
		var priority: float = 1.0
		
		if args.size() > 2 and not args[2].is_null():
			target = args[2].get_string_value()
		if args.size() > 3 and not args[3].is_null():
			priority = args[3].get_number_value()
		
		# Get AI agent for ship
		var ai_agent: Node = _get_ai_agent_for_ship(ship_name)
		if not ai_agent:
			return SexpResult.create_error("Ship not found or has no AI: " + ship_name)
		
		# Set AI goal through goal system
		var goal_system: Node = ai_agent.get_node_or_null("AIGoalSystem")
		if not goal_system:
			return SexpResult.create_error("Ship has no goal system: " + ship_name)
		
		var success: bool = goal_system.set_primary_goal(goal_type, target, priority)
		if success:
			# Emit signal for mission tracking
			AIBehaviorMissionInterface.ai_goal_assigned.emit(ship_name, goal_type, target, priority)
			return SexpResult.create_boolean(true)
		else:
			return SexpResult.create_error("Failed to set AI goal: " + goal_type)

## Change AI Behavior Function - Modifies AI tactical behavior
class ChangeAIBehaviorFunction extends BaseSexpFunction:
	func _init():
		super._init("ai-change-behavior", "ai", "Change AI tactical behavior parameters")
		function_signature = "(ai-change-behavior ship_name behavior_type [intensity])"
		minimum_args = 2
		maximum_args = 3
		is_pure_function = false
		is_cacheable = false
		supported_argument_types = [SexpResult.ResultType.STRING]
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var ship_name: String = args[0].get_string_value()
		var behavior_type: String = args[1].get_string_value()
		var intensity: float = 1.0
		
		if args.size() > 2:
			intensity = args[2].get_number_value()
		
		var ai_agent: Node = _get_ai_agent_for_ship(ship_name)
		if not ai_agent:
			return SexpResult.create_error("Ship not found or has no AI: " + ship_name)
		
		# Apply behavior change through behavior system
		var success: bool = _apply_behavior_change(ai_agent, behavior_type, intensity)
		if success:
			AIBehaviorMissionInterface.ai_behavior_changed.emit(ship_name, behavior_type, intensity)
			return SexpResult.create_boolean(true)
		else:
			return SexpResult.create_error("Invalid behavior type: " + behavior_type)

## Set Formation Function - Assigns ships to formation
class SetFormationFunction extends BaseSexpFunction:
	func _init():
		super._init("ai-set-formation", "ai", "Assign ships to formation pattern")
		function_signature = "(ai-set-formation leader_ship formation_type ship_list [spacing])"
		minimum_args = 3
		maximum_args = 4
		is_pure_function = false
		is_cacheable = false
		supported_argument_types = [SexpResult.ResultType.STRING, SexpResult.ResultType.ARRAY]
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var leader_name: String = args[0].get_string_value()
		var formation_type: String = args[1].get_string_value()
		var ship_names: Array = args[2].get_array_value()
		var spacing: float = 120.0
		
		if args.size() > 3:
			spacing = args[3].get_number_value()
		
		# Get formation manager
		var formation_manager: Node = AIManager.get_formation_manager()
		if not formation_manager:
			return SexpResult.create_error("Formation manager not available")
		
		# Get leader ship
		var leader_ship: Node3D = _get_ship_node(leader_name)
		if not leader_ship:
			return SexpResult.create_error("Leader ship not found: " + leader_name)
		
		# Create formation
		var formation_id: String = formation_manager.create_formation(
			leader_ship, 
			_parse_formation_type(formation_type), 
			spacing
		)
		
		if formation_id.is_empty():
			return SexpResult.create_error("Failed to create formation")
		
		# Add member ships
		for ship_name in ship_names:
			var ship: Node3D = _get_ship_node(ship_name)
			if ship:
				formation_manager.add_ship_to_formation(formation_id, ship)
		
		AIBehaviorMissionInterface.formation_created.emit(leader_name, formation_type, ship_names, spacing)
		return SexpResult.create_string(formation_id)

## Set Target Priority Function - Modifies target prioritization
class SetTargetPriorityFunction extends BaseSexpFunction:
	func _init():
		super._init("ai-set-target-priority", "ai", "Set target priority for AI ship")
		function_signature = "(ai-set-target-priority ship_name target_name priority)"
		minimum_args = 3
		maximum_args = 3
		is_pure_function = false
		is_cacheable = false
		supported_argument_types = [SexpResult.ResultType.STRING, SexpResult.ResultType.NUMBER]
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var ship_name: String = args[0].get_string_value()
		var target_name: String = args[1].get_string_value()
		var priority: float = args[2].get_number_value()
		
		var ai_agent: Node = _get_ai_agent_for_ship(ship_name)
		if not ai_agent:
			return SexpResult.create_error("Ship not found or has no AI: " + ship_name)
		
		# Get threat assessment system
		var threat_system: Node = ai_agent.get_node_or_null("ThreatAssessmentSystem")
		if not threat_system:
			return SexpResult.create_error("Ship has no threat assessment system: " + ship_name)
		
		var target_ship: Node3D = _get_ship_node(target_name)
		if not target_ship:
			return SexpResult.create_error("Target ship not found: " + target_name)
		
		# Set target priority
		threat_system.set_target_priority_override(target_ship, priority)
		AIBehaviorMissionInterface.target_priority_set.emit(ship_name, target_name, priority)
		return SexpResult.create_boolean(true)

## Enable/Disable AI Function - Control AI engagement
class SetAIEnabledFunction extends BaseSexpFunction:
	func _init():
		super._init("ai-set-enabled", "ai", "Enable or disable AI for ship")
		function_signature = "(ai-set-enabled ship_name enabled)"
		minimum_args = 2
		maximum_args = 2
		is_pure_function = false
		is_cacheable = false
		supported_argument_types = [SexpResult.ResultType.STRING, SexpResult.ResultType.BOOLEAN]
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var ship_name: String = args[0].get_string_value()
		var enabled: bool = args[1].get_boolean_value()
		
		var ai_agent: Node = _get_ai_agent_for_ship(ship_name)
		if not ai_agent:
			return SexpResult.create_error("Ship not found or has no AI: " + ship_name)
		
		# Enable/disable AI
		ai_agent.set_enabled(enabled)
		AIBehaviorMissionInterface.ai_enabled_changed.emit(ship_name, enabled)
		return SexpResult.create_boolean(true)

## AI Status Check Function - Query AI state
class GetAIStatusFunction extends BaseSexpFunction:
	func _init():
		super._init("ai-get-status", "ai", "Get current AI status information")
		function_signature = "(ai-get-status ship_name [status_type])"
		minimum_args = 1
		maximum_args = 2
		is_pure_function = true
		is_cacheable = false  # Status changes frequently
		supported_argument_types = [SexpResult.ResultType.STRING]
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var ship_name: String = args[0].get_string_value()
		var status_type: String = "all"
		
		if args.size() > 1:
			status_type = args[1].get_string_value()
		
		var ai_agent: Node = _get_ai_agent_for_ship(ship_name)
		if not ai_agent:
			return SexpResult.create_error("Ship not found or has no AI: " + ship_name)
		
		match status_type:
			"goal":
				var goal_system: Node = ai_agent.get_node_or_null("AIGoalSystem")
				if goal_system:
					return SexpResult.create_string(goal_system.get_current_goal_type())
				else:
					return SexpResult.create_string("none")
			"target":
				if ai_agent.current_target:
					return SexpResult.create_string(ai_agent.current_target.name)
				else:
					return SexpResult.create_string("none")
			"behavior":
				return SexpResult.create_string(ai_agent.current_ai_state)
			"formation":
				if not ai_agent.formation_id.is_empty():
					return SexpResult.create_string(ai_agent.formation_id)
				else:
					return SexpResult.create_string("none")
			_:
				# Return full status as dictionary
				var status: Dictionary = {
					"goal": "none",
					"target": "none",
					"behavior": ai_agent.current_ai_state,
					"formation": ai_agent.formation_id if not ai_agent.formation_id.is_empty() else "none",
					"enabled": ai_agent.is_enabled()
				}
				return SexpResult.create_dictionary(status)

## Helper Functions
static func _get_ai_agent_for_ship(ship_name: String) -> Node:
	var ship: Node3D = _get_ship_node(ship_name)
	if not ship:
		return null
	
	# Look for WCSAIAgent component
	var ai_agent: Node = ship.get_node_or_null("WCSAIAgent")
	if not ai_agent:
		# Try finding it in children
		for child in ship.get_children():
			if child is preload("res://scripts/ai/core/wcs_ai_agent.gd"):
				ai_agent = child
				break
	
	return ai_agent

static func _get_ship_node(ship_name: String) -> Node3D:
	# This would integrate with the actual ship management system
	# For now, use a simple approach
	var ships: Array = get_tree().get_nodes_in_group("ships")
	for ship in ships:
		if ship.name == ship_name:
			return ship
	return null

static func _parse_formation_type(formation_type: String) -> int:
	match formation_type.to_lower():
		"diamond":
			return 0  # FormationManager.FormationType.DIAMOND
		"vic":
			return 1  # FormationManager.FormationType.VIC
		"line_abreast":
			return 2  # FormationManager.FormationType.LINE_ABREAST
		"column":
			return 3  # FormationManager.FormationType.COLUMN
		"finger_four":
			return 4  # FormationManager.FormationType.FINGER_FOUR
		"wall":
			return 5  # FormationManager.FormationType.WALL
		_:
			return 0  # Default to diamond

static func _apply_behavior_change(ai_agent: Node, behavior_type: String, intensity: float) -> bool:
	match behavior_type.to_lower():
		"aggressive":
			ai_agent.aggression_level = intensity
			return true
		"defensive":
			ai_agent.aggression_level = 1.0 - intensity
			return true
		"evasive":
			ai_agent.evasion_skill = intensity
			return true
		"accurate":
			ai_agent.accuracy_modifier = intensity
			return true
		"formation_precise":
			ai_agent.formation_precision = intensity
			return true
		_:
			return false

## Mission Interface Singleton for AI Events
class_name AIBehaviorMissionInterface
extends Node

signal ai_goal_assigned(ship_name: String, goal_type: String, target: String, priority: float)
signal ai_behavior_changed(ship_name: String, behavior_type: String, intensity: float)
signal formation_created(leader_name: String, formation_type: String, ship_names: Array, spacing: float)
signal target_priority_set(ship_name: String, target_name: String, priority: float)
signal ai_enabled_changed(ship_name: String, enabled: bool)

var active_ai_commands: Array[Dictionary] = []
var mission_context: Dictionary = {}

func _ready() -> void:
	# Connect to mission event system
	if has_node("/root/MissionEventManager"):
		var mission_manager: Node = get_node("/root/MissionEventManager")
		mission_manager.mission_phase_changed.connect(_on_mission_phase_changed)

func _on_mission_phase_changed(phase: String) -> void:
	mission_context["current_phase"] = phase
	# Adapt AI behaviors based on mission phase
	_adapt_ai_for_mission_phase(phase)

func _adapt_ai_for_mission_phase(phase: String) -> void:
	# Apply phase-specific AI adaptations
	match phase:
		"approach":
			_set_global_ai_behavior("cautious", 0.7)
		"engagement":
			_set_global_ai_behavior("aggressive", 0.9)
		"retreat":
			_set_global_ai_behavior("defensive", 0.8)

func _set_global_ai_behavior(behavior_type: String, intensity: float) -> void:
	var ai_agents: Array = get_tree().get_nodes_in_group("ai_agents")
	for agent in ai_agents:
		AIBehaviorSexpFunctions._apply_behavior_change(agent, behavior_type, intensity)

## Function Registration
static func register_all_functions(registry: SexpFunctionRegistry) -> void:
	registry.register_function(AIBehaviorSexpFunctions.SetAIGoalFunction.new())
	registry.register_function(AIBehaviorSexpFunctions.ChangeAIBehaviorFunction.new())
	registry.register_function(AIBehaviorSexpFunctions.SetFormationFunction.new())
	registry.register_function(AIBehaviorSexpFunctions.SetTargetPriorityFunction.new())
	registry.register_function(AIBehaviorSexpFunctions.SetAIEnabledFunction.new())
	registry.register_function(AIBehaviorSexpFunctions.GetAIStatusFunction.new())