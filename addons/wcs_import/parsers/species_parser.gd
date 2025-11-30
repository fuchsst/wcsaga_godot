class_name WCSSpeciesParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const SpeciesData = preload("res://scripts/resources/species/species_data.gd")
const SpeciesManifest = preload("res://scripts/resources/species/species_manifest.gd")

func _parse_content() -> Variant:
	var manifest = SpeciesManifest.new()
	var current_species: SpeciesData = null
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line.to_lower() == "#end":
				break
			continue
			
		if line.begins_with("$Species_Name:"):
			current_species = SpeciesData.new()
			current_species.species_name = _extract_string_value(line, "$Species_Name:")
			manifest.species_list.append(current_species)
			
		elif current_species:
			if line.begins_with("$Default IFF:"):
				current_species.default_iff = _extract_string_value(line, "$Default IFF:")
			elif line.begins_with("$FRED Color:") or line.begins_with("$FRED Colour:"):
				current_species.fred_color = _parse_color(line)
			elif line.begins_with("+Debris_Texture:"):
				current_species.set_meta("debris_texture_filename", _extract_string_value(line, "+Debris_Texture:"))
			elif line.begins_with("+Shield_Hit_ani:"):
				current_species.set_meta("shield_hit_anim_filename", _extract_string_value(line, "+Shield_Hit_ani:"))
			
			# Thruster Anims
			elif line.begins_with("+Pri_Normal:"):
				current_species.set_meta("thruster_normal_filename", _extract_string_value(line, "+Pri_Normal:"))
			elif line.begins_with("+Pri_Afterburn:"):
				current_species.set_meta("thruster_afterburn_filename", _extract_string_value(line, "+Pri_Afterburn:"))
			elif line.begins_with("+Sec_Normal:"):
				current_species.set_meta("thruster_secondary_normal_filename", _extract_string_value(line, "+Sec_Normal:"))
			elif line.begins_with("+Sec_Afterburn:"):
				current_species.set_meta("thruster_secondary_afterburn_filename", _extract_string_value(line, "+Sec_Afterburn:"))
			elif line.begins_with("+Ter_Normal:"):
				current_species.set_meta("thruster_tertiary_normal_filename", _extract_string_value(line, "+Ter_Normal:"))
			elif line.begins_with("+Ter_Afterburn:"):
				current_species.set_meta("thruster_tertiary_afterburn_filename", _extract_string_value(line, "+Ter_Afterburn:"))
				
			# Thruster Glows
			elif line.begins_with("+Normal:"):
				current_species.set_meta("glow_normal_filename", _extract_string_value(line, "+Normal:"))
			elif line.begins_with("+Afterburn:"):
				current_species.set_meta("glow_afterburn_filename", _extract_string_value(line, "+Afterburn:"))
				
			elif line.begins_with("$AwacsMultiplier:"):
				current_species.awacs_multiplier = _extract_float_value(line, "$AwacsMultiplier:")
				
	return manifest

func _load_texture(name: String) -> Texture2D:
	if name.is_empty():
		return null
	# Try to load from assets/effects/ or assets/species/
	# This is a placeholder - actual path resolution should happen via AssetPathResolver
	# But since we are in GDScript, we rely on the resource loader finding it if it's in the project
	# For now, we return null as the actual asset loading might need a more complex system
	# or we assume assets are already imported at a standard location.
	return null

func _load_animation(name: String) -> SpriteFrames:
	if name.is_empty():
		return null
	return null
