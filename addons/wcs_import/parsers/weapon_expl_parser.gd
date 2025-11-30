extends "res://addons/wcs_import/parsers/base_parser.gd"

const WeaponExplosionResource = preload("res://scripts/resources/effects/weapon_expl_resource.gd")


func parse(path: String) -> Variant:
	if not load_file(path):
		return null
	return _parse_content()


func _parse_content() -> Variant:
	var resources: Array[WeaponExplosionResource] = []
	var current_resource: WeaponExplosionResource = null

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			if line == "#End":
				break
			continue

		if line.begins_with("$Name:"):
			current_resource = WeaponExplosionResource.new()
			var raw_name = _extract_string_value(line, "$Name:")
			# Strip comments
			if raw_name.contains(";"):
				raw_name = raw_name.split(";")[0]
			current_resource.name = raw_name.strip_edges()
			resources.append(current_resource)

		elif current_resource:
			if line.begins_with("$LOD:"):
				current_resource.lod_count = _extract_int_value(line, "$LOD:")

	return resources
