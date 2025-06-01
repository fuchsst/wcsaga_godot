class_name RankData
extends Resource

## WCS rank data resource containing rank information and promotion requirements.
## Represents a single rank with display information and advancement criteria.

@export var name: String = ""
@export var description: String = ""
@export var bitmap_filename: String = ""
@export var promotion_text: String = ""
@export var promotion_voice_base: String = ""

# Rank progression
@export var rank_index: int = 0
@export var points_required: int = 0

# Additional promotion requirements
@export var missions_required: int = 0
@export var kills_required: int = 0
@export var accuracy_required: float = 0.0
@export var medals_required: Array[String] = []

# Rank categories
enum RankCategory {
	ENLISTED,
	OFFICER,
	SENIOR_OFFICER,
	FLAG_OFFICER
}

@export var category: RankCategory = RankCategory.ENLISTED

# Rank flags
enum RankFlags {
	NONE = 0,
	REQUIRES_MEDAL = 1 << 0,        # Requires specific medals
	SKIP_PROMOTION_CEREMONY = 1 << 1, # Skip promotion ceremony
	FINAL_RANK = 1 << 2             # Highest achievable rank
}

@export var flags: int = RankFlags.NONE

func _init() -> void:
	"""Initialize rank data resource."""
	resource_name = "RankData"

func is_final_rank() -> bool:
	"""Check if this is the final achievable rank."""
	return (flags & RankFlags.FINAL_RANK) != 0

func requires_medals() -> bool:
	"""Check if rank requires specific medals."""
	return (flags & RankFlags.REQUIRES_MEDAL) != 0 or not medals_required.is_empty()

func skip_ceremony() -> bool:
	"""Check if promotion ceremony should be skipped."""
	return (flags & RankFlags.SKIP_PROMOTION_CEREMONY) != 0

func get_display_name() -> String:
	"""Get display name for the rank."""
	if name.is_empty():
		return "Unknown Rank"
	return name

func get_rank_info() -> Dictionary:
	"""Get rank information summary."""
	return {
		"name": name,
		"description": description,
		"rank_index": rank_index,
		"category": RankCategory.keys()[category],
		"points_required": points_required,
		"missions_required": missions_required,
		"kills_required": kills_required,
		"accuracy_required": accuracy_required,
		"medals_required": medals_required.size(),
		"is_final_rank": is_final_rank(),
		"requires_medals": requires_medals()
	}

func check_promotion_eligibility(pilot_stats: PilotStatistics, earned_medals: Array[String]) -> bool:
	"""Check if pilot is eligible for promotion to this rank."""
	if not pilot_stats:
		return false
	
	# Check points requirement
	if points_required > 0 and pilot_stats.score < points_required:
		return false
	
	# Check missions requirement
	if missions_required > 0 and pilot_stats.missions_flown < missions_required:
		return false
	
	# Check kills requirement
	if kills_required > 0 and pilot_stats.kill_count_ok < kills_required:
		return false
	
	# Check accuracy requirement
	if accuracy_required > 0.0:
		var total_accuracy: float = pilot_stats.get_total_accuracy()
		if total_accuracy < accuracy_required:
			return false
	
	# Check medal requirements
	if requires_medals():
		for required_medal in medals_required:
			if not earned_medals.has(required_medal):
				return false
	
	return true

func get_promotion_progress(pilot_stats: PilotStatistics, earned_medals: Array[String]) -> Dictionary:
	"""Get pilot's progress toward promotion to this rank."""
	if not pilot_stats:
		return {"progress": 0.0, "requirements_met": {}}
	
	var progress: Dictionary = {
		"progress": 0.0,
		"requirements_met": {},
		"next_requirement": "",
		"blocking_requirements": []
	}
	
	var requirements_count: int = 0
	var met_count: int = 0
	
	# Check points requirement
	if points_required > 0:
		requirements_count += 1
		var points_progress: float = float(pilot_stats.score) / float(points_required)
		var points_met: bool = pilot_stats.score >= points_required
		progress.requirements_met["points"] = {
			"current": pilot_stats.score,
			"required": points_required,
			"progress": min(points_progress, 1.0),
			"met": points_met
		}
		if points_met:
			met_count += 1
		else:
			var points_needed: int = points_required - pilot_stats.score
			progress.blocking_requirements.append("Need %d more points" % points_needed)
			if progress.next_requirement.is_empty():
				progress.next_requirement = "Score %d more points" % points_needed
	
	# Check missions requirement
	if missions_required > 0:
		requirements_count += 1
		var missions_progress: float = float(pilot_stats.missions_flown) / float(missions_required)
		var missions_met: bool = pilot_stats.missions_flown >= missions_required
		progress.requirements_met["missions"] = {
			"current": pilot_stats.missions_flown,
			"required": missions_required,
			"progress": min(missions_progress, 1.0),
			"met": missions_met
		}
		if missions_met:
			met_count += 1
		else:
			var missions_needed: int = missions_required - pilot_stats.missions_flown
			progress.blocking_requirements.append("Complete %d more missions" % missions_needed)
			if progress.next_requirement.is_empty():
				progress.next_requirement = "Complete %d more missions" % missions_needed
	
	# Check kills requirement
	if kills_required > 0:
		requirements_count += 1
		var kills_progress: float = float(pilot_stats.kill_count_ok) / float(kills_required)
		var kills_met: bool = pilot_stats.kill_count_ok >= kills_required
		progress.requirements_met["kills"] = {
			"current": pilot_stats.kill_count_ok,
			"required": kills_required,
			"progress": min(kills_progress, 1.0),
			"met": kills_met
		}
		if kills_met:
			met_count += 1
		else:
			var kills_needed: int = kills_required - pilot_stats.kill_count_ok
			progress.blocking_requirements.append("Score %d more kills" % kills_needed)
			if progress.next_requirement.is_empty():
				progress.next_requirement = "Score %d more kills" % kills_needed
	
	# Check accuracy requirement
	if accuracy_required > 0.0:
		requirements_count += 1
		var current_accuracy: float = pilot_stats.get_total_accuracy()
		var accuracy_progress: float = current_accuracy / accuracy_required
		var accuracy_met: bool = current_accuracy >= accuracy_required
		progress.requirements_met["accuracy"] = {
			"current": current_accuracy,
			"required": accuracy_required,
			"progress": min(accuracy_progress, 1.0),
			"met": accuracy_met
		}
		if accuracy_met:
			met_count += 1
		else:
			var accuracy_needed: float = accuracy_required - current_accuracy
			progress.blocking_requirements.append("Improve accuracy by %.1f%%" % accuracy_needed)
			if progress.next_requirement.is_empty():
				progress.next_requirement = "Achieve %.1f%% accuracy" % accuracy_required
	
	# Check medal requirements
	if requires_medals():
		requirements_count += 1
		var medals_met: int = 0
		var missing_medals: Array[String] = []
		
		for required_medal in medals_required:
			if earned_medals.has(required_medal):
				medals_met += 1
			else:
				missing_medals.append(required_medal)
		
		var medals_complete: bool = missing_medals.is_empty()
		progress.requirements_met["medals"] = {
			"current": medals_met,
			"required": medals_required.size(),
			"progress": float(medals_met) / float(medals_required.size()) if medals_required.size() > 0 else 1.0,
			"met": medals_complete,
			"missing_medals": missing_medals
		}
		
		if medals_complete:
			met_count += 1
		else:
			var medal_text: String = "Earn required medals"
			if missing_medals.size() == 1:
				medal_text = "Earn medal: " + missing_medals[0]
			elif missing_medals.size() <= 3:
				medal_text = "Earn medals: " + ", ".join(missing_medals)
			progress.blocking_requirements.append(medal_text)
			if progress.next_requirement.is_empty():
				progress.next_requirement = medal_text
	
	# Calculate overall progress
	if requirements_count > 0:
		progress.progress = float(met_count) / float(requirements_count)
	else:
		progress.progress = 1.0  # No requirements means automatic promotion
	
	return progress

func get_category_name() -> String:
	"""Get human-readable category name."""
	match category:
		RankCategory.ENLISTED:
			return "Enlisted"
		RankCategory.OFFICER:
			return "Officer"
		RankCategory.SENIOR_OFFICER:
			return "Senior Officer"
		RankCategory.FLAG_OFFICER:
			return "Flag Officer"
		_:
			return "Unknown"