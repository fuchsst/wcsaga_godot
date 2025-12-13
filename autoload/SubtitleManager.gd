# SubtitleManager - Subtitle Display System
# Displays text and images during cutscenes with fade in/out
# Uses Godot's native CanvasLayer and RichTextLabel for rendering

extends CanvasLayer


## Signals
signal subtitle_shown(text: String)
signal subtitle_hidden()
signal all_subtitles_cleared()

# ==============================================================================
# SUBTITLE DATA
# ==============================================================================

## Subtitle display entry
class SubtitleEntry:
	var text_lines: PackedStringArray = []
	var text_position: Vector2 = Vector2.ZERO
	var image_path: String = ""
	var image_position: Rect2 = Rect2()
	var display_time: float = 0.0
	var fade_time: float = 0.0
	var text_color: Color = Color.WHITE
	var time_displayed: float = 0.0
	var time_displayed_end: float = 0.0
	var post_shaded: bool = false
	var label: RichTextLabel = null
	var texture_rect: TextureRect = null


# ==============================================================================
# STATE
# ==============================================================================

## Active subtitles
var _subtitles: Array[SubtitleEntry] = []

## Container for subtitle UI elements
var _container: Control = null


# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	layer = 100 # Above most UI
	_create_container()


func _create_container() -> void:
	_container = Control.new()
	_container.name = "SubtitleContainer"
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)


func _process(delta: float) -> void:
	_update_subtitles(delta)


# ==============================================================================
# PUBLIC API
# ==============================================================================


## Show a subtitle with text
func show_subtitle(
	text: String,
	x_pos: int = -1,
	y_pos: int = -1,
	display_time: float = 3.0,
	fade_time: float = 0.5,
	color: Color = Color.WHITE,
	center_x: bool = true,
	center_y: bool = false,
	width: int = 0,
	post_shaded: bool = false
) -> void:
	var entry := SubtitleEntry.new()

	# Split text into lines
	if width > 0:
		entry.text_lines = _wrap_text(text, width)
	else:
		entry.text_lines = text.split("\n")

	# Calculate position
	var viewport_size := get_viewport().get_visible_rect().size
	var text_width := _estimate_text_width(entry.text_lines)
	var text_height := entry.text_lines.size() * 20 # Approximate line height

	if center_x:
		entry.text_position.x = (viewport_size.x - text_width) / 2
	elif x_pos < 0:
		entry.text_position.x = viewport_size.x + x_pos
	else:
		entry.text_position.x = x_pos

	if center_y:
		entry.text_position.y = (viewport_size.y - text_height) / 2
	elif y_pos < 0:
		entry.text_position.y = viewport_size.y + y_pos
	else:
		entry.text_position.y = y_pos

	entry.display_time = display_time
	entry.fade_time = fade_time
	entry.text_color = color
	entry.time_displayed = 0.0
	entry.time_displayed_end = 2.0 * fade_time + display_time
	entry.post_shaded = post_shaded

	# Create label
	entry.label = _create_label(entry)
	_container.add_child(entry.label)

	_subtitles.append(entry)
	subtitle_shown.emit(text)


## Configuration for subtitle with image
class SubtitleImageConfig:
	var x_pos: int = -1
	var y_pos: int = -1
	var display_time: float = 3.0
	var fade_time: float = 0.5
	var color: Color = Color.WHITE
	var image_width: int = 0
	var image_height: int = 0
	var center_x: bool = true
	var center_y: bool = false
	var post_shaded: bool = false


## Show a subtitle with image
func show_subtitle_with_image(
	text: String,
	image_path: String,
	config: SubtitleImageConfig = null
) -> void:
	if config == null:
		config = SubtitleImageConfig.new()

	var entry := SubtitleEntry.new()

	entry.text_lines = text.split("\n")
	entry.image_path = image_path

	# Calculate position
	var viewport_size := get_viewport().get_visible_rect().size

	if config.center_x:
		entry.text_position.x = viewport_size.x / 2
	elif config.x_pos < 0:
		entry.text_position.x = viewport_size.x + config.x_pos
	else:
		entry.text_position.x = config.x_pos

	if config.center_y:
		entry.text_position.y = viewport_size.y / 2
	elif config.y_pos < 0:
		entry.text_position.y = viewport_size.y + config.y_pos
	else:
		entry.text_position.y = config.y_pos

	entry.image_position = Rect2(
		entry.text_position.x,
		entry.text_position.y,
		config.image_width,
		config.image_height
	)

	entry.display_time = config.display_time
	entry.fade_time = config.fade_time
	entry.text_color = config.color
	entry.time_displayed = 0.0
	entry.time_displayed_end = 2.0 * config.fade_time + config.display_time
	entry.post_shaded = config.post_shaded

	# Create image if valid
	if ResourceLoader.exists(image_path):
		entry.texture_rect = _create_image(entry)
		_container.add_child(entry.texture_rect)

	# Create label
	if text.length() > 0:
		entry.label = _create_label(entry)
		_container.add_child(entry.label)

	_subtitles.append(entry)
	subtitle_shown.emit(text)


## Clear all subtitles immediately
func clear_all_subtitles() -> void:
	for entry in _subtitles:
		if entry.label:
			entry.label.queue_free()
		if entry.texture_rect:
			entry.texture_rect.queue_free()

	_subtitles.clear()
	all_subtitles_cleared.emit()


# ==============================================================================
# UPDATE
# ==============================================================================


func _update_subtitles(delta: float) -> void:
	var to_remove: Array[int] = []

	for i in range(_subtitles.size()):
		var entry := _subtitles[i]
		entry.time_displayed += delta

		# Calculate alpha based on fade
		var alpha := _calculate_alpha(entry)

		# Update label alpha
		if entry.label:
			entry.label.modulate.a = alpha

		# Update image alpha
		if entry.texture_rect:
			entry.texture_rect.modulate.a = alpha

		# Check if finished
		if entry.time_displayed > entry.time_displayed_end:
			to_remove.append(i)

	# Remove finished subtitles (in reverse order)
	for i in range(to_remove.size() - 1, -1, -1):
		var idx := to_remove[i]
		var entry := _subtitles[idx]

		if entry.label:
			entry.label.queue_free()
		if entry.texture_rect:
			entry.texture_rect.queue_free()

		_subtitles.remove_at(idx)
		subtitle_hidden.emit()


func _calculate_alpha(entry: SubtitleEntry) -> float:
	# Fade in phase
	if entry.time_displayed < entry.fade_time:
		return entry.time_displayed / entry.fade_time

	# Finished phase
	if entry.time_displayed > entry.time_displayed_end:
		return 0.0

	# Fade out phase
	if (entry.time_displayed - entry.fade_time) > entry.display_time:
		var fade_progress := entry.time_displayed - entry.fade_time - entry.display_time
		return 1.0 - (fade_progress / entry.fade_time)

	# Full display phase
	return 1.0


# ==============================================================================
# UI CREATION
# ==============================================================================


func _create_label(entry: SubtitleEntry) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Set text
	var combined_text := "\n".join(entry.text_lines)
	label.text = "[center]%s[/center]" % combined_text

	# Set position
	label.position = entry.text_position
	label.custom_minimum_size = Vector2(400, 0)

	# Set color
	label.add_theme_color_override("default_color", entry.text_color)

	return label


func _create_image(entry: SubtitleEntry) -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.texture = load(entry.image_path)
	tex_rect.position = entry.image_position.position

	if entry.image_position.size.x > 0:
		tex_rect.custom_minimum_size.x = entry.image_position.size.x
	if entry.image_position.size.y > 0:
		tex_rect.custom_minimum_size.y = entry.image_position.size.y

	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return tex_rect


# ==============================================================================
# TEXT UTILITIES
# ==============================================================================


func _wrap_text(text: String, max_width: int) -> PackedStringArray:
	# Simple word-wrap implementation
	var lines: PackedStringArray = []
	var words := text.split(" ")
	var current_line := ""

	for word in words:
		if current_line.length() == 0:
			current_line = word
		elif (current_line.length() + 1 + word.length()) * 8 <= max_width:
			current_line += " " + word
		else:
			lines.append(current_line)
			current_line = word

	if current_line.length() > 0:
		lines.append(current_line)

	return lines


func _estimate_text_width(lines: PackedStringArray) -> float:
	var max_len := 0
	for line in lines:
		if line.length() > max_len:
			max_len = line.length()
	return max_len * 10.0 # Approximate character width
