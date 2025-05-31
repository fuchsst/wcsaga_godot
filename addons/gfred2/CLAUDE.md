# GFRED2 Mission Editor - Agent Guidance

## Package Purpose
Modern FRED2-style mission editor as Godot plugin integrating WCS asset management (EPIC-002) and SEXP systems (EPIC-004). Provides visual mission creation with scene-based UI architecture.

## Architecture Reference
- **Main Architecture**: `.ai/docs/epic-005-gfred2-mission-editor/architecture.md`
- **Dependencies**: `.ai/docs/epic-005-gfred2-mission-editor/godot-dependencies.md`
- **File Structure**: `.ai/docs/epic-005-gfred2-mission-editor/godot-files.md`

## Core Integration Points

### EPIC-002 Asset Integration
```gdscript
# Direct asset access - no wrappers
var ship_data: ShipData = WCSAssetLoader.load_asset(ship_path)
var assets: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
```

### EPIC-004 SEXP Integration  
```gdscript
# Direct SEXP system access
var is_valid: bool = SexpManager.validate_syntax(expression)
var errors: Array[String] = SexpManager.get_validation_errors(expression)
```

## Critical Architecture Rules (NON-NEGOTIABLE)

### Scene-Based UI Only
- **ALL UI components MUST be scenes (.tscn files)**
- **NO programmatic UI construction allowed**
- **Scripts attach to scene root nodes as controllers**
- See Architecture Section 3 for mandatory patterns

### Folder Organization
```
addons/gfred2/
├── scenes/                    # CENTRALIZED SCENE-BASED UI (ALL .tscn files)
│   ├── docks/                 # Editor dock scenes (.tscn files)
│   │   ├── main_editor_dock.tscn
│   │   ├── asset_browser_dock.tscn  
│   │   ├── sexp_editor_dock.tscn
│   │   ├── object_inspector_dock.tscn
│   │   ├── validation_dock.tscn
│   │   └── performance_profiler_dock.tscn
│   ├── dialogs/               # Modal dialog scenes (.tscn files)
│   │   ├── base_dialog.tscn
│   │   ├── mission_settings_dialog.tscn
│   │   ├── object_creation_dialog.tscn
│   │   ├── briefing_editor/   # Briefing editor dialog scenes
│   │   └── template_library/  # Template library scenes
│   ├── components/            # Reusable UI component scenes (.tscn files)
│   │   ├── property_editors/  # Property editing component scenes
│   │   ├── validation_indicator.tscn
│   │   ├── dependency_graph_view.tscn
│   │   ├── pattern_browser/   # Pattern browser component scenes
│   │   └── performance_monitor.tscn
│   ├── gizmos/                # 3D viewport gizmo scenes (.tscn files)
│   │   ├── base_gizmo.tscn
│   │   ├── object_transform_gizmo.tscn
│   │   └── selection_indicator.tscn
│   └── overlays/              # Viewport overlay scenes (.tscn files)
│       ├── viewport_overlay.tscn
│       ├── object_labels.tscn
│       └── grid_display.tscn
├── scripts/                   # Business logic scripts (controllers only, NO UI construction)
│   ├── controllers/           # Scene controllers (.gd files attached to .tscn roots)
│   ├── utilities/             # Business logic utilities (non-UI)
│   └── managers/              # Data management scripts (non-UI)
├── core/                      # Mission data management (non-UI logic)
├── object_management/         # Mission object lifecycle management
├── validation/                # Validation logic (non-UI)
├── integration/               # System integration points (non-UI)
└── tests/                     # gdUnit4 test suites (extends GdUnitTestSuite)
    ├── scene/                 # Scene-based UI tests
    ├── integration/           # Integration tests
    ├── performance/           # Performance tests  
    └── ui/                    # UI component tests
```

### Performance Requirements
- Scene instantiation: < 16ms per component
- UI updates: Batched at 60 FPS
- Real-time validation: < 5ms for standard expressions
- Mission handling: 100+ SEXP expressions at >60 FPS

### Testing Requirements (gdUnit4)
- **ALL new functionality MUST have gdUnit4 tests**
- **Test classes extend GdUnitTestSuite**
- **Run tests**: `target/addons/gdUnit4/runtest.sh` or project menu
- **Test organization**:
  - `tests/scene/`: Scene-based UI component tests
  - `tests/integration/`: EPIC integration tests (asset, SEXP systems)
  - `tests/performance/`: Performance benchmark tests
  - `tests/ui/`: UI interaction and workflow tests
- **Coverage target**: >80% for all business logic scripts

## Integration Architecture

### Mission Data Flow
```gdscript
# Mission loading with EPIC-004 validation
func load_mission_data(mission_data: MissionData):
    for event in mission_data.events:
        if event.condition_sexp:
            var is_valid: bool = SexpManager.validate_syntax(event.condition_sexp)
            if not is_valid:
                _report_validation_errors(SexpManager.get_validation_errors(event.condition_sexp))
```

### Asset Browser Integration
```gdscript
# Direct EPIC-002 asset browsing
func populate_asset_browser():
    var ship_paths: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
    for ship_path in ship_paths:
        var ship_data: ShipData = WCSAssetLoader.load_asset(ship_path)
        asset_browser.add_asset_item(ship_data.ship_name, ship_path)
```

## Key Components

### VisualSexpEditor
**Purpose**: Scene-based SEXP editor with EPIC-004 integration  
**Scene**: `scenes/components/sexp_tree_panel.tscn`  
**Performance**: Real-time validation <5ms, 400+ function support

### MissionEditorDock  
**Purpose**: Main editing interface scene  
**Scene**: `scenes/docks/main_editor_dock.tscn`  
**Features**: 3D viewport, object hierarchy, property editing

### AssetBrowserDock
**Purpose**: Asset browsing scene using EPIC-002 system  
**Scene**: `scenes/docks/asset_browser_dock.tscn`  
**Integration**: Direct WCSAssetRegistry access

## Testing Strategy (gdUnit4)

### Test Structure (ALL tests extend GdUnitTestSuite)
```gdscript
# Example: Scene-based UI test
extends GdUnitTestSuite

func test_main_editor_dock_instantiation():
    var dock_scene = preload("res://addons/gfred2/scenes/docks/main_editor_dock.tscn")
    var dock_instance = dock_scene.instantiate()
    assert_not_null(dock_instance)
    assert_that(dock_instance).is_instance_of(Control)

# Example: Integration test
func test_sexp_addon_integration():
    # Verify direct SEXP system access
    var expression = "(is-destroyed \"Alpha 1\")"
    var is_valid: bool = SexpManager.validate_syntax(expression)
    assert_bool(is_valid).is_true()
    assert_not_null(sexp_editor.sexp_manager)
    var is_valid = SexpManager.validate_syntax("(+ 1 2)")
    assert_true(is_valid)

func test_wcs_asset_strucutres_addon_integration():
    # Verify direct asset system access
    var assets = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
    assert_true(assets.size() > 0)
```

### Run Tests
```bash
# From target directory
bash addons/gdUnit4/runtest.sh -a addons/gfred2/tests/
```

## Common Patterns

### Scene Controller Pattern
```gdscript
# scene_controller.gd (attached to scene root)
class_name SceneController
extends Control

@onready var child_component: ChildType = $ChildPath
signal component_action(data: Dictionary)

func _ready() -> void:
    _setup_ui_connections()
    _initialize_component_state()
```

### Signal-Based Communication
```gdscript
# Loose coupling between components
signal mission_object_selected(object: MissionObject)
signal validation_status_changed(is_valid: bool, errors: Array[String])
```

## Implementation Notes

### Direct System Access
- Use core systems directly (no wrapper layers)
- Leverage existing `addons/wcs_converter` legacy file utilities, `addons/wcs_assets_core` constants, assets and data structures, `addons/sexp` S-Expression framework
- Follow Godot scene composition patterns
- Maintain performance requirements throughout

### Scene Implementation
1. Create scene file first
2. Attach script to scene root as controller
3. Use scene composition for complex components
4. Test functionality
