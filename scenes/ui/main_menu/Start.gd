extends Control

# Start.gd
# Bootstrapper for the application

func _ready():
	# Intro Placeholder
	print("Starting Intro Sequence...")
	await get_tree().create_timer(2.0).timeout # Simulate 2s intro logo
	print("Intro Finished. Loading Main Menu...")
	# Transition using SceneManager
	# The user requested using the addon. Assumes "SceneManager" is an autoload.
	var main_scene_path = "res://scenes/ui/main_menu/TimelineMain.tscn"
	if has_node("/root/SceneManager"):
		var scene_manager = get_node("/root/SceneManager")
		await scene_manager.change_scene(main_scene_path, {"pattern": "fade", "speed": 1.0})
	else:
		if ResourceLoader.exists(main_scene_path):
			get_tree().change_scene_to_file(main_scene_path)
		else:
			printerr("TimelineMain scene not found at: " + main_scene_path)
