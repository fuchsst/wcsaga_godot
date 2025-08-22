#!/usr/bin/env python3
"""
Godot Scene Generator - EPIC-003 DM-007 Implementation

Generates Godot .tscn scene files with proper node hierarchy representing
mission layout and object relationships from parsed FS2 mission data.
"""

import json
import logging
from dataclasses import asdict, dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from .fs2_mission_parser import (MissionData, MissionObject, MissionWaypoint,
                                 MissionWing, ObjectType)


class GodotNodeType(Enum):
    """Godot node types for mission objects."""
    NODE3D = "Node3D"
    RIGIDBODY3D = "RigidBody3D"
    STATICBODY3D = "StaticBody3D"
    CHARACTERBODY3D = "CharacterBody3D"
    AREA3D = "Area3D"
    MARKER3D = "Marker3D"
    PATH3D = "Path3D"
    PATHFOLLOW3D = "PathFollow3D"


@dataclass
class GodotNode:
    """Represents a Godot scene node."""
    name: str
    type: str
    parent: Optional[str] = None
    position: Tuple[float, float, float] = (0.0, 0.0, 0.0)
    rotation: Tuple[float, float, float] = (0.0, 0.0, 0.0)
    scale: Tuple[float, float, float] = (1.0, 1.0, 1.0)
    script: Optional[str] = None
    groups: List[str] = []
    properties: Dict[str, Any] = {}
    
    def __post_init__(self):
        if self.groups is None:
            self.groups = []
        if self.properties is None:
            self.properties = {}


@dataclass
class GodotScene:
    """Represents a complete Godot scene."""
    format: int = 3  # Godot 4.x format
    root_node: Optional[GodotNode] = None
    nodes: List[GodotNode] = []
    connections: List[Dict[str, Any]] = []
    
    def __post_init__(self):
        if self.nodes is None:
            self.nodes = []
        if self.connections is None:
            self.connections = []


class GodotSceneGenerator:
    """Generates Godot scene files from FS2 mission data."""
    
    def __init__(self) -> None:
        """Initialize scene generator."""
        self.logger = logging.getLogger(__name__)
        
        # WCS to Godot coordinate system conversion
        # WCS: X=right, Y=up, Z=forward (right-handed)
        # Godot: X=right, Y=up, Z=back (right-handed, but Z is inverted)
        self.coord_scale = 0.01  # Convert WCS units to Godot meters
        
        # Ship class to node type mapping
        self.ship_class_node_mapping = {
            'fighter': GodotNodeType.CHARACTERBODY3D,
            'bomber': GodotNodeType.CHARACTERBODY3D,
            'cruiser': GodotNodeType.CHARACTERBODY3D,
            'freighter': GodotNodeType.CHARACTERBODY3D,
            'transport': GodotNodeType.CHARACTERBODY3D,
            'capital': GodotNodeType.RIGIDBODY3D,
            'supercap': GodotNodeType.RIGIDBODY3D,
            'installation': GodotNodeType.STATICBODY3D,
            'navbuoy': GodotNodeType.STATICBODY3D,
            'support': GodotNodeType.CHARACTERBODY3D,
            'sentry gun': GodotNodeType.STATICBODY3D,
            'escape pod': GodotNodeType.RIGIDBODY3D,
            'cargo': GodotNodeType.RIGIDBODY3D,
            'asteroid': GodotNodeType.RIGIDBODY3D
        }
    
    def generate_mission_scene(self, mission_data: MissionData, output_path: Path, 
                              asset_base_path: str = "res://") -> bool:
        """Generate complete Godot scene from mission data."""
        try:
            self.logger.info(f"Generating Godot scene: {mission_data.mission_info.name}")
            
            # Create scene structure
            scene = self._create_scene_structure(mission_data, asset_base_path)
            
            # Write scene file
            scene_content = self._generate_scene_file_content(scene)
            
            # Ensure output directory exists
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(scene_content)
            
            self.logger.info(f"Generated scene file: {output_path}")
            
            # Note: Using generic MissionController, no need for custom script generation
            
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to generate scene: {e}")
            return False
    
    def _create_scene_structure(self, mission_data: MissionData, asset_base_path: str) -> GodotScene:
        """Create hierarchical scene structure from mission data."""
        scene = GodotScene()
        
        # Create root mission node using generic MissionController
        mission_name = self._sanitize_node_name(mission_data.mission_info.name or "Mission")
        root_node = GodotNode(
            name=mission_name,
            type="MissionController",  # Use generic mission controller
            script=f"{asset_base_path}scripts/missions/mission_controller.gd",
            properties={
                "mission_resource_path": f"res://resources/missions/{mission_name}.tres",
                "auto_start_mission": True,
                "debug_mode": False
            }
        )
        scene.root_node = root_node
        scene.nodes.append(root_node)
        
        # Create organizational containers (will be created by MissionController)
        ships_container = GodotNode(
            name="Ships",
            type=GodotNodeType.NODE3D.value,
            parent=root_node.name
        )
        scene.nodes.append(ships_container)
        
        wings_container = GodotNode(
            name="Wings", 
            type=GodotNodeType.NODE3D.value,
            parent=root_node.name
        )
        scene.nodes.append(wings_container)
        
        waypoints_container = GodotNode(
            name="Waypoints",
            type=GodotNodeType.NODE3D.value,
            parent=root_node.name
        )
        scene.nodes.append(waypoints_container)
        
        # Note: Ships, wings, and waypoints are now created from resources by MissionController
        # No need to create individual nodes here - they'll be spawned at runtime
        
        return scene
    
    def _create_ship_node(self, obj: MissionObject, parent_name: str, asset_base_path: str) -> GodotNode:
        """Create ship node from mission object."""
        # Determine appropriate node type based on ship class
        node_type = self._get_ship_node_type(obj.class_name)
        
        # Convert WCS coordinates to Godot
        godot_position = self._convert_wcs_coordinates(obj.position)
        godot_rotation = self._convert_wcs_orientation(obj.orientation)
        
        # Create ship node
        ship_node = GodotNode(
            name=self._sanitize_node_name(obj.name),
            type=node_type.value,
            parent=parent_name,
            position=godot_position,
            rotation=godot_rotation,
            groups=["ships", obj.team.lower()],
            properties={
                "ship_class": obj.class_name,
                "team": obj.team,
                "ai_class": obj.ai_class,
                "cargo": obj.cargo,
                "initial_velocity": obj.initial_velocity,
                "initial_hull": obj.initial_hull,
                "initial_shields": obj.initial_shields,
                "arrival_location": obj.arrival_location,
                "arrival_distance": obj.arrival_distance,
                "arrival_anchor": obj.arrival_anchor,
                "departure_location": obj.departure_location,
                "departure_anchor": obj.departure_anchor,
                "orders": obj.orders,
                "goals": obj.goals,
                "subsystem_status": obj.subsystem_status
            }
        )
        
        # Add model reference if available
        model_path = f"{asset_base_path}models/{obj.class_name.lower().replace(' ', '_')}.glb"
        ship_node.properties["model_path"] = model_path
        
        return ship_node
    
    def _create_wing_node(self, wing: MissionWing, parent_name: str) -> GodotNode:
        """Create wing node from mission wing."""
        wing_node = GodotNode(
            name=self._sanitize_node_name(wing.name),
            type=GodotNodeType.NODE3D.value,
            parent=parent_name,
            groups=["wings"],
            properties={
                "num_waves": wing.num_waves,
                "threshold": wing.threshold,
                "arrival_location": wing.arrival_location,
                "arrival_distance": wing.arrival_distance,
                "arrival_anchor": wing.arrival_anchor,
                "departure_location": wing.departure_location,
                "departure_anchor": wing.departure_anchor,
                "ships": wing.ships,
                "arrival_cue": wing.arrival_cue,
                "departure_cue": wing.departure_cue,
                "orders": wing.orders,
                "goals": wing.goals
            }
        )
        
        return wing_node
    
    def _create_waypoint_node(self, waypoint: MissionWaypoint, parent_name: str) -> GodotNode:
        """Create waypoint node from mission waypoint."""
        godot_position = self._convert_wcs_coordinates(waypoint.position)
        
        waypoint_node = GodotNode(
            name=self._sanitize_node_name(waypoint.name),
            type=GodotNodeType.MARKER3D.value,
            parent=parent_name,
            position=godot_position,
            groups=["waypoints", f"list_{waypoint.list_name}"],
            properties={
                "list_name": waypoint.list_name,
                "waypoint_index": waypoint.name.split('_')[-1] if '_' in waypoint.name else "0"
            }
        )
        
        return waypoint_node
    
    def _get_ship_node_type(self, ship_class: str) -> GodotNodeType:
        """Determine appropriate Godot node type for ship class."""
        ship_class_lower = ship_class.lower()
        
        # Check for specific matches first
        for class_keyword, node_type in self.ship_class_node_mapping.items():
            if class_keyword in ship_class_lower:
                return node_type
        
        # Default to CharacterBody3D for unknown ship types
        return GodotNodeType.CHARACTERBODY3D
    
    def _convert_wcs_coordinates(self, wcs_coords: Tuple[float, float, float]) -> Tuple[float, float, float]:
        """Convert WCS coordinates to Godot coordinate system."""
        x, y, z = wcs_coords
        
        # WCS to Godot coordinate conversion
        # WCS: X=right, Y=up, Z=forward 
        # Godot: X=right, Y=up, Z=back (Z is inverted)
        godot_x = x * self.coord_scale
        godot_y = y * self.coord_scale
        godot_z = -z * self.coord_scale  # Invert Z axis
        
        return (godot_x, godot_y, godot_z)
    
    def _convert_wcs_orientation(self, wcs_orientation: Tuple[float, float, float]) -> Tuple[float, float, float]:
        """Convert WCS orientation to Godot rotation (simplified)."""
        # For now, use simple conversion
        # In full implementation, would need proper matrix to Euler conversion
        if wcs_orientation and len(wcs_orientation) == 3:
            x, y, z = wcs_orientation
            # Basic rotation conversion (may need refinement)
            return (x, y, -z)  # Invert Z rotation for coordinate system
        return (0.0, 0.0, 0.0)
    
    def _sanitize_node_name(self, name: str) -> str:
        """Sanitize name for use as Godot node name."""
        # Replace invalid characters
        sanitized = re.sub(r'[^a-zA-Z0-9_]', '_', name)
        
        # Ensure doesn't start with number
        if sanitized and sanitized[0].isdigit():
            sanitized = f"_{sanitized}"
        
        # Ensure not empty
        if not sanitized:
            sanitized = "Node"
        
        return sanitized
    
    def _generate_scene_file_content(self, scene: GodotScene) -> str:
        """Generate .tscn file content from scene structure."""
        lines = []
        
        # Add header
        lines.append(f"[gd_scene load_steps=1 format={scene.format}]")
        lines.append("")
        
        # Add root node
        if scene.root_node:
            lines.append(f'[node name="{scene.root_node.name}" type="{scene.root_node.type}"]')
            if scene.root_node.script:
                lines.append(f'script = preload("{scene.root_node.script}")')
            
            # Add root node properties
            self._add_node_properties(lines, scene.root_node)
            lines.append("")
        
        # Add child nodes
        for node in scene.nodes[1:]:  # Skip root node
            lines.append(f'[node name="{node.name}" type="{node.type}" parent="{node.parent}"]')
            
            # Add transform
            if node.position != (0.0, 0.0, 0.0):
                lines.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {node.position[0]}, {node.position[1]}, {node.position[2]})')
            
            # Add node properties
            self._add_node_properties(lines, node)
            lines.append("")
        
        # Add connections if any
        for connection in scene.connections:
            signal_line = f'[connection signal="{connection["signal"]}" from="{connection["from"]}" to="{connection["to"]}" method="{connection["method"]}"]'
            lines.append(signal_line)
        
        return '\n'.join(lines)
    
    def _add_node_properties(self, lines: List[str], node: GodotNode) -> None:
        """Add node properties to scene file lines."""
        # Add groups
        if node.groups:
            groups_str = ', '.join(f'&"{group}"' for group in node.groups)
            lines.append(f'groups = [{groups_str}]')
        
        # Add custom properties as metadata
        if node.properties:
            for key, value in node.properties.items():
                if isinstance(value, str):
                    lines.append(f'metadata/{key} = "{value}"')
                elif isinstance(value, (list, dict)):
                    # Convert complex types to JSON strings
                    json_value = json.dumps(value)
                    lines.append(f'metadata/{key} = "{json_value}"')
                else:
                    lines.append(f'metadata/{key} = {value}')
    
    def _generate_mission_script(self, mission_data: MissionData, script_path: Path) -> None:
        """Generate GDScript mission controller file."""
        script_content = self._create_mission_script_content(mission_data)
        
        # Ensure script directory exists
        script_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(script_path, 'w', encoding='utf-8') as f:
            f.write(script_content)
        
        self.logger.info(f"Generated mission script: {script_path}")
    
    def _create_mission_script_content(self, mission_data: MissionData) -> str:
        """Create GDScript content for mission controller."""
        mission_name = mission_data.mission_info.name or "Unknown Mission"
        sanitized_class_name = self._sanitize_node_name(mission_name) + "Mission"
        
        script_template = f'''class_name {sanitized_class_name}
extends Node3D

## Mission: {mission_name}
## Author: {mission_data.mission_info.author}
## Converted from FS2 mission file

signal mission_started()
signal mission_completed()
signal mission_failed()
signal objective_completed(objective_name: String)
signal objective_failed(objective_name: String)

@export var mission_time: float = 0.0
@export var mission_started: bool = false
@export var mission_completed: bool = false

var ships_container: Node3D
var wings_container: Node3D
var waypoints_container: Node3D

# Mission objectives tracking
var objectives: Dictionary = {{}}
var events: Array[Dictionary] = []
var goals: Array[Dictionary] = []

func _ready() -> void:
    _setup_mission_containers()
    _initialize_mission_data()
    _setup_objectives()
    _setup_events()
    _start_mission()

func _setup_mission_containers() -> void:
    """Initialize container node references."""
    ships_container = $Ships
    wings_container = $Wings
    waypoints_container = $Waypoints
    
    if not ships_container:
        push_error("Ships container not found")
    if not wings_container:
        push_error("Wings container not found")
    if not waypoints_container:
        push_error("Waypoints container not found")

func _initialize_mission_data() -> void:
    """Initialize mission-specific data."""
    # Mission info
    set_meta("mission_name", "{mission_name}")
    set_meta("mission_author", "{mission_data.mission_info.author}")
    set_meta("mission_description", "{mission_data.mission_info.description}")
    set_meta("mission_version", {mission_data.mission_info.version})
    
    # Initialize ships from metadata
    _initialize_ships()
    
    # Initialize wings from metadata
    _initialize_wings()

func _initialize_ships() -> void:
    """Initialize ship properties from scene metadata."""
    if not ships_container:
        return
    
    for ship_node in ships_container.get_children():
        if ship_node.has_meta("ship_class"):
            var ship_class: String = ship_node.get_meta("ship_class")
            var team: String = ship_node.get_meta("team", "friendly")
            var initial_hull: int = ship_node.get_meta("initial_hull", 100)
            var initial_shields: int = ship_node.get_meta("initial_shields", 100)
            
            # Set up ship-specific initialization
            _setup_ship(ship_node, ship_class, team, initial_hull, initial_shields)

func _setup_ship(ship: Node3D, ship_class: String, team: String, hull: int, shields: int) -> void:
    """Set up individual ship with proper configuration."""
    # Add ship to appropriate team group
    ship.add_to_group(team)
    
    # Set up ship properties
    ship.set_meta("current_hull", hull)
    ship.set_meta("current_shields", shields)
    ship.set_meta("team", team)
    
    # Connect ship signals if available
    if ship.has_signal("destroyed"):
        ship.destroyed.connect(_on_ship_destroyed.bind(ship))
    if ship.has_signal("damaged"):
        ship.damaged.connect(_on_ship_damaged.bind(ship))

func _initialize_wings() -> void:
    """Initialize wing formations and spawn logic."""
    if not wings_container:
        return
    
    for wing_node in wings_container.get_children():
        if wing_node.has_meta("ships"):
            var wing_ships: Array = []
            var ships_json: String = wing_node.get_meta("ships", "[]")
            var ships_array = JSON.parse_string(ships_json)
            
            if ships_array is Array:
                wing_ships = ships_array
            
            # Set up wing management
            _setup_wing(wing_node, wing_ships)

func _setup_wing(wing: Node3D, ship_names: Array) -> void:
    """Set up wing formation and management."""
    wing.set_meta("active_ships", ship_names.size())
    wing.set_meta("original_ship_count", ship_names.size())
    
    # Connect wing ships to wing management
    for ship_name in ship_names:
        var ship_node = ships_container.get_node_or_null(ship_name)
        if ship_node:
            ship_node.set_meta("wing", wing.name)

func _setup_objectives() -> void:
    """Set up mission objectives from goals."""
{self._generate_objectives_code(mission_data.goals)}

func _setup_events() -> void:
    """Set up mission events and triggers."""
{self._generate_events_code(mission_data.events)}

func _start_mission() -> void:
    """Start the mission."""
    mission_started = true
    mission_time = 0.0
    mission_started.emit()
    
    print("Mission started: {mission_name}")

func _process(delta: float) -> void:
    if not mission_started or mission_completed:
        return
    
    mission_time += delta
    
    # Update events and objectives
    _update_events(delta)
    _check_objectives()

func _update_events(delta: float) -> void:
    """Update mission events each frame."""
    # Process time-based events
    for event in events:
        if event.get("active", false):
            _process_event(event, delta)

func _process_event(event: Dictionary, delta: float) -> void:
    """Process individual mission event."""
    # Basic event processing - would be expanded with SEXP conversion
    var event_name: String = event.get("name", "")
    var formula: String = event.get("formula", "")
    
    # For now, just log event processing
    # In full implementation, would evaluate SEXP formulas
    if event_name:
        _evaluate_event_condition(event_name, formula)

func _evaluate_event_condition(event_name: String, formula: String) -> bool:
    """Evaluate event condition (simplified SEXP evaluation)."""
    # Placeholder for SEXP formula evaluation
    # In full implementation, would parse and evaluate SEXP expressions
    print("Evaluating event: ", event_name, " with formula: ", formula)
    return false

func _check_objectives() -> void:
    """Check objective completion status."""
    for objective_name in objectives.keys():
        var objective = objectives[objective_name]
        if not objective.get("completed", false):
            if _evaluate_objective_condition(objective):
                _complete_objective(objective_name)

func _evaluate_objective_condition(objective: Dictionary) -> bool:
    """Evaluate objective completion condition."""
    # Placeholder for objective evaluation
    # In full implementation, would evaluate goal formulas
    return false

func _complete_objective(objective_name: String) -> void:
    """Mark objective as completed."""
    if objective_name in objectives:
        objectives[objective_name]["completed"] = true
        objective_completed.emit(objective_name)
        print("Objective completed: ", objective_name)
        
        # Check if all primary objectives are complete
        _check_mission_completion()

func _fail_objective(objective_name: String) -> void:
    """Mark objective as failed."""
    if objective_name in objectives:
        objectives[objective_name]["failed"] = true
        objective_failed.emit(objective_name)
        print("Objective failed: ", objective_name)
        
        # Check if mission should fail
        _check_mission_failure()

func _check_mission_completion() -> void:
    """Check if mission is complete."""
    var primary_objectives_complete: bool = true
    
    for objective in objectives.values():
        if objective.get("type") == "primary" and not objective.get("completed", false):
            primary_objectives_complete = false
            break
    
    if primary_objectives_complete:
        _complete_mission()

func _check_mission_failure() -> void:
    """Check if mission has failed."""
    for objective in objectives.values():
        if objective.get("type") == "primary" and objective.get("failed", false):
            _fail_mission()
            return

func _complete_mission() -> void:
    """Complete the mission successfully."""
    if not mission_completed:
        mission_completed = true
        mission_completed.emit()
        print("Mission completed successfully!")

func _fail_mission() -> void:
    """Fail the mission."""
    if not mission_completed:
        mission_completed = true
        mission_failed.emit()
        print("Mission failed!")

# Ship event handlers
func _on_ship_destroyed(ship: Node3D) -> void:
    """Handle ship destruction."""
    var ship_name: String = ship.name
    print("Ship destroyed: ", ship_name)
    
    # Update wing if ship was part of one
    var wing_name: String = ship.get_meta("wing", "")
    if wing_name:
        _update_wing_status(wing_name, ship_name, "destroyed")

func _on_ship_damaged(ship: Node3D, damage: float) -> void:
    """Handle ship damage."""
    var current_hull: float = ship.get_meta("current_hull", 100.0)
    current_hull = max(0.0, current_hull - damage)
    ship.set_meta("current_hull", current_hull)
    
    if current_hull <= 0.0:
        _on_ship_destroyed(ship)

func _update_wing_status(wing_name: String, ship_name: String, status: String) -> void:
    """Update wing status when ship status changes."""
    var wing_node = wings_container.get_node_or_null(wing_name)
    if wing_node:
        var active_ships: int = wing_node.get_meta("active_ships", 0)
        if status == "destroyed":
            active_ships = max(0, active_ships - 1)
            wing_node.set_meta("active_ships", active_ships)
            
            if active_ships == 0:
                print("Wing eliminated: ", wing_name)

# Utility functions
func get_ship_by_name(ship_name: String) -> Node3D:
    """Get ship node by name."""
    if ships_container:
        return ships_container.get_node_or_null(ship_name)
    return null

func get_wing_by_name(wing_name: String) -> Node3D:
    """Get wing node by name."""
    if wings_container:
        return wings_container.get_node_or_null(wing_name)
    return null

func get_ships_by_team(team_name: String) -> Array[Node]:
    """Get all ships belonging to a team."""
    return get_tree().get_nodes_in_group(team_name)

func get_mission_time() -> float:
    """Get current mission time."""
    return mission_time

func is_mission_active() -> bool:
    """Check if mission is currently active."""
    return mission_started and not mission_completed
'''
        
        return script_template
    
    def _generate_objectives_code(self, goals: List) -> str:
        """Generate GDScript code for setting up objectives."""
        if not goals:
            return "    # No objectives defined"
        
        lines = []
        for i, goal in enumerate(goals):
            goal_name = goal.name or f"objective_{i}"
            goal_type = goal.type or "primary"
            goal_message = goal.message or goal_name
            
            lines.append(f'    objectives["{goal_name}"] = {{')
            lines.append(f'        "type": "{goal_type}",')
            lines.append(f'        "name": "{goal_name}",')
            lines.append(f'        "message": "{goal_message}",')
            lines.append(f'        "formula": "{goal.formula}",')
            lines.append(f'        "completed": false,')
            lines.append(f'        "failed": false')
            lines.append('    }')
            
        return '\n'.join(lines)
    
    def _generate_events_code(self, events: List) -> str:
        """Generate GDScript code for setting up events."""
        if not events:
            return "    # No events defined"
        
        lines = []
        for i, event in enumerate(events):
            event_name = event.name or f"event_{i}"
            
            lines.append(f'    events.append({{')
            lines.append(f'        "name": "{event_name}",')
            lines.append(f'        "formula": "{event.formula}",')
            lines.append(f'        "repeat_count": {event.repeat_count},')
            lines.append(f'        "score": {event.score},')
            lines.append(f'        "active": true')
            lines.append('    })')
            
        return '\n'.join(lines)


# Import required module
import re

# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Test with sample mission data
    from .fs2_mission_parser import (MissionData, MissionEvent, MissionGoal,
                                     MissionInfo, MissionObject)

    # Create test mission data
    test_mission = MissionData()
    test_mission.mission_info = MissionInfo(
        name="Test Mission",
        author="Test Author",
        version=2.0,
        description="A test mission for validation"
    )
    
    # Add test ship
    test_ship = MissionObject(
        name="Alpha 1",
        class_name="GTF Ulysses",
        position=(1000.0, 0.0, 2000.0),
        team="friendly"
    )
    test_mission.objects.append(test_ship)
    
    # Add test goal
    test_goal = MissionGoal(
        type="primary",
        name="Destroy Enemy",
        message="Destroy all enemy fighters"
    )
    test_mission.goals.append(test_goal)
    
    # Generate scene
    generator = GodotSceneGenerator()
    output_path = Path("test_mission.tscn")
    success = generator.generate_mission_scene(test_mission, output_path)
    
    if success:
        print(f"Successfully generated test scene: {output_path}")
    else:
        print("Failed to generate test scene")