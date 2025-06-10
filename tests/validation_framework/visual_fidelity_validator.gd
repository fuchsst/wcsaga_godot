@tool
extends RefCounted

## Visual Fidelity Validator
## DM-012 - Validation and Testing Framework
##
## Compares visual fidelity between original WCS and converted Godot assets
## with automated image comparison and quality assessment.
##
## Author: Dev (GDScript Developer)  
## Date: January 30, 2025
## Story: DM-012 - Validation and Testing Framework
## Epic: EPIC-003 - Data Migration & Conversion Tools

class_name VisualFidelityValidator

signal validation_progress(percentage: float, current_task: String)
signal visual_issue_detected(asset_path: String, issue_description: String)

# Visual quality thresholds based on conversion requirements
const MINIMUM_SIMILARITY_SCORE: float = 0.95
const MAXIMUM_PIXEL_DIFFERENCE_PERCENT: float = 5.0
const STRUCTURAL_SIMILARITY_THRESHOLD: float = 0.90

enum ComparisonMethod {
	PIXEL_LEVEL,
	HISTOGRAM,
	STRUCTURAL_SIMILARITY,
	PERCEPTUAL_HASH
}

func validate_visual_fidelity(source_directory: String, target_directory: String) -> Array:
	"""
	AC3: Validate visual fidelity between original and converted assets.
	
	Args:
		source_directory: Directory containing original WCS assets  
		target_directory: Directory containing converted Godot assets
		
	Returns:
		Array of visual fidelity validation results
	"""
	print("Validating visual fidelity between source and target assets")
	
	var fidelity_results: Array = []
	
	if not DirAccess.dir_exists_absolute(source_directory):
		print("WARNING: Source directory does not exist: ", source_directory)
		return fidelity_results
	
	if not DirAccess.dir_exists_absolute(target_directory):
		print("WARNING: Target directory does not exist: ", target_directory)
		return fidelity_results
	
	# Find visual asset pairs for comparison
	var visual_pairs: Array = _find_visual_asset_pairs(source_directory, target_directory)
	print("Found ", visual_pairs.size(), " visual asset pairs to compare")
	
	var progress_step: float = 100.0 / float(visual_pairs.size()) if visual_pairs.size() > 0 else 100.0
	var current_progress: float = 0.0
	
	# Compare each visual asset pair
	for i in range(visual_pairs.size()):
		var pair: Dictionary = visual_pairs[i]
		var original_path: String = pair["original"]
		var converted_path: String = pair["converted"]
		
		validation_progress.emit(current_progress, "Comparing " + original_path.get_file())
		
		var fidelity_result: Dictionary = _compare_visual_asset_fidelity(original_path, converted_path)
		fidelity_results.append(fidelity_result)
		
		current_progress += progress_step
	
	validation_progress.emit(100.0, "Visual fidelity validation completed")
	return fidelity_results

func _find_visual_asset_pairs(source_directory: String, target_directory: String) -> Array:
	"""Find pairs of original and converted visual assets"""
	var visual_pairs: Array = []
	
	# Texture conversions: PCX/TGA/DDS -> PNG
	_find_texture_pairs(source_directory, target_directory, visual_pairs)
	
	# Model screenshots: POF -> GLB (if screenshots available)
	_find_model_screenshot_pairs(source_directory, target_directory, visual_pairs)
	
	# Interface graphics conversions
	_find_interface_graphics_pairs(source_directory, target_directory, visual_pairs)
	
	return visual_pairs

func _find_texture_pairs(source_dir: String, target_dir: String, pairs: Array) -> void:
	"""Find texture conversion pairs for visual comparison"""
	var wcs_texture_extensions: Array[String] = ["pcx", "tga", "dds"]
	
	for ext in wcs_texture_extensions:
		var texture_files: Array[String] = []
		_scan_files_with_extension(source_dir, ext, texture_files)
		
		for texture_file in texture_files:
			var texture_name: String = texture_file.get_file().get_basename()
			var converted_png: String = target_dir + "/textures/" + texture_name + ".png"
			var converted_jpg: String = target_dir + "/textures/" + texture_name + ".jpg"
			
			# Check for PNG conversion first, then JPG
			if FileAccess.file_exists(converted_png):
				pairs.append({
					"original": texture_file,
					"converted": converted_png,
					"comparison_type": "texture_conversion",
					"original_format": ext,
					"converted_format": "png"
				})
			elif FileAccess.file_exists(converted_jpg):
				pairs.append({
					"original": texture_file,
					"converted": converted_jpg,
					"comparison_type": "texture_conversion",
					"original_format": ext,
					"converted_format": "jpg"
				})

func _find_model_screenshot_pairs(source_dir: String, target_dir: String, pairs: Array) -> void:
	"""Find model screenshot pairs for visual comparison"""
	# This would require generating screenshots of POF models vs GLB models
	# For now, we'll look for any existing comparison screenshots
	var screenshot_dir: String = target_dir + "/validation_screenshots"
	
	if DirAccess.dir_exists_absolute(screenshot_dir):
		var pof_files: Array[String] = []
		_scan_files_with_extension(source_dir, "pof", pof_files)
		
		for pof_file in pof_files:
			var model_name: String = pof_file.get_file().get_basename()
			var original_screenshot: String = screenshot_dir + "/" + model_name + "_original.png"
			var converted_screenshot: String = screenshot_dir + "/" + model_name + "_converted.png"
			
			if FileAccess.file_exists(original_screenshot) and FileAccess.file_exists(converted_screenshot):
				pairs.append({
					"original": original_screenshot,
					"converted": converted_screenshot,
					"comparison_type": "model_screenshot",
					"model_name": model_name
				})

func _find_interface_graphics_pairs(source_dir: String, target_dir: String, pairs: Array) -> void:
	"""Find interface graphics pairs for visual comparison"""
	# Look for UI graphics in common WCS locations
	var ui_directories: Array[String] = ["interface", "ui", "hud", "2_interface"]
	
	for ui_dir in ui_directories:
		var ui_path: String = source_dir + "/" + ui_dir
		if DirAccess.dir_exists_absolute(ui_path):
			var ui_files: Array[String] = []
			_scan_files_with_extension(ui_path, "pcx", ui_files)
			_scan_files_with_extension(ui_path, "tga", ui_files)
			
			for ui_file in ui_files:
				var ui_name: String = ui_file.get_file().get_basename()
				var converted_ui: String = target_dir + "/interface/" + ui_name + ".png"
				
				if FileAccess.file_exists(converted_ui):
					pairs.append({
						"original": ui_file,
						"converted": converted_ui,
						"comparison_type": "interface_graphics",
						"category": "ui"
					})

func _scan_files_with_extension(directory: String, extension: String, file_list: Array[String]) -> void:
	"""Recursively scan directory for files with specific extension"""
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_files_with_extension(full_path, extension, file_list)
		elif not dir.current_is_dir() and file_name.get_extension().to_lower() == extension:
			file_list.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _compare_visual_asset_fidelity(original_path: String, converted_path: String) -> Dictionary:
	"""Compare visual fidelity between original and converted assets"""
	var result: Dictionary = {
		"original_path": original_path,
		"converted_path": converted_path,
		"comparison_type": "",
		"similarity_score": 0.0,
		"pixel_difference_count": 0,
		"pixel_difference_percent": 0.0,
		"structural_similarity_index": 0.0,
		"color_histogram_difference": 0.0,
		"perceptual_hash_distance": 0,
		"visual_artifacts_detected": [],
		"acceptable_quality": false,
		"comparison_methods_used": [],
		"metadata": {},
		"validation_issues": [],
		"validation_warnings": []
	}
	
	try:
		# Load original image
		var original_image: Image = _load_image_from_path(original_path)
		if original_image == null:
			result["validation_issues"].append("Cannot load original image: " + original_path)
			return result
		
		# Load converted image
		var converted_image: Image = Image.new()
		var load_result: Error = converted_image.load(converted_path)
		if load_result != OK:
			result["validation_issues"].append("Cannot load converted image: " + converted_path)
			return result
		
		# Store image metadata
		result["metadata"]["original_size"] = Vector2(original_image.get_width(), original_image.get_height())
		result["metadata"]["converted_size"] = Vector2(converted_image.get_width(), converted_image.get_height())
		result["metadata"]["original_format"] = original_path.get_extension().to_lower()
		result["metadata"]["converted_format"] = converted_path.get_extension().to_lower()
		
		# Resize images if necessary for comparison
		if original_image.get_size() != converted_image.get_size():
			result["validation_warnings"].append("Image size mismatch - resizing for comparison")
			converted_image.resize(original_image.get_width(), original_image.get_height(), Image.INTERPOLATE_LANCZOS)
		
		# Perform different comparison methods
		_compare_pixel_level(original_image, converted_image, result)
		_compare_color_histograms(original_image, converted_image, result)
		_compare_structural_similarity(original_image, converted_image, result)
		_calculate_perceptual_hash_distance(original_image, converted_image, result)
		
		# Calculate overall similarity score
		_calculate_overall_similarity_score(result)
		
		# Detect visual artifacts
		_detect_visual_artifacts(original_image, converted_image, result)
		
		# Determine if quality is acceptable
		result["acceptable_quality"] = result["similarity_score"] >= MINIMUM_SIMILARITY_SCORE
		
		# Emit issues if quality is unacceptable
		if not result["acceptable_quality"]:
			visual_issue_detected.emit(original_path, "Visual fidelity below threshold: " + str(result["similarity_score"]))
		
	except Exception as e:
		result["validation_issues"].append("Visual comparison error: " + str(e))
	
	return result

func _load_image_from_path(image_path: String) -> Image:
	"""Load image from various WCS formats"""
	var extension: String = image_path.get_extension().to_lower()
	
	match extension:
		"png", "jpg", "jpeg":
			# Standard formats - load directly
			var image: Image = Image.new()
			if image.load(image_path) == OK:
				return image
		
		"pcx":
			# PCX format - attempt conversion or use placeholder
			return _load_pcx_image(image_path)
		
		"tga":
			# TGA format - attempt conversion or use placeholder
			return _load_tga_image(image_path)
		
		"dds":
			# DDS format - attempt conversion or use placeholder
			return _load_dds_image(image_path)
	
	return null

func _load_pcx_image(pcx_path: String) -> Image:
	"""Load PCX image (simplified implementation)"""
	# For a full implementation, this would parse PCX format
	# For now, create a placeholder or attempt external conversion
	print("WARNING: PCX format not fully supported, using placeholder")
	
	# Create a simple placeholder image
	var placeholder: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	placeholder.fill(Color.MAGENTA)  # Magenta to indicate placeholder
	return placeholder

func _load_tga_image(tga_path: String) -> Image:
	"""Load TGA image (simplified implementation)"""
	# For a full implementation, this would parse TGA format
	print("WARNING: TGA format not fully supported, using placeholder")
	
	var placeholder: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	placeholder.fill(Color.CYAN)  # Cyan to indicate placeholder
	return placeholder

func _load_dds_image(dds_path: String) -> Image:
	"""Load DDS image (simplified implementation)"""
	# For a full implementation, this would parse DDS format
	print("WARNING: DDS format not fully supported, using placeholder")
	
	var placeholder: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	placeholder.fill(Color.YELLOW)  # Yellow to indicate placeholder
	return placeholder

func _compare_pixel_level(original: Image, converted: Image, result: Dictionary) -> void:
	"""Compare images at pixel level"""
	result["comparison_methods_used"].append("pixel_level")
	
	var width: int = original.get_width()
	var height: int = original.get_height()
	var total_pixels: int = width * height
	var different_pixels: int = 0
	
	# Convert to RGB8 for consistent comparison
	original.convert(Image.FORMAT_RGB8)
	converted.convert(Image.FORMAT_RGB8)
	
	# Compare pixel by pixel
	for y in range(height):
		for x in range(width):
			var original_color: Color = original.get_pixel(x, y)
			var converted_color: Color = converted.get_pixel(x, y)
			
			# Check if colors are significantly different
			var color_distance: float = original_color.distance_to(converted_color)
			if color_distance > 0.1:  # Threshold for "different" pixels
				different_pixels += 1
	
	result["pixel_difference_count"] = different_pixels
	result["pixel_difference_percent"] = (float(different_pixels) / float(total_pixels)) * 100.0
	
	# Calculate pixel-level similarity
	var pixel_similarity: float = 1.0 - (float(different_pixels) / float(total_pixels))
	result["metadata"]["pixel_level_similarity"] = pixel_similarity

func _compare_color_histograms(original: Image, converted: Image, result: Dictionary) -> void:
	"""Compare color histograms of images"""
	result["comparison_methods_used"].append("color_histogram")
	
	var original_histogram: Dictionary = _calculate_color_histogram(original)
	var converted_histogram: Dictionary = _calculate_color_histogram(converted)
	
	# Calculate histogram difference
	var total_difference: float = 0.0
	var total_bins: int = 0
	
	# Compare RGB histograms
	for channel in ["r", "g", "b"]:
		var original_channel: Array = original_histogram[channel]
		var converted_channel: Array = converted_histogram[channel]
		
		for i in range(256):
			var diff: float = abs(original_channel[i] - converted_channel[i])
			total_difference += diff
			total_bins += 1
	
	# Normalize difference
	var normalized_difference: float = total_difference / float(total_bins)
	result["color_histogram_difference"] = normalized_difference
	
	# Calculate histogram similarity
	var histogram_similarity: float = 1.0 - (normalized_difference / 255.0)
	result["metadata"]["histogram_similarity"] = histogram_similarity

func _calculate_color_histogram(image: Image) -> Dictionary:
	"""Calculate color histogram for image"""
	var histogram: Dictionary = {
		"r": [],
		"g": [],
		"b": []
	}
	
	# Initialize bins
	for channel in ["r", "g", "b"]:
		histogram[channel] = []
		for i in range(256):
			histogram[channel].append(0)
	
	# Count pixels in each bin
	image.convert(Image.FORMAT_RGB8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	
	for y in range(height):
		for x in range(width):
			var color: Color = image.get_pixel(x, y)
			var r_bin: int = int(color.r * 255)
			var g_bin: int = int(color.g * 255)
			var b_bin: int = int(color.b * 255)
			
			histogram["r"][r_bin] += 1
			histogram["g"][g_bin] += 1
			histogram["b"][b_bin] += 1
	
	return histogram

func _compare_structural_similarity(original: Image, converted: Image, result: Dictionary) -> void:
	"""Compare structural similarity between images (simplified SSIM)"""
	result["comparison_methods_used"].append("structural_similarity")
	
	# Simplified structural similarity calculation
	# In a full implementation, this would use proper SSIM algorithm
	
	# Convert to grayscale for structural analysis
	var original_gray: Image = _convert_to_grayscale(original)
	var converted_gray: Image = _convert_to_grayscale(converted)
	
	# Calculate basic structural similarity metrics
	var mean_original: float = _calculate_image_mean(original_gray)
	var mean_converted: float = _calculate_image_mean(converted_gray)
	var variance_original: float = _calculate_image_variance(original_gray, mean_original)
	var variance_converted: float = _calculate_image_variance(converted_gray, mean_converted)
	var covariance: float = _calculate_image_covariance(original_gray, converted_gray, mean_original, mean_converted)
	
	# Simplified SSIM calculation
	var c1: float = 0.01 * 0.01
	var c2: float = 0.03 * 0.03
	
	var luminance: float = (2.0 * mean_original * mean_converted + c1) / (mean_original * mean_original + mean_converted * mean_converted + c1)
	var contrast: float = (2.0 * sqrt(variance_original) * sqrt(variance_converted) + c2) / (variance_original + variance_converted + c2)
	var structure: float = (covariance + c2 / 2.0) / (sqrt(variance_original) * sqrt(variance_converted) + c2 / 2.0)
	
	var ssim: float = luminance * contrast * structure
	result["structural_similarity_index"] = ssim
	result["metadata"]["luminance_similarity"] = luminance
	result["metadata"]["contrast_similarity"] = contrast
	result["metadata"]["structure_similarity"] = structure

func _convert_to_grayscale(image: Image) -> Image:
	"""Convert image to grayscale"""
	var gray_image: Image = image.duplicate()
	gray_image.convert(Image.FORMAT_RGB8)
	
	var width: int = gray_image.get_width()
	var height: int = gray_image.get_height()
	
	for y in range(height):
		for x in range(width):
			var color: Color = gray_image.get_pixel(x, y)
			var gray_value: float = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
			gray_image.set_pixel(x, y, Color(gray_value, gray_value, gray_value))
	
	return gray_image

func _calculate_image_mean(image: Image) -> float:
	"""Calculate mean pixel value of grayscale image"""
	var total: float = 0.0
	var count: int = 0
	var width: int = image.get_width()
	var height: int = image.get_height()
	
	for y in range(height):
		for x in range(width):
			var color: Color = image.get_pixel(x, y)
			total += color.r  # Grayscale, so r = g = b
			count += 1
	
	return total / float(count)

func _calculate_image_variance(image: Image, mean_value: float) -> float:
	"""Calculate variance of pixel values"""
	var total_variance: float = 0.0
	var count: int = 0
	var width: int = image.get_width()
	var height: int = image.get_height()
	
	for y in range(height):
		for x in range(width):
			var color: Color = image.get_pixel(x, y)
			var diff: float = color.r - mean_value
			total_variance += diff * diff
			count += 1
	
	return total_variance / float(count)

func _calculate_image_covariance(image1: Image, image2: Image, mean1: float, mean2: float) -> float:
	"""Calculate covariance between two images"""
	var total_covariance: float = 0.0
	var count: int = 0
	var width: int = image1.get_width()
	var height: int = image1.get_height()
	
	for y in range(height):
		for x in range(width):
			var color1: Color = image1.get_pixel(x, y)
			var color2: Color = image2.get_pixel(x, y)
			var diff1: float = color1.r - mean1
			var diff2: float = color2.r - mean2
			total_covariance += diff1 * diff2
			count += 1
	
	return total_covariance / float(count)

func _calculate_perceptual_hash_distance(original: Image, converted: Image, result: Dictionary) -> void:
	"""Calculate perceptual hash distance (simplified implementation)"""
	result["comparison_methods_used"].append("perceptual_hash")
	
	# Simplified perceptual hash - in practice would use more sophisticated algorithms
	var original_hash: String = _calculate_simple_hash(original)
	var converted_hash: String = _calculate_simple_hash(converted)
	
	# Calculate Hamming distance
	var distance: int = 0
	var hash_length: int = min(original_hash.length(), converted_hash.length())
	
	for i in range(hash_length):
		if original_hash[i] != converted_hash[i]:
			distance += 1
	
	result["perceptual_hash_distance"] = distance
	result["metadata"]["original_hash"] = original_hash
	result["metadata"]["converted_hash"] = converted_hash

func _calculate_simple_hash(image: Image) -> String:
	"""Calculate a simple perceptual hash"""
	# Resize to small size for hash calculation
	var small_image: Image = image.duplicate()
	small_image.resize(8, 8, Image.INTERPOLATE_LANCZOS)
	small_image.convert(Image.FORMAT_RGB8)
	
	# Convert to grayscale and calculate average
	var total: float = 0.0
	var pixel_count: int = 64
	
	for y in range(8):
		for x in range(8):
			var color: Color = small_image.get_pixel(x, y)
			var gray: float = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
			total += gray
	
	var average: float = total / float(pixel_count)
	
	# Generate hash based on average
	var hash: String = ""
	for y in range(8):
		for x in range(8):
			var color: Color = small_image.get_pixel(x, y)
			var gray: float = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
			hash += "1" if gray > average else "0"
	
	return hash

func _calculate_overall_similarity_score(result: Dictionary) -> void:
	"""Calculate overall similarity score from all comparison methods"""
	var scores: Array[float] = []
	var weights: Array[float] = []
	
	# Pixel-level similarity (30% weight)
	if result["metadata"].has("pixel_level_similarity"):
		scores.append(result["metadata"]["pixel_level_similarity"])
		weights.append(0.3)
	
	# Histogram similarity (25% weight)
	if result["metadata"].has("histogram_similarity"):
		scores.append(result["metadata"]["histogram_similarity"])
		weights.append(0.25)
	
	# Structural similarity (35% weight)
	if result.has("structural_similarity_index"):
		scores.append(result["structural_similarity_index"])
		weights.append(0.35)
	
	# Perceptual hash similarity (10% weight)
	if result.has("perceptual_hash_distance"):
		var hash_similarity: float = 1.0 - (float(result["perceptual_hash_distance"]) / 64.0)  # 64 bits max
		scores.append(hash_similarity)
		weights.append(0.1)
	
	# Calculate weighted average
	var weighted_sum: float = 0.0
	var total_weight: float = 0.0
	
	for i in range(scores.size()):
		weighted_sum += scores[i] * weights[i]
		total_weight += weights[i]
	
	if total_weight > 0:
		result["similarity_score"] = weighted_sum / total_weight
	else:
		result["similarity_score"] = 0.0

func _detect_visual_artifacts(original: Image, converted: Image, result: Dictionary) -> void:
	"""Detect common visual artifacts in conversion"""
	var artifacts: Array[String] = []
	
	# Check for significant size changes
	var original_size: Vector2 = result["metadata"]["original_size"]
	var converted_size: Vector2 = result["metadata"]["converted_size"]
	
	if original_size != converted_size:
		artifacts.append("Image dimensions changed: " + str(original_size) + " -> " + str(converted_size))
	
	# Check for compression artifacts
	if result.get("pixel_difference_percent", 0.0) > MAXIMUM_PIXEL_DIFFERENCE_PERCENT:
		artifacts.append("High pixel difference detected: " + str(result["pixel_difference_percent"]) + "%")
	
	# Check for color shift
	if result.get("color_histogram_difference", 0.0) > 50.0:  # Threshold for significant color shift
		artifacts.append("Significant color shift detected")
	
	# Check for structural degradation
	if result.get("structural_similarity_index", 1.0) < STRUCTURAL_SIMILARITY_THRESHOLD:
		artifacts.append("Structural similarity below threshold: " + str(result["structural_similarity_index"]))
	
	# Check for format-specific issues
	var original_format: String = result["metadata"]["original_format"]
	var converted_format: String = result["metadata"]["converted_format"]
	
	if original_format in ["pcx", "tga", "dds"] and converted_format in ["jpg", "jpeg"]:
		if result.get("similarity_score", 0.0) < 0.9:
			artifacts.append("Possible compression artifacts from lossy conversion")
	
	result["visual_artifacts_detected"] = artifacts

# Specific comparison functions for different asset types
func compare_texture_fidelity(original_path: String, converted_path: String) -> Dictionary:
	"""Compare texture conversion fidelity"""
	var result: Dictionary = _compare_visual_asset_fidelity(original_path, converted_path)
	result["comparison_type"] = "texture_conversion"
	return result

func compare_model_visual_fidelity(pof_path: String, glb_path: String) -> Dictionary:
	"""Compare 3D model visual fidelity (requires screenshots)"""
	var result: Dictionary = {
		"original_path": pof_path,
		"converted_path": glb_path,
		"comparison_type": "model_visual",
		"visual_similarity": 0.0,
		"structural_changes": [],
		"material_differences": [],
		"comparison_available": false
	}
	
	# Check if screenshots are available for comparison
	var screenshot_dir: String = glb_path.get_base_dir() + "/validation_screenshots"
	var model_name: String = pof_path.get_file().get_basename()
	var original_screenshot: String = screenshot_dir + "/" + model_name + "_original.png"
	var converted_screenshot: String = screenshot_dir + "/" + model_name + "_converted.png"
	
	if FileAccess.file_exists(original_screenshot) and FileAccess.file_exists(converted_screenshot):
		var screenshot_comparison: Dictionary = _compare_visual_asset_fidelity(original_screenshot, converted_screenshot)
		result["visual_similarity"] = screenshot_comparison["similarity_score"]
		result["comparison_available"] = true
	else:
		result["structural_changes"].append("No screenshots available for visual comparison")
	
	return result

# Public interface functions
func generate_model_screenshots(pof_path: String, glb_path: String, output_dir: String) -> bool:
	"""Generate screenshots of POF and GLB models for comparison"""
	# This would require integration with rendering system
	# For now, return placeholder
	print("Model screenshot generation not implemented yet")
	return false

func batch_compare_textures(texture_pairs: Array) -> Array:
	"""Batch compare multiple texture pairs"""
	var results: Array = []
	var total_pairs: int = texture_pairs.size()
	
	for i in range(total_pairs):
		var pair: Dictionary = texture_pairs[i]
		validation_progress.emit(float(i) / float(total_pairs) * 100.0, "Comparing texture " + str(i + 1))
		
		var comparison_result: Dictionary = compare_texture_fidelity(pair["original"], pair["converted"])
		results.append(comparison_result)
	
	return results

func analyze_visual_quality_trends(fidelity_results: Array) -> Dictionary:
	"""Analyze visual quality trends across multiple comparisons"""
	var analysis: Dictionary = {
		"total_comparisons": fidelity_results.size(),
		"average_similarity": 0.0,
		"quality_distribution": {},
		"common_artifacts": {},
		"format_specific_issues": {}
	}
	
	if fidelity_results.is_empty():
		return analysis
	
	# Calculate average similarity
	var total_similarity: float = 0.0
	var quality_buckets: Dictionary = {"excellent": 0, "good": 0, "fair": 0, "poor": 0}
	var artifact_counts: Dictionary = {}
	
	for result in fidelity_results:
		var similarity: float = result.get("similarity_score", 0.0)
		total_similarity += similarity
		
		# Categorize quality
		if similarity >= 0.95:
			quality_buckets["excellent"] += 1
		elif similarity >= 0.85:
			quality_buckets["good"] += 1
		elif similarity >= 0.70:
			quality_buckets["fair"] += 1
		else:
			quality_buckets["poor"] += 1
		
		# Count artifacts
		var artifacts: Array = result.get("visual_artifacts_detected", [])
		for artifact in artifacts:
			artifact_counts[artifact] = artifact_counts.get(artifact, 0) + 1
	
	analysis["average_similarity"] = total_similarity / float(fidelity_results.size())
	analysis["quality_distribution"] = quality_buckets
	analysis["common_artifacts"] = artifact_counts
	
	return analysis