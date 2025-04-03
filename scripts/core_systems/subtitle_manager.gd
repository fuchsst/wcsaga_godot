# scripts/core_systems/subtitle_manager.gd
extends Node
class_name SubtitleManager

## Manages the subtitle queue and controls their display and fading.
## Corresponds to subtitle management logic in camera.cpp/.h.
## This should be configured as an Autoload Singleton named "SubtitleManager".

# --- Node References ---
# Assuming the SubtitleDisplay scene is instanced under this manager
# or added to the scene tree elsewhere and referenced here.
var subtitle_display_node: Control = null # Reference to the UI node that shows subtitles

# --- State ---
var subtitle_queue: Array[SubtitleData] = []
var current_subtitle: SubtitleData = null
var current_subtitle_start_time: float = 0.0

# --- Parameters ---
@export var subtitle_display_scene: PackedScene = preload("res://scenes/ui/subtitle_display.tscn") # Default path

func _ready():
	# Ensure a display node exists
	if subtitle_display_node == null:
		if subtitle_display_scene:
			subtitle_display_node = subtitle_display_scene.instantiate()
			# Add it to the scene tree, perhaps as a child of a main UI canvas
			# get_tree().root.add_child(subtitle_display_node) # Example, adjust as needed
			# For simplicity, let's assume it's added elsewhere and we get a reference
			# subtitle_display_node = get_tree().get_first_node_in_group("subtitle_display") # Example
			if subtitle_display_node == null:
				printerr("SubtitleManager: Could not find or instance SubtitleDisplay node!")
		else:
			printerr("SubtitleManager: subtitle_display_scene not set!")

	if subtitle_display_node:
		subtitle_display_node.visible = false # Start hidden


func _process(delta: float):
	if current_subtitle == null:
		# Check queue if nothing is currently displayed
		if not subtitle_queue.is_empty():
			_show_next_subtitle()
		return

	# Update current subtitle timing and alpha
	var elapsed_time = Time.get_ticks_msec() / 1000.0 - current_subtitle_start_time
	var total_duration = current_subtitle.calculate_duration()
	var fade_time = current_subtitle.fade_time
	var display_time = current_subtitle.display_time
	var alpha: float = 1.0

	if elapsed_time < fade_time:
		# Fading in
		alpha = clamp(elapsed_time / fade_time, 0.0, 1.0) if fade_time > 0 else 1.0
	elif elapsed_time > (fade_time + display_time):
		# Fading out
		var fade_out_elapsed = elapsed_time - (fade_time + display_time)
		alpha = clamp(1.0 - (fade_out_elapsed / fade_time), 0.0, 1.0) if fade_time > 0 else 0.0
	else:
		# Fully visible
		alpha = 1.0

	# Update the display node
	if subtitle_display_node and subtitle_display_node.has_method("update_display"):
		subtitle_display_node.update_display(current_subtitle, alpha)

	# Check if subtitle duration is over
	if elapsed_time >= total_duration:
		_clear_current_subtitle()
		# Immediately check queue for the next one
		if not subtitle_queue.is_empty():
			_show_next_subtitle()


func queue_subtitle(subtitle_res: SubtitleData):
	if not subtitle_res is SubtitleData:
		printerr("SubtitleManager: Attempted to queue invalid SubtitleData.")
		return
	subtitle_queue.append(subtitle_res)


func queue_subtitle_params(text: String, image: String = "", display_t: float = 3.0, fade_t: float = 0.5, color: Color = Color.WHITE, x: int = 0, y: int = 0, center_x: bool = true, center_y: bool = false, w: int = 0, h: int = 0, post: bool = false):
	var sub_data = SubtitleData.new()
	sub_data.text = text
	sub_data.image_path = image
	sub_data.display_time = display_t
	sub_data.fade_time = fade_t
	sub_data.text_color = color
	sub_data.position_x = x
	sub_data.position_y = y
	sub_data.center_x = center_x
	sub_data.center_y = center_y
	sub_data.width = w
	sub_data.height = h
	sub_data.post_shaded = post
	queue_subtitle(sub_data)


func clear_queue():
	subtitle_queue.clear()


func clear_all():
	clear_queue()
	_clear_current_subtitle()


# --- Internal Helpers ---

func _show_next_subtitle():
	if subtitle_queue.is_empty():
		return

	current_subtitle = subtitle_queue.pop_front()
	current_subtitle_start_time = Time.get_ticks_msec() / 1000.0

	if subtitle_display_node:
		if subtitle_display_node.has_method("set_subtitle_data"):
			subtitle_display_node.set_subtitle_data(current_subtitle)
		subtitle_display_node.visible = true
		# Initial update with alpha 0 for fade-in start
		if subtitle_display_node.has_method("update_display"):
			subtitle_display_node.update_display(current_subtitle, 0.0)


func _clear_current_subtitle():
	current_subtitle = null
	if subtitle_display_node:
		subtitle_display_node.visible = false
		if subtitle_display_node.has_method("clear_display"):
			subtitle_display_node.clear_display()
