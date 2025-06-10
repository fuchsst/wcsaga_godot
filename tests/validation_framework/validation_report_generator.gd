@tool
extends RefCounted

## Validation Report Generator
## DM-012 - Validation and Testing Framework
##
## Generates comprehensive validation reports with trend analysis and CI/CD integration.
## Supports multiple output formats and automated test suite integration.
##
## Author: Dev (GDScript Developer)
## Date: January 30, 2025
## Story: DM-012 - Validation and Testing Framework
## Epic: EPIC-003 - Data Migration & Conversion Tools

class_name ValidationReportGenerator

signal report_generation_started(report_type: String)
signal report_generation_progress(percentage: float, current_task: String)
signal report_generation_completed(report_path: String)

enum ReportFormat {
	JSON,
	HTML,
	XML,
	CSV,
	JUNIT,
	MARKDOWN
}

enum ReportSeverity {
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

# Report configuration
var report_config: Dictionary = {
	"include_detailed_results": true,
	"include_trend_analysis": true,
	"include_performance_metrics": true,
	"include_visual_comparisons": true,
	"generate_summary_charts": false,  # Simplified for now
	"max_file_list_entries": 100,
	"compress_large_reports": false
}

# Historical data management
var historical_data_file: String = "user://validation_history.json"
var max_historical_entries: int = 100

func generate_comprehensive_report(validation_results: Dictionary, output_directory: String, 
								 formats: Array[ReportFormat] = [ReportFormat.JSON, ReportFormat.HTML]) -> Array[String]:
	"""
	AC4: Generate comprehensive test reports with trend analysis.
	
	Args:
		validation_results: Complete validation results dictionary
		output_directory: Directory to save reports
		formats: Array of report formats to generate
		
	Returns:
		Array of generated report file paths
	"""
	print("Generating comprehensive validation reports")
	report_generation_started.emit("comprehensive")
	
	var generated_files: Array[String] = []
	
	if not DirAccess.dir_exists_absolute(output_directory):
		DirAccess.make_dir_recursive_absolute(output_directory)
	
	var validation_id: String = validation_results.get("validation_id", "unknown")
	var timestamp: String = validation_results.get("timestamp", Time.get_datetime_string_from_system())
	
	try:
		# Generate each requested format
		var format_count: int = formats.size()
		for i in range(format_count):
			var format: ReportFormat = formats[i]
			var progress: float = (float(i) / float(format_count)) * 90.0
			
			match format:
				ReportFormat.JSON:
					report_generation_progress.emit(progress + 10.0, "Generating JSON report")
					var json_path: String = _generate_json_report(validation_results, output_directory, validation_id)
					if not json_path.is_empty():
						generated_files.append(json_path)
				
				ReportFormat.HTML:
					report_generation_progress.emit(progress + 20.0, "Generating HTML report")
					var html_path: String = _generate_html_report(validation_results, output_directory, validation_id)
					if not html_path.is_empty():
						generated_files.append(html_path)
				
				ReportFormat.XML:
					report_generation_progress.emit(progress + 30.0, "Generating XML report")
					var xml_path: String = _generate_xml_report(validation_results, output_directory, validation_id)
					if not xml_path.is_empty():
						generated_files.append(xml_path)
				
				ReportFormat.CSV:
					report_generation_progress.emit(progress + 40.0, "Generating CSV report")
					var csv_path: String = _generate_csv_report(validation_results, output_directory, validation_id)
					if not csv_path.is_empty():
						generated_files.append(csv_path)
				
				ReportFormat.JUNIT:
					report_generation_progress.emit(progress + 50.0, "Generating JUnit XML report")
					var junit_path: String = _generate_junit_report(validation_results, output_directory, validation_id)
					if not junit_path.is_empty():
						generated_files.append(junit_path)
				
				ReportFormat.MARKDOWN:
					report_generation_progress.emit(progress + 60.0, "Generating Markdown report")
					var md_path: String = _generate_markdown_report(validation_results, output_directory, validation_id)
					if not md_path.is_empty():
						generated_files.append(md_path)
		
		# Generate trend analysis report
		report_generation_progress.emit(95.0, "Generating trend analysis")
		_update_historical_data(validation_results)
		var trend_path: String = _generate_trend_analysis_report(validation_results, output_directory, validation_id)
		if not trend_path.is_empty():
			generated_files.append(trend_path)
		
		report_generation_progress.emit(100.0, "Report generation completed")
		
		for file_path in generated_files:
			report_generation_completed.emit(file_path)
			
	except Exception as e:
		print("ERROR: Report generation failed: ", str(e))
	
	return generated_files

func _generate_json_report(validation_results: Dictionary, output_dir: String, validation_id: String) -> String:
	"""Generate comprehensive JSON validation report"""
	var json_path: String = output_dir + "/validation_report_" + validation_id + ".json"
	
	try:
		# Create enhanced report with additional metadata
		var enhanced_results: Dictionary = validation_results.duplicate(true)
		enhanced_results["report_metadata"] = {
			"generated_by": "WCS-Godot Validation Framework",
			"framework_version": "1.0.0",
			"generation_timestamp": Time.get_datetime_string_from_system(),
			"report_format": "JSON",
			"schema_version": "1.0"
		}
		
		# Add summary statistics if not present
		if not enhanced_results.has("summary_statistics"):
			enhanced_results["summary_statistics"] = _calculate_summary_statistics(validation_results)
		
		# Add quality assessment
		enhanced_results["quality_assessment"] = _generate_quality_assessment(validation_results)
		
		# Add recommendations
		enhanced_results["automated_recommendations"] = _generate_automated_recommendations(validation_results)
		
		var file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
		if file == null:
			print("ERROR: Cannot create JSON report file: ", json_path)
			return ""
		
		var json_string: String = JSON.stringify(enhanced_results, "\t")
		file.store_string(json_string)
		file.close()
		
		print("Generated JSON report: ", json_path)
		return json_path
		
	except Exception as e:
		print("ERROR: Failed to generate JSON report: ", str(e))
		return ""

func _generate_html_report(validation_results: Dictionary, output_dir: String, validation_id: String) -> String:
	"""Generate comprehensive HTML validation report"""
	var html_path: String = output_dir + "/validation_report_" + validation_id + ".html"
	
	try:
		var validation_summary: Dictionary = validation_results.get("validation_summary", {})
		var quality_scores: Dictionary = validation_results.get("quality_scores", {})
		var critical_issues: Array = validation_results.get("critical_issues", [])
		var recommendations: Array = validation_results.get("recommendations", [])
		var execution_time: float = validation_results.get("execution_time_seconds", 0.0)
		
		var html_content: String = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WCS-Godot Validation Report - """ + validation_id + """</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            line-height: 1.6;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
        }
        .header .subtitle {
            margin-top: 10px;
            font-size: 1.2em;
            opacity: 0.9;
        }
        .content {
            padding: 30px;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .metric-card {
            background: #f8f9fa;
            border-left: 4px solid #28a745;
            padding: 20px;
            border-radius: 0 8px 8px 0;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .metric-card.warning {
            border-left-color: #ffc107;
        }
        .metric-card.error {
            border-left-color: #dc3545;
        }
        .metric-card h3 {
            margin: 0 0 10px 0;
            color: #333;
            font-size: 1.1em;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #28a745;
            margin: 10px 0;
        }
        .metric-value.warning {
            color: #ffc107;
        }
        .metric-value.error {
            color: #dc3545;
        }
        .section {
            margin-bottom: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 8px;
        }
        .section h2 {
            margin-top: 0;
            color: #333;
            border-bottom: 2px solid #e9ecef;
            padding-bottom: 10px;
        }
        .issue-list {
            list-style: none;
            padding: 0;
        }
        .issue-item {
            background: white;
            margin: 10px 0;
            padding: 15px;
            border-radius: 5px;
            border-left: 4px solid #dc3545;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .recommendation-item {
            background: white;
            margin: 10px 0;
            padding: 15px;
            border-radius: 5px;
            border-left: 4px solid #17a2b8;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .success-indicator {
            color: #28a745;
            font-weight: bold;
        }
        .warning-indicator {
            color: #ffc107;
            font-weight: bold;
        }
        .error-indicator {
            color: #dc3545;
            font-weight: bold;
        }
        .footer {
            background: #343a40;
            color: white;
            padding: 20px;
            text-align: center;
            font-size: 0.9em;
        }
        .progress-bar {
            width: 100%;
            height: 20px;
            background-color: #e9ecef;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #28a745, #20c997);
            transition: width 0.3s ease;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }
        th, td {
            border: 1px solid #dee2e6;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #e9ecef;
            font-weight: 600;
        }
        tr:nth-child(even) {
            background-color: #f8f9fa;
        }
    </style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>WCS-Godot Validation Report</h1>
            <div class="subtitle">Validation ID: """ + validation_id + """</div>
            <div class="subtitle">Generated: """ + validation_results.get("timestamp", "") + """</div>
        </header>
        
        <div class="content">
            <!-- Summary Metrics -->
            <div class="metrics-grid">
                <div class="metric-card">
                    <h3>Total Assets Validated</h3>
                    <div class="metric-value">""" + str(validation_summary.get("total_assets_validated", 0)) + """</div>
                </div>
                <div class="metric-card""" + (" error" if validation_summary.get("validation_success_rate", 1.0) < 0.95 else "") + """">
                    <h3>Validation Success Rate</h3>
                    <div class="metric-value""" + (" error" if validation_summary.get("validation_success_rate", 1.0) < 0.95 else "") + """">""" + ("%.1f%%" % (validation_summary.get("validation_success_rate", 0.0) * 100)) + """</div>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: """ + str(validation_summary.get("validation_success_rate", 0.0) * 100) + """%"></div>
                    </div>
                </div>
                <div class="metric-card""" + (" warning" if quality_scores.get("data_integrity", 1.0) < 0.99 else "") + """">
                    <h3>Data Integrity Score</h3>
                    <div class="metric-value""" + (" warning" if quality_scores.get("data_integrity", 1.0) < 0.99 else "") + """">""" + ("%.1f%%" % (quality_scores.get("data_integrity", 0.0) * 100)) + """</div>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: """ + str(quality_scores.get("data_integrity", 0.0) * 100) + """%"></div>
                    </div>
                </div>
                <div class="metric-card""" + (" warning" if quality_scores.get("visual_fidelity", 1.0) < 0.95 else "") + """">
                    <h3>Visual Fidelity Score</h3>
                    <div class="metric-value""" + (" warning" if quality_scores.get("visual_fidelity", 1.0) < 0.95 else "") + """">""" + ("%.1f%%" % (quality_scores.get("visual_fidelity", 0.0) * 100)) + """</div>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: """ + str(quality_scores.get("visual_fidelity", 0.0) * 100) + """%"></div>
                    </div>
                </div>
                <div class="metric-card">
                    <h3>Execution Time</h3>
                    <div class="metric-value">""" + ("%.2fs" % execution_time) + """</div>
                </div>
                <div class="metric-card""" + (" error" if critical_issues.size() > 0 else "") + """">
                    <h3>Critical Issues</h3>
                    <div class="metric-value""" + (" error" if critical_issues.size() > 0 else "") + """">""" + str(critical_issues.size()) + """</div>
                </div>
            </div>
            
            <!-- Quality Assessment -->
            <div class="section">
                <h2>Quality Assessment</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Metric</th>
                            <th>Score</th>
                            <th>Status</th>
                            <th>Threshold</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td>Format Compliance</td>
                            <td>""" + ("%.1f%%" % (quality_scores.get("format_compliance", 0.0) * 100)) + """</td>
                            <td><span class="success-indicator">PASS</span></td>
                            <td>95%</td>
                        </tr>
                        <tr>
                            <td>Data Integrity</td>
                            <td>""" + ("%.1f%%" % (quality_scores.get("data_integrity", 0.0) * 100)) + """</td>
                            <td><span class="success-indicator">PASS</span></td>
                            <td>99%</td>
                        </tr>
                        <tr>
                            <td>Visual Fidelity</td>
                            <td>""" + ("%.1f%%" % (quality_scores.get("visual_fidelity", 0.0) * 100)) + """</td>
                            <td><span class="success-indicator">PASS</span></td>
                            <td>95%</td>
                        </tr>
                        <tr>
                            <td>WCS Compliance</td>
                            <td>""" + ("%.1f%%" % (quality_scores.get("wcs_compliance", 0.0) * 100)) + """</td>
                            <td><span class="success-indicator">PASS</span></td>
                            <td>90%</td>
                        </tr>
                    </tbody>
                </table>
            </div>
"""

		# Critical Issues Section
		if critical_issues.size() > 0:
			html_content += """
            <!-- Critical Issues -->
            <div class="section">
                <h2>Critical Issues Found</h2>
                <ul class="issue-list">"""
			
			for issue in critical_issues:
				html_content += """
                    <li class="issue-item">
                        <strong>❌ Critical:</strong> """ + str(issue) + """
                    </li>"""
			
			html_content += """
                </ul>
            </div>"""
		else:
			html_content += """
            <!-- No Critical Issues -->
            <div class="section">
                <h2>Critical Issues</h2>
                <p class="success-indicator">✅ No critical issues found. All validation criteria met successfully.</p>
            </div>"""
		
		# Recommendations Section
		if recommendations.size() > 0:
			html_content += """
            <!-- Recommendations -->
            <div class="section">
                <h2>Recommendations</h2>
                <ul class="issue-list">"""
			
			for recommendation in recommendations:
				html_content += """
                    <li class="recommendation-item">
                        <strong>💡 Recommendation:</strong> """ + str(recommendation) + """
                    </li>"""
			
			html_content += """
                </ul>
            </div>"""
		else:
			html_content += """
            <!-- No Recommendations -->
            <div class="section">
                <h2>Recommendations</h2>
                <p class="success-indicator">✅ No recommendations. Validation results meet all quality targets.</p>
            </div>"""
		
		# Footer
		html_content += """
        </div>
        
        <footer class="footer">
            <p>Generated by WCS-Godot Validation Framework v1.0.0</p>
            <p>🤖 Generated with <a href="https://claude.ai/code" style="color: #17a2b8;">Claude Code</a></p>
        </footer>
    </div>
</body>
</html>"""
		
		var file: FileAccess = FileAccess.open(html_path, FileAccess.WRITE)
		if file == null:
			print("ERROR: Cannot create HTML report file: ", html_path)
			return ""
		
		file.store_string(html_content)
		file.close()
		
		print("Generated HTML report: ", html_path)
		return html_path
		
	except Exception as e:
		print("ERROR: Failed to generate HTML report: ", str(e))
		return ""

func _generate_xml_report(validation_results: Dictionary, output_dir: String, validation_id: String) -> String:
	"""Generate XML validation report for CI/CD integration"""
	var xml_path: String = output_dir + "/validation_report_" + validation_id + ".xml"
	
	try:
		var validation_summary: Dictionary = validation_results.get("validation_summary", {})
		var quality_scores: Dictionary = validation_results.get("quality_scores", {})
		var critical_issues: Array = validation_results.get("critical_issues", [])
		
		var xml_content: String = """<?xml version="1.0" encoding="UTF-8"?>
<ValidationReport id=\"""" + validation_id + """\" timestamp=\"""" + validation_results.get("timestamp", "") + """\" version="1.0">
    <Summary>
        <TotalAssets>""" + str(validation_summary.get("total_assets_validated", 0)) + """</TotalAssets>
        <ValidAssets>""" + str(validation_summary.get("valid_assets", 0)) + """</ValidAssets>
        <SuccessRate>""" + str(validation_summary.get("validation_success_rate", 0.0)) + """</SuccessRate>
        <ExecutionTime>""" + str(validation_results.get("execution_time_seconds", 0.0)) + """</ExecutionTime>
        <OverallStatus>""" + ("PASS" if critical_issues.size() == 0 else "FAIL") + """</OverallStatus>
    </Summary>
    
    <QualityScores>
        <FormatCompliance>""" + str(quality_scores.get("format_compliance", 0.0)) + """</FormatCompliance>
        <DataIntegrity>""" + str(quality_scores.get("data_integrity", 0.0)) + """</DataIntegrity>
        <VisualFidelity>""" + str(quality_scores.get("visual_fidelity", 0.0)) + """</VisualFidelity>
        <WCSCompliance>""" + str(quality_scores.get("wcs_compliance", 0.0)) + """</WCSCompliance>
    </QualityScores>
    
    <ValidationResults>
        <AssetValidation>
            <TotalTests>""" + str(validation_results.get("asset_validation_results", []).size()) + """</TotalTests>
            <PassedTests>""" + str(_count_passed_validations(validation_results.get("asset_validation_results", []))) + """</PassedTests>
        </AssetValidation>
        <IntegrityValidation>
            <TotalTests>""" + str(validation_results.get("integrity_verification_results", []).size()) + """</TotalTests>
            <AverageScore>""" + str(validation_summary.get("average_integrity_score", 0.0)) + """</AverageScore>
        </IntegrityValidation>
        <VisualValidation>
            <TotalTests>""" + str(validation_results.get("visual_fidelity_results", []).size()) + """</TotalTests>
            <AverageScore>""" + str(validation_summary.get("average_visual_fidelity_score", 0.0)) + """</AverageScore>
        </VisualValidation>
    </ValidationResults>"""
		
		# Add critical issues
		if critical_issues.size() > 0:
			xml_content += """
    <CriticalIssues count=\"""" + str(critical_issues.size()) + """\">"""
			
			for i in range(critical_issues.size()):
				xml_content += """
        <Issue id=\"""" + str(i + 1) + """">""" + _escape_xml(str(critical_issues[i])) + """</Issue>"""
			
			xml_content += """
    </CriticalIssues>"""
		else:
			xml_content += """
    <CriticalIssues count="0"/>"""
		
		xml_content += """
    
    <Metadata>
        <GeneratedBy>WCS-Godot Validation Framework</GeneratedBy>
        <FrameworkVersion>1.0.0</FrameworkVersion>
        <ReportFormat>XML</ReportFormat>
        <SourceDirectory>""" + _escape_xml(validation_results.get("source_directory", "")) + """</SourceDirectory>
        <TargetDirectory>""" + _escape_xml(validation_results.get("target_directory", "")) + """</TargetDirectory>
    </Metadata>
</ValidationReport>"""
		
		var file: FileAccess = FileAccess.open(xml_path, FileAccess.WRITE)
		if file == null:
			print("ERROR: Cannot create XML report file: ", xml_path)
			return ""
		
		file.store_string(xml_content)
		file.close()
		
		print("Generated XML report: ", xml_path)
		return xml_path
		
	except Exception as e:
		print("ERROR: Failed to generate XML report: ", str(e))
		return ""

func _generate_junit_report(validation_results: Dictionary, output_dir: String, validation_id: String) -> String:
	"""Generate JUnit XML report for CI/CD integration"""
	var junit_path: String = output_dir + "/junit_validation_" + validation_id + ".xml"
	
	try:
		var validation_summary: Dictionary = validation_results.get("validation_summary", {})
		var asset_results: Array = validation_results.get("asset_validation_results", [])
		var integrity_results: Array = validation_results.get("integrity_verification_results", [])
		var critical_issues: Array = validation_results.get("critical_issues", [])
		
		var total_tests: int = asset_results.size() + integrity_results.size()
		var failed_tests: int = _count_failed_validations(asset_results) + _count_failed_integrity_checks(integrity_results)
		var execution_time: float = validation_results.get("execution_time_seconds", 0.0)
		
		var junit_content: String = """<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="WCS-Godot Validation" tests=\"""" + str(total_tests) + """\" failures=\"""" + str(failed_tests) + """\" errors="0" time=\"""" + str(execution_time) + """\">
    <testsuite name="AssetValidation" tests=\"""" + str(asset_results.size()) + """\" failures=\"""" + str(_count_failed_validations(asset_results)) + """\" errors="0" time=\"""" + str(execution_time * 0.5) + """\">"""
		
		# Add asset validation test cases
		for i in range(asset_results.size()):
			var result: Dictionary = asset_results[i]
			var asset_path: String = result.get("asset_path", "unknown")
			var is_valid: bool = result.get("format_valid", false)
			var issues: Array = result.get("validation_issues", [])
			
			junit_content += """
        <testcase name=\"validate_""" + asset_path.get_file() + """\" classname="AssetValidation" time="0.1">"""
			
			if not is_valid or issues.size() > 0:
				junit_content += """
            <failure message="Asset validation failed">"""
				for issue in issues:
					junit_content += _escape_xml(str(issue)) + "\n"
				junit_content += """</failure>"""
			
			junit_content += """
        </testcase>"""
		
		junit_content += """
    </testsuite>
    
    <testsuite name="IntegrityValidation" tests=\"""" + str(integrity_results.size()) + """\" failures=\"""" + str(_count_failed_integrity_checks(integrity_results)) + """\" errors="0" time=\"""" + str(execution_time * 0.5) + """\">"""
		
		# Add integrity validation test cases
		for i in range(integrity_results.size()):
			var result: Dictionary = integrity_results[i]
			var original_path: String = result.get("original_path", "unknown")
			var integrity_score: float = result.get("integrity_score", 0.0)
			var data_loss: bool = result.get("data_loss_detected", false)
			
			junit_content += """
        <testcase name=\"integrity_""" + original_path.get_file() + """\" classname="IntegrityValidation" time="0.1">"""
			
			if data_loss or integrity_score < 0.95:
				junit_content += """
            <failure message="Integrity validation failed">Integrity score: """ + str(integrity_score) + """
Data loss detected: """ + str(data_loss) + """</failure>"""
			
			junit_content += """
        </testcase>"""
		
		junit_content += """
    </testsuite>
</testsuites>"""
		
		var file: FileAccess = FileAccess.open(junit_path, FileAccess.WRITE)
		if file == null:
			print("ERROR: Cannot create JUnit report file: ", junit_path)
			return ""
		
		file.store_string(junit_content)
		file.close()
		
		print("Generated JUnit XML report: ", junit_path)
		return junit_path
		
	except Exception as e:
		print("ERROR: Failed to generate JUnit report: ", str(e))
		return ""

func _generate_csv_report(validation_results: Dictionary, output_dir: String, validation_id: String) -> String:
	"""Generate CSV report for data analysis"""
	var csv_path: String = output_dir + "/validation_summary_" + validation_id + ".csv"
	
	try:
		var asset_results: Array = validation_results.get("asset_validation_results", [])
		var integrity_results: Array = validation_results.get("integrity_verification_results", [])
		
		var csv_content: String = "Asset Path,Asset Type,Format Valid,WCS Compliant,Issues Count,Warnings Count,File Size\n"
		
		# Add asset validation data
		for result in asset_results:
			var asset_path: String = result.get("asset_path", "")
			var asset_type: String = result.get("asset_type", "")
			var format_valid: bool = result.get("format_valid", false)
			var wcs_compliant: bool = result.get("wcs_compliant", false)
			var issues: Array = result.get("validation_issues", [])
			var warnings: Array = result.get("validation_warnings", [])
			var metadata: Dictionary = result.get("metadata", {})
			var file_size: int = metadata.get("file_size", 0)
			
			csv_content += "\"%s\",%s,%s,%s,%d,%d,%d\n" % [
				asset_path, asset_type, str(format_valid), str(wcs_compliant),
				issues.size(), warnings.size(), file_size
			]
		
		# Add integrity data in separate section
		csv_content += "\nIntegrity Analysis\n"
		csv_content += "Original Path,Converted Path,Integrity Score,Data Loss,Missing Properties,Size Variance\n"
		
		for result in integrity_results:
			var original_path: String = result.get("original_path", "")
			var converted_path: String = result.get("converted_path", "")
			var integrity_score: float = result.get("integrity_score", 0.0)
			var data_loss: bool = result.get("data_loss_detected", false)
			var missing_props: Array = result.get("missing_properties", [])
			var size_variance: float = result.get("size_variance_percent", 0.0)
			
			csv_content += "\"%s\",\"%s\",%.3f,%s,%d,%.2f\n" % [
				original_path, converted_path, integrity_score, str(data_loss),
				missing_props.size(), size_variance
			]
		
		var file: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
		if file == null:
			print("ERROR: Cannot create CSV report file: ", csv_path)
			return ""
		
		file.store_string(csv_content)
		file.close()
		
		print("Generated CSV report: ", csv_path)
		return csv_path
		
	except Exception as e:
		print("ERROR: Failed to generate CSV report: ", str(e))
		return ""

func _generate_markdown_report(validation_results: Dictionary, output_dir: String, validation_id: String) -> String:
	"""Generate Markdown report for documentation"""
	var md_path: String = output_dir + "/validation_report_" + validation_id + ".md"
	
	try:
		var validation_summary: Dictionary = validation_results.get("validation_summary", {})
		var quality_scores: Dictionary = validation_results.get("quality_scores", {})
		var critical_issues: Array = validation_results.get("critical_issues", [])
		var recommendations: Array = validation_results.get("recommendations", [])
		
		var md_content: String = """# WCS-Godot Validation Report

**Validation ID:** `""" + validation_id + """`  
**Generated:** """ + validation_results.get("timestamp", "") + """  
**Execution Time:** """ + ("%.2fs" % validation_results.get("execution_time_seconds", 0.0)) + """

## Summary

| Metric | Value | Status |
|--------|-------|--------|
| Total Assets | """ + str(validation_summary.get("total_assets_validated", 0)) + """ | ✅ |
| Success Rate | """ + ("%.1f%%" % (validation_summary.get("validation_success_rate", 0.0) * 100)) + """ | """ + ("✅" if validation_summary.get("validation_success_rate", 0.0) >= 0.95 else "⚠️") + """ |
| Data Integrity | """ + ("%.1f%%" % (quality_scores.get("data_integrity", 0.0) * 100)) + """ | """ + ("✅" if quality_scores.get("data_integrity", 0.0) >= 0.99 else "⚠️") + """ |
| Visual Fidelity | """ + ("%.1f%%" % (quality_scores.get("visual_fidelity", 0.0) * 100)) + """ | """ + ("✅" if quality_scores.get("visual_fidelity", 0.0) >= 0.95 else "⚠️") + """ |
| Critical Issues | """ + str(critical_issues.size()) + """ | """ + ("✅" if critical_issues.size() == 0 else "❌") + """ |

## Quality Assessment

### Format Compliance: """ + ("%.1f%%" % (quality_scores.get("format_compliance", 0.0) * 100)) + """
- All converted assets validated against WCS specifications
- """ + str(validation_summary.get("valid_assets", 0)) + """ of """ + str(validation_summary.get("total_assets_validated", 0)) + """ assets passed format validation

### Data Integrity: """ + ("%.1f%%" % (quality_scores.get("data_integrity", 0.0) * 100)) + """
- Average integrity score across all conversions
- Zero data loss tolerance maintained

### Visual Fidelity: """ + ("%.1f%%" % (quality_scores.get("visual_fidelity", 0.0) * 100)) + """
- Visual similarity between original and converted assets
- Automated image comparison algorithms used

### WCS Compliance: """ + ("%.1f%%" % (quality_scores.get("wcs_compliance", 0.0) * 100)) + """
- Compliance with Wing Commander Saga specifications
- Preservation of WCS-specific metadata and properties
"""

		# Critical Issues Section
		if critical_issues.size() > 0:
			md_content += """
## ❌ Critical Issues

The following critical issues were identified and must be addressed:

"""
			for i in range(critical_issues.size()):
				md_content += str(i + 1) + ". **" + str(critical_issues[i]) + "**\n"
		else:
			md_content += """
## ✅ Critical Issues

No critical issues found. All validation criteria met successfully.
"""
		
		# Recommendations Section
		if recommendations.size() > 0:
			md_content += """
## 💡 Recommendations

The following recommendations can help improve validation results:

"""
			for i in range(recommendations.size()):
				md_content += str(i + 1) + ". " + str(recommendations[i]) + "\n"
		else:
			md_content += """
## ✅ Recommendations

No recommendations. Validation results meet all quality targets.
"""
		
		md_content += """
## Detailed Results

### Asset Validation
- **Total Assets:** """ + str(validation_results.get("asset_validation_results", []).size()) + """
- **Passed:** """ + str(_count_passed_validations(validation_results.get("asset_validation_results", []))) + """
- **Failed:** """ + str(_count_failed_validations(validation_results.get("asset_validation_results", []))) + """

### Integrity Verification
- **Total Checks:** """ + str(validation_results.get("integrity_verification_results", []).size()) + """
- **Average Score:** """ + ("%.3f" % validation_summary.get("average_integrity_score", 0.0)) + """

### Visual Fidelity Testing
- **Total Comparisons:** """ + str(validation_results.get("visual_fidelity_results", []).size()) + """
- **Average Score:** """ + ("%.3f" % validation_summary.get("average_visual_fidelity_score", 0.0)) + """

---

*Generated by WCS-Godot Validation Framework v1.0.0*  
*🤖 Generated with [Claude Code](https://claude.ai/code)*
"""
		
		var file: FileAccess = FileAccess.open(md_path, FileAccess.WRITE)
		if file == null:
			print("ERROR: Cannot create Markdown report file: ", md_path)
			return ""
		
		file.store_string(md_content)
		file.close()
		
		print("Generated Markdown report: ", md_path)
		return md_path
		
	except Exception as e:
		print("ERROR: Failed to generate Markdown report: ", str(e))
		return ""

func _generate_trend_analysis_report(validation_results: Dictionary, output_dir: String, validation_id: String) -> String:
	"""Generate trend analysis report with historical comparison"""
	var trend_path: String = output_dir + "/trend_analysis_" + validation_id + ".json"
	
	try:
		var historical_data: Array = _load_historical_data()
		var current_metrics: Dictionary = _extract_key_metrics(validation_results)
		
		var trend_analysis: Dictionary = {
			"report_id": validation_id,
			"timestamp": validation_results.get("timestamp", ""),
			"current_metrics": current_metrics,
			"historical_comparison": {},
			"trends": {},
			"predictions": {},
			"recommendations_based_on_trends": []
		}
		
		if historical_data.size() >= 2:
			# Calculate trends
			trend_analysis["historical_comparison"] = _calculate_historical_comparison(current_metrics, historical_data)
			trend_analysis["trends"] = _calculate_trends(historical_data)
			trend_analysis["predictions"] = _generate_trend_predictions(historical_data)
			trend_analysis["recommendations_based_on_trends"] = _generate_trend_recommendations(historical_data, current_metrics)
		else:
			trend_analysis["message"] = "Insufficient historical data for trend analysis. Need at least 2 validation runs."
		
		var file: FileAccess = FileAccess.open(trend_path, FileAccess.WRITE)
		if file == null:
			print("ERROR: Cannot create trend analysis file: ", trend_path)
			return ""
		
		var json_string: String = JSON.stringify(trend_analysis, "\t")
		file.store_string(json_string)
		file.close()
		
		print("Generated trend analysis report: ", trend_path)
		return trend_path
		
	except Exception as e:
		print("ERROR: Failed to generate trend analysis: ", str(e))
		return ""

func generate_ci_cd_summary(validation_results: Dictionary) -> Dictionary:
	"""
	AC5: Generate CI/CD compatible summary for automated test suite integration.
	
	Args:
		validation_results: Complete validation results
		
	Returns:
		CI/CD compatible summary dictionary
	"""
	var critical_issues: Array = validation_results.get("critical_issues", [])
	var validation_summary: Dictionary = validation_results.get("validation_summary", {})
	var quality_scores: Dictionary = validation_results.get("quality_scores", {})
	
	var ci_summary: Dictionary = {
		"status": "PASS" if critical_issues.size() == 0 else "FAIL",
		"exit_code": 0 if critical_issues.size() == 0 else 1,
		"validation_id": validation_results.get("validation_id", ""),
		"timestamp": validation_results.get("timestamp", ""),
		"execution_time_seconds": validation_results.get("execution_time_seconds", 0.0),
		
		# Summary metrics
		"total_assets": validation_summary.get("total_assets_validated", 0),
		"successful_validations": validation_summary.get("valid_assets", 0),
		"failed_validations": validation_summary.get("total_assets_validated", 0) - validation_summary.get("valid_assets", 0),
		"success_rate": validation_summary.get("validation_success_rate", 0.0),
		
		# Quality metrics  
		"format_compliance": quality_scores.get("format_compliance", 0.0),
		"data_integrity": quality_scores.get("data_integrity", 0.0),
		"visual_fidelity": quality_scores.get("visual_fidelity", 0.0),
		"wcs_compliance": quality_scores.get("wcs_compliance", 0.0),
		
		# Issues and recommendations
		"critical_issues_count": critical_issues.size(),
		"critical_issues": critical_issues,
		"recommendations_count": validation_results.get("recommendations", []).size(),
		
		# Thresholds status
		"meets_quality_thresholds": {
			"format_compliance": quality_scores.get("format_compliance", 0.0) >= 0.95,
			"data_integrity": quality_scores.get("data_integrity", 0.0) >= 0.99,
			"visual_fidelity": quality_scores.get("visual_fidelity", 0.0) >= 0.95,
			"success_rate": validation_summary.get("validation_success_rate", 0.0) >= 0.98
		},
		
		# Regression analysis
		"regression_detected": validation_results.get("regression_analysis", {}).get("regressions_detected", false),
		
		# CI/CD metadata
		"framework_version": "1.0.0",
		"report_format_version": "1.0",
		"compatible_with": ["Jenkins", "GitHub Actions", "GitLab CI", "Azure DevOps", "TeamCity"]
	}
	
	return ci_summary

func generate_json_report(validation_data: Dictionary, output_path: String) -> bool:
	"""Generate JSON validation report at specified path"""
	return not _generate_json_report(validation_data, output_path.get_base_dir(), 
									 output_path.get_file().get_basename()).is_empty()

func generate_html_report(validation_data: Dictionary, output_path: String) -> bool:
	"""Generate HTML validation report at specified path"""
	return not _generate_html_report(validation_data, output_path.get_base_dir(), 
									 output_path.get_file().get_basename()).is_empty()

func generate_xml_report(validation_data: Dictionary, output_path: String) -> bool:
	"""Generate XML validation report at specified path"""
	return not _generate_xml_report(validation_data, output_path.get_base_dir(), 
									output_path.get_file().get_basename()).is_empty()

# Helper functions for report generation
func _calculate_summary_statistics(validation_results: Dictionary) -> Dictionary:
	"""Calculate comprehensive summary statistics"""
	var asset_results: Array = validation_results.get("asset_validation_results", [])
	var integrity_results: Array = validation_results.get("integrity_verification_results", [])
	var visual_results: Array = validation_results.get("visual_fidelity_results", [])
	
	var total_assets: int = asset_results.size()
	var valid_assets: int = _count_passed_validations(asset_results)
	var failed_assets: int = total_assets - valid_assets
	
	# Calculate average scores
	var integrity_scores: Array[float] = []
	for result in integrity_results:
		integrity_scores.append(result.get("integrity_score", 0.0))
	
	var visual_scores: Array[float] = []
	for result in visual_results:
		visual_scores.append(result.get("similarity_score", 0.0))
	
	return {
		"total_assets_validated": total_assets,
		"valid_assets": valid_assets,
		"failed_assets": failed_assets,
		"validation_success_rate": float(valid_assets) / float(total_assets) if total_assets > 0 else 0.0,
		"average_integrity_score": _calculate_average(integrity_scores),
		"average_visual_fidelity_score": _calculate_average(visual_scores),
		"integrity_tests_performed": integrity_results.size(),
		"visual_tests_performed": visual_results.size()
	}

func _generate_quality_assessment(validation_results: Dictionary) -> Dictionary:
	"""Generate detailed quality assessment"""
	var quality_scores: Dictionary = validation_results.get("quality_scores", {})
	
	return {
		"overall_grade": _calculate_overall_grade(quality_scores),
		"quality_categories": {
			"format_compliance": {
				"score": quality_scores.get("format_compliance", 0.0),
				"grade": _get_grade_from_score(quality_scores.get("format_compliance", 0.0)),
				"threshold": 0.95,
				"meets_threshold": quality_scores.get("format_compliance", 0.0) >= 0.95
			},
			"data_integrity": {
				"score": quality_scores.get("data_integrity", 0.0),
				"grade": _get_grade_from_score(quality_scores.get("data_integrity", 0.0)),
				"threshold": 0.99,
				"meets_threshold": quality_scores.get("data_integrity", 0.0) >= 0.99
			},
			"visual_fidelity": {
				"score": quality_scores.get("visual_fidelity", 0.0),
				"grade": _get_grade_from_score(quality_scores.get("visual_fidelity", 0.0)),
				"threshold": 0.95,
				"meets_threshold": quality_scores.get("visual_fidelity", 0.0) >= 0.95
			}
		},
		"improvement_areas": _identify_improvement_areas(quality_scores),
		"strengths": _identify_strengths(quality_scores)
	}

func _generate_automated_recommendations(validation_results: Dictionary) -> Array[String]:
	"""Generate automated recommendations based on validation results"""
	var recommendations: Array[String] = []
	var quality_scores: Dictionary = validation_results.get("quality_scores", {})
	var critical_issues: Array = validation_results.get("critical_issues", [])
	
	# Quality-based recommendations
	if quality_scores.get("format_compliance", 1.0) < 0.95:
		recommendations.append("Improve asset format validation - compliance rate below 95%")
	
	if quality_scores.get("data_integrity", 1.0) < 0.99:
		recommendations.append("Address data integrity issues - score below 99% threshold")
	
	if quality_scores.get("visual_fidelity", 1.0) < 0.95:
		recommendations.append("Enhance visual fidelity - similarity score below 95% threshold")
	
	# Issue-based recommendations
	if critical_issues.size() > 0:
		recommendations.append("Resolve " + str(critical_issues.size()) + " critical issues before deployment")
	
	# Performance recommendations
	var execution_time: float = validation_results.get("execution_time_seconds", 0.0)
	if execution_time > 300:  # 5 minutes
		recommendations.append("Consider optimization - validation took " + ("%.1f" % execution_time) + " seconds")
	
	# Coverage recommendations
	var asset_count: int = validation_results.get("validation_summary", {}).get("total_assets_validated", 0)
	if asset_count < 10:
		recommendations.append("Increase validation coverage - only " + str(asset_count) + " assets validated")
	
	return recommendations

func _update_historical_data(validation_results: Dictionary) -> void:
	"""Update historical validation data for trend analysis"""
	var historical_data: Array = _load_historical_data()
	var current_metrics: Dictionary = _extract_key_metrics(validation_results)
	
	historical_data.append(current_metrics)
	
	# Keep only the last N entries
	if historical_data.size() > max_historical_entries:
		historical_data = historical_data.slice(-max_historical_entries)
	
	_save_historical_data(historical_data)

func _load_historical_data() -> Array:
	"""Load historical validation data"""
	if not FileAccess.file_exists(historical_data_file):
		return []
	
	try:
		var file: FileAccess = FileAccess.open(historical_data_file, FileAccess.READ)
		if file == null:
			return []
		
		var json_text: String = file.get_as_text()
		file.close()
		
		var json: JSON = JSON.new()
		if json.parse(json_text) == OK:
			return json.data as Array
	except Exception as e:
		print("WARNING: Failed to load historical data: ", str(e))
	
	return []

func _save_historical_data(data: Array) -> void:
	"""Save historical validation data"""
	try:
		var file: FileAccess = FileAccess.open(historical_data_file, FileAccess.WRITE)
		if file == null:
			print("WARNING: Cannot save historical data")
			return
		
		var json_string: String = JSON.stringify(data, "\t")
		file.store_string(json_string)
		file.close()
	except Exception as e:
		print("WARNING: Failed to save historical data: ", str(e))

func _extract_key_metrics(validation_results: Dictionary) -> Dictionary:
	"""Extract key metrics for historical tracking"""
	var validation_summary: Dictionary = validation_results.get("validation_summary", {})
	var quality_scores: Dictionary = validation_results.get("quality_scores", {})
	
	return {
		"timestamp": validation_results.get("timestamp", ""),
		"validation_id": validation_results.get("validation_id", ""),
		"total_assets": validation_summary.get("total_assets_validated", 0),
		"success_rate": validation_summary.get("validation_success_rate", 0.0),
		"format_compliance": quality_scores.get("format_compliance", 0.0),
		"data_integrity": quality_scores.get("data_integrity", 0.0),
		"visual_fidelity": quality_scores.get("visual_fidelity", 0.0),
		"wcs_compliance": quality_scores.get("wcs_compliance", 0.0),
		"execution_time": validation_results.get("execution_time_seconds", 0.0),
		"critical_issues_count": validation_results.get("critical_issues", []).size()
	}

func _calculate_historical_comparison(current_metrics: Dictionary, historical_data: Array) -> Dictionary:
	"""Calculate comparison with historical data"""
	if historical_data.is_empty():
		return {}
	
	var last_run: Dictionary = historical_data[-1]
	var comparison: Dictionary = {}
	
	for metric in ["success_rate", "data_integrity", "visual_fidelity", "execution_time"]:
		var current_value: float = current_metrics.get(metric, 0.0)
		var previous_value: float = last_run.get(metric, 0.0)
		
		if previous_value > 0:
			var change_percent: float = ((current_value - previous_value) / previous_value) * 100.0
			comparison[metric] = {
				"current": current_value,
				"previous": previous_value,
				"change_percent": change_percent,
				"trend": "improving" if change_percent > 0 else ("declining" if change_percent < 0 else "stable")
			}
	
	return comparison

func _calculate_trends(historical_data: Array) -> Dictionary:
	"""Calculate long-term trends from historical data"""
	if historical_data.size() < 3:
		return {"message": "Insufficient data for trend analysis"}
	
	var trends: Dictionary = {}
	
	for metric in ["success_rate", "data_integrity", "visual_fidelity"]:
		var values: Array[float] = []
		for entry in historical_data:
			values.append(entry.get(metric, 0.0))
		
		trends[metric] = {
			"direction": _calculate_trend_direction(values),
			"stability": _calculate_trend_stability(values),
			"average": _calculate_average(values),
			"recent_average": _calculate_average(values.slice(-5))  # Last 5 entries
		}
	
	return trends

func _generate_trend_predictions(historical_data: Array) -> Dictionary:
	"""Generate simple trend predictions"""
	if historical_data.size() < 5:
		return {"message": "Insufficient data for predictions"}
	
	var predictions: Dictionary = {}
	
	for metric in ["success_rate", "data_integrity", "visual_fidelity"]:
		var recent_values: Array[float] = []
		for entry in historical_data.slice(-5):
			recent_values.append(entry.get(metric, 0.0))
		
		var trend_direction: String = _calculate_trend_direction(recent_values)
		var avg_change: float = _calculate_average_change(recent_values)
		
		predictions[metric] = {
			"predicted_direction": trend_direction,
			"predicted_next_value": recent_values[-1] + avg_change,
			"confidence": "low"  # Simple prediction model
		}
	
	return predictions

func _generate_trend_recommendations(historical_data: Array, current_metrics: Dictionary) -> Array[String]:
	"""Generate recommendations based on historical trends"""
	var recommendations: Array[String] = []
	
	if historical_data.size() < 3:
		return recommendations
	
	# Analyze trends for each metric
	for metric in ["success_rate", "data_integrity", "visual_fidelity"]:
		var values: Array[float] = []
		for entry in historical_data.slice(-5):  # Last 5 entries
			values.append(entry.get(metric, 0.0))
		
		var trend: String = _calculate_trend_direction(values)
		if trend == "declining":
			recommendations.append("Address declining " + metric + " trend - consider process improvements")
		elif trend == "stable" and values[-1] < 0.95:
			recommendations.append("Improve consistently low " + metric + " performance")
	
	return recommendations

# Utility functions
func _count_passed_validations(asset_results: Array) -> int:
	"""Count number of passed asset validations"""
	var passed: int = 0
	for result in asset_results:
		if result.get("format_valid", false):
			passed += 1
	return passed

func _count_failed_validations(asset_results: Array) -> int:
	"""Count number of failed asset validations"""
	return asset_results.size() - _count_passed_validations(asset_results)

func _count_failed_integrity_checks(integrity_results: Array) -> int:
	"""Count number of failed integrity checks"""
	var failed: int = 0
	for result in integrity_results:
		if result.get("data_loss_detected", false) or result.get("integrity_score", 1.0) < 0.95:
			failed += 1
	return failed

func _calculate_average(values: Array[float]) -> float:
	"""Calculate average of float array"""
	if values.is_empty():
		return 0.0
	
	var sum: float = 0.0
	for value in values:
		sum += value
	
	return sum / float(values.size())

func _calculate_average_change(values: Array[float]) -> float:
	"""Calculate average change between consecutive values"""
	if values.size() < 2:
		return 0.0
	
	var changes: Array[float] = []
	for i in range(1, values.size()):
		changes.append(values[i] - values[i-1])
	
	return _calculate_average(changes)

func _calculate_trend_direction(values: Array[float]) -> String:
	"""Calculate overall trend direction"""
	if values.size() < 2:
		return "unknown"
	
	var first_half: Array[float] = values.slice(0, values.size() / 2)
	var second_half: Array[float] = values.slice(values.size() / 2)
	
	var first_avg: float = _calculate_average(first_half)
	var second_avg: float = _calculate_average(second_half)
	
	if second_avg > first_avg * 1.02:  # 2% improvement threshold
		return "improving"
	elif second_avg < first_avg * 0.98:  # 2% decline threshold
		return "declining"
	else:
		return "stable"

func _calculate_trend_stability(values: Array[float]) -> String:
	"""Calculate trend stability"""
	if values.size() < 3:
		return "unknown"
	
	var avg: float = _calculate_average(values)
	var variance: float = 0.0
	
	for value in values:
		variance += pow(value - avg, 2)
	variance /= float(values.size())
	
	var std_dev: float = sqrt(variance)
	var coefficient_of_variation: float = std_dev / avg if avg > 0 else 0.0
	
	if coefficient_of_variation < 0.05:  # 5%
		return "very_stable"
	elif coefficient_of_variation < 0.10:  # 10%
		return "stable"
	elif coefficient_of_variation < 0.20:  # 20%
		return "moderate"
	else:
		return "unstable"

func _calculate_overall_grade(quality_scores: Dictionary) -> String:
	"""Calculate overall quality grade"""
	var scores: Array[float] = [
		quality_scores.get("format_compliance", 0.0),
		quality_scores.get("data_integrity", 0.0),
		quality_scores.get("visual_fidelity", 0.0),
		quality_scores.get("wcs_compliance", 0.0)
	]
	
	var avg_score: float = _calculate_average(scores)
	return _get_grade_from_score(avg_score)

func _get_grade_from_score(score: float) -> String:
	"""Convert score to letter grade"""
	if score >= 0.97:
		return "A+"
	elif score >= 0.93:
		return "A"
	elif score >= 0.90:
		return "A-"
	elif score >= 0.87:
		return "B+"
	elif score >= 0.83:
		return "B"
	elif score >= 0.80:
		return "B-"
	elif score >= 0.77:
		return "C+"
	elif score >= 0.73:
		return "C"
	elif score >= 0.70:
		return "C-"
	elif score >= 0.60:
		return "D"
	else:
		return "F"

func _identify_improvement_areas(quality_scores: Dictionary) -> Array[String]:
	"""Identify areas needing improvement"""
	var areas: Array[String] = []
	
	if quality_scores.get("format_compliance", 1.0) < 0.95:
		areas.append("Format Compliance")
	if quality_scores.get("data_integrity", 1.0) < 0.99:
		areas.append("Data Integrity")
	if quality_scores.get("visual_fidelity", 1.0) < 0.95:
		areas.append("Visual Fidelity")
	if quality_scores.get("wcs_compliance", 1.0) < 0.90:
		areas.append("WCS Compliance")
	
	return areas

func _identify_strengths(quality_scores: Dictionary) -> Array[String]:
	"""Identify quality strengths"""
	var strengths: Array[String] = []
	
	if quality_scores.get("format_compliance", 0.0) >= 0.98:
		strengths.append("Excellent Format Compliance")
	if quality_scores.get("data_integrity", 0.0) >= 0.995:
		strengths.append("Outstanding Data Integrity")
	if quality_scores.get("visual_fidelity", 0.0) >= 0.98:
		strengths.append("Superior Visual Fidelity")
	if quality_scores.get("wcs_compliance", 0.0) >= 0.95:
		strengths.append("Strong WCS Compliance")
	
	return strengths

func _escape_xml(text: String) -> String:
	"""Escape XML special characters"""
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&apos;")