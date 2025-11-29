extends SceneTree

func _init():
	print("Testing load of species_parser.gd")
	var script = load("res://addons/wcs_import/parsers/species_parser.gd")
	if script:
		print("Loaded successfully")
	else:
		print("Failed to load")
	quit()
