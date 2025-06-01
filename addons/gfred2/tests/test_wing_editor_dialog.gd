extends GdUnitTestSuite

## Test suite for Wing Editor Dialog
## 
## Tests the comprehensive wing editing functionality to ensure proper integration
## with WCS wing data structures and mission editing workflows.

var wing_editor_scene: PackedScene
var wing_editor: WingEditorDialogController
var test_mission: MissionData
var test_wing: WingInstanceData

func before_test():
	# Load the wing editor scene
	wing_editor_scene = load("res://addons/gfred2/scenes/dialogs/wing_editor_dialog.tscn")
	assert_not_null(wing_editor_scene, "Wing editor scene should load")
	
	# Create test mission data
	test_mission = MissionData.create_empty_mission()
	test_mission.mission_title = "Test Mission for Wing Editor"
	
	# Create test wing data
	test_wing = WingInstanceData.new()
	test_wing.wing_name = "Alpha"
	test_wing.num_waves = 2
	test_wing.wave_threshold = 1
	test_wing.special_ship_index = 0
	test_wing.hotkey = 0  # F5
	test_wing.squad_logo_filename = "alpha_logo.png"
	test_wing.arrival_location = 0
	test_wing.arrival_delay_ms = 5000  # 5 seconds
	test_wing.arrival_distance = 1000
	test_wing.wave_delay_min = 2000  # 2 seconds
	test_wing.wave_delay_max = 8000  # 8 seconds
	test_wing.departure_location = 0
	test_wing.departure_delay_ms = 3000  # 3 seconds
	test_wing.flags = 0  # No flags initially
	test_wing.arrival_anchor_name = ""
	test_wing.departure_anchor_name = ""
	
	# Add wing to mission
	test_mission.wings.append(test_wing)

func after_test():
	# Clean up
	if wing_editor and is_instance_valid(wing_editor):
		wing_editor.queue_free()

func test_wing_editor_scene_instantiation():
	# Test that the wing editor scene can be instantiated
	wing_editor = wing_editor_scene.instantiate()
	assert_not_null(wing_editor, "Wing editor should instantiate")
	assert_that(wing_editor).is_instance_of(WingEditorDialogController)

func test_wing_editor_show_dialog():
	# Test showing the wing editor dialog
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	# Show the dialog with test data
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Verify dialog is visible
	assert_bool(wing_editor.visible).is_true()
	assert_that(wing_editor.current_wing).is_equal(test_wing)
	assert_int(wing_editor.current_wing_index).is_equal(0)
	assert_that(wing_editor.mission_data).is_equal(test_mission)

func test_wing_basic_info_loading():
	# Test that basic wing info loads correctly
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Check that UI elements reflect the wing data
	assert_str(wing_editor.wing_name_edit.text).is_equal("Alpha")
	assert_int(wing_editor.special_ship_option.selected).is_equal(1)  # +1 for "<none>" option
	assert_int(wing_editor.hotkey_option.selected).is_equal(1)  # +1 for "<none>" option
	assert_str(wing_editor.squad_logo_edit.text).is_equal("alpha_logo.png")

func test_wing_wave_management_loading():
	# Test that wave management data loads correctly
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Check wave management values
	assert_float(wing_editor.waves_spin.value).is_equal_approx(2.0, 0.01)
	assert_float(wing_editor.threshold_spin.value).is_equal_approx(1.0, 0.01)

func test_wing_arrival_settings_loading():
	# Test that arrival settings load correctly
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Check arrival settings
	assert_int(wing_editor.arrival_location_option.selected).is_equal(0)
	assert_float(wing_editor.arrival_delay_spin.value).is_equal_approx(5.0, 0.01)  # 5000ms -> 5s
	assert_float(wing_editor.arrival_distance_spin.value).is_equal_approx(1000.0, 0.01)
	assert_float(wing_editor.arrival_delay_min_spin.value).is_equal_approx(2.0, 0.01)  # 2000ms -> 2s
	assert_float(wing_editor.arrival_delay_max_spin.value).is_equal_approx(8.0, 0.01)  # 8000ms -> 8s

func test_wing_departure_settings_loading():
	# Test that departure settings load correctly
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Check departure settings
	assert_int(wing_editor.departure_location_option.selected).is_equal(0)
	assert_float(wing_editor.departure_delay_spin.value).is_equal_approx(3.0, 0.01)  # 3000ms -> 3s

func test_wing_flags_loading():
	# Test that wing flags load correctly
	test_wing.flags = wing_editor.WING_FLAG_REINFORCEMENT | wing_editor.WING_FLAG_NO_ARRIVAL_MUSIC
	
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Check that flags are reflected in checkboxes
	assert_bool(wing_editor.reinforcement_check.button_pressed).is_true()
	assert_bool(wing_editor.no_arrival_music_check.button_pressed).is_true()
	assert_bool(wing_editor.ignore_count_check.button_pressed).is_false()

func test_wing_data_modification():
	# Test that modifying wing data works correctly
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Modify wing name
	wing_editor.wing_name_edit.text = "Beta Squadron"
	wing_editor._on_wing_name_changed("Beta Squadron")
	
	# Modify wave settings
	wing_editor.waves_spin.value = 3
	wing_editor._on_waves_changed(3.0)
	
	# Check that modification flag is set
	assert_bool(wing_editor.modified).is_true()

func test_wing_data_saving():
	# Test that wing data saves correctly
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Modify data
	wing_editor.wing_name_edit.text = "Beta Squadron"
	wing_editor.waves_spin.value = 3
	wing_editor.threshold_spin.value = 2
	wing_editor.reinforcement_check.button_pressed = true
	wing_editor.no_arrival_music_check.button_pressed = true
	
	# Save data
	wing_editor._save_wing_data()
	
	# Check that wing data was updated
	assert_str(test_wing.wing_name).is_equal("Beta Squadron")
	assert_int(test_wing.num_waves).is_equal(3)
	assert_int(test_wing.wave_threshold).is_equal(2)
	
	# Check flags
	var expected_flags = wing_editor.WING_FLAG_REINFORCEMENT | wing_editor.WING_FLAG_NO_ARRIVAL_MUSIC
	assert_int(test_wing.flags).is_equal(expected_flags)

func test_wing_navigation_buttons():
	# Test navigation button functionality
	# Create multiple wings
	var wing2 = WingInstanceData.new()
	wing2.wing_name = "Beta"
	test_mission.wings.append(wing2)
	
	var wing3 = WingInstanceData.new()  
	wing3.wing_name = "Gamma"
	test_mission.wings.append(wing3)
	
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	# Show first wing
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Check navigation button states
	assert_bool(wing_editor.prev_wing_button.disabled).is_true()  # First wing
	assert_bool(wing_editor.next_wing_button.disabled).is_false()  # Can go to next
	
	# Show middle wing
	wing_editor.show_wing_editor(wing2, 1, test_mission)
	
	# Check navigation button states
	assert_bool(wing_editor.prev_wing_button.disabled).is_false()  # Can go to prev
	assert_bool(wing_editor.next_wing_button.disabled).is_false()  # Can go to next
	
	# Show last wing
	wing_editor.show_wing_editor(wing3, 2, test_mission)
	
	# Check navigation button states
	assert_bool(wing_editor.prev_wing_button.disabled).is_false()  # Can go to prev
	assert_bool(wing_editor.next_wing_button.disabled).is_true()  # Last wing

func test_wing_target_population():
	# Test that target options are populated correctly
	# Add ships to mission
	var ship1 = ShipInstanceData.new()
	ship1.ship_name = "GTF Ulysses 1"
	test_mission.ships.append(ship1)
	
	var ship2 = ShipInstanceData.new()
	ship2.ship_name = "GTF Ulysses 2"
	test_mission.ships.append(ship2)
	
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Check that target options include ships
	assert_int(wing_editor.arrival_target_option.get_item_count()).is_greater_equal(3)  # <none> + 2 ships
	assert_str(wing_editor.arrival_target_option.get_item_text(1)).is_equal("GTF Ulysses 1")
	assert_str(wing_editor.arrival_target_option.get_item_text(2)).is_equal("GTF Ulysses 2")

func test_wing_sexp_tree_loading():
	# Test that SEXP trees are properly initialized
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Check that SEXP trees have content
	var arrival_root = wing_editor.arrival_sexp_tree.get_root()
	assert_not_null(arrival_root, "Arrival SEXP tree should have root")
	assert_int(arrival_root.get_child_count()).is_greater(0)
	
	var departure_root = wing_editor.departure_sexp_tree.get_root()
	assert_not_null(departure_root, "Departure SEXP tree should have root")
	assert_int(departure_root.get_child_count()).is_greater(0)

func test_wing_flags_constants():
	# Test that wing flag constants are properly defined
	wing_editor = wing_editor_scene.instantiate()
	
	# Check that constants are non-zero and unique powers of 2
	assert_int(wing_editor.WING_FLAG_REINFORCEMENT).is_equal(1)
	assert_int(wing_editor.WING_FLAG_IGNORE_COUNT).is_equal(2)
	assert_int(wing_editor.WING_FLAG_NO_ARRIVAL_MUSIC).is_equal(4)
	assert_int(wing_editor.WING_FLAG_NO_ARRIVAL_MESSAGE).is_equal(8)
	assert_int(wing_editor.WING_FLAG_NO_ARRIVAL_WARP).is_equal(16)
	assert_int(wing_editor.WING_FLAG_NO_DEPARTURE_WARP).is_equal(32)
	assert_int(wing_editor.WING_FLAG_NO_ARRIVAL_LOG).is_equal(64)
	assert_int(wing_editor.WING_FLAG_NO_DEPARTURE_LOG).is_equal(128)
	assert_int(wing_editor.WING_FLAG_NO_DYNAMIC).is_equal(256)

func test_wing_location_constants():
	# Test that location constants are properly defined
	wing_editor = wing_editor_scene.instantiate()
	
	# Check arrival locations
	assert_int(wing_editor.ARRIVAL_LOCATIONS.size()).is_greater(0)
	assert_str(wing_editor.ARRIVAL_LOCATIONS[0]).is_equal("Hyperspace")
	
	# Check departure locations
	assert_int(wing_editor.DEPARTURE_LOCATIONS.size()).is_greater(0)
	assert_str(wing_editor.DEPARTURE_LOCATIONS[0]).is_equal("Hyperspace")

func test_wing_editor_signal_emission():
	# Test that wing editor emits proper signals
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	var signal_emitted = false
	var emitted_wing = null
	
	wing_editor.wing_modified.connect(func(wing): 
		signal_emitted = true
		emitted_wing = wing
	)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	wing_editor._save_wing_data()
	
	# Check that signal was emitted with correct data
	assert_bool(signal_emitted).is_true()
	assert_that(emitted_wing).is_equal(test_wing)

func test_wing_special_ship_population():
	# Test special ship option population
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Check that special ship options are populated
	assert_int(wing_editor.special_ship_option.get_item_count()).is_greater(1)  # <none> + ships
	assert_str(wing_editor.special_ship_option.get_item_text(0)).is_equal("<none>")

func test_wing_hotkey_options():
	# Test hotkey option setup
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	# Check hotkey options
	assert_int(wing_editor.hotkey_option.get_item_count()).is_equal(9)  # <none> + F5-F12
	assert_str(wing_editor.hotkey_option.get_item_text(0)).is_equal("None")
	assert_str(wing_editor.hotkey_option.get_item_text(1)).is_equal("F5")
	assert_str(wing_editor.hotkey_option.get_item_text(8)).is_equal("F12")

func test_wing_editor_performance():
	# Test that wing editor loads and displays quickly
	var start_time = Time.get_ticks_msec()
	
	wing_editor = wing_editor_scene.instantiate()
	add_child(wing_editor)
	wing_editor.show_wing_editor(test_wing, 0, test_mission)
	
	var load_time = Time.get_ticks_msec() - start_time
	
	# Should load in under 100ms for responsive UI
	assert_int(load_time).is_less(100)