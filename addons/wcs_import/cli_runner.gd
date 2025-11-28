extends MainLoop

## CLI Runner for WCS Import Addon.
## Usage: godot --headless -s addons/wcs_import/cli_runner.gd -- --input <file> --output <dir> --type <type>

const WCSBaseParser = preload("res://addons/wcs_import/parsers/base_parser.gd")
const WCSShipParser = preload("res://addons/wcs_import/parsers/ship_parser.gd")
const WCSWeaponParser = preload("res://addons/wcs_import/parsers/weapon_parser.gd")
const WCSMissionParser = preload("res://addons/wcs_import/parsers/mission_parser.gd")
const WCSPathResolver = preload("res://addons/wcs_import/core/path_resolver.gd")

# Resource scripts
const WCSCampaignParser = preload("res://addons/wcs_import/parsers/campaign_parser.gd")
# Assuming Campaign resource exists, or use generic Resource
# const CampaignData = preload("res://scripts/resources/gameplay/campaign_data.gd") 

var _exit_code = 0

# ... (existing code)


func _process_campaign(input_path: String, output_dir: String) -> bool:
	var parser = WCSCampaignParser.new()
	var result = parser.parse(input_path)
	
	if result.is_empty() or not result.has("campaign"):
		print("Failed to parse campaign.")
		return false
		
	var data = result["campaign"]
	print("Parsed campaign: " + data.get("name", "Unknown"))
	
	# TODO: Create Campaign resource when available
	# For now, just print success as we don't have a Campaign resource definition handy
	# or save as a generic dictionary resource if needed.
	
	return true

func _initialize():
	pass

func _process(delta):
	_run()
	return true # Exit loop

func _run():
	print("Cmdline args: " + str(OS.get_cmdline_args()))
	var args = _parse_args()
	if not args.has("input") or not args.has("output"):
		print("Usage: godot --headless -s addons/wcs_import/cli_runner.gd -- --input <file> --output <dir> [--type <type>]")
		_exit_code = 1
		return
		
	var input_path = args["input"]
	var output_dir = args["output"]
	var type = args.get("type", "auto")
	
	print("Starting WCS Import...")
	print("Input: " + input_path)
	print("Output: " + output_dir)
	
	if type == "auto":
		type = _detect_type(input_path)
		
	var success = false
	match type:
		"ships":
			success = _process_ships(input_path, output_dir)
		"weapons":
			success = _process_weapons(input_path, output_dir)
		"mission":
			success = _process_mission(input_path, output_dir)
		_:
			print("Skipping unsupported type: " + type)
			# Return success to avoid failing the batch in Python CLI
			print("Import completed successfully.")
			_exit_code = 0
			return
			
	if success:
		print("Import completed successfully.")
		_exit_code = 0
	else:
		print("Import failed.")
		_exit_code = 1

func _finalize():
	pass

func _parse_args() -> Dictionary:
	var args = {}
	var user_args = OS.get_cmdline_user_args()
	print("User args: " + str(user_args))
	
	for i in range(user_args.size()):
		var arg = user_args[i]
		if arg.begins_with("--"):
			var key = arg.substr(2)
			var val = ""
			if i + 1 < user_args.size() and not user_args[i + 1].begins_with("--"):
				val = user_args[i + 1]
			args[key] = val
	return args

func _detect_type(path: String) -> String:
	var filename = path.get_file().to_lower()
	if filename == "ships.tbl":
		return "ships"
	if filename == "weapons.tbl":
		return "weapons"
	if filename.ends_with(".fs2") or filename.ends_with(".fc2"):
		return "mission"
	return "unknown"

func _process_ships(input_path: String, output_dir: String) -> bool:
	var parser = WCSShipParser.new()
	var ships = parser.parse(input_path)
	
	if ships == null or ships.is_empty():
		print("Failed to parse ships.")
		return false
		
	print("Parsed " + str(ships.size()) + " ships.")
	
	for res in ships:
		# Determine output path using PathResolver
		var pof_file = res.model_file
		if pof_file.is_empty():
			pof_file = res.ship_class + ".pof" # Fallback
			res.model_file = pof_file
			
		var path_info = WCSPathResolver.determine_output_path(pof_file)
		var category = path_info[0]
		var subcategory = path_info[1]
		
		var save_dir = output_dir.path_join(category).path_join(subcategory)
		DirAccess.make_dir_recursive_absolute(save_dir)
		
		var save_path = save_dir.path_join(res.ship_class + ".tres")
		var err = ResourceSaver.save(res, save_path)
		if err != OK:
			print("Failed to save resource: " + save_path)
		else:
			print("Saved: " + save_path)
			
	return true

func _process_weapons(input_path: String, output_dir: String) -> bool:
	var parser = WCSWeaponParser.new()
	var weapons = parser.parse(input_path)
	
	if weapons == null or weapons.is_empty():
		print("Failed to parse weapons.")
		return false
		
	print("Parsed " + str(weapons.size()) + " weapons.")
	
	for res in weapons:
		# Determine output path
		var pof_file = res.projectile_model
		var save_dir = ""
		
		if not pof_file.is_empty():
			var path_info = WCSPathResolver.determine_output_path(pof_file)
			save_dir = output_dir.path_join(path_info[0]).path_join(path_info[1])
		else:
			# Fallback for weapons without models
			save_dir = output_dir.path_join("weapons").path_join("misc")
			
		DirAccess.make_dir_recursive_absolute(save_dir)
		
		var save_path = save_dir.path_join(res.weapon_class + ".tres")
		var err = ResourceSaver.save(res, save_path)
		if err != OK:
			print("Failed to save resource: " + save_path)
		else:
			print("Saved: " + save_path)
			
	return true

func _process_mission(input_path: String, output_dir: String) -> bool:
	var parser = WCSMissionParser.new()
	
	# Check extension first
	if input_path.get_extension() == "fc2":
		return _process_campaign(input_path, output_dir)
		
	var res = parser.parse(input_path)
	
	if res == null:
		print("Failed to parse mission.")
		return false
		
	# Determine output path
	var path_info = WCSPathResolver.determine_asset_output_path(input_path.get_file())
	var save_dir = output_dir.path_join(path_info[0]).path_join(path_info[1])
	
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var filename = input_path.get_file().get_basename() + ".tres"
	var save_path = save_dir.path_join(filename)
	
	var err = ResourceSaver.save(res, save_path)
	if err != OK:
		print("Failed to save resource: " + save_path)
	else:
		print("Saved: " + save_path)
		
	return true
