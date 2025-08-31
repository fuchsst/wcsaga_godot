# Test script for the IFF system
# Verifies that IFF relationships and queries work correctly

class_name TestIFFSystem
extends Node


func _ready() -> void:
	test_iff_loading()
	test_iff_relationships()
	test_iff_perceptions()
	print("All IFF system tests completed!")


func test_iff_loading() -> void:
	print("Testing IFF loading...")

	# Check that all expected IFFs are loaded
	var expected_iffs = ["Friendly", "Hostile", "Neutral", "Unknown", "Traitor", "Non Combatant"]
	for iff_name in expected_iffs:
		var iff = IFFManager.get_iff(iff_name)
		if iff:
			print("  Loaded IFF: " + iff_name)
		else:
			print("  ERROR: Failed to load IFF: " + iff_name)


func test_iff_relationships() -> void:
	print("Testing IFF relationships...")

	# Test that Friendly attacks Hostile
	if IFFManager.does_iff_attack("Friendly", "Hostile"):
		print("  PASS: Friendly attacks Hostile")
	else:
		print("  FAIL: Friendly should attack Hostile")

	# Test that Non Combatant doesn't attack anyone
	if not IFFManager.does_iff_attack("Non Combatant", "Friendly"):
		print("  PASS: Non Combatant doesn't attack Friendly")
	else:
		print("  FAIL: Non Combatant should not attack anyone")


func test_iff_perceptions() -> void:
	print("Testing IFF perceptions...")

	# Test Hostile's perception of Friendly
	var hostile_sees_friendly = IFFManager.get_iff_perception("Hostile", "Friendly")
	var expected_color = Color(0.92549, 0.219608, 0.094118, 1)  # Red
	if hostile_sees_friendly == expected_color:
		print("  PASS: Hostile perceives Friendly as Red")
	else:
		print("  FAIL: Hostile should perceive Friendly as Red")
