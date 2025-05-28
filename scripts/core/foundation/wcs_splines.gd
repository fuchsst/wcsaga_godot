class_name WCSSplines
extends RefCounted

## Complete WCS curve and spline system implementation.
## Provides Bezier curves, Hermite splines, and utility functions for smooth motion paths.
## Ported from spline.h/spline.cpp with full mathematical compatibility.

# Maximum number of control points (matching WCS limits)
const MAX_BEZ_PTS: int = 3
const MAX_HERM_PTS: int = 3

# ========================================
# Bezier Spline Class
# ========================================

class BezierSpline:
	"""Bezier curve implementation with variable control points."""
	
	var control_points: Array[Vector3] = []
	var num_points: int = 0
	
	func _init(points: Array[Vector3] = []) -> void:
		set_points(points)
	
	func set_points(points: Array[Vector3]) -> void:
		"""Set the control points for the Bezier curve."""
		
		if points.size() > MAX_BEZ_PTS:
			push_error("BezierSpline: Too many control points (%d > %d)" % [points.size(), MAX_BEZ_PTS])
			return
		
		control_points = points.duplicate()
		num_points = points.size()
	
	func add_point(point: Vector3) -> bool:
		"""Add a control point to the curve."""
		
		if control_points.size() >= MAX_BEZ_PTS:
			push_error("BezierSpline: Cannot add more control points (max: %d)" % MAX_BEZ_PTS)
			return false
		
		control_points.append(point)
		num_points = control_points.size()
		return true
	
	func clear_points() -> void:
		"""Clear all control points."""
		control_points.clear()
		num_points = 0
	
	func get_point(t: float) -> Vector3:
		"""Get a point on the Bezier curve. t goes from 0.0 to 1.0."""
		
		if num_points == 0:
			return Vector3.ZERO
		
		if num_points == 1:
			return control_points[0]
		
		# Clamp t to [0, 1]
		t = clampf(t, 0.0, 1.0)
		
		# Calculate using Bezier blend functions
		var result: Vector3 = Vector3.ZERO
		var n: int = num_points - 1  # Degree of curve
		
		for i in range(num_points):
			var blend: float = WCSSplines.bezier_blend(i, n, t)
			result += control_points[i] * blend
		
		return result
	
	func get_derivative(t: float) -> Vector3:
		"""Get the derivative (tangent) at parameter t."""
		
		if num_points < 2:
			return Vector3.ZERO
		
		t = clampf(t, 0.0, 1.0)
		
		# Derivative of Bezier curve
		var result: Vector3 = Vector3.ZERO
		var n: int = num_points - 1
		
		for i in range(num_points - 1):
			var diff: Vector3 = control_points[i + 1] - control_points[i]
			var blend: float = WCSSplines.bezier_blend(i, n - 1, t)
			result += diff * blend * float(n)
		
		return result
	
	func get_length_estimate(segments: int = 100) -> float:
		"""Estimate the length of the curve using line segments."""
		
		if num_points < 2:
			return 0.0
		
		var total_length: float = 0.0
		var prev_point: Vector3 = get_point(0.0)
		
		for i in range(1, segments + 1):
			var t: float = float(i) / float(segments)
			var current_point: Vector3 = get_point(t)
			total_length += prev_point.distance_to(current_point)
			prev_point = current_point
		
		return total_length
	
	func sample_uniform(num_samples: int) -> Array[Vector3]:
		"""Sample points uniformly along the curve."""
		
		var samples: Array[Vector3] = []
		
		if num_samples <= 0:
			return samples
		
		if num_samples == 1:
			samples.append(get_point(0.5))
			return samples
		
		for i in range(num_samples):
			var t: float = float(i) / float(num_samples - 1)
			samples.append(get_point(t))
		
		return samples
	
	func get_closest_point(target: Vector3, precision: int = 100) -> Dictionary:
		"""Find the closest point on the curve to the target point."""
		
		var closest_t: float = 0.0
		var closest_point: Vector3 = get_point(0.0)
		var closest_distance: float = target.distance_to(closest_point)
		
		# Sample the curve to find approximate closest point
		for i in range(precision + 1):
			var t: float = float(i) / float(precision)
			var point: Vector3 = get_point(t)
			var distance: float = target.distance_to(point)
			
			if distance < closest_distance:
				closest_distance = distance
				closest_point = point
				closest_t = t
		
		return {
			"parameter": closest_t,
			"point": closest_point,
			"distance": closest_distance
		}

# ========================================
# Hermite Spline Class
# ========================================

class HermiteSpline:
	"""Hermite curve implementation with control points and derivatives."""
	
	var control_points: Array[Vector3] = []
	var control_derivatives: Array[Vector3] = []
	var num_points: int = 0
	
	func _init(points: Array[Vector3] = [], derivatives: Array[Vector3] = []) -> void:
		set_points(points, derivatives)
	
	func set_points(points: Array[Vector3], derivatives: Array[Vector3] = []) -> void:
		"""Set control points and their derivatives (tangents)."""
		
		if points.size() > MAX_HERM_PTS:
			push_error("HermiteSpline: Too many control points (%d > %d)" % [points.size(), MAX_HERM_PTS])
			return
		
		control_points = points.duplicate()
		num_points = points.size()
		
		# Set derivatives
		if derivatives.size() == points.size():
			control_derivatives = derivatives.duplicate()
		else:
			# Generate default derivatives (tangents)
			control_derivatives.clear()
			for i in range(num_points):
				if i == 0 and num_points > 1:
					# First point: use direction to next point
					control_derivatives.append(control_points[1] - control_points[0])
				elif i == num_points - 1 and num_points > 1:
					# Last point: use direction from previous point
					control_derivatives.append(control_points[i] - control_points[i - 1])
				elif num_points > 2:
					# Middle points: use average of adjacent directions
					var dir1: Vector3 = control_points[i] - control_points[i - 1]
					var dir2: Vector3 = control_points[i + 1] - control_points[i]
					control_derivatives.append((dir1 + dir2) * 0.5)
				else:
					control_derivatives.append(Vector3.ZERO)
	
	func add_point(point: Vector3, derivative: Vector3 = Vector3.ZERO) -> bool:
		"""Add a control point with its derivative."""
		
		if control_points.size() >= MAX_HERM_PTS:
			push_error("HermiteSpline: Cannot add more control points (max: %d)" % MAX_HERM_PTS)
			return false
		
		control_points.append(point)
		control_derivatives.append(derivative)
		num_points = control_points.size()
		return true
	
	func clear_points() -> void:
		"""Clear all control points and derivatives."""
		control_points.clear()
		control_derivatives.clear()
		num_points = 0
	
	func get_point(t: float, segment: int = 0) -> Vector3:
		"""Get a point on the Hermite curve. t goes from 0.0 to 1.0 within the segment."""
		
		if num_points < 2:
			if num_points == 1:
				return control_points[0]
			return Vector3.ZERO
		
		# Ensure valid segment
		segment = clampi(segment, 0, num_points - 2)
		t = clampf(t, 0.0, 1.0)
		
		# Get segment points and derivatives
		var p0: Vector3 = control_points[segment]
		var p1: Vector3 = control_points[segment + 1]
		var d0: Vector3 = control_derivatives[segment]
		var d1: Vector3 = control_derivatives[segment + 1]
		
		# Hermite basis functions
		var t2: float = t * t
		var t3: float = t2 * t
		
		var h00: float = 2.0 * t3 - 3.0 * t2 + 1.0  # (1 + 2t)(1 - t)^2
		var h10: float = t3 - 2.0 * t2 + t           # t(1 - t)^2
		var h01: float = -2.0 * t3 + 3.0 * t2        # t^2(3 - 2t)
		var h11: float = t3 - t2                     # t^2(t - 1)
		
		# Calculate point using Hermite formula
		return p0 * h00 + d0 * h10 + p1 * h01 + d1 * h11
	
	func get_derivative(t: float, segment: int = 0) -> Vector3:
		"""Get the derivative (tangent) at parameter t within the segment."""
		
		if num_points < 2:
			return Vector3.ZERO
		
		segment = clampi(segment, 0, num_points - 2)
		t = clampf(t, 0.0, 1.0)
		
		var p0: Vector3 = control_points[segment]
		var p1: Vector3 = control_points[segment + 1]
		var d0: Vector3 = control_derivatives[segment]
		var d1: Vector3 = control_derivatives[segment + 1]
		
		# Derivative of Hermite basis functions
		var t2: float = t * t
		
		var dh00_dt: float = 6.0 * t2 - 6.0 * t
		var dh10_dt: float = 3.0 * t2 - 4.0 * t + 1.0
		var dh01_dt: float = -6.0 * t2 + 6.0 * t
		var dh11_dt: float = 3.0 * t2 - 2.0 * t
		
		return p0 * dh00_dt + d0 * dh10_dt + p1 * dh01_dt + d1 * dh11_dt
	
	func get_point_global(t: float) -> Vector3:
		"""Get a point on the entire curve. t goes from 0.0 to 1.0 across all segments."""
		
		if num_points < 2:
			if num_points == 1:
				return control_points[0]
			return Vector3.ZERO
		
		var num_segments: int = num_points - 1
		var segment_t: float = t * float(num_segments)
		var segment: int = int(segment_t)
		var local_t: float = segment_t - float(segment)
		
		# Clamp to valid range
		if segment >= num_segments:
			segment = num_segments - 1
			local_t = 1.0
		
		return get_point(local_t, segment)
	
	func get_derivative_global(t: float) -> Vector3:
		"""Get the derivative at parameter t across the entire curve."""
		
		if num_points < 2:
			return Vector3.ZERO
		
		var num_segments: int = num_points - 1
		var segment_t: float = t * float(num_segments)
		var segment: int = int(segment_t)
		var local_t: float = segment_t - float(segment)
		
		if segment >= num_segments:
			segment = num_segments - 1
			local_t = 1.0
		
		# Scale derivative by number of segments (chain rule)
		return get_derivative(local_t, segment) * float(num_segments)
	
	func auto_calculate_derivatives() -> void:
		"""Automatically calculate smooth derivatives for all control points."""
		
		if num_points < 2:
			return
		
		control_derivatives.clear()
		
		for i in range(num_points):
			var derivative: Vector3
			
			if i == 0:
				# First point: use forward difference
				derivative = control_points[1] - control_points[0]
			elif i == num_points - 1:
				# Last point: use backward difference
				derivative = control_points[i] - control_points[i - 1]
			else:
				# Middle points: use central difference
				derivative = (control_points[i + 1] - control_points[i - 1]) * 0.5
			
			control_derivatives.append(derivative)

# ========================================
# Utility Functions
# ========================================

## Calculate Bezier blend function (Bernstein polynomial)
static func bezier_blend(k: int, n: int, t: float) -> float:
	"""Calculate the Bezier blend function B(k,n)(t)."""
	
	if k < 0 or k > n:
		return 0.0
	
	var binomial_coeff: float = binomial_coefficient(n, k)
	var t_power: float = pow(t, k)
	var one_minus_t_power: float = pow(1.0 - t, n - k)
	
	return binomial_coeff * t_power * one_minus_t_power

## Calculate binomial coefficient C(n, k)
static func binomial_coefficient(n: int, k: int) -> float:
	"""Calculate binomial coefficient C(n, k) = n! / (k! * (n-k)!)."""
	
	if k < 0 or k > n:
		return 0.0
	
	if k == 0 or k == n:
		return 1.0
	
	# Use the more efficient formula: C(n,k) = C(n,k-1) * (n-k+1) / k
	var result: float = 1.0
	for i in range(k):
		result = result * float(n - i) / float(i + 1)
	
	return result

## Calculate factorial (for smaller values)
static func factorial(n: int) -> int:
	"""Calculate factorial n!. Limited to reasonable values to avoid overflow."""
	
	if n < 0:
		return 0
	
	if n <= 1:
		return 1
	
	var result: int = 1
	for i in range(2, n + 1):
		result *= i
		# Prevent overflow
		if result < 0:
			push_error("WCSSplines: Factorial overflow for n=%d" % n)
			return 0
	
	return result

## Create a smooth curve through points using Catmull-Rom splines
static func create_catmull_rom_curve(points: Array[Vector3], tension: float = 0.5) -> HermiteSpline:
	"""Create a smooth Catmull-Rom spline through the given points."""
	
	if points.size() < 2:
		push_error("WCSSplines: Need at least 2 points for Catmull-Rom curve")
		return HermiteSpline.new()
	
	var spline: HermiteSpline = HermiteSpline.new()
	var derivatives: Array[Vector3] = []
	
	for i in range(points.size()):
		var tangent: Vector3
		
		if i == 0:
			# First point
			if points.size() > 2:
				tangent = (points[2] - points[0]) * tension
			else:
				tangent = (points[1] - points[0]) * tension
		elif i == points.size() - 1:
			# Last point
			if points.size() > 2:
				tangent = (points[i] - points[i - 2]) * tension
			else:
				tangent = (points[i] - points[i - 1]) * tension
		else:
			# Middle points - use Catmull-Rom tangent
			tangent = (points[i + 1] - points[i - 1]) * tension
		
		derivatives.append(tangent)
	
	spline.set_points(points, derivatives)
	return spline

## Create a Bezier curve approximating a circle arc
static func create_circle_arc(center: Vector3, radius: float, start_angle: float, 
							 end_angle: float, up_vector: Vector3 = Vector3.UP) -> BezierSpline:
	"""Create a Bezier curve approximating a circular arc."""
	
	var angle_diff: float = end_angle - start_angle
	
	# Normalize angle difference to [-2π, 2π]
	while angle_diff > TAU:
		angle_diff -= TAU
	while angle_diff < -TAU:
		angle_diff += TAU
	
	# Use multiple segments for large arcs
	var num_segments: int = maxi(1, int(ceil(abs(angle_diff) / (PI * 0.5))))
	var segment_angle: float = angle_diff / float(num_segments)
	
	# Create control points for single segment
	var points: Array[Vector3] = []
	
	# Calculate control point weight for circular arc approximation
	var alpha: float = sin(segment_angle) * (sqrt(4.0 + 3.0 * tan(segment_angle * 0.5) * tan(segment_angle * 0.5)) - 1.0) / 3.0
	
	# Create perpendicular vectors for circle plane
	var forward: Vector3 = Vector3.FORWARD
	if abs(up_vector.dot(forward)) > 0.9:
		forward = Vector3.RIGHT
	
	var right: Vector3 = up_vector.cross(forward).normalized()
	forward = right.cross(up_vector).normalized()
	
	# Start point
	var start_pos: Vector3 = center + (right * cos(start_angle) + forward * sin(start_angle)) * radius
	points.append(start_pos)
	
	# Control point (for simple 3-point Bezier)
	var mid_angle: float = start_angle + segment_angle * 0.5
	var control_pos: Vector3 = center + (right * cos(mid_angle) + forward * sin(mid_angle)) * radius / cos(segment_angle * 0.5)
	points.append(control_pos)
	
	# End point
	var end_pos: Vector3 = center + (right * cos(end_angle) + forward * sin(end_angle)) * radius
	points.append(end_pos)
	
	var spline: BezierSpline = BezierSpline.new()
	spline.set_points(points)
	return spline

## Create a smooth spiral curve
static func create_spiral(center: Vector3, start_radius: float, end_radius: float, 
						 height: float, turns: float, points_per_turn: int = 8) -> HermiteSpline:
	"""Create a spiral curve from start_radius to end_radius with given height and turns."""
	
	var total_points: int = maxi(2, int(turns * float(points_per_turn)))
	var points: Array[Vector3] = []
	
	for i in range(total_points):
		var t: float = float(i) / float(total_points - 1)
		var angle: float = t * turns * TAU
		var radius: float = lerpf(start_radius, end_radius, t)
		var z: float = t * height
		
		var point: Vector3 = center + Vector3(
			cos(angle) * radius,
			sin(angle) * radius,
			z
		)
		
		points.append(point)
	
	return create_catmull_rom_curve(points, 0.5)

## Sample points along any curve with uniform spacing
static func sample_curve_uniform(curve_func: Callable, length_estimate: float, 
								num_samples: int) -> Array[Vector3]:
	"""Sample points along a curve with approximately uniform spacing."""
	
	if num_samples <= 0:
		return []
	
	if num_samples == 1:
		return [curve_func.call(0.5)]
	
	var samples: Array[Vector3] = []
	var target_distance: float = length_estimate / float(num_samples - 1)
	var current_t: float = 0.0
	var last_point: Vector3 = curve_func.call(0.0)
	samples.append(last_point)
	
	var accumulated_distance: float = 0.0
	var step_size: float = 1.0 / float(num_samples * 10)  # Fine step size
	
	for i in range(1, num_samples):
		while current_t < 1.0:
			current_t += step_size
			var current_point: Vector3 = curve_func.call(current_t)
			var segment_distance: float = last_point.distance_to(current_point)
			accumulated_distance += segment_distance
			
			if accumulated_distance >= target_distance:
				samples.append(current_point)
				accumulated_distance = 0.0
				last_point = current_point
				break
			
			last_point = current_point
	
	# Ensure we have the endpoint
	if samples.size() < num_samples:
		samples.append(curve_func.call(1.0))
	
	return samples

# ========================================
# Debug and Visualization
# ========================================

## Get debug information about a Bezier spline
static func get_bezier_debug_info(spline: BezierSpline) -> String:
	"""Get debug information about a Bezier spline."""
	
	var info: String = "Bezier Spline Debug:\n"
	info += "  Control Points: %d\n" % spline.num_points
	
	for i in range(spline.control_points.size()):
		info += "    P%d: %s\n" % [i, WCSVectorMath.vec_to_string(spline.control_points[i])]
	
	if spline.num_points >= 2:
		var length: float = spline.get_length_estimate()
		info += "  Estimated Length: %.2f\n" % length
	
	return info

## Get debug information about a Hermite spline
static func get_hermite_debug_info(spline: HermiteSpline) -> String:
	"""Get debug information about a Hermite spline."""
	
	var info: String = "Hermite Spline Debug:\n"
	info += "  Control Points: %d\n" % spline.num_points
	
	for i in range(spline.control_points.size()):
		info += "    P%d: %s (D: %s)\n" % [
			i, 
			WCSVectorMath.vec_to_string(spline.control_points[i]),
			WCSVectorMath.vec_to_string(spline.control_derivatives[i])
		]
	
	return info

## Validate spline data for errors
static func validate_bezier_spline(spline: BezierSpline, name: String = "bezier") -> bool:
	"""Validate Bezier spline data for common errors."""
	
	if spline.num_points != spline.control_points.size():
		push_error("WCSSplines: %s point count mismatch (%d != %d)" % [name, spline.num_points, spline.control_points.size()])
		return false
	
	for i in range(spline.control_points.size()):
		if not WCSVectorMath.validate_vector(spline.control_points[i], "%s.point[%d]" % [name, i]):
			return false
	
	return true

## Validate Hermite spline data for errors
static func validate_hermite_spline(spline: HermiteSpline, name: String = "hermite") -> bool:
	"""Validate Hermite spline data for common errors."""
	
	if spline.num_points != spline.control_points.size():
		push_error("WCSSplines: %s point count mismatch (%d != %d)" % [name, spline.num_points, spline.control_points.size()])
		return false
	
	if spline.control_points.size() != spline.control_derivatives.size():
		push_error("WCSSplines: %s derivative count mismatch (%d != %d)" % [name, spline.control_points.size(), spline.control_derivatives.size()])
		return false
	
	for i in range(spline.control_points.size()):
		if not WCSVectorMath.validate_vector(spline.control_points[i], "%s.point[%d]" % [name, i]):
			return false
		if not WCSVectorMath.validate_vector(spline.control_derivatives[i], "%s.derivative[%d]" % [name, i]):
			return false
	
	return true
