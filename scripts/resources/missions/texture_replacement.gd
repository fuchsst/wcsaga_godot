extends Resource
class_name TextureReplacement

## Texture replacement configuration for a ship

@export var ship_name: String = ""
@export var old_texture: String = ""
@export var new_texture: String = ""
@export var new_texture_id: int = -1
@export var new_texture_stream: Texture2D = null
