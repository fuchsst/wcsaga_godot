class_name WCSHudConfigParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const HudConfigResource = preload("res://scripts/resources/ui/hud/hud_config_resource.gd")
const HudGaugeOverride = preload("res://scripts/resources/ui/hud/hud_gauge_override.gd")


func _parse_content() -> Variant:
	var config = HudConfigResource.new()
	var current_gauge_name: String = ""
	var current_override: HudGaugeOverride = null

	# Temporary dictionary to track existing overrides by name to avoid duplicates if needed,
	# or just append. The HCF format usually lists gauges sequentially.
	# We'll append to the list.

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			continue

		if line.begins_with("+Gauge:"):
			current_gauge_name = _extract_string_value(line, "+Gauge:")
			current_override = HudGaugeOverride.new()
			current_override.gauge_name = current_gauge_name
			config.gauges.append(current_override)

		elif current_override:
			if line.begins_with("+RGBA:"):
				var color = _parse_color(line.substr(6))
				current_override.color = color
				current_override.override_color = true

	return config
