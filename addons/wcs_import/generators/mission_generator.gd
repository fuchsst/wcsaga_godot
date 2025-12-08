class_name MissionGenerator
extends RefCounted

const MissionParser = preload("res://addons/wcs_import/parsers/mission_parser.gd")
const MissionManifest = preload("res://scripts/resources/missions/mission_manifest.gd")
const SexpParser = preload("res://addons/wcs_import/sexp/sexp_parser.gd")
const SexpCompiler = preload("res://addons/wcs_import/sexp/sexp_compiler.gd")


func process_mission(source_path: String, output_dir: String) -> bool:
	if not FileAccess.file_exists(source_path):
		push_error("Mission file not found: " + source_path)
		return false

	var parser = MissionParser.new()
	var manifest = parser.parse(source_path)

	if manifest == null:
		push_error("Failed to parse mission: " + source_path)
		return false

	# Compile SEXP formulas to BehaviorTrees
	_compile_mission_sexps(manifest)

	# Ensure output directory exists
	if not DirAccess.dir_exists_absolute(output_dir):
		var err = DirAccess.make_dir_recursive_absolute(output_dir)
		if err != OK:
			push_error("Failed to create output directory: " + output_dir)
			return false

	# Determine output filename
	var mission_name = source_path.get_file().get_basename()
	var filename = "mission.tres"

	# Force output to target/campaigns/hermes/missions/
	var mission_output_dir = "res://campaigns/hermes/missions/"
	var specific_mission_dir = mission_output_dir.path_join(mission_name)

	# Ensure directory exists (using DirAccess with absolute path)
	var abs_output_dir = ProjectSettings.globalize_path(specific_mission_dir)
	if not DirAccess.dir_exists_absolute(abs_output_dir):
		var err = DirAccess.make_dir_recursive_absolute(abs_output_dir)
		if err != OK:
			push_error("Failed to create mission directory: " + str(err))

	var output_path = specific_mission_dir.path_join(filename)

	# Set source file metadata
	manifest.mission_id = source_path.get_file().get_basename()

	# Save resource
	var err = ResourceSaver.save(manifest, output_path)
	if err != OK:
		push_error("Failed to save mission resource to: " + output_path)
		return false

	print("Successfully generated mission: " + output_path)
	return true


func _compile_mission_sexps(manifest: MissionManifest) -> void:
	"""Compile all SEXP formulas in the mission to BehaviorTrees"""

	# Compile event formulas
	for event in manifest.events:
		if not event.formula.is_empty():
			var bt = _compile_sexp_formula(event.formula)
			if bt:
				event.behavior_tree = bt
				print("  Compiled event BT: " + event.event_name)

	# Compile object arrival/departure cues and AI goals
	for obj in manifest.objects:
		# Arrival cue
		if (
			not obj.arrival_cue.is_empty()
			and obj.arrival_cue != "( true )"
			and obj.arrival_cue != "true"
		):
			var bt = _compile_sexp_formula(obj.arrival_cue)
			if bt:
				obj.arrival_cue_bt = bt
				print("  Compiled arrival cue BT: " + obj.object_name)

		# Departure cue
		if (
			not obj.departure_cue.is_empty()
			and obj.departure_cue != "( false )"
			and obj.departure_cue != "false"
		):
			var bt = _compile_sexp_formula(obj.departure_cue)
			if bt:
				obj.departure_cue_bt = bt
				print("  Compiled departure cue BT: " + obj.object_name)

		# AI goals
		if not obj.ai_goals.is_empty():
			var bt = _compile_sexp_formula(obj.ai_goals)
			if bt:
				obj.ai_goals_bt = bt
				print("  Compiled AI goals BT: " + obj.object_name)

	# Compile wing arrival/departure cues
	for wing in manifest.wings:
		if (
			not wing.arrival_cue.is_empty()
			and wing.arrival_cue != "( true )"
			and wing.arrival_cue != "true"
		):
			var bt = _compile_sexp_formula(wing.arrival_cue)
			if bt:
				wing.arrival_cue_bt = bt
				print("  Compiled wing arrival BT: " + wing.wing_name)

		if (
			not wing.departure_cue.is_empty()
			and wing.departure_cue != "( false )"
			and wing.departure_cue != "false"
		):
			var bt = _compile_sexp_formula(wing.departure_cue)
			if bt:
				wing.departure_cue_bt = bt
				print("  Compiled wing departure BT: " + wing.wing_name)

	# Compile goal formulas
	for goal in manifest.goals:
		if not goal.formula.is_empty():
			var bt = _compile_sexp_formula(goal.formula)
			if bt:
				goal.behavior_tree = bt
				print("  Compiled goal BT: " + goal.goal_name)


func _compile_sexp_formula(formula: String) -> BehaviorTree:
	"""Parse SEXP string and compile to BehaviorTree"""
	if formula.is_empty():
		return null

	# Parse SEXP string to node tree
	var sexp_node = SexpParser.parse(formula)
	if sexp_node == null:
		push_warning("Failed to parse SEXP formula: " + formula.left(50) + "...")
		return null

	# Compile node tree to BehaviorTree
	var bt = SexpCompiler.compile(sexp_node)
	if bt == null:
		push_warning("Failed to compile SEXP to BT: " + formula.left(50) + "...")
		return null

	return bt
