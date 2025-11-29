class_name WCSSpeciesParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const SpeciesData = preload("res://scripts/resources/species/species_data.gd")

func _parse_content() -> Variant:
	var species_list: Array[SpeciesData] = []
	var current_species: SpeciesData = null
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Species_Name:"):
			current_species = SpeciesData.new()
			current_species.species_name = _extract_string_value(line, "$Species_Name:")
			species_list.append(current_species)
				
	return species_list
