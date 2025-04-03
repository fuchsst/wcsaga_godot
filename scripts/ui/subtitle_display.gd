# scripts/ui/subtitle_display.gd
extends CanvasLayer
class_name SubtitleDisplay

## Displays a single subtitle with text and/or image, handling positioning and fading.
## Instanced and managed by SubtitleManager.

# --- Node References ---
@onready var text_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TextLabel")
@onready var image_rect: TextureRect = get_node_or_null("MarginContainer/VBoxContainer/ImageRect")
@onready var margin_container: MarginContainer = get_node_or_null("MarginContainer")
@onready var vbox_container: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer")

# --- State ---
var current_subtitle: SubtitleData = null
var current_image_texture: Texture2D = null

func _ready():
	if not text_label: printerr("SubtitleDisplay: TextLabel node not found!")
	if not image_rect: printerr("SubtitleDisplay: ImageRect node not found!")
	if not margin_container: printerr("SubtitleDisplay: MarginContainer node not found!")
	if not vbox_container: printerr("SubtitleDisplay: VBoxContainer node not found!")

	# Initial setup
	if text_label: text_label.text = ""
	if image_rect: image_rect.texture = null; image_rect.visible = false
	modulate = Color(1,1,1,0) # Start fully transparent
	visible = false


func set_subtitle_data(subtitle: SubtitleData):
	current_subtitle = subtitle
	if not is_instance_valid(current_subtitle):
		clear_display()
		return

	# --- Set Text ---
	if text_label:
		text_label.text = current_subtitle.text
		text_label.modulate = current_subtitle.text_color # Apply base color
		text_label.visible = not current_subtitle.text.is_empty()
		# TODO: Apply text wrapping based on subtitle.width if > 0
		# text_label.autowrap_mode = TextServer.AUTOWRAP_WORD if current_subtitle.width > 0 else TextServer.AUTOWRAP_OFF
		# text_label.custom_minimum_size.x = current_subtitle.width if current_subtitle.width > 0 else 0

	# --- Set Image ---
	if image_rect:
		if not current_subtitle.image_path.is_empty():
			# TODO: Handle potential animation loading (.ani -> SpriteFrames?)
			current_image_texture = load(current_subtitle.image_path) if ResourceLoader.exists(current_subtitle.image_path) else null
			if current_image_texture:
				image_rect.texture = current_image_texture
				image_rect.visible = true
				# Apply fixed size if specified
				if current_subtitle.width > 0: image_rect.custom_minimum_size.x = current_subtitle.width
				if current_subtitle.height > 0: image_rect.custom_minimum_size.y = current_subtitle.height
				image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # Or fit based on needs
				image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT # Or scale
			else:
				printerr("SubtitleDisplay: Failed to load image '", current_subtitle.image_path, "'")
				image_rect.texture = null
				image_rect.visible = false
		else:
			image_rect.texture = null
			image_rect.visible = false

	# --- Set Positioning ---
	_apply_positioning()


func update_display(subtitle: SubtitleData, alpha: float):
	# Ensure we're displaying the correct subtitle (might have changed)
	if subtitle != current_subtitle:
		set_subtitle_data(subtitle)

	# Apply alpha modulation for fading
	modulate.a = alpha


func clear_display():
	current_subtitle = null
	current_image_texture = null
	if text_label: text_label.text = ""
	if image_rect: image_rect.texture = null; image_rect.visible = false
	visible = false
	modulate.a = 0.0


func _apply_positioning():
	if not is_instance_valid(current_subtitle) or not margin_container or not vbox_container:
		return

	var screen_size = get_viewport_rect().size
	var content_size = vbox_container.get_combined_minimum_size()

	var final_x = float(current_subtitle.position_x)
	var final_y = float(current_subtitle.position_y)

	# Handle centering
	if current_subtitle.center_x:
		final_x = (screen_size.x - content_size.x) / 2.0 + final_x # Add offset to centered pos
	elif final_x < 0: # Negative X means right-aligned offset
		final_x = screen_size.x + final_x - content_size.x

	if current_subtitle.center_y:
		final_y = (screen_size.y - content_size.y) / 2.0 + final_y # Add offset to centered pos
	elif final_y < 0: # Negative Y means bottom-aligned offset
		final_y = screen_size.y + final_y - content_size.y

	# Apply margins - This assumes MarginContainer covers the whole screen initially
	# We adjust margins to effectively position the VBoxContainer within it.
	# This is a bit indirect but works with container sizing.
	margin_container.set("theme_override_constants/margin_left", int(final_x))
	margin_container.set("theme_override_constants/margin_top", int(final_y))
	# Set right/bottom margins based on screen size minus position and content size
	margin_container.set("theme_override_constants/margin_right", int(screen_size.x - final_x - content_size.x))
	margin_container.set("theme_override_constants/margin_bottom", int(screen_size.y - final_y - content_size.y))

	# Set alignment within the VBoxContainer (usually start/top)
	vbox_container.alignment = BoxContainer.ALIGNMENT_BEGIN

	# TODO: Handle post_shaded flag - might involve changing the CanvasLayer's layer property
	# layer = 1 if current_subtitle.post_shaded else 0 # Example
