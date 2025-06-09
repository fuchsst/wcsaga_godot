@tool
extends HUDGauge
class_name HUDBrackets

# Bracket State
@export var brackets_active: bool = false:
	set(value):
		brackets_active = value
		queue_redraw()
@export var bracket_rect: Rect2 = Rect2(): # Screen coordinates for main target brackets
	set(value):
		bracket_rect = value
		queue_redraw()
@export var subsystem_bracket_active: bool = false:
	set(value):
		subsystem_bracket_active = value
		queue_redraw()
@export var subsystem_bracket_rect: Rect2 = Rect2(): # Screen coordinates for subsystem brackets
	set(value):
		subsystem_bracket_rect = value
		queue_redraw()
@export var target_distance: float = 0.0:
	set(value):
		target_distance = value
		queue_redraw()
@export var target_iff_color: Color = Color.WHITE: # Color based on IFF
	set(value):
		target_iff_color = value
		queue_redraw()
@export var subsystem_iff_color: Color = Color.WHITE: # Color for subsystem bracket
	set(value):
		subsystem_iff_color = value
		queue_redraw()
@export var subsystem_in_sight: bool = true: # Is the subsystem visible? Affects bracket style
	set(value):
		subsystem_in_sight = value
		queue_redraw()

# Visual Settings
@export_group("Visual Settings")
@export var bracket_thickness: float = 1.0
@export var bracket_length_ratio: float = 0.25 # Percentage of width/height for bracket lines
@export var min_bracket_size: Vector2 = Vector2(20, 20) # Minimum screen size
@export var subsystem_min_bracket_size: Vector2 = Vector2(12, 12)
@export var show_distance_on_bracket: bool = true
@export var distance_offset: Vector2 = Vector2(4, 4) # Offset from bottom-right corner

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(200, 200) # Small preview area

func _init() -> void:
	super._init()
	# Brackets don't have a specific gauge ID in the original flags,
	# they are drawn as part of the targeting process.
	# Assigning a placeholder or NONE might be appropriate.
	gauge_id = GaugeType.EMPTY # Or a custom ID if needed later
	is_popup = false

func _ready() -> void:
	super._ready()
	brackets_active = false
	subsystem_bracket_active = false

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship and target exist
	var player_ship = ObjectManager.get_player_ship() if ObjectManager else null
	var target_object_id = player_ship.get("target_object_id", -1) if player_ship and player_ship.has_method("get") else -1
	if not player_ship or not is_instance_valid(player_ship) or target_object_id == -1:
		brackets_active = false
		subsystem_bracket_active = false
		return

	var target_node = ObjectManager.get_object_by_id(target_object_id) if ObjectManager and ObjectManager.has_method("get_object_by_id") else null
	if not is_instance_valid(target_node):
		brackets_active = false
		subsystem_bracket_active = false
		return

	var camera = get_viewport().get_camera_3d()
	if not camera:
		brackets_active = false
		subsystem_bracket_active = false
		return

	# --- Main Target Brackets ---
	var main_rect = _calculate_screen_bounds(target_node, camera)
	if main_rect:
		brackets_active = true
		bracket_rect = main_rect
		target_distance = player_ship.global_position.distance_to(target_node.global_position)
		# Determine IFF color
		var target_team = target_node.get_team() if target_node.has_method("get_team") else 0  # Unknown team
		var player_team = player_ship.get("team", 0) if player_ship.has_method("get") else 0
		target_iff_color = Color.GREEN if ObjectManager.is_friendly(player_team, target_team) else Color.RED
	else:
		brackets_active = false
		target_distance = 0.0

	# --- Subsystem Target Brackets ---
	var subsys_node = player_ship.get("target_subsystem_node", null) if player_ship.has_method("get") else null
	if brackets_active and is_instance_valid(subsys_node):
		var subsys = subsys_node  # Generic subsystem reference
		var subsys_rect = _calculate_screen_bounds(subsys, camera, target_node) # Pass parent for world pos calculation

		if subsys_rect:
			subsystem_bracket_active = true
			subsystem_bracket_rect = subsys_rect
			# Determine subsystem bracket color (usually same as target IFF, but could change if destroyed)
			if subsys.current_hits <= 0.0 and subsys.subsystem_definition and subsys.subsystem_definition.max_hits > 0:
				subsystem_iff_color = Color.GRAY # Example for destroyed
			else:
				subsystem_iff_color = target_iff_color
			# Determine if subsystem is in sight (needs proper check)
			subsystem_in_sight = _is_subsystem_in_sight(target_node, subsys, camera) # Placeholder
		else:
			subsystem_bracket_active = false
	else:
		subsystem_bracket_active = false


# Placeholder: Calculate screen bounds for an object or subsystem
func _calculate_screen_bounds(node: Node3D, camera: Camera3D, parent_ship: Node = null) -> Rect2:
	var aabb: AABB
	var world_transform: Transform3D

	if parent_ship and is_instance_valid(parent_ship):
		# Calculate world position for subsystem
		var subsys = node
		if not subsys.has_method("get") or not subsys.get("subsystem_definition"): return Rect2()
		# Need a way to get the world transform of the subsystem node itself
		# Assuming the node's global_transform is correct
		world_transform = subsys.global_transform
		# Use subsystem radius for AABB estimation
		var radius = subsys.subsystem_definition.radius
		aabb = AABB(-Vector3.ONE * radius, Vector3.ONE * radius * 2.0)
	elif node.has_method("get_aabb"): # Check if it's a VisualInstance3D or similar
		aabb = node.get_aabb()
		world_transform = node.global_transform
	else:
		# Fallback using node position and a default size
		world_transform = node.global_transform
		aabb = AABB(Vector3(-1,-1,-1), Vector3(2,2,2)) # Default 1m cube

	# Project AABB corners to screen space
	var screen_points = []
	for i in range(8):
		var corner_local = aabb.get_endpoint(i)
		var corner_world = world_transform * corner_local
		if camera.is_position_behind(corner_world):
			# If any corner is behind, the projection is unreliable for bounds
			# FS2 logic might handle this differently (clipping?)
			# For now, return null if any point is behind.
			return Rect2()
		var screen_pos = camera.unproject_position(corner_world)
		screen_points.append(screen_pos)

	if screen_points.is_empty():
		return Rect2()

	# Find min/max screen coordinates
	var min_pos = screen_points[0]
	var max_pos = screen_points[0]
	for i in range(1, screen_points.size()):
		min_pos.x = min(min_pos.x, screen_points[i].x)
		min_pos.y = min(min_pos.y, screen_points[i].y)
		max_pos.x = max(max_pos.x, screen_points[i].x)
		max_pos.y = max(max_pos.y, screen_points[i].y)

	# Check if bounds are completely off-screen (basic check)
	var viewport_rect = get_viewport_rect()
	if max_pos.x < viewport_rect.position.x or min_pos.x > viewport_rect.end.x or \
	   max_pos.y < viewport_rect.position.y or min_pos.y > viewport_rect.end.y:
		return Rect2() # Completely off-screen

	return Rect2(min_pos, max_pos - min_pos)


# Placeholder: Check if subsystem is visible (not occluded)
func _is_subsystem_in_sight(parent_ship: ShipBase, subsys: ShipSubsystem, camera: Camera3D) -> bool:
	# TODO: Implement line-of-sight check from camera to subsystem position,
	# potentially ignoring the parent ship's collision body.
	# var space_state = get_world_3d().direct_space_state
	# var query = PhysicsRayQueryParameters3D.create(camera.global_position, subsys.global_position)
	# query.exclude = [parent_ship.get_instance_id()] # Exclude parent ship
	# var result = space_state.intersect_ray(query)
	# return result.is_empty() or result.collider == subsys # Or check distance
	return true # Placeholder


# Draw the brackets
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		super._draw()
		# Draw sample brackets
		var center = preview_size / 2.0
		var sample_rect = Rect2(center - Vector2(40, 30), Vector2(80, 60))
		_draw_brackets_for_rect(sample_rect, Color.YELLOW)
		var sample_sub_rect = Rect2(center + Vector2(10, 5) - Vector2(10, 8), Vector2(20, 16))
		_draw_brackets_for_rect(sample_sub_rect, Color.CYAN, true) # Diamond for subsys
		return

	if not can_draw(): return

	# Draw main target brackets
	if brackets_active:
		_draw_brackets_for_rect(bracket_rect, target_iff_color)
		# Draw distance text
		if show_distance_on_bracket and target_distance > 0:
			var font = ThemeDB.fallback_font
			var font_size = ThemeDB.fallback_font_size
			var dist_text = "%.0fm" % target_distance # Assuming meters
			var text_size = font.get_string_size(dist_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos = Vector2(bracket_rect.end.x + distance_offset.x, bracket_rect.end.y + distance_offset.y + text_size.y)
			# Clamp text position to viewport bounds
			text_pos.x = clamp(text_pos.x, 0, get_viewport_rect().size.x - text_size.x)
			text_pos.y = clamp(text_pos.y, text_size.y, get_viewport_rect().size.y)
			draw_string(font, text_pos, dist_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, target_iff_color)

	# Draw subsystem brackets
	if subsystem_bracket_active:
		_draw_brackets_for_rect(subsystem_bracket_rect, subsystem_iff_color, not subsystem_in_sight) # Use diamond if not in sight


# Helper to draw brackets based on style (square/diamond)
func _draw_brackets_for_rect(rect: Rect2, color: Color, use_diamond: bool = false):
	var x1 = rect.position.x
	var y1 = rect.position.y
	var x2 = rect.end.x
	var y2 = rect.end.y

	# Apply minimum size constraints
	var w = max(x2 - x1, min_bracket_size.x if not use_diamond else subsystem_min_bracket_size.x)
	var h = max(y2 - y1, min_bracket_size.y if not use_diamond else subsystem_min_bracket_size.y)
	var center = rect.get_center()
	x1 = center.x - w / 2.0
	y1 = center.y - h / 2.0
	x2 = center.x + w / 2.0
	y2 = center.y + h / 2.0

	# Calculate bracket line lengths
	var bracket_w = w * bracket_length_ratio
	var bracket_h = h * bracket_length_ratio

	if use_diamond:
		# Draw diamond brackets (simplified outline)
		var half_w = w / 2.0
		var half_h = h / 2.0
		var side_len_sq = half_w*half_w + half_h*half_h
		if side_len_sq < 0.01: return # Avoid division by zero
		var side_len = sqrt(side_len_sq)
		var bracket_len = side_len * bracket_length_ratio * 0.5 # Adjust ratio for diamond corners

		var dx = (bracket_len * half_w) / side_len
		var dy = (bracket_len * half_h) / side_len

		# Top point
		draw_line(Vector2(center.x - dx, y1 + dy), Vector2(center.x, y1), color, bracket_thickness)
		draw_line(Vector2(center.x + dx, y1 + dy), Vector2(center.x, y1), color, bracket_thickness)
		# Left point
		draw_line(Vector2(x1 + dx, center.y - dy), Vector2(x1, center.y), color, bracket_thickness)
		draw_line(Vector2(x1 + dx, center.y + dy), Vector2(x1, center.y), color, bracket_thickness)
		# Bottom point
		draw_line(Vector2(center.x - dx, y2 - dy), Vector2(center.x, y2), color, bracket_thickness)
		draw_line(Vector2(center.x + dx, y2 - dy), Vector2(center.x, y2), color, bracket_thickness)
		# Right point
		draw_line(Vector2(x2 - dx, center.y - dy), Vector2(x2, center.y), color, bracket_thickness)
		draw_line(Vector2(x2 - dx, center.y + dy), Vector2(x2, center.y), color, bracket_thickness)
	else:
		# Draw square brackets
		# Top-Left
		draw_line(Vector2(x1, y1), Vector2(x1 + bracket_w, y1), color, bracket_thickness)
		draw_line(Vector2(x1, y1), Vector2(x1, y1 + bracket_h), color, bracket_thickness)
		# Top-Right
		draw_line(Vector2(x2, y1), Vector2(x2 - bracket_w, y1), color, bracket_thickness)
		draw_line(Vector2(x2, y1), Vector2(x2, y1 + bracket_h), color, bracket_thickness)
		# Bottom-Left
		draw_line(Vector2(x1, y2), Vector2(x1 + bracket_w, y2), color, bracket_thickness)
		draw_line(Vector2(x1, y2), Vector2(x1, y2 - bracket_h), color, bracket_thickness)
		# Bottom-Right
		draw_line(Vector2(x2, y2), Vector2(x2 - bracket_w, y2), color, bracket_thickness)
		draw_line(Vector2(x2, y2), Vector2(x2, y2 - bracket_h), color, bracket_thickness)


func _process(delta: float):
	# Base class handles flashing etc. if needed
	# super._process(delta)
	pass
