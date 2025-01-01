extends Node

# Active pilot and settings
var active_pilot: PilotData = null
var settings: GameSettings = null
var is_multiplayer: bool = false

func _ready() -> void:
	settings = GameSettings.load_or_create()

# Save active pilot and all related data
func save_active_pilot() -> bool:
	if active_pilot == null:
		return false
		
	# Create pilot directory if needed
	var pilot_dir = "user://pilots/%s" % active_pilot.callsign
	if not DirAccess.dir_exists_absolute(pilot_dir):
		DirAccess.make_dir_recursive_absolute(pilot_dir)
	
	# Save pilot data
	if ResourceSaver.save(active_pilot, "%s/pilot.tres" % pilot_dir) != OK:
		return false
	
	# Update last pilot info
	settings.last_pilot_callsign = active_pilot.callsign
	settings.last_pilot_was_multi = (active_pilot.flags & PilotData.PilotFlags.IS_MULTI) != 0
	return settings.save()

# Load pilot
func load_pilot(callsign: String) -> bool:
	var pilot_path = "user://pilots/%s/pilot.tres" % callsign
	if not ResourceLoader.exists(pilot_path):
		return false
		
	var pilot = ResourceLoader.load(pilot_path) as PilotData
	if pilot == null:
		return false
		
	active_pilot = pilot
	return true

# Try to load last used pilot
func try_load_last_pilot() -> bool:
	if settings.last_pilot_callsign.is_empty():
		return false
	return load_pilot(settings.last_pilot_callsign)

# Get list of all pilots
func get_all_pilots() -> Array[String]:
	var pilots: Array[String] = []
	
	# Ensure pilots directory exists
	var pilots_dir = "user://pilots"
	if not DirAccess.dir_exists_absolute(pilots_dir):
		DirAccess.make_dir_recursive_absolute(pilots_dir)
		return pilots
	
	# List pilot directories
	var dir = DirAccess.open(pilots_dir)
	if dir != null:
		dir.list_dir_begin()
		var dir_name = dir.get_next()
		while dir_name != "":
			if dir.current_is_dir() and ResourceLoader.exists("%s/%s/pilot.tres" % [pilots_dir, dir_name]):
				pilots.append(dir_name)
			dir_name = dir.get_next()
	
	return pilots

# Delete pilot and associated files
func delete_pilot(callsign: String) -> bool:
	var pilot_dir = "user://pilots/%s" % callsign
	
	# Delete pilot directory and all contents
	var dir = DirAccess.open(pilot_dir)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Remove directory
	if DirAccess.remove_absolute(pilot_dir) != OK:
		return false
	
	# Clear last pilot if this was it
	if callsign == settings.last_pilot_callsign:
		settings.last_pilot_callsign = ""
		settings.last_pilot_was_multi = false
		settings.save()
	
	return true

# Show a tip to the pilot if appropriate
func show_pilot_tip() -> void:
	if active_pilot == null or not active_pilot.show_tips:
		return
		
	# Load available tips
	var tips_res = load("res://resources/pilot_tips.tres") as PilotTips
	if tips_res == null:
		return
		
	# Find an unshown tip
	for tip in tips_res.tips:
		if not tip in active_pilot.tips_shown:
			# Show tip dialog
			var dialog = AcceptDialog.new()
			dialog.title = "Pilot Tip"
			dialog.dialog_text = tip
			dialog.add_button("Don't Show Tips", true, "disable_tips")
			dialog.custom_action.connect(func(action):
				if action == "disable_tips":
					active_pilot.show_tips = false
					save_active_pilot()
			)
			dialog.confirmed.connect(func():
				active_pilot.tips_shown.append(tip)
				save_active_pilot()
			)
			
			# Add to current scene
			var root = get_tree().get_root()
			if root.get_child_count() > 0:
				var current_scene = root.get_child(root.get_child_count() - 1)
				current_scene.add_child(dialog)
				dialog.popup_centered()
			break
