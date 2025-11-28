extends Resource
class_name BackgroundSet

## A set of background elements (suns + star bitmaps)
## Multiple sets can exist in a mission

@export var suns: Array[SunData] = []
@export var bitmaps: Array[StarBitmapData] = []
