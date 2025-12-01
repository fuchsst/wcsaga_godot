extends GdUnitTestSuite

func test_ship_initialization() -> void:
	var ship = Ship.new()
	assert_object(ship).is_not_null()
	assert_float(ship.max_speed).is_equal(100.0)
	assert_float(ship.gravity_scale).is_equal(0.0)
	ship.free()

func test_ship_inheritance() -> void:
	var ship = Ship.new()
	assert_bool(ship is GameEntity).is_true()
	assert_bool(ship is RigidBody3D).is_true()
	ship.free()
