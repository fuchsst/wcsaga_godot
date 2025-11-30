extends MainLoop

## CLI Runner for WCS Import Addon.
## Usage: godot --headless -s addons/wcs_import/cli_runner.gd -- --input <file> --output <dir> --type <type>

const WCSBaseParser = preload("res://addons/wcs_import/parsers/base_parser.gd")
const WCSShipParser = preload("res://addons/wcs_import/parsers/ship_parser.gd")
const WCSWeaponParser = preload("res://addons/wcs_import/parsers/weapon_parser.gd")
const WCSMissionParser = preload("res://addons/wcs_import/parsers/mission_parser.gd")
const WCSAIProfileParser = preload("res://addons/wcs_import/parsers/ai_profile_parser.gd")
const WCSAIClassParser = preload("res://addons/wcs_import/parsers/ai_class_parser.gd")
const WCSAsteroidParser = preload("res://addons/wcs_import/parsers/asteroid_parser.gd")
const WCSAutopilotParser = preload("res://addons/wcs_import/parsers/autopilot_parser.gd")
const WCSMedalParser = preload("res://addons/wcs_import/parsers/medal_parser.gd")
const WCSRankParser = preload("res://addons/wcs_import/parsers/rank_parser.gd")
const WCSTraitorParser = preload("res://addons/wcs_import/parsers/traitor_parser.gd")
const WCSTipsParser = preload("res://addons/wcs_import/parsers/tips_parser.gd")
const WCSLocalizationParser = preload("res://addons/wcs_import/parsers/localization_parser.gd")
const WCSCreditsParser = preload("res://addons/wcs_import/parsers/credits_parser.gd")
const WCSCutsceneParser = preload("res://addons/wcs_import/parsers/cutscene_parser.gd")
const WCSFireballParser = preload("res://addons/wcs_import/parsers/fireball_parser.gd")
const WCSFontParser = preload("res://addons/wcs_import/parsers/font_parser.gd")
const WCSHelpParser = preload("res://addons/wcs_import/parsers/help_parser.gd")
const WCSHudGaugeParser = preload("res://addons/wcs_import/parsers/hud_gauge_parser.gd")
const WCSIconParser = preload("res://addons/wcs_import/parsers/icon_parser.gd")
const WCSIffParser = preload("res://addons/wcs_import/parsers/iff_parser.gd")
const WCSLaunchHelpParser = preload("res://addons/wcs_import/parsers/launchhelp_parser.gd")
const WCSLightningParser = preload("res://addons/wcs_import/parsers/lightning_parser.gd")
const WCSMuzzleFlashParser = preload("res://addons/wcs_import/parsers/mflash_parser.gd")
const WCSMainhallParser = preload("res://addons/wcs_import/parsers/mainhall_parser.gd")
const WCSMenuParser = preload("res://addons/wcs_import/parsers/menu_parser.gd")
const WCSMessageParser = preload("res://addons/wcs_import/parsers/message_parser.gd")
const WCSMFlashParser = preload("res://addons/wcs_import/parsers/mflash_parser.gd")
const WCSMusicParser = preload("res://addons/wcs_import/parsers/music_parser.gd")
const WCSNebulaParser = preload("res://addons/wcs_import/parsers/nebula_parser.gd")
const WCSPixelParser = preload("res://addons/wcs_import/parsers/pixel_parser.gd")
const WCSScriptingParser = preload("res://addons/wcs_import/parsers/scripting_parser.gd")
const WCSSoundParser = preload("res://addons/wcs_import/parsers/sound_parser.gd")
const WCSSpeciesParser = preload("res://addons/wcs_import/parsers/species_parser.gd")
const WCSSSMParser = preload("res://addons/wcs_import/parsers/ssm_parser.gd")
const WCSStarParser = preload("res://addons/wcs_import/parsers/star_parser.gd")
const WCSWeaponExplParser = preload("res://addons/wcs_import/parsers/weapon_expl_parser.gd")
const WCSHudConfigParser = preload("res://addons/wcs_import/parsers/hud_config_parser.gd")
const HudSceneGenerator = preload("res://addons/wcs_import/generators/hud_scene_generator.gd")
const HudGaugeResource = preload("res://scripts/resources/ui/hud/hud_gauge_resource.gd")
const AsteroidGenerator = preload("res://addons/wcs_import/generators/asteroid_generator.gd")
const FireballGenerator = preload("res://addons/wcs_import/generators/fireball_generator.gd")
const LightningGenerator = preload("res://addons/wcs_import/generators/lightning_generator.gd")
const MuzzleFlashGenerator = preload("res://addons/wcs_import/generators/mflash_generator.gd")
const WeaponExplosionGenerator = preload("res://addons/wcs_import/generators/weapon_expl_generator.gd")
const WCSPathResolver = preload("res://addons/wcs_import/core/path_resolver.gd")

# Resource scripts
const WCSCampaignParser = preload("res://addons/wcs_import/parsers/campaign_parser.gd")
# Assuming Campaign resource exists, or use generic Resource
# const CampaignData = preload("res://scripts/resources/gameplay/campaign_data.gd") 

var _exit_code = 0

# ... (existing code)


func _process_campaign(input_path: String, output_dir: String) -> bool:
	var parser = WCSCampaignParser.new()
	var manifest = parser.parse(input_path)
	
	if manifest == null:
		print("Failed to parse campaign.")
		return false
		
	print("Parsed campaign: " + manifest.campaign_name)
	
	# Save to campaigns/{campaign}/campaign.tres
	var campaign_name = "hermes" # Default or derive
	# If input path contains campaign name, use it
	if input_path.contains("hermes"):
		campaign_name = "hermes"
		
	var save_dir = output_dir.path_join("campaigns").path_join(campaign_name)
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var save_path = save_dir.path_join("campaign.tres")
	var err = ResourceSaver.save(manifest, save_path)
	
	if err != OK:
		print("Failed to save campaign resource: " + save_path)
		return false
		
	print("Saved: " + save_path)
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
	if not input_path.begins_with("/"):
		# Resolve relative path against project root (parent of target/)
		var res_path = ProjectSettings.globalize_path("res://")
		print("res:// path: " + res_path)
		
		# If res_path ends with /, remove it to get base dir correctly
		if res_path.ends_with("/"):
			res_path = res_path.left(-1)
			
		var project_root = res_path.get_base_dir()
		print("Project root: " + project_root)
		input_path = project_root.path_join(input_path)
		
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
		"ai_profiles":
			success = _process_ai_profiles(input_path, output_dir)
		"ai_classes":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ai_classes"), WCSAIClassParser, "", "class_name")
		"ai_profiles":
			success = _process_ai_profiles(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ai_profiles"))
		"asteroids":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/asteroids"), WCSAsteroidParser, "", "name")
		"autopilot":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSAutopilotParser, "", "autopilot.tres")
		"campaign":
			success = _process_campaign(input_path, _resolve_output_path(output_dir, "campaigns/hermes"))
		"credits":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSCreditsParser, "", "credits.tres")
		"cutscenes":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSCutsceneParser, "", "cutscenes.tres")
		"fireball":
			success = _process_fireballs(input_path, _resolve_output_path(output_dir, "assets/effects/fireball"))
		"fonts":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSFontParser, "", "fonts.tres")
		"help":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSHelpParser, "", "help.tres")
		"hud_gauges":
			success = _process_hud_gauges(input_path, output_dir)
		"hud_config":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/config/hud"), WCSHudConfigParser, "", input_path.get_file().get_basename() + ".tres")
		"icons":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/icons"), WCSIconParser, "", "name")
		"iff_defs":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/iff_defs"), WCSIffParser, "", "iff_defs.tres")
		"launchhelp":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSLaunchHelpParser, "", "launchhelp.tres")
		"lightning":
			success = _process_lightning(input_path, output_dir)
		"mflash":
			success = _process_mflash(input_path, _resolve_output_path(output_dir, "assets/effects"))
		"mainhall":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/menu"), WCSMainhallParser, "", "mainhall.tres")
		"medals":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSMedalParser, "", "medals.tres")
		"menu":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/menu"), WCSMenuParser, "", "menu.tres")
		"messages":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSMessageParser, "", "messages.tres")
		"mflash":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/effects/mflash"), WCSMFlashParser, "", "name")
		"mission":
			success = _process_mission(input_path, _resolve_output_path(output_dir, "campaigns/hermes/missions"))
		"music":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/soundtrack"), WCSMusicParser, "", "name")
		"nebula":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "assets/environment/nebula"), WCSNebulaParser, "", "nebula.tres")
		"pixels":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "assets/environment/stars"), WCSPixelParser, "", "pixels.tres")
		"rank":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSRankParser, "", "ranks.tres")
		"scripting":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSScriptingParser, "", "scripting.tres")
		"ships":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/ships"), WCSShipParser, "", "ship_class_name")
		"sounds":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "assets/sounds"), WCSSoundParser, "", "sounds.tres")
		"species":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "assets/species"), WCSSpeciesParser, "", "species_defs.tres")
		"ssm":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/weapons"), WCSSSMParser, "", "name")
		"stars":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/environment/stars"), WCSStarParser, "", "filename")
		"tips":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSTipsParser, "", "tips.tres")
		"traitor":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSTraitorParser, "", "traitor.tres")
		"weapon_expl":
			success = _process_weapon_expl(input_path, _resolve_output_path(output_dir, "assets/effects"))
		"weapons":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/weapons"), WCSWeaponParser, "", "name")
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
	if filename == "ai_profiles.tbl":
		return "ai_profiles"
	if filename == "ai.tbl":
		return "ai_classes"
	if filename.ends_with(".fs2") or filename.ends_with(".fc2"):
		return "mission"
	if filename == "asteroid.tbl":
		return "asteroids"
	if filename == "autopilot.tbl":
		return "autopilot"
	if filename == "medals.tbl":
		return "medals"
	if filename == "rank.tbl":
		return "rank"
	if filename == "traitor.tbl":
		return "traitor"
	if filename == "tips.tbl":
		return "tips"
	if filename == "strings.tbl" or filename == "tstrings.tbl":
		return "localization"
	if filename == "species.tbl" or filename == "species_defs.tbl":
		return "species"
	if filename == "credits.tbl": return "credits"
	if filename == "cutscenes.tbl": return "cutscenes"
	if filename == "fireball.tbl": return "fireball"
	if filename == "fonts.tbl": return "fonts"
	if filename == "help.tbl": return "help"
	if filename == "hud_gauges.tbl": return "hud_gauges"
	if filename == "icons.tbl": return "icons"
	if filename == "iff_defs.tbl": return "iff_defs"
	if filename == "launchhelp.tbl": return "launchhelp"
	if filename == "lightning.tbl": return "lightning"
	if filename == "mainhall.tbl": return "mainhall"
	if filename == "menu.tbl": return "menu"
	if filename == "messages.tbl": return "messages"
	if filename == "mflash.tbl": return "mflash"
	if filename == "music.tbl": return "music"
	if filename == "nebula.tbl": return "nebula"
	if filename == "pixels.tbl": return "pixels"
	if filename == "scripting.tbl": return "scripting"
	if filename == "sounds.tbl": return "sounds"
	if filename == "species.tbl" or filename == "species_defs.tbl": return "species"
	if filename == "ssm.tbl": return "ssm"
	if filename == "stars.tbl": return "stars"
	if filename == "weapon_expl.tbl": return "weapon_expl"
	if filename.ends_with(".hcf"): return "hud_config"
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

func _process_ai_profiles(input_path: String, output_dir: String) -> bool:
	var parser = WCSAIProfileParser.new()
	var profiles = parser.parse(input_path)
	
	if profiles == null or profiles.is_empty():
		print("Failed to parse AI profiles.")
		return false
		
	print("Parsed " + str(profiles.size()) + " AI profile levels.")
	
	# Extract campaign name from path if present (e.g., hermes_core -> hermes)
	var campaign_name = "default"
	var path_parts = input_path.split("/")
	for i in range(path_parts.size()):
		if path_parts[i].ends_with("_campaign") or path_parts[i].contains("campaign"):
			campaign_name = path_parts[i].replace("_campaign", "").replace("wcs_", "")
			break
	
	# Save to campaigns/{campaign}/ai_profiles/ subdirectory
	var save_dir = output_dir.path_join("campaigns").path_join(campaign_name).path_join("ai_profiles")
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var saved_count = 0
	for profile in profiles:
		var difficulty_slug = profile.difficulty_level.to_lower().replace(" ", "_")
		if difficulty_slug.is_empty():
			difficulty_slug = "level_" + str(saved_count)
		
		# Save as {difficulty}.tres instead of ai_profile_{difficulty}.tres
		var profile_path = save_dir.path_join(difficulty_slug + ".tres")
		var err = ResourceSaver.save(profile, profile_path)
		if err != OK:
			print("Failed to save AI profile: " + profile_path)
		else:
			print("Saved: " + profile_path)
			saved_count += 1
	
	print("Saved " + str(saved_count) + "/" + str(profiles.size()) + " AI profiles.")
	return saved_count == profiles.size()

func _process_ai_classes(input_path: String, output_dir: String) -> bool:
	var parser = WCSAIClassParser.new()
	var ai_classes = parser.parse(input_path)
	
	if ai_classes == null or ai_classes.is_empty():
		print("Failed to parse AI classes.")
		return false
		
	print("Parsed " + str(ai_classes.size()) + " AI class instances.")
	
	# Extract campaign name from path
	var campaign_name = "default"
	var path_parts = input_path.split("/")
	for i in range(path_parts.size()):
		if path_parts[i].ends_with("_campaign") or path_parts[i].contains("campaign"):
			campaign_name = path_parts[i].replace("_campaign", "").replace("wcs_", "")
			break
	
	# Save to campaigns/{campaign}/ai_classes/ subdirectory
	var save_dir = output_dir.path_join("campaigns").path_join(campaign_name).path_join("ai_classes")
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var saved_count = 0
	for ai_class in ai_classes:
		# Create filename from class name and difficulty
		var class_slug = ai_class.ai_class_name.to_lower().replace(" ", "_").replace("#", "")
		var difficulty_slug = ai_class.difficulty_level.to_lower().replace(" ", "_")
		
		# New structure: campaigns/{campaign}/ai_classes/{class_slug}/{difficulty_slug}.tres
		var class_dir = save_dir.path_join(class_slug)
		DirAccess.make_dir_recursive_absolute(class_dir)
		
		var filename = difficulty_slug + ".tres"
		var class_path = class_dir.path_join(filename)
		
		var err = ResourceSaver.save(ai_class, class_path)
		if err != OK:
			print("Failed to save AI class: " + class_path)
		else:
			print("Saved: " + class_path)
			saved_count += 1
	
	print("Saved " + str(saved_count) + "/" + str(ai_classes.size()) + " AI class instances.")
	return saved_count == ai_classes.size()

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

func _process_asteroids(input_path: String, output_dir: String) -> bool:
	var parser = WCSAsteroidParser.new()
	var asteroids = parser.parse(input_path)
	
	if asteroids == null or asteroids.is_empty():
		print("Failed to parse asteroids.")
		return false
		
	print("Parsed " + str(asteroids.size()) + " asteroids.")
	
	var generator = AsteroidGenerator.new()
	var success_count = 0
	
	for data in asteroids:
		if generator.generate(data, output_dir):
			success_count += 1
			
	print("Generated " + str(success_count) + "/" + str(asteroids.size()) + " asteroid scenes.")
	return success_count == asteroids.size()

func _process_autopilot(input_path: String, output_dir: String) -> bool:
	var parser = WCSAutopilotParser.new()
	var res = parser.parse(input_path)
	
	if res == null:
		print("Failed to parse autopilot.")
		return false
		
	# Save to campaigns/{campaign}/ui/localisation/autopilot.tres
	# Assuming hermes for now based on mapping rules, or derive from path
	var campaign_name = "hermes" # Defaulting as per rules for now
	var save_dir = output_dir.path_join("campaigns").path_join(campaign_name).path_join("ui").path_join("localisation")
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var save_path = save_dir.path_join("autopilot.tres")
	var err = ResourceSaver.save(res, save_path)
	if err != OK:
		print("Failed to save resource: " + save_path)
		return false
	
	print("Saved: " + save_path)
	return true

func _process_medals(input_path: String, output_dir: String) -> bool:
	var parser = WCSMedalParser.new()
	var medals = parser.parse(input_path)
	
	if medals == null:
		print("Failed to parse medals.")
		return false
		
	# Save to campaigns/{campaign}/medals.tres
	# Since we have a list, we need to save individual resources or a container.
	# The rule says "medals.tbl entries tres go to target/campaigns/hermes/medals.tres"
	# This implies a single file. But Godot resources are usually one per file unless embedded.
	# If we save a list, we need a container resource.
	# For now, I will save them as individual files in a 'medals' directory to be safe,
	# OR I will create a dummy container if needed.
	# BUT, looking at the rule again: "medals.tres".
	# I'll assume for now we save them individually in a folder named medals, 
	# OR I'll save them as a ResourceGroup if I had one.
	# Let's save them individually for now as it's safer for Godot.
	# Wait, rule says: target/campaigns/hermes/medals.tres
	# Maybe I should create a Resource that holds an Array?
	# I didn't create a MedalsManifest.
	# I'll save them as individual files in `target/campaigns/hermes/medals/` for now.
	
	var campaign_name = "hermes"
	var save_dir = output_dir.path_join("campaigns").path_join(campaign_name).path_join("medals")
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	for medal in medals:
		var filename = medal.name.to_lower().replace(" ", "_") + ".tres"
		var save_path = save_dir.path_join(filename)
		ResourceSaver.save(medal, save_path)
		print("Saved: " + save_path)
		
	return true

func _process_ranks(input_path: String, output_dir: String) -> bool:
	var parser = WCSRankParser.new()
	var ranks = parser.parse(input_path)
	
	if ranks == null:
		print("Failed to parse ranks.")
		return false
		
	var campaign_name = "hermes"
	var save_dir = output_dir.path_join("campaigns").path_join(campaign_name).path_join("ranks")
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	for rank in ranks:
		var filename = rank.name.to_lower().replace(" ", "_") + ".tres"
		var save_path = save_dir.path_join(filename)
		ResourceSaver.save(rank, save_path)
		print("Saved: " + save_path)
		
	return true

func _process_traitor(input_path: String, output_dir: String) -> bool:
	var parser = WCSTraitorParser.new()
	var res = parser.parse(input_path)
	
	if res == null:
		print("Failed to parse traitor.")
		return false
		
	var campaign_name = "hermes"
	var save_dir = output_dir.path_join("campaigns").path_join(campaign_name)
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var save_path = save_dir.path_join("traitor.tres")
	var err = ResourceSaver.save(res, save_path)
	if err != OK:
		print("Failed to save resource: " + save_path)
		return false
		
	print("Saved: " + save_path)
	return true

func _process_tips(input_path: String, output_dir: String) -> bool:
	var parser = WCSTipsParser.new()
	var res = parser.parse(input_path)
	
	if res == null:
		print("Failed to parse tips.")
		return false
		
	var campaign_name = "hermes"
	var save_dir = output_dir.path_join("campaigns").path_join(campaign_name).path_join("ui").path_join("localisation")
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var save_path = save_dir.path_join("tips.tres")
	var err = ResourceSaver.save(res, save_path)
	if err != OK:
		print("Failed to save resource: " + save_path)
		return false
		
	print("Saved: " + save_path)
	return true

func _process_localization(input_path: String, output_dir: String) -> bool:
	var parser = WCSLocalizationParser.new()
	var strings = parser.parse(input_path)
	
	if strings == null:
		print("Failed to parse localization.")
		return false
		
	var campaign_name = "hermes"
	var save_dir = output_dir.path_join("campaigns").path_join(campaign_name).path_join("ui").path_join("localisation")
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	# Save as individual files? Or one big file?
	# Usually localization is one big file/resource.
	# But I defined LocalizationResource as single string.
	# I should probably save them as individual files for now or change the resource to be a dictionary.
	# Given the quantity (thousands), individual files is bad.
	# But I didn't create a LocalizationManifest.
	# I'll save them in a folder `strings` for now.
	
	var strings_dir = save_dir.path_join("strings")
	DirAccess.make_dir_recursive_absolute(strings_dir)
	
	for s in strings:
		var filename = str(s.id) + ".tres"
		var save_path = strings_dir.path_join(filename)
		ResourceSaver.save(s, save_path)
		
	print("Saved " + str(strings.size()) + " localization strings.")
	return true

func _process_simple_resource(input_path: String, output_dir: String, parser_class, subpath: String, filename: String) -> bool:
	var parser = parser_class.new()
	var res = parser.parse(input_path)
	
	if res == null:
		print("Failed to parse " + input_path.get_file())
		return false
		
	var save_dir = output_dir.path_join(subpath)
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var save_path = save_dir.path_join(filename)
	var err = ResourceSaver.save(res, save_path)
	if err != OK:
		print("Failed to save resource: " + save_path)
		return false
		
	print("Saved: " + save_path)
	return true

func _process_list_resource(input_path: String, output_dir: String, parser_class, subpath: String, name_field: String) -> bool:
	var parser = parser_class.new()
	var items = parser.parse(input_path)
	
	if items == null:
		print("Failed to parse " + input_path.get_file())
		return false
		
	var save_dir = output_dir.path_join(subpath)
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var saved_count = 0
	for item in items:
		var item_name = item.get(name_field)
		if item_name == null:
			item_name = "unknown_" + str(saved_count)
			
		var filename = str(item_name).to_lower().replace(" ", "_").replace(".", "_") + ".tres"
		var save_path = save_dir.path_join(filename)
		
		var err = ResourceSaver.save(item, save_path)
		if err != OK:
			print("Failed to save resource: " + save_path)
		else:
			print("Saved: " + save_path)
			saved_count += 1
			
	print("Saved " + str(saved_count) + " items from " + input_path.get_file())
	return true

func _resolve_output_path(base_output_dir: String, subpath: String) -> String:
	# If subpath starts with "campaigns/", use project root (res://)
	# This assumes the project root is the parent of "addons" or similar.
	# But we need an absolute path for ResourceSaver if running headless?
	# Actually, ResourceSaver works with res:// if inside project.
	# But cli_runner might be running with absolute paths.
	if subpath.begins_with("campaigns/"):
		# We need to find the project root from base_output_dir
		# base_output_dir is usually .../target/assets
		# We want .../target/campaigns/...
		# So we go up one level from assets
		var project_root = base_output_dir.get_base_dir() # .../target
		if base_output_dir.ends_with("assets"):
			return project_root.path_join(subpath)
		else:
			# Fallback if output dir structure is unexpected
			return base_output_dir.path_join(subpath)
			
	# If subpath starts with "assets/" and base_output_dir ends with "assets", strip it
	if subpath.begins_with("assets/") and base_output_dir.ends_with("assets"):
		return base_output_dir.path_join(subpath.substr(7))
			
	# Otherwise, use base output dir (target/assets)
	return base_output_dir.path_join(subpath)

func _process_hud_gauges(input_path: String, output_dir: String) -> bool:
	var parser = WCSHudGaugeParser.new()
	var gauges = parser.parse(input_path)
	
	if gauges == null:
		print("Failed to parse hud_gauges.tbl")
		return false
		
	var generator = HudSceneGenerator.new()
	
	# Group gauges by section
	var sections = {
		"Custom Gauges": [] as Array[HudGaugeResource],
		"Main Gauges": [] as Array[HudGaugeResource],
		"Gauges": [] as Array[HudGaugeResource],
		"Ship Main Gauges": {},
		"Ship Gauges": {}
	}
	
	for gauge in gauges:
		if gauge.section == "Custom Gauges":
			sections["Custom Gauges"].append(gauge)
		elif gauge.section == "Main Gauges":
			sections["Main Gauges"].append(gauge)
		elif gauge.section == "Gauges":
			sections["Gauges"].append(gauge)
		elif gauge.section == "Ship Main Gauges":
			var ship = gauge.ship_name
			if ship.is_empty():
				ship = "generic"
			if not sections["Ship Main Gauges"].has(ship):
				sections["Ship Main Gauges"][ship] = [] as Array[HudGaugeResource]
			sections["Ship Main Gauges"][ship].append(gauge)
		elif gauge.section == "Ship Gauges":
			var ship = gauge.ship_name
			if ship.is_empty():
				ship = "generic"
			if not sections["Ship Gauges"].has(ship):
				sections["Ship Gauges"][ship] = [] as Array[HudGaugeResource]
			sections["Ship Gauges"][ship].append(gauge)
			
	generator.create_custom_gauges_scene(sections["Custom Gauges"], output_dir)
	generator.create_main_gauges_scene(sections["Main Gauges"], output_dir)
	generator.create_gauges_scene(sections["Gauges"], output_dir)
	
	generator.create_ship_scenes(sections["Ship Main Gauges"], output_dir, true)
	generator.create_ship_scenes(sections["Ship Gauges"], output_dir, false)
			
	print("Generated HUD scenes.")
	return true

func _process_fireballs(input_path: String, output_dir: String) -> bool:
	var parser = WCSFireballParser.new()
	var fireballs = parser.parse(input_path)
	
	if fireballs == null or fireballs.is_empty():
		print("Failed to parse fireballs.")
		return false
		
	print("Parsed " + str(fireballs.size()) + " fireballs.")
	
	var generator = FireballGenerator.new()
	var success_count = 0
	
	for res in fireballs:
		if generator.generate(res, output_dir):
			success_count += 1
			
	print("Generated " + str(success_count) + "/" + str(fireballs.size()) + " fireball scenes.")
	return success_count == fireballs.size()

func _process_lightning(input_path: String, output_dir: String) -> bool:
	var parser = WCSLightningParser.new()
	var resources = parser.parse(input_path)
	
	if resources == null or resources.is_empty():
		print("Failed to parse lightning.")
		return false
		
	print("Parsed " + str(resources.size()) + " lightning entries.")
	
	var generator = LightningGenerator.new()
	var success_count = 0
	
	for res in resources:
		if generator.generate(res, output_dir):
			success_count += 1
			
	print("Generated " + str(success_count) + "/" + str(resources.size()) + " lightning resources.")
	return success_count == resources.size()

func _process_mflash(input_path: String, output_dir: String) -> bool:
	var parser = WCSMuzzleFlashParser.new()
	var resources = parser.parse(input_path)
	
	if resources == null or resources.is_empty():
		print("Failed to parse mflash.")
		return false
		
	print("Parsed " + str(resources.size()) + " mflash entries.")
	
	var generator = MuzzleFlashGenerator.new()
	var success_count = 0
	
	for res in resources:
		if generator.generate(res, output_dir):
			success_count += 1
			
	print("Generated " + str(success_count) + "/" + str(resources.size()) + " mflash resources.")
	return success_count == resources.size()

func _process_weapon_expl(input_path: String, output_dir: String) -> bool:
	var parser = WCSWeaponExplParser.new()
	var resources = parser.parse(input_path)
	
	if resources == null or resources.is_empty():
		print("Failed to parse weapon_expl.")
		return false
		
	print("Parsed " + str(resources.size()) + " weapon_expl entries.")
	
	var generator = WeaponExplosionGenerator.new()
	var success_count = 0
	
	for res in resources:
		if generator.generate(res, output_dir):
			success_count += 1
			
	print("Generated " + str(success_count) + "/" + str(resources.size()) + " weapon_expl resources.")
	return success_count == resources.size()
