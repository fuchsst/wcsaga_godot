class_name ContextualHelp
extends RefCounted

## Contextual help system for property inspector.
## Provides property descriptions, examples, and documentation links.

static var _help_data: Dictionary = {}
static var _initialized: bool = false

static func initialize() -> void:
	"""Initialize the help system with property documentation."""
	if _initialized:
		return
	
	_load_help_data()
	_initialized = true

static func get_property_help(property_name: String) -> Dictionary:
	"""Get help information for a property."""
	if not _initialized:
		initialize()
	
	return _help_data.get(property_name, {
		"description": "No description available",
		"example": "",
		"valid_range": "",
		"related_properties": []
	})

static func get_property_tooltip(property_name: String) -> String:
	"""Get a concise tooltip for a property."""
	var help: Dictionary = get_property_help(property_name)
	var tooltip: String = help.get("description", "")
	
	var valid_range: String = help.get("valid_range", "")
	if not valid_range.is_empty():
		tooltip += "\nValid range: " + valid_range
	
	var example: String = help.get("example", "")
	if not example.is_empty():
		tooltip += "\nExample: " + example
	
	return tooltip

static func _load_help_data() -> void:
	"""Load help data for all properties."""
	# Transform properties
	_help_data["position"] = {
		"description": "Object position in 3D space (meters)",
		"example": "Vector3(1000.0, 0.0, 500.0)",
		"valid_range": "Any valid Vector3 values",
		"related_properties": ["rotation", "scale"]
	}
	
	_help_data["rotation"] = {
		"description": "Object rotation in degrees (Euler angles: pitch, bank, heading)",
		"example": "Vector3(0.0, 45.0, 0.0) for 45° turn",
		"valid_range": "-360° to 360° for each axis",
		"related_properties": ["position"]
	}
	
	_help_data["scale"] = {
		"description": "Object scale multiplier for each axis",
		"example": "Vector3(1.0, 1.0, 1.0) for normal size",
		"valid_range": "Positive values (typically 0.1 to 10.0)",
		"related_properties": ["position"]
	}
	
	# Object properties
	_help_data["object_name"] = {
		"description": "Unique name for this object in the mission",
		"example": "Alpha 1, Cargo Depot, Waypoint Alpha",
		"valid_range": "Any non-empty string",
		"related_properties": ["object_id"]
	}
	
	_help_data["visible"] = {
		"description": "Whether this object is visible in the mission",
		"example": "false for hidden objectives",
		"valid_range": "true or false",
		"related_properties": []
	}
	
	# Ship properties
	_help_data["ship_class"] = {
		"description": "Ship class type determining model and capabilities",
		"example": "GTF Apollo, GTD Orion, PVF Anubis",
		"valid_range": "Valid ship class from ships.tbl",
		"related_properties": ["team", "ai_class"]
	}
	
	_help_data["team"] = {
		"description": "Ship allegiance determining IFF and behavior",
		"example": "0=Friendly, 1=Hostile, 2=Neutral, 3=Unknown",
		"valid_range": "0 to 3",
		"related_properties": ["ai_class", "initial_orders"]
	}
	
	_help_data["ai_class"] = {
		"description": "AI skill level affecting combat behavior",
		"example": "5 for average pilot, 8 for ace",
		"valid_range": "0 (poor) to 10 (excellent)",
		"related_properties": ["team", "initial_orders"]
	}
	
	_help_data["initial_orders"] = {
		"description": "Starting AI orders for this ship",
		"example": "attack ship Alpha 2, guard ship Beta 1",
		"valid_range": "Valid AI order string",
		"related_properties": ["ai_class"]
	}
	
	# Mission logic properties
	_help_data["arrival_cue"] = {
		"description": "SEXP expression determining when object arrives",
		"example": "(true) for immediate arrival",
		"valid_range": "Valid SEXP returning boolean",
		"related_properties": ["departure_cue"]
	}
	
	_help_data["departure_cue"] = {
		"description": "SEXP expression determining when object departs",
		"example": "(false) to never depart",
		"valid_range": "Valid SEXP returning boolean",
		"related_properties": ["arrival_cue"]
	}
	
	# Weapon properties
	_help_data["weapon_type"] = {
		"description": "Type of weapon for weapon objects",
		"example": "Subach HL-7, Maxim Gun, GTM Hornet",
		"valid_range": "Valid weapon from weapons.tbl",
		"related_properties": []
	}
	
	# Waypoint properties
	_help_data["waypoint_path"] = {
		"description": "Name of waypoint path this waypoint belongs to",
		"example": "Alpha, Beta, Gamma",
		"valid_range": "Valid path name (letters/numbers)",
		"related_properties": []
	}
	
	# File paths
	_help_data["model_file"] = {
		"description": "3D model file for this object",
		"example": "fighter01.pof, capship02.glb",
		"valid_range": "Valid model file path",
		"related_properties": []
	}
	
	# Advanced properties
	_help_data["flags"] = {
		"description": "Object-specific flags controlling behavior",
		"example": "no-shields protect-ship",
		"valid_range": "Space-separated flag names",
		"related_properties": []
	}
	
	_help_data["object_id"] = {
		"description": "Unique identifier for this object (read-only)",
		"example": "12345",
		"valid_range": "System-generated unique ID",
		"related_properties": ["object_name"]
	}

static func show_detailed_help(property_name: String, parent_control: Control) -> void:
	"""Show detailed help dialog for a property."""
	var help: Dictionary = get_property_help(property_name)
	
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Help: " + property_name
	dialog.size = Vector2i(500, 400)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	dialog.add_child(vbox)
	
	# Description
	var desc_label: RichTextLabel = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.text = "[b]Description:[/b]\n" + help.get("description", "No description available")
	desc_label.custom_minimum_size.y = 60
	desc_label.fit_content = true
	vbox.add_child(desc_label)
	
	# Example
	var example: String = help.get("example", "")
	if not example.is_empty():
		var example_label: RichTextLabel = RichTextLabel.new()
		example_label.bbcode_enabled = true
		example_label.text = "[b]Example:[/b]\n[code]" + example + "[/code]"
		example_label.custom_minimum_size.y = 40
		example_label.fit_content = true
		vbox.add_child(example_label)
	
	# Valid range
	var valid_range: String = help.get("valid_range", "")
	if not valid_range.is_empty():
		var range_label: RichTextLabel = RichTextLabel.new()
		range_label.bbcode_enabled = true
		range_label.text = "[b]Valid Range:[/b]\n" + valid_range
		range_label.custom_minimum_size.y = 40
		range_label.fit_content = true
		vbox.add_child(range_label)
	
	# Related properties
	var related: Array = help.get("related_properties", [])
	if not related.is_empty():
		var related_label: RichTextLabel = RichTextLabel.new()
		related_label.bbcode_enabled = true
		related_label.text = "[b]Related Properties:[/b]\n" + ", ".join(related)
		related_label.custom_minimum_size.y = 40
		related_label.fit_content = true
		vbox.add_child(related_label)
	
	# Add to scene and show
	parent_control.add_child(dialog)
	dialog.popup_centered()
	
	# Clean up when closed
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)