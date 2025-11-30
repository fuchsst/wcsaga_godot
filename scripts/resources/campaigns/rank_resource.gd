extends Resource

@export var name: String
@export var bitmap: Texture2D
@export var promotion_text: String
@export var points: int = 0
@export var promotion_voice_base: String = ""
@export var promotion_voice: AudioStream

# Temporary field for conversion
var _bitmap_filename: String = ""
var _promotion_voice_base: String = ""
