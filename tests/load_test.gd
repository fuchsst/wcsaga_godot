extends SceneTree

func _init():
	print("Loading MissionParser script...")
	var script_path = "res://addons/wcs_import/parsers/mission_parser.gd"
	var script = load(script_path)
	
	if script == null:
		print("ERROR: Could not load script at all")
		quit(1)
		return
	
	if script is GDScript:
		print("Script loaded as GDScript")
		print("Checking if it has errors...")
		if script.is_tool():
			print("Script is marked as tool")
		
		# Try to instantiate
		print("Attempting to call new()...")
		var instance = script.new()
		if instance:
			print("SUCCESS!")
		else:
			print("FAILED: new() returned null")
	else:
		print("ERROR: Loaded resource is not a GDScript")
	
	quit()
