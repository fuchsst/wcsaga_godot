extends Node
## InputHelper.gd
## DEPRECATED: Input bindings are now managed per-profile via GameSettings.
## This file is kept for backwards compatibility but should not be used.
## See: ProfileManager.gd, GameSettings.gd, GlobalSettings.apply_input_bindings()


func save_keybindings() -> void:
	push_warning("InputHelper.save_keybindings() is deprecated. Use ProfileManager instead.")


func load_keybindings() -> void:
	push_warning("InputHelper.load_keybindings() is deprecated. Use ProfileManager instead.")
