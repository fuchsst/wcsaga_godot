# scripts/resources/texture_replacement_data.gd
# Defines a texture replacement for a specific ship instance in a mission.
class_name TextureReplacementData
extends Resource

@export var old_texture_name: String = "" # Original texture filename (without extension)
@export var new_texture_path: String = "" # Path to the new texture resource (e.g., "res://assets/textures/...")
