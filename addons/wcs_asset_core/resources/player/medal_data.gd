class_name MedalData
extends Resource

## WCS medal data resource containing medal information and requirements.
## Represents a single medal with display information and earning criteria.

@export var name: String = ""
@export var description: String = ""
@export var bitmap_filename: String = ""
@export var num_versions: int = 1
@export var kills_needed: int = 0
@export var badge_number: int = 0

# Badge-specific data (for kill-based medals)
@export var voice_base_filename: String = ""
@export var promotion_text: String = ""

# Medal categories for organization
enum MedalCategory {
	GENERAL_SERVICE,
	COMBAT_DECORATION,
	UNIT_CITATION,
	CAMPAIGN_MEDAL,
	ACHIEVEMENT_BADGE,
	RANK_INSIGNIA
}

@export var category: MedalCategory = MedalCategory.GENERAL_SERVICE

# Medal flags for special behavior
enum MedalFlags {
	NONE = 0,
	KILLBOARD_MEDAL = 1 << 0,    # Medal appears on killboard display
	MULTI_AWARD = 1 << 1,        # Can be awarded multiple times
	HIDDEN = 1 << 2,             # Hidden until earned
	SPECIAL_CRITERIA = 1 << 3    # Requires special mission criteria
}

@export var flags: int = MedalFlags.NONE

# Scoring requirements
@export var points_required: int = 0
@export var missions_required: int = 0
@export var accuracy_required: float = 0.0

# Special criteria for complex medals
@export var special_requirements: Array[String] = []

func _init() -> void:
	"""Initialize medal data resource."""
	resource_name = "MedalData"

func is_badge() -> bool:
	"""Check if this is a kill-based badge."""
	return kills_needed > 0

func is_multi_award() -> bool:
	"""Check if medal can be awarded multiple times."""
	return (flags & MedalFlags.MULTI_AWARD) != 0

func is_hidden_until_earned() -> bool:
	"""Check if medal is hidden until earned."""
	return (flags & MedalFlags.HIDDEN) != 0

func has_special_criteria() -> bool:
	"""Check if medal has special earning criteria."""
	return (flags & MedalFlags.SPECIAL_CRITERIA) != 0

func get_display_name() -> String:
	"""Get display name for the medal."""
	if name.is_empty():
		return "Unknown Medal"
	return name

func get_medal_info() -> Dictionary:
	"""Get medal information summary."""
	return {
		"name": name,
		"description": description,
		"category": MedalCategory.keys()[category],
		"is_badge": is_badge(),
		"kills_needed": kills_needed,
		"points_required": points_required,
		"missions_required": missions_required,
		"accuracy_required": accuracy_required,
		"is_multi_award": is_multi_award(),
		"is_hidden": is_hidden_until_earned()
	}

func check_eligibility(pilot_stats: PilotStatistics) -> bool:
	"""Check if pilot is eligible for this medal."""
	if not pilot_stats:
		return false
	
	# Check kill requirements
	if kills_needed > 0:
		var total_kills: int = pilot_stats.kill_count_ok
		if total_kills < kills_needed:
			return false
	
	# Check points requirement
	if points_required > 0:
		if pilot_stats.score < points_required:
			return false
	
	# Check missions requirement
	if missions_required > 0:
		if pilot_stats.missions_flown < missions_required:
			return false
	
	# Check accuracy requirement
	if accuracy_required > 0.0:
		var total_accuracy: float = pilot_stats.get_total_accuracy()
		if total_accuracy < accuracy_required:
			return false
	
	return true

func get_progress_toward_medal(pilot_stats: PilotStatistics) -> Dictionary:
	"""Get pilot's progress toward earning this medal."""
	if not pilot_stats:
		return {"progress": 0.0, "requirements_met": {}}
	
	var progress: Dictionary = {
		"progress": 0.0,
		"requirements_met": {},
		"next_requirement": ""
	}
	
	var requirements_count: int = 0
	var met_count: int = 0
	
	# Check each requirement
	if kills_needed > 0:
		requirements_count += 1
		var kills_progress: float = float(pilot_stats.kill_count_ok) / float(kills_needed)
		progress.requirements_met["kills"] = {
			"current": pilot_stats.kill_count_ok,
			"required": kills_needed,
			"progress": min(kills_progress, 1.0),
			"met": pilot_stats.kill_count_ok >= kills_needed
		}
		if pilot_stats.kill_count_ok >= kills_needed:
			met_count += 1
		elif progress.next_requirement.is_empty():
			progress.next_requirement = "Need %d more kills" % (kills_needed - pilot_stats.kill_count_ok)
	
	if points_required > 0:
		requirements_count += 1
		var points_progress: float = float(pilot_stats.score) / float(points_required)
		progress.requirements_met["points"] = {
			"current": pilot_stats.score,
			"required": points_required,
			"progress": min(points_progress, 1.0),
			"met": pilot_stats.score >= points_required
		}
		if pilot_stats.score >= points_required:
			met_count += 1
		elif progress.next_requirement.is_empty():
			progress.next_requirement = "Need %d more points" % (points_required - pilot_stats.score)
	
	if missions_required > 0:
		requirements_count += 1
		var missions_progress: float = float(pilot_stats.missions_flown) / float(missions_required)
		progress.requirements_met["missions"] = {
			"current": pilot_stats.missions_flown,
			"required": missions_required,
			"progress": min(missions_progress, 1.0),
			"met": pilot_stats.missions_flown >= missions_required
		}
		if pilot_stats.missions_flown >= missions_required:
			met_count += 1
		elif progress.next_requirement.is_empty():
			progress.next_requirement = "Need %d more missions" % (missions_required - pilot_stats.missions_flown)
	
	if accuracy_required > 0.0:
		requirements_count += 1
		var current_accuracy: float = pilot_stats.get_total_accuracy()
		var accuracy_progress: float = current_accuracy / accuracy_required
		progress.requirements_met["accuracy"] = {
			"current": current_accuracy,
			"required": accuracy_required,
			"progress": min(accuracy_progress, 1.0),
			"met": current_accuracy >= accuracy_required
		}
		if current_accuracy >= accuracy_required:
			met_count += 1
		elif progress.next_requirement.is_empty():
			progress.next_requirement = "Need %.1f%% accuracy" % accuracy_required
	
	# Calculate overall progress
	if requirements_count > 0:
		progress.progress = float(met_count) / float(requirements_count)
	
	return progress