@tool
extends RefCounted
# gdlint: ignore=max-returns

# const WCSPathResolver_preload = preload("res://addons/wcs_import/core/path_resolver.gd") # Uses global class_name

# Parsers
const WCSBaseParser = preload("res://addons/wcs_import/parsers/base_parser.gd")
const WCSShipParser = preload("res://addons/wcs_import/parsers/ship_parser.gd")
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
const AnimationGenerator = preload("res://addons/wcs_import/generators/animation_generator.gd")
const MuzzleFlashGenerator = preload("res://addons/wcs_import/generators/mflash_generator.gd")
const WeaponExplosionGenerator = preload("res://addons/wcs_import/generators/weapon_expl_generator.gd")
const WeaponSceneGenerator = preload("res://addons/wcs_import/generators/weapon_scene_generator.gd")
const PersonaGenerator = preload("res://addons/wcs_import/generators/persona_generator.gd")
const RankGenerator = preload("res://addons/wcs_import/generators/rank_generator.gd")
const MedalGenerator = preload("res://addons/wcs_import/generators/medal_generator.gd")
const StarGenerator = preload("res://addons/wcs_import/generators/star_generator.gd")
const NebulaGenerator = preload("res://addons/wcs_import/generators/nebula_generator.gd")
const ShipGenerator = preload("res://addons/wcs_import/generators/ship_generator.gd")
const ShipSceneGenerator = preload("res://addons/wcs_import/generators/ship_scene_generator.gd")
const WeaponGenerator = preload("res://addons/wcs_import/generators/weapon_generator.gd")
const IconGenerator = preload("res://addons/wcs_import/generators/icon_generator.gd")
const MainhallGenerator = preload("res://addons/wcs_import/generators/mainhall_generator.gd")
const MenuGenerator = preload("res://addons/wcs_import/generators/menu_generator.gd")
const MusicGenerator = preload("res://addons/wcs_import/generators/music_generator.gd")
const SoundGenerator = preload("res://addons/wcs_import/generators/sound_generator.gd")
const SpeciesGenerator = preload("res://addons/wcs_import/generators/species_generator.gd")
const MissionGenerator = preload("res://addons/wcs_import/generators/mission_generator.gd")
const CampaignGenerator = preload("res://addons/wcs_import/generators/campaign_generator.gd")

const PROCESSING_ORDER = [
	"species_defs.tbl",
	"species.tbl",
	"sounds.tbl",
	"music.tbl",
	"iff_defs.tbl",
	"ai.tbl",
	"ai_profiles.tbl",
	"asteroid.tbl",
	"ships.tbl",
	"weapons.tbl",
	"hud_gauges.tbl",
	"icons.tbl",
	"medals.tbl",
	"rank.tbl",
	"traitor.tbl",
	"nebula.tbl",
	"stars.tbl",
	"pixels.tbl",
	"fireball.tbl",
	"mflash.tbl",
	"lightning.tbl",
	"weapon_expl.tbl",
	"strings.tbl",
	"tstrings.tbl",
	"tips.tbl",
	"help.tbl",
	"launchhelp.tbl",
	"credits.tbl",
	"mainhall.tbl",
	"menu.tbl",
	"cutscenes.tbl",
	"fonts.tbl",
	"scripting.tbl"
]

var _file_map: Dictionary = {}


func build_file_map(root_dir: String) -> void:
	print("Building file map from: " + root_dir)
	_file_map.clear()
	_scan_dir_recursive(root_dir)
	WCSPathResolver.file_map = _file_map
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
				_file_map[lower_name] = dir_path.path_join(file_name)
			file_name = dir.get_next()
	else:
		print("Failed to open directory: " + dir_path)


func process_batch(output_dir: String, filter_pattern: String = "", types_to_process: Array = []) -> bool:
	build_file_map_if_needed()
	print("Starting batch processing...")
	var failure_count = 0

	var process_all = types_to_process.is_empty() or "all" in types_to_process

	# 1. Process Animations (*.eff, *.ani)
	if process_all or "animation" in types_to_process:
		failure_count += _process_batch_animations(output_dir, filter_pattern)

	# 2. Process ordered TBLs
	for filename in PROCESSING_ORDER:
		if not filter_pattern.is_empty() and not filename.matchn(filter_pattern):
			continue

		if _file_map.has(filename.to_lower()):
			var full_path = _file_map[filename.to_lower()]
			var type = detect_type(full_path)

			if not process_all and not type in types_to_process:
				continue

			print("Processing: " + filename + " (" + type + ")")
			if not process_file(full_path, output_dir, type):
				print("Failed to process: " + filename)
				failure_count += 1
		else:
			# Only warn if we intend to process it
			pass

	# 3. Process Missions (*.fs2)
	if process_all or "mission" in types_to_process:
		failure_count += _process_batch_extension(output_dir, "fs2", "mission", filter_pattern)

	# 4. Process Campaigns (*.fc2)
	if process_all or "campaign" in types_to_process:
		failure_count += _process_batch_extension(output_dir, "fc2", "campaign", filter_pattern)

	if failure_count == 0:
		print("Batch processing completed successfully.")
		return true

	print("Batch processing completed with " + str(failure_count) + " failures.")
	return false


func _process_batch_animations(output_dir: String, filter_pattern: String) -> int:
	var failure_count = 0
	var anim_files = []
	for fname in _file_map:
		if fname.ends_with(".eff") or fname.ends_with(".ani"):
			anim_files.append(fname)
	anim_files.sort()

	for fname in anim_files:
		if not filter_pattern.is_empty() and not fname.matchn(filter_pattern):
			continue

		var full_path = _file_map[fname]
		if fname.begins_with("empty.") or full_path.contains("hermes_effects") or full_path.contains("hermes_interface"):
			continue

		# Skip duplicates handled by generators
		if fname.begins_with("ExpMissileHit") or fname.begins_with("Shivan_Impact") or fname.begins_with("rockEXP") or fname.begins_with("exp") or fname.begins_with("Fade") or fname.begins_with("Icon") or fname.begins_with("shieldhit"):
			continue

		var specific_output_dir = output_dir.path_join("assets/animations/effects")
		if full_path.contains("/hermes_cbanims/"):
			specific_output_dir = output_dir.path_join("campaigns/hermes/animations/command_briefings")
		elif fname.begins_with("Exp") or fname.begins_with("exp") or fname.begins_with("rockEXP") or fname.begins_with("Shivan_Impact") or fname.begins_with("shieldhit"):
			specific_output_dir = output_dir.path_join("assets/effects/explosions")
		elif fname.begins_with("Icon") or fname.begins_with("Fade") or fname.begins_with("bicon"):
			specific_output_dir = output_dir.path_join("assets/animations/interface")

		print("Processing Animation: " + fname + " -> " + specific_output_dir)
		if not process_file(full_path, specific_output_dir, "animation"):
			print("Failed to process animation: " + fname)
			failure_count += 1
	return failure_count


func _process_batch_extension(output_dir: String, ext: String, type: String, filter_pattern: String) -> int:
	var failure_count = 0
	var files = []
	for fname in _file_map:
		if fname.ends_with("." + ext):
			files.append(fname)
	files.sort()

	for fname in files:
		if not filter_pattern.is_empty() and not fname.matchn(filter_pattern):
			continue

		var full_path = _file_map[fname]
		print("Processing " + type + ": " + fname)
		if not process_file(full_path, output_dir, type):
			print("Failed to process " + type + ": " + fname)
			failure_count += 1
	return failure_count


func process_file(input_path: String, output_dir: String, type: String) -> bool:
	match type:
		"ships": return _process_ships(input_path, _resolve_output_path(output_dir, "assets/ships"))
		"weapons": return _process_weapons(input_path, _resolve_output_path(output_dir, "assets/weapons"))
		"ai_profiles": return _process_ai_profiles(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ai_profiles"))
		"ai_classes": return _process_ai_classes(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ai_classes"))
		"asteroids": return _process_asteroids(input_path, _resolve_output_path(output_dir, "assets/environment/asteroids"))
		"autopilot": return _process_autopilot(input_path, _resolve_output_path(output_dir, "campaigns/hermes"))
		"campaign": return _process_campaign(input_path, _resolve_output_path(output_dir, "campaigns/hermes"))
		"credits": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ui/localisation"), WCSCreditsParser, "", "credits.tres")
		"cutscenes": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSCutsceneParser, "", "cutscenes.tres")
		"fireball": return _process_fireballs(input_path, _resolve_output_path(output_dir, "assets/effects/fireball"))
		"fonts": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSFontParser, "", "fonts.tres")
		"help": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ui/localisation"), WCSHelpParser, "", "help.tres")
		"hud_gauges": return _process_hud_gauges(input_path, _resolve_output_path(output_dir, "assets/cockpits/hud_gauges"))
		"hud_config": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/config/hud"), WCSHudConfigParser, "", input_path.get_file().get_basename() + ".tres")
		"icons": return _process_icons(input_path, _resolve_output_path(output_dir, "assets/icons"))
		"iff_defs": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSIffParser, "", "iff_defs.tres")
		"launchhelp": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ui/localisation"), WCSLaunchHelpParser, "", "launchhelp.tres")
		"lightning": return _process_lightning(input_path, _resolve_output_path(output_dir, "assets/effects/lightning"))
		"mflash": return _process_mflash(input_path, _resolve_output_path(output_dir, "assets/effects"))
		"mainhall": return _process_mainhall(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ui/menu"))
		"medals": return _process_medals(input_path, _resolve_output_path(output_dir, "campaigns/hermes/medals"))
		"menu": return _process_menu(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ui/menu"))
		"animation": return _process_animation(input_path, output_dir)
		"messages": return _process_personas(input_path, _resolve_output_path(output_dir, "campaigns/hermes/personas"))
		"mission": return _process_mission(input_path, _resolve_output_path(output_dir, "campaigns/hermes/missions"))
		"music": return _process_music(input_path, _resolve_output_path(output_dir, "campaigns/hermes/soundtrack"))
		"nebula": return _process_nebula(input_path, _resolve_output_path(output_dir, "assets/environment/nebula"))
		"pixels": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "assets/environment/stars"), WCSPixelParser, "", "pixels.tres")
		"rank": return _process_ranks(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ranks"))
		"scripting": return _process_simple_resource(input_path, _resolve_output_path(output_dir, "campaigns/hermes"), WCSScriptingParser, "", "scripting.tres")
		"sounds": return _process_sounds(input_path, _resolve_output_path(output_dir, "assets/sounds"))
		"species_defs": return _process_species_defs(input_path, _resolve_output_path(output_dir, "assets/species_defs"))
		"species": return _process_species(input_path, _resolve_output_path(output_dir, "campaigns/hermes/fiction"))
		"ssm": return _process_list_resource(input_path, _resolve_output_path(output_dir, "assets/weapons"), WCSSSMParser, "", "name")
		"stars": return _process_stars(input_path, _resolve_output_path(output_dir, "assets/environment/stars"))
		"tips": return _process_tips(input_path, _resolve_output_path(output_dir, "campaigns/hermes"))
		"traitor": return _process_traitor(input_path, _resolve_output_path(output_dir, "campaigns/hermes/ui/localisation"))
		"weapon_expl": return _process_weapon_expl(input_path, _resolve_output_path(output_dir, "assets/effects"))
		"localization": return _process_localization(input_path, output_dir)
		_:
			print("Skipping unsupported type: " + type)
			return true


func detect_type(path: String) -> String:
	var filename = path.get_file().to_lower()
	if filename.ends_with(".fs2"): return "mission"
	if filename.ends_with(".fc2"): return "campaign"
	if filename.ends_with(".hcf"): return "hud_config"
	if filename.ends_with(".eff") or filename.ends_with(".ani"): return "animation"

	var special_mappings = {
		"ai.tbl": "ai_classes",
		"strings.tbl": "localization",
		"tstrings.tbl": "localization",
		"species_defs.tbl": "species_defs"
	}
	if special_mappings.has(filename): return special_mappings[filename]
	if filename.ends_with(".tbl"): return filename.get_basename()
	return "unknown"


func build_file_map_if_needed():
	if _file_map.is_empty():
		var res_path = ProjectSettings.globalize_path("res://")
		if res_path.ends_with("/"): res_path = res_path.left(-1)
		var project_root = res_path.get_base_dir()
		var default_source_root = project_root.path_join("source_assets/wcs_hermes_campaign")
		build_file_map(default_source_root)


func _resolve_output_path(base: String, sub: String) -> String:
	return base.path_join(sub)


# --- Specific Processors (Copied from cli_runner.gd) ---

func _process_animation(input_path: String, output_dir: String) -> bool:
	var generator = AnimationGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(input_path, output_dir, source_root)


func _process_ships(input_path: String, output_dir: String) -> bool:
	var parser = WCSShipParser.new()
	var ships = parser.parse(input_path)
	if ships == null or ships.is_empty(): return false
	print("Parsed " + str(ships.size()) + " ships.")
	var generator = ShipGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	var success = generator.generate(ships, output_dir, source_root)
	if success:
		print("Generating ship scenes...")
		var scene_generator = ShipSceneGenerator.new()
		for ship in ships: scene_generator.generate(ship, output_dir, source_root)
	return success


func _process_weapons(input_path: String, output_dir: String) -> bool:
	# Note: dynamic load check removed for simplicity, or keep if needed
	var parser = load("res://addons/wcs_import/parsers/weapon_parser.gd").new()
	var weapons = parser.parse(input_path)
	if weapons == null or weapons.is_empty(): return false
	print("Parsed " + str(weapons.size()) + " weapons.")
	var generator = WeaponGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(weapons, output_dir, source_root)


func _process_ai_profiles(input_path: String, output_dir: String) -> bool:
	var parser = WCSAIProfileParser.new()
	var profiles = parser.parse(input_path)
	if profiles == null or profiles.is_empty(): return false
	print("Parsed " + str(profiles.size()) + " AI profile levels.")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var saved_count = 0
	for profile in profiles:
		var difficulty_slug = profile.difficulty_level.to_lower().replace(" ", "_")
		if difficulty_slug.is_empty(): difficulty_slug = "level_" + str(saved_count)
		var profile_path = output_dir.path_join(difficulty_slug + ".tres")
		if ResourceSaver.save(profile, profile_path) == OK: saved_count += 1
	return saved_count == profiles.size()


func _process_ai_classes(input_path: String, output_dir: String) -> bool:
	var parser = WCSAIClassParser.new()
	var ai_classes = parser.parse(input_path)
	if ai_classes == null or ai_classes.is_empty(): return false
	print("Parsed " + str(ai_classes.size()) + " AI class instances.")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var saved_count = 0
	for ai_class in ai_classes:
		var class_slug = ai_class.ai_class_name.to_lower().replace(" ", "_").replace("#", "")
		var difficulty_slug = ai_class.difficulty_level.to_lower().replace(" ", "_")
		var class_dir = output_dir.path_join(class_slug)
		DirAccess.make_dir_recursive_absolute(class_dir)
		if ResourceSaver.save(ai_class, class_dir.path_join(difficulty_slug + ".tres")) == OK: saved_count += 1
	return saved_count == ai_classes.size()


func _process_mission(input_path: String, output_dir: String) -> bool:
	if input_path.get_extension() == "fc2": return _process_campaign(input_path, output_dir)
	var generator = MissionGenerator.new()
	return generator.process_mission(input_path, output_dir)


func _process_campaign(input_path: String, output_dir: String) -> bool:
	var generator = CampaignGenerator.new()
	return generator.process_campaign(input_path, output_dir)


func _process_asteroids(input_path: String, output_dir: String) -> bool:
	var parser = WCSAsteroidParser.new()
	var asteroids = parser.parse(input_path)
	if asteroids == null or asteroids.is_empty(): return false
	var generator = AsteroidGenerator.new()
	var success_count = 0
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	for data in asteroids:
		if generator.generate(data, output_dir, source_root): success_count += 1
	return success_count == asteroids.size()


func _process_icons(input_path: String, output_dir: String) -> bool:
	var parser = WCSIconParser.new()
	var icons = parser.parse(input_path)
	if icons == null or icons.is_empty(): return false
	var generator = IconGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(icons, output_dir, source_root)


func _process_autopilot(input_path: String, output_dir: String) -> bool:
	var parser = WCSAutopilotParser.new()
	var data = parser.parse(input_path)
	if data == null: return false
	DirAccess.make_dir_recursive_absolute(output_dir)
	return ResourceSaver.save(data, output_dir.path_join("autopilot.tres")) == OK


func _process_simple_resource(input_path: String, output_dir: String, parser_class, _unused_arg, filename: String) -> bool:
	var parser = parser_class.new()
	var data = parser.parse(input_path)
	if data == null:
		print("Failed to parse resource from " + input_path)
		return false
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path = output_dir.path_join(filename)
	var err = ResourceSaver.save(data, output_path)
	if err != OK:
		print("Failed to save resource to: " + output_path)
		return false
	print("Saved resource: " + output_path)
	return true


func _process_fireballs(input_path: String, output_dir: String) -> bool:
	var parser = WCSFireballParser.new()
	var fireballs = parser.parse(input_path)
	if fireballs == null or fireballs.is_empty(): return false
	var generator = FireballGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(fireballs, output_dir, source_root)


func _process_hud_gauges(input_path: String, output_dir: String) -> bool:
	var parser = WCSHudGaugeParser.new()
	var gauges = parser.parse(input_path)
	if gauges == null or gauges.is_empty(): return false
	var generator = HudSceneGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(gauges, output_dir, source_root)


func _process_lightning(input_path: String, output_dir: String) -> bool:
	var parser = WCSLightningParser.new()
	var data = parser.parse(input_path)
	if data == null: return false
	var generator = LightningGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(data, output_dir, source_root)


func _process_mflash(input_path: String, output_dir: String) -> bool:
	var parser = WCSMuzzleFlashParser.new()
	var flashes = parser.parse(input_path)
	if flashes == null: return false
	var generator = MuzzleFlashGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(flashes, output_dir, source_root)


func _process_mainhall(input_path: String, output_dir: String) -> bool:
	var parser = WCSMainhallParser.new()
	var halls = parser.parse(input_path)
	if halls == null: return false
	var generator = MainhallGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(halls, output_dir, source_root)


func _process_medals(input_path: String, output_dir: String) -> bool:
	var parser = WCSMedalParser.new()
	var medals = parser.parse(input_path)
	if medals == null: return false
	var generator = MedalGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(medals, output_dir, source_root)


func _process_menu(input_path: String, output_dir: String) -> bool:
	var parser = WCSMenuParser.new()
	var regions = parser.parse(input_path)
	if regions == null: return false
	var generator = MenuGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(regions, output_dir, source_root)


func _process_personas(input_path: String, output_dir: String) -> bool:
	var parser = WCSMessageParser.new()
	var personas = parser.parse(input_path)
	if personas == null: return false
	var generator = PersonaGenerator.new()
	return generator.generate(personas, output_dir)


func _process_music(input_path: String, output_dir: String) -> bool:
	var parser = WCSMusicParser.new()
	var music = parser.parse(input_path)
	if music == null: return false
	var generator = MusicGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(music, output_dir, source_root)


func _process_nebula(input_path: String, output_dir: String) -> bool:
	var parser = WCSNebulaParser.new()
	var data = parser.parse(input_path)
	if data == null: return false
	var generator = NebulaGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(data, output_dir, source_root)


func _process_ranks(input_path: String, output_dir: String) -> bool:
	var parser = WCSRankParser.new()
	var ranks = parser.parse(input_path)
	if ranks == null: return false
	var generator = RankGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(ranks, output_dir, source_root)


func _process_sounds(input_path: String, output_dir: String) -> bool:
	var parser = WCSSoundParser.new()
	var sounds = parser.parse(input_path)
	if sounds == null: return false
	var generator = SoundGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(sounds, output_dir, source_root)


func _process_species_defs(input_path: String, output_dir: String) -> bool:
	var parser = WCSSpeciesParser.new()
	var species = parser.parse(input_path)
	if species == null: return false
	var generator = SpeciesGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate_defs(species, output_dir, source_root)


func _process_species(input_path: String, output_dir: String) -> bool:
	var parser = WCSSpeciesParser.new()
	var species = parser.parse(input_path)
	if species == null: return false
	var generator = SpeciesGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(species, output_dir, source_root)


func _process_list_resource(input_path: String, output_dir: String, parser_class, _unused, name_key: String) -> bool:
	var parser = parser_class.new()
	var items = parser.parse(input_path)
	if items == null: return false
	DirAccess.make_dir_recursive_absolute(output_dir)
	var count = 0
	for item in items:
		var name = item.get(name_key)
		if name:
			var path = output_dir.path_join(name.to_lower() + ".tres")
			if ResourceSaver.save(item, path) == OK: count += 1
	return count == items.size()


func _process_stars(input_path: String, output_dir: String) -> bool:
	var parser = WCSStarParser.new()
	var stars = parser.parse(input_path)
	if stars == null: return false
	var generator = StarGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(stars, output_dir, source_root)


func _process_tips(input_path: String, output_dir: String) -> bool:
	var parser = WCSTipsParser.new()
	var tips = parser.parse(input_path)
	if tips == null: return false
	DirAccess.make_dir_recursive_absolute(output_dir)
	return ResourceSaver.save(tips, output_dir.path_join("tips.tres")) == OK


func _process_traitor(input_path: String, output_dir: String) -> bool:
	var parser = WCSTraitorParser.new()
	var traitor = parser.parse(input_path)
	if traitor == null: return false
	DirAccess.make_dir_recursive_absolute(output_dir)
	return ResourceSaver.save(traitor, output_dir.path_join("traitor.tres")) == OK


func _process_weapon_expl(input_path: String, output_dir: String) -> bool:
	var parser = WCSWeaponExplParser.new()
	var data = parser.parse(input_path)
	if data == null: return false
	var generator = WeaponExplosionGenerator.new()
	var source_root = ProjectSettings.globalize_path(input_path.get_base_dir().get_base_dir())
	return generator.generate(data, output_dir, source_root)


func _process_localization(input_path: String, output_dir: String) -> bool:
	var parser = WCSLocalizationParser.new()
	return parser.convert(input_path, output_dir)
