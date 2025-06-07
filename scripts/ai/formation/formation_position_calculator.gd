class_name FormationPositionCalculator
extends RefCounted

## Utility class for calculating formation positions and patterns
## Provides algorithms for different formation types and position optimization

enum FormationType {
	DIAMOND,
	VIC,
	LINE_ABREAST,
	COLUMN,
	FINGER_FOUR,
	WALL,
	CUSTOM
}

static func calculate_formation_positions(
	formation_type: FormationType,
	leader_position: Vector3,
	leader_forward: Vector3,
	leader_right: Vector3,
	leader_up: Vector3,
	spacing: float,
	member_count: int,
	custom_data: Dictionary = {}
) -> Array[Vector3]:
	## Calculates formation positions for all members based on formation type
	
	match formation_type:
		FormationType.DIAMOND:
			return _calculate_diamond_positions(leader_position, leader_forward, leader_right, spacing)
		FormationType.VIC:
			return _calculate_vic_positions(leader_position, leader_forward, leader_right, spacing)
		FormationType.LINE_ABREAST:
			return _calculate_line_abreast_positions(leader_position, leader_forward, leader_right, spacing, member_count)
		FormationType.COLUMN:
			return _calculate_column_positions(leader_position, leader_forward, spacing, member_count)
		FormationType.FINGER_FOUR:
			return _calculate_finger_four_positions(leader_position, leader_forward, leader_right, spacing)
		FormationType.WALL:
			return _calculate_wall_positions(leader_position, leader_forward, leader_right, spacing, member_count)
		FormationType.CUSTOM:
			return _calculate_custom_positions(leader_position, leader_forward, leader_right, leader_up, custom_data)
		_:
			return []

static func calculate_formation_orientations(
	formation_type: FormationType,
	leader_forward: Vector3,
	member_count: int,
	custom_data: Dictionary = {}
) -> Array[Vector3]:
	## Calculates formation orientations for all members
	
	var orientations: Array[Vector3] = []
	
	match formation_type:
		FormationType.DIAMOND, FormationType.VIC, FormationType.LINE_ABREAST, FormationType.COLUMN:
			# Standard formations maintain leader's orientation
			for i in range(member_count):
				orientations.append(leader_forward)
		
		FormationType.FINGER_FOUR:
			# Finger four has slight variations in orientation
			orientations = _calculate_finger_four_orientations(leader_forward, member_count)
		
		FormationType.WALL:
			# Wall formation members face slightly outward
			orientations = _calculate_wall_orientations(leader_forward, member_count)
		
		FormationType.CUSTOM:
			# Custom orientations from data
			if custom_data.has("orientations"):
				orientations = custom_data["orientations"]
			else:
				# Default to leader orientation
				for i in range(member_count):
					orientations.append(leader_forward)
		
		_:
			# Default case: all face same direction as leader
			for i in range(member_count):
				orientations.append(leader_forward)
	
	return orientations

static func calculate_optimal_spacing(
	formation_type: FormationType,
	ship_sizes: Array[float],
	safety_margin: float = 20.0
) -> float:
	## Calculates optimal spacing based on ship sizes and formation type
	
	if ship_sizes.is_empty():
		return 100.0
	
	var max_ship_size: float = ship_sizes.max()
	var spacing_multiplier: float = 1.0
	
	match formation_type:
		FormationType.DIAMOND, FormationType.VIC:
			spacing_multiplier = 3.0  # Tighter formations
		FormationType.LINE_ABREAST:
			spacing_multiplier = 2.5
		FormationType.COLUMN:
			spacing_multiplier = 4.0  # More spacing for trailing
		FormationType.FINGER_FOUR:
			spacing_multiplier = 3.5
		FormationType.WALL:
			spacing_multiplier = 4.5  # Wide spacing for capital ship escort
		_:
			spacing_multiplier = 3.0
	
	return max_ship_size * spacing_multiplier + safety_margin

static func adjust_formation_for_obstacles(
	positions: Array[Vector3],
	leader_position: Vector3,
	obstacles: Array[Node3D],
	avoidance_radius: float = 100.0
) -> Array[Vector3]:
	## Adjusts formation positions to avoid obstacles
	
	var adjusted_positions: Array[Vector3] = []
	
	for position in positions:
		var adjusted_pos: Vector3 = position
		
		# Check for conflicts with obstacles
		for obstacle in obstacles:
			if not is_instance_valid(obstacle):
				continue
			
			var obstacle_pos: Vector3 = obstacle.global_position
			var distance_to_obstacle: float = adjusted_pos.distance_to(obstacle_pos)
			
			if distance_to_obstacle < avoidance_radius:
				# Calculate avoidance vector
				var avoidance_vector: Vector3 = (adjusted_pos - obstacle_pos).normalized()
				adjusted_pos = obstacle_pos + avoidance_vector * avoidance_radius
		
		adjusted_positions.append(adjusted_pos)
	
	return adjusted_positions

static func validate_formation_spacing(
	positions: Array[Vector3],
	min_spacing: float = 50.0
) -> bool:
	## Validates that formation positions maintain minimum spacing
	
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var distance: float = positions[i].distance_to(positions[j])
			if distance < min_spacing:
				return false
	
	return true

# Private helper functions for specific formation calculations

static func _calculate_diamond_positions(
	leader_pos: Vector3,
	leader_forward: Vector3,
	leader_right: Vector3,
	spacing: float
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	
	# Right wingman (position 0)
	positions.append(leader_pos + leader_right * spacing + leader_forward * (-spacing * 0.5))
	
	# Left wingman (position 1)
	positions.append(leader_pos + leader_right * (-spacing) + leader_forward * (-spacing * 0.5))
	
	# Trailing wingman (position 2)
	positions.append(leader_pos + leader_forward * (-spacing * 1.5))
	
	return positions

static func _calculate_vic_positions(
	leader_pos: Vector3,
	leader_forward: Vector3,
	leader_right: Vector3,
	spacing: float
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	
	# Right wingman
	positions.append(leader_pos + leader_right * spacing + leader_forward * (-spacing * 0.8))
	
	# Left wingman
	positions.append(leader_pos + leader_right * (-spacing) + leader_forward * (-spacing * 0.8))
	
	return positions

static func _calculate_line_abreast_positions(
	leader_pos: Vector3,
	leader_forward: Vector3,
	leader_right: Vector3,
	spacing: float,
	member_count: int
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	
	for i in range(member_count):
		var offset: float = (i + 1) * spacing
		positions.append(leader_pos + leader_right * offset)
	
	return positions

static func _calculate_column_positions(
	leader_pos: Vector3,
	leader_forward: Vector3,
	spacing: float,
	member_count: int
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	
	for i in range(member_count):
		var offset: float = (i + 1) * spacing
		positions.append(leader_pos + leader_forward * (-offset))
	
	return positions

static func _calculate_finger_four_positions(
	leader_pos: Vector3,
	leader_forward: Vector3,
	leader_right: Vector3,
	spacing: float
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	
	# Right wingman (close)
	positions.append(leader_pos + leader_right * spacing * 0.7 + leader_forward * (-spacing * 0.3))
	
	# Far right wingman
	positions.append(leader_pos + leader_right * spacing * 1.5 + leader_forward * (-spacing * 0.8))
	
	# Far left wingman
	positions.append(leader_pos + leader_right * (-spacing * 1.5) + leader_forward * (-spacing * 0.8))
	
	return positions

static func _calculate_wall_positions(
	leader_pos: Vector3,
	leader_forward: Vector3,
	leader_right: Vector3,
	spacing: float,
	member_count: int
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var wide_spacing: float = spacing * 2.0
	var ships_per_row: int = 4
	var rows: int = (member_count + ships_per_row - 1) / ships_per_row
	
	for i in range(member_count):
		var row: int = i / ships_per_row
		var col: int = i % ships_per_row
		
		var x_offset: float = (col - ships_per_row * 0.5 + 0.5) * wide_spacing
		var z_offset: float = -(row + 1) * spacing * 0.8
		
		positions.append(leader_pos + leader_right * x_offset + leader_forward * z_offset)
	
	return positions

static func _calculate_custom_positions(
	leader_pos: Vector3,
	leader_forward: Vector3,
	leader_right: Vector3,
	leader_up: Vector3,
	custom_data: Dictionary
) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	
	if custom_data.has("relative_positions"):
		var relative_positions: Array = custom_data["relative_positions"]
		
		for offset in relative_positions:
			if offset is Vector3:
				var world_pos: Vector3 = leader_pos + (leader_right * offset.x) + (leader_up * offset.y) + (leader_forward * offset.z)
				positions.append(world_pos)
	
	return positions

static func _calculate_finger_four_orientations(leader_forward: Vector3, member_count: int) -> Array[Vector3]:
	var orientations: Array[Vector3] = []
	
	for i in range(member_count):
		# Slight outward angle for finger four positions
		var angle_offset: float = 0.0
		
		match i:
			0:  # Right wingman
				angle_offset = -5.0  # Degrees
			1:  # Far right
				angle_offset = -10.0
			2:  # Far left
				angle_offset = 10.0
			_:
				angle_offset = 0.0
		
		var rotation_radians: float = deg_to_rad(angle_offset)
		var rotated_forward: Vector3 = leader_forward.rotated(Vector3.UP, rotation_radians)
		orientations.append(rotated_forward)
	
	return orientations

static func _calculate_wall_orientations(leader_forward: Vector3, member_count: int) -> Array[Vector3]:
	var orientations: Array[Vector3] = []
	var ships_per_row: int = 4
	
	for i in range(member_count):
		var col: int = i % ships_per_row
		var angle_offset: float = 0.0
		
		# Outer ships face slightly outward for better coverage
		if col == 0:  # Leftmost
			angle_offset = 15.0
		elif col == ships_per_row - 1:  # Rightmost
			angle_offset = -15.0
		else:
			angle_offset = 0.0
		
		var rotation_radians: float = deg_to_rad(angle_offset)
		var rotated_forward: Vector3 = leader_forward.rotated(Vector3.UP, rotation_radians)
		orientations.append(rotated_forward)
	
	return orientations