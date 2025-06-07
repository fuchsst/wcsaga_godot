extends Node

## SEXP Manager Singleton
##
## Central coordination point for the SEXP Expression System.
## Provides parsing, evaluation, and function registration capabilities
## for mission scripting and runtime expression evaluation.

const SexpParser = preload("res://addons/sexp/core/sexp_parser.gd")
const SexpTokenizer = preload("res://addons/sexp/core/sexp_tokenizer.gd")
const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd")

## Signals for system integration
signal sexp_system_ready()
signal expression_evaluated(expression_id: String, result: Variant)
signal parse_error(error_message: String, expression_text: String)

## Core system components
var _parser: SexpParser
var _tokenizer: SexpTokenizer

## System initialization flag
var _is_initialized: bool = false

func _ready() -> void:
	_initialize_sexp_system()

## Initialize the SEXP system
func _initialize_sexp_system() -> void:
	if _is_initialized:
		return
	
	print("Initializing WCS SEXP Expression System...")
	
	# Create core components
	_parser = SexpParser.new()
	_tokenizer = SexpTokenizer.new()
	
	_is_initialized = true
	sexp_system_ready.emit()
	
	print("SEXP Expression System ready")

## Parse SEXP expression text into expression tree
func parse_expression(expression_text: String) -> SexpExpression:
	if not _is_initialized:
		push_error("SEXP system not initialized")
		return null
	
	var result: SexpParser.ParseResult = _parser.parse_with_validation(expression_text)
	
	if not result.is_valid:
		var error_msg: String = "Parse errors: " + str(result.errors)
		parse_error.emit(error_msg, expression_text)
		push_error(error_msg)
		return null
	
	return result.expression

## Validate SEXP syntax without building expression tree
func validate_syntax(expression_text: String) -> bool:
	if not _is_initialized:
		push_error("SEXP system not initialized")
		return false
	
	var result: SexpParser.SexpValidationResult = _parser.validate_syntax(expression_text)
	return result.is_valid

## Get detailed validation results
func get_validation_errors(expression_text: String) -> Array[String]:
	if not _is_initialized:
		return ["SEXP system not initialized"]
	
	var result: SexpParser.SexpValidationResult = _parser.validate_syntax(expression_text)
	return result.errors

## Tokenize SEXP text for syntax highlighting or analysis
func tokenize_expression(expression_text: String) -> Array:
	if not _is_initialized:
		push_error("SEXP system not initialized")
		return []
	
	return _tokenizer.tokenize_with_validation(expression_text)

## Check if system is ready
func is_ready() -> bool:
	return _is_initialized

## Get system status information
func get_system_status() -> Dictionary:
	return {
		"initialized": _is_initialized,
		"parser_available": _parser != null,
		"tokenizer_available": _tokenizer != null,
		"version": "1.0.0"
	}
