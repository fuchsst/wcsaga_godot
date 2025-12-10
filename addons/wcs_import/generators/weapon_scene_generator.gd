class_name WeaponSceneGenerator
extends RefCounted

## Generates weapon scenes (.tscn) with proper script attachments using text-based generation.
## This approach ensures scripts are correctly serialized as ext_resource entries.
## Enhanced to support:
## - Beam-specific scene structure (no collision area, raycast-based)
## - Audio nodes for weapon sounds
## - Light nodes for glowing projectiles
## - Pre-generated laser meshes

const WCSWeaponData = preload("res://scripts/resources/weapons/weapon_data.gd")

# Script paths for weapon types
const PROJECTILE_SCRIPT = "res://scripts/entities/weapons/projectile_weapon.gd"
const MISSILE_SCRIPT = "res://scripts/entities/weapons/missile_weapon.gd"
const BEAM_SCRIPT = "res://scripts/entities/weapons/beam_weapon.gd"
const FLAK_SCRIPT = "res://scripts/entities/weapons/flak_weapon.gd"
const BASE_WEAPON_SCRIPT = "res://scripts/entities/weapons/base_weapon.gd"


func generate_scene(weapon_data: WCSWeaponData, output_root: String) -> void:
	# Determine folder structure: target/assets/weapons/<category>/<faction>/<weapon>/
	var category_slug = weapon_data.category.to_lower().replace(" ", "_")
	var faction_slug = weapon_data.manufacturer_species.to_lower()

	if faction_slug.is_empty() or faction_slug == "unknown":
		faction_slug = "common"

	var weapon_slug = weapon_data.id.to_lower().replace(" ", "_")

	var target_dir = output_root.path_join(category_slug).path_join(faction_slug).path_join(
		weapon_slug
	)

	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)

	# Determine paths
	var scene_filename = weapon_slug + ".tscn"
	var scene_abs_path = target_dir.path_join(scene_filename)
	var resource_filename = weapon_slug + ".tres"
	var resource_abs_path = target_dir.path_join(resource_filename)

	# Convert to res:// paths
	var godot_root = ProjectSettings.globalize_path("res://")
	var scene_res_path = _to_res_path(
		scene_abs_path, godot_root, category_slug, faction_slug, weapon_slug, scene_filename
	)
	var resource_res_path = _to_res_path(
		resource_abs_path, godot_root, category_slug, faction_slug, weapon_slug, resource_filename
	)

	# Set scene_path on weapon_data for runtime use
	weapon_data.scene_path = scene_res_path

	# Save Resource first
	ResourceSaver.save(weapon_data, resource_abs_path)
	weapon_data.take_over_path(resource_abs_path)
	print("Saved weapon resource to: " + resource_abs_path)

	# Determine weapon type and script path
	var script_path = _get_script_path(weapon_data)
	var weapon_type_name = _get_weapon_type_name(weapon_data)

	# Calculate collision radius
	var collision_radius = _get_collision_radius(weapon_data)

	# Check for model
	var model_res_path = ""
	if _has_valid_model(weapon_data, target_dir):
		var model_filename = weapon_data.projectile_model
		model_res_path = _to_res_path(
			target_dir.path_join(model_filename),
			godot_root,
			category_slug,
			faction_slug,
			weapon_slug,
			model_filename
		)

	# Generate scene text based on weapon type
	var scene_text: String
	if weapon_data.is_beam:
		scene_text = _generate_beam_scene_text(
			weapon_type_name, script_path, resource_res_path, weapon_data
		)
	else:
		scene_text = _generate_projectile_scene_text(
			weapon_type_name,
			script_path,
			resource_res_path,
			collision_radius,
			model_res_path,
			weapon_data
		)

	# Write scene file
	var file = FileAccess.open(scene_abs_path, FileAccess.WRITE)
	if file:
		file.store_string(scene_text)
		file.close()
		print("Saved weapon scene to: " + scene_abs_path)
	else:
		push_error("Failed to write weapon scene: " + scene_abs_path)


func _to_res_path(
	abs_path: String,
	godot_root: String,
	_category: String,
	_faction: String,
	_weapon: String,
	_filename: String
) -> String:
	# Normalize paths - remove trailing slashes for consistent comparison
	var normalized_root = godot_root.rstrip("/")
	var normalized_path = abs_path.rstrip("/")

	if normalized_path.begins_with(normalized_root):
		var relative = normalized_path.substr(normalized_root.length())
		# Ensure it starts with /
		if not relative.begins_with("/"):
			relative = "/" + relative
		return "res:/" + relative

	# If we can't determine the res:// path, log warning and use absolute
	push_warning("Could not convert to res:// path: " + abs_path)
	return abs_path


func _get_script_path(weapon_data: WCSWeaponData) -> String:
	if weapon_data.is_beam:
		return BEAM_SCRIPT
	if weapon_data.flak_config != null:
		return FLAK_SCRIPT
	if weapon_data.homing_type > 0:
		return MISSILE_SCRIPT
	return PROJECTILE_SCRIPT


func _get_weapon_type_name(weapon_data: WCSWeaponData) -> String:
	if weapon_data.is_beam:
		return "BeamWeapon"
	if weapon_data.flak_config != null:
		return "FlakWeapon"
	if weapon_data.homing_type > 0:
		return "MissileWeapon"
	return "ProjectileWeapon"


func _get_collision_radius(weapon_data: WCSWeaponData) -> float:
	if weapon_data.inner_radius > 0:
		return weapon_data.inner_radius
	if weapon_data.arm_radius > 0:
		return weapon_data.arm_radius
	if weapon_data.laser_head_radius > 0:
		return weapon_data.laser_head_radius
	return 0.5 # Default


func _has_valid_model(weapon_data: WCSWeaponData, target_dir: String) -> bool:
	if weapon_data.projectile_model.is_empty():
		return false
	if weapon_data.projectile_model == "none":
		return false
	if not weapon_data.projectile_model.ends_with(".gltf"):
		return false
	var model_path = target_dir.path_join(weapon_data.projectile_model)
	return FileAccess.file_exists(model_path)


func _should_add_light(weapon_data: WCSWeaponData) -> bool:
	# Add light for glowing weapons (lasers, energy weapons)
	if weapon_data.laser_glow:
		return true
	if weapon_data.laser_color and weapon_data.laser_color != Color.BLACK:
		return true
	return false


func _should_add_audio(weapon_data: WCSWeaponData) -> bool:
	# Add audio node if fire sound AudioStream is set (resolved during weapon generation)
	return weapon_data.fire_sound != null


# ==============================================================================
# BEAM SCENE GENERATION
# ==============================================================================


func _generate_beam_scene_text(
	node_name: String, script_path: String, resource_path: String, weapon_data: WCSWeaponData
) -> String:
	# Beam weapons have different structure:
	# - No HitArea (uses raycast instead)
	# - BeamMesh child created at runtime by script
	# - AudioStreamPlayer3D for beam sound
	var load_steps = 2 # Script + Resource
	var has_audio = _should_add_audio(weapon_data)

	var lines: Array[String] = []

	# Header
	lines.append("[gd_scene load_steps=%d format=3]" % load_steps)
	lines.append("")

	# External resources
	var ext_id = 1
	var script_ext = '[ext_resource type="Script" path="%s" id="script_%d"]'
	lines.append(script_ext % [script_path, ext_id])
	var script_id = "script_%d" % ext_id
	ext_id += 1

	lines.append("")

	# Root node with script (BeamWeapon creates its own mesh at runtime)
	lines.append('[node name="%s" type="Node3D"]' % node_name)
	lines.append('script = ExtResource("%s")' % script_id)
	lines.append('metadata/weapon_data_path = "%s"' % resource_path)
	lines.append("")

	# Add AudioStreamPlayer3D for beam sound
	if has_audio:
		lines.append('[node name="BeamAudio" type="AudioStreamPlayer3D" parent="."]')
		lines.append('bus = &"SFX"')
		lines.append("unit_size = 20.0")
		lines.append("max_distance = 500.0")
		lines.append("")

	return "\n".join(lines)


# ==============================================================================
# PROJECTILE SCENE GENERATION
# ==============================================================================


func _generate_projectile_scene_text(
	node_name: String,
	script_path: String,
	resource_path: String,
	collision_radius: float,
	model_path: String,
	weapon_data: WCSWeaponData
) -> String:
	# Count external resources
	var load_steps = 3 # Script + Resource + SphereShape3D
	var has_model = not model_path.is_empty()
	var has_light = _should_add_light(weapon_data)
	var has_audio = _should_add_audio(weapon_data)

	if has_model:
		load_steps += 1

	var lines: Array[String] = []

	# Header
	lines.append("[gd_scene load_steps=%d format=3]" % load_steps)
	lines.append("")

	# External resources
	var ext_id = 1
	var script_ext = '[ext_resource type="Script" path="%s" id="script_%d"]'
	lines.append(script_ext % [script_path, ext_id])
	var script_id = "script_%d" % ext_id
	ext_id += 1

	var res_ext = '[ext_resource type="Resource" path="%s" id="weapon_data_%d"]'
	lines.append(res_ext % [resource_path, ext_id])
	# Note: resource_id not needed for projectile scenes as weapon_data is loaded via metadata
	ext_id += 1

	var model_id = ""
	if has_model:
		var model_ext = '[ext_resource type="PackedScene" path="%s" id="model_%d"]'
		lines.append(model_ext % [model_path, ext_id])
		model_id = "model_%d" % ext_id
		ext_id += 1

	lines.append("")

	# Sub-resources
	lines.append('[sub_resource type="SphereShape3D" id="SphereShape3D_collision"]')
	if collision_radius != 1.0: # Only specify if not default
		lines.append("radius = %s" % _float_to_str(collision_radius))
	lines.append("")

	# Root node with script
	lines.append('[node name="%s" type="Node3D"]' % node_name)
	lines.append('script = ExtResource("%s")' % script_id)
	lines.append('metadata/weapon_data_path = "%s"' % resource_path)
	lines.append("")

	# HitArea
	lines.append('[node name="HitArea" type="Area3D" parent="."]')
	lines.append("collision_layer = 0")
	lines.append("collision_mask = 0")
	lines.append("monitorable = true")
	lines.append("monitoring = true")
	lines.append("")

	# CollisionShape
	lines.append('[node name="CollisionShape" type="CollisionShape3D" parent="HitArea"]')
	lines.append('shape = SubResource("SphereShape3D_collision")')
	lines.append("")

	# Visuals (model instance) if available
	if has_model:
		lines.append('[node name="Visuals" parent="." instance=ExtResource("%s")]' % model_id)
		lines.append("")

	# Light node for glowing projectiles
	if has_light:
		lines.append('[node name="ProjectileLight" type="OmniLight3D" parent="."]')
		var light_color = weapon_data.laser_color if weapon_data.laser_color else Color.WHITE
		lines.append(
			(
				"light_color = Color(%s, %s, %s, 1)"
				% [
					_float_to_str(light_color.r),
					_float_to_str(light_color.g),
					_float_to_str(light_color.b)
				]
			)
		)
		lines.append("light_energy = 2.0")
		lines.append("omni_range = 5.0")
		lines.append("omni_attenuation = 1.5")
		lines.append("shadow_enabled = false")
		lines.append("")

	# Audio node for fire sound
	if has_audio:
		lines.append('[node name="ProjectileAudio" type="AudioStreamPlayer3D" parent="."]')
		lines.append('bus = &"SFX"')
		lines.append("unit_size = 10.0")
		lines.append("max_distance = 300.0")
		lines.append("autoplay = true")
		lines.append("")

	return "\n".join(lines)


func _float_to_str(value: float) -> String:
	# Format float for TSCN (avoid scientific notation, limit decimals)
	if value == floorf(value):
		return str(int(value)) + ".0"
	return "%.4f" % value
