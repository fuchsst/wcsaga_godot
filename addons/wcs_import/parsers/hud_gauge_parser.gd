class_name WCSHudGaugeParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const HudGaugeResource = preload("res://scripts/resources/ui/hud_gauge_resource.gd")

func _parse_content() -> Variant:
	var gauges: Array[HudGaugeResource] = []
	var current_gauge: HudGaugeResource = null
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Gauge Name:"):
			current_gauge = HudGaugeResource.new()
			current_gauge.gauge_name = _extract_string_value(line, "$Gauge Name:")
			gauges.append(current_gauge)
		elif current_gauge:
			if line.begins_with("+Pos:"):
				current_gauge.position = _parse_vector2_int(line)
			elif line.begins_with("+Filename:"):
				current_gauge.filename = _extract_string_value(line, "+Filename:")
				
	return gauges

func _parse_vector2_int(line: String) -> Vector2i:
	var clean = line.replace("+Pos:", "").replace(",", " ").strip_edges()
	var parts = clean.split(" ", false)
	if parts.size() >= 2:
		return Vector2i(parts[0].to_int(), parts[1].to_int())
	return Vector2i.ZERO
