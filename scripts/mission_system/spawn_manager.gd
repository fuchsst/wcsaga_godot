# scripts/mission_system/spawn_manager.gd
# Node or helper class responsible for instantiating ship and wing scenes.
# Interacts with MissionManager, ObjectManager, and loads scene resources.
class_name SpawnManager
extends Node # Using Node allows easy scene instantiation

# --- Dependencies ---
# Access ObjectManager via singleton: Engine.get_singleton("ObjectManager")
# Access GlobalConstants via singleton: Engine.get_singleton("GlobalConstants")
const ShipInstanceData = preload("res://scripts/resources/mission/ship_instance_data.gd") # Adjusted path
const WingInstanceData = preload("res://scripts/resources/mission/wing_instance_data.gd") # Adjusted path
const ShipBase = preload("res://scripts/ship/ship_base.gd") # Assuming ShipBase script exists
const ShipData = preload("res://scripts/resources/ship_weapon/ship_data.gd") # Adjusted path

# --- Scene Cache (Optional but recommended) ---
var ship_scene_cache: Dictionary = {}

# --- References ---
var mission_manager = null # Set externally

func _ready() -> void:
	print("SpawnManager initialized.")
	# Attempt to get mission_manager if it's a known singleton or node path
	if Engine.has_singleton("MissionManager"):
		mission_manager = Engine.get_singleton("MissionManager")


# Spawns a single ship based on instance data
func spawn_ship(ship_data: ShipInstanceData) -> Node3D:
	if ship_data == null:
		printerr("SpawnManager: Attempted to spawn ship with null data.")
		return null

	# Determine the correct scene path based on ship_data.ship_class_index
	var ship_static_data: ShipData = GlobalConstants.get_ship_data(ship_data.ship_class_index)
	if ship_static_data == null:
		printerr("SpawnManager: Could not find ShipData for class index %d" % ship_data.ship_class_index)
		return null

	# TODO: Need the actual scene path from ShipData. Assuming 'model_scene_path' for now.
	var scene_path = ship_static_data.pof_file # Placeholder - This should be the Godot scene path (.tscn/.glb)
	if scene_path.is_empty() or not scene_path.ends_with(".tscn"): # Basic check, might need .glb too
		# Attempt to construct a path if pof_file holds the base name
		if not ship_static_data.pof_file.is_empty():
			scene_path = "res://scenes/ships_weapons/%s.tscn" % ship_static_data.pof_file.get_file().get_basename()
			print("SpawnManager: Constructed scene path: ", scene_path)
		else:
			printerr("SpawnManager: No scene path or valid POF filename defined for ship class '%s'" % ship_static_data.ship_name)
			return null


	# Load the scene (use cache if implemented)
	var packed_scene: PackedScene = _load_packed_scene(scene_path)
	if packed_scene == null:
		printerr("SpawnManager: Failed to load ship scene: ", scene_path)
		return null

	# Instantiate the scene
	var ship_node = packed_scene.instantiate() as Node3D # Assuming base scene is Node3D
	if ship_node == null:
		printerr("SpawnManager: Failed to instantiate ship scene: ", scene_path)
		return null

	# --- Configure the spawned ship ---
	ship_node.name = ship_data.name # Set the node name

	# Add to the scene tree (assuming SpawnManager is part of the main gameplay scene)
	# Or get the appropriate parent node from MissionManager/GameManager
	# TODO: Determine the correct parent node dynamically (e.g., a "Ships" node in the gameplay scene)
	var ships_parent = get_tree().current_scene.get_node_or_null("Gameplay/Ships") # Example path
	if ships_parent:
		ships_parent.add_child(ship_node)
	else:
		printerr("SpawnManager: Could not find 'Gameplay/Ships' node to parent spawned ship.")
		get_tree().current_scene.add_child(ship_node) # Fallback to scene root

	# Set initial position and orientation
	ship_node.global_transform.origin = ship_data.position
	ship_node.global_transform.basis = ship_data.orientation

	# Get the ShipBase script instance
	# Assuming the script is attached to the root node of the ship scene
	var ship_script = ship_node as ShipBase
	if ship_script == null:
		# Try finding it as a child node named "ShipBase"
		ship_script = ship_node.get_node_or_null("ShipBase") as ShipBase
		if ship_script == null:
			printerr("SpawnManager: Spawned ship '%s' is missing ShipBase script/node." % ship_data.name)
			ship_node.queue_free() # Clean up the incorrectly configured node
			return null

	# Initialize the ship script with static and instance data
	ship_script.initialize_ship(ship_static_data, ship_data)

	# TODO: Apply initial subsystem status from ship_data.subsystem_status
	# TODO: Apply texture replacements from ship_data.texture_replacements
	# TODO: Set initial velocity, hull, shields based on ship_data percentages
	# TODO: Assign AI behavior and goals (call AIController?)
	# TODO: Handle initial docking based on ship_data.initial_dock_points (call DockingManager?)
	# TODO: Set wing info (wing_name, position_in_wing)

	# ObjectManager registration happens in BaseObject._ready(), which should be called
	# automatically after add_child and the node is processed.
	# Ensure the signature from ship_data is passed correctly.
	ship_node.set_meta("signature", ship_data.net_signature) # Pass signature via meta

	print("SpawnManager: Spawned ship '%s' (Class: %s)" % [ship_data.name, ship_static_data.ship_name])
	return ship_node


# Spawns a wave of ships for a wing
func spawn_wing_wave(wing_data: WingInstanceData, wave_number: int, num_to_spawn: int) -> Array[Node3D]:
	if wing_data == null:
		printerr("SpawnManager: Attempted to spawn wing wave with null data.")
		return []

	print("SpawnManager: Spawning wave %d for wing '%s' (%d ships)" % [wave_number, wing_data.name, num_to_spawn])
	var spawned_nodes: Array[Node3D] = []

	# Determine which ships from the wing's list correspond to this wave
	var start_index = (wave_number - 1) * wing_data.ship_names.size() # Assuming simple wave repetition
	var spawned_in_wave = 0

	# Find the corresponding ShipInstanceData resources
	if mission_manager == null or mission_manager.current_mission_data == null:
		printerr("SpawnManager: MissionManager not available to find ship instance data for wing.")
		return []

	var mission_ships = mission_manager.current_mission_data.ships
	var ships_in_wing_instance_data: Array[ShipInstanceData] = []

	# --- Robust linking of wing ships to instance data ---
	# Iterate through all ship instances defined in the mission
	for ship_instance_data in mission_ships:
		# Check if this instance belongs to the target wing
		if ship_instance_data.wing_name == wing_data.name:
			# Check if this instance corresponds to the current wave being spawned
			# This requires knowing how ships are assigned to waves. Assuming simple repetition for now.
			# The original parse logic might assign wingnum and pos_in_wing differently.
			# We need to determine the correct ship instance for the i-th ship in the wave.
			# For now, just add all ships belonging to the wing. This needs refinement.
			ships_in_wing_instance_data.append(ship_instance_data)

	if ships_in_wing_instance_data.is_empty():
		printerr("SpawnManager: No ShipInstanceData found for wing '%s'" % wing_data.name)
		return []

	# Spawn the required number of ships for this wave
	for i in range(num_to_spawn):
		# --- Determine which ShipInstanceData to use for the i-th ship in this wave ---
		# This logic needs to be accurate based on how FS2 assigns ships to waves.
		# Simple modulo might work if ships repeat exactly per wave.
		var instance_index = (start_index + i) % ships_in_wing_instance_data.size()
		if instance_index >= ships_in_wing_instance_data.size():
			printerr("SpawnManager: Calculated invalid instance index for wing '%s' wave %d, ship %d" % [wing_data.name, wave_number, i])
			continue

		var ship_data_to_spawn = ships_in_wing_instance_data[instance_index]

		# Adjust ship name for wave number if multiple waves exist
		if wing_data.num_waves > 1:
			ship_data_to_spawn.name = "%s %d" % [wing_data.name, start_index + i + 1] # Example naming

		# TODO: Calculate arrival position based on wing formation/anchor
		# This needs formation logic and anchor resolution.
		var arrival_pos = ship_data_to_spawn.position # Use parsed position as placeholder
		var arrival_orient = ship_data_to_spawn.orientation # Use parsed orientation as placeholder
		# arrival_pos = _calculate_wing_arrival_position(wing_data, i, num_to_spawn) # Example helper call
		ship_data_to_spawn.position = arrival_pos
		ship_data_to_spawn.orientation = arrival_orient

		# Assign wing-level goals and properties
		# ship_data_to_spawn.ai_goals_sexp = wing_data.ai_goals_sexp # Or merge goals?
		ship_data_to_spawn.wing_name = wing_data.name
		ship_data_to_spawn.position_in_wing = i # Position within this *spawned wave*

		var spawned_node = spawn_ship(ship_data_to_spawn)
		if spawned_node:
			spawned_nodes.append(spawned_node)
			# TODO: Assign wingman AI goals/formation logic after spawn
			# Example: spawned_node.get_node("AIController").set_formation_leader(leader_node)

	return spawned_nodes


# --- Internal Helpers ---

func _load_packed_scene(path: String) -> PackedScene:
	if path.is_empty(): return null

	if ship_scene_cache.has(path):
		return ship_scene_cache[path]

	if not ResourceLoader.exists(path):
		printerr("SpawnManager: Scene file does not exist at path: ", path)
		# Attempt fallback? Try .glb if .tscn failed?
		if path.ends_with(".tscn"):
			var glb_path = path.get_basename() + ".glb"
			if ResourceLoader.exists(glb_path):
				print("SpawnManager: Falling back to .glb: ", glb_path)
				path = glb_path
			else:
				return null
		else:
			return null # No fallback

	var packed_scene = ResourceLoader.load(path) # No type hint needed here
	if packed_scene is PackedScene:
		ship_scene_cache[path] = packed_scene
		return packed_scene
	else:
		printerr("SpawnManager: Failed to load PackedScene at path: ", path, " - Loaded type: ", typeof(packed_scene))
		return null

# TODO: Implement _calculate_wing_arrival_position(wing_data, ship_index_in_wave, total_in_wave)
