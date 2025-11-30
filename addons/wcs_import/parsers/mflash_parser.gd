extends "res://addons/wcs_import/parsers/base_parser.gd"

const MuzzleFlashResource = preload("res://scripts/resources/effects/muzzle_flash_resource.gd")


func parse(path: String) -> Variant:
	if not load_file(path):
		return null
	return _parse_content()


func _parse_content() -> Variant:
	var resources: Array[MuzzleFlashResource] = []
	var current_resource: MuzzleFlashResource = null

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			if line == "#end":
				break
			continue

		if line.begins_with("$Mflash:"):
			current_resource = MuzzleFlashResource.new()
			resources.append(current_resource)

		elif current_resource:
			_parse_property(line, current_resource)

	return resources


func _parse_property(line: String, res: MuzzleFlashResource) -> void:
	if line.begins_with("+name:"):
		res.name = _extract_string_value(line, "+name:")
	elif line.begins_with("+blob_name:"):
		var blob = MuzzleFlashResource.MuzzleFlashBlob.new()
		blob.name = _extract_string_value(line, "+blob_name:")
		res.blobs.append(blob)
	elif line.begins_with("+blob_offset:") and not res.blobs.is_empty():
		res.blobs.back().offset = _extract_float_value(line, "+blob_offset:")
	elif line.begins_with("+blob_radius:") and not res.blobs.is_empty():
		res.blobs.back().radius = _extract_float_value(line, "+blob_radius:")
