# scripts/core_systems/docking_manager.gd
# Singleton (Autoload) to manage docking relationships between objects.
# Corresponds to logic in objectdock.cpp and parts of object.cpp.
class_name DockingManager
extends Node

# --- Data Structures ---

# Represents a single docking connection from one object's perspective.
class DockInstance:
	var docked_object_id: int = -1 # Instance ID of the object docked to
	var docked_object_sig: int = -1 # Signature for validation
	var dock_point_index: int = -1 # Index of the dock point used on *this* object
	# var dock_point_other_index: int = -1 # Index of the dock point used on the *other* object (optional)

	func _init(other_obj: Node, point_idx: int):
		if is_instance_valid(other_obj):
			docked_object_id = other_obj.get_instance_id()
			docked_object_sig = other_obj.get_meta("signature", -1)
		dock_point_index = point_idx

	func get_docked_object() -> Node:
		if docked_object_id != -1:
			var node = instance_from_id(docked_object_id)
			# Validate signature
			if is_instance_valid(node) and node.get_meta("signature", -1) == docked_object_sig:
				return node
		return null

# Main dictionary mapping an object's instance ID to an array of its DockInstance objects.
# { object_instance_id: [DockInstance, DockInstance, ...] }
var live_docks: Dictionary = {}

# Dictionary for objects marked for deletion but still potentially docked (dead_dock_list equivalent)
# { object_instance_id: [DockInstance, DockInstance, ...] }
var dead_docks: Dictionary = {}


# --- Public API ---

# Docks two objects together at specified points.
# Corresponds to dock_dock_objects.
func dock_objects(obj1: Node, dockpoint1_idx: int, obj2: Node, dockpoint2_idx: int):
	if not is_instance_valid(obj1) or not is_instance_valid(obj2):
		printerr("DockingManager: Invalid object provided for docking.")
		return

	var id1 = obj1.get_instance_id()
	var id2 = obj2.get_instance_id()

	# Check if already docked
	if _find_instance(live_docks, id1, id2) or _find_instance(live_docks, id2, id1):
		printerr("DockingManager: Objects %d and %d are already docked." % [id1, id2])
		return

	# Check if dockpoints are already in use
	if _find_instance_by_point(live_docks, id1, dockpoint1_idx) or \
	   _find_instance_by_point(live_docks, id2, dockpoint2_idx):
		printerr("DockingManager: One or both dockpoints (%d on %d, %d on %d) are already in use." % [dockpoint1_idx, id1, dockpoint2_idx, id2])
		return

	_add_instance(live_docks, id1, obj2, dockpoint1_idx)
	_add_instance(live_docks, id2, obj1, dockpoint2_idx)
	print("DockingManager: Docked %d (point %d) and %d (point %d)" % [id1, dockpoint1_idx, id2, dockpoint2_idx])


# Undocks two objects.
# Corresponds to dock_undock_objects.
func undock_objects(obj1: Node, obj2: Node):
	if not is_instance_valid(obj1) or not is_instance_valid(obj2):
		printerr("DockingManager: Invalid object provided for undocking.")
		return

	var id1 = obj1.get_instance_id()
	var id2 = obj2.get_instance_id()

	if not _find_instance(live_docks, id1, id2) or not _find_instance(live_docks, id2, id1):
		printerr("DockingManager: Objects %d and %d are not docked." % [id1, id2])
		# Continue anyway to ensure cleanup
		# return

	_remove_instance(live_docks, id1, id2)
	_remove_instance(live_docks, id2, id1)
	print("DockingManager: Undocked %d and %d" % [id1, id2])


# Checks if an object is currently docked to any other object.
func is_object_docked(obj: Node) -> bool:
	if not is_instance_valid(obj): return false
	var id = obj.get_instance_id()
	return live_docks.has(id) and not live_docks[id].is_empty()


# Gets the first object docked to the given object.
func get_first_docked_object(obj: Node) -> Node:
	if not is_instance_valid(obj): return null
	var id = obj.get_instance_id()
	if live_docks.has(id) and not live_docks[id].is_empty():
		var dock_instance: DockInstance = live_docks[id][0]
		return dock_instance.get_docked_object()
	return null


# Gets all objects directly docked to the given object.
func get_directly_docked_objects(obj: Node) -> Array[Node]:
	var docked_nodes: Array[Node] = []
	if not is_instance_valid(obj): return docked_nodes
	var id = obj.get_instance_id()
	if live_docks.has(id):
		for dock_instance in live_docks[id]:
			var docked_obj = dock_instance.get_docked_object()
			if is_instance_valid(docked_obj):
				docked_nodes.append(docked_obj)
	return docked_nodes


# Finds the object docked at a specific dockpoint index of the given object.
func get_object_at_dockpoint(obj: Node, dockpoint_idx: int) -> Node:
	if not is_instance_valid(obj): return null
	var id = obj.get_instance_id()
	var instance = _find_instance_by_point(live_docks, id, dockpoint_idx)
	if instance:
		return instance.get_docked_object()
	return null


# Finds the dockpoint index used by a specific docked object pair.
func get_dockpoint_used_by_object(obj: Node, other_obj: Node) -> int:
	if not is_instance_valid(obj) or not is_instance_valid(other_obj): return -1
	var id1 = obj.get_instance_id()
	var id2 = other_obj.get_instance_id()
	var instance = _find_instance(live_docks, id1, id2)
	if instance:
		return instance.dock_point_index
	return -1


# Moves all objects docked directly or indirectly to the leader object.
# This needs to be called *after* the leader object's physics update.
# Corresponds to dock_move_docked_objects.
func move_docked_objects(leader_obj: Node):
	if not is_instance_valid(leader_obj) or not is_object_docked(leader_obj):
		return

	# Use a set to avoid processing objects multiple times in complex trees
	var processed_ids: Set = Set()
	_move_docked_children_recursive(leader_obj, null, processed_ids)


# --- Internal Helper Functions ---

func _add_instance(dock_dict: Dictionary, obj_id: int, other_obj: Node, dockpoint_idx: int):
	var instance = DockInstance.new(other_obj, dockpoint_idx)
	if not dock_dict.has(obj_id):
		dock_dict[obj_id] = []
	dock_dict[obj_id].append(instance)


func _remove_instance(dock_dict: Dictionary, obj_id: int, other_obj_id: int):
	if dock_dict.has(obj_id):
		var instances: Array = dock_dict[obj_id]
		for i in range(instances.size() - 1, -1, -1): # Iterate backwards for safe removal
			var instance: DockInstance = instances[i]
			if instance.docked_object_id == other_obj_id:
				instances.remove_at(i)
				# No need to free DockInstance manually, GDScript handles it
		# If the list becomes empty, remove the key from the dictionary
		if instances.is_empty():
			dock_dict.erase(obj_id)


func _find_instance(dock_dict: Dictionary, obj_id: int, other_obj_id: int) -> DockInstance:
	if dock_dict.has(obj_id):
		for instance in dock_dict[obj_id]:
			if instance.docked_object_id == other_obj_id:
				return instance
	return null


func _find_instance_by_point(dock_dict: Dictionary, obj_id: int, dockpoint_idx: int) -> DockInstance:
	if dock_dict.has(obj_id):
		for instance in dock_dict[obj_id]:
			if instance.dock_point_index == dockpoint_idx:
				return instance
	return null


# Recursive function to move docked children relative to their parent.
func _move_docked_children_recursive(current_obj: Node, parent_obj: Node, processed_ids: Set):
	var current_id = current_obj.get_instance_id()
	if processed_ids.has(current_id):
		return # Already processed this object in this movement chain
	processed_ids.add(current_id)

	# If this isn't the leader, calculate and apply its new transform based on the parent
	if parent_obj:
		_move_one_docked_object(current_obj, parent_obj)

	# Recursively move children
	var id = current_obj.get_instance_id()
	if live_docks.has(id):
		# Iterate over a copy because the list might change if undocking happens during iteration
		var docked_instances_copy = live_docks[id].duplicate()
		for instance in docked_instances_copy:
			var docked_obj = instance.get_docked_object()
			if is_instance_valid(docked_obj):
				_move_docked_children_recursive(docked_obj, current_obj, processed_ids)


# Calculates and applies the transform for a single docked object relative to its parent.
# Corresponds to call_doa.
func _move_one_docked_object(child_obj: Node, parent_obj: Node):
	if not is_instance_valid(child_obj) or not is_instance_valid(parent_obj):
		return

	# Find the docking points used for this connection
	var parent_dock_idx = get_dockpoint_used_by_object(parent_obj, child_obj)
	var child_dock_idx = get_dockpoint_used_by_object(child_obj, parent_obj)

	if parent_dock_idx == -1 or child_dock_idx == -1:
		printerr("DockingManager: Could not find dock points for moving %s relative to %s" % [child_obj.name, parent_obj.name])
		return

	# Get the dock point transforms from ModelMetadata (or Marker3Ds)
	var parent_dock_xform: Transform3D = _get_dock_point_transform(parent_obj, parent_dock_idx)
	var child_dock_xform: Transform3D = _get_dock_point_transform(child_obj, child_dock_idx)

	if parent_dock_xform == Transform3D.IDENTITY or child_dock_xform == Transform3D.IDENTITY:
		printerr("DockingManager: Could not retrieve valid dock point transforms for moving %s relative to %s" % [child_obj.name, parent_obj.name])
		return

	# --- Calculate Relative Transform ---
	# 1. Get the parent's dock point in world space
	var parent_dock_world: Transform3D = parent_obj.global_transform * parent_dock_xform

	# 2. Calculate the desired orientation of the child's dock point in world space.
	#    It should align with the parent's dock point but face the opposite direction.
	#    Rotate the parent's dock basis 180 degrees around its local Y-axis (or another suitable axis).
	var rotation_180_y = Basis.from_euler(Vector3(0, PI, 0))
	var desired_child_dock_basis_world = parent_dock_world.basis * rotation_180_y

	# 3. Calculate the child's required global basis to achieve the desired dock basis.
	#    Basis_ChildGlobal = Basis_DesiredDockWorld * Basis_ChildDockLocal.inverse()
	var child_dock_basis_inv = child_dock_xform.basis.inverse()
	var child_global_basis = desired_child_dock_basis_world * child_dock_basis_inv

	# 4. Calculate the child's required global origin.
	#    Origin_ChildGlobal = Origin_ParentDockWorld - (Basis_ChildGlobal * Origin_ChildDockLocal)
	var child_dock_origin_rotated = child_global_basis * child_dock_xform.origin
	var child_global_origin = parent_dock_world.origin - child_dock_origin_rotated

	# 5. Construct the new global transform for the child.
	var new_global_transform = Transform3D(child_global_basis, child_global_origin)

	# --- Apply Transform and Physics State ---
	# Apply the new transform to the child object
	child_obj.global_transform = new_global_transform

	# Match velocities and rotational velocities for physics consistency
	if child_obj is RigidBody3D and parent_obj is RigidBody3D:
		child_obj.linear_velocity = parent_obj.linear_velocity
		child_obj.angular_velocity = parent_obj.angular_velocity
		# Optional: Reset forces/torques if direct velocity setting causes issues
		# child_obj.apply_central_impulse(Vector3.ZERO)
		# child_obj.apply_torque_impulse(Vector3.ZERO)
	elif child_obj is CharacterBody3D and parent_obj is CharacterBody3D:
		# CharacterBody velocity is handled differently, might need custom logic
		# child_obj.velocity = parent_obj.velocity # This might not be correct depending on implementation
		pass


# Placeholder: Gets the local transform of a dock point marker.
# This needs to be implemented based on how dock points are stored (e.g., Marker3D nodes).
func _get_dock_point_transform(obj: Node, dock_idx: int) -> Transform3D:
	# Option 1: Find Marker3D child node by name convention
	# Example name: "DockPoint_0", "DockPoint_1"
	var marker_name = "DockPoint_%d" % dock_idx
	var marker_node = obj.find_child(marker_name, true, false) # Recursive search
	if marker_node is Marker3D:
		return marker_node.transform # Return local transform relative to parent (obj)

	# Option 2: Get data from ModelMetadata resource (if Markers aren't used)
	# if obj is ShipBase and is_instance_valid(obj.model_metadata):
	#     if dock_idx >= 0 and dock_idx < obj.model_metadata.docking_points.size():
	#         var dock_point_data = obj.model_metadata.docking_points[dock_idx]
	#         if dock_point_data.points.size() > 0:
	#             var pos = dock_point_data.points[0].position
	#             var norm = dock_point_data.points[0].normal
	#             # Create transform from position and normal (needs up vector)
	#             var basis = Basis.looking_at(norm) # Might need adjustment
	#             return Transform3D(basis, pos)

	printerr("DockingManager: Could not find dock point %d for object %s" % [dock_idx, obj.name])
	return Transform3D.IDENTITY # Return identity if not found


# --- Cleanup ---

# Called when an object is potentially being deleted
func handle_object_deletion(obj: Node):
	if not is_instance_valid(obj): return
	var id = obj.get_instance_id()

	# Remove from live docks
	if live_docks.has(id):
		var instances_copy = live_docks[id].duplicate() # Iterate copy
		for instance in instances_copy:
			var other_obj = instance.get_docked_object()
			if is_instance_valid(other_obj):
				# Remove the link from the other object back to this one
				_remove_instance(live_docks, other_obj.get_instance_id(), id)
		live_docks.erase(id) # Remove all links from the deleted object

	# TODO: Handle dead_docks list if necessary (for delayed undocking effects?)
	# For now, assume immediate cleanup.
