@tool
extends EditorPlugin

## WCS SEXP Expression System Plugin
## 
## Provides S-Expression scripting capabilities for Wing Commander Saga mission logic.
## Includes parsing, evaluation, debugging, and integration tools for SEXP mission scripts.

const SexpManager = preload("res://addons/sexp/core/sexp_manager.gd")

func _enter_tree() -> void:
	# Add the SEXP manager as an autoload singleton
	add_autoload_singleton("SexpManager", "res://addons/sexp/core/sexp_manager.gd")
	
	print("WCS SEXP Expression System plugin activated")

func _exit_tree() -> void:
	# Remove the autoload singleton
	remove_autoload_singleton("SexpManager")
	
	print("WCS SEXP Expression System plugin deactivated")

func _has_main_screen() -> bool:
	return false

func _get_plugin_name() -> String:
	return "WCS SEXP System"