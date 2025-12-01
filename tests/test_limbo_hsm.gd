extends GdUnitTestSuite

func test_hsm_initialization() -> void:
	var hsm = GameStateMachine.new()
	add_child(hsm)
	
	# Verify initial state is Intro
	assert_object(hsm.get_active_state()).is_equal(hsm.state_intro)
	
	hsm.free()

func test_state_transition() -> void:
	var hsm = GameStateMachine.new()
	add_child(hsm)
	
	# Wait for timer transition or force it
	hsm.dispatch(&"to_main_menu")
	
	assert_object(hsm.get_active_state()).is_equal(hsm.state_main_menu)
	
	hsm.free()
