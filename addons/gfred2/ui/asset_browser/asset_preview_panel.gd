class_name AssetPreviewPanel
extends VBoxContainer

## Asset preview panel for displaying detailed information about selected assets.
## Shows 3D model previews, technical specifications, and asset metadata
## with efficient rendering and responsive updates.

signal asset_selection_confirmed(asset_data: AssetData)
signal preview_settings_changed(settings: Dictionary)

# UI Components
var preview_container: VBoxContainer
var model_preview: SubViewport
var camera_3d: Camera3D
var model_node: Node3D
var info_panel: VBoxContainer
var specs_table: GridContainer
var description_label: RichTextLabel
var action_buttons: HBoxContainer
var select_button: Button
var details_button: Button

# Asset data
var current_asset: AssetData
var preview_mesh: MeshInstance3D
var is_preview_active: bool = false

# Performance tracking
var last_update_time: int = 0

func _init() -> void:
	name = "AssetPreviewPanel"
	set_custom_minimum_size(Vector2(200, 300))

func _ready() -> void:
	_setup_ui()
	_setup_3d_preview()
	_connect_signals()

func _setup_ui() -> void:
	"""Setup the preview panel UI layout."""
	# Main container already is VBoxContainer
	
	# Header label
	var header_label: Label = Label.new()
	header_label.text = "Asset Preview"
	header_label.add_theme_font_size_override("font_size", 14)
	add_child(header_label)
	
	# Separator
	add_child(HSeparator.new())
	
	# 3D Preview area
	preview_container = VBoxContainer.new()
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(preview_container)
	
	var preview_label: Label = Label.new()
	preview_label.text = "3D Preview"
	preview_container.add_child(preview_label)
	
	# SubViewport for 3D preview
	model_preview = SubViewport.new()
	model_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	model_preview.set_custom_minimum_size(Vector2(150, 150))
	model_preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	preview_container.add_child(model_preview)
	
	# Information panel
	info_panel = VBoxContainer.new()
	add_child(info_panel)
	
	var info_label: Label = Label.new()
	info_label.text = "Technical Specifications"
	info_panel.add_child(info_label)
	
	# Specifications table
	specs_table = GridContainer.new()
	specs_table.columns = 2
	info_panel.add_child(specs_table)
	
	# Description area
	var desc_label: Label = Label.new()
	desc_label.text = "Description"
	info_panel.add_child(desc_label)
	
	description_label = RichTextLabel.new()
	description_label.set_custom_minimum_size(Vector2(0, 80))
	description_label.fit_content = true
	description_label.scroll_active = false
	info_panel.add_child(description_label)
	
	# Action buttons
	action_buttons = HBoxContainer.new()
	add_child(action_buttons)
	
	select_button = Button.new()
	select_button.text = "Select Asset"
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_buttons.add_child(select_button)
	
	details_button = Button.new()
	details_button.text = "Details..."
	action_buttons.add_child(details_button)
	
	# Initially show "no selection" state
	_show_no_selection_state()

func _setup_3d_preview() -> void:
	"""Initialize the 3D preview system."""
	# Setup camera
	camera_3d = Camera3D.new()
	camera_3d.position = Vector3(0, 0, 5)
	camera_3d.look_at(Vector3.ZERO, Vector3.UP)
	model_preview.add_child(camera_3d)
	
	# Setup lighting
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.position = Vector3(2, 2, 2)
	light.look_at(Vector3.ZERO, Vector3.UP)
	model_preview.add_child(light)
	
	# Setup ambient environment
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.2, 0.2, 0.3)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.4, 0.5)
	environment.ambient_light_energy = 0.8
	
	camera_3d.environment = environment

func _connect_signals() -> void:
	"""Connect UI interaction signals."""
	select_button.pressed.connect(_on_select_button_pressed)
	details_button.pressed.connect(_on_details_button_pressed)

func display_asset(asset_data: AssetData) -> void:
	"""Display detailed information for the specified asset."""
	if asset_data == null:
		_show_no_selection_state()
		return
	
	last_update_time = Time.get_ticks_msec()
	current_asset = asset_data
	
	# Update 3D preview
	_update_3d_preview(asset_data)
	
	# Update specifications
	_update_specifications(asset_data)
	
	# Update description
	_update_description(asset_data)
	
	# Update buttons
	_update_action_buttons(asset_data)
	
	var update_time: int = Time.get_ticks_msec() - last_update_time
	print("Asset preview updated in %d ms" % update_time)

func _update_3d_preview(asset_data: AssetData) -> void:
	"""Update the 3D model preview for the asset."""
	# Clear existing preview
	if preview_mesh != null:
		preview_mesh.queue_free()
		preview_mesh = null
	
	# Create placeholder mesh based on asset type
	var mesh: Mesh = _create_placeholder_mesh(asset_data)
	if mesh != null:
		preview_mesh = MeshInstance3D.new()
		preview_mesh.mesh = mesh
		preview_mesh.position = Vector3.ZERO
		
		# Apply material based on asset properties
		var material: StandardMaterial3D = _create_asset_material(asset_data)
		preview_mesh.material_override = material
		
		model_preview.add_child(preview_mesh)
		
		# Animate the model for visual appeal
		_start_preview_animation()
	
	# Force viewport update
	model_preview.render_target_update_mode = SubViewport.UPDATE_ONCE

func _create_placeholder_mesh(asset_data: AssetData) -> Mesh:
	"""Create a placeholder mesh based on asset type."""
	if asset_data is ShipClassData:
		var ship_data: ShipClassData = asset_data as ShipClassData
		match ship_data.ship_type:
			"Fighter":
				return _create_fighter_mesh()
			"Bomber":
				return _create_bomber_mesh()
			"Cruiser":
				return _create_cruiser_mesh()
			_:
				return _create_generic_ship_mesh()
	elif asset_data is WeaponClassData:
		return _create_weapon_mesh()
	else:
		return BoxMesh.new()

func _create_fighter_mesh() -> Mesh:
	"""Create a fighter-style mesh."""
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.8, 0.3, 2.0)
	return mesh

func _create_bomber_mesh() -> Mesh:
	"""Create a bomber-style mesh."""
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.2, 0.4, 2.5)
	return mesh

func _create_cruiser_mesh() -> Mesh:
	"""Create a cruiser-style mesh."""
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(2.0, 0.8, 4.0)
	return mesh

func _create_generic_ship_mesh() -> Mesh:
	"""Create a generic ship mesh."""
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 0.5, 2.0)
	return mesh

func _create_weapon_mesh() -> Mesh:
	"""Create a weapon-style mesh."""
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = 1.0
	mesh.top_radius = 0.1
	mesh.bottom_radius = 0.1
	return mesh

func _create_asset_material(asset_data: AssetData) -> StandardMaterial3D:
	"""Create a material based on asset properties."""
	var material: StandardMaterial3D = StandardMaterial3D.new()
	
	if asset_data is ShipClassData:
		var ship_data: ShipClassData = asset_data as ShipClassData
		match ship_data.faction:
			"Terran":
				material.albedo_color = Color(0.3, 0.5, 0.8)
			"Kilrathi":
				material.albedo_color = Color(0.8, 0.4, 0.3)
			"Shivan":
				material.albedo_color = Color(0.6, 0.3, 0.8)
			_:
				material.albedo_color = Color(0.5, 0.5, 0.5)
	elif asset_data is WeaponClassData:
		var weapon_data: WeaponClassData = asset_data as WeaponClassData
		match weapon_data.damage_type:
			"Energy":
				material.albedo_color = Color(0.8, 0.8, 0.3)
			"Kinetic":
				material.albedo_color = Color(0.6, 0.6, 0.6)
			"Missile":
				material.albedo_color = Color(0.8, 0.3, 0.3)
			_:
				material.albedo_color = Color(0.5, 0.5, 0.5)
	
	material.metallic = 0.7
	material.roughness = 0.3
	return material

func _start_preview_animation() -> void:
	"""Start rotation animation for the preview model."""
	if preview_mesh == null:
		return
	
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(preview_mesh, "rotation_degrees", Vector3(0, 360, 0), 8.0)

func _update_specifications(asset_data: AssetData) -> void:
	"""Update the specifications table with asset data."""
	# Clear existing specifications
	for child in specs_table.get_children():
		child.queue_free()
	
	if asset_data is ShipClassData:
		_add_ship_specifications(asset_data as ShipClassData)
	elif asset_data is WeaponClassData:
		_add_weapon_specifications(asset_data as WeaponClassData)

func _add_ship_specifications(ship_data: ShipClassData) -> void:
	"""Add ship-specific specifications to the table."""
	_add_spec_row("Type:", ship_data.ship_type)
	_add_spec_row("Faction:", ship_data.faction)
	_add_spec_row("Max Speed:", "%.1f m/s" % ship_data.max_velocity)
	_add_spec_row("Hull Strength:", "%.0f" % ship_data.max_hull_strength)
	_add_spec_row("Shield Strength:", "%.0f" % ship_data.max_shield_strength)

func _add_weapon_specifications(weapon_data: WeaponClassData) -> void:
	"""Add weapon-specific specifications to the table."""
	_add_spec_row("Type:", weapon_data.weapon_type)
	_add_spec_row("Damage Type:", weapon_data.damage_type)
	_add_spec_row("Damage/Shot:", "%.1f" % weapon_data.damage_per_shot)
	_add_spec_row("Fire Rate:", "%.1f/sec" % weapon_data.firing_rate)
	_add_spec_row("Energy Cost:", "%.1f" % weapon_data.energy_consumed)

func _add_spec_row(label: String, value: String) -> void:
	"""Add a specification row to the table."""
	var label_widget: Label = Label.new()
	label_widget.text = label
	label_widget.add_theme_font_size_override("font_size", 10)
	specs_table.add_child(label_widget)
	
	var value_widget: Label = Label.new()
	value_widget.text = value
	value_widget.add_theme_font_size_override("font_size", 10)
	specs_table.add_child(value_widget)

func _update_description(asset_data: AssetData) -> void:
	"""Update the description text."""
	var description: String = asset_data.get_description()
	if description.is_empty():
		description = "No description available."
	
	description_label.clear()
	description_label.append_text(description)

func _update_action_buttons(asset_data: AssetData) -> void:
	"""Update action button states based on asset."""
	select_button.disabled = false
	details_button.disabled = false
	
	# Update button text based on asset type
	if asset_data is ShipClassData:
		select_button.text = "Select Ship"
	elif asset_data is WeaponClassData:
		select_button.text = "Select Weapon"
	else:
		select_button.text = "Select Asset"

func _show_no_selection_state() -> void:
	"""Show the panel state when no asset is selected."""
	current_asset = null
	
	# Clear 3D preview
	if preview_mesh != null:
		preview_mesh.queue_free()
		preview_mesh = null
	
	# Clear specifications
	for child in specs_table.get_children():
		child.queue_free()
	
	# Clear description
	description_label.clear()
	description_label.append_text("Select an asset to view details and preview.")
	
	# Disable buttons
	select_button.disabled = true
	details_button.disabled = true
	select_button.text = "Select Asset"

# Signal handlers
func _on_select_button_pressed() -> void:
	"""Handle asset selection confirmation."""
	if current_asset != null:
		asset_selection_confirmed.emit(current_asset)

func _on_details_button_pressed() -> void:
	"""Handle request for detailed asset information."""
	if current_asset != null:
		# For now, print details to console
		# TODO: Open detailed asset dialog
		print("Detailed asset info requested for: %s" % current_asset.get_display_name())

# Public API
func clear_preview() -> void:
	"""Clear the current preview."""
	_show_no_selection_state()

func get_current_asset() -> AssetData:
	"""Get the currently previewed asset."""
	return current_asset