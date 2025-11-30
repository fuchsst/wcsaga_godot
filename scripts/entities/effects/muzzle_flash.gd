extends Node3D

class_name MuzzleFlash

@export var resource: MuzzleFlashResource
@export var auto_start: bool = true

var _is_active: bool = false
var _sprites: Array[AnimatedSprite3D] = []


func _ready():
	if auto_start and resource:
		play()


func play():
	if not resource:
		return

	_is_active = true

	# Clear existing
	for s in _sprites:
		s.queue_free()
	_sprites.clear()

	# Spawn blobs
	for blob in resource.blobs:
		_spawn_blob(blob)


func _spawn_blob(blob: MuzzleFlashResource.MuzzleFlashBlob):
	var sprite = AnimatedSprite3D.new()
	add_child(sprite)

	# Load frames
	# Assuming frames are at res://assets/effects/muzzleflash/<blob_name>.tres
	# Or if it's a sequence, it might be <blob_name>.tres directly if converted as sequence
	# Lowercase to handle case-insensitivity
	var frames_path = "res://assets/effects/muzzleflash/" + blob.name.to_lower() + ".tres"
	if ResourceLoader.exists(frames_path):
		var frames = load(frames_path)
		if frames is SpriteFrames:
			sprite.sprite_frames = frames
			sprite.play("default")  # Assuming default animation

			# Connect animation finished to cleanup check
			sprite.animation_finished.connect(_on_animation_finished)
	else:
		push_warning("MuzzleFlash: Could not find frames for blob: " + blob.name)

	# Setup transform
	sprite.position = Vector3(0, 0, -blob.offset)  # Negative Z is forward usually
	sprite.pixel_size = 0.1  # Standard scale

	# Scale based on radius?
	# If radius is in meters, and sprite is roughly 1m x 1m at pixel_size 0.01 (100px),
	# we might need to adjust.
	# For now, let's assume pixel_size 0.1 is a good baseline and radius scales it.
	# If radius is 0, it might mean default size.
	if blob.radius > 0:
		# This is a guess. Need to verify visual scale.
		# If radius is the visual radius of the flash.
		var scale_factor = blob.radius
		sprite.scale = Vector3(scale_factor, scale_factor, scale_factor)

	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprites.append(sprite)


func _on_animation_finished():
	# Check if all finished
	var all_finished = true
	for s in _sprites:
		if s.is_playing():
			all_finished = false
			break

	if all_finished:
		queue_free()
