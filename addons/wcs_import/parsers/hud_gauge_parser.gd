class_name WCSHudGaugeParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const HudGaugeResource = preload("res://scripts/resources/ui/hud/hud_gauge_resource.gd")

func _parse_content() -> Variant:
	var gauges: Array[HudGaugeResource] = []
	var current_section: String = ""
	var current_resolution: Vector2i = Vector2i(1024, 768)
	var current_ship_name: String = ""
	
	# Stack for nested gauges
	var gauge_stack: Array[HudGaugeResource] = []
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end" or line == "#End":
				current_section = ""
				current_ship_name = "" # Reset ship name on section end
				gauge_stack.clear()
				continue
			current_section = line.substr(1).strip_edges()
			gauge_stack.clear()
			continue
			
		if current_section == "Custom Gauges":
			if line.begins_with("$Name:"):
				var gauge = HudGaugeResource.new()
				gauge.name = _extract_string_value(line, "$Name:")
				gauge.section = current_section
				gauges.append(gauge)
				gauge_stack = [gauge]
			elif not gauge_stack.is_empty():
				var gauge = gauge_stack.back()
				if line.begins_with("+Default1024x:"):
					gauge.position.x = _extract_int_value(line, "+Default1024x:")
					gauge.base_resolution = Vector2i(1024, 768)
				elif line.begins_with("+Default1024y:"):
					gauge.position.y = _extract_int_value(line, "+Default1024y:")
				elif line.begins_with("+Parent:"):
					gauge.parent = _extract_string_value(line, "+Parent:")
					
		elif current_section == "Main Gauges" or current_section == "Ship Main Gauges":
			if line.begins_with("$Ship:"):
				current_ship_name = _extract_string_value(line, "$Ship:")
			elif line.begins_with("$Default:"):
				current_resolution = _parse_vector2_int_parens(line.substr(9))
			elif line.begins_with("$"):
				# $Gauge Name: (x y)
				var parts = line.split(":")
				if parts.size() >= 2:
					var gauge_name = parts[0].substr(1).strip_edges()
					var pos_str = parts[1].strip_edges()
					
					var gauge = HudGaugeResource.new()
					gauge.name = gauge_name
					gauge.section = current_section
					gauge.ship_name = current_ship_name
					gauge.base_resolution = current_resolution
					gauge.position = _parse_vector2_int_parens(pos_str)
					gauges.append(gauge)
					
		elif current_section == "Gauges" or current_section == "Ship Gauges":
			if line.begins_with("$Ship:"):
				current_ship_name = _extract_string_value(line, "$Ship:")
			elif line.begins_with("$Default:"):
				current_resolution = _parse_vector2_int_parens(line.substr(9))
			elif line.begins_with("$Gauge:"):
				var gauge = HudGaugeResource.new()
				gauge.name = _extract_string_value(line, "$Gauge:")
				gauge.section = current_section
				gauge.ship_name = current_ship_name
				gauge.base_resolution = current_resolution
				gauges.append(gauge)
				gauge_stack = [gauge]
			elif line.begins_with("$") and not gauge_stack.is_empty():
				# Sub-gauge (e.g., $HP_Text:)
				var parts = line.split(":")
				var sub_name = parts[0].substr(1).strip_edges()
				var pos_str = parts[1].strip_edges() if parts.size() > 1 else ""
				
				var sub_gauge = HudGaugeResource.new()
				sub_gauge.name = sub_name
				sub_gauge.section = current_section
				sub_gauge.ship_name = current_ship_name
				sub_gauge.base_resolution = current_resolution
				if not pos_str.is_empty():
					sub_gauge.position = _parse_vector2_int_parens(pos_str)
				
				# Add to parent
				gauge_stack[0].sub_gauges.append(sub_gauge)
				# Push to stack to handle its attributes
				if gauge_stack.size() > 1:
					gauge_stack.pop_back() # Only support 1 level of nesting for attributes for now?
				gauge_stack.append(sub_gauge)
				
			elif not gauge_stack.is_empty():
				var gauge = gauge_stack.back()
				if line.begins_with("+Text:"):
					gauge.text = _extract_string_value(line, "+Text:")
				elif line.begins_with("+Image:"):
					gauge.image = _extract_string_value(line, "+Image:")
				elif line.begins_with("+Color:"):
					gauge.color = _parse_color_rgb(line.substr(7))
					gauge.use_color = true
				elif line.begins_with("+Inherit Color from:"):
					gauge.inherit_color_from = _extract_string_value(line, "+Inherit Color from:")

	return gauges

func _parse_vector2_int_parens(s: String) -> Vector2i:
	var clean = s.replace("(", "").replace(")", "").replace(",", " ").strip_edges()
	var parts = clean.split(" ", false)
	if parts.size() >= 2:
		return Vector2i(parts[0].to_int(), parts[1].to_int())
	return Vector2i.ZERO

func _parse_color_rgb(s: String) -> Color:
	var clean = s.replace(",", " ").strip_edges()
	var parts = clean.split(" ", false)
	if parts.size() >= 3:
		return Color(parts[0].to_float() / 255.0, parts[1].to_float() / 255.0, parts[2].to_float() / 255.0)
	return Color.WHITE
