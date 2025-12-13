class_name ShipSelection
extends Control

## Ship Selection UI
##
## Displays available ships for player selection with 3D preview and stats.

signal ship_selected(ship_class: String)
signal selection_confirmed(ship_class: String)
signal back_pressed

const SHIP_STATS_PATH := "res://assets/ships/ships.tres"

@export var ship_preview_rotation_speed: float = 0.5

var _available_ships: Array[String] = []
var _selected_index: int = 0
var _ship_manifest: Resource = null
var _preview_model: Node3D = null

@onready var ship_list: ItemList = $HSplitContainer/LeftPanel/ShipList
@onready var stats_label: RichTextLabel = $HSplitContainer/RightPanel/StatsPanel/StatsLabel
@onready var preview_container: SubViewportContainer = $HSplitContainer/RightPanel/PreviewContainer
@onready var preview_viewport: SubViewport = $HSplitContainer/RightPanel/PreviewContainer/SubViewport
@onready
var model_pivot: Node3D = $HSplitContainer/RightPanel/PreviewContainer/SubViewport/ModelPivot
@onready var confirm_button: Button = $HSplitContainer/LeftPanel/ButtonContainer/ConfirmButton
@onready var back_button: Button = $HSplitContainer/LeftPanel/ButtonContainer/BackButton


func _ready() -> void:
	_load_ship_manifest()
	_setup_connections()
	_populate_ship_list()


func _process(delta: float) -> void:
	if model_pivot:
		model_pivot.rotate_y(ship_preview_rotation_speed * delta)


func _setup_connections() -> void:
	if ship_list:
		ship_list.item_selected.connect(_on_ship_selected)
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _load_ship_manifest() -> void:
	if ResourceLoader.exists(SHIP_STATS_PATH):
		_ship_manifest = load(SHIP_STATS_PATH)


func set_available_ships(ships: Array) -> void:
	_available_ships.clear()
	for ship in ships:
		if ship is String:
			_available_ships.append(ship)
	_populate_ship_list()


func _populate_ship_list() -> void:
	if not ship_list:
		return

	ship_list.clear()

	# If no ships set, load all player-flyable ships
	if _available_ships.is_empty() and _ship_manifest:
		if "ships" in _ship_manifest:
			for ship_name: String in _ship_manifest.ships.keys():
				var ship_data: Resource = _ship_manifest.ships[ship_name]
				if ship_data and "flags" in ship_data:
					# Check PLAYER_FLYABLE flag
					if ship_data.flags & 1:
						_available_ships.append(ship_name)

	for ship_name: String in _available_ships:
		ship_list.add_item(ship_name)

	if not _available_ships.is_empty():
		ship_list.select(0)
		_on_ship_selected(0)


func _on_ship_selected(index: int) -> void:
	_selected_index = index
	if index < _available_ships.size():
		var ship_name: String = _available_ships[index]
		ship_selected.emit(ship_name)
		_update_stats_display(ship_name)
		_load_ship_preview(ship_name)


func _update_stats_display(ship_name: String) -> void:
	if not stats_label:
		return

	var text := "[b]%s[/b]\n\n" % ship_name

	if _ship_manifest and "ships" in _ship_manifest:
		if ship_name in _ship_manifest.ships:
			var ship: Resource = _ship_manifest.ships[ship_name]
			if ship:
				if "alt_name" in ship and ship.alt_name:
					text += "[i]%s[/i]\n\n" % ship.alt_name

				text += "[u]Performance[/u]\n"
				if "max_speed" in ship:
					text += "Max Speed: %.0f m/s\n" % ship.max_speed
				if "afterburner_max_speed" in ship:
					text += "Afterburner: %.0f m/s\n" % ship.afterburner_max_speed
				if "rotation_time" in ship:
					text += "Maneuverability: %.1f\n" % (100.0 / ship.rotation_time)

				text += "\n[u]Defenses[/u]\n"
				if "max_hull_strength" in ship:
					text += "Hull: %.0f\n" % ship.max_hull_strength
				if "max_shield_strength" in ship:
					text += "Shields: %.0f\n" % ship.max_shield_strength

				text += "\n[u]Armament[/u]\n"
				if "num_primary_banks" in ship:
					text += "Primary Banks: %d\n" % ship.num_primary_banks
				if "num_secondary_banks" in ship:
					text += "Secondary Banks: %d\n" % ship.num_secondary_banks

	stats_label.text = text


func _load_ship_preview(ship_name: String) -> void:
	# Clear existing preview
	if _preview_model and is_instance_valid(_preview_model):
		_preview_model.queue_free()
		_preview_model = null

	if not model_pivot:
		return

	# Try to load ship scene
	var ship_path := "res://assets/ships/%s/%s.tscn" % [ship_name.to_lower(), ship_name.to_lower()]

	if not ResourceLoader.exists(ship_path):
		ship_path = "res://assets/ships/%s/%s.glb" % [ship_name.to_lower(), ship_name.to_lower()]

	if ResourceLoader.exists(ship_path):
		var scene := load(ship_path)
		if scene:
			_preview_model = scene.instantiate()
			model_pivot.add_child(_preview_model)

			# Center and scale model
			if _preview_model is Node3D:
				_preview_model.position = Vector3.ZERO
				# Auto-scale based on AABB
				var aabb := _get_node3d_aabb(_preview_model)
				var max_dim := maxf(maxf(aabb.size.x, aabb.size.y), aabb.size.z)
				if max_dim > 0:
					var scale_factor := 3.0 / max_dim
					_preview_model.scale = Vector3.ONE * scale_factor


func _get_node3d_aabb(node: Node3D) -> AABB:
	var result := AABB()
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh:
			var mesh_aabb := child.mesh.get_aabb()
			mesh_aabb.position += child.position
			result = result.merge(mesh_aabb)
		if child is Node3D:
			result = result.merge(_get_node3d_aabb(child))
	return result


func _on_confirm_pressed() -> void:
	if _selected_index < _available_ships.size():
		selection_confirmed.emit(_available_ships[_selected_index])


func _on_back_pressed() -> void:
	back_pressed.emit()


func get_selected_ship() -> String:
	if _selected_index < _available_ships.size():
		return _available_ships[_selected_index]
	return ""
