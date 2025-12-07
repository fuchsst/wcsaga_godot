extends Node

# TimelineDatabase.gd
# Dynamic database that scans for TimelineEventResource files

static var _events: Dictionary = {}
static var _initialized: bool = false

# Path to scan for timeline resources
const CAMPAIGNS_PATH = "res://campaigns/index/"

static func _initialize_data():
	if _initialized: return
	
	print("TimelineDatabase: Initialization started.")
	_scan_campaigns_folder()
	
	# Fallback: Validation checks if needed
	if _events.is_empty():
		printerr("TimelineDatabase: No timeline events found in ", CAMPAIGNS_PATH)
		
	_initialized = true

static func _scan_campaigns_folder():
	# Scan the root directory itself for files
	_scan_campaign_subdirectory(CAMPAIGNS_PATH)

	var dir = DirAccess.open(CAMPAIGNS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				# Iterate into campaign subfolders
				_scan_campaign_subdirectory(CAMPAIGNS_PATH + file_name + "/")
			file_name = dir.get_next()
	else:
		printerr("TimelineDatabase: Failed to open campaigns path: ", CAMPAIGNS_PATH)

static func _scan_campaign_subdirectory(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
				var resource_path = path + file_name
				var resource = load(resource_path)
				if resource is TimelineEventResource:
					if not _events.has(resource.year):
						_events[resource.year] = []
					_events[resource.year].append(resource)
					print("TimelineDatabase: Loaded event ", resource.title, " for year ", resource.year)
			file_name = dir.get_next()

func get_events_for_year(year: int) -> Array:
	_initialize_data()
	if _events.has(year):
		return _events[year]
	return []

func get_all_years() -> Array:
	_initialize_data()
	var years = _events.keys()
	years.sort()
	return years
