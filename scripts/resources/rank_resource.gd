class_name RankResource
extends Resource

@export var name: String = ""
@export var points: int = 0
@export var bitmap: String = ""
@export var promo_voice: String = ""
@export var promo_text: String = ""

func _init(p_name: String = "", p_points: int = 0, p_bitmap: String = "", p_promo_voice: String = "", p_promo_text: String = "") -> void:
    name = p_name
    points = p_points
    bitmap = p_bitmap
    promo_voice = p_promo_voice
    promo_text = p_promo_text

func get_rank_name() -> String:
    return name

func get_points_required() -> int:
    return points

func get_insignia_bitmap() -> String:
    return bitmap

func get_promotion_voice() -> String:
    return promo_voice

func get_promotion_text() -> String:
    return promo_text