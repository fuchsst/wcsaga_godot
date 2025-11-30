extends Node3D

class_name WeaponExplosion

@export var resource: WeaponExplosionResource
@export var auto_start: bool = true

var _sprite: AnimatedSprite3D
var _current_lod: int = 0


func _ready():
	_sprite = AnimatedSprite3D.new()
	add_child(_sprite)
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = 0.1  # Adjust as needed
	_sprite.animation_finished.connect(_on_animation_finished)

	if auto_start and resource:
		play()


func play():
	if not resource or resource.lod_paths.is_empty():
		return

	# Initial LOD selection (can be improved with distance check)
	_update_lod(0)
	_sprite.play("default")


func _process(_delta):
	# Simple LOD check based on distance to camera
	if not resource or resource.lod_count <= 1:
		return

	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var dist = global_position.distance_to(camera.global_position)

	# Thresholds (arbitrary for now, should be tuned)
	var new_lod = 0
	if dist > 500:
		new_lod = min(2, resource.lod_count - 1)
	elif dist > 200:
		new_lod = min(1, resource.lod_count - 1)

	if new_lod != _current_lod:
		_update_lod(new_lod)


func _update_lod(lod_index: int):
	if lod_index < 0 or lod_index >= resource.lod_paths.size():
		return

	var frames_path = resource.lod_paths[lod_index]
	if ResourceLoader.exists(frames_path):
		var frames = load(frames_path)
		if frames is SpriteFrames:
			var current_frame = _sprite.frame
			var is_playing = _sprite.is_playing()

			_sprite.sprite_frames = frames
			_current_lod = lod_index

			if is_playing:
				_sprite.play("default")
				_sprite.frame = current_frame  # Try to maintain frame continuity
	else:
		push_warning("WeaponExplosion: Missing frames for LOD " + str(lod_index))


func _on_animation_finished():
	queue_free()
