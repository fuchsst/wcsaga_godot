extends MainLoop

## CLI Runner for WCS Import Addon.
## Usage: godot --headless -s addons/wcs_import/cli_runner.gd -- --input <file> --output <dir> --type <type>

# Parsers
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
const WCSCampaignParser = preload("res://addons/wcs_import/parsers/campaign_parser.gd")

# Generators
const HudSceneGenerator = preload("res://addons/wcs_import/generators/hud_scene_generator.gd")
const AsteroidGenerator = preload("res://addons/wcs_import/generators/asteroid_generator.gd")
const FireballGenerator = preload("res://addons/wcs_import/generators/fireball_generator.gd")
const LightningGenerator = preload("res://addons/wcs_import/generators/lightning_generator.gd")
const MuzzleFlashGenerator = preload("res://addons/wcs_import/generators/mflash_generator.gd")
const WeaponExplosionGenerator = preload("res://addons/wcs_import/generators/weapon_expl_generator.gd")
const WeaponSceneGenerator = preload("res://addons/wcs_import/generators/weapon_scene_generator.gd")
const PersonaGenerator = preload("res://addons/wcs_import/generators/persona_generator.gd")
const RankGenerator = preload("res://addons/wcs_import/generators/rank_generator.gd")
const MedalGenerator = preload("res://addons/wcs_import/generators/medal_generator.gd")
const StarGenerator = preload("res://addons/wcs_import/generators/star_generator.gd")
const NebulaGenerator = preload("res://addons/wcs_import/generators/nebula_generator.gd")
const ShipGenerator = preload("res://addons/wcs_import/generators/ship_generator.gd")
const WeaponGenerator = preload("res://addons/wcs_import/generators/weapon_generator.gd")
const IconGenerator = preload("res://addons/wcs_import/generators/icon_generator.gd")
const MainhallGenerator = preload("res://addons/wcs_import/generators/mainhall_generator.gd")
const MenuGenerator = preload("res://addons/wcs_import/generators/menu_generator.gd")
const MusicGenerator = preload("res://addons/wcs_import/generators/music_generator.gd")
const SoundGenerator = preload("res://addons/wcs_import/generators/sound_generator.gd")
const SpeciesGenerator = preload("res://addons/wcs_import/generators/species_generator.gd")

# Core
const WCSPathResolver = preload("res://addons/wcs_import/core/path_resolver.gd")

# Resources
const HudGaugeResource = preload("res://scripts/resources/ui/hud/hud_gauge_resource.gd")
const WCSSunData = preload("res://scripts/resources/environment/stars/sun_data.gd")
const WCSSunFlare = preload("res://scripts/resources/environment/stars/sun_flare.gd")
const SoundManifest = preload("res://scripts/resources/sounds/sound_manifest.gd")

const PROCESSING_ORDER = [
	"species_defs.tbl", "species.tbl",
	"sounds.tbl", "music.tbl",
	"iff_defs.tbl",
	"ai.tbl", "ai_profiles.tbl",
	"asteroid.tbl",
	"ships.tbl", "weapons.tbl",
	"hud_gauges.tbl", "icons.tbl", "medals.tbl", "rank.tbl", "traitor.tbl",
	"nebula.tbl", "stars.tbl", "pixels.tbl", "fireball.tbl", "mflash.tbl", "lightning.tbl", "weapon_expl.tbl",
	"strings.tbl", "tstrings.tbl", "tips.tbl", "help.tbl", "launchhelp.tbl", "credits.tbl",
	"mainhall.tbl", "menu.tbl", "cutscenes.tbl", "fonts.tbl", "scripting.tbl"
]

var _exit_code = 0
var _file_map: Dictionary = {}
var _source_root: String = ""

func _initialize():
	pass

func _process(_delta):
	_run()
	return true # Exit loop

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

func _build_file_map(root_dir: String) -> void:
	print("Building file map from: " + root_dir)
	_source_root = root_dir
	_scan_dir_recursive(root_dir)
	print("File map built with " + str(_file_map.size()) + " entries.")

func _scan_dir_recursive(dir_path: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_scan_dir_recursive(dir_path.path_join(file_name))
			else:
				var lower_name = file_name.to_lower()
				# Store full path, keyed by lowercase filename
				# If duplicate, we might overwrite, but usually unique enough or we don't care which one
				_file_map[lower_name] = dir_path.path_join(file_name)
			file_name = dir.get_next()
	else:
		print("Failed to open directory: " + dir_path)

func _run():
	print("Cmdline args: " + str(OS.get_cmdline_args()))
	var args = _parse_args()

	# Determine source root (default to source_assets/wcs_hermes_campaign/hermes_core if not specified?)
	# Or assume we are running from project root and know where source is.
	# User said: "the cli runner should by defaul loop over all tbl files in @[source_assets/wcs_hermes_campaign/hermes_core]"
	# Let's try to find that path relative to project or absolute.

	var res_path = ProjectSettings.globalize_path("res://")
	if res_path.ends_with("/"):
		res_path = res_path.left(-1)
	var project_root = res_path.get_base_dir()
	var default_source_root = project_root.path_join("source_assets/wcs_hermes_campaign")

	if not args.has("output"):
		print("Usage: godot --headless -s addons/wcs_import/cli_runner.gd -- --output <dir> [--input <file>] [--filter <pattern>]")
		_exit_code = 1
		return

	var output_dir = args["output"]
	var filter_pattern = args.get("filter", "")

	# Build file map first
	_build_file_map(default_source_root)

	if args.has("input"):
		# Single file mode
		var input_path = args["input"]
		if not input_path.begins_with("/"):
			input_path = project_root.path_join(input_path)

		var type = args.get("type", "auto")
		if type == "auto":
			type = _detect_type(input_path)

		print("Processing single file: " + input_path)
		if _process_file(input_path, output_dir, type):
			_exit_code = 0
		else:
			_exit_code = 1
	else:
		# Batch mode
		print("Starting batch processing...")
		var failure_count = 0

		# 1. Process ordered TBLs
		for filename in PROCESSING_ORDER:
			if not filter_pattern.is_empty() and not filename.matchn(filter_pattern):
				continue

			if _file_map.has(filename.to_lower()):
				var full_path = _file_map[filename.to_lower()]
				var type = _detect_type(full_path)
				print("Processing: " + filename + " (" + type + ")")
				if not _process_file(full_path, output_dir, type):
					print("Failed to process: " + filename)
					failure_count += 1
			else:
				print("Warning: File not found in source: " + filename)

		# 2. Process Missions (*.fs2)
		# Find all .fs2 files in map
		var mission_files = []
		for fname in _file_map:
			if fname.ends_with(".fs2"):
				mission_files.append(fname)
		mission_files.sort() # Ensure consistent order

		for fname in mission_files:
			if not filter_pattern.is_empty() and not fname.matchn(filter_pattern):
				continue

			var full_path = _file_map[fname]
			print("Processing Mission: " + fname)
			if not _process_file(full_path, output_dir, "mission"):
				print("Failed to process mission: " + fname)
				failure_count += 1

		# 3. Process Campaigns (*.fc2)
		var campaign_files = []
		for fname in _file_map:
			if fname.ends_with(".fc2"):
				campaign_files.append(fname)
		campaign_files.sort()

		for fname in campaign_files:
			if not filter_pattern.is_empty() and not fname.matchn(filter_pattern):
				continue

			var full_path = _file_map[fname]
			print("Processing Campaign: " + fname)
			if not _process_file(full_path, output_dir, "campaign"):
				print("Failed to process campaign: " + fname)
				failure_count += 1

		if failure_count == 0:
			print("Batch processing completed successfully.")
			_exit_code = 0
		else:
			print("Batch processing completed with " + str(failure_count) + " failures.")
			_exit_code = 1

func _process_file(input_path: String, output_dir: String, type: String) -> bool:
	match type:
		"ships": return _process_ships(input_path, _resolve_output_path(output_dir, "assets/ships"))
		"weapons": return _process_weapons(input_path, _resolve_output_path(output_dir, "assets/weapons"))
		"ai_profiles": return _process_ai_profiles(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ai_profiles"))
		"ai_classes": return _process_list_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ai_classes"), WCSAIClassParser, "", "class_name")
		"asteroids": return _process_asteroids(input_path, _resolve_output_path(output_dir, "assets/environment/asteroids"))
		"autopilot": return _process_autopilot(input_path, _resolve_output_path(output_dir, "campaigns/hermes"))
		"campaign": return _process_campaign(input_path, _resolve_output_path(output_dir, "campaigns/hermes"))
		"credits": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSCreditsParser, "", "credits.tres")
		"cutscenes": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSCutsceneParser, "", "cutscenes.tres")
		"fireball": return _process_fireballs(input_path, _resolve_output_path(output_dir, "assets/effects/fireball"))
		"fonts": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSFontParser, "", "fonts.tres")
		"help": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSHelpParser, "", "help.tres")
		"hud_gauges": return _process_hud_gauges(input_path, _resolve_output_path(output_dir, "campaigns/hermes/cockpits/hud_gauges"))
		"hud_config": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/config/hud"), WCSHudConfigParser, "", input_path.get_file().get_basename() + ".tres")
		"icons": return _process_icons(input_path, _resolve_output_path(output_dir, "assets/icons"))
		"iff_defs": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/iff_defs"), WCSIffParser, "", "iff_defs.tres")
		"launchhelp": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSLaunchHelpParser, "", "launchhelp.tres")
		"lightning": return _process_lightning(input_path, _resolve_output_path(output_dir, "assets/effects/lightning"))
		"mflash": return _process_mflash(input_path, _resolve_output_path(output_dir, "assets/effects"))
		"mainhall": return _process_mainhall(input_path, _resolve_output_path(output_dir, "campaigns/hermes/menu"))
		"medals": return _process_medals(input_path, _resolve_output_path(output_dir, "campaigns/hermes/medals"))
		"menu": return _process_menu(input_path, _resolve_output_path(output_dir, "campaigns/hermes/menu"))
		"messages": return _process_personas(input_path, _resolve_output_path(output_dir, "campaigns/hermes/personas"))
		"mission": return _process_mission(input_path, _resolve_output_path(output_dir, "campaigns/hermes/missions"))
		"music": return _process_music(input_path, _resolve_output_path(output_dir, "campaigns/hermes/soundtrack"))
		"nebula": return _process_nebula(input_path, _resolve_output_path(output_dir, "assets/environment/nebula"))
		"pixels": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "assets/environment/stars"), WCSPixelParser, "", "pixels.tres")
		"rank": return _process_ranks(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ranks"))
		"scripting": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSScriptingParser, "", "scripting.tres")
		"sounds": return _process_sounds(input_path, _resolve_output_path(output_dir, "assets/sounds"))
		"species": return _process_species(input_path, _resolve_output_path(output_dir, "campaigns/hermes/fiction/star_systems"))
		"ssm": return _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/weapons"), WCSSSMParser, "", "name")
		"stars": return _process_stars(input_path, _resolve_output_path(output_dir, "assets/environment/stars"))
		"tips": return _process_tips(input_path, _resolve_output_path(output_dir, "campaigns/hermes"))
		"traitor": return _process_traitor(input_path, _resolve_output_path(output_dir, "campaigns/hermes"))
		"weapon_expl": return _process_weapon_expl(input_path, _resolve_output_path(output_dir, "assets/effects"))
		"localization": return _process_localization(input_path, output_dir)
		_:
			print("Skipping unsupported type: " + type)
			return true

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

	var generator = ShipGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	return generator.generate(ships, output_dir, source_root)

func _process_weapons(input_path: String, output_dir: String) -> bool:
	var parser = WCSWeaponParser.new()
	var weapons = parser.parse(input_path)

	if weapons == null or weapons.is_empty():
		print("Failed to parse weapons.")
		return false

	print("Parsed " + str(weapons.size()) + " weapons.")

	var generator = WeaponGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	return generator.generate(weapons, output_dir, source_root)

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
	# output_dir is already .../campaigns/{campaign}/ai_profiles
	var save_dir = output_dir
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
	# output_dir is already .../campaigns/{campaign}/ai_classes
	var save_dir = output_dir
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
	# Determine output path
	# output_dir is .../campaigns/{campaign}/missions
	# We want subfolders based on mission filename?
	# output_dir is the root for missions, for each mission a subfolder is created, where all assets, directly related to the mission go (e.g. mission.tres, cutscenes, audio)
	
	var save_dir = output_dir

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
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	for data in asteroids:
		if generator.generate(data, output_dir, source_root):
			success_count += 1

	print("Generated " + str(success_count) + "/" + str(asteroids.size()) + " asteroid scenes.")
	return success_count == asteroids.size()

func _process_icons(input_path: String, output_dir: String) -> bool:
	var parser = WCSIconParser.new()
	var icons = parser.parse(input_path)

	if icons == null or icons.is_empty():
		print("Failed to parse icons.")
		return false

	print("Parsed " + str(icons.size()) + " icons.")

	var generator = IconGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	return generator.generate(icons, output_dir, source_root)

func _process_autopilot(input_path: String, output_dir: String) -> bool:
	var parser = WCSAutopilotParser.new()
	var res = parser.parse(input_path)

	if res == null:
		print("Failed to parse autopilot.")
		return false

	# Save to campaigns/{campaign}/ui/localisation/autopilot.tres
	# output_dir is campaigns/{campaign}
	
	var save_dir = output_dir.path_join("ui").path_join("localisation")
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
	var manifest = parser.parse(input_path)

	if manifest == null:
		print("Failed to parse medals.")
		return false

	var generator = MedalGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate_medals(manifest, output_dir, source_root)

func _process_ranks(input_path: String, output_dir: String) -> bool:
	var parser = WCSRankParser.new()
	var manifest = parser.parse(input_path)

	if manifest == null:
		print("Failed to parse ranks.")
		return false

	var generator = RankGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate_ranks(manifest, output_dir, source_root)

func _process_traitor(input_path: String, output_dir: String) -> bool:
	var parser = WCSTraitorParser.new()
	var res = parser.parse(input_path)

	if res == null:
		print("Failed to parse traitor.")
		return false

	# output_dir is campaigns/{campaign}
	var save_dir = output_dir
	DirAccess.make_dir_recursive_absolute(save_dir)

	var save_path = save_dir.path_join("traitor.tres")
	var err = ResourceSaver.save(res, save_path)
	if err != OK:
		print("Failed to save resource: " + save_path)
		return false

	print("Saved: " + save_path)
	return true

func _process_mainhall(input_path: String, output_dir: String) -> bool:
	var parser = WCSMainhallParser.new()
	var res = parser.parse(input_path)

	if res == null:
		print("Failed to parse mainhall.")
		return false

	var generator = MainhallGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	var save_dir = output_dir

	return generator.generate(res, save_dir, source_root)

func _process_menu(input_path: String, output_dir: String) -> bool:
	var parser = WCSMenuParser.new()
	var res = parser.parse(input_path)

	if res == null:
		print("Failed to parse menu.")
		return false

	var generator = MenuGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	var save_dir = output_dir

	return generator.generate(res, save_dir, source_root)

func _process_tips(input_path: String, output_dir: String) -> bool:
	var parser = WCSTipsParser.new()
	var res = parser.parse(input_path)

	if res == null:
		print("Failed to parse tips.")
		return false

	# output_dir is campaigns/{campaign}
	var save_dir = output_dir.path_join("ui").path_join("localisation")
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

	# output_dir is .../campaigns/{campaign} (passed as campaigns/hermes/ui/localisation? No, passed as campaigns/hermes/ui/localisation/strings?)
	# User passed output_dir for localization?
	# "localization": return _process_localization(input_path, output_dir)
	# Wait, user didn't change localization call in _process_file?
	# Let's check _process_file again.
	# "localization": return _process_localization(input_path, output_dir)
	# It seems user didn't change localization.
	# But I should probably assume output_dir is the base.
	# If output_dir is just "assets", then I still need to append path.
	# But if I want to be consistent, I should update _process_file for localization too.
	# For now, let's keep it as is if user didn't change it, OR update it to be consistent.
	# User said "refactor the rest of the script to work with my changes".
	# User changed MOST of them.
	# Let's assume output_dir passed here is the target directory for localization.
	
	var save_dir = output_dir.path_join("ui").path_join("localisation")
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

		# Fallback if output dir structure is unexpected
		return base_output_dir.path_join(subpath)

	# If subpath starts with "assets/" and base_output_dir ends with "assets", strip it
	if subpath.begins_with("assets/") and base_output_dir.ends_with("assets"):
		return base_output_dir.path_join(subpath.substr(7))

	# Otherwise, use base output dir (target/assets)
	return base_output_dir.path_join(subpath)

func _process_stars(input_path: String, output_dir: String) -> bool:
	var parser = WCSStarParser.new()
	var result = parser.parse(input_path)

	if result == null or result.is_empty():
		print("Failed to parse stars.")
		return false

	print("Parsed stars data.")

	var generator = StarGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	return generator.generate(result, output_dir, source_root)

func _process_nebula(input_path: String, output_dir: String) -> bool:
	var parser = WCSNebulaParser.new()
	var assets = parser.parse(input_path)

	if assets == null:
		print("Failed to parse nebula.")
		return false

	var generator = NebulaGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	return generator.generate(assets, output_dir, source_root)

func _process_hud_gauges(input_path: String, output_dir: String) -> bool:
	var parser = WCSHudGaugeParser.new()
	var gauges = parser.parse(input_path)

	if gauges == null:
		print("Failed to parse hud_gauges.tbl")
		return false

	var generator = HudSceneGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	return generator.generate(gauges, output_dir, source_root)

func _process_fireballs(input_path: String, output_dir: String) -> bool:
	var parser = WCSFireballParser.new()
	var fireballs = parser.parse(input_path)

	if fireballs == null or fireballs.is_empty():
		print("Failed to parse fireballs.")
		return false

	print("Parsed " + str(fireballs.size()) + " fireballs.")

	var generator = FireballGenerator.new()
	var success_count = 0
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	for res in fireballs:
		if generator.generate(res, output_dir, source_root):
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
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	for res in resources:
		if generator.generate(res, output_dir, source_root):
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
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	# Output root is passed as output_dir (e.g. target/).
	# Generator handles subpath campaigns/hermes/persona/...

	for persona in personas:
		generator.generate_persona(persona, output_dir, source_root)

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
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	for res in resources:
		if generator.generate(res, output_dir, source_root):
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
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())

	for res in resources:
		if generator.generate(res, output_dir, source_root):
			success_count += 1

	print("Generated " + str(success_count) + "/" + str(resources.size()) + " weapon_expl resources.")
	return success_count == resources.size()

func _process_music(input_path: String, output_dir: String) -> bool:
	var parser = WCSMusicParser.new()
	var result = parser.parse(input_path)

	if result == null or not result is Dictionary:
		print("Failed to parse music.")
		return false

	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	var generator = MusicGenerator.new()

	return generator.generate(result, output_dir, source_root)

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

	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	var generator = SoundGenerator.new()

	return generator.generate(manifest, output_dir, source_root)

func _process_species(input_path: String, output_dir: String) -> bool:
	var parser = WCSSpeciesParser.new()
	var manifest = parser.parse(input_path)

	if manifest == null:
		print("Failed to parse species.")
		return false

	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	var generator = SpeciesGenerator.new()

	return generator.generate(manifest, output_dir, source_root)
