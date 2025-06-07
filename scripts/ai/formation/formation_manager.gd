class_name FormationManager
extends Node

## Central manager for AI formation flying and coordination
## Handles formation creation, member management, and position calculations

signal formation_created(formation_id: String, formation: Formation)
signal formation_destroyed(formation_id: String)
signal member_joined_formation(ship: Node3D, formation_id: String, position: int)
signal member_left_formation(ship: Node3D, formation_id: String)
signal formation_leader_changed(formation_id: String, new_leader: Node3D, old_leader: Node3D)

enum FormationType {
	DIAMOND,        ## 4-ship diamond formation
	VIC,           ## 3-ship V formation  
	LINE_ABREAST,  ## Ships side by side
	COLUMN,        ## Ships in single file
	FINGER_FOUR,   ## 4-ship finger formation
	WALL,          ## Large capital ship screen
	CUSTOM         ## User-defined formation pattern
}

var active_formations: Dictionary = {}
var formation_templates: Dictionary = {}
var next_formation_id: int = 1

class Formation:
	var formation_id: String
	var leader: Node3D
	var members: Array[Node3D] = []
	var formation_type: FormationType
	var formation_spacing: float = 100.0
	var formation_positions: Array[Vector3] = []
	var formation_orientations: Array[Vector3] = []
	var formation_data: Dictionary = {}
	var integrity_threshold: float = 0.8
	var last_update_time: float = 0.0
	
	func _init(id: String, leader_ship: Node3D, type: FormationType, spacing: float = 100.0) -> void:
		formation_id = id
		leader = leader_ship
		formation_type = type
		formation_spacing = spacing
		formation_data = {}
		last_update_time = Time.get_time_from_start()
	
	func add_member(ship: Node3D, position_index: int = -1) -> bool:
		if ship == leader:
			return false  # Leader can't be a member
		
		if ship in members:
			return false  # Already a member
		
		# Find next available position if not specified
		if position_index == -1:
			position_index = members.size()
		
		# Ensure we have enough formation positions
		while formation_positions.size() <= position_index:
			formation_positions.append(Vector3.ZERO)
			formation_orientations.append(Vector3.FORWARD)
		
		members.append(ship)
		
		# Set formation information on the ship's AI agent
		var ai_agent: WCSAIAgent = _get_ai_agent(ship)
		if ai_agent:
			ai_agent.set_formation_leader(leader)
			ai_agent.set_formation_position_index(position_index)
			ai_agent.set_formation_manager(self)
		
		return true
	
	func remove_member(ship: Node3D) -> bool:
		var index: int = members.find(ship)
		if index == -1:
			return false
		
		members.remove_at(index)
		
		# Clear formation information on the ship's AI agent
		var ai_agent: WCSAIAgent = _get_ai_agent(ship)
		if ai_agent:
			ai_agent.clear_formation_assignment()
		
		return true
	
	func change_leader(new_leader: Node3D) -> bool:
		if new_leader == leader:
			return false
		
		var old_leader: Node3D = leader
		
		# Remove new leader from members if they were a member
		remove_member(new_leader)
		
		# Set new leader
		leader = new_leader
		
		# Update all members with new leader
		for member in members:
			var ai_agent: WCSAIAgent = _get_ai_agent(member)
			if ai_agent:
				ai_agent.set_formation_leader(leader)
		
		return true
	
	func get_member_count() -> int:
		return members.size()
	
	func get_formation_position(position_index: int) -> Vector3:
		if position_index >= 0 and position_index < formation_positions.size():
			return formation_positions[position_index]
		return Vector3.ZERO
	
	func get_formation_orientation(position_index: int) -> Vector3:
		if position_index >= 0 and position_index < formation_orientations.size():
			return formation_orientations[position_index]
		return Vector3.FORWARD
	
	func update_formation_positions() -> void:
		if not is_instance_valid(leader):
			return
		
		var leader_pos: Vector3 = leader.global_position
		var leader_forward: Vector3 = _get_ship_forward(leader)
		var leader_right: Vector3 = leader_forward.cross(Vector3.UP).normalized()
		var leader_up: Vector3 = Vector3.UP
		
		# Update positions based on formation type
		_calculate_formation_positions(leader_pos, leader_forward, leader_right, leader_up)
		
		last_update_time = Time.get_time_from_start()
	
	func get_formation_integrity() -> float:
		if members.is_empty():
			return 1.0
		
		var total_compliance: float = 0.0
		var checked_members: int = 0
		
		for i in range(members.size()):
			var member: Node3D = members[i]
			if not is_instance_valid(member):
				continue
			
			var target_pos: Vector3 = get_formation_position(i)
			var actual_pos: Vector3 = member.global_position
			var distance: float = actual_pos.distance_to(target_pos)
			
			# Calculate compliance (1.0 = perfect, 0.0 = completely out of position)
			var max_acceptable_distance: float = formation_spacing * 1.5
			var compliance: float = 1.0 - clamp(distance / max_acceptable_distance, 0.0, 1.0)
			
			total_compliance += compliance
			checked_members += 1
		
		return total_compliance / max(checked_members, 1) if checked_members > 0 else 0.0
	
	func is_formation_intact() -> bool:
		return get_formation_integrity() >= integrity_threshold
	
	func _get_ai_agent(ship: Node3D) -> WCSAIAgent:
		if ship.has_method("get_ai_agent"):
			return ship.get_ai_agent()
		return ship.get_node("WCSAIAgent") as WCSAIAgent
	
	func _get_ship_forward(ship: Node3D) -> Vector3:
		if ship.has_method("get_forward_vector"):
			return ship.get_forward_vector()
		return -ship.global_transform.basis.z
	
	func _calculate_formation_positions(leader_pos: Vector3, leader_forward: Vector3, leader_right: Vector3, leader_up: Vector3) -> void:
		match formation_type:
			FormationType.DIAMOND:
				_setup_diamond_formation(leader_pos, leader_forward, leader_right, leader_up)
			FormationType.VIC:
				_setup_vic_formation(leader_pos, leader_forward, leader_right, leader_up)
			FormationType.LINE_ABREAST:
				_setup_line_abreast_formation(leader_pos, leader_forward, leader_right, leader_up)
			FormationType.COLUMN:
				_setup_column_formation(leader_pos, leader_forward, leader_right, leader_up)
			FormationType.FINGER_FOUR:
				_setup_finger_four_formation(leader_pos, leader_forward, leader_right, leader_up)
			FormationType.WALL:
				_setup_wall_formation(leader_pos, leader_forward, leader_right, leader_up)
			FormationType.CUSTOM:
				_setup_custom_formation(leader_pos, leader_forward, leader_right, leader_up)
	
	func _setup_diamond_formation(leader_pos: Vector3, leader_forward: Vector3, leader_right: Vector3, leader_up: Vector3) -> void:
		formation_positions.clear()
		formation_orientations.clear()
		
		# Diamond formation: leader at front, 2 wingmen to sides, 1 trailing
		var spacing: float = formation_spacing
		
		# Position 0: Right wingman
		formation_positions.append(leader_pos + leader_right * spacing + leader_forward * (-spacing * 0.5))
		formation_orientations.append(leader_forward)
		
		# Position 1: Left wingman  
		formation_positions.append(leader_pos + leader_right * (-spacing) + leader_forward * (-spacing * 0.5))
		formation_orientations.append(leader_forward)
		
		# Position 2: Trailing wingman
		formation_positions.append(leader_pos + leader_forward * (-spacing * 1.5))
		formation_orientations.append(leader_forward)
	
	func _setup_vic_formation(leader_pos: Vector3, leader_forward: Vector3, leader_right: Vector3, leader_up: Vector3) -> void:
		formation_positions.clear()
		formation_orientations.clear()
		
		# V formation: leader at front, wingmen behind and to sides
		var spacing: float = formation_spacing
		
		# Position 0: Right wingman
		formation_positions.append(leader_pos + leader_right * spacing + leader_forward * (-spacing * 0.8))
		formation_orientations.append(leader_forward)
		
		# Position 1: Left wingman
		formation_positions.append(leader_pos + leader_right * (-spacing) + leader_forward * (-spacing * 0.8))
		formation_orientations.append(leader_forward)
	
	func _setup_line_abreast_formation(leader_pos: Vector3, leader_forward: Vector3, leader_right: Vector3, leader_up: Vector3) -> void:
		formation_positions.clear()
		formation_orientations.clear()
		
		# Line abreast: ships side by side
		var spacing: float = formation_spacing
		var member_count: int = max(members.size(), 4)  # Plan for up to 4 members
		
		for i in range(member_count):
			var offset: float = (i + 1) * spacing
			formation_positions.append(leader_pos + leader_right * offset)
			formation_orientations.append(leader_forward)
	
	func _setup_column_formation(leader_pos: Vector3, leader_forward: Vector3, leader_right: Vector3, leader_up: Vector3) -> void:
		formation_positions.clear()
		formation_orientations.clear()
		
		# Column: ships in single file behind leader
		var spacing: float = formation_spacing
		var member_count: int = max(members.size(), 6)  # Plan for up to 6 members
		
		for i in range(member_count):
			var offset: float = (i + 1) * spacing
			formation_positions.append(leader_pos + leader_forward * (-offset))
			formation_orientations.append(leader_forward)
	
	func _setup_finger_four_formation(leader_pos: Vector3, leader_forward: Vector3, leader_right: Vector3, leader_up: Vector3) -> void:
		formation_positions.clear()
		formation_orientations.clear()
		
		# Finger Four: 2 pairs in echelon
		var spacing: float = formation_spacing
		
		# Position 0: Right wingman (close)
		formation_positions.append(leader_pos + leader_right * spacing * 0.7 + leader_forward * (-spacing * 0.3))
		formation_orientations.append(leader_forward)
		
		# Position 1: Far right wingman
		formation_positions.append(leader_pos + leader_right * spacing * 1.5 + leader_forward * (-spacing * 0.8))
		formation_orientations.append(leader_forward)
		
		# Position 2: Far left wingman  
		formation_positions.append(leader_pos + leader_right * (-spacing * 1.5) + leader_forward * (-spacing * 0.8))
		formation_orientations.append(leader_forward)
	
	func _setup_wall_formation(leader_pos: Vector3, leader_forward: Vector3, leader_right: Vector3, leader_up: Vector3) -> void:
		formation_positions.clear()
		formation_orientations.clear()
		
		# Wall formation: wide spread for capital ship escort
		var spacing: float = formation_spacing * 2.0  # Wider spacing
		var member_count: int = max(members.size(), 8)  # Plan for up to 8 members
		
		# Create a wall pattern with multiple rows
		var ships_per_row: int = 4
		var rows: int = (member_count + ships_per_row - 1) / ships_per_row
		
		for i in range(member_count):
			var row: int = i / ships_per_row
			var col: int = i % ships_per_row
			
			var x_offset: float = (col - ships_per_row * 0.5 + 0.5) * spacing
			var z_offset: float = -(row + 1) * spacing * 0.8
			
			formation_positions.append(leader_pos + leader_right * x_offset + leader_forward * z_offset)
			formation_orientations.append(leader_forward)
	
	func _setup_custom_formation(leader_pos: Vector3, leader_forward: Vector3, leader_right: Vector3, leader_up: Vector3) -> void:
		# Custom formation uses pre-defined positions from formation_data
		if formation_data.has("custom_positions"):
			var custom_positions: Array = formation_data["custom_positions"]
			formation_positions.clear()
			formation_orientations.clear()
			
			for offset in custom_positions:
				if offset is Vector3:
					var world_pos: Vector3 = leader_pos + (leader_right * offset.x) + (leader_up * offset.y) + (leader_forward * offset.z)
					formation_positions.append(world_pos)
					formation_orientations.append(leader_forward)

func _ready() -> void:
	set_name("FormationManager")
	_initialize_formation_templates()

func _initialize_formation_templates() -> void:
	## Initialize standard formation templates with default parameters
	formation_templates[FormationType.DIAMOND] = {
		"name": "Diamond",
		"max_members": 3,
		"default_spacing": 100.0,
		"description": "Classic 4-ship diamond formation"
	}
	
	formation_templates[FormationType.VIC] = {
		"name": "Vic",
		"max_members": 2,
		"default_spacing": 120.0,
		"description": "3-ship V formation"
	}
	
	formation_templates[FormationType.LINE_ABREAST] = {
		"name": "Line Abreast",
		"max_members": 6,
		"default_spacing": 80.0,
		"description": "Ships positioned side by side"
	}
	
	formation_templates[FormationType.COLUMN] = {
		"name": "Column", 
		"max_members": 8,
		"default_spacing": 90.0,
		"description": "Ships in single file formation"
	}
	
	formation_templates[FormationType.FINGER_FOUR] = {
		"name": "Finger Four",
		"max_members": 3,
		"default_spacing": 110.0,
		"description": "Fighter squadron finger-four formation"
	}
	
	formation_templates[FormationType.WALL] = {
		"name": "Wall",
		"max_members": 12,
		"default_spacing": 150.0,
		"description": "Wide escort formation for capital ships"
	}

func create_formation(leader: Node3D, formation_type: FormationType, spacing: float = 0.0) -> String:
	## Creates a new formation with the specified leader and type
	if not is_instance_valid(leader):
		push_error("FormationManager: Invalid leader provided for formation")
		return ""
	
	# Use template default spacing if not specified
	var actual_spacing: float = spacing
	if spacing <= 0.0 and formation_templates.has(formation_type):
		actual_spacing = formation_templates[formation_type]["default_spacing"]
	
	if actual_spacing <= 0.0:
		actual_spacing = 100.0  # Fallback default
	
	var formation_id: String = "formation_" + str(next_formation_id)
	next_formation_id += 1
	
	var formation: Formation = Formation.new(formation_id, leader, formation_type, actual_spacing)
	active_formations[formation_id] = formation
	
	# Set formation leader on the leader's AI agent
	var leader_ai: WCSAIAgent = formation._get_ai_agent(leader)
	if leader_ai:
		leader_ai.set_as_formation_leader(formation_id, self)
	
	formation_created.emit(formation_id, formation)
	return formation_id

func destroy_formation(formation_id: String) -> bool:
	## Destroys a formation and clears all member assignments
	if not active_formations.has(formation_id):
		return false
	
	var formation: Formation = active_formations[formation_id]
	
	# Clear formation assignments for all members
	for member in formation.members:
		if is_instance_valid(member):
			var ai_agent: WCSAIAgent = formation._get_ai_agent(member)
			if ai_agent:
				ai_agent.clear_formation_assignment()
	
	# Clear leader assignment
	if is_instance_valid(formation.leader):
		var leader_ai: WCSAIAgent = formation._get_ai_agent(formation.leader)
		if leader_ai:
			leader_ai.clear_formation_leadership()
	
	active_formations.erase(formation_id)
	formation_destroyed.emit(formation_id)
	return true

func add_ship_to_formation(formation_id: String, ship: Node3D, position_index: int = -1) -> bool:
	## Adds a ship to an existing formation
	if not active_formations.has(formation_id):
		push_error("FormationManager: Formation " + formation_id + " does not exist")
		return false
	
	if not is_instance_valid(ship):
		push_error("FormationManager: Invalid ship provided")
		return false
	
	var formation: Formation = active_formations[formation_id]
	if formation.add_member(ship, position_index):
		member_joined_formation.emit(ship, formation_id, position_index)
		return true
	
	return false

func remove_ship_from_formation(formation_id: String, ship: Node3D) -> bool:
	## Removes a ship from a formation
	if not active_formations.has(formation_id):
		return false
	
	var formation: Formation = active_formations[formation_id]
	if formation.remove_member(ship):
		member_left_formation.emit(ship, formation_id)
		return true
	
	return false

func change_formation_leader(formation_id: String, new_leader: Node3D) -> bool:
	## Changes the leader of an existing formation
	if not active_formations.has(formation_id) or not is_instance_valid(new_leader):
		return false
	
	var formation: Formation = active_formations[formation_id]
	var old_leader: Node3D = formation.leader
	
	if formation.change_leader(new_leader):
		formation_leader_changed.emit(formation_id, new_leader, old_leader)
		return true
	
	return false

func get_formation(formation_id: String) -> Formation:
	## Returns the formation object for the given ID
	return active_formations.get(formation_id)

func get_formation_for_ship(ship: Node3D) -> Formation:
	## Finds the formation that contains the specified ship
	for formation in active_formations.values():
		if formation.leader == ship or ship in formation.members:
			return formation
	return null

func get_ship_formation_id(ship: Node3D) -> String:
	## Returns the formation ID for the ship, or empty string if not in formation
	var formation: Formation = get_formation_for_ship(ship)
	return formation.formation_id if formation else ""

func get_ship_formation_position(ship: Node3D) -> Vector3:
	## Returns the target formation position for the ship
	var formation: Formation = get_formation_for_ship(ship)
	if not formation:
		return Vector3.ZERO
	
	if ship == formation.leader:
		return ship.global_position  # Leader's position is their current position
	
	var member_index: int = formation.members.find(ship)
	if member_index != -1:
		formation.update_formation_positions()
		return formation.get_formation_position(member_index)
	
	return Vector3.ZERO

func get_ship_formation_orientation(ship: Node3D) -> Vector3:
	## Returns the target formation orientation for the ship
	var formation: Formation = get_formation_for_ship(ship)
	if not formation:
		return Vector3.FORWARD
	
	if ship == formation.leader:
		return formation._get_ship_forward(ship)
	
	var member_index: int = formation.members.find(ship)
	if member_index != -1:
		return formation.get_formation_orientation(member_index)
	
	return Vector3.FORWARD

func update_all_formations() -> void:
	## Updates position calculations for all active formations
	for formation in active_formations.values():
		formation.update_formation_positions()

func get_formation_integrity(formation_id: String) -> float:
	## Returns formation integrity (0.0 = broken, 1.0 = perfect)
	var formation: Formation = active_formations.get(formation_id)
	return formation.get_formation_integrity() if formation else 0.0

func get_active_formation_count() -> int:
	## Returns the number of active formations
	return active_formations.size()

func get_formation_debug_info(formation_id: String) -> Dictionary:
	## Returns detailed debug information about a formation
	var formation: Formation = active_formations.get(formation_id)
	if not formation:
		return {"error": "Formation not found"}
	
	return {
		"formation_id": formation_id,
		"leader": formation.leader.name if is_instance_valid(formation.leader) else "Invalid",
		"type": FormationType.keys()[formation.formation_type],
		"member_count": formation.get_member_count(),
		"spacing": formation.formation_spacing,
		"integrity": formation.get_formation_integrity(),
		"is_intact": formation.is_formation_intact(),
		"last_update": formation.last_update_time,
		"members": formation.members.map(func(ship): return ship.name if is_instance_valid(ship) else "Invalid")
	}

func cleanup_invalid_formations() -> void:
	## Removes formations with invalid leaders or no members
	var formations_to_remove: Array[String] = []
	
	for formation_id in active_formations.keys():
		var formation: Formation = active_formations[formation_id]
		
		# Check if leader is still valid
		if not is_instance_valid(formation.leader):
			formations_to_remove.append(formation_id)
			continue
		
		# Remove invalid members
		var valid_members: Array[Node3D] = []
		for member in formation.members:
			if is_instance_valid(member):
				valid_members.append(member)
		
		formation.members = valid_members
		
		# If no members remain, mark for removal
		if formation.members.is_empty():
			formations_to_remove.append(formation_id)
	
	# Remove invalid formations
	for formation_id in formations_to_remove:
		destroy_formation(formation_id)

# Called every frame to maintain formations
func _process(_delta: float) -> void:
	# Update all formations periodically
	if Time.get_time_from_start() - _last_formation_update > 0.1:  # 10 FPS update rate
		update_all_formations()
		_last_formation_update = Time.get_time_from_start()
	
	# Cleanup invalid formations less frequently
	if Time.get_time_from_start() - _last_cleanup_time > 5.0:  # Every 5 seconds
		cleanup_invalid_formations()
		_last_cleanup_time = Time.get_time_from_start()

var _last_formation_update: float = 0.0
var _last_cleanup_time: float = 0.0