@tool
class_name ShipPreview3D
extends SubViewport

## 3D ship preview component for GFRED2-009 Advanced Ship Configuration.
## Provides real-time ship visualization with configuration changes.
## Scene: addons/gfred2/scenes/components/ship_preview_3d/ship_preview_3d.tscn

signal preview_ready()
signal ship_model_loaded(model_path: String)
signal texture_applied(texture_path: String)
signal weapon_preview_updated()

# Ship preview state
var current_ship_config: ShipConfigurationData = null
var ship_model_node: Node3D = null
var camera_controller: Camera3D = null
var preview_environment: Environment = null

# Asset loading
var asset_loader: AssetLoader = null
var current_ship_data: ShipData = null

# Rendering configuration
var render_size: Vector2i = Vector2i(512, 512)
var preview_scale: float = 1.0
var rotation_speed: float = 0.5
var auto_rotate: bool = true

# Scene node references
@onready var camera_3d: Camera3D = $Camera3D
@onready var ship_container: Node3D = $ShipContainer
@onready var lighting_setup: Node3D = $LightingSetup
@onready var environment_node: Node3D = $EnvironmentNode

# Performance tracking
var model_load_time: int = 0
var texture_apply_time: int = 0
var last_update_time: int = 0

func _ready() -> void:
	name = "ShipPreview3D"
	
	# Configure viewport
	size = render_size
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Initialize asset system integration
	asset_loader = WCSAssetLoader
	
	# Setup camera and lighting
	_setup_camera_and_lighting()
	
	# Setup environment
	_setup_preview_environment()
	
	print("ShipPreview3D: Component initialized")
	preview_ready.emit()

func _process(delta: float) -> void:
	# Auto-rotate ship if enabled
	if auto_rotate and ship_model_node:
		ship_model_node.rotation.y += rotation_speed * delta

## Sets up camera positioning and lighting
func _setup_camera_and_lighting() -> void:
	if camera_3d:
		camera_controller = camera_3d
		camera_controller.position = Vector3(0, 0, 5)
		camera_controller.look_at(Vector3.ZERO, Vector3.UP)
		camera_controller.fov = 45.0
	
	# Setup lighting for ship preview
	if lighting_setup:
		# Primary directional light
		var main_light: DirectionalLight3D = DirectionalLight3D.new()
		main_light.position = Vector3(2, 3, 5)
		main_light.look_at(Vector3.ZERO, Vector3.UP)
		main_light.light_energy = 1.0
		main_light.shadow_enabled = true
		lighting_setup.add_child(main_light)
		
		# Fill light
		var fill_light: DirectionalLight3D = DirectionalLight3D.new()
		fill_light.position = Vector3(-2, 1, 3)
		fill_light.look_at(Vector3.ZERO, Vector3.UP)
		fill_light.light_energy = 0.3
		lighting_setup.add_child(fill_light)

## Sets up preview environment
func _setup_preview_environment() -> void:
	if environment_node:
		# Create a simple environment for ship preview
		preview_environment = Environment.new()
		preview_environment.background_mode = Environment.BG_COLOR
		preview_environment.background_color = Color(0.1, 0.1, 0.15, 1.0)
		preview_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		preview_environment.ambient_light_color = Color(0.2, 0.2, 0.3, 1.0)
		preview_environment.ambient_light_energy = 0.3
		
		# Apply environment to camera
		if camera_controller:
			camera_controller.environment = preview_environment

## Updates ship preview with configuration
func update_ship_preview(ship_config: ShipConfigurationData) -> void:
	if not ship_config:
		_clear_ship_preview()
		return
	
	current_ship_config = ship_config
	
	# Load ship model if ship class changed
	if not current_ship_data or current_ship_data.ship_name != ship_config.ship_class:
		_load_ship_model(ship_config.ship_class)
	else:
		# Update existing model with configuration changes
		_update_ship_appearance()

## Loads ship model from asset system
func _load_ship_model(ship_class: String) -> void:
	if ship_class.is_empty():
		return
	
	var start_time: int = Time.get_ticks_msec()
	
	# Clear existing ship model
	_clear_ship_model()
	
	# Load ship data from asset system
	if asset_loader:
		var ship_paths: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
		for ship_path in ship_paths:
			var ship_data: ShipData = asset_loader.load_asset(ship_path)
			if ship_data and ship_data.ship_name == ship_class:
				current_ship_data = ship_data
				_create_ship_model_from_data(ship_data)
				break
	
	model_load_time = Time.get_ticks_msec() - start_time
	
	# Performance requirement: < 16ms scene instantiation
	if model_load_time > 16:
		print("ShipPreview3D: Model loading took %d ms (> 16ms threshold)" % model_load_time)

## Creates ship model from ship data
func _create_ship_model_from_data(ship_data: ShipData) -> void:
	if not ship_data or not ship_container:
		return
	
	# Load POF model if available
	if not ship_data.pof_file.is_empty():
		var model_path: String = "res://assets/models/ships/" + ship_data.pof_file
		
		# Try to load the model
		if ResourceLoader.exists(model_path):
			var model_scene: PackedScene = load(model_path)
			if model_scene:
				ship_model_node = model_scene.instantiate()
				ship_container.add_child(ship_model_node)
				
				# Scale model appropriately for preview
				_scale_model_for_preview()
				
				# Apply initial textures and appearance
				_update_ship_appearance()
				
				ship_model_loaded.emit(model_path)
				print("ShipPreview3D: Loaded ship model: %s" % model_path)
				return
	
	# Fallback: create simple geometric representation
	_create_fallback_ship_model(ship_data)

## Creates fallback geometric ship model
func _create_fallback_ship_model(ship_data: ShipData) -> void:
	# Create a simple geometric representation if model not available
	ship_model_node = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	
	# Scale based on ship size (approximation)
	var ship_length: float = _parse_ship_length(ship_data.ship_length)
	if ship_length > 0:
		mesh.size = Vector3(ship_length * 0.1, ship_length * 0.03, ship_length * 0.15)
	else:
		mesh.size = Vector3(2.0, 0.5, 3.0)  # Default size
	
	ship_model_node.mesh = mesh
	ship_container.add_child(ship_model_node)
	
	# Apply basic material
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.6, 0.8, 1.0)
	ship_model_node.material_override = material
	
	print("ShipPreview3D: Created fallback model for: %s" % ship_data.ship_name)

## Parses ship length string to float
func _parse_ship_length(length_str: String) -> float:
	if length_str.is_empty():
		return 0.0
	
	# Extract numeric value from length string (e.g., "150 m" -> 150.0)
	var regex: RegEx = RegEx.new()
	regex.compile("([0-9.]+)")
	var result: RegExMatch = regex.search(length_str)
	
	if result:
		return result.get_string(1).to_float()
	
	return 0.0

## Scales model for optimal preview
func _scale_model_for_preview() -> void:
	if not ship_model_node:
		return
	
	# Get model bounds
	var aabb: AABB = _get_model_bounds(ship_model_node)
	if aabb.size.length() > 0:
		# Calculate scale to fit in preview
		var max_dimension: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
		var target_size: float = 3.0  # Target size in preview units
		preview_scale = target_size / max_dimension
		
		ship_model_node.scale = Vector3.ONE * preview_scale
	
	# Center the model
	ship_model_node.position = Vector3.ZERO

## Gets model bounds recursively
func _get_model_bounds(node: Node3D) -> AABB:
	var bounds: AABB = AABB()
	
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			bounds = mesh_instance.mesh.get_aabb()
	
	# Check child nodes
	for child in node.get_children():
		if child is Node3D:
			var child_bounds: AABB = _get_model_bounds(child as Node3D)
			if child_bounds.size.length() > 0:
				if bounds.size.length() == 0:
					bounds = child_bounds
				else:
					bounds = bounds.merge(child_bounds)
	
	return bounds

## Updates ship appearance based on configuration
func _update_ship_appearance() -> void:
	if not ship_model_node or not current_ship_config:
		return
	
	var start_time: int = Time.get_ticks_msec()
	
	# Apply texture replacements
	_apply_texture_replacements()
	
	# Update weapon visual indicators
	_update_weapon_visuals()
	
	# Apply damage system visual changes
	_apply_damage_system_visuals()
	
	# Update hull/shield visualization
	_update_hull_shield_visuals()
	
	last_update_time = Time.get_ticks_msec() - start_time
	
	# Performance requirement: 60+ FPS UI updates
	if last_update_time > 16:
		print("ShipPreview3D: Appearance update took %d ms (> 16ms threshold)" % last_update_time)

## Applies texture replacements from configuration
func _apply_texture_replacements() -> void:
	if not ship_model_node or not current_ship_config.texture_config:
		return
	
	var texture_start_time: int = Time.get_ticks_msec()
	
	# Apply texture replacements
	for original_texture in current_ship_config.texture_config.texture_replacements:
		var replacement_path: String = current_ship_config.texture_config.texture_replacements[original_texture]
		if ResourceLoader.exists(replacement_path):
			var new_texture: Texture2D = load(replacement_path)
			if new_texture:
				_replace_texture_on_model(ship_model_node, original_texture, new_texture)
				texture_applied.emit(replacement_path)
	
	texture_apply_time = Time.get_ticks_msec() - texture_start_time

## Replaces texture on model recursively
func _replace_texture_on_model(node: Node3D, original_texture: String, new_texture: Texture2D) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.material_override is StandardMaterial3D:
			var material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
			# TODO: Implement texture replacement logic based on material structure
			if material.albedo_texture and material.albedo_texture.resource_path.contains(original_texture):
				material.albedo_texture = new_texture
	
	# Check child nodes
	for child in node.get_children():
		if child is Node3D:
			_replace_texture_on_model(child as Node3D, original_texture, new_texture)

## Updates weapon visual indicators
func _update_weapon_visuals() -> void:
	if not current_ship_config:
		return
	
	# TODO: Add weapon hardpoint visualization
	# This would show weapon mount points and loadouts visually
	weapon_preview_updated.emit()

## Applies damage system visuals
func _apply_damage_system_visuals() -> void:
	if not current_ship_config.damage_config:
		return
	
	# TODO: Implement damage system visualization
	# This could show damaged areas, subsystem highlights, etc.
	pass

## Updates hull and shield visualization
func _update_hull_shield_visuals() -> void:
	if not current_ship_config.hitpoint_config:
		return
	
	# TODO: Implement hull/shield visualization
	# This could show shield bubble, hull integrity indicators, etc.
	pass

## Clears current ship preview
func _clear_ship_preview() -> void:
	_clear_ship_model()
	current_ship_config = null
	current_ship_data = null

## Clears current ship model
func _clear_ship_model() -> void:
	if ship_model_node:
		ship_model_node.queue_free()
		ship_model_node = null

## Sets preview options
func set_preview_options(size: Vector2i, scale: float, rotate: bool) -> void:
	render_size = size
	preview_scale = scale
	auto_rotate = rotate
	
	# Update viewport size
	self.size = render_size
	
	# Update model scale
	if ship_model_node:
		ship_model_node.scale = Vector3.ONE * preview_scale

## Captures preview as texture
func capture_preview() -> ImageTexture:
	# Force render update
	render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw(false, 0.0)
	
	# Get rendered image
	var image: Image = get_texture().get_image()
	if image:
		var texture: ImageTexture = ImageTexture.new()
		texture.set_image(image)
		return texture
	
	return null

## Camera controls

## Sets camera position for different views
func set_camera_view(view_type: String) -> void:
	if not camera_controller:
		return
	
	match view_type:
		"front":
			camera_controller.position = Vector3(0, 0, 5)
			camera_controller.look_at(Vector3.ZERO, Vector3.UP)
		"side":
			camera_controller.position = Vector3(5, 0, 0)
			camera_controller.look_at(Vector3.ZERO, Vector3.UP)
		"top":
			camera_controller.position = Vector3(0, 5, 0)
			camera_controller.look_at(Vector3.ZERO, Vector3.FORWARD)
		"isometric":
			camera_controller.position = Vector3(3, 3, 3)
			camera_controller.look_at(Vector3.ZERO, Vector3.UP)

## Zoom camera by factor
func zoom_camera(zoom_factor: float) -> void:
	if camera_controller:
		camera_controller.position = camera_controller.position * zoom_factor

## Rotate camera around ship
func rotate_camera(rotation_delta: Vector2) -> void:
	if not camera_controller:
		return
	
	# TODO: Implement camera rotation around target
	pass

## Public API

## Gets current ship configuration
func get_current_ship_config() -> ShipConfigurationData:
	return current_ship_config

## Gets performance statistics
func get_performance_stats() -> Dictionary:
	return {
		"model_load_time": model_load_time,
		"texture_apply_time": texture_apply_time,
		"last_update_time": last_update_time,
		"meets_performance_requirements": last_update_time < 16
	}

## Checks if preview is ready
func is_preview_ready() -> bool:
	return ship_model_node != null

## Gets preview texture for external use
func get_preview_texture() -> Texture2D:
	return get_texture()