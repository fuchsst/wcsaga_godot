class_name WCSLightningParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const LightningResource = preload("res://scripts/resources/effects/lightning/lightning_resource.gd")

func _parse_content() -> Variant:
	var lightnings: Array[LightningResource] = []
	var current_lightning: LightningResource = null
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Name:"):
			current_lightning = LightningResource.new()
			current_lightning.name = _extract_string_value(line, "$Name:")
			lightnings.append(current_lightning)
		elif current_lightning:
			if line.begins_with("+Texture:"):
				# Handle texture
				pass
			elif line.begins_with("+Delay:"):
				current_lightning.delay = _extract_float_value(line, "+Delay:")
			elif line.begins_with("+Duration:"):
				current_lightning.duration = _extract_float_value(line, "+Duration:")
				
	return lightnings
