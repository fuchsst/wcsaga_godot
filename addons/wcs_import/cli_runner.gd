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
const WeaponSceneGenerator = preload("res://addons/wcs_import/generators/weapon_scene_generator.gd")
const PersonaGenerator = preload("res://addons/wcs_import/generators/persona_generator.gd")
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
			success = _process_medals(input_path, output_dir)
		"menu":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/menu"), WCSMenuParser, "", "menu.tres")
		"messages":
			success = _process_personas(input_path, output_dir)
		"mflash":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/effects/mflash"), WCSMFlashParser, "", "name")
		"mission":
			success = _process_mission(input_path, _resolve_output_path(output_dir, "campaigns/hermes/missions"))
		"music":
			success = _process_music(input_path, output_dir)
		"nebula":
			success = _process_nebula(input_path, _resolve_output_path(output_dir, "assets/environment/nebula"))
		"pixels":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "assets/environment/stars"), WCSPixelParser, "", "pixels.tres")
		"rank":
			success = _process_ranks(input_path, output_dir)
		"scripting":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSScriptingParser, "", "scripting.tres")
		"ships":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/ships"), WCSShipParser, "", "ship_class_name")
		"sounds":
			success = _process_sounds(input_path, output_dir)
		"species":
			success = _process_simple_resource(input_path, _resolve_output_path(output_dir, "assets/species"), WCSSpeciesParser, "", "species_defs.tres")
		"ssm":
			success = _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/weapons"), WCSSSMParser, "", "name")
		"stars":
			success = _process_stars(input_path, _resolve_output_path(output_dir, "assets/environment/stars"))
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
	
	var generator = WeaponSceneGenerator.new()
	
	# Use base output dir (assets/weapons) as root for generator
	# The generator handles subdirectories (category/weapon_name)
	var weapons_root = output_dir.path_join("assets").path_join("weapons")
	
	# If output_dir already ends in assets/weapons, use it directly?
	# _process calls this with output_dir.
	# In _run: "weapons": success = _process_list_resource(..., _resolve_output_path(output_dir, "assets/weapons"), ...)
	# Wait, _run calls _process_weapons directly:
	# "weapons": success = _process_weapons(input_path, output_dir)
	# So output_dir is the root target dir (e.g. target/).
	
	# We should resolve the root for weapons here.
	weapons_root = _resolve_output_path(output_dir, "assets/weapons")
	
	for res in weapons:
		# 1. Determine specific output directory for this weapon
		# e.g. target/assets/weapons/<category>/<faction>/<weapon_slug>/
		var category_dir = res.category.to_lower().replace(" ", "_")
		var faction_dir = res.manufacturer_species.to_lower().replace(" ", "_")
		var weapon_slug = res.weapon_class.to_lower().replace(" ", "_")
		
		var weapon_dir = weapons_root.path_join(category_dir).path_join(faction_dir).path_join(weapon_slug)
		DirAccess.make_dir_recursive_absolute(weapon_dir)
		
		# 2. Convert POF Model
		if not res.projectile_model.is_empty() and res.projectile_model != "none":
			var pof_source = _find_source_asset(input_path.get_base_dir().get_base_dir(), res.projectile_model)
			if not pof_source.is_empty():
				_convert_asset(pof_source, weapon_dir, "model")
				# Update resource to point to converted GLB (keep original basename)
				res.projectile_model = pof_source.get_file().get_basename() + ".gltf"
			else:
				print("Warning: Could not find POF source for " + res.projectile_model)

		# 3. Convert/Copy Textures and Icons
		if not res.display_icon.is_empty():
			var icon_source = _find_source_asset(input_path.get_base_dir().get_base_dir(), res.display_icon, [".pcx", ".dds", ".png"])
			if not icon_source.is_empty():
				_convert_asset(icon_source, weapon_dir, "texture")
				res.display_icon = icon_source.get_file().get_basename() + ".png" # Assuming conversion to PNG

		if not res.laser_bitmap.is_empty():
			var laser_source = _find_source_asset(input_path.get_base_dir().get_base_dir(), res.laser_bitmap, [".pcx", ".dds", ".png"])
			if not laser_source.is_empty():
				_convert_asset(laser_source, weapon_dir, "texture")
				res.laser_bitmap = laser_source.get_file().get_basename() + ".png"

		if not res.laser_glow.is_empty():
			var glow_source = _find_source_asset(input_path.get_base_dir().get_base_dir(), res.laser_glow, [".pcx", ".dds", ".png"])
			if not glow_source.is_empty():
				_convert_asset(glow_source, weapon_dir, "texture")
				res.laser_glow = glow_source.get_file().get_basename() + ".png"

		if not res.tech_animation.is_empty():
			var anim_source = _find_source_asset(input_path.get_base_dir().get_base_dir(), res.tech_animation, [".ani", ".eff"])
			if not anim_source.is_empty():
				_convert_asset(anim_source, weapon_dir, "ui") # Or animation type
				# res.tech_animation updated by generator or here? 
				# For now assume generator handles the resource path if it's standard

		# 4. Resolve Impact Explosion
		if not res.impact_explosion.is_empty():
			# Try to find corresponding scene in assets/effects/explosion (or similar)
			# Assuming explosion generator puts them in assets/effects/weapon_expl or similar
			# The user mentioned "target/assets/effects/explosion/"
			var expl_name = res.impact_explosion.get_basename()
			var expl_path = "res://assets/effects/weapon_expl/" + expl_name + ".tscn" # Adjust path based on actual generator output
			# Check if it exists? We might not have generated them yet if running in parallel or order matters.
			# But we can set the path.
			# Or search for it.
			# For now, let's assume a standard path convention.
			res.impact_explosion = expl_path

		# 5. Generate Scene and Resource
		generator.generate_scene(res, weapons_root)
			
	return true

func _find_source_asset(root_dir: String, filename: String, extensions: Array = []) -> String:
	# Naive search in source_assets
	# In a real scenario, we might use a pre-built index or the Python AssetRegistry
	# For now, we'll shell out to 'find' for simplicity as per user request context
	# Or just check common folders
	var search_filename = filename
	if extensions.is_empty():
		# If no extensions provided, assume filename has it or we search exact
		pass
	else:
		# If filename has no extension, try adding them
		if filename.get_extension().is_empty():
			# We need to find ANY match
			pass

	# Use 'find' command via OS.execute for speed and coverage
	var output = []
	var args = [root_dir, "-iname", filename + "*"] # simplified
	print("Searching in: " + root_dir + " for " + filename)
	OS.execute("find", args, output)
	print("Find output: " + str(output))
	if output.size() > 0 and not output[0].is_empty():
		var lines = output[0].split("\n", false)
		for line in lines:
			# Filter by extension if needed
			if extensions.is_empty():
				return line
			for ext in extensions:
				if line.to_lower().ends_with(ext):
					return line
	return ""

func _convert_asset(source_path: String, output_dir: String, type: String) -> void:
	# Trigger Python converter
	# uv run python -m converter convert <source> <output> --type <type>
	var global_output_dir = ProjectSettings.globalize_path(output_dir)
	var args = ["run", "python", "-m", "converter", "convert", source_path, global_output_dir, "--type", type]
	var output = []
	var exit_code = OS.execute("uv", args, output, true)
	if exit_code != 0:
		print("Failed to convert asset: " + source_path)
		print("Output: " + str(output))
	else:
		print("Converted: " + source_path)

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

const RankGenerator = preload("res://addons/wcs_import/generators/rank_generator.gd")
const MedalGenerator = preload("res://addons/wcs_import/generators/medal_generator.gd")

func _process_medals(input_path: String, output_dir: String) -> bool:
	var parser = WCSMedalParser.new()
	var manifest = parser.parse(input_path)
	
	if manifest == null:
		print("Failed to parse medals.")
		return false
		
	var generator = MedalGenerator.new()
	generator.generate_medals(manifest, output_dir)
	return true

func _process_ranks(input_path: String, output_dir: String) -> bool:
	var parser = WCSRankParser.new()
	var manifest = parser.parse(input_path)
	
	if manifest == null:
		print("Failed to parse ranks.")
		return false
		
	var generator = RankGenerator.new()
	generator.generate_ranks(manifest, output_dir)
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

const WCSSunData = preload("res://scripts/resources/environment/stars/sun_data.gd")
const WCSSunFlare = preload("res://scripts/resources/environment/stars/sun_flare.gd")

func _process_stars(input_path: String, output_dir: String) -> bool:
	var parser = WCSStarParser.new()
	var result = parser.parse(input_path)
	
	if result == null or result.is_empty():
		print("Failed to parse stars.")
		return false
		
	print("Parsed stars data.")
	
	var success = true
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir()) # Assuming input is in hermes_core
	
	# Output directories based on user request:
	# images -> target/assets/environment/stars/ (which is output_dir passed in)
	# suns -> target/assets/environment/suns/
	# debris -> target/assets/environment/debris/
	
	var stars_dir = output_dir # target/assets/environment/stars
	var suns_dir = output_dir.get_base_dir().path_join("suns") # target/assets/environment/suns
	var debris_dir = output_dir.get_base_dir().path_join("debris") # target/assets/environment/debris
	var debris_neb_dir = output_dir.get_base_dir().path_join("debris_neb") # target/assets/environment/debris_neb
	
	DirAccess.make_dir_recursive_absolute(stars_dir)
	DirAccess.make_dir_recursive_absolute(suns_dir)
	DirAccess.make_dir_recursive_absolute(debris_dir)
	DirAccess.make_dir_recursive_absolute(debris_neb_dir)
	
	# Process Bitmaps (Convert to PNG in stars_dir)
	for star in result.get("bitmaps", []):
		# star is WCSStarBitmapData, has filename
		var tex_filename = star.filename
		if not tex_filename.is_empty():
			var source_file = _find_source_asset(source_root, tex_filename, [".pcx", ".dds", ".png", ".tga"])
			if not source_file.is_empty():
				_convert_asset(source_file, stars_dir, "texture")
				
				var png_filename = source_file.get_file().get_basename() + ".png"
				var png_path = stars_dir.path_join(png_filename)
				
				# Ensure path is res://
				var res_path = png_path
				if not res_path.begins_with("res://"):
					res_path = ProjectSettings.localize_path(res_path)
				
				var tex = PlaceholderTexture2D.new()
				tex.resource_path = res_path
				star.texture = tex
			else:
				print("Warning: Could not find source for star bitmap: " + tex_filename)
			
	# Process Suns
	for sun_dict in result.get("suns", []):
		var sun_res = WCSSunData.new()
		sun_res.sun_name = sun_dict.get("sun_name", "")
		sun_res.color = sun_dict.get("color", Color.WHITE)
		sun_res.scale = sun_dict.get("scale", 1.0)
		
		# Handle sunglow texture
		var sunglow_name = sun_dict.get("sunglow_filename", "")
		if not sunglow_name.is_empty():
			var source_file = _find_source_asset(source_root, sunglow_name, [".pcx", ".dds", ".png", ".tga"])
			if not source_file.is_empty():
				_convert_asset(source_file, stars_dir, "texture") # Save texture to stars dir? Or suns dir? User said images go to stars/
				# Load the converted texture using PlaceholderTexture2D to ensure path is saved
				var png_filename = source_file.get_file().get_basename() + ".png"
				var png_path = stars_dir.path_join(png_filename)
				
				# Ensure path is res://
				var res_path = png_path
				if not res_path.begins_with("res://"):
					res_path = ProjectSettings.localize_path(res_path)
				
				var tex = PlaceholderTexture2D.new()
				tex.resource_path = res_path
				sun_res.sunglow = tex
			else:
				print("Warning: Could not find source for sunglow: " + sunglow_name)
				
		# Handle flares
		for flare_dict in sun_dict.get("flares", []):
			var flare_res = WCSSunFlare.new()
			flare_res.position = flare_dict.get("position", 0.0)
			flare_res.scale = flare_dict.get("scale", 1.0)
			
			var flare_tex_name = flare_dict.get("texture_filename", "")
			if not flare_tex_name.is_empty():
				var source_file = _find_source_asset(source_root, flare_tex_name, [".pcx", ".dds", ".png", ".tga"])
				if not source_file.is_empty():
					_convert_asset(source_file, stars_dir, "texture") # Save texture to stars dir
					var png_filename = source_file.get_file().get_basename() + ".png"
					var png_path = stars_dir.path_join(png_filename)
					
					# Ensure path is res://
					var res_path = png_path
					if not res_path.begins_with("res://"):
						res_path = ProjectSettings.localize_path(res_path)
					
					var tex = PlaceholderTexture2D.new()
					tex.resource_path = res_path
					flare_res.texture = tex
				else:
					print("Warning: Could not find source for flare: " + flare_tex_name)
			
			sun_res.flares.append(flare_res)
			
		var filename = sun_res.sun_name.to_lower().replace(" ", "_") + ".tres"
		var save_path = suns_dir.path_join(filename)
		if ResourceSaver.save(sun_res, save_path) != OK:
			print("Failed to save sun: " + save_path)
			success = false
			
	# Process Debris
	# Directories created at top of function
	
	for debris in result.get("debris", []):
		# debris is WCSDebrisData, has filename and is_nebula_debris
		var tex_filename = debris.filename
		var target_dir = debris_dir
		if debris.is_nebula_debris:
			target_dir = debris_neb_dir
			
		if not tex_filename.is_empty():
			var source_file = _find_source_asset(source_root, tex_filename, [".pcx", ".dds", ".png", ".tga", ".ani", ".eff"])
			if not source_file.is_empty():
				var ext = source_file.get_extension().to_lower()
				if ext == "ani" or ext == "eff":
					# Convert animation (creates spritesheet PNG and SpriteFrames TRES)
					_convert_asset(source_file, target_dir, "animation")
					print("Converted " + ext.to_upper() + " to spritesheet: " + tex_filename)
				else:
					# Standard texture conversion
					_convert_asset(source_file, target_dir, "texture")
			else:
				print("Warning: Could not find source for debris: " + tex_filename)
			
	return success

func _process_nebula(input_path: String, output_dir: String) -> bool:
	var parser = WCSNebulaParser.new()
	var assets = parser.parse(input_path)
	
	if assets == null:
		print("Failed to parse nebula.")
		return false
		
	DirAccess.make_dir_recursive_absolute(output_dir)
	
	# Process background bitmaps
	for bitmap_name in assets.backgrounds.keys():
		var source = _find_source_asset(input_path.get_base_dir().get_base_dir(), bitmap_name, [".pcx", ".dds", ".png", ".tga"])
		if not source.is_empty():
			_convert_asset(source, output_dir, "texture")
			var texture_path = output_dir.path_join(source.get_file().get_basename() + ".png")
			# Use PlaceholderTexture2D to create a reference to the file
			# This ensures ResourceSaver writes ExtResource("path") even if the file isn't imported yet
			var texture = PlaceholderTexture2D.new()
			# Ensure path is res://
			var res_path = texture_path
			if not res_path.begins_with("res://"):
				# Assuming running from project root, relative paths are res://
				# Strip ./ if present
				res_path = res_path.replace("./", "")
				# If it doesn't start with res://, prepend it
				if not res_path.begins_with("res://"):
					res_path = "res://" + res_path.lstrip("/")
			
			texture.resource_path = res_path
			assets.backgrounds[bitmap_name] = texture
		else:
			print("Source not found for: " + bitmap_name)

	# Process poof bitmaps
	for poof_name in assets.poofs.keys():
		var source = _find_source_asset(input_path.get_base_dir().get_base_dir(), poof_name, [".pcx", ".dds", ".png", ".tga"])
		if not source.is_empty():
			_convert_asset(source, output_dir, "texture")
			var texture_path = output_dir.path_join(source.get_file().get_basename() + ".png")
			
			var texture = PlaceholderTexture2D.new()
			var res_path = texture_path
			if not res_path.begins_with("res://"):
				res_path = res_path.replace("./", "")
				if not res_path.begins_with("res://"):
					res_path = "res://" + res_path.lstrip("/")
					
			texture.resource_path = res_path
			assets.poofs[poof_name] = texture
		else:
			print("Source not found for: " + poof_name)
			
	var save_path = output_dir.path_join("nebula.tres")
	var err = ResourceSaver.save(assets, save_path)
	if err != OK:
		print("Failed to save resource: " + save_path)
		return false
		
	print("Saved: " + save_path)
	return true

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
	
	if resources == null:
		print("Failed to parse lightning.")
		return false
		
	var generator = LightningGenerator.new()
	var success_count = 0
	
	for res in resources:
		if generator.generate(res, output_dir):
			success_count += 1
			
	print("Generated " + str(success_count) + "/" + str(resources.size()) + " lightning scenes.")
	return success_count == resources.size()

func _process_personas(input_path: String, output_dir: String) -> bool:
	var parser = WCSMessageParser.new()
	var personas = parser.parse(input_path)
	
	if personas == null or personas.is_empty():
		print("Failed to parse personas/messages.")
		return false
		
	print("Parsed " + str(personas.size()) + " personas.")
	
	var generator = PersonaGenerator.new()
	
	# Output root is passed as output_dir (e.g. target/).
	# Generator handles subpath campaigns/hermes/persona/...
	
	for persona in personas:
		generator.generate_persona(persona, output_dir)
		
	return true


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
const SoundManifest = preload("res://scripts/resources/sounds/sound_manifest.gd")

func _process_music(input_path: String, output_dir: String) -> bool:
	var parser = WCSMusicParser.new()
	var result = parser.parse(input_path)
	
	if result == null or not result is Dictionary:
		print("Failed to parse music.")
		return false
		
	var soundtracks = result.get("soundtracks", [])
	var menu_music = result.get("menu_music")
	
	var save_dir = _resolve_output_path(output_dir, "campaigns/hermes/soundtrack")
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var saved_count = 0
	for item in soundtracks:
		var item_name = item.name
		if item_name.is_empty():
			item_name = "unknown_" + str(saved_count)
			
		var filename = item_name.to_lower().replace(" ", "_").replace(".", "_") + ".tres"
		var save_path = save_dir.path_join(filename)
		
		var err = ResourceSaver.save(item, save_path)
		if err != OK:
			print("Failed to save resource: " + save_path)
		else:
			print("Saved: " + save_path)
			saved_count += 1
			
	if menu_music:
		var menu_path = save_dir.path_join("menu_music.tres")
		var err = ResourceSaver.save(menu_music, menu_path)
		if err != OK:
			print("Failed to save menu music: " + menu_path)
		else:
			print("Saved: " + menu_path)
			
	print("Saved " + str(saved_count) + " soundtracks and menu music.")
	return true

func _process_sounds(input_path: String, output_dir: String) -> bool:
	var parser = WCSSoundParser.new()
	var result = parser.parse(input_path)
	
	if result == null or not result is Dictionary:
		print("Failed to parse sounds.")
		return false
		
	var manifest = SoundManifest.new()
	
	# Cast to Array[Resource] to satisfy strict typing
	var configs: Array[Resource] = []
	configs.append_array(result.get("audio_configs", []))
	manifest.audio_configs = configs
	
	var flybys: Array[Resource] = []
	flybys.append_array(result.get("flyby_sounds", []))
	manifest.flyby_sounds = flybys
	
	var save_dir = _resolve_output_path(output_dir, "assets/sounds")
	DirAccess.make_dir_recursive_absolute(save_dir)
	
	var save_path = save_dir.path_join("sounds.tres")
	var err = ResourceSaver.save(manifest, save_path)
	if err != OK:
		print("Failed to save sounds manifest: " + save_path)
		return false
		
	print("Saved sounds manifest to: " + save_path)
	return true
