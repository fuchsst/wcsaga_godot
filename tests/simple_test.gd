extends SceneTree

func _init():
	print("Simple test: trying WCSMissionParser.new()")
	var parser = WCSMissionParser.new()
	if parser:
		print("SUCCESS: MissionParser instantiated!")
	else:
		print("FAILED: Could not instantiate MissionParser")
	quit()
