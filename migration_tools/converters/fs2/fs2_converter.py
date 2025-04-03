#!/usr/bin/env python3

import logging
import os
from pathlib import Path
from typing import Dict, Any, List, Iterator, Optional
from dataclasses import dataclass, field
from ..base_converter import BaseConverter
from .parsers.parser_factory import ParserFactory

logger = logging.getLogger(__name__)

@dataclass
class FS2File:
    """Container for all FS2 file sections"""
    mission_info: Dict[str, Any] = field(default_factory=dict)
    command_briefing: Dict[str, Any] = field(default_factory=dict)
    fiction_viewer: Dict[str, Any] = field(default_factory=dict)
    briefing: Dict[str, Any] = field(default_factory=dict)
    debriefing_info: Dict[str, Any] = field(default_factory=dict)
    players: Dict[str, Any] = field(default_factory=dict)
    objects: List[Dict[str, Any]] = field(default_factory=list)
    wings: List[Dict[str, Any]] = field(default_factory=list)
    messages: List[Dict[str, Any]] = field(default_factory=list)
    events: List[Dict[str, Any]] = field(default_factory=list)
    goals: List[Dict[str, Any]] = field(default_factory=list)
    waypoints: List[Dict[str, Any]] = field(default_factory=list)
    asteroid_fields: List[Dict[str, Any]] = field(default_factory=list)
    background_bitmaps: Dict[str, Any] = field(default_factory=dict)
    music: Dict[str, Any] = field(default_factory=dict)
    cutscenes: List[Dict[str, Any]] = field(default_factory=list)
    sexp_variables: List[Dict[str, Any]] = field(default_factory=list)
    callsigns: List[str] = field(default_factory=list)
    reinforcements: List[Dict[str, Any]] = field(default_factory=list)

class FS2Converter(BaseConverter):
    """Converter for Wing Commander Saga .fs2 files"""
    
    def __init__(self, input_dir="extracted", output_dir="converted", force=False):
        super().__init__(input_dir, output_dir, force)
        logger.debug("Initialized FS2Converter with input_dir=%s, output_dir=%s, force=%s", 
                    input_dir, output_dir, force)
        
    @property
    def source_extension(self) -> str:
        """File extension this converter handles"""
        return ".fs2"
        
    @property
    def target_extension(self) -> str:
        """File extension to convert to"""
        return ".tres"

    def _normalize_section_name(self, section: str) -> str:
        """Normalize section name to match FS2File field names
        
        Args:
            section: Raw section name
            
        Returns:
            str: Normalized section name
        """
        # Remove any comments (starting with semicolon)
        if ';' in section:
            section = section.split(';')[0]
            
        # Convert to lowercase and replace spaces with underscores
        section = section.replace(':', '').strip().lower().replace(' ', '_')
        
        return section
    
    def _parse_fs2_file(self, content: str) -> FS2File:
        """Parse complete FS2 file content
        
        Args:
            content: Raw file content
            
        Returns:
            FS2File: Parsed file data
        """
        fs2_data = FS2File()
        lines = iter(content.splitlines())
        current_section = None
        section_lines = []
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('#'):
                # Process previous section
                if current_section and section_lines:
                    logger.debug("Processing section '%s' with %d lines", 
                               current_section, len(section_lines))
                    self._parse_section(fs2_data, current_section, section_lines)
                
                # Start new section
                raw_section = line[1:].strip()  # Remove #
                current_section = self._normalize_section_name(raw_section)
                section_lines = []
                logger.debug("Found section marker: '%s' -> normalized to '%s'", 
                           raw_section, current_section)
                continue
                
            # Collect lines for current section
            section_lines.append(line)
            
        # Parse final section
        if current_section and section_lines:
            self._parse_section(fs2_data, current_section, section_lines)
            
        return fs2_data
    
    def _parse_section(self, fs2_data: FS2File, section: str, lines: List[str]) -> None:
        """Parse a mission file section
        
        Args:
            fs2_data: FS2File object to update
            section: Section name
            lines: Section lines to parse
        """
        logger.debug("Parsing section: %s", section)
        
        try:
            # Get parser for section
            parser = ParserFactory.create_parser(section)
            
            # Convert lines to list to allow multiple iterations
            lines_list = list(lines)
            
            # Parse section
            result = parser.parse(iter(lines_list))
                
            # Set the result
            setattr(fs2_data, section, result)
            logger.debug("Successfully parsed section: %s with result: %s", 
                        section, str(result)[:200])  # Truncate long results
            
        except Exception as e:
            logger.error("Error parsing section %s: %s", section, str(e), exc_info=True)
            # Log the full section content for debugging
            logger.error("Section content that failed to parse:\n%s", 
                        '\n'.join(list(lines)))

    def _format_value_for_tres(self, value: Any, indent_level: int = 1) -> Optional[str]:
        """Formats a Python value into a Godot .tres string representation."""
        indent = "  " * indent_level
        if isinstance(value, str):
            # Escape quotes and backslashes within the string
            escaped_value = value.replace('\\', '\\\\').replace('"', '\\"')
            # Handle multi-line strings
            if '\n' in escaped_value:
                # Indent subsequent lines correctly
                lines = escaped_value.split('\n')
                indented_lines = [lines[0]] + [indent + line for line in lines[1:]]
                return f'"""\n{indent}{"\n".join(indented_lines)}\n{indent[:-2]}"""'
            else:
                return f'"{escaped_value}"'
        elif isinstance(value, bool):
            return "true" if value else "false"
        elif isinstance(value, int):
             # Godot uses 64-bit ints by default in GDScript, export as standard int
             return str(value)
        elif isinstance(value, float):
             # Ensure float representation includes decimal point if it's a whole number
             # Use a reasonable precision
             s_val = f"{value:.6f}".rstrip('0')
             return s_val if s_val.endswith('.') else s_val + ('0' if '.' not in s_val else '')
        elif isinstance(value, dict):
            # Handle specific dictionary structures (Vector3, Basis, Color, SexpNode)
            # Check for Vector3 structure
            if all(k in value for k in ['x', 'y', 'z']) and len(value) == 3 and all(isinstance(v, (int, float)) for v in value.values()):
                return f"Vector3({self._format_value_for_tres(value['x'])}, {self._format_value_for_tres(value['y'])}, {self._format_value_for_tres(value['z'])})"
            # Check for Basis structure
            elif all(k in value for k in ['x_axis', 'y_axis', 'z_axis']) and len(value) == 3:
                 x = self._format_value_for_tres(value['x_axis'], indent_level + 1)
                 y = self._format_value_for_tres(value['y_axis'], indent_level + 1)
                 z = self._format_value_for_tres(value['z_axis'], indent_level + 1)
                 # Ensure sub-vectors are formatted correctly
                 if x and y and z:
                     return f"Basis({x}, {y}, {z})"
                 else:
                     logger.warning(f"Failed to format Basis components: {value}")
                     return "Basis()" # Default Basis
            # Check for Color structure
            elif all(k in value for k in ['r', 'g', 'b', 'a']) and len(value) == 4:
                 return f"Color({self._format_value_for_tres(value['r'])}, {self._format_value_for_tres(value['g'])}, {self._format_value_for_tres(value['b'])}, {self._format_value_for_tres(value['a'])})"
            # Check for SexpNode structure (based on placeholder parser output)
            elif 'node_type' in value:
                 # TODO: Implement proper SubResource formatting for SexpNode
                 logger.warning("SexpNode formatting for .tres not fully implemented - using placeholder.")
                 # Placeholder: represent as a dictionary string for now
                 items = [f'"{k}": {self._format_value_for_tres(v, indent_level + 1)}' for k, v in value.items() if v is not None]
                 return f"{{ {', '.join(items)} }}" # Not valid .tres, needs SubResource
            else:
                 # Generic dictionary formatting
                 items = [f"{self._format_value_for_tres(k, indent_level + 1)}: {self._format_value_for_tres(v, indent_level + 1)}" for k, v in value.items() if v is not None]
                 items_str = f",\n{indent}".join(items)
                 return f"{{\n{indent}{items_str}\n{indent[:-2]}}}"
        elif isinstance(value, list):
            if not value:
                return "[]"
            # Format arrays of simple types or resources
            formatted_items = [self._format_value_for_tres(item, indent_level + 1) for item in value]
            valid_items = [item for item in formatted_items if item is not None]
            if not valid_items:
                return "[]"

            # Determine array type hint (needs improvement for resource types)
            first_item = value[0]
            type_hint = ""
            # Basic type hinting (improve this based on actual resource types)
            if all(isinstance(item, str) for item in value): type_hint = ": PackedStringArray"
            elif all(isinstance(item, int) for item in value): type_hint = ": PackedInt64Array" # Use 64-bit for safety
            elif all(isinstance(item, float) for item in value): type_hint = ": PackedFloat64Array"
            elif all(isinstance(item, dict) and 'node_type' in item for item in value): type_hint = ": Array[Resource]" # Placeholder for SexpNode array
            elif all(isinstance(item, dict) for item in value): type_hint = ": Array[Dictionary]" # Generic dictionary array
            elif all(isinstance(item, list) for item in value): type_hint = ": Array[Array]" # Array of arrays
            else: type_hint = ": Array[Resource]" # Generic resource array

            # Multi-line formatting for readability if items are complex or numerous
            if any(isinstance(item, (dict, list)) for item in value) or len(valid_items) > 5:
                 items_str = f",\n{indent}".join(valid_items)
                 return f"[\n{indent}{items_str}\n{indent[:-2]}]{type_hint}"
            else:
                 return f"[{', '.join(valid_items)}]{type_hint}"
        elif value is None:
             return "null"
        else:
            # Attempt to convert unknown types to string as a fallback
            logger.warning(f"Unsupported type for .tres formatting: {type(value)}, attempting str()")
            try:
                return f'"{str(value)}"' # Represent as string if possible
            except:
                 logger.error(f"Could not convert value of type {type(value)} to string.")
                 return None # Skip unsupported types

    def _write_tres_file(self, fs2_data: FS2File, output_path: Path):
        """Writes the parsed FS2 data to a Godot .tres file."""
        # TODO: Determine the correct script path dynamically if needed, or assume MissionData
        script_path = "res://scripts/resources/mission/mission_data.gd" # Adjust if needed
        # TODO: Generate or assign unique UIDs more robustly
        uid_base = re.sub(r'[^a-zA-Z0-9]', '_', output_path.stem) # Basic sanitization
        uid = f"uid://res_{uid_base}_{os.urandom(4).hex()}"

        # TODO: Manage ExtResource IDs properly, especially for nested resources
        ext_resource_id = "1_res" # Placeholder ID, needs better management

        # TODO: Handle SubResource creation for nested SexpNodes, etc.
        sub_resources = {}
        sub_resource_counter = 1

        def format_value_recursive(value: Any, indent_level: int = 1) -> Optional[str]:
            """Recursive helper to format values and handle SubResources."""
            nonlocal sub_resource_counter
            indent = "  " * indent_level

            # Handle SexpNode specifically for SubResource creation
            if isinstance(value, dict) and 'node_type' in value:
                # Generate a unique ID for this SubResource based on its content? Hash?
                # For now, just assign sequential IDs.
                sub_id = f"SubResource_{sub_resource_counter}"
                sub_resource_counter += 1

                # Store the SubResource definition
                sub_resources[sub_id] = {
                    "type": "Resource", # Base type
                    "script": "res://scripts/scripting/sexp/sexp_node.gd", # Path to SexpNode script
                    "data": value # The actual data for this node
                }
                return f'SubResource("{sub_id}")'

            # Handle lists recursively
            elif isinstance(value, list):
                formatted_items = [format_value_recursive(item, indent_level + 1) for item in value]
                valid_items = [item for item in formatted_items if item is not None]
                if not valid_items: return "[]"

                # Determine type hint (simplified)
                first_item = value[0]
                type_hint = ""
                if all(isinstance(item, str) for item in value): type_hint = ": PackedStringArray"
                elif all(isinstance(item, int) for item in value): type_hint = ": PackedInt64Array"
                elif all(isinstance(item, float) for item in value): type_hint = ": PackedFloat64Array"
                elif all(isinstance(item, dict) and 'node_type' in item for item in value): type_hint = ": Array[Resource]" # SexpNode array
                elif all(isinstance(item, dict) for item in value): type_hint = ": Array[Dictionary]"
                elif all(isinstance(item, list) for item in value): type_hint = ": Array[Array]"
                else: type_hint = ": Array[Resource]" # Assume Resource for mixed/other complex types

                if any("\n" in item for item in valid_items) or len(valid_items) > 5:
                    items_str = f",\n{indent}".join(valid_items)
                    return f"[\n{indent}{items_str}\n{indent[:-2]}]{type_hint}"
                else:
                    return f"[{', '.join(valid_items)}]{type_hint}"

            # Handle other types using the base formatter
            else:
                return self._format_value_for_tres(value, indent_level)


        # --- Start writing the file ---
        with open(output_path, 'w', encoding='utf-8') as f:
            # --- Write Header ---
            # Calculate load_steps based on ExtResources + SubResources
            # For now, assume 1 ExtResource (the main script) + SubResources
            # This needs refinement if other ExtResources are used.
            # Placeholder: load_steps=2 initially, will be updated later if sub_resources exist.
            f.write(f"[gd_resource type=\"Resource\" script_class=\"MissionData\" load_steps=2 format=3 uid=\"{uid}\"]\n\n")
            f.write(f"[ext_resource type=\"Script\" path=\"{script_path}\" id=\"{ext_resource_id}\"]\n")
            # Placeholder for SexpNode script ExtResource - will add later if needed
            sexp_ext_res_id = None

            # --- Write Main Resource Properties ---
            resource_lines = []
            resource_lines.append(f"script = ExtResource(\"{ext_resource_id}\")")

            for field_name in fs2_data.__dataclass_fields__:
                value = getattr(fs2_data, field_name)
                godot_prop_name = field_name
                if godot_prop_name.startswith("_"): continue

                formatted_value = format_value_recursive(value) # Use recursive formatter

                if formatted_value is not None:
                    resource_lines.append(f"{godot_prop_name} = {formatted_value}")
                else:
                    logger.warning(f"Skipping property '{godot_prop_name}' due to unsupported value type: {type(value)}")

            # --- Write SubResources (if any) ---
            if sub_resources:
                 # Add SexpNode script as ExtResource if not already present
                 sexp_script_path = "res://scripts/scripting/sexp/sexp_node.gd"
                 # Check if we already have an ExtResource for this path (unlikely here)
                 # For simplicity, assign a new ID. Proper management needed for complex cases.
                 sexp_ext_res_id = "2_sexp" # Placeholder
                 f.write(f"[ext_resource type=\"Script\" path=\"{sexp_script_path}\" id=\"{sexp_ext_res_id}\"]\n")

                 # Update load_steps in the header (requires re-writing or placeholder update)
                 # This is tricky with streaming write. Ideally, collect all content first.
                 # For now, we'll write subresources after the main resource block.

                 f.write("\n") # Separator

                 for sub_id, sub_data in sub_resources.items():
                     f.write(f"[sub_resource type=\"{sub_data['type']}\" id=\"{sub_id}\"]\n")
                     # Assuming sub_data['script'] holds the path
                     # Find or use the correct ExtResource ID for the script
                     script_ext_id = sexp_ext_res_id # Use the ID defined above
                     f.write(f"script = ExtResource(\"{script_ext_id}\")\n")
                     # Write the properties of the sub-resource
                     for prop, val in sub_data['data'].items():
                         formatted_sub_val = format_value_recursive(val, 2) # Indent sub-resource props
                         if formatted_sub_val is not None:
                             f.write(f"{prop} = {formatted_sub_val}\n")
                     f.write("\n") # Blank line after sub-resource

            # --- Write the main resource block content ---
            f.write("\n[resource]\n")
            for line in resource_lines:
                f.write(line + "\n")

            # Note: Updating load_steps accurately requires either:
            # 1. Knowing all ExtResources and SubResources beforehand.
            # 2. Writing to a temporary buffer, calculating steps, writing header, then content.
            # The current approach might result in an incorrect load_steps value if SubResources are added.


    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """Convert a .fs2 file to Godot .tres format

        Args:
            input_path: Path to input .fs2 file
            output_path: Path to write converted .tres file

        Returns:
            bool: True if conversion successful, False otherwise
        """
        self._reset_parser_state() # Reset state for each file
        logger.info("Starting conversion of %s", input_path)
        try:
            # Read input file
            logger.debug("Reading input file %s", input_path)
            # Try common encodings if utf-8 fails
            encodings_to_try = ['utf-8', 'latin-1', 'cp1252']
            content = None
            for encoding in encodings_to_try:
                try:
                    with open(input_path, 'r', encoding=encoding) as f:
                        content = f.read()
                    logger.debug(f"Successfully read {input_path} with encoding {encoding}")
                    break # Stop trying encodings once successful
                except UnicodeDecodeError:
                    logger.warning(f"Failed to read {input_path} with encoding {encoding}, trying next...")
                except Exception as e:
                     logger.error(f"Error reading {input_path} with encoding {encoding}: {e}")
                     # Don't break here, allow trying other encodings

            if content is None:
                 logger.error(f"Could not read {input_path} with any attempted encoding.")
                 return False

            logger.debug("Successfully read %d bytes", len(content))

            # Parse content
            logger.debug("Starting parsing of file content")
            parsed_data = self._parse_fs2_file(content)
            logger.debug("Successfully parsed file content")

            # Write converted .tres file
            # Ensure output path has .tres extension
            output_tres_path = output_path.with_suffix(self.target_extension)
            logger.debug("Writing output to %s", output_tres_path)
            self._write_tres_file(parsed_data, output_tres_path)

            logger.info("Successfully converted %s to %s", input_path, output_tres_path)
            return True

        except ValueError as e:
            logger.error(f"Parsing error in {input_path} near line {self.current_line_num + 1}: {e}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error converting {input_path}: {e}", exc_info=True)
            # Optionally remove partially created output file on error
            # if output_tres_path.exists():
            #     output_tres_path.unlink()
            return False
