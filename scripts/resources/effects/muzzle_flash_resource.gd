extends Resource

class_name MuzzleFlashResource

## Defines a muzzle flash effect composed of multiple blobs.

@export var name: String = ""
@export var blobs: Array[MuzzleFlashBlob] = []

class MuzzleFlashBlob extends Resource:
	@export var name: String = "" # Texture/Anim name
	@export var offset: float = 0.0
	@export var radius: float = 1.0
