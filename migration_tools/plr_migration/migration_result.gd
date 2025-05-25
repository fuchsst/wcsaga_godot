class_name MigrationResult
extends Resource

## Result of PLR file migration operation.
## Contains success status, converted data, and detailed error/warning information.

enum ResultType {
	SUCCESS = 0,        ## Migration completed successfully
	PARTIAL_SUCCESS = 1, ## Migration completed with warnings
	FAILED = 2,         ## Migration failed
	SKIPPED = 3         ## Migration was skipped (duplicate, invalid, etc.)
}

# --- Migration Status ---
@export var result_type: ResultType = ResultType.FAILED
@export var success: bool = false           ## Whether migration succeeded
@export var source_file: String = ""       ## Path to source PLR file
@export var target_profile_path: String = "" ## Path to saved PlayerProfile

# --- Converted Data ---
@export var target_profile: PlayerProfile  ## Converted PlayerProfile resource
@export var plr_header: PLRHeader          ## Original PLR header data
@export var source_file_size: int = 0      ## Size of source file
@export var target_file_size: int = 0      ## Size of target file

# --- Migration Details ---
@export var migration_time: float = 0.0    ## Time taken for migration (seconds)
@export var data_integrity_score: float = 1.0 ## Data integrity score (0.0-1.0)
@export var features_migrated: int = 0     ## Number of features successfully migrated
@export var total_features: int = 0        ## Total number of features attempted

# --- Error and Warning Information ---
@export var errors: Array[String] = []     ## Critical errors that caused failure
@export var warnings: Array[String] = []   ## Non-critical warnings
@export var data_losses: Array[String] = [] ## Data that couldn't be migrated
@export var conversions: Array[String] = [] ## Data conversions performed

# --- File Information ---
@export var backup_created: bool = false   ## Whether backup was created
@export var backup_path: String = ""       ## Path to backup file
@export var validation_passed: bool = false ## Whether final validation passed

# --- Statistics ---
@export var statistics_migrated: Dictionary = {} ## Which statistics were migrated
@export var campaigns_migrated: Array[String] = [] ## Campaign data migrated
@export var settings_migrated: Dictionary = {}   ## Which settings were migrated

func _init() -> void:
	errors = []
	warnings = []
	data_losses = []
	conversions = []
	statistics_migrated = {}
	campaigns_migrated = []
	settings_migrated = {}

## Mark migration as successful
func mark_success(profile: PlayerProfile, migration_duration: float) -> void:
	result_type = ResultType.SUCCESS
	success = true
	target_profile = profile
	migration_time = migration_duration
	
	if warnings.size() > 0:
		result_type = ResultType.PARTIAL_SUCCESS

## Mark migration as failed
func mark_failed(error_message: String, migration_duration: float = 0.0) -> void:
	result_type = ResultType.FAILED
	success = false
	migration_time = migration_duration
	add_error(error_message)

## Mark migration as skipped
func mark_skipped(reason: String) -> void:
	result_type = ResultType.SKIPPED
	success = false
	add_warning("Migration skipped: " + reason)

## Add error message
func add_error(message: String) -> void:
	if not errors.has(message):
		errors.append(message)

## Add warning message
func add_warning(message: String) -> void:
	if not warnings.has(message):
		warnings.append(message)

## Add data loss notification
func add_data_loss(message: String) -> void:
	if not data_losses.has(message):
		data_losses.append(message)

## Add conversion notification
func add_conversion(message: String) -> void:
	if not conversions.has(message):
		conversions.append(message)

## Record feature migration
func record_feature_migration(feature_name: String, migrated: bool) -> void:
	total_features += 1
	if migrated:
		features_migrated += 1
	else:
		add_data_loss("Feature not migrated: " + feature_name)

## Record statistic migration
func record_statistic_migration(stat_name: String, original_value: Variant, converted_value: Variant) -> void:
	statistics_migrated[stat_name] = {
		"original": original_value,
		"converted": converted_value,
		"migrated": true
	}

## Record campaign migration
func record_campaign_migration(campaign_name: String, success: bool) -> void:
	if success:
		campaigns_migrated.append(campaign_name)
	else:
		add_data_loss("Campaign data not migrated: " + campaign_name)

## Record setting migration
func record_setting_migration(setting_category: String, setting_name: String, migrated: bool) -> void:
	if not settings_migrated.has(setting_category):
		settings_migrated[setting_category] = {}
	
	settings_migrated[setting_category][setting_name] = migrated
	
	if not migrated:
		add_data_loss("Setting not migrated: " + setting_category + "." + setting_name)

## Calculate migration completeness percentage
func get_migration_completeness() -> float:
	if total_features == 0:
		return 0.0
	return float(features_migrated) / float(total_features) * 100.0

## Get result type name
func get_result_type_name() -> String:
	match result_type:
		ResultType.SUCCESS: return "Success"
		ResultType.PARTIAL_SUCCESS: return "Partial Success"
		ResultType.FAILED: return "Failed"
		ResultType.SKIPPED: return "Skipped"
		_: return "Unknown"

## Get summary for display
func get_migration_summary() -> Dictionary:
	return {
		"result": get_result_type_name(),
		"source_file": source_file.get_file(),
		"pilot_name": target_profile.callsign if target_profile else "Unknown",
		"migration_time": str(migration_time) + "s",
		"completeness": str(int(get_migration_completeness())) + "%",
		"features_migrated": str(features_migrated) + "/" + str(total_features),
		"data_integrity": str(int(data_integrity_score * 100)) + "%",
		"has_errors": errors.size() > 0,
		"has_warnings": warnings.size() > 0,
		"has_data_losses": data_losses.size() > 0,
		"error_count": errors.size(),
		"warning_count": warnings.size(),
		"backup_created": backup_created
	}

## Get detailed report
func get_detailed_report() -> String:
	var report: PackedStringArray = PackedStringArray()
	
	# Header
	report.append("=== PLR Migration Report ===")
	report.append("Source File: " + source_file)
	report.append("Result: " + get_result_type_name())
	report.append("Migration Time: " + str(migration_time) + " seconds")
	report.append("Completeness: " + str(int(get_migration_completeness())) + "%")
	report.append("")
	
	# Target profile info
	if target_profile:
		report.append("--- Converted Profile ---")
		report.append("Pilot Callsign: " + target_profile.callsign)
		if target_profile.pilot_stats:
			report.append("Rank: " + str(target_profile.pilot_stats.rank))
			report.append("Score: " + str(target_profile.pilot_stats.score))
			report.append("Missions Flown: " + str(target_profile.pilot_stats.missions_flown))
		report.append("")
	
	# Features migrated
	if features_migrated > 0:
		report.append("--- Features Migrated ---")
		report.append("Successfully migrated: " + str(features_migrated) + "/" + str(total_features))
		
		if statistics_migrated.size() > 0:
			report.append("Statistics: " + str(statistics_migrated.size()) + " items")
		
		if campaigns_migrated.size() > 0:
			report.append("Campaigns: " + str(campaigns_migrated.size()) + " campaigns")
			for campaign in campaigns_migrated:
				report.append("  - " + campaign)
		
		if settings_migrated.size() > 0:
			report.append("Settings: " + str(settings_migrated.size()) + " categories")
		
		report.append("")
	
	# Conversions performed
	if conversions.size() > 0:
		report.append("--- Data Conversions ---")
		for conversion in conversions:
			report.append("• " + conversion)
		report.append("")
	
	# Warnings
	if warnings.size() > 0:
		report.append("--- Warnings ---")
		for warning in warnings:
			report.append("⚠ " + warning)
		report.append("")
	
	# Data losses
	if data_losses.size() > 0:
		report.append("--- Data Losses ---")
		for loss in data_losses:
			report.append("⚠ " + loss)
		report.append("")
	
	# Errors
	if errors.size() > 0:
		report.append("--- Errors ---")
		for error in errors:
			report.append("✗ " + error)
		report.append("")
	
	# Footer
	if backup_created:
		report.append("Original file backed up to: " + backup_path)
	
	report.append("=== End Report ===")
	
	return "\n".join(report)

## Export to dictionary for serialization
func export_to_dictionary() -> Dictionary:
	var profile_data: Dictionary = {}
	if target_profile:
		profile_data = target_profile.export_to_json()
	
	var header_data: Dictionary = {}
	if plr_header:
		header_data = plr_header.export_to_dictionary()
	
	return {
		"metadata": {
			"result_type": result_type,
			"success": success,
			"source_file": source_file,
			"target_profile_path": target_profile_path,
			"migration_time": migration_time,
			"timestamp": Time.get_unix_time_from_system()
		},
		"files": {
			"source_file_size": source_file_size,
			"target_file_size": target_file_size,
			"backup_created": backup_created,
			"backup_path": backup_path
		},
		"quality": {
			"data_integrity_score": data_integrity_score,
			"features_migrated": features_migrated,
			"total_features": total_features,
			"validation_passed": validation_passed
		},
		"messages": {
			"errors": errors,
			"warnings": warnings,
			"data_losses": data_losses,
			"conversions": conversions
		},
		"data": {
			"statistics_migrated": statistics_migrated,
			"campaigns_migrated": campaigns_migrated,
			"settings_migrated": settings_migrated
		},
		"plr_header": header_data,
		"target_profile": profile_data
	}

## Import from dictionary
func import_from_dictionary(data: Dictionary) -> bool:
	if not data.has("metadata"):
		return false
	
	var metadata: Dictionary = data.metadata
	result_type = metadata.get("result_type", ResultType.FAILED)
	success = metadata.get("success", false)
	source_file = metadata.get("source_file", "")
	target_profile_path = metadata.get("target_profile_path", "")
	migration_time = metadata.get("migration_time", 0.0)
	
	if data.has("files"):
		var files: Dictionary = data.files
		source_file_size = files.get("source_file_size", 0)
		target_file_size = files.get("target_file_size", 0)
		backup_created = files.get("backup_created", false)
		backup_path = files.get("backup_path", "")
	
	if data.has("quality"):
		var quality: Dictionary = data.quality
		data_integrity_score = quality.get("data_integrity_score", 1.0)
		features_migrated = quality.get("features_migrated", 0)
		total_features = quality.get("total_features", 0)
		validation_passed = quality.get("validation_passed", false)
	
	if data.has("messages"):
		var messages: Dictionary = data.messages
		errors = messages.get("errors", [])
		warnings = messages.get("warnings", [])
		data_losses = messages.get("data_losses", [])
		conversions = messages.get("conversions", [])
	
	if data.has("data"):
		var migration_data: Dictionary = data.data
		statistics_migrated = migration_data.get("statistics_migrated", {})
		campaigns_migrated = migration_data.get("campaigns_migrated", [])
		settings_migrated = migration_data.get("settings_migrated", {})
	
	# Note: PLR header and target profile would need special handling
	# for full deserialization if needed
	
	return true

## Check if migration should be considered successful
func is_acceptable_result() -> bool:
	return result_type == ResultType.SUCCESS or result_type == ResultType.PARTIAL_SUCCESS

## Get migration quality rating
func get_quality_rating() -> String:
	var completeness: float = get_migration_completeness()
	var integrity: float = data_integrity_score * 100.0
	
	if completeness >= 90.0 and integrity >= 95.0:
		return "Excellent"
	elif completeness >= 75.0 and integrity >= 85.0:
		return "Good"
	elif completeness >= 50.0 and integrity >= 70.0:
		return "Fair"
	else:
		return "Poor"

## Create a successful migration result
static func create_success_result(source: String, profile: PlayerProfile, duration: float) -> MigrationResult:
	var result: MigrationResult = MigrationResult.new()
	result.source_file = source
	result.mark_success(profile, duration)
	return result

## Create a failed migration result
static func create_failure_result(source: String, error: String, duration: float = 0.0) -> MigrationResult:
	var result: MigrationResult = MigrationResult.new()
	result.source_file = source
	result.mark_failed(error, duration)
	return result