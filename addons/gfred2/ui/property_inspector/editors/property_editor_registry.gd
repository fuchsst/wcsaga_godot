class_name PropertyEditorRegistry
extends RefCounted

## Registry for creating type-specific property editors.
## Provides factory methods for different property types with consistent interfaces.
## Supports dependency injection for testing and custom editor implementations.

var editor_factories: Dictionary = {}
var validator: ObjectValidator
var contextual_help: ContextualHelp

func _init(custom_validator: ObjectValidator = null, custom_help: ContextualHelp = null) -> void:
	validator = custom_validator if custom_validator else ObjectValidator.new()
	contextual_help = custom_help if custom_help else ContextualHelp
	_register_default_factories()

func _register_default_factories() -> void:
	"""Register default editor factory functions."""
	editor_factories["vector3"] = _create_vector3_editor_default
	editor_factories["string"] = _create_string_editor_default
	editor_factories["boolean"] = _create_boolean_editor_default
	editor_factories["number"] = _create_number_editor_default
	editor_factories["sexp"] = _create_sexp_editor_default
	editor_factories["file_path"] = _create_file_path_editor_default
	editor_factories["readonly"] = _create_readonly_editor_default
	editor_factories["enum"] = _create_enum_editor_default
	editor_factories["color"] = _create_color_editor_default

func register_editor_factory(editor_type: String, factory_function: Callable) -> void:
	"""Register a custom editor factory for testing or custom implementations."""
	editor_factories[editor_type] = factory_function

func create_vector3_editor(property_name: String, label_text: String, 
	current_value: Vector3, options: Dictionary = {}) -> Vector3PropertyEditor:
	"""Create a Vector3 property editor."""
	if not options.has("tooltip") and contextual_help:
		options["tooltip"] = contextual_help.get_property_tooltip(property_name)
	
	var factory: Callable = editor_factories.get("vector3", _create_vector3_editor_default)
	return factory.call(property_name, label_text, current_value, options)

func _create_vector3_editor_default(property_name: String, label_text: String, 
	current_value: Vector3, options: Dictionary) -> Vector3PropertyEditor:
	"""Default factory for Vector3 editors."""
	var editor: Vector3PropertyEditor = Vector3PropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func create_string_editor(property_name: String, label_text: String, 
	current_value: String, options: Dictionary = {}) -> StringPropertyEditor:
	"""Create a string property editor."""
	if not options.has("tooltip") and contextual_help:
		options["tooltip"] = contextual_help.get_property_tooltip(property_name)
	
	var factory: Callable = editor_factories.get("string", _create_string_editor_default)
	return factory.call(property_name, label_text, current_value, options)

func _create_string_editor_default(property_name: String, label_text: String, 
	current_value: String, options: Dictionary) -> StringPropertyEditor:
	"""Default factory for string editors."""
	var editor: StringPropertyEditor = StringPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func create_number_editor(property_name: String, label_text: String, 
	current_value: float, options: Dictionary = {}) -> NumberPropertyEditor:
	"""Create a number property editor."""
	var editor: NumberPropertyEditor = NumberPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func create_boolean_editor(property_name: String, label_text: String, 
	current_value: bool, options: Dictionary = {}) -> BooleanPropertyEditor:
	"""Create a boolean property editor."""
	var editor: BooleanPropertyEditor = BooleanPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func create_enum_editor(property_name: String, label_text: String, 
	current_value: int, options: Dictionary = {}) -> EnumPropertyEditor:
	"""Create an enum property editor."""
	var editor: EnumPropertyEditor = EnumPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func create_color_editor(property_name: String, label_text: String, 
	current_value: Color, options: Dictionary = {}) -> ColorPropertyEditor:
	"""Create a color property editor."""
	var editor: ColorPropertyEditor = ColorPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func create_file_path_editor(property_name: String, label_text: String, 
	current_value: String, options: Dictionary = {}) -> FilePathPropertyEditor:
	"""Create a file path property editor."""
	var editor: FilePathPropertyEditor = FilePathPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func create_sexp_editor(property_name: String, label_text: String, 
	current_value: String, options: Dictionary = {}) -> SexpPropertyEditor:
	"""Create a SEXP property editor."""
	var editor: SexpPropertyEditor = SexpPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func create_readonly_editor(property_name: String, label_text: String, 
	value: String) -> ReadOnlyPropertyEditor:
	"""Create a read-only property display."""
	var editor: ReadOnlyPropertyEditor = ReadOnlyPropertyEditor.new()
	editor.setup_editor(property_name, label_text, value, {})
	return editor

# Multi-object editors

func create_multi_vector3_editor(property_name: String, label_text: String, 
	objects: Array[MissionObjectData]) -> MultiVector3PropertyEditor:
	"""Create a Vector3 property editor for multiple objects."""
	var editor: MultiVector3PropertyEditor = MultiVector3PropertyEditor.new()
	editor.setup_multi_editor(property_name, label_text, objects)
	return editor

func create_multi_boolean_editor(property_name: String, label_text: String, 
	objects: Array[MissionObjectData]) -> MultiBooleanPropertyEditor:
	"""Create a boolean property editor for multiple objects."""
	var editor: MultiBooleanPropertyEditor = MultiBooleanPropertyEditor.new()
	editor.setup_multi_editor(property_name, label_text, objects)
	return editor

func create_multi_string_editor(property_name: String, label_text: String, 
	objects: Array[MissionObjectData]) -> MultiStringPropertyEditor:
	"""Create a string property editor for multiple objects."""
	var editor: MultiStringPropertyEditor = MultiStringPropertyEditor.new()
	editor.setup_multi_editor(property_name, label_text, objects)
	return editor

func create_multi_number_editor(property_name: String, label_text: String, 
	objects: Array[MissionObjectData]) -> MultiNumberPropertyEditor:
	"""Create a number property editor for multiple objects."""
	var editor: MultiNumberPropertyEditor = MultiNumberPropertyEditor.new()
	editor.setup_multi_editor(property_name, label_text, objects)
	return editor

# Default factory implementations for dependency injection
func _create_boolean_editor_default(property_name: String, label_text: String, 
	current_value: bool, options: Dictionary) -> BooleanPropertyEditor:
	var editor: BooleanPropertyEditor = BooleanPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func _create_number_editor_default(property_name: String, label_text: String, 
	current_value: float, options: Dictionary) -> NumberPropertyEditor:
	var editor: NumberPropertyEditor = NumberPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func _create_sexp_editor_default(property_name: String, label_text: String, 
	current_value: String, options: Dictionary) -> SexpPropertyEditor:
	var editor: SexpPropertyEditor = SexpPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func _create_file_path_editor_default(property_name: String, label_text: String, 
	current_value: String, options: Dictionary) -> FilePathPropertyEditor:
	var editor: FilePathPropertyEditor = FilePathPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func _create_readonly_editor_default(property_name: String, label_text: String, 
	value: String, options: Dictionary) -> ReadOnlyPropertyEditor:
	var editor: ReadOnlyPropertyEditor = ReadOnlyPropertyEditor.new()
	editor.setup_editor(property_name, label_text, value, options)
	return editor

func _create_enum_editor_default(property_name: String, label_text: String, 
	current_value: int, options: Dictionary) -> EnumPropertyEditor:
	var editor: EnumPropertyEditor = EnumPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor

func _create_color_editor_default(property_name: String, label_text: String, 
	current_value: Color, options: Dictionary) -> ColorPropertyEditor:
	var editor: ColorPropertyEditor = ColorPropertyEditor.new()
	editor.setup_editor(property_name, label_text, current_value, options)
	return editor