extends Resource
class_name LocalizationManifest

## Manifest containing localized strings for a specific locale

@export var locale: String = "en"
@export var strings: Array[LocalizationResource] = []
