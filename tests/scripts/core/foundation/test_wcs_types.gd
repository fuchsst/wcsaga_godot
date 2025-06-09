extends GdUnitTestSuite

## Unit tests for WCSTypes class
## Tests type definitions, enums, data structures, and conversion functions
## Ensures all types maintain WCS compatibility

func test_game_mode_enum():
	# Test GameMode enum values match expected WCS values
	assert_that(WCSTypes.GameMode.NONE).is_equal(0)
	assert_that(WCSTypes.GameMode.HUD_CONFIG).is_equal(1)
	assert_that(WCSTypes.GameMode.MENU).is_equal(2)
	assert_that(WCSTypes.GameMode.GAME).is_equal(4)
	assert_that(WCSTypes.GameMode.BRIEFING).is_equal(8)
	assert_that(WCSTypes.GameMode.MULTIPLAYER).is_equal(256)

func test_viewer_mode_enum():
	# Test ViewerMode enum values
	assert_that(WCSTypes.ViewerMode.CHASE).is_equal(0)
	assert_that(WCSTypes.ViewerMode.EXTERNAL).is_equal(1)
	assert_that(WCSTypes.ViewerMode.COCKPIT).is_equal(2)
	assert_that(WCSTypes.ViewerMode.OTHER_SHIP).is_equal(7)

func test_iff_enum():
	# Test IFF enum values
	assert_that(WCSTypes.IFF.UNKNOWN).is_equal(-1)
	assert_that(WCSTypes.IFF.FRIENDLY).is_equal(0)
	assert_that(WCSTypes.IFF.HOSTILE).is_equal(1)
	assert_that(WCSTypes.IFF.NEUTRAL).is_equal(2)
	assert_that(WCSTypes.IFF.TRAITOR).is_equal(4)

func test_wcs_vector3d_creation():
	# Test WCSVector3D creation and conversion
	var vec3d: WCSTypes.WCSVector3D = WCSTypes.WCSVector3D.new(1.0, 2.0, 3.0)
	assert_that(vec3d.x).is_equal(1.0)
	assert_that(vec3d.y).is_equal(2.0)
	assert_that(vec3d.z).is_equal(3.0)

func test_wcs_vector3d_to_godot_conversion():
	# Test conversion to Godot Vector3
	var wcs_vec: WCSTypes.WCSVector3D = WCSTypes.WCSVector3D.new(5.0, 10.0, 15.0)
	var godot_vec: Vector3 = wcs_vec.to_vector3()
	
	assert_that(godot_vec.x).is_equal(5.0)
	assert_that(godot_vec.y).is_equal(10.0)
	assert_that(godot_vec.z).is_equal(15.0)

func test_wcs_vector3d_from_godot_conversion():
	# Test creation from Godot Vector3
	var godot_vec: Vector3 = Vector3(7.0, 8.0, 9.0)
	var wcs_vec: WCSTypes.WCSVector3D = WCSTypes.WCSVector3D.from_vector3(godot_vec)
	
	assert_that(wcs_vec.x).is_equal(7.0)
	assert_that(wcs_vec.y).is_equal(8.0)
	assert_that(wcs_vec.z).is_equal(9.0)

func test_wcs_vector3d_from_array():
	# Test creation from array (WCS C++ format)
	var array: Array = [10.0, 20.0, 30.0]
	var wcs_vec: WCSTypes.WCSVector3D = WCSTypes.WCSVector3D.from_array(array)
	
	assert_that(wcs_vec.x).is_equal(10.0)
	assert_that(wcs_vec.y).is_equal(20.0)
	assert_that(wcs_vec.z).is_equal(30.0)

func test_wcs_vector3d_from_small_array():
	# Test error handling with insufficient array size
	var small_array: Array = [1.0, 2.0]  # Only 2 elements
	var wcs_vec: WCSTypes.WCSVector3D = WCSTypes.WCSVector3D.from_array(small_array)
	
	# Should return default vector when array is too small
	assert_that(wcs_vec.x).is_equal(0.0)
	assert_that(wcs_vec.y).is_equal(0.0)
	assert_that(wcs_vec.z).is_equal(0.0)

func test_wcs_vector2d():
	# Test WCSVector2D functionality
	var vec2d: WCSTypes.WCSVector2D = WCSTypes.WCSVector2D.new(3.0, 4.0)
	assert_that(vec2d.x).is_equal(3.0)
	assert_that(vec2d.y).is_equal(4.0)
	
	var godot_vec2: Vector2 = vec2d.to_vector2()
	assert_that(godot_vec2.x).is_equal(3.0)
	assert_that(godot_vec2.y).is_equal(4.0)

func test_wcs_angles():
	# Test WCSAngles functionality
	var angles: WCSTypes.WCSAngles = WCSTypes.WCSAngles.new(45.0, 90.0, 180.0)
	assert_that(angles.pitch).is_equal(45.0)
	assert_that(angles.bank).is_equal(90.0)
	assert_that(angles.heading).is_equal(180.0)
	
	var radians_vec: Vector3 = angles.to_vector3_radians()
	assert_that(radians_vec.x).is_equal_approx(0.785398, 0.001)
	assert_that(radians_vec.y).is_equal_approx(3.141593, 0.001)
	assert_that(radians_vec.z).is_equal_approx(1.570796, 0.001)

func test_wcs_matrix():
	# Test WCSMatrix creation and conversion
	var matrix: WCSTypes.WCSMatrix = WCSTypes.WCSMatrix.new()
	
	# Test default identity matrix
	assert_that(matrix.right_vector.x).is_equal(1.0)
	assert_that(matrix.up_vector.y).is_equal(1.0)
	assert_that(matrix.forward_vector.z).is_equal(1.0)
	
	# Test conversion to Godot Basis
	var basis: Basis = matrix.to_basis()
	assert_that(basis.x.x).is_equal(1.0)
	assert_that(basis.y.y).is_equal(1.0)
	assert_that(basis.z.z).is_equal(1.0)

func test_wcs_matrix_from_basis():
	# Test creation from Godot Basis
	var basis: Basis = Basis(Vector3(2.0, 0.0, 0.0), Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, 4.0))
	var matrix: WCSTypes.WCSMatrix = WCSTypes.WCSMatrix.from_basis(basis)
	
	assert_that(matrix.right_vector.x).is_equal(2.0)
	assert_that(matrix.up_vector.y).is_equal(3.0)
	assert_that(matrix.forward_vector.z).is_equal(4.0)

func test_fix_conversion():
	# Test fixed-point conversion functions
	var float_val: float = 1.5
	var fix_val: int = WCSTypes.float_to_fix(float_val)
	var converted_back: float = WCSTypes.fix_to_float(fix_val)
	
	assert_that(converted_back).is_equal_approx(float_val, 0.001)
	
	# Test specific values
	assert_that(WCSTypes.float_to_fix(1.0)).is_equal(65536)
	assert_that(WCSTypes.fix_to_float(65536)).is_equal(1.0)

func test_color_conversion():
	# Test ubyte to color component conversion
	assert_that(WCSTypes.ubyte_to_color_component(0)).is_equal(0.0)
	assert_that(WCSTypes.ubyte_to_color_component(255)).is_equal(1.0)
	assert_that(WCSTypes.ubyte_to_color_component(128)).is_equal_approx(0.502, 0.01)
	
	# Test color component to ubyte conversion
	assert_that(WCSTypes.color_component_to_ubyte(0.0)).is_equal(0)
	assert_that(WCSTypes.color_component_to_ubyte(1.0)).is_equal(255)
	assert_that(WCSTypes.color_component_to_ubyte(0.5)).is_equal_approx(127.5, 1.0)

func test_vertex_color_conversion():
	# Test vertex color to Godot Color conversion
	var godot_color: Color = WCSTypes.vertex_color_to_godot(255, 128, 64, 32)
	
	assert_that(godot_color.r).is_equal(1.0)
	assert_that(godot_color.g).is_equal_approx(0.502, 0.01)
	assert_that(godot_color.b).is_equal_approx(0.251, 0.01)
	assert_that(godot_color.a).is_equal_approx(0.125, 0.01)

func test_godot_color_to_vertex():
	# Test Godot Color to vertex color conversion
	var color: Color = Color(1.0, 0.5, 0.25, 0.125)
	var vertex_color: Dictionary = WCSTypes.godot_color_to_vertex(color)
	
	assert_that(vertex_color["r"]).is_equal(255)
	assert_that(vertex_color["g"]).is_equal_approx(127.5, 1.0)
	assert_that(vertex_color["b"]).is_equal_approx(63.75, 1.0)
	assert_that(vertex_color["a"]).is_equal_approx(31.875, 1.0)

func test_validation_functions():
	# Test game mode validation
	assert_that(WCSTypes.validate_game_mode(WCSTypes.GameMode.MENU)).is_true()
	assert_that(WCSTypes.validate_game_mode(0)).is_true()
	assert_that(WCSTypes.validate_game_mode(256)).is_true()
	assert_that(WCSTypes.validate_game_mode(-1)).is_false()
	assert_that(WCSTypes.validate_game_mode(1000)).is_false()
	
	# Test viewer mode validation
	assert_that(WCSTypes.validate_viewer_mode(WCSTypes.ViewerMode.CHASE)).is_true()
	assert_that(WCSTypes.validate_viewer_mode(WCSTypes.ViewerMode.OTHER_SHIP)).is_true()
	assert_that(WCSTypes.validate_viewer_mode(-1)).is_false()
	assert_that(WCSTypes.validate_viewer_mode(10)).is_false()
	
	# Test IFF validation
	assert_that(WCSTypes.validate_iff(WCSTypes.IFF.FRIENDLY)).is_true()
	assert_that(WCSTypes.validate_iff(WCSTypes.IFF.UNKNOWN)).is_true()
	assert_that(WCSTypes.validate_iff(-2)).is_false()
	assert_that(WCSTypes.validate_iff(10)).is_false()

func test_string_conversion_functions():
	# Test GameMode to string conversion
	assert_that(WCSTypes.game_mode_to_string(WCSTypes.GameMode.MENU)).is_equal("Menu")
	assert_that(WCSTypes.game_mode_to_string(WCSTypes.GameMode.BRIEFING)).is_equal("Briefing")
	assert_that(WCSTypes.game_mode_to_string(999)).is_equal("Unknown")
	
	# Test ViewerMode to string conversion
	assert_that(WCSTypes.viewer_mode_to_string(WCSTypes.ViewerMode.CHASE)).is_equal("Chase")
	assert_that(WCSTypes.viewer_mode_to_string(WCSTypes.ViewerMode.COCKPIT)).is_equal("Cockpit")
	assert_that(WCSTypes.viewer_mode_to_string(999)).is_equal("Unknown")
	
	# Test IFF to string conversion
	assert_that(WCSTypes.iff_to_string(WCSTypes.IFF.FRIENDLY)).is_equal("Friendly")
	assert_that(WCSTypes.iff_to_string(WCSTypes.IFF.HOSTILE)).is_equal("Hostile")
	assert_that(WCSTypes.iff_to_string(999)).is_equal("Invalid")

func test_uv_pair():
	# Test WCSUVPair functionality
	var uv: WCSTypes.WCSUVPair = WCSTypes.WCSUVPair.new(0.25, 0.75)
	assert_that(uv.u).is_equal(0.25)
	assert_that(uv.v).is_equal(0.75)
	
	var vec2: Vector2 = uv.to_vector2()
	assert_that(vec2.x).is_equal(0.25)
	assert_that(vec2.y).is_equal(0.75)