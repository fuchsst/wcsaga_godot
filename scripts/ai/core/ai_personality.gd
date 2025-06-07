class_name AIPersonality
extends Resource

## Defines behavioral characteristics for AI agents
## Configurable personality traits that affect AI behavior patterns and decision making

@export_group("Basic Traits")
@export var personality_name: String = "Default"
@export_range(0.1, 3.0) var skill_multiplier: float = 1.0
@export_range(0.05, 2.0) var reaction_time: float = 0.5
@export_range(0.1, 3.0) var accuracy_modifier: float = 1.0
@export_range(-1.0, 1.0) var aggression_bias: float = 0.0
@export_range(0.1, 2.0) var formation_discipline: float = 1.0
@export_range(0.05, 0.8) var retreat_threshold: float = 0.2

@export_group("Combat Behavior")
@export_range(0.1, 3.0) var weapon_accuracy: float = 1.0
@export_range(0.5, 3.0) var firing_rate_modifier: float = 1.0
@export_range(0.1, 2.0) var evasion_skill: float = 1.0
@export_range(0.0, 2.0) var pursuit_aggression: float = 1.0
@export var preferred_range: float = 500.0  # Preferred combat range
@export var preferred_weapons: Array[String] = ["primary"]

@export_group("Navigation Behavior")
@export_range(0.5, 2.0) var maneuver_speed: float = 1.0
@export_range(0.1, 2.0) var formation_precision: float = 1.0
@export_range(0.5, 3.0) var intercept_skill: float = 1.0
@export var preferred_approach: String = "direct"  # "direct", "flanking", "cautious"

@export_group("Tactical Behavior")
@export var target_priority_weights: Dictionary = {
	"fighters": 1.0,
	"bombers": 1.5,
	"capital_ships": 0.8,
	"player": 1.2
}
@export var behavior_modifiers: Dictionary = {
	"cover_wingman": 1.0,
	"protect_capital": 1.0,
	"hunt_enemies": 1.0,
	"follow_orders": 1.0
}

@export_group("Communication")
@export var chatter_frequency: float = 1.0
@export var responds_to_orders: bool = true
@export var reports_status: bool = true
@export var warns_allies: bool = true

@export_group("Advanced Traits")
@export_range(0.0, 2.0) var adaptability: float = 1.0  # How quickly AI adapts to situations
@export_range(0.0, 2.0) var predictability: float = 1.0  # How predictable AI behavior is
@export_range(0.0, 2.0) var risk_tolerance: float = 1.0  # Willingness to take risks
@export var special_abilities: Array[String] = []  # Special AI abilities

func apply_to_agent(agent: WCSAIAgent) -> void:
	"""Apply this personality's traits to an AI agent"""
	if not agent:
		return
	
	# Apply basic traits
	agent.skill_level *= skill_multiplier
	agent.aggression_level = clamp(agent.aggression_level + aggression_bias, 0.0, 2.0)
	agent.decision_frequency = reaction_time
	
	# Apply combat modifiers
	if agent.has_method("set_accuracy_modifier"):
		agent.set_accuracy_modifier(accuracy_modifier * weapon_accuracy)
	
	if agent.has_method("set_firing_rate_modifier"):
		agent.set_firing_rate_modifier(firing_rate_modifier)
	
	if agent.has_method("set_evasion_skill"):
		agent.set_evasion_skill(evasion_skill)
	
	# Apply navigation modifiers
	if agent.has_method("set_maneuver_speed"):
		agent.set_maneuver_speed(maneuver_speed)
	
	if agent.has_method("set_formation_precision"):
		agent.set_formation_precision(formation_precision * formation_discipline)
	
	# Store personality reference
	agent.ai_personality = self

func get_trait_description() -> String:
	"""Get a human-readable description of this personality"""
	var description: String = personality_name + " pilot:\n"
	
	# Skill assessment
	if skill_multiplier > 1.5:
		description += "• Highly skilled\n"
	elif skill_multiplier < 0.8:
		description += "• Inexperienced\n"
	else:
		description += "• Average skill\n"
	
	# Aggression assessment
	if aggression_bias > 0.3:
		description += "• Very aggressive\n"
	elif aggression_bias < -0.3:
		description += "• Cautious\n"
	else:
		description += "• Balanced temperament\n"
	
	# Reaction assessment
	if reaction_time < 0.3:
		description += "• Lightning reflexes\n"
	elif reaction_time > 0.8:
		description += "• Slow to react\n"
	else:
		description += "• Good reflexes\n"
	
	# Formation discipline
	if formation_discipline > 1.3:
		description += "• Excellent formation flying\n"
	elif formation_discipline < 0.8:
		description += "• Poor formation discipline\n"
	
	return description

func calculate_threat_rating(target_type: String) -> float:
	"""Calculate threat rating for a target type based on personality"""
	var base_rating: float = 1.0
	
	if target_priority_weights.has(target_type):
		base_rating = target_priority_weights[target_type]
	
	# Modify based on personality traits
	if aggression_bias > 0:
		base_rating *= 1.0 + aggression_bias * 0.5
	
	return base_rating

func should_retreat(current_health: float, threat_level: float) -> bool:
	"""Determine if AI should retreat based on personality and situation"""
	var health_factor: float = 1.0 - current_health
	var personality_threshold: float = retreat_threshold
	
	# Modify threshold based on aggression
	if aggression_bias > 0:
		personality_threshold *= (1.0 + aggression_bias)
	
	# Risk tolerance affects retreat decision
	personality_threshold *= (2.0 - risk_tolerance)
	
	return health_factor > personality_threshold or threat_level > (2.0 - risk_tolerance)

func get_preferred_combat_range() -> float:
	"""Get preferred combat range based on personality"""
	var range_modifier: float = 1.0
	
	# Aggressive pilots prefer closer range
	if aggression_bias > 0:
		range_modifier = 1.0 - (aggression_bias * 0.3)
	# Cautious pilots prefer longer range
	elif aggression_bias < 0:
		range_modifier = 1.0 + (abs(aggression_bias) * 0.5)
	
	return preferred_range * range_modifier

func get_maneuver_preference() -> String:
	"""Get preferred maneuver style based on personality"""
	if evasion_skill > 1.3 and aggression_bias > 0:
		return "aggressive_barrel_roll"
	elif evasion_skill > 1.0 and aggression_bias < 0:
		return "evasive_climb"
	elif skill_multiplier > 1.2:
		return "skilled_weaving"
	else:
		return "basic_evasion"

func get_formation_behavior() -> String:
	"""Get formation behavior preference"""
	if formation_discipline > 1.3:
		return "strict_formation"
	elif aggression_bias > 0.5:
		return "loose_formation"
	elif formation_discipline < 0.8:
		return "irregular_formation"
	else:
		return "standard_formation"

func modify_decision_weight(decision_type: String, base_weight: float) -> float:
	"""Modify AI decision weights based on personality"""
	var modified_weight: float = base_weight
	
	match decision_type:
		"attack_aggressively":
			modified_weight *= (1.0 + aggression_bias)
		"maintain_formation":
			modified_weight *= formation_discipline
		"retreat":
			modified_weight *= (2.0 - risk_tolerance)
		"assist_wingman":
			if behavior_modifiers.has("cover_wingman"):
				modified_weight *= behavior_modifiers["cover_wingman"]
		"follow_orders":
			if behavior_modifiers.has("follow_orders"):
				modified_weight *= behavior_modifiers["follow_orders"]
		"hunt_enemies":
			if behavior_modifiers.has("hunt_enemies"):
				modified_weight *= behavior_modifiers["hunt_enemies"]
	
	return modified_weight

func get_chatter_probability() -> float:
	"""Get probability of AI making radio chatter"""
	return chatter_frequency * 0.1  # Convert to probability per second

func create_behavior_profile() -> Dictionary:
	"""Create a complete behavior profile dictionary for AI system"""
	return {
		"personality_name": personality_name,
		"skill_level": skill_multiplier,
		"reaction_time": reaction_time,
		"accuracy": accuracy_modifier * weapon_accuracy,
		"aggression": aggression_bias,
		"formation_discipline": formation_discipline,
		"retreat_threshold": retreat_threshold,
		"evasion_skill": evasion_skill,
		"maneuver_speed": maneuver_speed,
		"preferred_range": get_preferred_combat_range(),
		"maneuver_preference": get_maneuver_preference(),
		"formation_behavior": get_formation_behavior(),
		"target_priorities": target_priority_weights,
		"behavior_weights": behavior_modifiers,
		"adaptability": adaptability,
		"predictability": predictability,
		"risk_tolerance": risk_tolerance,
		"special_abilities": special_abilities
	}

# Static factory methods for common personality types
static func create_rookie() -> AIPersonality:
	var personality: AIPersonality = AIPersonality.new()
	personality.personality_name = "Rookie"
	personality.skill_multiplier = 0.7
	personality.reaction_time = 0.8
	personality.accuracy_modifier = 0.8
	personality.aggression_bias = -0.2
	personality.formation_discipline = 0.9
	personality.retreat_threshold = 0.3
	personality.weapon_accuracy = 0.7
	personality.evasion_skill = 0.8
	personality.risk_tolerance = 0.6
	return personality

static func create_veteran() -> AIPersonality:
	var personality: AIPersonality = AIPersonality.new()
	personality.personality_name = "Veteran"
	personality.skill_multiplier = 1.3
	personality.reaction_time = 0.2
	personality.accuracy_modifier = 1.2
	personality.aggression_bias = 0.1
	personality.formation_discipline = 1.2
	personality.retreat_threshold = 0.15
	personality.weapon_accuracy = 1.3
	personality.evasion_skill = 1.4
	personality.risk_tolerance = 1.2
	return personality

static func create_ace() -> AIPersonality:
	var personality: AIPersonality = AIPersonality.new()
	personality.personality_name = "Ace"
	personality.skill_multiplier = 1.8
	personality.reaction_time = 0.1
	personality.accuracy_modifier = 1.5
	personality.aggression_bias = 0.3
	personality.formation_discipline = 1.5
	personality.retreat_threshold = 0.1
	personality.weapon_accuracy = 1.6
	personality.evasion_skill = 1.7
	personality.risk_tolerance = 1.5
	personality.special_abilities = ["advanced_maneuvers", "precise_targeting"]
	return personality

static func create_defender() -> AIPersonality:
	var personality: AIPersonality = AIPersonality.new()
	personality.personality_name = "Defender"
	personality.skill_multiplier = 1.1
	personality.reaction_time = 0.4
	personality.accuracy_modifier = 1.0
	personality.aggression_bias = -0.3
	personality.formation_discipline = 1.4
	personality.retreat_threshold = 0.25
	personality.behavior_modifiers = {
		"cover_wingman": 1.5,
		"protect_capital": 1.8,
		"hunt_enemies": 0.7,
		"follow_orders": 1.3
	}
	personality.risk_tolerance = 0.8
	return personality

static func create_aggressive() -> AIPersonality:
	var personality: AIPersonality = AIPersonality.new()
	personality.personality_name = "Aggressive"
	personality.skill_multiplier = 1.2
	personality.reaction_time = 0.3
	personality.accuracy_modifier = 0.9
	personality.aggression_bias = 0.6
	personality.formation_discipline = 0.8
	personality.retreat_threshold = 0.05
	personality.pursuit_aggression = 1.8
	personality.behavior_modifiers = {
		"hunt_enemies": 1.6,
		"follow_orders": 0.8
	}
	personality.risk_tolerance = 1.7
	return personality