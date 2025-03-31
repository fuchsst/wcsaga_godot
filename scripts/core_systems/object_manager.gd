# scripts/core_systems/object_manager.gd
# Singleton (Autoload) responsible for tracking and managing game objects.
# Corresponds to parts of object.cpp functionality.
class_name ObjectManager
extends Node

# Dictionaries to track objects by instance ID and potentially signature
var objects_by_id: Dictionary = {}
var objects_by_signature: Dictionary = {} # Might be needed for network/save compatibility

# Potentially use groups for faster type-based lookups
const GROUP_SHIP = "group_ship"
const GROUP_WEAPON = "group_weapon"
const GROUP_ASTEROID = "group_asteroid"
const GROUP_DEBRIS = "group_debris"
# Add other groups as needed

func _ready():
	print("ObjectManager initialized.")

# Called by objects themselves when they enter the tree
func register_object(obj: Node, signature: int = -1):
	if not is_instance_valid(obj):
		printerr("ObjectManager: Attempted to register invalid object.")
		return

	var id = obj.get_instance_id()
	if objects_by_id.has(id):
		printerr("ObjectManager: Object with ID %d already registered." % id)
		return

	objects_by_id[id] = obj

	# Assign signature if not provided (use instance ID as fallback)
	var obj_signature = signature if signature != -1 else id
	if obj.has_meta("signature"): # Check if signature meta exists
		obj_signature = obj.get_meta("signature")
	else:
		obj.set_meta("signature", obj_signature) # Store signature in meta

	if objects_by_signature.has(obj_signature):
		printerr("ObjectManager: Object with signature %d already registered." % obj_signature)
		# Handle signature collision? For now, overwrite.
	objects_by_signature[obj_signature] = obj

	# Add to appropriate group based on type (requires type info on object)
	if obj.has_method("get_object_type"): # Assuming a method to get type enum/string
		match obj.get_object_type():
			# TODO: Define object type enums (e.g., in GlobalConstants.gd)
			GlobalConstants.ObjectType.SHIP:
				obj.add_to_group(GROUP_SHIP)
			GlobalConstants.ObjectType.WEAPON:
				obj.add_to_group(GROUP_WEAPON)
			GlobalConstants.ObjectType.ASTEROID:
				obj.add_to_group(GROUP_ASTEROID)
			GlobalConstants.ObjectType.DEBRIS:
				obj.add_to_group(GROUP_DEBRIS)
			_:
				printerr("ObjectManager: Unknown object type for grouping: ", obj.name)
	else:
		printerr("ObjectManager: Object %s missing get_object_type() method for grouping." % obj.name)

	#print("ObjectManager: Registered object %s (ID: %d, Sig: %d)" % [obj.name, id, obj_signature])


# Called by objects themselves when they exit the tree
func unregister_object(obj: Node):
	if not is_instance_valid(obj):
		# This can happen during shutdown, don't treat as error
		# printerr("ObjectManager: Attempted to unregister invalid object.")
		return

	var id = obj.get_instance_id()
	var obj_signature = obj.get_meta("signature", -1)

	if objects_by_id.has(id):
		objects_by_id.erase(id)
	#else:
		# Might already be unregistered if freed manually before _exit_tree signal
		# printerr("ObjectManager: Object with ID %d not found for unregistering." % id)

	if obj_signature != -1 and objects_by_signature.has(obj_signature):
		# Ensure we only remove if the signature maps back to this object ID
		if objects_by_signature[obj_signature] == obj:
			objects_by_signature.erase(obj_signature)
	#else:
		# printerr("ObjectManager: Object with signature %d not found for unregistering." % obj_signature)

	# Remove from groups (Godot handles this automatically if node is freed,
	# but good practice if unregistering without freeing immediately)
	# if obj.is_in_group(GROUP_SHIP): obj.remove_from_group(GROUP_SHIP)
	# ... etc for other groups ...

	#print("ObjectManager: Unregistered object %s (ID: %d, Sig: %d)" % [obj.name, id, obj_signature])


# --- Lookup Functions ---

func get_object_by_id(id: int) -> Node:
	return objects_by_id.get(id, null)

func get_object_by_signature(signature: int) -> Node:
	# TODO: Need robust signature handling, especially for multiplayer persistence
	return objects_by_signature.get(signature, null)

# Example: Get all active ships
func get_all_ships() -> Array[Node]:
	return get_tree().get_nodes_in_group(GROUP_SHIP)

# Example: Get all active weapons
func get_all_weapons() -> Array[Node]:
	return get_tree().get_nodes_in_group(GROUP_WEAPON)

# TODO: Add functions for finding ships by name, wing, etc.
# These might require iterating through groups or maintaining separate lists.

# func find_ship_by_name(ship_name: String) -> Node3D:
#	 for ship_node in get_all_ships():
#		 if is_instance_valid(ship_node) and ship_node.name == ship_name:
#			 return ship_node
#	 return null

# --- Utility Functions ---

func get_next_signature() -> int:
	# TODO: Implement a robust way to generate unique signatures,
	# especially for network synchronization. Using instance ID is simple but not persistent.
	# For now, just return a placeholder or rely on instance ID stored in meta.
	return -1 # Indicate signature needs proper assignment

func clear_all_objects():
	# Use with caution - typically called during level unload
	# Unregistering happens automatically when nodes are freed, but this clears the manager's state.
	objects_by_id.clear()
	objects_by_signature.clear()
	print("ObjectManager: Cleared all object references.")
