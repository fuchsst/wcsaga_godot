#!/usr/bin/env python3
"""
Mission Event Converter - EPIC-003 DM-007 Implementation

Transforms mission events and goals into GDScript equivalents preserving
trigger conditions and action sequences from FS2 SEXP expressions.
"""

import logging
import re
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple, Union

from .fs2_mission_parser import MissionData, MissionEvent, MissionGoal


class SexpNodeType(Enum):
    """SEXP expression node types."""
    OPERATOR = "operator"
    DATA = "data"
    VARIABLE = "variable"
    NUMBER = "number"
    STRING = "string"
    BOOLEAN = "boolean"


@dataclass
class SexpNode:
    """Represents a parsed SEXP expression node."""
    type: SexpNodeType
    value: str
    children: List['SexpNode'] = []
    
    def __post_init__(self):
        if self.children is None:
            self.children = []


@dataclass
class ConvertedEvent:
    """Represents a converted mission event."""
    original_name: str
    gdscript_function: str
    trigger_conditions: List[str]
    actions: List[str]
    repeat_count: int = 1
    interval: float = 1.0
    dependencies: List[str] = []
    
    def __post_init__(self):
        if self.dependencies is None:
            self.dependencies = []


class MissionEventConverter:
    """Converts FS2 mission events and SEXP expressions to GDScript."""
    
    def __init__(self) -> None:
        """Initialize event converter."""
        self.logger = logging.getLogger(__name__)
        
        # SEXP operator to GDScript mapping
        self.sexp_operators = {
            # Logical operators
            'and': 'and',
            'or': 'or', 
            'not': 'not',
            'true': 'true',
            'false': 'false',
            
            # Comparison operators
            '=': '==',
            '<': '<',
            '>': '>',
            '<=': '<=',
            '>=': '>=',
            
            # Arithmetic operators
            '+': '+',
            '-': '-',
            '*': '*',
            '/': '/',
            
            # Mission-specific operators
            'when': 'when',
            'time-elapsed': 'time_elapsed',
            'mission-time': 'mission_time',
            'is-destroyed': 'is_destroyed',
            'is-disabled': 'is_disabled',
            'has-departed': 'has_departed',
            'has-arrived': 'has_arrived',
            'distance': 'distance_between',
            'shields': 'get_shields',
            'hull': 'get_hull',
            'speed': 'get_speed',
            'is-ship-type': 'is_ship_type',
            'num-ships-in-battle': 'num_ships_in_battle',
            'num-kills': 'get_kill_count',
            'cargo': 'get_cargo',
            'is-cargo': 'has_cargo',
            'waypoints-done': 'waypoints_completed',
            'ship-type-destroyed': 'ship_type_destroyed_count',
            
            # Action operators
            'send-message': 'send_message',
            'training-msg': 'show_training_message',
            'change-ship-model': 'change_ship_model',
            'ship-vanish': 'vanish_ship',
            'ship-create': 'create_ship',
            'add-goal': 'add_goal',
            'clear-goals': 'clear_goals',
            'warp-in': 'warp_in_ship',
            'warp-out': 'warp_out_ship',
            'end-mission': 'end_mission',
            'end-campaign': 'end_campaign',
            'sabotage-subsystem': 'sabotage_subsystem',
            'repair-subsystem': 'repair_subsystem',
            'set-subsystem-strength': 'set_subsystem_strength',
            'invalidate-goal': 'invalidate_goal',
            'validate-goal': 'validate_goal',
            'set-cargo': 'set_cargo',
            'jettison-cargo': 'jettison_cargo',
            'modify-variable': 'modify_variable',
            'set-variable': 'set_variable'
        }
        
        # Convert mission function templates
        self.mission_function_templates = {
            'time_elapsed': 'get_mission_time() >= {0}',
            'is_destroyed': 'is_ship_destroyed("{0}")',
            'is_disabled': 'is_ship_disabled("{0}")',
            'has_departed': 'has_ship_departed("{0}")',
            'has_arrived': 'has_ship_arrived("{0}")',
            'distance_between': 'get_distance_between("{0}", "{1}")',
            'get_shields': 'get_ship_shields("{0}")',
            'get_hull': 'get_ship_hull("{0}")',
            'num_ships_in_battle': 'get_ships_in_battle().size()',
            'send_message': 'send_message("{0}", "{1}")',
            'end_mission': 'end_mission({0})',
            'warp_in_ship': 'warp_in_ship("{0}")',
            'warp_out_ship': 'warp_out_ship("{0}")'
        }
    
    def convert_mission_events(self, mission_data: MissionData) -> Dict[str, ConvertedEvent]:
        """Convert all mission events to GDScript equivalents."""
        try:
            self.logger.info("Converting mission events to GDScript")
            
            converted_events = {}
            
            # Convert events
            for i, event in enumerate(mission_data.events):
                event_name = event.name or f"event_{i}"
                converted_event = self._convert_single_event(event, event_name)
                if converted_event:
                    converted_events[event_name] = converted_event
            
            # Convert goals as special events
            for i, goal in enumerate(mission_data.goals):
                goal_name = goal.name or f"goal_{i}"
                converted_goal = self._convert_goal_to_event(goal, goal_name)
                if converted_goal:
                    converted_events[f"goal_{goal_name}"] = converted_goal
            
            self.logger.info(f"Converted {len(converted_events)} events/goals")
            return converted_events
            
        except Exception as e:
            self.logger.error(f"Failed to convert mission events: {e}")
            return {}
    
    def _convert_single_event(self, event: MissionEvent, event_name: str) -> Optional[ConvertedEvent]:
        """Convert a single mission event."""
        try:
            # Parse SEXP formula
            if not event.formula:
                self.logger.warning(f"Event {event_name} has no formula")
                return None
            
            # Parse the SEXP expression
            sexp_tree = self._parse_sexp(event.formula)
            if not sexp_tree:
                return None
            
            # Convert to GDScript
            gdscript_condition = self._convert_sexp_to_gdscript(sexp_tree)
            
            # Generate event function
            function_name = f"check_{self._sanitize_name(event_name)}"
            gdscript_function = self._generate_event_function(
                function_name, gdscript_condition, event
            )
            
            # Identify trigger conditions and actions
            trigger_conditions, actions = self._extract_conditions_and_actions(sexp_tree)
            
            converted_event = ConvertedEvent(
                original_name=event_name,
                gdscript_function=gdscript_function,
                trigger_conditions=trigger_conditions,
                actions=actions,
                repeat_count=event.repeat_count,
                interval=event.interval
            )
            
            return converted_event
            
        except Exception as e:
            self.logger.error(f"Failed to convert event {event_name}: {e}")
            return None
    
    def _convert_goal_to_event(self, goal: MissionGoal, goal_name: str) -> Optional[ConvertedEvent]:
        """Convert a mission goal to an event-like structure."""
        try:
            if not goal.formula:
                return None
            
            # Parse goal SEXP formula
            sexp_tree = self._parse_sexp(goal.formula)
            if not sexp_tree:
                return None
            
            # Convert to GDScript condition
            gdscript_condition = self._convert_sexp_to_gdscript(sexp_tree)
            
            # Generate goal check function
            function_name = f"check_goal_{self._sanitize_name(goal_name)}"
            gdscript_function = self._generate_goal_function(
                function_name, gdscript_condition, goal
            )
            
            # Goals are typically checked continuously
            trigger_conditions = [gdscript_condition]
            actions = [f"complete_objective('{goal_name}')"]
            
            converted_event = ConvertedEvent(
                original_name=goal_name,
                gdscript_function=gdscript_function,
                trigger_conditions=trigger_conditions,
                actions=actions,
                repeat_count=1
            )
            
            return converted_event
            
        except Exception as e:
            self.logger.error(f"Failed to convert goal {goal_name}: {e}")
            return None
    
    def _parse_sexp(self, sexp_str: str) -> Optional[SexpNode]:
        """Parse SEXP expression into tree structure."""
        try:
            # Clean and tokenize SEXP string
            tokens = self._tokenize_sexp(sexp_str)
            if not tokens:
                return None
            
            # Parse tokens into tree
            tree, _ = self._parse_sexp_tokens(tokens, 0)
            return tree
            
        except Exception as e:
            self.logger.error(f"Failed to parse SEXP: {sexp_str[:100]}... Error: {e}")
            return None
    
    def _tokenize_sexp(self, sexp_str: str) -> List[str]:
        """Tokenize SEXP expression string."""
        # Remove extra whitespace and normalize
        normalized = re.sub(r'\s+', ' ', sexp_str.strip())
        
        # Split on parentheses and spaces, keeping parentheses
        tokens = []
        current_token = ""
        in_quotes = False
        
        for char in normalized:
            if char == '"' and not in_quotes:
                in_quotes = True
                current_token += char
            elif char == '"' and in_quotes:
                in_quotes = False
                current_token += char
            elif char in '()' and not in_quotes:
                if current_token.strip():
                    tokens.append(current_token.strip())
                    current_token = ""
                tokens.append(char)
            elif char == ' ' and not in_quotes:
                if current_token.strip():
                    tokens.append(current_token.strip())
                    current_token = ""
            else:
                current_token += char
        
        if current_token.strip():
            tokens.append(current_token.strip())
        
        return tokens
    
    def _parse_sexp_tokens(self, tokens: List[str], index: int) -> Tuple[Optional[SexpNode], int]:
        """Parse tokens into SEXP node tree."""
        if index >= len(tokens):
            return None, index
        
        token = tokens[index]
        
        if token == '(':
            # Start of expression - next token is operator
            index += 1
            if index >= len(tokens):
                return None, index
            
            operator = tokens[index]
            node = SexpNode(SexpNodeType.OPERATOR, operator)
            index += 1
            
            # Parse children until closing parenthesis
            while index < len(tokens) and tokens[index] != ')':
                child, index = self._parse_sexp_tokens(tokens, index)
                if child:
                    node.children.append(child)
            
            # Skip closing parenthesis
            if index < len(tokens) and tokens[index] == ')':
                index += 1
            
            return node, index
            
        elif token == ')':
            # End of expression
            return None, index
            
        else:
            # Data token
            node_type = self._determine_node_type(token)
            return SexpNode(node_type, token), index + 1
    
    def _determine_node_type(self, token: str) -> SexpNodeType:
        """Determine the type of a SEXP token."""
        # Remove quotes for analysis
        clean_token = token.strip('"')
        
        # Check if it's a number
        if re.match(r'^-?\d+\.?\d*$', clean_token):
            return SexpNodeType.NUMBER
        
        # Check if it's a boolean
        if clean_token.lower() in ('true', 'false'):
            return SexpNodeType.BOOLEAN
        
        # Check if it's quoted (string)
        if token.startswith('"') and token.endswith('"'):
            return SexpNodeType.STRING
        
        # Check if it's a known variable pattern
        if clean_token.startswith('@') or clean_token in ('player', 'enemy'):
            return SexpNodeType.VARIABLE
        
        # Default to data
        return SexpNodeType.DATA
    
    def _convert_sexp_to_gdscript(self, node: SexpNode) -> str:
        """Convert SEXP node tree to GDScript expression."""
        if node.type == SexpNodeType.OPERATOR:
            return self._convert_operator_node(node)
        elif node.type == SexpNodeType.STRING:
            return '"' + node.value.strip('"') + '"'
        elif node.type == SexpNodeType.NUMBER:
            return node.value
        elif node.type == SexpNodeType.BOOLEAN:
            return node.value.lower()
        elif node.type == SexpNodeType.VARIABLE:
            return self._convert_variable(node.value)
        else:
            # Data - could be ship name, etc.
            return f'"{node.value}"'
    
    def _convert_operator_node(self, node: SexpNode) -> str:
        """Convert SEXP operator node to GDScript."""
        operator = node.value.lower()
        
        # Get GDScript equivalent
        if operator in self.sexp_operators:
            gdscript_op = self.sexp_operators[operator]
        else:
            self.logger.warning(f"Unknown SEXP operator: {operator}")
            gdscript_op = operator
        
        # Convert children
        child_expressions = []
        for child in node.children:
            child_expr = self._convert_sexp_to_gdscript(child)
            child_expressions.append(child_expr)
        
        # Handle different operator types
        if operator in ('and', 'or'):
            if len(child_expressions) >= 2:
                return f"({f' {gdscript_op} '.join(child_expressions)})"
            elif len(child_expressions) == 1:
                return child_expressions[0]
            else:
                return 'true'
        
        elif operator == 'not':
            if child_expressions:
                return f"not ({child_expressions[0]})"
            return 'false'
        
        elif operator in ('=', '<', '>', '<=', '>='):
            if len(child_expressions) >= 2:
                return f"{child_expressions[0]} {gdscript_op} {child_expressions[1]}"
            return 'false'
        
        elif operator in ('+', '-', '*', '/'):
            if len(child_expressions) >= 2:
                return f"({f' {gdscript_op} '.join(child_expressions)})"
            elif len(child_expressions) == 1:
                return child_expressions[0]
            return '0'
        
        # Mission-specific operators
        elif operator in self.mission_function_templates:
            template = self.mission_function_templates[operator]
            try:
                return template.format(*child_expressions)
            except (IndexError, ValueError):
                return f"{gdscript_op}({', '.join(child_expressions)})"
        
        else:
            # Generic function call
            return f"{gdscript_op}({', '.join(child_expressions)})"
    
    def _convert_variable(self, variable: str) -> str:
        """Convert SEXP variable to GDScript equivalent."""
        clean_var = variable.strip('@')
        
        # Common variable mappings
        variable_mappings = {
            'player': 'get_player_ship()',
            'enemy': 'get_enemy_ships()',
            'friendly': 'get_friendly_ships()',
            'hostile': 'get_hostile_ships()',
            'neutral': 'get_neutral_ships()',
            'alpha': 'get_wing("Alpha")',
            'beta': 'get_wing("Beta")',
            'gamma': 'get_wing("Gamma")',
            'delta': 'get_wing("Delta")'
        }
        
        if clean_var.lower() in variable_mappings:
            return variable_mappings[clean_var.lower()]
        
        # Check if it's a wing name (typically uppercase)
        if clean_var.isupper() and len(clean_var) <= 10:
            return f'get_wing("{clean_var}")'
        
        # Default to ship name
        return f'get_ship("{clean_var}")'
    
    def _extract_conditions_and_actions(self, sexp_tree: SexpNode) -> Tuple[List[str], List[str]]:
        """Extract conditions and actions from SEXP tree."""
        conditions = []
        actions = []
        
        # Recursively extract conditions and actions
        self._extract_from_node(sexp_tree, conditions, actions)
        
        return conditions, actions
    
    def _extract_from_node(self, node: SexpNode, conditions: List[str], actions: List[str]) -> None:
        """Recursively extract conditions and actions from node."""
        if node.type == SexpNodeType.OPERATOR:
            operator = node.value.lower()
            
            # Condition operators
            if operator in ('is-destroyed', 'is-disabled', 'has-departed', 'has-arrived', 
                          'time-elapsed', '=', '<', '>', '<=', '>=', 'distance', 'hull', 'shields'):
                condition_str = self._convert_sexp_to_gdscript(node)
                conditions.append(condition_str)
            
            # Action operators
            elif operator in ('send-message', 'warp-in', 'warp-out', 'end-mission',
                            'ship-vanish', 'ship-create', 'add-goal', 'clear-goals'):
                action_str = self._convert_sexp_to_gdscript(node)
                actions.append(action_str)
            
            # Recurse into children
            for child in node.children:
                self._extract_from_node(child, conditions, actions)
    
    def _generate_event_function(self, function_name: str, condition: str, event: MissionEvent) -> str:
        """Generate GDScript function for event."""
        function_template = f'''func {function_name}() -> bool:
    """Check event condition: {event.name}"""
    # Original formula: {event.formula}
    return {condition}

func {function_name}_action() -> void:
    """Execute event action: {event.name}"""
    if {function_name}():
        # Event triggered
        print("Event triggered: {event.name}")
        
        # Add event-specific actions here
        if "{event.objective_text}":
            show_objective_text("{event.objective_text}")
        
        if {event.score} > 0:
            add_score({event.score})
        
        if {str(event.end_mission).lower()}:
            end_mission()
'''
        
        return function_template
    
    def _generate_goal_function(self, function_name: str, condition: str, goal: MissionGoal) -> str:
        """Generate GDScript function for goal."""
        function_template = f'''func {function_name}() -> bool:
    """Check goal condition: {goal.name}"""
    # Goal type: {goal.type}
    # Original formula: {goal.formula}
    return {condition}

func {function_name}_complete() -> void:
    """Complete goal: {goal.name}"""
    if {function_name}():
        complete_objective("{goal.name}")
        
        if "{goal.message}":
            show_goal_message("{goal.message}")
        
        # Mark goal as completed
        if "{goal.name}" in objectives:
            objectives["{goal.name}"]["completed"] = true
'''
        
        return function_template
    
    def _sanitize_name(self, name: str) -> str:
        """Sanitize name for use in GDScript function names."""
        # Replace invalid characters with underscores
        sanitized = re.sub(r'[^a-zA-Z0-9_]', '_', name)
        
        # Ensure doesn't start with number
        if sanitized and sanitized[0].isdigit():
            sanitized = f"_{sanitized}"
        
        # Convert to lowercase for function names
        return sanitized.lower()
    
    def generate_mission_event_system(self, converted_events: Dict[str, ConvertedEvent]) -> str:
        """Generate complete GDScript event system."""
        system_code = '''# Mission Event System - Auto-generated from FS2 mission file

# Event checking functions
var event_states: Dictionary = {}
var event_timers: Dictionary = {}

func _ready_events() -> void:
    """Initialize event system."""
    # Initialize event states
'''
        
        # Add event initialization
        for event_name in converted_events.keys():
            system_code += f'    event_states["{event_name}"] = false\n'
            system_code += f'    event_timers["{event_name}"] = 0.0\n'
        
        system_code += '''
    # Start event processing
    set_process(true)

func _process_events(delta: float) -> void:
    """Process all mission events."""
    # Update event timers
    for event_name in event_timers.keys():
        event_timers[event_name] += delta
    
    # Check event conditions
'''
        
        # Add event checks
        for event_name, event in converted_events.items():
            sanitized_name = self._sanitize_name(event_name)
            system_code += f'    _check_{sanitized_name}()\n'
        
        system_code += '\n'
        
        # Add all event functions
        for event_name, event in converted_events.items():
            system_code += event.gdscript_function + '\n\n'
        
        # Add utility functions
        system_code += '''
# Utility functions for mission events

func is_ship_destroyed(ship_name: String) -> bool:
    """Check if ship is destroyed."""
    var ship = get_ship_by_name(ship_name)
    return ship == null or ship.get_meta("destroyed", false)

func is_ship_disabled(ship_name: String) -> bool:
    """Check if ship is disabled."""
    var ship = get_ship_by_name(ship_name)
    if ship == null:
        return false
    return ship.get_meta("current_hull", 100) <= 0

func has_ship_departed(ship_name: String) -> bool:
    """Check if ship has departed."""
    var ship = get_ship_by_name(ship_name)
    return ship == null or ship.get_meta("departed", false)

func has_ship_arrived(ship_name: String) -> bool:
    """Check if ship has arrived."""
    var ship = get_ship_by_name(ship_name)
    return ship != null and ship.get_meta("arrived", false)

func get_distance_between(ship1_name: String, ship2_name: String) -> float:
    """Get distance between two ships."""
    var ship1 = get_ship_by_name(ship1_name)
    var ship2 = get_ship_by_name(ship2_name)
    
    if ship1 == null or ship2 == null:
        return 999999.0
    
    return ship1.global_position.distance_to(ship2.global_position)

func get_ship_shields(ship_name: String) -> float:
    """Get ship shield percentage."""
    var ship = get_ship_by_name(ship_name)
    if ship == null:
        return 0.0
    return ship.get_meta("current_shields", 0.0)

func get_ship_hull(ship_name: String) -> float:
    """Get ship hull percentage."""
    var ship = get_ship_by_name(ship_name)
    if ship == null:
        return 0.0
    return ship.get_meta("current_hull", 0.0)

func send_message(sender: String, message: String) -> void:
    """Send in-game message."""
    print("Message from ", sender, ": ", message)
    # In full implementation, would show in HUD

func warp_in_ship(ship_name: String) -> void:
    """Warp in a ship."""
    var ship = get_ship_by_name(ship_name)
    if ship:
        ship.set_meta("arrived", true)
        ship.show()
        print("Ship warped in: ", ship_name)

func warp_out_ship(ship_name: String) -> void:
    """Warp out a ship."""
    var ship = get_ship_by_name(ship_name)
    if ship:
        ship.set_meta("departed", true)
        ship.hide()
        print("Ship warped out: ", ship_name)

func show_objective_text(text: String) -> void:
    """Show objective text to player."""
    print("OBJECTIVE: ", text)

func add_score(points: int) -> void:
    """Add score points."""
    var current_score = get_meta("mission_score", 0)
    set_meta("mission_score", current_score + points)
    print("Score added: ", points, " (Total: ", current_score + points, ")")

func show_goal_message(message: String) -> void:
    """Show goal completion message."""
    print("GOAL: ", message)
'''
        
        return system_code


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Test SEXP parsing and conversion
    converter = MissionEventConverter()
    
    # Test simple SEXP expressions
    test_expressions = [
        "(and (is-destroyed \"Alpha 1\") (time-elapsed 30))",
        "(or (hull \"Beta 1\" 25) (shields \"Beta 1\" 0))",
        "(= (distance \"Player\" \"Target\") 1000)",
        "(send-message \"Command\" \"Objective complete!\")"
    ]
    
    for expr in test_expressions:
        print(f"\nTesting SEXP: {expr}")
        tree = converter._parse_sexp(expr)
        if tree:
            gdscript = converter._convert_sexp_to_gdscript(tree)
            print(f"GDScript: {gdscript}")
        else:
            print("Failed to parse")