extends SceneTree

func _init():
	print("Checking MissionParser...")
	var script = load("res://addons/wcs_import/parsers/mission_parser.gd")
	if script:
		print("MissionParser loaded.")
		var parser = script.new()
		print("MissionParser instantiated.")
	else:
		print("Failed to load MissionParser.")
	quit()
