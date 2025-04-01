# scripts/mission_system/briefing/briefing_icon.gd
# Script attached to the BriefingIcon scene (briefing_icon.tscn).
# Represents a single icon on the briefing map.
class_name BriefingIcon
extends Node3D # Assuming the icon scene root is Node3D

# --- Dependencies ---
const BriefingIconData = preload("res://scripts/resources/mission/briefing_icon_data.gd")
# Access SpeciesManager via singleton: Engine.get_singleton("SpeciesManager")

# --- Nodes ---
# Assign these in the editor for the BriefingIcon scene
@onready var icon_sprite: Sprite3D = %IconSprite # Example path
@onready var label_node: Label3D = %IconLabel # Example path
@onready var highlight_anim_player: AnimationPlayer = %HighlightAnimPlayer # Example path for highlight effect
@export var fade_anim_player: AnimationPlayer = null # Optional fade animation player

# --- State ---
var icon_data: BriefingIconData = null
var is_highlighted: bool = false
var is_fading_in: bool = false
var is_fading_out: bool = false # Not directly used by original logic, but useful

func _ready() -> void:
	# Initialization, potentially hide until setup
	visible = false
	if is_instance_valid(label_node): label_node.visible = false
	if is_instance_valid(icon_sprite): icon_sprite.visible = false


# Called by BriefingMapManager to set up the icon
func setup(data: BriefingIconData) -> void:
	icon_data = data
	if icon_data == null:
		printerr("BriefingIcon: Setup called with null data.")
		visible = false
		return

	# Set position
	global_position = icon_data.position

	# Set icon texture based on type and ship class/species
	_update_icon_texture()

	# Set label text
	if is_instance_valid(label_node):
		# TODO: Handle localization if needed (using tr())
		label_node.text = icon_data.label
		label_node.visible = not icon_data.label.is_empty()

	# Handle initial flags (e.g., fade-in)
	if icon_data.flags & GlobalConstants.BI_FADEIN: # Assuming BI_FADEIN is defined
		start_fade_in()
	else:
		# Make visible immediately if not fading in
		visible = true
		if is_instance_valid(icon_sprite): icon_sprite.visible = true
		# Label visibility already handled

	# Set highlight state
	is_highlighted = (icon_data.flags & GlobalConstants.BI_SHOWHIGHLIGHT) != 0 # Assuming BI_SHOWHIGHLIGHT defined
	if is_highlighted and is_instance_valid(highlight_anim_player):
		highlight_anim_player.play("HighlightLoop") # Assuming animation name
	elif is_instance_valid(highlight_anim_player):
		highlight_anim_player.stop()
		highlight_anim_player.seek(0, true) # Reset animation


# Called by BriefingMapManager when icon data potentially changes for the same ID
func update_data(data: BriefingIconData) -> void:
	# Only update if data actually changed to avoid unnecessary work
	if icon_data == data:
		return

	var old_flags = icon_data.flags if icon_data else 0
	icon_data = data

	# Update position (might need tweening handled by MapManager)
	global_position = icon_data.position

	# Update texture if type/class changed
	_update_icon_texture()

	# Update label
	if is_instance_valid(label_node):
		label_node.text = icon_data.label
		label_node.visible = not icon_data.label.is_empty()

	# Handle flag changes (highlight, fade)
	var highlight_changed = ((old_flags & GlobalConstants.BI_SHOWHIGHLIGHT) != (icon_data.flags & GlobalConstants.BI_SHOWHIGHLIGHT))
	is_highlighted = (icon_data.flags & GlobalConstants.BI_SHOWHIGHLIGHT) != 0

	if highlight_changed and is_instance_valid(highlight_anim_player):
		if is_highlighted:
			highlight_anim_player.play("HighlightLoop") # Assuming animation name
			# TODO: Play highlight sound (managed by BriefingScreen?)
		else:
			highlight_anim_player.stop()
			highlight_anim_player.seek(0, true) # Reset animation

	# Handle fade-in if newly added (though MapManager usually handles creation)
	if not (old_flags & GlobalConstants.BI_FADEIN) and (icon_data.flags & GlobalConstants.BI_FADEIN):
		start_fade_in()


func update_animations(delta: float):
	# Placeholder for any continuous animation updates if not using AnimationPlayer
	pass


func start_fade_in():
	if is_instance_valid(fade_anim_player):
		visible = true
		if is_instance_valid(icon_sprite): icon_sprite.visible = true
		# Label visibility depends on label text
		if is_instance_valid(label_node): label_node.visible = not icon_data.label.is_empty()
		fade_anim_player.play("FadeIn") # Assuming animation name
		is_fading_in = true
		await fade_anim_player.animation_finished
		is_fading_in = false
		# Ensure flags are cleared after fade
		if icon_data: icon_data.flags &= ~GlobalConstants.BI_FADEIN
	else:
		# No fade animation, just make visible
		visible = true
		if is_instance_valid(icon_sprite): icon_sprite.visible = true
		if is_instance_valid(label_node): label_node.visible = not icon_data.label.is_empty()
		if icon_data: icon_data.flags &= ~GlobalConstants.BI_FADEIN


func start_fade_out():
	if is_instance_valid(fade_anim_player):
		fade_anim_player.play_backwards("FadeIn") # Play fade in reverse
		is_fading_out = true
		await fade_anim_player.animation_finished
		is_fading_out = false
		queue_free() # Remove after fading
	else:
		queue_free() # Remove immediately if no fade


func _update_icon_texture():
	if not is_instance_valid(icon_sprite) or icon_data == null:
		return

	# Get species index from ship class
	var species_index = 0 # Default to Terran?
	if icon_data.ship_class_index != -1:
		var ship_data = GlobalConstants.get_ship_data(icon_data.ship_class_index)
		if ship_data:
			species_index = ship_data.species

	# Get the correct icon bitmap path from SpeciesManager/SpeciesInfo
	var icon_texture_path = ""
	if Engine.has_singleton("SpeciesManager"):
		var species_info = SpeciesManager.get_species_info_by_index(species_index)
		if species_info and species_info.has_method("get_briefing_icon_path"): # Assuming helper method
			icon_texture_path = species_info.get_briefing_icon_path(icon_data.type)

	if not icon_texture_path.is_empty():
		var texture = load(icon_texture_path) as Texture2D
		if texture:
			icon_sprite.texture = texture
			icon_sprite.visible = true
		else:
			printerr("BriefingIcon: Failed to load icon texture: ", icon_texture_path)
			icon_sprite.visible = false
	else:
		printerr("BriefingIcon: Could not determine texture path for type %d, species %d" % [icon_data.type, species_index])
		icon_sprite.visible = false

	# TODO: Handle mirroring (icon_sprite.flip_h = icon_data.flags & GlobalConstants.BI_MIRROR_ICON)
	# TODO: Handle selection state (use different texture frame?)
