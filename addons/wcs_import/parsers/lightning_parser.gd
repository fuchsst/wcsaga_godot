class_name WCSLightningParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const LightningResource = preload("res://scripts/resources/effects/lightning_resource.gd")


func _parse_content() -> Variant:
	var resources: Array[LightningResource] = []
	var current_resource: LightningResource = null

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			if line == "#Bolts end" or line == "#Storms end":
				current_resource = null
				continue
			continue

		# Bolt Definition
		if line.begins_with("$Bolt:"):
			current_resource = LightningResource.new()
			current_resource.type = LightningResource.LightningType.BOLT
			var raw_name = _extract_string_value(line, "$Bolt:")
			current_resource.name = raw_name.split(";")[0].strip_edges()
			resources.append(current_resource)

		# Storm Definition
		elif line.begins_with("$Storm:"):
			current_resource = LightningResource.new()
			current_resource.type = LightningResource.LightningType.STORM
			var raw_name = _extract_string_value(line, "$Storm:")
			current_resource.name = raw_name.split(";")[0].strip_edges()
			resources.append(current_resource)

		elif current_resource:
			if current_resource.type == LightningResource.LightningType.BOLT:
				_parse_bolt_property(line, current_resource)
			else:
				_parse_storm_property(line, current_resource)

	return resources


func _parse_bolt_property(line: String, res: LightningResource) -> void:
	if line.begins_with("+b_scale:"):
		res.b_scale = _extract_float_value(line, "+b_scale:")
	elif line.begins_with("+b_shrink:"):
		res.b_shrink = _extract_float_value(line, "+b_shrink:")
	elif line.begins_with("+b_poly_pct:"):
		res.b_poly_pct = _extract_float_value(line, "+b_poly_pct:")
	elif line.begins_with("+b_rand:"):
		res.b_rand = _extract_float_value(line, "+b_rand:")
	elif line.begins_with("+b_add:"):
		res.b_add = _extract_float_value(line, "+b_add:")
	elif line.begins_with("+b_strikes:"):
		res.b_strikes = _extract_int_value(line, "+b_strikes:")
	elif line.begins_with("+b_lifetime:"):
		res.b_lifetime = _extract_float_value(line, "+b_lifetime:") / 1000.0  # Convert ms to s
	elif line.begins_with("+b_noise:"):
		res.b_noise = _extract_float_value(line, "+b_noise:")
	elif line.begins_with("+b_emp:"):
		var parts = _extract_string_value(line, "+b_emp:").split(" ", false)
		if parts.size() >= 2:
			res.b_emp_intensity = parts[0].to_float()
			res.b_emp_time = parts[1].to_float()
	elif line.begins_with("+b_texture:"):
		res.b_texture = _extract_string_value(line, "+b_texture:")
	elif line.begins_with("+b_glow:"):
		res.b_glow = _extract_string_value(line, "+b_glow:")
	elif line.begins_with("+b_bright:"):
		res.b_bright = _extract_float_value(line, "+b_bright:")


func _parse_storm_property(line: String, res: LightningResource) -> void:
	if line.begins_with("+bolt:"):
		res.s_bolt_types.append(_extract_string_value(line, "+bolt:"))
	elif line.begins_with("+flavor:"):
		var parts = _extract_string_value(line, "+flavor:").split(" ", false)
		if parts.size() >= 3:
			res.s_flavor = Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	elif line.begins_with("+random_freq:"):
		var parts = _extract_string_value(line, "+random_freq:").split(" ", false)
		if parts.size() >= 2:
			res.s_random_freq_min = parts[0].to_float() / 1000.0
			res.s_random_freq_max = parts[1].to_float() / 1000.0
	elif line.begins_with("+random_count:"):
		var parts = _extract_string_value(line, "+random_count:").split(" ", false)
		if parts.size() >= 2:
			res.s_random_count_min = parts[0].to_int()
			res.s_random_count_max = parts[1].to_int()
