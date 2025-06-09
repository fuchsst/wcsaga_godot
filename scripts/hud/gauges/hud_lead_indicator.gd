@tool
extends HUDGauge
class_name HUDLeadIndicator

# Lead Indicator State
@export var lead_active: bool = false:
	set(value):
		lead_active = value
		queue_redraw()
@export var screen_position: Vector2 = Vector2.ZERO:
	set(value):
		screen_position = value
		queue_redraw()
@export var in_range: bool = false: # Is the lead position within weapon range?
	set(value):
		in_range = value
		queue_redraw()

# Visual Settings
@export_group("Visual Settings")
@export var indicator_size: float = 10.0 # Half-width/height of the diamond
@export var color_in_range: Color = Color.GREEN
@export var color_out_of_range: Color = Color.RED

# Editor properties
@export_group("Editor Preview")
@export var preview_size := Vector2(50, 50) # Small preview area

func _init() -> void:
	super._init()
	gauge_id = GaugeType.LEAD_INDICATOR
	# Lead indicator might not need standard flashing/popup logic from base class
	is_popup = false # Ensure it's not treated as a popup

func _ready() -> void:
	super._ready()
	# Initial state
	lead_active = false

# Update gauge based on current game state
func update_from_game_state() -> void:
	# Check if player ship and targeting component exist
	if GameStateManager.player_ship and is_instance_valid(GameStateManager.player_ship) and GameStateManager.player_ship.targeting_component:
		var targeting_comp = GameStateManager.player_ship.targeting_component # Assuming TargetingComponent exists

		# Get lead indicator data
		var lead_data = targeting_comp.get_lead_indicator_data() # Placeholder method
		# Assuming lead_data is a Dictionary: { active: bool, screen_pos: Vector2, in_range: bool }

		if lead_data and lead_data.get("active", false):
			lead_active = true
			screen_position = lead_data.get("screen_pos", Vector2.ZERO)
			in_range = lead_data.get("in_range", false)
		else:
			lead_active = false
	else:
		# No player or targeting component
		lead_active = false


# Draw the lead indicator diamond
func _draw() -> void:
	if Engine.is_editor_hint():
		# Draw editor preview background
		draw_rect(Rect2(Vector2.ZERO, preview_size), Color(0.1, 0.1, 0.1, 0.5))
		# Draw a sample indicator in the center of the preview
		var center = preview_size / 2.0
		_draw_diamond(center, Color.YELLOW) # Use a distinct color for preview
		super._draw() # Draw base gauge info if needed
		return

	if not can_draw() or not lead_active:
		return

	# Determine color based on range
	var draw_color = color_out_of_range
	if in_range:
		draw_color = color_in_range

	# Apply base gauge alpha/flashing if needed (though likely not for lead)
	# draw_color = get_current_color() # If using base class flashing/alpha
	# if not in_range: draw_color = color_out_of_range # Override if out of range

	# Draw the diamond shape at the screen_position
	_draw_diamond(screen_position, draw_color)


# Helper function to draw the diamond shape
func _draw_diamond(pos: Vector2, color: Color) -> void:
	var size = indicator_size
	var points = PackedVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(size, 0),
		pos + Vector2(0, size),
		pos + Vector2(-size, 0)
	])
	# Draw filled or outline? Original likely outline.
	draw_polyline(points, color, 1.0, true) # Draw connected lines


func _process(delta: float):
	# Base class process handles flashing, but lead indicator likely doesn't flash.
	# If flashing is desired based on some condition, override or add logic here.
	# super._process(delta)
	pass # No specific processing needed here unless adding flashing
