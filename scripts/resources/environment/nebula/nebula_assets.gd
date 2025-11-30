class_name NebulaAssets
extends Resource

## Resource for storing global nebula assets defined in nebula.tbl.
## Contains lists of available background bitmaps and poof bitmaps.

@export var backgrounds: Dictionary[String, Texture2D] = {}  # name: String -> texture: Texture2D
@export var poofs: Dictionary[String, Texture2D] = {}  # name: String -> texture: Texture2D


func get_background_texture(name: String) -> Texture2D:
	return backgrounds.get(name)


func get_poof_texture(name: String) -> Texture2D:
	return poofs.get(name)


func validate() -> bool:
	return not backgrounds.is_empty() and not poofs.is_empty()
