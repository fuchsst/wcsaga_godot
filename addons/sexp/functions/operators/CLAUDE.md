# SEXP Operators Package

## Purpose
The SEXP Operators package provides comprehensive implementations of all logical, comparison, arithmetic, conditional, and string operators required for SEXP expression evaluation. This package forms the core of the WCS-compatible expression system, implementing operators with faithful WCS semantics while adding modern safety and type handling.

## Key Classes

### Logical Operators
- **LogicalAndFunction** (`logical_and_function.gd`) - Logical AND with full argument evaluation (no short-circuiting for mission logging)
- **LogicalOrFunction** (`logical_or_function.gd`) - Logical OR with full argument evaluation
- **LogicalNotFunction** (`logical_not_function.gd`) - Logical NOT for single argument negation  
- **LogicalXorFunction** (`logical_xor_function.gd`) - Logical XOR supporting multiple arguments (odd count = true)

### Comparison Operators
- **EqualsFunction** (`equals_function.gd`) - Equality comparison with WCS-compatible type conversion
- **LessThanFunction** (`less_than_function.gd`) - Less than comparison with multi-argument support
- **GreaterThanFunction** (`greater_than_function.gd`) - Greater than comparison
- **LessThanOrEqualFunction** (`less_than_or_equal_function.gd`) - Less than or equal comparison
- **GreaterThanOrEqualFunction** (`greater_than_or_equal_function.gd`) - Greater than or equal comparison
- **NotEqualsFunction** (`not_equals_function.gd`) - Not equals comparison

### Arithmetic Operators
- **AdditionFunction** (`addition_function.gd`) - Addition with floating-point support (WCS enhancement)
- **SubtractionFunction** (`subtraction_function.gd`) - Subtraction with negation support for single arguments
- **MultiplicationFunction** (`multiplication_function.gd`) - Multiplication with floating-point support
- **DivisionFunction** (`division_function.gd`) - Division with zero-protection (critical WCS improvement)
- **ModuloFunction** (`modulo_function.gd`) - Modulo with zero-protection (critical WCS improvement)

### Conditional Operators
- **IfFunction** (`if_function.gd`) - Conditional branching with optional else clause
- **WhenFunction** (`when_function.gd`) - Conditional execution with implicit progn behavior
- **CondFunction** (`cond_function.gd`) - Multi-branch conditional for complex decision trees

### String Operators
- **StringEqualsFunction** (`string_equals_function.gd`) - Case-sensitive string equality
- **StringContainsFunction** (`string_contains_function.gd`) - Substring search functionality

## Usage Examples

### Basic Operator Usage
```gdscript
# Register all operators
var registry = SexpFunctionRegistry.new()
SexpOperatorRegistration.register_all_operators(registry)

# Execute logical operations
var and_func = registry.get_function("and")
var result = and_func.execute([
    SexpResult.create_boolean(true),
    SexpResult.create_number(1),
    SexpResult.create_string("hello")
])
# Result: true (all arguments are truthy)

# Execute arithmetic with type conversion
var add_func = registry.get_function("+")
result = add_func.execute([
    SexpResult.create_number(5),
    SexpResult.create_string("3"),
    SexpResult.create_boolean(true)
])
# Result: 9.0 (5 + 3 + 1)
```

### Complex Conditional Logic
```gdscript
# Multi-branch conditional
var cond_func = registry.get_function("cond")
result = cond_func.execute([
    SexpResult.create_boolean(false),  # condition 1
    SexpResult.create_string("first"), # expression 1
    SexpResult.create_boolean(true),   # condition 2  
    SexpResult.create_string("second") # expression 2
])
# Result: "second" (first true condition)
```

### Error Handling Examples
```gdscript
# Division by zero protection (WCS improvement)
var div_func = registry.get_function("/")
result = div_func.execute([
    SexpResult.create_number(10),
    SexpResult.create_number(0)
])
# Result: Error with type ARITHMETIC_ERROR
```

## Architecture Notes

### WCS Compatibility
All operators maintain strict compatibility with Wing Commander Saga semantics:
- **Type Conversion**: String-to-number using `atoi()` equivalent, boolean-to-number (true=1, false=0)
- **Multi-Argument Logic**: Comparison operators check first argument against ALL remaining arguments
- **Full Evaluation**: Logical operators evaluate all arguments for mission logging (no short-circuiting)
- **Error Propagation**: Errors in arguments are properly propagated through operator chains

### Critical Improvements Over WCS
1. **Division by Zero Protection**: WCS had NO protection - our implementation returns proper errors
2. **Modulo by Zero Protection**: WCS had NO protection - our implementation returns proper errors  
3. **Floating-Point Support**: WCS used integer-only arithmetic - we support full floating-point
4. **Better Error Messages**: Contextual error reporting with argument position information
5. **Null Argument Handling**: Proper validation and error reporting for null arguments

### Performance Characteristics
- **Logical Operators**: O(n) where n = number of arguments
- **Comparison Operators**: O(n*m) where m = average comparison cost
- **Arithmetic Operators**: O(n) for addition/subtraction/multiplication, O(1) for division/modulo
- **Conditional Operators**: O(1) for condition evaluation + O(branch) for selected branch
- **String Operators**: O(n*m) where n = arguments, m = average string length

### Memory Management
- All operators extend `BaseSexpFunction` with RefCounted base for automatic cleanup
- No memory leaks through proper error handling and result management
- Efficient string handling with minimal temporary allocations
- Cache-friendly implementations for high-frequency operations

## Integration Points

### With Function Registry
All operators are registered through `SexpOperatorRegistration.register_all_operators()`:
- Automatic registration with proper categorization
- Error handling for registration failures
- Statistics tracking for registration success

### With Evaluator Engine
- Direct integration with `SexpEvaluator` for function execution
- Performance statistics collection and optimization
- Error propagation through evaluation pipeline
- Cache coordination for maximum performance

### With Parser System
- Function name validation during parsing phase
- Signature validation for early error detection
- Help integration for development-time assistance

## Testing Notes

### Test Coverage
- **Comprehensive Unit Tests**: All operators tested with valid inputs, edge cases, and error conditions
- **WCS Compatibility Tests**: Behavior verification against original WCS semantics
- **Performance Tests**: Validation of execution speed requirements
- **Integration Tests**: Complex nested expressions and operator combinations
- **Error Handling Tests**: Null arguments, type mismatches, arithmetic errors

### Test Files
- `test_sexp_operators.gd` - Comprehensive operator test suite with 20+ test methods
- Individual operator tests within the main test suite
- Performance benchmarking for high-frequency operations
- Memory usage validation with large operator sets

## Common Patterns

### Type Conversion Implementation
All operators follow consistent type conversion patterns:
```gdscript
func _convert_to_boolean(result: SexpResult) -> bool:
    match result.result_type:
        SexpResult.ResultType.NUMBER:
            return result.get_number_value() != 0.0
        SexpResult.ResultType.STRING:
            var str_val = result.get_string_value()
            return not str_val.is_empty() and str_val.to_float() != 0.0
        # ... other types
```

### Error Handling Pattern
```gdscript
func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
    for i in range(args.size()):
        var arg = args[i]
        if arg == null:
            return SexpResult.create_error("Argument %d is null" % (i + 1))
        if arg.is_error():
            return arg  # Propagate error
```

### Multi-Argument Comparison Pattern
```gdscript
# Compare first argument against ALL others (WCS semantics)
for i in range(1, args.size()):
    var comparison_result = _compare_values(first_arg, args[i])
    if not condition_met(comparison_result):
        return SexpResult.create_boolean(false)
return SexpResult.create_boolean(true)
```

## Error Handling

### Arithmetic Errors
- **Division by Zero**: Returns `ARITHMETIC_ERROR` with descriptive message
- **Modulo by Zero**: Returns `ARITHMETIC_ERROR` with descriptive message
- **Overflow/Underflow**: Handled by Godot's float system

### Type Errors
- **Null Arguments**: Returns `TYPE_MISMATCH` with argument position
- **Invalid Conversions**: Object references cannot convert to numbers
- **Unsupported Types**: Unknown result types handled gracefully

### Validation Errors
- **Argument Count**: Enforced by function framework, not individual operators
- **Type Requirements**: Flexible type acceptance with conversion where possible
- **Range Validation**: Applied where mathematically meaningful

This operators package provides the foundation for all SEXP expression evaluation, maintaining strict WCS compatibility while adding modern safety and performance features. It supports all 18 core operators required for mission logic with comprehensive error handling and type conversion capabilities.