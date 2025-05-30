extends Node

## VP Resource Manager - Handles registration of VP ResourceFormatLoader
## Integrates VP archives with Godot's resource loading system

const VPResourceFormatLoader = preload("res://scripts/core/archives/vp_resource_loader.gd")
const VPArchive = preload("res://scripts/core/archives/vp_archive.gd")

var vp_loader: VPResourceFormatLoader
var is_registered: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_register_vp_loader()

## Register the VP ResourceFormatLoader with Godot
func _register_vp_loader() -> void:
	if is_registered:
		push_warning("VPResourceManager: VP loader already registered")
		return
	
	vp_loader = VPResourceFormatLoader.new()
	ResourceLoader.add_resource_format_loader(vp_loader, true)
	is_registered = true
	
	print("VPResourceManager: VP ResourceFormatLoader registered successfully")

## Unregister the VP ResourceFormatLoader (cleanup)
func _unregister_vp_loader() -> void:
	if not is_registered or vp_loader == null:
		return
	
	ResourceLoader.remove_resource_format_loader(vp_loader)
	is_registered = false
	vp_loader = null
	
	print("VPResourceManager: VP ResourceFormatLoader unregistered")

## Enable debug logging for VP loading
func enable_debug_logging(enabled: bool = true) -> void:
	if vp_loader != null:
		vp_loader.set_debug_enabled(enabled)

## Clear VP archive cache
func clear_cache() -> void:
	if vp_loader != null:
		vp_loader.clear_cache()

## Get cache information
func get_cache_info() -> Dictionary:
	if vp_loader != null:
		return vp_loader.get_cache_info()
	return {}

## Load a VP archive using standard Godot resource loading
## Example: var archive = VPResourceManager.load_vp_archive("res://data/models.vp")
func load_vp_archive(vp_path: String) -> VPArchive:
	var resource = load(vp_path)
	if resource is VPArchive:
		return resource as VPArchive
	else:
		push_error("VPResourceManager: Failed to load VP archive or wrong type: %s" % vp_path)
		return null

## Check if VP loading is available
func is_vp_loading_available() -> bool:
	return is_registered and vp_loader != null

func _exit_tree() -> void:
	_unregister_vp_loader()
