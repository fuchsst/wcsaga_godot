class_name Fireball
extends Node3D

## Fireball Entity
## Handles the lifecycle of a fireball effect, including explosions and warp effects.

signal finished
signal warp_opened
signal warp_closed

const FireballResource = preload("res://scripts/resources/effects/fireball_resource.gd")

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

var _resource: FireballResource
var _time_elapsed: float = 0.0
var _is_warping: bool = false
var _warp_state: int = 0 # 0: None, 1: Opening, 2: Open, 3: Closing

func setup(resource: FireballResource, params: Dictionary = {}) -> void:
	_resource = resource
	
	if sprite and resource:
		# Set billboard mode based on type
		if resource.render_type == FireballResource.FireballType.EXPLOSION_LARGE1 or \
		   resource.render_type == FireballResource.FireballType.EXPLOSION_LARGE2:
			# Large explosions rotate with viewer (Y-Billboard usually, or specific shader)
			# For now, standard billboard is often sufficient, or Y-Billboard
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		else:
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			
		# Scale
		if params.has("scale"):
			scale = Vector3.ONE * params["scale"]
		elif resource.radius > 0:
			# Assuming sprite pixel size is calibrated, we might need to adjust scale
			# For now, keep default or use radius as a hint
			pass

	if resource.is_warp:
		_start_warp_in()
	else:
		_start_explosion()

func _ready():
	# If setup wasn't called (e.g. testing scene directly), try to play default
	if not _resource and sprite:
		sprite.animation_finished.connect(_on_animation_finished)
		sprite.play("default")

func _process(delta: float) -> void:
	if _is_warping:
		_process_warp(delta)

func _start_explosion() -> void:
	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)
		sprite.play("default")
		# Play sound if available (TODO: Add sound manager integration)

func _start_warp_in() -> void:
	_is_warping = true
	_warp_state = 1 # Opening
	_time_elapsed = 0.0
	
	# Start small
	scale = Vector3.ZERO
	
	if sprite:
		sprite.play("default")
	
	# Play warp open sound (TODO)
	
	# Tween scale up
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, _resource.warp_lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_warp_opened)

func _on_warp_opened() -> void:
	_warp_state = 2 # Open
	warp_opened.emit()

func start_warp_out() -> void:
	if not _resource or not _resource.is_warp:
		return
		
	_warp_state = 3 # Closing
	_time_elapsed = 0.0
	
	# Play warp close sound (TODO)
	
	# Tween scale down
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, _resource.warp_lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_warp_closed)

func _on_warp_closed() -> void:
	warp_closed.emit()
	finished.emit()
	queue_free()

func _process_warp(delta: float) -> void:
	_time_elapsed += delta
	# Custom warp logic if needed beyond tweens

func _on_animation_finished():
	if not _is_warping:
		finished.emit()
		queue_free()
