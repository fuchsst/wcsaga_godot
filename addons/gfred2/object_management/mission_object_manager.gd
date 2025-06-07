@tool
class_name MissionObjectManager
extends Node

## Central coordinator for mission object management in the FRED2 editor plugin.
## Handles object creation, lifecycle management, property updates, and integration
## with the 3D viewport and mission data Resource systems.

signal object_created(object_data: MissionObject)
signal object_deleted(object_data: MissionObject)
signal object_modified(object_data: MissionObject)
signal selection_changed(selected_objects: Array[MissionObject])

# Core systems
var mission_data: MissionData
var viewport_3d: MissionViewport3D
var object_factory: ObjectFactory
var property_editor: ObjectPropertyEditor
var object_hierarchy: ObjectHierarchy
var object_clipboard: ObjectClipboard
var object_validator: ObjectValidator

# Object management state
var all_objects: Array[MissionObject] = []
var selected_objects: Array[MissionObject] = []
var object_nodes: Dictionary = {}  # MissionObject -> MissionObjectNode3D mapping
var next_object_id: int = 1

# Undo/redo integration
var undo_redo_manager: UndoRedoManager

func _ready() -> void:
	name = "MissionObjectManager"
	_setup_components()
	_setup_signal_connections()

## Initialize all management components
func _setup_components() -> void:
	# Create factory for object creation
	object_factory = ObjectFactory.new()
	object_factory.object_manager = self
	add_child(object_factory)
	
	# Create clipboard for copy/paste operations
	object_clipboard = ObjectClipboard.new()
	object_clipboard.object_manager = self
	add_child(object_clipboard)
	
	# Create validator for property validation
	object_validator = ObjectValidator.new()
	object_validator.object_manager = self
	add_child(object_validator)

## Connect to relevant signals for coordination
func _setup_signal_connections() -> void:
	# Connect factory signals
	if object_factory:
		object_factory.object_created.connect(_on_factory_object_created)
	
	# Connect clipboard signals
	if object_clipboard:
		object_clipboard.objects_pasted.connect(_on_objects_pasted)

## Set mission data Resource reference
func set_mission_data(data: MissionData) -> void:
	mission_data = data
	if mission_data:
		load_objects_from_mission()

## Set 3D viewport reference for visual integration
func set_viewport(viewport: MissionViewport3D) -> void:
	viewport_3d = viewport
	if viewport_3d:
		undo_redo_manager = viewport_3d.undo_redo_manager
		# Connect viewport selection signals
		viewport_3d.object_selected.connect(_on_viewport_selection_changed)

## Set property editor reference
func set_property_editor(editor: ObjectPropertyEditor) -> void:
	property_editor = editor
	if property_editor:
		property_editor.property_changed.connect(_on_property_changed)

## Set object hierarchy reference
func set_object_hierarchy(hierarchy: ObjectHierarchy) -> void:
	object_hierarchy = hierarchy
	if object_hierarchy:
		object_hierarchy.object_selected.connect(_on_hierarchy_selection_changed)

## Load all objects from mission data Resource into management system
func load_objects_from_mission() -> void:
	if not mission_data:
		return
	
	clear_all_objects()
	
	# Load objects from mission data Resource
	for obj: MissionObject in mission_data.objects:
		register_existing_object(obj)
	
	# Update UI displays
	refresh_all_displays()

## Register an existing object (from Resource load)
func register_existing_object(obj: MissionObject) -> void:
	if obj in all_objects:
		return
	
	# Add to tracking
	all_objects.append(obj)
	
	# Assign ID if not set
	if obj.object_id.is_empty():
		obj.object_id = generate_unique_object_id()
	
	# Create 3D representation if viewport available
	if viewport_3d:
		var node_3d: MissionObjectNode3D = viewport_3d.create_mission_object_node(obj)
		viewport_3d.add_child(node_3d)
		object_nodes[obj] = node_3d
		
		# Connect object signals
		node_3d.transform_changed.connect(_on_object_transform_changed.bind(obj))

## Create a new mission object Resource
func create_object(object_type: MissionObject.Type, position: Vector3 = Vector3.ZERO) -> MissionObject:
	if not object_factory:
		push_error("Object factory not available")
		return null
	
	# Use factory to create object Resource
	var new_object: MissionObject = object_factory.create_object(object_type, position)
	if not new_object:
		return null
	
	# Begin undo operation
	if undo_redo_manager:
		undo_redo_manager.begin_action("Create Object")
	
	# Add to mission data Resource
	if mission_data:
		mission_data.add_object(new_object)
	
	# Register with management system
	register_new_object(new_object)
	
	# Commit undo operation
	if undo_redo_manager:
		undo_redo_manager.commit_action()
	
	return new_object

## Register a newly created object Resource
func register_new_object(obj: MissionObject) -> void:
	if obj in all_objects:
		return
	
	# Add to tracking
	all_objects.append(obj)
	
	# Create 3D representation
	if viewport_3d:
		var node_3d: MissionObjectNode3D = viewport_3d.create_mission_object_node(obj)
		viewport_3d.add_child(node_3d)
		object_nodes[obj] = node_3d
		
		# Connect signals
		node_3d.transform_changed.connect(_on_object_transform_changed.bind(obj))
	
	# Update displays
	refresh_hierarchy_display()
	
	# Emit signal
	object_created.emit(obj)

## Delete mission object Resource
func delete_object(obj: MissionObject) -> bool:
	if not obj or obj not in all_objects:
		return false
	
	# Begin undo operation
	if undo_redo_manager:
		undo_redo_manager.begin_action("Delete Object")
		# Capture state for undo
		undo_redo_manager.capture_object_state_for_deletion(obj)
	
	# Remove from selection
	if obj in selected_objects:
		deselect_object(obj)
	
	# Remove 3D representation
	var node_3d: MissionObjectNode3D = object_nodes.get(obj)
	if node_3d and is_instance_valid(node_3d):
		node_3d.queue_free()
	object_nodes.erase(obj)
	
	# Remove from mission data Resource
	if mission_data:
		mission_data.remove_object(obj)
	
	# Remove from tracking
	all_objects.erase(obj)
	
	# Update displays
	refresh_hierarchy_display()
	
	# Emit signal
	object_deleted.emit(obj)
	
	# Commit undo operation
	if undo_redo_manager:
		undo_redo_manager.commit_action()
	
	return true

## Duplicate an existing object Resource
func duplicate_object(obj: MissionObject, offset: Vector3 = Vector3(10, 0, 0)) -> MissionObject:
	if not obj or not object_factory:
		return null
	
	# Create duplicate through factory
	var duplicate: MissionObject = object_factory.duplicate_object(obj)
	if not duplicate:
		return null
	
	# Offset position
	duplicate.position += offset
	
	# Generate unique name
	duplicate.object_name = generate_unique_object_name(duplicate.object_name)
	duplicate.object_id = generate_unique_object_id()
	
	# Register as new object Resource
	if mission_data:
		mission_data.add_object(duplicate)
	register_new_object(duplicate)
	
	return duplicate

## Select objects
func select_objects(objects: Array[MissionObject], add_to_selection: bool = false) -> void:
	if not add_to_selection:
		clear_selection()
	
	for obj: MissionObject in objects:
		if obj not in selected_objects:
			selected_objects.append(obj)
			
			# Update 3D representation
			var node_3d: MissionObjectNode3D = object_nodes.get(obj)
			if node_3d:
				node_3d.set_selected(true)
	
	# Update UI displays
	update_selection_displays()
	
	# Emit signal
	selection_changed.emit(selected_objects)

## Select single object
func select_object(obj: MissionObject, add_to_selection: bool = false) -> void:
	select_objects([obj], add_to_selection)

## Deselect object
func deselect_object(obj: MissionObject) -> void:
	if obj in selected_objects:
		selected_objects.erase(obj)
		
		# Update 3D representation
		var node_3d: MissionObjectNode3D = object_nodes.get(obj)
		if node_3d:
			node_3d.set_selected(false)
		
		# Update displays
		update_selection_displays()
		
		# Emit signal
		selection_changed.emit(selected_objects)

## Clear all selection
func clear_selection() -> void:
	for obj: MissionObject in selected_objects:
		var node_3d: MissionObjectNode3D = object_nodes.get(obj)
		if node_3d:
			node_3d.set_selected(false)
	
	selected_objects.clear()
	update_selection_displays()
	selection_changed.emit(selected_objects)

## Get currently selected objects
func get_selected_objects() -> Array[MissionObject]:
	return selected_objects.duplicate()

## Update object Resource property
func set_object_property(obj: MissionObject, property: String, value: Variant) -> bool:
	if not obj or not obj.has_method("set"):
		return false
	
	# Validate the property change
	if object_validator and not object_validator.validate_property_change(obj, property, value):
		return false
	
	# Store old value for undo
	var old_value: Variant = obj.get(property) if obj.has_method("get") else null
	
	# Begin undo operation
	if undo_redo_manager:
		undo_redo_manager.begin_action("Change Property")
		undo_redo_manager.capture_property_change(obj, property, old_value, value)
	
	# Set the property on the Resource
	obj.set(property, value)
	
	# Update 3D representation if needed
	var node_3d: MissionObjectNode3D = object_nodes.get(obj)
	if node_3d:
		node_3d.sync_from_mission_data()
	
	# Emit signal
	object_modified.emit(obj)
	
	# Commit undo operation
	if undo_redo_manager:
		undo_redo_manager.commit_action()
	
	return true

## Update object property (simplified interface for UI)
func update_object_property(property_name: String, new_value: Variant) -> void:
	if selected_objects.size() == 1:
		set_object_property(selected_objects[0], property_name, new_value)

## Undo last action
func undo() -> void:
	if undo_redo_manager:
		undo_redo_manager.undo()

## Redo last undone action
func redo() -> void:
	if undo_redo_manager:
		undo_redo_manager.redo()

## Copy selected objects to clipboard
func copy_selected() -> void:
	if object_clipboard:
		object_clipboard.copy_objects(selected_objects)

## Paste objects from clipboard
func paste() -> void:
	if object_clipboard:
		object_clipboard.paste_objects()

## Delete selected objects
func delete_selected() -> void:
	var objects_to_delete: Array[MissionObject] = selected_objects.duplicate()
	for obj: MissionObject in objects_to_delete:
		delete_object(obj)

## Select all objects
func select_all() -> void:
	select_objects(all_objects.duplicate())

## Set selection from external source
func set_selection(objects: Array[MissionObject]) -> void:
	select_objects(objects, false)

## Generate unique object ID
func generate_unique_object_id() -> String:
	var id: String = "obj_%04d" % next_object_id
	next_object_id += 1
	
	# Ensure uniqueness
	while has_object_with_id(id):
		id = "obj_%04d" % next_object_id
		next_object_id += 1
	
	return id

## Generate unique object name
func generate_unique_object_name(base_name: String) -> String:
	var name: String = base_name
	var counter: int = 1
	
	while has_object_with_name(name):
		name = "%s_%02d" % [base_name, counter]
		counter += 1
	
	return name

## Check if object with ID exists
func has_object_with_id(id: String) -> bool:
	for obj: MissionObject in all_objects:
		if obj.object_id == id:
			return true
	return false

## Check if object with name exists
func has_object_with_name(name: String) -> bool:
	for obj: MissionObject in all_objects:
		if obj.object_name == name:
			return true
	return false

## Get object by ID
func get_object_by_id(id: String) -> MissionObject:
	for obj: MissionObject in all_objects:
		if obj.object_id == id:
			return obj
	return null

## Get object by name
func get_object_by_name(name: String) -> MissionObject:
	for obj: MissionObject in all_objects:
		if obj.object_name == name:
			return obj
	return null

## Get 3D node for object
func get_object_node(obj: MissionObject) -> MissionObjectNode3D:
	return object_nodes.get(obj)

## Get all objects of specific type
func get_objects_by_type(object_type: MissionObject.Type) -> Array[MissionObject]:
	var result: Array[MissionObject] = []
	for obj: MissionObject in all_objects:
		if obj.object_type == object_type:
			result.append(obj)
	return result

## Clear all objects
func clear_all_objects() -> void:
	# Clear selection first
	clear_selection()
	
	# Remove all 3D nodes
	for obj: MissionObject in all_objects:
		var node_3d: MissionObjectNode3D = object_nodes.get(obj)
		if node_3d and is_instance_valid(node_3d):
			node_3d.queue_free()
	
	# Clear tracking
	all_objects.clear()
	object_nodes.clear()
	
	# Reset ID counter
	next_object_id = 1
	
	# Update displays
	refresh_all_displays()

## Refresh all UI displays
func refresh_all_displays() -> void:
	refresh_hierarchy_display()
	refresh_property_display()

## Refresh hierarchy display
func refresh_hierarchy_display() -> void:
	if object_hierarchy:
		object_hierarchy.set_mission_data(mission_data)

## Refresh property display
func refresh_property_display() -> void:
	if property_editor:
		if selected_objects.size() == 1:
			property_editor.edit_object(selected_objects[0])
		else:
			property_editor.edit_object(null)

## Update selection-related displays
func update_selection_displays() -> void:
	refresh_property_display()
	
	if object_hierarchy:
		object_hierarchy.select_objects(selected_objects)

## Signal handlers

func _on_factory_object_created(obj: MissionObject) -> void:
	# Object creation is handled by create_object method
	pass

func _on_objects_pasted(objects: Array[MissionObject]) -> void:
	# Register all pasted objects
	for obj: MissionObject in objects:
		register_new_object(obj)

func _on_viewport_selection_changed(objects: Array[MissionObjectNode3D]) -> void:
	# Convert 3D nodes back to mission object Resources
	var mission_objects: Array[MissionObject] = []
	for node_3d: MissionObjectNode3D in objects:
		if node_3d.mission_object:
			mission_objects.append(node_3d.mission_object)
	
	# Update selection (without clearing to allow multi-select)
	select_objects(mission_objects, Input.is_key_pressed(KEY_CTRL))

func _on_hierarchy_selection_changed(objects: Array[MissionObject]) -> void:
	# Update selection from hierarchy
	select_objects(objects, Input.is_key_pressed(KEY_CTRL))

func _on_property_changed(property_name: String, new_value: Variant) -> void:
	# Update property through proper channel
	update_object_property(property_name, new_value)

func _on_object_transform_changed(obj: MissionObject) -> void:
	# 3D transform changed, ensure Resource data is synced
	var node_3d: MissionObjectNode3D = object_nodes.get(obj)
	if node_3d:
		obj.position = node_3d.global_position
		obj.rotation = node_3d.rotation
		obj.scale = node_3d.scale
		
		# Emit property change signal
		object_modified.emit(obj)

## Get object statistics
func get_object_statistics() -> Dictionary:
	var stats: Dictionary = {}
	stats.total_objects = all_objects.size()
	stats.selected_objects = selected_objects.size()
	
	# Count by type
	var type_counts: Dictionary = {}
	for obj: MissionObject in all_objects:
		var type_name: String = MissionObject.Type.keys()[obj.object_type]
		type_counts[type_name] = type_counts.get(type_name, 0) + 1
	stats.type_counts = type_counts
	
	return stats