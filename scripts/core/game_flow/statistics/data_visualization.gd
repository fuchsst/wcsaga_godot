class_name DataVisualization
extends RefCounted

## Data visualization helper for statistics analysis
## Creates chart data structures for UI consumption
## Supports multiple chart types with statistical analysis

# Chart data structures
class ChartData extends RefCounted:
	var chart_type: String = "line"  # line, bar, pie, radar
	var title: String = ""
	var x_axis_label: String = ""
	var y_axis_label: String = ""
	var data_points: Array[DataPoint] = []
	var categories: Array[String] = []
	var trend_line: TrendLine = null
	var chart_config: Dictionary = {}

class DataPoint extends RefCounted:
	var x: float = 0.0
	var y: float = 0.0
	var value: float = 0.0
	var category: String = ""
	var label: String = ""
	var color: Color = Color.WHITE

class TrendLine extends RefCounted:
	var slope: float = 0.0
	var intercept: float = 0.0
	var direction: String = "stable"  # improving, declining, stable
	var r_squared: float = 0.0  # Correlation coefficient

# Chart configuration
@export var max_data_points: int = 50
@export var use_trend_lines: bool = true
@export var auto_color_palette: bool = true

# Color palettes
var default_colors: Array[Color] = [
	Color(0.2, 0.6, 1.0),      # Blue
	Color(1.0, 0.4, 0.4),      # Red
	Color(0.4, 0.8, 0.4),      # Green
	Color(1.0, 0.8, 0.2),      # Yellow
	Color(0.8, 0.4, 1.0),      # Purple
	Color(0.2, 0.8, 0.8),      # Cyan
	Color(1.0, 0.6, 0.2),      # Orange
	Color(0.6, 0.6, 0.6)       # Gray
]

## Create mission score trend chart data
func create_score_trend_chart_data(mission_scores: Array[int], max_points: int = 20) -> ChartData:
	var chart_data: ChartData = ChartData.new()
	chart_data.chart_type = "line"
	chart_data.title = "Mission Score Trend"
	chart_data.x_axis_label = "Mission"
	chart_data.y_axis_label = "Score"
	
	# Sample data if we have too many missions
	var sampled_scores: Array = _sample_array(mission_scores, max_points)
	
	# Create data points
	chart_data.data_points = []
	for i in range(sampled_scores.size()):
		var point: DataPoint = DataPoint.new()
		point.x = float(i + 1)
		point.y = float(sampled_scores[i])
		point.label = "Mission %d" % (i + 1)
		point.color = default_colors[0]
		chart_data.data_points.append(point)
	
	# Calculate trend line if enabled
	if use_trend_lines and chart_data.data_points.size() >= 3:
		chart_data.trend_line = _calculate_trend_line(chart_data.data_points)
	
	# Chart configuration
	chart_data.chart_config = {
		"show_grid": true,
		"show_trend": use_trend_lines,
		"point_style": "circle",
		"line_width": 2.0
	}
	
	return chart_data

## Create accuracy trend chart data
func create_accuracy_trend_chart_data(accuracy_history: Array[float]) -> ChartData:
	var chart_data: ChartData = ChartData.new()
	chart_data.chart_type = "line"
	chart_data.title = "Accuracy Trend"
	chart_data.x_axis_label = "Mission"
	chart_data.y_axis_label = "Accuracy %"
	
	# Create data points
	chart_data.data_points = []
	for i in range(accuracy_history.size()):
		var point: DataPoint = DataPoint.new()
		point.x = float(i + 1)
		point.y = accuracy_history[i]
		point.label = "%.1f%%" % accuracy_history[i]
		point.color = _get_accuracy_color(accuracy_history[i])
		chart_data.data_points.append(point)
	
	# Calculate trend line
	if use_trend_lines and chart_data.data_points.size() >= 3:
		chart_data.trend_line = _calculate_trend_line(chart_data.data_points)
	
	chart_data.chart_config = {
		"y_min": 0.0,
		"y_max": 100.0,
		"show_grid": true,
		"show_trend": use_trend_lines
	}
	
	return chart_data

## Create weapon proficiency radar chart
func create_weapon_proficiency_radar_chart(weapon_stats: Dictionary) -> ChartData:
	var chart_data: ChartData = ChartData.new()
	chart_data.chart_type = "radar"
	chart_data.title = "Weapon Proficiency"
	
	chart_data.categories = []
	chart_data.data_points = []
	
	var color_index: int = 0
	for weapon_type in weapon_stats:
		var stats: Dictionary = weapon_stats[weapon_type]
		chart_data.categories.append(_format_weapon_name(weapon_type))
		
		# Calculate proficiency score (0-100)
		var proficiency: float = _calculate_weapon_proficiency_score(stats)
		
		var point: DataPoint = DataPoint.new()
		point.category = _format_weapon_name(weapon_type)
		point.value = proficiency
		point.label = "%.1f%%" % proficiency
		point.color = default_colors[color_index % default_colors.size()]
		chart_data.data_points.append(point)
		
		color_index += 1
	
	chart_data.chart_config = {
		"value_min": 0.0,
		"value_max": 100.0,
		"show_labels": true,
		"fill_alpha": 0.3
	}
	
	return chart_data

## Create achievement progress pie chart
func create_achievement_progress_chart(achievement_progress: Dictionary) -> ChartData:
	var chart_data: ChartData = ChartData.new()
	chart_data.chart_type = "pie"
	chart_data.title = "Achievement Progress by Category"
	
	var categories: Array[String] = ["Combat", "Mission", "Special", "Remaining"]
	var combat_count: int = achievement_progress.get("combat_achievements", 0)
	var mission_count: int = achievement_progress.get("mission_achievements", 0)
	var special_count: int = achievement_progress.get("special_achievements", 0)
	var total_earned: int = combat_count + mission_count + special_count
	var total_available: int = 15  # Estimated total achievements
	var remaining_count: int = max(0, total_available - total_earned)
	
	var values: Array[int] = [combat_count, mission_count, special_count, remaining_count]
	
	chart_data.data_points = []
	for i in range(categories.size()):
		if values[i] > 0:  # Only show non-zero categories
			var point: DataPoint = DataPoint.new()
			point.category = categories[i]
			point.value = float(values[i])
			point.label = "%s: %d" % [categories[i], values[i]]
			point.color = default_colors[i % default_colors.size()]
			chart_data.data_points.append(point)
	
	chart_data.chart_config = {
		"show_percentages": true,
		"show_labels": true,
		"donut_style": false
	}
	
	return chart_data

## Create performance comparison bar chart
func create_performance_comparison_chart(pilot_stats: Dictionary, benchmark_stats: Dictionary) -> ChartData:
	var chart_data: ChartData = ChartData.new()
	chart_data.chart_type = "bar"
	chart_data.title = "Performance vs Benchmark"
	chart_data.x_axis_label = "Metrics"
	chart_data.y_axis_label = "Score"
	
	var metrics: Array[String] = ["Accuracy", "Survival", "Efficiency", "Combat"]
	chart_data.categories = metrics
	chart_data.data_points = []
	
	# Create data points for pilot and benchmark
	for i in range(metrics.size()):
		var metric: String = metrics[i].to_lower()
		
		# Pilot data point
		var pilot_point: DataPoint = DataPoint.new()
		pilot_point.x = float(i)
		pilot_point.y = pilot_stats.get(metric, 0.0)
		pilot_point.category = "Pilot"
		pilot_point.label = "%.1f" % pilot_point.y
		pilot_point.color = default_colors[0]
		chart_data.data_points.append(pilot_point)
		
		# Benchmark data point
		var benchmark_point: DataPoint = DataPoint.new()
		benchmark_point.x = float(i) + 0.4  # Offset for grouped bars
		benchmark_point.y = benchmark_stats.get(metric, 0.0)
		benchmark_point.category = "Benchmark"
		benchmark_point.label = "%.1f" % benchmark_point.y
		benchmark_point.color = default_colors[1]
		chart_data.data_points.append(benchmark_point)
	
	chart_data.chart_config = {
		"grouped_bars": true,
		"show_grid": true,
		"bar_width": 0.35
	}
	
	return chart_data

## Create kill distribution pie chart
func create_kill_distribution_chart(kill_stats: Dictionary) -> ChartData:
	var chart_data: ChartData = ChartData.new()
	chart_data.chart_type = "pie"
	chart_data.title = "Kill Distribution by Target Type"
	
	chart_data.data_points = []
	var color_index: int = 0
	
	for target_type in kill_stats:
		var kill_count: int = kill_stats[target_type]
		if kill_count > 0:
			var point: DataPoint = DataPoint.new()
			point.category = _format_target_name(target_type)
			point.value = float(kill_count)
			point.label = "%s: %d" % [point.category, kill_count]
			point.color = default_colors[color_index % default_colors.size()]
			chart_data.data_points.append(point)
			color_index += 1
	
	chart_data.chart_config = {
		"show_percentages": true,
		"show_labels": true
	}
	
	return chart_data

## Create mission timeline chart
func create_mission_timeline_chart(mission_history: Array[Dictionary]) -> ChartData:
	var chart_data: ChartData = ChartData.new()
	chart_data.chart_type = "line"
	chart_data.title = "Mission Performance Timeline"
	chart_data.x_axis_label = "Date"
	chart_data.y_axis_label = "Score"
	
	chart_data.data_points = []
	for i in range(mission_history.size()):
		var mission: Dictionary = mission_history[i]
		var point: DataPoint = DataPoint.new()
		point.x = float(i)
		point.y = mission.get("score", 0.0)
		point.label = mission.get("name", "Mission %d" % (i + 1))
		point.color = _get_performance_color(mission.get("grade", "C"))
		chart_data.data_points.append(point)
	
	if use_trend_lines and chart_data.data_points.size() >= 3:
		chart_data.trend_line = _calculate_trend_line(chart_data.data_points)
	
	return chart_data

## Utility methods for data processing
func _sample_array(array: Array, max_size: int) -> Array:
	if array.size() <= max_size:
		return array
	
	var step: float = float(array.size()) / float(max_size)
	var sampled: Array = []
	
	for i in range(max_size):
		var index: int = int(i * step)
		sampled.append(array[index])
	
	return sampled

## Calculate trend line using linear regression
func _calculate_trend_line(data_points: Array[DataPoint]) -> TrendLine:
	if data_points.size() < 2:
		return null
	
	var n: int = data_points.size()
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	var sum_xy: float = 0.0
	var sum_x2: float = 0.0
	
	# Calculate sums for linear regression
	for point in data_points:
		sum_x += point.x
		sum_y += point.y
		sum_xy += point.x * point.y
		sum_x2 += point.x * point.x
	
	# Calculate slope and intercept
	var denominator: float = n * sum_x2 - sum_x * sum_x
	if abs(denominator) < 0.001:
		return null
	
	var slope: float = (n * sum_xy - sum_x * sum_y) / denominator
	var intercept: float = (sum_y - slope * sum_x) / n
	
	# Calculate R-squared for trend quality
	var y_mean: float = sum_y / n
	var ss_tot: float = 0.0
	var ss_res: float = 0.0
	
	for point in data_points:
		var predicted_y: float = slope * point.x + intercept
		ss_tot += (point.y - y_mean) * (point.y - y_mean)
		ss_res += (point.y - predicted_y) * (point.y - predicted_y)
	
	var r_squared: float = 1.0 - (ss_res / max(ss_tot, 0.001))
	
	# Create trend line
	var trend_line: TrendLine = TrendLine.new()
	trend_line.slope = slope
	trend_line.intercept = intercept
	trend_line.r_squared = max(0.0, r_squared)
	
	# Determine trend direction
	if abs(slope) < 50.0:  # Small slope threshold
		trend_line.direction = "stable"
	elif slope > 0:
		trend_line.direction = "improving"
	else:
		trend_line.direction = "declining"
	
	return trend_line

## Color calculation methods
func _get_accuracy_color(accuracy: float) -> Color:
	if accuracy >= 80.0:
		return Color.GREEN
	elif accuracy >= 60.0:
		return Color.YELLOW
	elif accuracy >= 40.0:
		return Color.ORANGE
	else:
		return Color.RED

func _get_performance_color(grade: String) -> Color:
	match grade:
		"S", "A+", "A":
			return Color.GREEN
		"A-", "B+", "B":
			return Color.YELLOW
		"B-", "C+", "C":
			return Color.ORANGE
		_:
			return Color.RED

## Data formatting methods
func _format_weapon_name(weapon_type: String) -> String:
	return weapon_type.replace("_", " ").capitalize()

func _format_target_name(target_type: String) -> String:
	return target_type.replace("_", " ").capitalize()

## Weapon proficiency calculation
func _calculate_weapon_proficiency_score(weapon_stats: Dictionary) -> float:
	var accuracy: float = weapon_stats.get("accuracy", 0.0)
	var damage_per_shot: float = weapon_stats.get("damage_per_shot", 0.0)
	var kill_ratio: float = weapon_stats.get("kill_ratio", 0.0)
	
	# Weighted average of metrics (normalize to 0-100 scale)
	var accuracy_score: float = min(100.0, accuracy)
	var damage_score: float = min(100.0, damage_per_shot * 2.0)  # Scaled assumption
	var kill_score: float = min(100.0, kill_ratio * 10.0)  # Scaled assumption
	
	return (accuracy_score * 0.5 + damage_score * 0.3 + kill_score * 0.2)

## Create multi-series line chart for trend comparison
func create_multi_trend_chart(data_series: Dictionary, title: String) -> ChartData:
	var chart_data: ChartData = ChartData.new()
	chart_data.chart_type = "line"
	chart_data.title = title
	chart_data.x_axis_label = "Mission"
	chart_data.y_axis_label = "Value"
	
	chart_data.data_points = []
	var color_index: int = 0
	
	for series_name in data_series:
		var data: Array = data_series[series_name]
		var color: Color = default_colors[color_index % default_colors.size()]
		
		for i in range(data.size()):
			var point: DataPoint = DataPoint.new()
			point.x = float(i)
			point.y = float(data[i])
			point.category = series_name
			point.label = "%s: %.1f" % [series_name, point.y]
			point.color = color
			chart_data.data_points.append(point)
		
		color_index += 1
	
	chart_data.chart_config = {
		"multi_series": true,
		"show_legend": true,
		"line_width": 2.0
	}
	
	return chart_data

## Export chart data to CSV format
func export_chart_to_csv(chart_data: ChartData) -> String:
	var csv: String = ""
	
	# Header
	match chart_data.chart_type:
		"line", "bar":
			csv += "X,Y,Label,Category\n"
			for point in chart_data.data_points:
				csv += "%.2f,%.2f,%s,%s\n" % [point.x, point.y, point.label, point.category]
		"pie", "radar":
			csv += "Category,Value,Label\n"
			for point in chart_data.data_points:
				csv += "%s,%.2f,%s\n" % [point.category, point.value, point.label]
	
	return csv

## Generate chart summary statistics
func generate_chart_statistics(chart_data: ChartData) -> Dictionary:
	var stats: Dictionary = {}
	
	if chart_data.data_points.size() == 0:
		return stats
	
	# Calculate basic statistics
	var values: Array[float] = []
	for point in chart_data.data_points:
		values.append(point.y if chart_data.chart_type in ["line", "bar"] else point.value)
	
	values.sort()
	
	stats["count"] = values.size()
	stats["min"] = values[0]
	stats["max"] = values[-1]
	stats["mean"] = _calculate_mean(values)
	stats["median"] = _calculate_median(values)
	stats["std_dev"] = _calculate_std_deviation(values)
	
	# Trend information
	if chart_data.trend_line:
		stats["trend_direction"] = chart_data.trend_line.direction
		stats["trend_slope"] = chart_data.trend_line.slope
		stats["trend_r_squared"] = chart_data.trend_line.r_squared
	
	return stats

## Statistical calculation helpers
func _calculate_mean(values: Array[float]) -> float:
	var sum: float = 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _calculate_median(values: Array[float]) -> float:
	var n: int = values.size()
	if n % 2 == 0:
		return (values[n/2 - 1] + values[n/2]) / 2.0
	else:
		return values[n/2]

func _calculate_std_deviation(values: Array[float]) -> float:
	var mean: float = _calculate_mean(values)
	var variance: float = 0.0
	
	for value in values:
		variance += (value - mean) * (value - mean)
	
	variance /= values.size()
	return sqrt(variance)