class_name BehaviorTreeManager
extends Node

## Manages behavior tree templates, pooling, and lifecycle for WCS AI system
## Integrates with SEXP system for mission-driven AI behavior modification

signal behavior_tree_loaded(template_name: String, tree: BehaviorTree)
signal behavior_tree_assigned(agent: WCSAIAgent, tree: BehaviorTree)
signal behavior_tree_performance_warning(template_name: String, execution_time: float)

@export var default_pool_size: int = 10
@export var max_concurrent_trees: int = 100
@export var performance_warning_threshold: float = 5.0  # milliseconds

# Tree template storage and pooling
var tree_templates: Dictionary = {}  # String -> BehaviorTree
var tree_pools: Dictionary = {}      # String -> Array[BehaviorTree]
var active_trees: Dictionary = {}    # WCSAIAgent -> BehaviorTree
var template_metadata: Dictionary = {} # String -> Dictionary

# SEXP integration for mission-driven behavior
var sexp_behavior_overrides: Dictionary = {}  # String -> SexpExpression
var mission_behavior_context: Dictionary = {}

# Performance monitoring
var tree_performance_stats: Dictionary = {}
var last_cleanup_time: float = 0.0
var cleanup_interval: float = 30.0

func _ready() -> void:
	_load_default_behavior_templates()
	_setup_sexp_integration()
	set_process(true)

func _process(delta: float) -> void:
	_update_performance_monitoring(delta)
	_cleanup_inactive_trees(delta)

func _load_default_behavior_templates() -> void:
	"""Load the standard behavior tree templates for different ship classes"""
	_load_fighter_templates()
	_load_capital_ship_templates()
	_load_support_ship_templates()
	_load_utility_templates()

func _load_fighter_templates() -> void:
	"""Load behavior tree templates for fighter-class ships"""
	var fighter_combat: BehaviorTree = _create_fighter_combat_tree()
	register_behavior_template("fighter_combat", fighter_combat, {
		"ship_classes": ["fighter", "interceptor", "bomber"],
		"behavior_type": "combat",
		"performance_priority": "high",
		"sexp_modifiable": true
	})
	
	var fighter_escort: BehaviorTree = _create_fighter_escort_tree()
	register_behavior_template("fighter_escort", fighter_escort, {
		"ship_classes": ["fighter", "interceptor"],
		"behavior_type": "escort",
		"performance_priority": "medium",
		"sexp_modifiable": true
	})
	
	var fighter_patrol: BehaviorTree = _create_fighter_patrol_tree()
	register_behavior_template("fighter_patrol", fighter_patrol, {
		"ship_classes": ["fighter", "interceptor", "bomber"],
		"behavior_type": "patrol",
		"performance_priority": "low",
		"sexp_modifiable": true
	})

func _load_capital_ship_templates() -> void:
	"""Load behavior tree templates for capital ships"""
	var capital_combat: BehaviorTree = _create_capital_ship_combat_tree()
	register_behavior_template("capital_combat", capital_combat, {
		"ship_classes": ["cruiser", "destroyer", "carrier", "capital"],
		"behavior_type": "combat",
		"performance_priority": "medium",
		"sexp_modifiable": true
	})
	
	var capital_support: BehaviorTree = _create_capital_ship_support_tree()
	register_behavior_template("capital_support", capital_support, {
		"ship_classes": ["carrier", "support"],
		"behavior_type": "support",
		"performance_priority": "low",
		"sexp_modifiable": true
	})

func _load_support_ship_templates() -> void:
	"""Load behavior tree templates for support ships"""
	var support_repair: BehaviorTree = _create_support_repair_tree()
	register_behavior_template("support_repair", support_repair, {
		"ship_classes": ["support", "repair"],
		"behavior_type": "support",
		"performance_priority": "medium",
		"sexp_modifiable": true
	})
	
	var support_cargo: BehaviorTree = _create_support_cargo_tree()
	register_behavior_template("support_cargo", support_cargo, {
		"ship_classes": ["cargo", "transport"],
		"behavior_type": "cargo",
		"performance_priority": "low",
		"sexp_modifiable": false
	})

func _load_utility_templates() -> void:
	"""Load utility behavior tree templates"""
	var retreat: BehaviorTree = _create_retreat_tree()
	register_behavior_template("retreat", retreat, {
		"ship_classes": ["all"],
		"behavior_type": "emergency",
		"performance_priority": "high",
		"sexp_modifiable": true
	})

func register_behavior_template(template_name: String, template_tree: BehaviorTree, metadata: Dictionary = {}) -> bool:
	"""Register a new behavior tree template"""
	if template_name.is_empty() or not template_tree:
		push_error("BehaviorTreeManager: Invalid template registration - name: %s, tree: %s" % [template_name, template_tree])
		return false
	
	tree_templates[template_name] = template_tree
	template_metadata[template_name] = metadata
	
	# Initialize pool for this template
	tree_pools[template_name] = []
	_populate_tree_pool(template_name, default_pool_size)
	
	behavior_tree_loaded.emit(template_name, template_tree)
	print("BehaviorTreeManager: Registered template '%s' with metadata: %s" % [template_name, metadata])
	return true

func assign_behavior_tree(agent: WCSAIAgent, template_name: String, force_new: bool = false) -> BehaviorTree:
	"""Assign a behavior tree to an AI agent, using pooling for efficiency"""
	if not agent or not agent.is_inside_tree():
		push_error("BehaviorTreeManager: Invalid agent for tree assignment")
		return null
	
	if not template_name in tree_templates:
		push_error("BehaviorTreeManager: Unknown behavior template: %s" % template_name)
		return null
	
	# Check if agent already has a tree assigned
	if agent in active_trees and not force_new:
		var current_tree: BehaviorTree = active_trees[agent]
		if current_tree and current_tree.resource_path == tree_templates[template_name].resource_path:
			return current_tree  # Already has the correct tree
		
		# Release the current tree back to pool
		release_behavior_tree(agent)
	
	# Get tree from pool or create new one
	var tree: BehaviorTree = _get_tree_from_pool(template_name)
	if not tree:
		push_warning("BehaviorTreeManager: Pool exhausted for template '%s', creating new tree" % template_name)
		tree = _create_tree_from_template(template_name)
	
	if not tree:
		push_error("BehaviorTreeManager: Failed to create tree from template: %s" % template_name)
		return null
	
	# Apply SEXP behavior modifications if available
	_apply_sexp_modifications(tree, template_name, agent)
	
	# Assign tree to agent
	active_trees[agent] = tree
	
	# Connect to agent for lifecycle management
	if not agent.tree_changed.is_connected(_on_agent_tree_changed):
		agent.tree_changed.connect(_on_agent_tree_changed.bind(agent))
	
	if not agent.tree_finished.is_connected(_on_agent_tree_finished):
		agent.tree_finished.connect(_on_agent_tree_finished.bind(agent))
	
	behavior_tree_assigned.emit(agent, tree)
	
	# Update performance tracking
	if not template_name in tree_performance_stats:
		tree_performance_stats[template_name] = {
			"total_assignments": 0,
			"active_count": 0,
			"average_execution_time": 0.0,
			"peak_execution_time": 0.0
		}
	
	tree_performance_stats[template_name]["total_assignments"] += 1
	tree_performance_stats[template_name]["active_count"] += 1
	
	return tree

func release_behavior_tree(agent: WCSAIAgent) -> bool:
	"""Release a behavior tree from an agent back to the pool"""
	if not agent in active_trees:
		return false
	
	var tree: BehaviorTree = active_trees[agent]
	var template_name: String = _find_template_name_for_tree(tree)
	
	# Clean up tree state
	if tree.has_method("reset"):
		tree.reset()
	
	# Return to pool if pool isn't full
	if template_name and template_name in tree_pools:
		var pool: Array = tree_pools[template_name]
		if pool.size() < default_pool_size * 2:  # Allow pool to grow up to 2x default size
			pool.append(tree)
		# If pool is full, let tree be garbage collected
	
	# Remove from active tracking
	active_trees.erase(agent)
	
	# Update performance stats
	if template_name in tree_performance_stats:
		tree_performance_stats[template_name]["active_count"] -= 1
	
	# Disconnect signals
	if agent.tree_changed.is_connected(_on_agent_tree_changed):
		agent.tree_changed.disconnect(_on_agent_tree_changed)
	
	if agent.tree_finished.is_connected(_on_agent_tree_finished):
		agent.tree_finished.disconnect(_on_agent_tree_finished)
	
	return true

func get_behavior_tree_for_agent(agent: WCSAIAgent) -> BehaviorTree:
	"""Get the currently assigned behavior tree for an agent"""
	return active_trees.get(agent, null)

func get_available_templates() -> Array:
	"""Get list of all available behavior tree templates"""
	return tree_templates.keys()

func get_templates_for_ship_class(ship_class: String) -> Array:
	"""Get behavior tree templates suitable for a specific ship class"""
	var suitable_templates: Array = []  # Array[String] - simplified for compatibility
	
	for template_name in tree_templates.keys():
		var metadata: Dictionary = template_metadata.get(template_name, {})
		var ship_classes: Array = metadata.get("ship_classes", [])
		
		if "all" in ship_classes or ship_class in ship_classes:
			suitable_templates.append(template_name)
	
	return suitable_templates

func _setup_sexp_integration() -> void:
	"""Initialize SEXP system integration for mission-driven AI behaviors"""
	# Connect to SEXP manager if available
	var sexp_manager = Engine.get_singleton("SexpManager")
	if sexp_manager:
		# Register AI behavior modification functions
		_register_ai_sexp_functions()
		
		# Connect to mission events for behavior changes
		if sexp_manager.has_signal("variable_changed"):
			sexp_manager.variable_changed.connect(_on_sexp_variable_changed)

func _register_ai_sexp_functions() -> void:
	"""Register SEXP functions for AI behavior modification"""
	var sexp_manager = Engine.get_singleton("SexpManager")
	if not sexp_manager or not sexp_manager.has_method("register_function"):
		return
	
	# Register AI behavior modification functions
	sexp_manager.register_function("ai-change-behavior", _sexp_change_ai_behavior)
	sexp_manager.register_function("ai-set-skill", _sexp_set_ai_skill)
	sexp_manager.register_function("ai-set-aggression", _sexp_set_ai_aggression)
	sexp_manager.register_function("ai-modify-formation", _sexp_modify_formation)
	sexp_manager.register_function("ai-override-behavior", _sexp_override_behavior)

func _sexp_change_ai_behavior(args: Array) -> Variant:
	"""SEXP function: (ai-change-behavior "ship_name" "behavior_template")"""
	if args.size() < 2:
		return false
	
	var ship_name: String = str(args[0])
	var behavior_template: String = str(args[1])
	
	# Find the ship by name and change its behavior
	var agent: WCSAIAgent = _find_agent_by_ship_name(ship_name)
	if agent:
		var tree: BehaviorTree = assign_behavior_tree(agent, behavior_template, true)
		return tree != null
	
	return false

func _sexp_set_ai_skill(args: Array) -> Variant:
	"""SEXP function: (ai-set-skill "ship_name" skill_level)"""
	if args.size() < 2:
		return false
	
	var ship_name: String = str(args[0])
	var skill_level: float = float(args[1])
	
	var agent: WCSAIAgent = _find_agent_by_ship_name(ship_name)
	if agent and agent.has_method("set_skill_level"):
		agent.set_skill_level(clamp(skill_level, 0.0, 1.0))
		return true
	
	return false

func _sexp_set_ai_aggression(args: Array) -> Variant:
	"""SEXP function: (ai-set-aggression "ship_name" aggression_level)"""
	if args.size() < 2:
		return false
	
	var ship_name: String = str(args[0])
	var aggression_level: float = float(args[1])
	
	var agent: WCSAIAgent = _find_agent_by_ship_name(ship_name)
	if agent and agent.has_method("set_aggression_level"):
		agent.set_aggression_level(clamp(aggression_level, 0.0, 1.0))
		return true
	
	return false

func _sexp_modify_formation(args: Array) -> Variant:
	"""SEXP function: (ai-modify-formation "wing_name" "formation_type")"""
	if args.size() < 2:
		return false
	
	var wing_name: String = str(args[0])
	var formation_type: String = str(args[1])
	
	# This would interface with formation management system
	# Implementation depends on wing/formation system
	push_warning("BehaviorTreeManager: Formation modification not yet implemented")
	return false

func _sexp_override_behavior(args: Array) -> Variant:
	"""SEXP function: (ai-override-behavior "ship_name" "override_expression")"""
	if args.size() < 2:
		return false
	
	var ship_name: String = str(args[0])
	var override_expr: String = str(args[1])
	
	# Parse and store behavior override
	var sexp_manager = Engine.get_singleton("SexpManager")
	if sexp_manager and sexp_manager.has_method("parse_expression"):
		var parsed_expr = sexp_manager.parse_expression(override_expr)
		if parsed_expr:
			sexp_behavior_overrides[ship_name] = parsed_expr
			return true
	
	return false

func _find_agent_by_ship_name(ship_name: String) -> WCSAIAgent:
	"""Find an AI agent by ship name"""
	for agent in active_trees.keys():
		if agent.has_method("get_ship_name") and agent.get_ship_name() == ship_name:
			return agent
		elif agent.name == ship_name:
			return agent
	
	return null

func _apply_sexp_modifications(tree: BehaviorTree, template_name: String, agent: WCSAIAgent) -> void:
	"""Apply SEXP-based behavior modifications to a behavior tree"""
	if not agent:
		return
	
	var ship_name: String = agent.get_ship_name() if agent.has_method("get_ship_name") else agent.name
	
	# Check for ship-specific overrides
	if ship_name in sexp_behavior_overrides:
		var override_expr = sexp_behavior_overrides[ship_name]
		_apply_behavior_override(tree, override_expr)
	
	# Apply global mission context modifications
	_apply_mission_context_modifications(tree, template_name)

func _apply_behavior_override(tree: BehaviorTree, override_expr) -> void:
	"""Apply a SEXP override expression to modify behavior tree"""
	# This would implement the logic to modify behavior tree based on SEXP expression
	# Could involve changing parameters, swapping nodes, or adding conditions
	push_warning("BehaviorTreeManager: Behavior override application not yet implemented")

func _apply_mission_context_modifications(tree: BehaviorTree, template_name: String) -> void:
	"""Apply mission context-based modifications to behavior tree"""
	# Apply global mission state modifications
	for context_key in mission_behavior_context.keys():
		var context_value = mission_behavior_context[context_key]
		# Apply modifications based on mission context
		# This is where mission-specific AI behavior changes would be applied
	
	# Get template metadata for context-sensitive modifications
	var metadata: Dictionary = template_metadata.get(template_name, {})
	if metadata.get("sexp_modifiable", false):
		# Apply any template-specific SEXP modifications
		pass

func _on_sexp_variable_changed(variable_name: String, new_value: Variant) -> void:
	"""Handle SEXP variable changes that might affect AI behavior"""
	# Check if this variable affects AI behavior
	if variable_name.begins_with("ai_") or variable_name.begins_with("behavior_"):
		mission_behavior_context[variable_name] = new_value
		
		# Trigger behavior updates for affected agents
		_update_behaviors_for_context_change(variable_name, new_value)

func _update_behaviors_for_context_change(variable_name: String, new_value: Variant) -> void:
	"""Update AI behaviors when mission context changes"""
	# This would implement logic to update active behavior trees
	# when SEXP variables change that affect AI behavior
	pass

func _on_agent_tree_changed(agent: WCSAIAgent) -> void:
	"""Handle when an agent's behavior tree changes"""
	# Update tracking if needed
	pass

func _on_agent_tree_finished(agent: WCSAIAgent) -> void:
	"""Handle when an agent's behavior tree finishes execution"""
	# Could trigger automatic behavior tree reassignment or cleanup
	pass

func _get_tree_from_pool(template_name: String) -> BehaviorTree:
	"""Get a behavior tree from the pool"""
	if not template_name in tree_pools:
		return null
	
	var pool: Array = tree_pools[template_name]
	if pool.is_empty():
		return null
	
	return pool.pop_back()

func _populate_tree_pool(template_name: String, count: int) -> void:
	"""Populate the tree pool with copies of a template"""
	if not template_name in tree_templates:
		return
	
	var template: BehaviorTree = tree_templates[template_name]
	var pool: Array = tree_pools.get(template_name, [])
	
	for i in count:
		var tree_copy: BehaviorTree = _create_tree_from_template(template_name)
		if tree_copy:
			pool.append(tree_copy)
	
	tree_pools[template_name] = pool

func _create_tree_from_template(template_name: String) -> BehaviorTree:
	"""Create a new behavior tree instance from a template"""
	if not template_name in tree_templates:
		return null
	
	var template: BehaviorTree = tree_templates[template_name]
	return template.duplicate() as BehaviorTree

func _find_template_name_for_tree(tree: BehaviorTree) -> String:
	"""Find the template name for a given behavior tree"""
	for template_name in tree_templates.keys():
		var template: BehaviorTree = tree_templates[template_name]
		if tree.resource_path == template.resource_path:
			return template_name
	
	return ""

func _update_performance_monitoring(delta: float) -> void:
	"""Update performance monitoring for active behavior trees"""
	# This would track execution times and performance metrics
	# Implementation depends on LimboAI's performance monitoring capabilities
	pass

func _cleanup_inactive_trees(delta: float) -> void:
	"""Periodic cleanup of inactive trees and performance data"""
	var current_time: float = Time.get_time_from_start()
	if current_time - last_cleanup_time < cleanup_interval:
		return
	
	last_cleanup_time = current_time
	
	# Clean up orphaned entries in active_trees
	var agents_to_remove: Array = []  # Array[WCSAIAgent] - avoiding circular type issues
	for agent in active_trees.keys():
		if not is_instance_valid(agent) or not agent.is_inside_tree():
			agents_to_remove.append(agent)
	
	for agent in agents_to_remove:
		active_trees.erase(agent)

func get_performance_stats() -> Dictionary:
	"""Get performance statistics for all behavior tree templates"""
	return tree_performance_stats.duplicate()

func get_template_metadata(template_name: String) -> Dictionary:
	"""Get metadata for a specific template"""
	return template_metadata.get(template_name, {})

# Template creation methods (these would create actual BehaviorTree resources)
func _create_fighter_combat_tree() -> BehaviorTree:
	"""Create a combat behavior tree for fighter ships"""
	# This would create a proper BehaviorTree resource with LimboAI nodes
	# For now, return a placeholder
	var tree: BehaviorTree = BehaviorTree.new()
	tree.resource_name = "FighterCombat"
	return tree

func _create_fighter_escort_tree() -> BehaviorTree:
	"""Create an escort behavior tree for fighter ships"""
	var tree: BehaviorTree = BehaviorTree.new()
	tree.resource_name = "FighterEscort"
	return tree

func _create_fighter_patrol_tree() -> BehaviorTree:
	"""Create a patrol behavior tree for fighter ships"""
	var tree: BehaviorTree = BehaviorTree.new()
	tree.resource_name = "FighterPatrol"
	return tree

func _create_capital_ship_combat_tree() -> BehaviorTree:
	"""Create a combat behavior tree for capital ships"""
	var tree: BehaviorTree = BehaviorTree.new()
	tree.resource_name = "CapitalCombat"
	return tree

func _create_capital_ship_support_tree() -> BehaviorTree:
	"""Create a support behavior tree for capital ships"""
	var tree: BehaviorTree = BehaviorTree.new()
	tree.resource_name = "CapitalSupport"
	return tree

func _create_support_repair_tree() -> BehaviorTree:
	"""Create a repair behavior tree for support ships"""
	var tree: BehaviorTree = BehaviorTree.new()
	tree.resource_name = "SupportRepair"
	return tree

func _create_support_cargo_tree() -> BehaviorTree:
	"""Create a cargo behavior tree for transport ships"""
	var tree: BehaviorTree = BehaviorTree.new()
	tree.resource_name = "SupportCargo"
	return tree

func _create_retreat_tree() -> BehaviorTree:
	"""Create a retreat behavior tree for emergency situations"""
	var tree: BehaviorTree = BehaviorTree.new()
	tree.resource_name = "Retreat"
	return tree