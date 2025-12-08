extends GdUnitTestSuite

func test_ship_entity_initialization() -> void:
	var ship = ShipEntity.new()
	assert_object(ship).is_not_null()
	# ShipEntity is a physics body, check it exists
	assert_bool(ship is WCSPhysicsBody).is_true()
	ship.free()

func test_ship_entity_inheritance() -> void:
	var ship = ShipEntity.new()
	assert_bool(ship is WCSPhysicsBody).is_true()
	assert_bool(ship is CharacterBody3D).is_true()
	ship.free()
