# Ship Weapons Systems Package - SHIP-005

## Purpose
The Ship Weapons Systems package provides comprehensive weapon management, firing control, and targeting systems for the WCS-Godot conversion. This package implements SHIP-005 to deliver authentic WCS weapon behavior with precise timing, energy/ammunition management, and advanced targeting capabilities.

## Implementation Status
**✅ SHIP-005 COMPLETED**: Weapon Manager and Firing System implemented with full WCS-authentic weapon behavior and integration.

## Package Overview

### SHIP-005: Weapon Manager and Firing System
**Status**: ✅ COMPLETED  
**Location**: `scripts/ships/weapons/`

**Key Features**:
- Central weapon system coordination with primary/secondary bank management
- Precise firing timing control with rate limiting and burst fire mechanics
- Energy/ammunition tracking with ETS integration
- Target acquisition with lock-on mechanics and firing solutions
- Weapon selection system with bank cycling and linking modes
- Comprehensive weapon state management and validation

## Key Classes

### WeaponManager
**Purpose**: Central coordinator for all weapon systems on a ship, managing primary/secondary banks and energy/ammunition tracking.

**Location**: `scripts/ships/weapons/weapon_manager.gd`

**Key Features**:
- Primary and secondary weapon bank configuration and management (SHIP-005 AC1)
- Energy Transfer System (ETS) integration for weapon energy management (SHIP-005 AC3)
- Ammunition tracking for missile weapons with rearm processes (SHIP-005 AC4)
- Weapon selection coordination with linking and dual-fire modes (SHIP-005 AC5)
- Target acquisition integration with AI and player systems (SHIP-005 AC6)
- Subsystem integration for weapon health and turret control (SHIP-005 AC7)

**Usage**:
```gdscript
# Initialize weapon manager on ship
var weapon_manager: WeaponManager = WeaponManager.new()
ship.add_child(weapon_manager)
weapon_manager.initialize_weapon_manager(ship)

# Fire weapons
var fired_primary: bool = weapon_manager.fire_primary_weapons()
var fired_secondary: bool = weapon_manager.fire_secondary_weapons()

# Weapon selection
weapon_manager.cycle_weapon_selection(WeaponBankType.Type.PRIMARY, true)
weapon_manager.set_weapon_linking_mode(WeaponBankType.Type.PRIMARY, true)

# Target management
weapon_manager.set_weapon_target(enemy_ship, engine_subsystem)

# Get weapon status
var status: Dictionary = weapon_manager.get_weapon_status()
print("Primary energy: %.1f%%" % status["weapon_energy_percent"])
```

### FiringController
**Purpose**: Handles precise weapon firing timing, rate limiting, and burst fire mechanics with WCS-authentic behavior.

**Location**: `scripts/ships/weapons/firing_controller.gd`

**Key Features**:
- Precise timing control matching WCS millisecond-based firing delays (SHIP-005 AC2)
- Burst fire mechanics with configurable shot counts and intervals
- Projectile creation and positioning with convergence support
- Firing solution application for accuracy and target leading
- Performance optimization with projectile creation limits
- Continuous weapon support for beam weapons

**Usage**:
```gdscript
# Initialize firing controller
var firing_controller: FiringController = FiringController.new()
weapon_manager.add_child(firing_controller)
firing_controller.initialize_firing_controller(ship)

# Fire weapon bank with targeting data
var firing_data: Dictionary = {
    "target": current_target,
    "target_subsystem": target_subsystem,
    "ship_velocity": ship.get_linear_velocity(),
    "firing_solution": targeting_system.get_firing_solution(),
    "convergence_distance": 500.0
}
var fired: bool = firing_controller.fire_weapon_bank(weapon_bank, firing_data)

# Manage firing sequences
firing_controller.start_firing_sequence(WeaponBankType.Type.PRIMARY, primary_banks, "simultaneous")
var is_active: bool = firing_controller.is_firing_sequence_active(WeaponBankType.Type.PRIMARY)
```

### WeaponBank
**Purpose**: Individual weapon bank management with ammunition tracking, heat management, and mount positioning.

**Location**: `scripts/ships/weapons/weapon_bank.gd`

**Key Features**:
- Weapon mounting configuration with position and orientation
- Ammunition tracking for missile weapons with reload capabilities (SHIP-005 AC4)
- Heat management system with overheat prevention and cooling
- Burst fire state tracking and management
- Weapon performance rating for AI decision making
- Energy cost calculation for ETS integration

**Usage**:
```gdscript
# Create and initialize weapon bank
var weapon_bank: WeaponBank = WeaponBank.new()
weapon_bank.initialize_weapon_bank(
    WeaponBankType.Type.PRIMARY,
    0,  # bank index
    weapon_data,
    ship
)

# Configure mount position
weapon_bank.set_mount_configuration(
    Vector3(2.0, 0.5, 1.0),  # position
    Vector3.ZERO,            # orientation
    500.0                    # convergence distance
)

# Check firing capability
if weapon_bank.can_fire():
    var success: bool = weapon_bank.consume_shot()

# Reload ammunition
weapon_bank.reload_ammunition()  # Full reload
weapon_bank.reload_ammunition(10)  # Partial reload

# Get weapon status
var status: Dictionary = weapon_bank.get_weapon_status()
print("Ammunition: %d/%d (%.1f%%)" % [
    status["current_ammunition"],
    status["max_ammunition"],
    status["ammunition_percent"]
])
```

### WeaponSelectionManager
**Purpose**: Manages weapon selection, bank cycling, linking modes, and convergence settings.

**Location**: `scripts/ships/weapons/weapon_selection_manager.gd`

**Key Features**:
- Weapon bank selection with validation and automatic available weapon detection
- Bank cycling with forward/backward navigation (SHIP-005 AC5)
- Weapon linking modes for firing multiple banks of same weapon type
- Dual-fire mode support for simultaneous primary/secondary firing
- Convergence distance management for weapon accuracy
- Selection state persistence and refresh capabilities

**Usage**:
```gdscript
# Initialize selection manager
var selection_manager: WeaponSelectionManager = WeaponSelectionManager.new()
selection_manager.initialize_selection_manager(primary_banks, secondary_banks)

# Weapon selection
selection_manager.select_weapon_bank(WeaponBankType.Type.PRIMARY, 1)
selection_manager.cycle_weapon_selection(WeaponBankType.Type.SECONDARY, true)

# Linking modes
selection_manager.set_weapon_linking_mode(WeaponBankType.Type.PRIMARY, true)
selection_manager.set_dual_fire_mode(true)

# Get selected banks
var primary_banks: Array[int] = selection_manager.get_selected_primary_banks()
var secondary_banks: Array[int] = selection_manager.get_selected_secondary_banks()

# Convergence settings
selection_manager.set_convergence_distance(WeaponBankType.Type.PRIMARY, 400.0)

# Selection status
var status: Dictionary = selection_manager.get_selection_status()
var weapon_names: Array[String] = selection_manager.get_available_weapon_names(WeaponBankType.Type.PRIMARY)
```

### TargetingSystem
**Purpose**: Advanced target acquisition with lock-on mechanics, lead calculation, and firing solution computation.

**Location**: `scripts/ships/weapons/targeting_system.gd`

**Key Features**:
- Target acquisition with range and angle constraints (SHIP-005 AC6)
- Lock-on mechanics with strength tracking and acquisition time
- Motion prediction with velocity and acceleration tracking
- Firing solution calculation with lead vectors and accuracy modifiers
- Line of sight validation with obstacle detection
- Performance optimization with configurable update frequency

**Usage**:
```gdscript
# Initialize targeting system
var targeting_system: TargetingSystem = TargetingSystem.new()
weapon_manager.add_child(targeting_system)
targeting_system.initialize_targeting_system(ship)

# Set target
targeting_system.set_target(enemy_ship, engine_subsystem)

# Check targeting state
var has_lock: bool = targeting_system.has_target_lock()
var lock_strength: float = targeting_system.get_lock_strength()

# Get firing solution
var solution: Dictionary = targeting_system.get_firing_solution()
var lead_vector: Vector3 = solution["lead_vector"]
var accuracy: float = solution["accuracy_modifier"]
var time_to_target: float = solution["time_to_target"]

# Configure targeting constraints
targeting_system.set_targeting_constraints(8000.0, 60.0)  # max range, max angle
targeting_system.set_subsystem_targeting_enabled(true)

# Targeting status
var status: Dictionary = targeting_system.get_targeting_status()
```

## WCS Reference Implementation

### Weapon Bank Types and Management
Exactly matches WCS weapon bank organization:

**Primary Weapons (Energy-based)**:
- Unlimited ammunition using ship weapon energy
- Rate limiting based on weapon fire_rate property
- Energy consumption integrated with ETS allocation
- Heat generation and overheat mechanics

**Secondary Weapons (Ammunition-based)**:
- Limited ammunition with reload/rearm capability
- Missile guidance and tracking integration
- Launch energy cost for firing mechanisms
- Burst fire support for multi-shot weapons

**Beam Weapons**:
- Continuous fire mechanics for sustained damage
- High energy consumption with slower heat dissipation
- Special targeting requirements for beam accuracy

**Turret Weapons**:
- Independent targeting with subsystem AI integration
- Mount-specific positioning and orientation
- Mixed energy/ammunition types based on weapon class

### Energy Transfer System Integration
Full integration with ship ETS for weapon energy management:

**Energy Allocation**:
```gdscript
# ETS weapon allocation affects energy regeneration
var weapon_allocation: float = ship.get_weapon_energy_allocation()  # 0.0 to 1.0
var actual_regen_rate: float = base_regen_rate * weapon_allocation

# Energy consumption for primary weapons
var energy_cost: float = weapon_bank.get_energy_cost()
ship.consume_weapon_energy(energy_cost)
```

**Weapon Energy States**:
- Weapon energy separate from ship hull/engine energy
- Regeneration rate affected by ETS allocation
- Low energy warnings and firing restrictions
- Energy distribution among weapon banks

### Firing Timing and Rate Limiting
Precise replication of WCS weapon timing mechanics:

**Rate Limiting**:
```gdscript
# WCS-accurate rate limiting
var fire_rate: float = weapon_data.fire_rate  # shots per second
var required_interval: float = 1.0 / fire_rate
var time_since_last_fire: float = current_time - last_fire_time
var can_fire: bool = time_since_last_fire >= required_interval
```

**Burst Fire Mechanics**:
- Multi-shot weapons fire in rapid succession
- Configurable burst delays between shots
- Burst completion tracking and cooldown periods

### Target Acquisition and Lock-On
Advanced targeting system matching WCS mechanics:

**Lock-On Mechanics**:
- Progressive lock strength building over time
- Range and angle constraints for lock acquisition
- Line of sight validation with obstacle detection
- Lock degradation when constraints not met

**Firing Solutions**:
- Lead calculation for moving targets
- Accuracy modifiers based on range, movement, and lock strength
- Time-to-target calculation for projectile interception
- Subsystem targeting with precision positioning

## Integration Points

### BaseShip Integration
```gdscript
# WeaponManager integrates with BaseShip systems
weapon_manager.initialize_weapon_manager(ship)

# ETS integration for energy management
var weapon_energy: float = ship.current_weapon_energy
var energy_allocation: float = ship.get_weapon_energy_allocation()

# Subsystem integration for weapon health
var weapon_performance: float = ship.get_subsystem_performance("weapons")
```

### AI System Integration
```gdscript
# AI uses weapon manager for automated combat
var can_fire_primary: bool = weapon_manager.fire_primary_weapons()
var weapon_range: float = weapon_bank.get_effective_range()
var weapon_rating: float = weapon_bank.get_weapon_performance_rating()

# Targeting integration with AI target selection
targeting_system.set_target(ai_selected_target)
var firing_solution: Dictionary = targeting_system.get_firing_solution()
```

### Player Control Integration
```gdscript
# Player input processed through weapon manager
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("fire_primary"):
        weapon_manager.fire_primary_weapons()
    
    if event.is_action_pressed("fire_secondary"):
        weapon_manager.fire_secondary_weapons()
    
    if event.is_action_pressed("cycle_primary"):
        weapon_manager.cycle_weapon_selection(WeaponBankType.Type.PRIMARY)
    
    if event.is_action_pressed("link_primary"):
        var current_linked: bool = weapon_manager.selection_manager.is_primary_weapons_linked()
        weapon_manager.set_weapon_linking_mode(WeaponBankType.Type.PRIMARY, not current_linked)
```

### HUD System Integration
```gdscript
# Weapon status for HUD display
var weapon_status: Dictionary = weapon_manager.get_weapon_status()

# Primary weapon info
var primary_weapons: Array = weapon_status["primary_weapons"]
for weapon_info in primary_weapons:
    var ammo_percent: float = weapon_info["ammunition_percent"]
    var heat_percent: float = weapon_info["heat_percent"]
    hud.update_weapon_display(weapon_info["weapon_name"], ammo_percent, heat_percent)

# Target lock display
var targeting_status: Dictionary = targeting_system.get_targeting_status()
var lock_strength: float = targeting_status["lock_strength"]
hud.update_target_lock_display(lock_strength)
```

### VFX and Audio Integration
```gdscript
# Weapon firing effects
weapon_manager.weapon_fired.connect(_on_weapon_fired)

func _on_weapon_fired(bank_type: WeaponBankType.Type, weapon_name: String, projectiles: Array[WeaponBase]) -> void:
    for projectile in projectiles:
        # Create muzzle flash effect
        effects_manager.create_muzzle_flash(projectile.global_position, weapon_name)
        
        # Play weapon sound
        audio_manager.play_weapon_sound(weapon_name, projectile.global_position)
```

## Performance Considerations

### Weapon Bank Management
- Efficient weapon bank lookup with indexed access
- Minimal memory allocation during firing operations
- Weapon bank pooling for frequently spawned projectiles
- Performance tracking for firing system optimization

### Targeting System Optimization
- Configurable update frequency for targeting calculations
- Cached firing solutions with time-based invalidation
- Efficient line of sight checks with spatial optimization
- Motion prediction using smooth interpolation

### Projectile Creation Limits
- Per-frame projectile creation limits for performance
- Object pooling for projectile reuse
- Spatial culling for distant projectiles
- LOD system for visual effects

### Memory Management
- Minimal per-weapon memory overhead
- Efficient signal connections managed by Godot
- Cached calculations with automatic invalidation
- Resource sharing across weapon banks

## Testing Coverage

### SHIP-005 Test Suite
**Location**: `tests/test_ship_005_weapon_manager_firing.gd`

**Coverage**: All 7 acceptance criteria with comprehensive test scenarios:
- **AC1**: Primary/secondary bank management and state tracking
- **AC2**: Firing system timing control and rate limiting
- **AC3**: Energy management and ETS integration
- **AC4**: Ammunition tracking and rearm processes
- **AC5**: Weapon selection and linking validation
- **AC6**: Target acquisition and firing solutions
- **AC7**: Subsystem integration and turret control

**Test Categories**:
- Unit tests for each weapon system component
- Integration tests for ship weapon coordination
- Performance tests for firing system efficiency
- Accuracy tests for WCS behavior matching
- Error handling tests for edge cases

## Architecture Notes

### Design Principles
1. **Component Separation**: Clear separation between management, firing, selection, and targeting
2. **WCS Authenticity**: Exact replication of WCS weapon timing and behavior
3. **Performance Focus**: Optimize for large-scale combat scenarios
4. **Signal-Driven**: Extensive use of signals for loose coupling
5. **Modular Design**: Components can be used independently or together

### Integration Architecture
- **WeaponManager**: Central coordinator interfacing with ship systems
- **FiringController**: Handles actual projectile creation and timing
- **WeaponBank**: Individual weapon state and configuration management
- **WeaponSelectionManager**: Player/AI weapon selection interface
- **TargetingSystem**: Advanced targeting calculations and lock-on mechanics

### Future Extensions
The weapon system supports future enhancements:
- Advanced weapon AI with learning capabilities
- Dynamic weapon modification and upgrade systems
- Multiplayer weapon synchronization
- Weapon crafting and customization systems
- Advanced ballistics simulation with environmental effects

This comprehensive implementation successfully delivers SHIP-005 with full WCS compatibility while providing a robust foundation for all ship combat scenarios in the WCS-Godot conversion.