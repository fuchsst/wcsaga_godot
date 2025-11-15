# Wing Commander Saga Resource System

## Overview

The Wing Commander Saga Resource System provides a comprehensive, data-driven architecture for managing game entities through Godot's Custom Resource system. This system maps WCS table data to native Godot resources with full validation, cross-reference resolution, and performance optimization.

## Resource Class Hierarchy

### Base Classes

#### WCSBaseResource
- **File**: `target/scripts/resources/wcs_base_resource.gd`
- **Purpose**: Abstract base class providing common functionality
- **Features**:
  - Metadata tracking (source files, version, conversion info)
  - Validation system with error/warning reporting
  - Cross-reference resolution and dependency management
  - Caching system with TTL support
  - Performance monitoring
  - Dictionary serialization/deserialization

### Specialized Resource Classes

#### ShipStats
- **File**: `target/scripts/resources/ship_stats.gd`
- **Purpose**: Complete ship configuration from ships.tbl data
- **Key Properties**:
  - Identity: ship_class, display_name, ship_role, species
  - Physics: max_velocity, rotation_time, mass, dimensions
  - Systems: shields, armor, weapons, energy, afterburners
  - AI: aggressiveness, skill_level, reaction_time, optimal_range
  - Subsystems: engines, weapons, shields with hitpoint tracking
- **Nested Classes**:
  - `WeaponMount`: Detailed weapon mount specifications
  - `EngineSubsystem`, `WeaponSubsystem`, `ShieldSubsystem`
  - `TurretMount`: Turret configuration data

#### WeaponData
- **File**: `target/scripts/resources/weapon_data.gd`
- **Purpose**: Complete weapon configuration from weapons.tbl
- **Key Properties**:
  - Identity: weapon_class, display_name, manufacturer_species
  - Physics: projectile_mass, velocity, range, lifetime
  - Damage: base_damage, penetration factors, surface multipliers
  - Targeting: homing systems, guidance packages, lock parameters
  - Visual Effects: muzzle flash, projectile, impact effects
- **Advanced Features**:
  - Physics-based damage calculation
  - Surface-specific damage multipliers
  - Homing missile behavior modeling
  - Burst fire and multi-shot patterns

#### SpeciesData
- **File**: `target/scripts/resources/species_data.gd`
- **Purpose**: Faction/Species configuration from Species_defs.tbl
- **Key Properties**:
  - Identity: species_name, mnemonic, government_type, home_world
  - Military: doctrine, fleet_composition, preferred_combat_range
  - Technology: shield/armor/engine/sensor development levels
  - Diplomacy: IFF status, alliance demands, betrayal tolerance
  - Economics: resource efficiency, production multipliers
- **Strategic Analysis**:
  - Military strength calculation
  - Economic capability scoring
  - Technology advancement assessment
  - AI personality type determination

#### AsteroidData
- **File**: `target/scripts/resources/asteroid_data.gd`
- **Purpose**: Asteroid field and debris configuration
- **Key Properties**:
  - Field Properties: density, size distribution, movement patterns
  - Collision Physics: damage scaling, momentum transfer
  - Mining: mineral composition, extraction yields, equipment requirements
  - Hazards: radiation, electromagnetic interference
  - Performance: LOD distances, physics complexity levels

#### NebulaData
- **File**: `target/scripts/resources/nebula_data.gd`
- **Purpose**: Space weather and environmental effects
- **Key Properties**:
  - Basic Properties: density, opacity, chemical composition
  - Ship Impact: velocity reduction, shield interference, weapon range
  - Sensors: radar degradation, target lock difficulty, stealth bonuses
  - Severe Effects: sensor blackout, shield draining, weapon malfunctions
  - Tactical: ambush effectiveness, pursuit difficulty, concealment

## Resource Management Architecture

### WCSResourceManager
- **File**: `target/scripts/resource_loaders/wcs_resource_manager.gd`
- **Role**: Central coordinator for resource loading and validation
- **Key Features**:
  - Background loading queue with priority system
  - Intelligent caching with memory management
  - Cross-reference dependency resolution
  - Performance monitoring and metrics
  - Validation on load with detailed error reporting
  - Resource hot-reloading support

### Caching System
- **Cache Hit Rate Tracking**: Percentage of requests served from cache
- **Memory Management**: Automatic cleanup of oldest entries
- **TTL Support**: Time-based expiration for cache entries
- **Dependency Awareness**: Clears dependent resources when dependencies change

### Cross-Reference Resolution
- **Automatic Dependency Tracking**: Maps relationships between resources
- **Validation Integration**: Resolves references during resource validation
- **Error Reporting**: Identifies unresolved references
- **Circular Reference Prevention**: Detects and reports circular dependencies

## Validation System

### Property Validation
All resources implement comprehensive property validation:
- Type checking with defined constraints
- Range validation for numeric properties
- Cross-reference existence verification
- Dependency consistency checking
- Data integrity checksum validation

### Error Severity Levels
- **Critical Errors**: Prevent resource usage (validation fails)
- **Warnings**: Indicate potential issues but allow usage
- **Performance Warnings**: Signal performance concerns

### Validation Reports
Resources provide detailed validation summaries:
- Error count and specific error messages
- Warning count and descriptions
- Performance metrics
- Cross-reference resolution status

## Performance Optimization

### Metrics Collection
- Load time tracking by resource type
- Cache hit/miss rate analysis
- Memory usage estimation
- Validation performance monitoring

### Memory Management
- Automatic cache cleanup based on size limits
- Dependency-aware garbage collection
- Resource compression for large datasets
- Progressive loading for background resources

### Background Loading
- Priority-based loading queue
- Frame time budgeting for smooth operation
- Concurrent resource loading
- State monitoring and progress reporting

## Usage Examples

### Basic Resource Loading
```gdscript
# Get resource manager
var resource_manager = get_node("/root/WCSResourceManager")

# Load specific resource
var ship_stats = resource_manager.get_ship_by_class("F-86C Hellcat V")
var weapon_data = resource_manager.get_weapon_by_class("@Ion")
var species = resource_manager.get_species_by_mnemonic("TERRAN")

# Access nested properties
var ship_shields = ship_stats.shield_strength
var weapon_damage = weapon_data.get_damage_per_second()
var species_strength = species.calculate_military_strength()
```

### Custom Resource Creation
```gdscript
# Create and configure a ShipStats resource
var new_ship = ShipStats.new()
new_ship.ship_class = "F-99X Experimental"
new_ship.display_name = "Experimental Fighter"
new_ship.max_velocity = Vector3(0, 0, 100.0)
new_ship.shield_strength = 1500

# Validate the resource
if new_ship.validate():
    print("Ship configuration is valid!")
else:
    for error in new_ship.validation_errors:
        print("Validation error: " + error)
```

### Cross-Reference Resolution
```gdscript
# Let the manager resolve cross-references
resource_manager.resolve_all_cross_references()

# Check resolution status
var unresolved = resource_manager.unresolved_references
if unresolved.size() > 0:
    print("Unresolved references: " + str(unresolved))
```

### Performance Monitoring
```gdscript
# Get performance metrics
var performance = resource_manager.get_performance_summary()
print("Cache hit rate: %.1f%%" % (performance["cache_hit_rate"] * 100))
print("Total resources loaded: %d" % performance["total_resources_loaded"])

# Get validation summary
var validation = resource_manager.get_validation_summary()
print("Validation errors: %d" % validation["total_errors"])
```

## Testing and Validation

### Test Suite
The resource system includes comprehensive test coverage:
- **Unit Tests**: Individual resource validation
- **Integration Tests**: Cross-reference resolution
- **Performance Tests**: Load time and memory usage
- **Edge Case Tests**: Invalid data handling

### Test File Locations
- Base tests: `target/tests/test_resource_validation.gd`
- Resource manager tests: Part of manager implementation
- Performance tests: Integration with WCSResourceManager

### Validation Coverage
- All @export properties validated
- Cross-reference integrity verified
- Type safety enforced
- Performance constraints validated
- Memory usage monitored

## Integration with WCS Data

### TBL File Mapping
Resources directly map to WCS table data:
- **Ships**: All properties from ships.tbl
- **Weapons**: Complete weapons.tbl data
- **Species**: Species_defs.tbl information
- **Environmental**: Environment-specific configurations

### Conversion Process
- Original TBL parsing via Python tools
- Transformed to Godot CustomResource format
- Validation during conversion process
- Cross-reference establishment

### Data Integrity Features
- Checksum validation for converted data
- Conversion metadata tracking
- Source file reference preservation
- Version control integration

## Error Handling and Debugging

### Error Categories
1. **Loading Errors**: Resource not found, corrupted data
2. **Validation Errors**: Property constraints violated
3. **Cross-Reference Errors**: Dependencies not resolvable
4. **Performance Errors**: Exceeding time/memory limits

### Debugging Tools
- Comprehensive error logging
- Performance warning system
- Validation summary reports
- Resource dependency visualization
- Memory usage estimation

### Diagnostic Commands
```bash
# Generate system report
make godot-run-script target/scripts/resource_loaders/wcs_resource_manager.gd --report

# Validate all resources
make godot-run-script target/tests/test_resource_validation.gd

# Performance analysis
make godot-run-script target/scripts/resource_loaders/wcs_resource_manager.gd --performance
```

## Best Practices

### Resource Design
1. **Use nested resources** for complex data structures
2. **Implement proper validation** for all properties
3. **Provide clear documentation** for @export properties
4. **Handle edge cases gracefully** in validation methods

### Performance Optimization
1. **Enable caching** for frequently accessed resources
2. **Use background loading** for non-critical resources
3. **Monitor memory usage** with built-in metrics
4. **Implement resource pooling** for dynamic objects

### Cross-Reference Management
1. **Add references explicitly** using dependency system
2. **Validate cross-references** during resource updates
3. **Handle circular references** appropriately
4. **Document dependency relationships**

## Migration and Future Enhancements

### Planned Improvements
- **Async Resource Loading**: Non-blocking resource access
- **Resource Compression**: Advanced compression algorithms
- **Distributed Loading**: Multi-core resource processing
- **Real-time Updates**: Hot-reloading resource changes

### Backward Compatibility
- Resource format versioning system
- Migration tools for data updates
- Legacy support mode
- Gradual deprecation warnings

This resource system provides the foundation for data-driven game development in Wing Commander Saga, ensuring authentic gameplay while leveraging Godot's powerful Resource system for flexibility, performance, and maintainability.