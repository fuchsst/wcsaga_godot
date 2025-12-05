extends SceneTree

const GoalParser = preload("res://addons/wcs_import/parsers/mission_sections/goal_parser.gd")
const MissionManifest = preload("res://scripts/resources/missions/mission_manifest.gd")
const MissionGoal = preload("res://scripts/resources/missions/mission_goal.gd")
const MissionEvents = preload("res://scripts/resources/missions/mission_enums.gd")

func _init():
	_run_tests()
	quit()

func _run_tests():
	print("Running GoalParser Tests...")
	_test_basic_goal_parsing()
	print("All tests passed!")

func _test_basic_goal_parsing():
	print("  Testing basic goal parsing...")
	var base_parser = preload("res://addons/wcs_import/parsers/mission_parser.gd").new()
	var parser = GoalParser.new(base_parser)
	var manifest = MissionManifest.new()
	
	# Simulate Lines
	var lines = [
		"#Goals",
		"$Type: Primary",
		"+Name: destroy-enemy",
		"$MessageNew: Destroy all enemy fighters!",
		"+Formula: ( is-destroyed \"Enemy 1\" )",
		"+Score: 1000",
		"$Type: Bonus",
		"+Name: save-friendly",
		"$Message: Ensure friendly transport survives.",
		"+Formula: ( not ( is-destroyed \"Friend 1\" ) )",
		"+Score: 500",
		"#End"
	]
	
	base_parser._lines = lines
	base_parser._current_line_index = 1 # Start after #Goals
	
	parser.parse_section(1, manifest)
	
	_assert(manifest.goals.size() == 2, "Should have parsed 2 goals")
	
	var g1: MissionGoal = manifest.goals[0]
	_assert(g1.type == MissionGoal.Type.PRIMARY, "Goal 1 should be PRIMARY")
	_assert(g1.name == "destroy-enemy", "Goal 1 name mismatch")
	_assert(g1.message == "Destroy all enemy fighters!", "Goal 1 message mismatch")
	_assert(g1.score == 1000, "Goal 1 score mismatch")
	_assert(g1.behavior_tree != null, "Goal 1 BT should be compiled")
	
	var g2: MissionGoal = manifest.goals[1]
	_assert(g2.type == MissionGoal.Type.BONUS, "Goal 2 should be BONUS")
	_assert(g2.name == "save-friendly", "Goal 2 name mismatch")
	_assert(g2.message == "Ensure friendly transport survives.", "Goal 2 message mismatch")
	_assert(g2.behavior_tree != null, "Goal 2 BT should be compiled")

func _assert(condition: bool, message: String):
	if not condition:
		printerr("ASSERTION FAILED: ", message)
		quit(1)
