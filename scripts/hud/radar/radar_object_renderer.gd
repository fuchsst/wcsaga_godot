class_name RadarObjectRenderer
extends Control

## HUD-009 Component 3: Radar Object Renderer
## Handles visual rendering of radar contacts with type-specific icons and color coding
## Provides friend/foe identification and object classification display

signal contact_selected(contact: RadarDisplay3D.RadarContact)
signal contact_hovered(contact: RadarDisplay3D.RadarContact)

# Object type icons and visual configuration
var object_icons: Dictionary = {}
var object_colors: Dictionary = {}
var object_sizes: Dictionary = {}

# IFF color coding
var iff_colors: Dictionary = {
	"friendly": Color.GREEN,
	"enemy": Color.RED,
	"neutral": Color.YELLOW,
	"unknown": Color.GRAY
}

# Display configuration
var show_labels: bool = true
var show_range_indicators: bool = true
var show_elevation_markers: bool = true
var icon_base_size: float = 8.0
var label_font_size: int = 10

# Rendering data
var radar_contacts: Array[RadarDisplay3D.RadarContact] = []
var spatial_manager: RadarSpatialManager
var selected_contact: RadarDisplay3D.RadarContact = null
var hovered_contact: RadarDisplay3D.RadarContact = null

# Performance optimization
var max_rendered_contacts: int = 100
var lod_levels: Dictionary = {
	"full": 2000.0,      # Full detail within 2km
	"medium": 5000.0,    # Medium detail within 5km
	"low": 15000.0,      # Low detail within 15km
	"minimal": 50000.0   # Minimal detail beyond 15km
}

# Visual effects
var blink_timer: float = 0.0
var blink_rate: float = 2.0  # Blinks per second
var flash_contacts: Array[RadarDisplay3D.RadarContact] = []

# Font for labels
var label_font: Font

func _ready() -> void:
	_initialize_object_renderer()
	
	# Connect input events
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _initialize_object_renderer() -> void:
	print("RadarObjectRenderer: Initializing object renderer...")
	
	# Load default font
	label_font = ThemeDB.fallback_font
	
	# Initialize object visual configurations
	_setup_object_icons()
	_setup_object_colors()
	_setup_object_sizes()
	
	print("RadarObjectRenderer: Object renderer initialized")

func _setup_object_icons() -> void:
	# Create simple procedural icons for different object types
	# In a full implementation, these would be loaded from asset files
	
	object_icons = {
		RadarDisplay3D.RadarContact.ObjectType.FIGHTER: _create_fighter_icon(),
		RadarDisplay3D.RadarContact.ObjectType.BOMBER: _create_bomber_icon(),
		RadarDisplay3D.RadarContact.ObjectType.CRUISER: _create_cruiser_icon(),
		RadarDisplay3D.RadarContact.ObjectType.CAPITAL: _create_capital_icon(),
		RadarDisplay3D.RadarContact.ObjectType.STATION: _create_station_icon(),
		RadarDisplay3D.RadarContact.ObjectType.MISSILE: _create_missile_icon(),
		RadarDisplay3D.RadarContact.ObjectType.DEBRIS: _create_debris_icon(),
		RadarDisplay3D.RadarContact.ObjectType.WAYPOINT: _create_waypoint_icon(),
		RadarDisplay3D.RadarContact.ObjectType.UNKNOWN: _create_unknown_icon()
	}

func _create_fighter_icon() -> Texture2D:
	# Create a simple triangle icon for fighters
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Draw triangle
	var points = PackedVector2Array([
		Vector2(8, 2),    # Top
		Vector2(3, 14),   # Bottom left
		Vector2(13, 14)   # Bottom right
	])
	
	_draw_polygon_on_image(image, points, Color.WHITE)
	
	var texture = ImageTexture.create_from_image(image)
	return texture

func _create_bomber_icon() -> Texture2D:
	# Create a diamond icon for bombers
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var points = PackedVector2Array([
		Vector2(8, 2),    # Top
		Vector2(14, 8),   # Right
		Vector2(8, 14),   # Bottom
		Vector2(2, 8)     # Left
	])
	
	_draw_polygon_on_image(image, points, Color.WHITE)
	
	return ImageTexture.create_from_image(image)

func _create_cruiser_icon() -> Texture2D:
	# Create a cross icon for cruisers
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Horizontal line
	for x in range(4, 12):
		image.set_pixel(x, 8, Color.WHITE)
	
	# Vertical line
	for y in range(4, 12):
		image.set_pixel(8, y, Color.WHITE)
	
	return ImageTexture.create_from_image(image)

func _create_capital_icon() -> Texture2D:
	# Create a square icon for capital ships
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Draw filled square
	for x in range(4, 12):
		for y in range(4, 12):
			image.set_pixel(x, y, Color.WHITE)
	
	return ImageTexture.create_from_image(image)

func _create_station_icon() -> Texture2D:
	# Create a circle icon for stations
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Draw circle
	var center = Vector2(8, 8)
	var radius = 6
	
	for x in range(16):
		for y in range(16):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius and dist >= radius - 1:
				image.set_pixel(x, y, Color.WHITE)
	
	return ImageTexture.create_from_image(image)

func _create_missile_icon() -> Texture2D:
	# Create a small arrow icon for missiles
	var image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var points = PackedVector2Array([
		Vector2(6, 1),    # Top
		Vector2(9, 11),   # Bottom right
		Vector2(6, 8),    # Middle
		Vector2(3, 11)    # Bottom left
	])
	
	_draw_polygon_on_image(image, points, Color.WHITE)
	
	return ImageTexture.create_from_image(image)

func _create_debris_icon() -> Texture2D:
	# Create a small dot icon for debris
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Draw small filled circle
	image.set_pixel(3, 3, Color.WHITE)
	image.set_pixel(4, 3, Color.WHITE)
	image.set_pixel(3, 4, Color.WHITE)
	image.set_pixel(4, 4, Color.WHITE)
	
	return ImageTexture.create_from_image(image)

func _create_waypoint_icon() -> Texture2D:
	# Create a plus icon for waypoints
	var image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Horizontal line
	for x in range(3, 9):
		image.set_pixel(x, 6, Color.WHITE)
	
	# Vertical line
	for y in range(3, 9):
		image.set_pixel(6, y, Color.WHITE)
	
	return ImageTexture.create_from_image(image)

func _create_unknown_icon() -> Texture2D:
	# Create a question mark icon for unknown objects
	var image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Simple question mark (stylized)
	image.set_pixel(6, 2, Color.WHITE)
	image.set_pixel(6, 3, Color.WHITE)
	image.set_pixel(6, 4, Color.WHITE)
	image.set_pixel(6, 6, Color.WHITE)
	image.set_pixel(6, 8, Color.WHITE)
	
	return ImageTexture.create_from_image(image)

func _draw_polygon_on_image(image: Image, points: PackedVector2Array, color: Color) -> void:
	# Simple polygon drawing - in a full implementation this would be more sophisticated
	for i in range(points.size()):
		var start = points[i]
		var end = points[(i + 1) % points.size()]
		_draw_line_on_image(image, start, end, color)

func _draw_line_on_image(image: Image, start: Vector2, end: Vector2, color: Color) -> void:
	# Bresenham line algorithm simplified
	var dx = abs(end.x - start.x)
	var dy = abs(end.y - start.y)
	var steps = max(dx, dy)
	
	if steps == 0:
		image.set_pixel(int(start.x), int(start.y), color)
		return
	
	var x_inc = (end.x - start.x) / steps
	var y_inc = (end.y - start.y) / steps
	
	for i in range(int(steps) + 1):
		var x = int(start.x + x_inc * i)
		var y = int(start.y + y_inc * i)
		if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
			image.set_pixel(x, y, color)

func _setup_object_colors() -> void:
	# Base colors for different object types (modified by IFF)
	object_colors = {
		RadarDisplay3D.RadarContact.ObjectType.FIGHTER: Color.WHITE,
		RadarDisplay3D.RadarContact.ObjectType.BOMBER: Color.ORANGE,
		RadarDisplay3D.RadarContact.ObjectType.CRUISER: Color.CYAN,
		RadarDisplay3D.RadarContact.ObjectType.CAPITAL: Color.MAGENTA,
		RadarDisplay3D.RadarContact.ObjectType.STATION: Color.BLUE,
		RadarDisplay3D.RadarContact.ObjectType.MISSILE: Color.RED,
		RadarDisplay3D.RadarContact.ObjectType.DEBRIS: Color.GRAY,
		RadarDisplay3D.RadarContact.ObjectType.WAYPOINT: Color.GREEN,
		RadarDisplay3D.RadarContact.ObjectType.UNKNOWN: Color.GRAY
	}

func _setup_object_sizes() -> void:
	# Size multipliers for different object types
	object_sizes = {
		RadarDisplay3D.RadarContact.ObjectType.FIGHTER: 1.0,
		RadarDisplay3D.RadarContact.ObjectType.BOMBER: 1.2,
		RadarDisplay3D.RadarContact.ObjectType.CRUISER: 1.5,
		RadarDisplay3D.RadarContact.ObjectType.CAPITAL: 2.0,
		RadarDisplay3D.RadarContact.ObjectType.STATION: 2.5,
		RadarDisplay3D.RadarContact.ObjectType.MISSILE: 0.7,
		RadarDisplay3D.RadarContact.ObjectType.DEBRIS: 0.5,
		RadarDisplay3D.RadarContact.ObjectType.WAYPOINT: 1.0,
		RadarDisplay3D.RadarContact.ObjectType.UNKNOWN: 1.0
	}

## Setup renderer with parent reference
func setup_renderer(parent_radar: Node) -> void:
	# Store reference for callbacks if needed
	pass

## Update rendering data
func update_render_data(contacts: Array[RadarDisplay3D.RadarContact], spatial_mgr: RadarSpatialManager) -> void:
	radar_contacts = contacts
	spatial_manager = spatial_mgr
	queue_redraw()  # Trigger _draw() call

## Custom drawing
func _draw() -> void:
	if not spatial_manager:
		return
	
	# Update blink timer for flashing effects
	blink_timer += get_process_delta_time()
	
	# Draw range rings first
	_draw_range_rings()
	
	# Draw radar contacts
	_draw_radar_contacts()
	
	# Draw elevation markers if enabled
	if show_elevation_markers:
		_draw_elevation_markers()

func _draw_range_rings() -> void:
	if not show_range_indicators:
		return
	
	var range_rings = spatial_manager.get_range_rings()
	var ring_color = Color.GREEN
	ring_color.a = 0.3  # Semi-transparent
	
	for ring in range_rings:
		if ring.visible:
			draw_arc(ring.center, ring.radius, 0, TAU, 32, ring_color, 1.0)

func _draw_radar_contacts() -> void:
	var contacts_drawn = 0
	
	for contact in radar_contacts:
		if contacts_drawn >= max_rendered_contacts:
			break
		
		_draw_single_contact(contact)
		contacts_drawn += 1

func _draw_single_contact(contact: RadarDisplay3D.RadarContact) -> void:
	# Determine LOD level
	var lod_level = _get_lod_level(contact.distance)
	
	# Skip minimal LOD if too many contacts
	if lod_level == "minimal" and radar_contacts.size() > 50:
		return
	
	# Get visual properties
	var icon = object_icons.get(contact.object_type, object_icons[RadarDisplay3D.RadarContact.ObjectType.UNKNOWN])
	var base_color = object_colors.get(contact.object_type, Color.WHITE)
	var iff_color = iff_colors.get(contact.iff_status, Color.GRAY)
	var size_multiplier = object_sizes.get(contact.object_type, 1.0)
	
	# Blend base color with IFF color
	var final_color = base_color.lerp(iff_color, 0.7)
	
	# Apply targeting highlight
	if contact.is_targeted:
		final_color = final_color.lerp(Color.WHITE, 0.5)
	
	# Apply blinking effect for certain contacts
	if contact in flash_contacts:
		var blink_alpha = (sin(blink_timer * blink_rate * TAU) + 1.0) * 0.5
		final_color.a = blink_alpha
	
	# Calculate icon size based on LOD and distance
	var icon_size = _calculate_icon_size(contact, size_multiplier, lod_level)
	
	# Draw the icon
	var icon_rect = Rect2(contact.radar_position - icon_size * 0.5, icon_size)
	draw_texture_rect(icon, icon_rect, false, final_color)
	
	# Draw selection indicator
	if contact == selected_contact:
		_draw_selection_indicator(contact.radar_position, icon_size.length() * 0.7)
	
	# Draw elevation indicator
	if show_elevation_markers and abs(contact.elevation) > 0.1:
		_draw_elevation_indicator(contact.radar_position, contact.elevation, icon_size.x)
	
	# Draw label if enabled and appropriate LOD
	if show_labels and lod_level in ["full", "medium"]:
		_draw_contact_label(contact, icon_size)

func _get_lod_level(distance: float) -> String:
	if distance <= lod_levels.full:
		return "full"
	elif distance <= lod_levels.medium:
		return "medium"
	elif distance <= lod_levels.low:
		return "low"
	else:
		return "minimal"

func _calculate_icon_size(contact: RadarDisplay3D.RadarContact, size_multiplier: float, lod_level: String) -> Vector2:
	var base_size = icon_base_size * size_multiplier
	
	# Apply LOD scaling
	match lod_level:
		"full":
			base_size *= 1.0
		"medium":
			base_size *= 0.8
		"low":
			base_size *= 0.6
		"minimal":
			base_size *= 0.4
	
	# Apply distance scaling (closer objects appear slightly larger)
	var distance_factor = clamp(2000.0 / max(contact.distance, 500.0), 0.5, 2.0)
	base_size *= distance_factor
	
	# Apply radar signature scaling
	base_size *= clamp(contact.radar_signature, 0.5, 2.0)
	
	return Vector2(base_size, base_size)

func _draw_selection_indicator(position: Vector2, radius: float) -> void:
	# Draw pulsing circle around selected contact
	var pulse_factor = (sin(blink_timer * 3.0) + 1.0) * 0.5
	var selection_radius = radius + (pulse_factor * 5.0)
	var selection_color = Color.WHITE
	selection_color.a = 0.8 - (pulse_factor * 0.3)
	
	draw_arc(position, selection_radius, 0, TAU, 16, selection_color, 2.0)

func _draw_elevation_indicator(position: Vector2, elevation: float, icon_size: float) -> void:
	# Draw elevation indicator (triangle above/below icon)
	var indicator_size = icon_size * 0.3
	var offset_y = icon_size * 0.6
	
	if elevation > 0.1:
		# Above player - triangle pointing up
		var triangle_top = position + Vector2(0, -offset_y)
		var triangle_points = PackedVector2Array([
			triangle_top,
			triangle_top + Vector2(-indicator_size, indicator_size),
			triangle_top + Vector2(indicator_size, indicator_size)
		])
		draw_colored_polygon(triangle_points, Color.CYAN)
	elif elevation < -0.1:
		# Below player - triangle pointing down
		var triangle_bottom = position + Vector2(0, offset_y)
		var triangle_points = PackedVector2Array([
			triangle_bottom,
			triangle_bottom + Vector2(-indicator_size, -indicator_size),
			triangle_bottom + Vector2(indicator_size, -indicator_size)
		])
		draw_colored_polygon(triangle_points, Color.ORANGE)

func _draw_contact_label(contact: RadarDisplay3D.RadarContact, icon_size: Vector2) -> void:
	var label_text = contact.object_name
	if label_text.is_empty():
		label_text = _get_object_type_name(contact.object_type)
	
	# Calculate label position (below icon)
	var label_pos = contact.radar_position + Vector2(0, icon_size.y * 0.5 + 5)
	
	# Get text size for centering
	var text_size = label_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, label_font_size)
	label_pos.x -= text_size.x * 0.5
	
	# Draw text with outline for better visibility
	var text_color = iff_colors.get(contact.iff_status, Color.WHITE)
	
	# Draw outline
	for x_offset in [-1, 0, 1]:
		for y_offset in [-1, 0, 1]:
			if x_offset == 0 and y_offset == 0:
				continue
			draw_string(label_font, label_pos + Vector2(x_offset, y_offset), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, Color.BLACK)
	
	# Draw main text
	draw_string(label_font, label_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, text_color)

func _draw_elevation_markers() -> void:
	# Draw elevation reference indicators around radar edge
	var radar_bounds = spatial_manager.get_radar_bounds()
	var center = spatial_manager.get_radar_center()
	var radius = spatial_manager.get_radar_radius()
	
	# Draw elevation reference lines
	var elevation_color = Color.WHITE
	elevation_color.a = 0.3
	
	# Horizontal reference line (zero elevation)
	draw_line(Vector2(center.x - radius, center.y), Vector2(center.x + radius, center.y), elevation_color, 1.0)

## Input handling

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_contact = get_contact_at_position(mouse_event.position)
			if clicked_contact:
				selected_contact = clicked_contact
				contact_selected.emit(clicked_contact)
	
	elif event is InputEventMouseMotion:
		var motion_event = event as InputEventMouseMotion
		var hover_contact = get_contact_at_position(motion_event.position)
		
		if hover_contact != hovered_contact:
			hovered_contact = hover_contact
			if hover_contact:
				contact_hovered.emit(hover_contact)

func _on_mouse_entered() -> void:
	# Handle mouse entering radar display area
	pass

func _on_mouse_exited() -> void:
	# Clear hover state when mouse leaves
	hovered_contact = null

## Get contact at screen position
func get_contact_at_position(screen_pos: Vector2) -> RadarDisplay3D.RadarContact:
	var click_threshold = 15.0  # Pixels
	
	for contact in radar_contacts:
		var distance = screen_pos.distance_to(contact.radar_position)
		if distance <= click_threshold:
			return contact
	
	return null

## Get object type name for display
func _get_object_type_name(object_type: RadarDisplay3D.RadarContact.ObjectType) -> String:
	match object_type:
		RadarDisplay3D.RadarContact.ObjectType.FIGHTER:
			return "Fighter"
		RadarDisplay3D.RadarContact.ObjectType.BOMBER:
			return "Bomber"
		RadarDisplay3D.RadarContact.ObjectType.CRUISER:
			return "Cruiser"
		RadarDisplay3D.RadarContact.ObjectType.CAPITAL:
			return "Capital"
		RadarDisplay3D.RadarContact.ObjectType.STATION:
			return "Station"
		RadarDisplay3D.RadarContact.ObjectType.MISSILE:
			return "Missile"
		RadarDisplay3D.RadarContact.ObjectType.DEBRIS:
			return "Debris"
		RadarDisplay3D.RadarContact.ObjectType.WAYPOINT:
			return "Waypoint"
		_:
			return "Unknown"

## Configuration methods

## Set display options
func set_display_options(labels: bool, range_rings: bool, elevation: bool) -> void:
	show_labels = labels
	show_range_indicators = range_rings
	show_elevation_markers = elevation
	queue_redraw()

## Set icon base size
func set_icon_base_size(size: float) -> void:
	icon_base_size = clamp(size, 4.0, 32.0)
	queue_redraw()

## Set maximum rendered contacts
func set_max_rendered_contacts(max_contacts: int) -> void:
	max_rendered_contacts = clamp(max_contacts, 10, 500)

## Add contact to flash list
func flash_contact(contact: RadarDisplay3D.RadarContact, duration: float = 2.0) -> void:
	if contact not in flash_contacts:
		flash_contacts.append(contact)
		
		# Remove from flash list after duration
		var timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		timer.timeout.connect(func(): _remove_flash_contact(contact, timer))
		add_child(timer)
		timer.start()

func _remove_flash_contact(contact: RadarDisplay3D.RadarContact, timer: Timer) -> void:
	flash_contacts.erase(contact)
	timer.queue_free()

## Get rendering statistics
func get_render_stats() -> Dictionary:
	return {
		"contacts_total": radar_contacts.size(),
		"contacts_rendered": min(radar_contacts.size(), max_rendered_contacts),
		"max_contacts": max_rendered_contacts,
		"show_labels": show_labels,
		"show_range_rings": show_range_indicators,
		"show_elevation": show_elevation_markers,
		"icon_base_size": icon_base_size,
		"flash_contacts": flash_contacts.size()
	}
