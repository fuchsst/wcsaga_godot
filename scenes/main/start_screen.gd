class_name StartScreen
extends Control

## Simple start screen for WCS-Godot conversion project
## Provides basic navigation to main game systems

signal start_screen_ready()
signal main_hall_requested()
signal options_requested()
signal exit_requested()

@onready var title_label: Label = $VBoxContainer/Title
@onready var subtitle_label: Label = $VBoxContainer/Subtitle
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var main_hall_button: Button = $VBoxContainer/ButtonContainer/MainHallButton
@onready var options_button: Button = $VBoxContainer/ButtonContainer/OptionsButton
@onready var exit_button: Button = $VBoxContainer/ButtonContainer/ExitButton

var foundation_systems_ready: bool = false

func _ready() -> void:
	_check_foundation_systems()
	_setup_ui()
	start_screen_ready.emit()

func _check_foundation_systems() -> void:
	# Check if core foundation systems are operational
	var systems_status: Array[String] = []
	
	# Check ObjectManager
	if ObjectManager != null:
		systems_status.append("ObjectManager: OK")
	else:
		systems_status.append("ObjectManager: MISSING")
	
	# Check GameStateManager
	if GameStateManager != null:
		systems_status.append("GameStateManager: OK")
	else:
		systems_status.append("GameStateManager: MISSING")
	
	# Check PhysicsManager
	if PhysicsManager != null:
		systems_status.append("PhysicsManager: OK")
	else:
		systems_status.append("PhysicsManager: MISSING")
	
	# Check InputManager
	if InputManager != null:
		systems_status.append("InputManager: OK")
	else:
		systems_status.append("InputManager: MISSING")
	
	# Update foundation systems status
	foundation_systems_ready = systems_status.size() >= 4
	
	if foundation_systems_ready:
		status_label.text = "Foundation Systems: Ready"
		status_label.modulate = Color(0.8, 1.0, 0.8, 1.0)
		main_hall_button.disabled = false
	else:
		status_label.text = "Foundation Systems: Issues Detected"
		status_label.modulate = Color(1.0, 0.8, 0.8, 1.0)
		main_hall_button.disabled = true
	
	# Print detailed status to console
	print("=== WCS Foundation Systems Status ===")
	for status in systems_status:
		print(status)
	print("=====================================")

func _setup_ui() -> void:
	# Setup title styling
	title_label.add_theme_font_size_override("font_size", 32)
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	
	# Setup button styling
	var button_min_size: Vector2 = Vector2(200, 40)
	main_hall_button.custom_minimum_size = button_min_size
	options_button.custom_minimum_size = button_min_size
	exit_button.custom_minimum_size = button_min_size

func _on_main_hall_button_pressed() -> void:
	print("StartScreen: Transitioning to Main Hall")
	main_hall_requested.emit()
	
	# Use SceneManager if available, otherwise fallback
	if SceneManager != null and Scenes != null:
		SceneManager.change_scene(Scenes.get_scene_path("main_hall"))
	else:
		print("StartScreen: SceneManager not available, using direct scene change")
		get_tree().change_scene_to_file("res://scenes/main/main_hall.tscn")

func _on_options_button_pressed() -> void:
	print("StartScreen: Opening Options")
	options_requested.emit()
	
	# Use SceneManager if available, otherwise fallback
	if SceneManager != null and Scenes != null:
		SceneManager.change_scene(Scenes.get_scene_path("options"))
	else:
		print("StartScreen: SceneManager not available, using direct scene change")
		get_tree().change_scene_to_file("res://scenes/ui/options.tscn")

func _on_exit_button_pressed() -> void:
	print("StartScreen: Exit requested")
	exit_requested.emit()
	get_tree().quit()

## Check if all foundation systems are operational
func are_foundation_systems_ready() -> bool:
	return foundation_systems_ready

## Get foundation system status for debugging
func get_foundation_status() -> Dictionary:
	return {
		"ObjectManager": ObjectManager != null,
		"GameStateManager": GameStateManager != null,
		"PhysicsManager": PhysicsManager != null,
		"InputManager": InputManager != null,
		"SceneManager": SceneManager != null,
		"Scenes": Scenes != null
	}