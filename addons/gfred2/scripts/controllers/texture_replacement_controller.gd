@tool
class_name TextureReplacementController
extends Control

## Texture replacement controller for GFRED2-009 Advanced Ship Configuration.
## Scene-based UI controller for managing ship texture replacements.
## Scene: addons/gfred2/scenes/dialogs/ship_editor/texture_replacement_panel.tscn

signal texture_config_updated(replacement_type: String, original_texture: String, new_texture: String)
signal texture_removed(replacement_type: String, original_texture: String)

# Current texture configuration
var current_texture_config: TextureReplacementConfig = null

# Scene node references
@onready var texture_tree: Tree = $VBoxContainer/TextureTree
@onready var add_texture_button: Button = $VBoxContainer/AddTextureButton
@onready var remove_texture_button: Button = $VBoxContainer/RemoveTextureButton
@onready var browse_texture_button: Button = $VBoxContainer/BrowseTextureButton

# File dialog for texture selection
@onready var file_dialog: FileDialog = $TextureFileDialog

func _ready() -> void:
	name = "TextureReplacementController"
	_setup_ui()

func _setup_ui() -> void:
	if texture_tree:
		texture_tree.columns = 3
		texture_tree.set_column_title(0, "Type")
		texture_tree.set_column_title(1, "Original")
		texture_tree.set_column_title(2, "Replacement")
	
	if add_texture_button:
		add_texture_button.pressed.connect(_on_add_texture_pressed)
	if remove_texture_button:
		remove_texture_button.pressed.connect(_on_remove_texture_pressed)
	if browse_texture_button:
		browse_texture_button.pressed.connect(_on_browse_texture_pressed)
	
	if file_dialog:
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.access = FileDialog.ACCESS_RESOURCES
		file_dialog.add_filter("*.png", "PNG Images")
		file_dialog.add_filter("*.jpg", "JPEG Images")
		file_dialog.add_filter("*.dds", "DDS Textures")

func update_with_texture_config(config: TextureReplacementConfig) -> void:
	if not config:
		return
	
	current_texture_config = config
	_populate_texture_tree()

func _populate_texture_tree() -> void:
	if not texture_tree or not current_texture_config:
		return
	
	texture_tree.clear()
	var root: TreeItem = texture_tree.create_item()
	
	# Add texture replacements
	for original_texture in current_texture_config.texture_replacements:
		var replacement: String = current_texture_config.texture_replacements[original_texture]
		var item: TreeItem = texture_tree.create_item(root)
		item.set_text(0, "Main")
		item.set_text(1, original_texture)
		item.set_text(2, replacement)

func _on_add_texture_pressed() -> void:
	# TODO: Show dialog to add new texture replacement
	print("TextureReplacementController: Add texture functionality not yet implemented")

func _on_remove_texture_pressed() -> void:
	var selected: TreeItem = texture_tree.get_selected()
	if not selected or not current_texture_config:
		return
	
	var original_texture: String = selected.get_text(1)
	current_texture_config.texture_replacements.erase(original_texture)
	_populate_texture_tree()
	texture_removed.emit("main", original_texture)

func _on_browse_texture_pressed() -> void:
	if file_dialog:
		file_dialog.popup_centered(Vector2i(800, 600))

func get_current_texture_config() -> TextureReplacementConfig:
	return current_texture_config