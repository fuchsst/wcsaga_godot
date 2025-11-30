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
				var tex_name = _extract_string_value(line, "+Debris_Texture:")
				current_species.debris_texture = _load_texture(tex_name)
			elif line.begins_with("+Shield_Hit_ani:"):
				var anim_name = _extract_string_value(line, "+Shield_Hit_ani:")
				current_species.shield_hit_anim = _load_animation(anim_name)
			
			# Thruster Anims
			elif line.begins_with("+Pri_Normal:"):
				var anim_name = _extract_string_value(line, "+Pri_Normal:")
				current_species.thruster_normal = _load_animation(anim_name)
			elif line.begins_with("+Pri_Afterburn:"):
				var anim_name = _extract_string_value(line, "+Pri_Afterburn:")
				current_species.thruster_afterburn = _load_animation(anim_name)
			elif line.begins_with("+Sec_Normal:"):
				var anim_name = _extract_string_value(line, "+Sec_Normal:")
				current_species.thruster_secondary_normal = _load_animation(anim_name)
			elif line.begins_with("+Sec_Afterburn:"):
				var anim_name = _extract_string_value(line, "+Sec_Afterburn:")
				current_species.thruster_secondary_afterburn = _load_animation(anim_name)
			elif line.begins_with("+Ter_Normal:"):
				var anim_name = _extract_string_value(line, "+Ter_Normal:")
				current_species.thruster_tertiary_normal = _load_animation(anim_name)
			elif line.begins_with("+Ter_Afterburn:"):
				var anim_name = _extract_string_value(line, "+Ter_Afterburn:")
				current_species.thruster_tertiary_afterburn = _load_animation(anim_name)
				
			# Thruster Glows
			elif line.begins_with("+Normal:"):
				var tex_name = _extract_string_value(line, "+Normal:")
				current_species.glow_normal = _load_texture(tex_name)
			elif line.begins_with("+Afterburn:"):
				var tex_name = _extract_string_value(line, "+Afterburn:")
				current_species.glow_afterburn = _load_texture(tex_name)
				
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
