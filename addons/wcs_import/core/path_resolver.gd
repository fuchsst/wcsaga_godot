class_name WCSPathResolver
extends RefCounted

## Handles path resolution for WCS assets.
## Ports logic from Python PathManager.

const MODEL_MAPPINGS = {
	# Kilrathi models
	"kif": ["fighter", "kilrathi"],
	"kib": ["bomber", "kilrathi"],
	"kim": ["missile", "kilrathi"],
	"kis": ["capital", "kilrathi"],
	"kb": ["station", "kilrathi"],
	# Terran models
	"tcf": ["fighter", "terran"],
	"tcb": ["bomber", "terran"],
	"tcm": ["missile", "terran"],
	"tcs": ["capital", "terran"],
	"tb": ["station", "terran"],
	# Pirate models
	"prf": ["fighter", "pirate"],
	"prs": ["capital", "pirate"],
	# Special weapons
	"f_": ["weapon", "effect"],
	"t_": ["weapon", "effect"],
}

const ASSET_MAPPINGS = {
	# Audio
	"music": ["audio", "music"],
	"briefing": ["audio", "briefing"],
	"comm": ["audio", "comm"],
	"sound": ["audio", "sfx"],
	# Video
	"intro": ["video", "cutscenes"],
	"outro": ["video", "cutscenes"],
	"movie": ["video", "cutscenes"],
	# Images
	"load": ["interface", "loading"],
	"hud": ["interface", "hud"],
	"icon": ["interface", "icons"],
	"medal": ["interface", "medals"],
	"bab": ["interface", "briefing"],
	"loadout": ["interface", "loadout"],
	"weapon": ["interface", "weapons"],
	# Animations
	"ani": ["interface", "animations"],
	# Effects
	"eff": ["effects", "sequences"],
	# Missions
	"fs2": ["scenes", "missions"],
	"fc2": ["scenes", "missions"],
	# Fiction
	"txt": ["interface", "fiction"],
	# Shaders
	"sdr": ["shaders", "misc"],
	# HUD Config
	"hcf": ["interface", "hud"],
	# Force Feedback
	"frc": ["data", "force_feedback"],
	# Fonts
	"vf": ["interface", "fonts"],
}

const SPECIAL_CASES = {
	"Stormfire": ["weapon", "special"],
	"shockwave": ["effect", "special"],
	"infyrno": ["weapon", "special"],
	"starfield": ["environment", "starfield"],
	"subspacenode": ["environment", "subspace_node"],
	"warp": ["effect", "warp"],
	"spherec": ["effect", "spherec"],
	"f_shockwave": ["effect", "shockwave_f"],
	"t_shockwave": ["effect", "shockwave_t"],
}

const MISC_MAPPINGS = {
	"asteroid_1": ["asteroid", "asteroid_1"],
	"cmeasure": ["weapon", "countermeasure"],
	"escape_pod": ["utility", "escape_pod"],
	"fire": ["effect", "fire"],
	"ghost": ["effect", "ghost"],
	"ghostmissile": ["weapon", "ghost_missile"],
	"kcargo": ["utility", "kilrathi_cargo"],
	"launcher": ["utility", "launcher"],
}


static func determine_output_path(filename: String) -> Array:
	var file_base = filename.get_file().get_basename()

	if file_base in SPECIAL_CASES:
		return SPECIAL_CASES[file_base]

	if (
		file_base.begins_with("ast")
		or file_base.begins_with("asta")
		or file_base.begins_with("astb")
	):
		var asteroid_id = ""
		if file_base.begins_with("asta"):
			asteroid_id = file_base.substr(4)
		elif file_base.begins_with("astb"):
			asteroid_id = file_base.substr(4)
		elif file_base.begins_with("ast"):
			asteroid_id = file_base.substr(3)

		if asteroid_id.is_empty():
			asteroid_id = "01"
		return ["asteroid", "asteroid_" + asteroid_id]

	if "debris" in file_base:
		# Simplified debris logic
		return ["debris", "misc"]

	if file_base.begins_with("sky_"):
		var faction = file_base.replace("sky_", "").replace("_atmosphere", "_atmosphere")
		return ["environment", faction]

	if file_base.begins_with("misc_"):
		var misc_name = file_base.replace("misc_", "")
		if misc_name in MISC_MAPPINGS:
			return MISC_MAPPINGS[misc_name]
		return ["utility", misc_name]

	for prefix in MODEL_MAPPINGS:
		if file_base.begins_with(prefix):
			return MODEL_MAPPINGS[prefix]

	return ["misc", "unknown"]


static func determine_asset_output_path(filename: String) -> Array:
	var ext = filename.get_extension().to_lower()
	var name = filename.to_lower()

	# Extension based checks
	if ext in ["wav", "ogg", "mp3"]:
		return ["audio", "misc"]
	elif ext in ["avi", "mve", "ogv"]:
		return ["video", "cutscenes"]
	elif ext in ["bmp", "jpg", "jpeg", "png", "tga", "pcx", "dds"]:
		return ["interface", "misc"]
	elif ext == "ani":
		return ["interface", "animations"]
	elif ext == "eff":
		return ["effects", "sequences"]
	elif ext in ["fs2", "fc2"]:
		return ["campaigns", "hermes/missions"]
	elif ext == "txt":
		return ["interface", "fiction"]
	elif ext == "sdr":
		return ["shaders", "misc"]
	elif ext == "hcf":
		return ["interface", "hud"]
	elif ext == "frc":
		return ["data", "force_feedback"]
	elif ext == "vf":
		return ["interface", "fonts"]

	# Pattern based checks
	for pattern in ASSET_MAPPINGS:
		if pattern in name:
			var mapping = ASSET_MAPPINGS[pattern]
			var category = mapping[0]

			if category == "audio" and not ext in ["wav", "ogg", "mp3"]:
				continue
			if category == "video" and not ext in ["avi", "mve", "ogv"]:
				continue

			return mapping

	return ["misc", "unknown"]
