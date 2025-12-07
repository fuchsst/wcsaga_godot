class_name TimelineEventResource
extends Resource

@export var year: int
@export var order_index: int
@export var era: String
@export var title: String
@export var icon: Texture2D
@export_multiline var short_description: String
@export_multiline var long_description: String
@export var trailer: VideoStream
@export var preview_image: Texture2D
@export var campaign_root_scene: PackedScene
@export var locked: bool = false
@export var ship_model_scene: PackedScene
