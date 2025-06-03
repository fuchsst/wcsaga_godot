class_name MaterialData
extends BaseAssetData

## Material definition converted from WCS to Godot-compatible format
## Represents material properties for StandardMaterial3D creation and management

@export var material_name: String
@export var material_type: MaterialType
@export var diffuse_texture_path: String
@export var normal_texture_path: String
@export var specular_texture_path: String
@export var emission_texture_path: String
@export var roughness_texture_path: String

# PBR material properties (converted from WCS)
@export var metallic: float = 0.0
@export var roughness: float = 0.5
@export var emission_energy: float = 0.0
@export var transparency_mode: String = "OPAQUE"
@export var alpha_scissor_threshold: float = 0.0
@export var double_sided: bool = false

# Color properties
@export var albedo_color: Color = Color.WHITE
@export var emission_color: Color = Color.BLACK

# Advanced material properties
@export var rim_enabled: bool = false
@export var rim_tint: float = 0.5
@export var clearcoat_enabled: bool = false
@export var clearcoat_roughness: float = 0.0
@export var anisotropy_enabled: bool = false
@export var anisotropy_flowmap: String

# Special material features
@export var animated_uv: bool = false
@export var uv_scroll_speed: Vector2 = Vector2.ZERO
@export var blend_mode: String = "MIX"
@export var cull_mode: String = "BACK"

enum MaterialType {
	HULL,          # Ship hull materials
	COCKPIT,       # Transparent cockpit materials
	WEAPON,        # Weapon and turret materials
	ENGINE,        # Engine and thruster materials
	SHIELD,        # Energy shield materials
	SPACE,         # Space environment materials
	EFFECT,        # Visual effect materials
	GENERIC        # General purpose materials
}

func _init() -> void:
	super()
	asset_type = AssetTypes.Type.MATERIAL

func is_valid() -> bool:
	var errors: Array[String] = get_validation_errors()
	return errors.is_empty()

func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	
	if material_name.is_empty():
		errors.append("Material name cannot be empty")
	
	if metallic < 0.0 or metallic > 1.0:
		errors.append("Metallic must be 0.0-1.0")
	
	if roughness < 0.0 or roughness > 1.0:
		errors.append("Roughness must be 0.0-1.0")
	
	if emission_energy < 0.0:
		errors.append("Emission energy cannot be negative")
	
	if alpha_scissor_threshold < 0.0 or alpha_scissor_threshold > 1.0:
		errors.append("Alpha scissor threshold must be 0.0-1.0")
	
	# Validate texture paths if not empty
	if not diffuse_texture_path.is_empty() and not _is_valid_texture_path(diffuse_texture_path):
		errors.append("Invalid diffuse texture path: " + diffuse_texture_path)
	
	if not normal_texture_path.is_empty() and not _is_valid_texture_path(normal_texture_path):
		errors.append("Invalid normal texture path: " + normal_texture_path)
	
	# Validate transparency mode
	if transparency_mode not in ["OPAQUE", "ALPHA", "ALPHA_SCISSOR"]:
		errors.append("Invalid transparency mode: " + transparency_mode)
	
	# Validate blend mode
	if blend_mode not in ["MIX", "ADD", "SUB", "MUL"]:
		errors.append("Invalid blend mode: " + blend_mode)
	
	# Validate cull mode
	if cull_mode not in ["BACK", "FRONT", "DISABLED"]:
		errors.append("Invalid cull mode: " + cull_mode)
	
	return errors

func _is_valid_texture_path(texture_path: String) -> bool:
	# Check if texture path exists or can be loaded
	return FileAccess.file_exists(texture_path) or ResourceLoader.exists(texture_path)

func get_material_type_name() -> String:
	match material_type:
		MaterialType.HULL:
			return "Hull"
		MaterialType.COCKPIT:
			return "Cockpit"
		MaterialType.WEAPON:
			return "Weapon"
		MaterialType.ENGINE:
			return "Engine"
		MaterialType.SHIELD:
			return "Shield"
		MaterialType.SPACE:
			return "Space"
		MaterialType.EFFECT:
			return "Effect"
		MaterialType.GENERIC:
			return "Generic"
		_:
			return "Unknown"

func is_transparent() -> bool:
	return transparency_mode in ["ALPHA", "ALPHA_SCISSOR"] or alpha_scissor_threshold > 0.0

func has_emission() -> bool:
	return emission_energy > 0.0 or emission_color != Color.BLACK or not emission_texture_path.is_empty()

func requires_special_rendering() -> bool:
	return is_transparent() or has_emission() or blend_mode != "MIX" or double_sided

func create_standard_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = material_name
	
	# Basic PBR properties
	material.metallic = metallic
	material.roughness = roughness
	material.albedo_color = albedo_color
	
	# Transparency
	match transparency_mode:
		"ALPHA":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"ALPHA_SCISSOR":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = alpha_scissor_threshold
		"OPAQUE":
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	
	# Emission
	if has_emission():
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy = emission_energy
	
	# Blend mode
	match blend_mode:
		"ADD":
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		"SUB":
			material.blend_mode = BaseMaterial3D.BLEND_MODE_SUB
		"MUL":
			material.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		"MIX":
			material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	
	# Cull mode
	match cull_mode:
		"FRONT":
			material.cull_mode = BaseMaterial3D.CULL_FRONT
		"DISABLED":
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		"BACK":
			material.cull_mode = BaseMaterial3D.CULL_BACK
	
	# Advanced features
	if rim_enabled:
		material.rim_enabled = true
		material.rim_tint = rim_tint
	
	if clearcoat_enabled:
		material.clearcoat_enabled = true
		material.clearcoat_roughness = clearcoat_roughness
	
	if anisotropy_enabled:
		material.anisotropy_enabled = true
	
	# Load textures
	_apply_textures_to_material(material)
	
	return material

func _apply_textures_to_material(material: StandardMaterial3D) -> void:
	# Diffuse/Albedo texture
	if not diffuse_texture_path.is_empty():
		var texture: Texture2D = _load_texture_safe(diffuse_texture_path)
		if texture:
			material.albedo_texture = texture
	
	# Normal texture
	if not normal_texture_path.is_empty():
		var texture: Texture2D = _load_texture_safe(normal_texture_path)
		if texture:
			material.normal_texture = texture
			material.normal_enabled = true
	
	# Specular/Metallic texture
	if not specular_texture_path.is_empty():
		var texture: Texture2D = _load_texture_safe(specular_texture_path)
		if texture:
			material.metallic_texture = texture
	
	# Emission texture
	if not emission_texture_path.is_empty():
		var texture: Texture2D = _load_texture_safe(emission_texture_path)
		if texture:
			material.emission_texture = texture
			material.emission_enabled = true
	
	# Roughness texture
	if not roughness_texture_path.is_empty():
		var texture: Texture2D = _load_texture_safe(roughness_texture_path)
		if texture:
			material.roughness_texture = texture

func _load_texture_safe(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null
	
	var texture: Texture2D = null
	
	# Try loading from resources
	if ResourceLoader.exists(texture_path):
		texture = load(texture_path) as Texture2D
	elif FileAccess.file_exists(texture_path):
		# Try loading as image file
		var image: Image = Image.new()
		var error: Error = image.load(texture_path)
		if error == OK:
			texture = ImageTexture.new()
			texture.create_from_image(image)
	
	if not texture:
		push_warning("Failed to load texture: " + texture_path)
	
	return texture

func clone() -> MaterialData:
	var cloned: MaterialData = MaterialData.new()
	
	# Copy all properties
	cloned.material_name = material_name
	cloned.material_type = material_type
	cloned.diffuse_texture_path = diffuse_texture_path
	cloned.normal_texture_path = normal_texture_path
	cloned.specular_texture_path = specular_texture_path
	cloned.emission_texture_path = emission_texture_path
	cloned.roughness_texture_path = roughness_texture_path
	
	cloned.metallic = metallic
	cloned.roughness = roughness
	cloned.emission_energy = emission_energy
	cloned.transparency_mode = transparency_mode
	cloned.alpha_scissor_threshold = alpha_scissor_threshold
	cloned.double_sided = double_sided
	
	cloned.albedo_color = albedo_color
	cloned.emission_color = emission_color
	
	cloned.rim_enabled = rim_enabled
	cloned.rim_tint = rim_tint
	cloned.clearcoat_enabled = clearcoat_enabled
	cloned.clearcoat_roughness = clearcoat_roughness
	cloned.anisotropy_enabled = anisotropy_enabled
	cloned.anisotropy_flowmap = anisotropy_flowmap
	
	cloned.animated_uv = animated_uv
	cloned.uv_scroll_speed = uv_scroll_speed
	cloned.blend_mode = blend_mode
	cloned.cull_mode = cull_mode
	
	return cloned

func get_memory_usage_estimate() -> int:
	# Estimate memory usage in bytes
	var base_size: int = 1024  # Base material data
	var texture_memory: int = 0
	
	# Rough texture memory estimates
	if not diffuse_texture_path.is_empty():
		texture_memory += 1024 * 1024  # 1MB estimate
	if not normal_texture_path.is_empty():
		texture_memory += 1024 * 1024
	if not specular_texture_path.is_empty():
		texture_memory += 512 * 1024
	if not emission_texture_path.is_empty():
		texture_memory += 512 * 1024
	if not roughness_texture_path.is_empty():
		texture_memory += 512 * 1024
	
	return base_size + texture_memory

func get_display_name() -> String:
	return material_name + " (" + get_material_type_name() + ")"

func to_dictionary() -> Dictionary:
	var result: Dictionary = super.to_dictionary()
	
	result.merge({
		"material_name": material_name,
		"material_type": material_type,
		"diffuse_texture_path": diffuse_texture_path,
		"normal_texture_path": normal_texture_path,
		"specular_texture_path": specular_texture_path,
		"emission_texture_path": emission_texture_path,
		"roughness_texture_path": roughness_texture_path,
		"metallic": metallic,
		"roughness": roughness,
		"emission_energy": emission_energy,
		"transparency_mode": transparency_mode,
		"alpha_scissor_threshold": alpha_scissor_threshold,
		"double_sided": double_sided,
		"albedo_color": var_to_str(albedo_color),
		"emission_color": var_to_str(emission_color),
		"rim_enabled": rim_enabled,
		"rim_tint": rim_tint,
		"clearcoat_enabled": clearcoat_enabled,
		"clearcoat_roughness": clearcoat_roughness,
		"anisotropy_enabled": anisotropy_enabled,
		"anisotropy_flowmap": anisotropy_flowmap,
		"animated_uv": animated_uv,
		"uv_scroll_speed": var_to_str(uv_scroll_speed),
		"blend_mode": blend_mode,
		"cull_mode": cull_mode
	})
	
	return result

func from_dictionary(data: Dictionary) -> void:
	super.from_dictionary(data)
	
	if "material_name" in data:
		material_name = data.material_name
	if "material_type" in data:
		material_type = data.material_type
	if "diffuse_texture_path" in data:
		diffuse_texture_path = data.diffuse_texture_path
	if "normal_texture_path" in data:
		normal_texture_path = data.normal_texture_path
	if "specular_texture_path" in data:
		specular_texture_path = data.specular_texture_path
	if "emission_texture_path" in data:
		emission_texture_path = data.emission_texture_path
	if "roughness_texture_path" in data:
		roughness_texture_path = data.roughness_texture_path
	if "metallic" in data:
		metallic = data.metallic
	if "roughness" in data:
		roughness = data.roughness
	if "emission_energy" in data:
		emission_energy = data.emission_energy
	if "transparency_mode" in data:
		transparency_mode = data.transparency_mode
	if "alpha_scissor_threshold" in data:
		alpha_scissor_threshold = data.alpha_scissor_threshold
	if "double_sided" in data:
		double_sided = data.double_sided
	if "albedo_color" in data:
		albedo_color = str_to_var(data.albedo_color)
	if "emission_color" in data:
		emission_color = str_to_var(data.emission_color)
	if "rim_enabled" in data:
		rim_enabled = data.rim_enabled
	if "rim_tint" in data:
		rim_tint = data.rim_tint
	if "clearcoat_enabled" in data:
		clearcoat_enabled = data.clearcoat_enabled
	if "clearcoat_roughness" in data:
		clearcoat_roughness = data.clearcoat_roughness
	if "anisotropy_enabled" in data:
		anisotropy_enabled = data.anisotropy_enabled
	if "anisotropy_flowmap" in data:
		anisotropy_flowmap = data.anisotropy_flowmap
	if "animated_uv" in data:
		animated_uv = data.animated_uv
	if "uv_scroll_speed" in data:
		uv_scroll_speed = str_to_var(data.uv_scroll_speed)
	if "blend_mode" in data:
		blend_mode = data.blend_mode
	if "cull_mode" in data:
		cull_mode = data.cull_mode