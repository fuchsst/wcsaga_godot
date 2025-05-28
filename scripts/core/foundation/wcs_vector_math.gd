class_name WCSVectorMath
extends RefCounted

## Complete WCS vector/matrix mathematics library ported from vecmat.cpp.
## Provides all vector and matrix operations used by WCS with exact behavior matching.
## Uses Godot's Vector3 and Basis types for efficient computation while maintaining WCS compatibility.

# Mathematical constants from WCS
const SMALL_NUM: float = 1e-7
const SMALLER_NUM: float = 1e-20
const CONVERT_RADIANS: float = 0.017453292519943  # PI/180
const NO_LARGEST: int = -1

# Standard vectors (matching WCS globals)
const ZERO_VECTOR: Vector3 = Vector3.ZERO
const X_VECTOR: Vector3 = Vector3.RIGHT
const Y_VECTOR: Vector3 = Vector3.UP  
const Z_VECTOR: Vector3 = Vector3.FORWARD
const IDENTITY_MATRIX: Basis = Basis.IDENTITY

# ========================================
# Vector Operations
# ========================================

## Check if vector is effectively zero (safe epsilon)
static func is_vec_null_safe(v: Vector3) -> bool:
	return (abs(v.x) < 1e-16) and (abs(v.y) < 1e-16) and (abs(v.z) < 1e-16)

## Check if vector is effectively zero (smaller epsilon)
static func is_vec_null(v: Vector3) -> bool:
	return (abs(v.x) < 1e-36) and (abs(v.y) < 1e-36) and (abs(v.z) < 1e-36)

## Check if vector contains NaN values
static func is_vec_nan(v: Vector3) -> bool:
	return is_nan(v.x) or is_nan(v.y) or is_nan(v.z)

## Average n vectors
static func vec_avg_n(vectors: Array[Vector3]) -> Vector3:
	if vectors.is_empty():
		return ZERO_VECTOR
	
	var result: Vector3 = ZERO_VECTOR
	for vec in vectors:
		result += vec
	
	return result / float(vectors.size())

## Average two vectors
static func vec_avg(src0: Vector3, src1: Vector3) -> Vector3:
	return (src0 + src1) * 0.5

## Average three vectors
static func vec_avg3(src0: Vector3, src1: Vector3, src2: Vector3) -> Vector3:
	return (src0 + src1 + src2) / 3.0

## Average four vectors
static func vec_avg4(src0: Vector3, src1: Vector3, src2: Vector3, src3: Vector3) -> Vector3:
	return (src0 + src1 + src2 + src3) * 0.25

## Scale and add: dest = src1 + k * src2
static func vec_scale_add(src1: Vector3, src2: Vector3, k: float) -> Vector3:
	return src1 + src2 * k

## Scale and subtract: dest = src1 - k * src2
static func vec_scale_sub(src1: Vector3, src2: Vector3, k: float) -> Vector3:
	return src1 - src2 * k

## Returns magnitude squared (avoiding sqrt for performance)
static func vec_mag_squared(v: Vector3) -> float:
	return v.length_squared()

## Returns magnitude (length) of vector
static func vec_mag(v: Vector3) -> float:
	return v.length()

## Copy and normalize vector, return original magnitude
static func vec_copy_normalize(src: Vector3) -> Dictionary:
	var mag: float = src.length()
	if mag < SMALL_NUM:
		return {"normalized": ZERO_VECTOR, "magnitude": 0.0}
	return {"normalized": src / mag, "magnitude": mag}

## Normalize vector in place, return original magnitude
static func vec_normalize(v: Vector3) -> Dictionary:
	return vec_copy_normalize(v)

## Normalize vector only if magnitude > epsilon
static func vec_normalize_safe(v: Vector3) -> Vector3:
	var mag: float = v.length()
	if mag < SMALL_NUM:
		return ZERO_VECTOR
	return v / mag

## Fast normalize using Godot's optimized function
static func vec_normalize_quick(v: Vector3) -> Vector3:
	return v.normalized()

## Copy vector (explicitly for compatibility)
static func vec_copy(src: Vector3) -> Vector3:
	return Vector3(src.x, src.y, src.z)

## Distance between two points
static func vec_dist(src0: Vector3, src1: Vector3) -> float:
	return src0.distance_to(src1)

## Distance squared between two points (faster)
static func vec_dist_squared(src0: Vector3, src1: Vector3) -> float:
	return src0.distance_squared_to(src1)

## Dot product of two vectors
static func vec_dot(src0: Vector3, src1: Vector3) -> float:
	return src0.dot(src1)

## Cross product of two vectors
static func vec_cross(src0: Vector3, src1: Vector3) -> Vector3:
	return src0.cross(src1)

## Linear interpolation between two vectors
static func vec_interp(src0: Vector3, src1: Vector3, t: float) -> Vector3:
	return src0.lerp(src1, t)

## Create vector from three floats
static func vec_make(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)

## Random vector in sphere (uniform distribution)
static func vec_random_in_sphere(radius: float = 1.0) -> Vector3:
	var vec: Vector3
	repeat:
		vec = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0), 
			randf_range(-1.0, 1.0)
		)
		if vec.length_squared() <= 1.0:
			return vec * radius
		else:
			goto repeat

## Random vector on sphere surface
static func vec_random_on_sphere(radius: float = 1.0) -> Vector3:
	var vec: Vector3 = vec_random_in_sphere(1.0)
	return vec.normalized() * radius

## Random vector in cone around direction
static func vec_random_in_cone(direction: Vector3, angle_radians: float) -> Vector3:
	var dir_norm: Vector3 = direction.normalized()
	var random_vec: Vector3 = vec_random_on_sphere()
	
	# Use spherical linear interpolation to get vector in cone
	var cos_angle: float = cos(angle_radians)
	var t: float = (1.0 - cos_angle) * randf() + cos_angle
	
	# Find a perpendicular vector for rotation axis
	var perp: Vector3
	if abs(dir_norm.x) < 0.9:
		perp = Vector3.RIGHT.cross(dir_norm).normalized()
	else:
		perp = Vector3.UP.cross(dir_norm).normalized()
	
	# Rotate random vector around the cone
	var rotation_angle: float = randf() * TAU
	var rotated_perp: Vector3 = perp.rotated(dir_norm, rotation_angle)
	
	# Interpolate between direction and rotated perpendicular
	var result: Vector3 = dir_norm * t + rotated_perp * sqrt(1.0 - t * t)
	return result.normalized()

## Reflect vector off surface with given normal
static func vec_reflect(incident: Vector3, normal: Vector3) -> Vector3:
	return incident.reflect(normal)

## Project vector A onto vector B
static func vec_project(a: Vector3, b: Vector3) -> Vector3:
	var b_normalized: Vector3 = b.normalized()
	return b_normalized * a.dot(b_normalized)

## Get component of vector A perpendicular to vector B
static func vec_perpendicular(a: Vector3, b: Vector3) -> Vector3:
	return a - vec_project(a, b)

## Find index of largest component (0=x, 1=y, 2=z, NO_LARGEST if all < SMALL_NUM)
static func index_largest(a: float, b: float, c: float) -> int:
	var abs_a: float = abs(a)
	var abs_b: float = abs(b)
	var abs_c: float = abs(c)
	
	if abs_a < SMALL_NUM and abs_b < SMALL_NUM and abs_c < SMALL_NUM:
		return NO_LARGEST
	
	if abs_a >= abs_b and abs_a >= abs_c:
		return 0
	elif abs_b >= abs_c:
		return 1
	else:
		return 2

## Get largest component of vector
static func vec_largest_component(v: Vector3) -> int:
	return index_largest(v.x, v.y, v.z)

# ========================================
# Matrix Operations
# ========================================

## Set matrix to identity
static func matrix_set_identity() -> Basis:
	return IDENTITY_MATRIX

## Check if matrix is identity (within epsilon)
static func matrix_is_identity(m: Basis) -> bool:
	var id: Basis = IDENTITY_MATRIX
	return (
		abs(m.x.x - id.x.x) < SMALL_NUM and abs(m.x.y - id.x.y) < SMALL_NUM and abs(m.x.z - id.x.z) < SMALL_NUM and
		abs(m.y.x - id.y.x) < SMALL_NUM and abs(m.y.y - id.y.y) < SMALL_NUM and abs(m.y.z - id.y.z) < SMALL_NUM and
		abs(m.z.x - id.z.x) < SMALL_NUM and abs(m.z.y - id.z.y) < SMALL_NUM and abs(m.z.z - id.z.z) < SMALL_NUM
	)

## Multiply two matrices: result = m1 * m2
static func matrix_multiply(m1: Basis, m2: Basis) -> Basis:
	return m1 * m2

## Transform vector by matrix
static func matrix_transform_vec(m: Basis, v: Vector3) -> Vector3:
	return m * v

## Transform vector by transpose of matrix
static func matrix_transform_vec_transpose(m: Basis, v: Vector3) -> Vector3:
	return m.transposed() * v

## Get matrix transpose
static func matrix_transpose(m: Basis) -> Basis:
	return m.transposed()

## Get matrix determinant
static func matrix_determinant(m: Basis) -> float:
	return m.determinant()

## Invert matrix (returns null basis if not invertible)
static func matrix_invert(m: Basis) -> Basis:
	var det: float = m.determinant()
	if abs(det) < SMALLER_NUM:
		push_error("WCSVectorMath: Matrix is not invertible (determinant near zero)")
		return IDENTITY_MATRIX
	return m.inverse()

## Create rotation matrix from Euler angles (pitch, bank, heading)
static func matrix_from_angles(angles: Vector3) -> Basis:
	# Convert from WCS angle convention (pitch, bank, heading) to Godot (X, Z, Y)
	return Basis.from_euler(Vector3(angles.x, angles.z, angles.y))

## Extract Euler angles from rotation matrix
static func matrix_to_angles(m: Basis) -> Vector3:
	var euler: Vector3 = m.get_euler()
	# Convert from Godot convention (X, Y, Z) to WCS (pitch, bank, heading)
	return Vector3(euler.x, euler.z, euler.y)

## Create matrix from forward and up vectors
static func matrix_from_vectors(forward: Vector3, up: Vector3) -> Basis:
	var fwd: Vector3 = forward.normalized()
	var right: Vector3 = up.cross(fwd).normalized()
	var actual_up: Vector3 = fwd.cross(right).normalized()
	
	return Basis(right, actual_up, fwd)

## Extract forward vector from matrix
static func matrix_get_forward(m: Basis) -> Vector3:
	return m.z

## Extract up vector from matrix
static func matrix_get_up(m: Basis) -> Vector3:
	return m.y

## Extract right vector from matrix
static func matrix_get_right(m: Basis) -> Vector3:
	return m.x

## Create look-at matrix
static func matrix_look_at(from: Vector3, to: Vector3, up: Vector3 = Vector3.UP) -> Basis:
	var forward: Vector3 = (to - from).normalized()
	return matrix_from_vectors(forward, up)

# ========================================
# Angle Operations
# ========================================

## Convert degrees to radians
static func deg_to_rad(degrees: float) -> float:
	return degrees * CONVERT_RADIANS

## Convert radians to degrees  
static func rad_to_deg(radians: float) -> float:
	return radians / CONVERT_RADIANS

## Normalize angle to [0, 2*PI]
static func angle_normalize_2pi(angle: float) -> float:
	var result: float = fmod(angle, TAU)
	return result if result >= 0.0 else result + TAU

## Normalize angle to [-PI, PI]
static func angle_normalize_pi(angle: float) -> float:
	var result: float = angle_normalize_2pi(angle)
	return result if result <= PI else result - TAU

## Get shortest angular distance between two angles
static func angle_distance(angle1: float, angle2: float) -> float:
	var diff: float = angle2 - angle1
	return angle_normalize_pi(diff)

## Linear interpolation between angles (handles wrap-around)
static func angle_lerp(angle1: float, angle2: float, t: float) -> float:
	var diff: float = angle_distance(angle1, angle2)
	return angle_normalize_2pi(angle1 + diff * t)

# ========================================
# WCS Compatibility Functions
# ========================================

## Convert WCS vector to Godot Vector3 (direct copy, coordinates match)
static func wcs_vec_to_godot(wcs_vec: WCSTypes.WCSVector3D) -> Vector3:
	return Vector3(wcs_vec.x, wcs_vec.y, wcs_vec.z)

## Convert Godot Vector3 to WCS vector
static func godot_vec_to_wcs(godot_vec: Vector3) -> WCSTypes.WCSVector3D:
	return WCSTypes.WCSVector3D.new(godot_vec.x, godot_vec.y, godot_vec.z)

## Convert WCS matrix to Godot Basis
static func wcs_matrix_to_godot(wcs_matrix: WCSTypes.WCSMatrix) -> Basis:
	return Basis(
		wcs_vec_to_godot(wcs_matrix.right_vector),
		wcs_vec_to_godot(wcs_matrix.up_vector),
		wcs_vec_to_godot(wcs_matrix.forward_vector)
	)

## Convert Godot Basis to WCS matrix
static func godot_matrix_to_wcs(godot_basis: Basis) -> WCSTypes.WCSMatrix:
	var wcs_matrix: WCSTypes.WCSMatrix = WCSTypes.WCSMatrix.new()
	wcs_matrix.right_vector = godot_vec_to_wcs(godot_basis.x)
	wcs_matrix.up_vector = godot_vec_to_wcs(godot_basis.y)
	wcs_matrix.forward_vector = godot_vec_to_wcs(godot_basis.z)
	return wcs_matrix

# ========================================
# Specialized Physics Operations
# ========================================

## Calculate relative velocity between two objects
static func calc_relative_velocity(vel1: Vector3, vel2: Vector3) -> Vector3:
	return vel1 - vel2

## Calculate intercept point for projectile
static func calc_intercept_point(target_pos: Vector3, target_vel: Vector3, 
								shooter_pos: Vector3, projectile_speed: float) -> Vector3:
	var relative_pos: Vector3 = target_pos - shooter_pos
	var relative_speed_sq: float = target_vel.length_squared()
	var proj_speed_sq: float = projectile_speed * projectile_speed
	
	# Solve quadratic equation for intercept time
	var a: float = relative_speed_sq - proj_speed_sq
	var b: float = 2.0 * relative_pos.dot(target_vel)
	var c: float = relative_pos.length_squared()
	
	var discriminant: float = b * b - 4.0 * a * c
	
	if discriminant < 0.0 or abs(a) < SMALL_NUM:
		# No intercept possible, return current target position
		return target_pos
	
	var t1: float = (-b - sqrt(discriminant)) / (2.0 * a)
	var t2: float = (-b + sqrt(discriminant)) / (2.0 * a)
	
	# Use the positive, smaller time
	var t: float = t1 if t1 > 0.0 and (t2 <= 0.0 or t1 < t2) else t2
	
	if t <= 0.0:
		return target_pos
	
	return target_pos + target_vel * t

## Calculate bank angle for coordinated turn
static func calc_coordinated_bank(turn_rate: float, forward_speed: float, gravity: float = 0.0) -> float:
	if abs(forward_speed) < SMALL_NUM:
		return 0.0
	
	var centripetal_accel: float = turn_rate * forward_speed
	return atan2(centripetal_accel, gravity) if gravity > SMALL_NUM else 0.0

## Calculate minimum turning radius
static func calc_min_turn_radius(max_turn_rate: float, speed: float) -> float:
	if abs(max_turn_rate) < SMALL_NUM:
		return FLT_MAX
	return speed / max_turn_rate

# ========================================
# Debug and Validation Functions
# ========================================

## Validate vector (check for NaN, infinity)
static func validate_vector(v: Vector3, name: String = "vector") -> bool:
	if is_vec_nan(v):
		push_error("WCSVectorMath: %s contains NaN values: %s" % [name, v])
		return false
	
	if is_inf(v.x) or is_inf(v.y) or is_inf(v.z):
		push_error("WCSVectorMath: %s contains infinite values: %s" % [name, v])
		return false
	
	return true

## Validate matrix (check for NaN, infinity, orthogonality)
static func validate_matrix(m: Basis, name: String = "matrix") -> bool:
	if not validate_vector(m.x, name + ".x") or \
	   not validate_vector(m.y, name + ".y") or \
	   not validate_vector(m.z, name + ".z"):
		return false
	
	# Check if matrix is orthogonal (dot products should be near zero)
	var xy_dot: float = abs(m.x.dot(m.y))
	var xz_dot: float = abs(m.x.dot(m.z))
	var yz_dot: float = abs(m.y.dot(m.z))
	
	if xy_dot > 0.1 or xz_dot > 0.1 or yz_dot > 0.1:
		push_warning("WCSVectorMath: %s is not orthogonal (dots: %.3f, %.3f, %.3f)" % 
					 [name, xy_dot, xz_dot, yz_dot])
	
	return true

## Get vector debug string
static func vec_to_string(v: Vector3, precision: int = 3) -> String:
	var format_str: String = "(%." + str(precision) + "f, %." + str(precision) + "f, %." + str(precision) + "f)"
	return format_str % [v.x, v.y, v.z]

## Get matrix debug string
static func matrix_to_string(m: Basis, precision: int = 3) -> String:
	return "Right: %s\nUp: %s\nForward: %s" % [
		vec_to_string(m.x, precision),
		vec_to_string(m.y, precision),
		vec_to_string(m.z, precision)
	]