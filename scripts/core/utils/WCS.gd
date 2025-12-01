class_name WCS
extends Node

# Global helper for Wing Commander Saga localization
# Mimics the C++ XSTR macro behavior


static func XSTR(default_text: String, id: int) -> String:
	# If ID is valid, try to look up the XSTR key
	if id >= 0:
		var key = "XSTR_" + str(id)
		var translated = tr(key)

		# tr() returns the key if not found.
		# If the key is found, it returns the translation.
		# If the key is missing from CSV, we fall back to default_text.
		if translated != key:
			return translated

	# Fallback to translating the default text directly (for id -1 or missing IDs)
	# This supports tips/credits where the key is the text itself.
	return tr(default_text)
