import re
import os
import json
import uuid # For generating unique sub-resource IDs

# --- Configuration ---
# TODO: Load this mapping from sexp_constants.gd or a shared JSON file
# This is a placeholder - needs to be populated with ALL operators
OPERATOR_MAP = {
    "true": 0x0600, # OP_TRUE
    "false": 0x0601, # OP_FALSE
    "and": 0x0602, # OP_AND
    "or": 0x0604, # OP_OR
    "equals": 0x0605, # OP_EQUALS
    "is-destroyed": 0x0D02, # OP_IS_DESTROYED (Unlisted category)
    "distance": 0x0804, # OP_DISTANCE
    "mission-time": 0x0506, # OP_MISSION_TIME
    "hits-left": 0x0801, # OP_HITS_LEFT
    "hits-left-subsystem": 0x0802, # OP_HITS_LEFT_SUBSYSTEM
    "send-message": 0x0905, # OP_SEND_MESSAGE
    "add-goal": 0x0908, # OP_ADD_GOAL
    "modify-variable": 0x0924, # OP_MODIFY_VARIABLE
    "end-mission": 0x0941, # OP_END_MISSION
    "when": 0x0A00, # OP_WHEN
    "every-time": 0x0A02, # OP_EVERY_TIME
    "ai-chase": 0x0B00, # OP_AI_CHASE
    "ai-waypoints": 0x0B04, # OP_AI_WAYPOINTS
    "+": 0x0700, # OP_PLUS
    "-": 0x0701, # OP_MINUS
    "*": 0x0703, # OP_MUL
    "/": 0x0704, # OP_DIV
    "%": 0x0702, # OP_MOD
    "rand": 0x0705, # OP_RAND
    "abs": 0x0706, # OP_ABS
    # Add ALL other operators here...
}

# Godot SexpNode constants (mirroring sexp_constants.gd)
SEXP_LIST = 1
SEXP_ATOM = 2
SEXP_ATOM_OPERATOR = 1
SEXP_ATOM_NUMBER = 2
SEXP_ATOM_STRING = 3

# --- Tokenizer ---
def tokenize_sexp(sexp_string):
    """
    Splits an SEXP string into tokens (parentheses, atoms).
    Handles quoted strings correctly.
    """
    sexp_string = sexp_string.strip()
    # Add spaces around parentheses to ensure they are separate tokens
    sexp_string = sexp_string.replace('(', ' ( ').replace(')', ' ) ')
    tokens = []
    in_quotes = False
    current_token = ''
    for char in sexp_string:
        if char == '"':
            in_quotes = not in_quotes
            current_token += char # Keep quotes for now
            if not in_quotes: # End of quoted string
                 tokens.append(current_token)
                 current_token = ''
        elif in_quotes:
            current_token += char
        elif char.isspace():
            if current_token:
                tokens.append(current_token)
                current_token = ''
        else:
            current_token += char
    if current_token: # Add any remaining token
        tokens.append(current_token)
    # print(f"Tokens: {tokens}") # Debug
    return tokens

# --- Parser ---
def parse_sexp_recursive(tokens):
    """
    Recursively parses a list of tokens into a nested structure.
    Returns the parsed structure and the remaining tokens.
    """
    if not tokens:
        raise ValueError("Unexpected end of input")

    token = tokens.pop(0)

    if token == '(':
        # Start of a list
        parsed_list = []
        while tokens and tokens[0] != ')':
            sub_expression, tokens = parse_sexp_recursive(tokens)
            parsed_list.append(sub_expression)
        if not tokens or tokens.pop(0) != ')':
            raise ValueError("Expected ')'")
        # Check if it's an operator list
        if parsed_list and isinstance(parsed_list[0], dict) and parsed_list[0].get("subtype") == SEXP_ATOM_OPERATOR:
             return {"type": SEXP_LIST, "children": parsed_list}, tokens
        else:
             # This case might indicate an error or just a list of data - needs clarification
             print(f"Warning: Parsed list does not start with an operator: {parsed_list}")
             return {"type": SEXP_LIST, "children": parsed_list}, tokens # Treat as list for now
    elif token == ')':
        raise ValueError("Unexpected ')'")
    else:
        # It's an atom
        if token.startswith('"') and token.endswith('"'):
            # String atom (remove quotes)
            return {"type": SEXP_ATOM, "subtype": SEXP_ATOM_STRING, "text": token[1:-1]}, tokens
        elif token.startswith('@'):
             # Variable atom (treat as string for now, evaluator handles lookup)
             return {"type": SEXP_ATOM, "subtype": SEXP_ATOM_STRING, "text": token}, tokens
        elif token.lower() in OPERATOR_MAP:
            # Operator atom
            op_code = OPERATOR_MAP[token.lower()]
            return {"type": SEXP_ATOM, "subtype": SEXP_ATOM_OPERATOR, "text": token, "op_code": op_code}, tokens
        else:
            # Try parsing as a number
            try:
                # Attempt to parse as float, store as string for consistency? Or store float?
                # Storing as string matches SexpNode.text, evaluator uses get_number_value()
                float_val = float(token)
                return {"type": SEXP_ATOM, "subtype": SEXP_ATOM_NUMBER, "text": token}, tokens
            except ValueError:
                # If not a known operator or number, treat as a string atom (e.g., ship name)
                # This might need refinement based on context in FS2 files
                print(f"Warning: Treating unknown token '{token}' as string atom.")
                return {"type": SEXP_ATOM, "subtype": SEXP_ATOM_STRING, "text": token}, tokens


# --- TRES Formatter ---
def format_to_tres(parsed_data, base_resource_path):
    """
    Formats the parsed Python dictionary structure into a Godot .tres file string
    for the SexpNode resource.
    """
    tres_string = "[gd_resource type=\"Resource\" script_class=\"SexpNode\" load_steps=2 format=3 uid=\"uid://%s\"]\n\n" % str(uuid.uuid4())[:12]
    tres_string += "[ext_resource type=\"Script\" path=\"res://scripts/scripting/sexp/sexp_node.gd\" id=\"1_abcde\"]\n\n" # Placeholder ID

    sub_resources = {} # Store sub-resources to define them later

    def build_node_string(node_data, indent=""):
        nonlocal tres_string
        node_id = "SubResource_%s" % str(uuid.uuid4()).replace('-', '')[:8] # Unique ID for sub-resource
        sub_resource_def = f"{indent}[sub_resource type=\"SexpNode\" id=\"{node_id}\"]\n"
        sub_resource_def += f"{indent}script = ExtResource(\"1_abcde\")\n"
        sub_resource_def += f"{indent}node_type = {node_data['type']}\n"

        if node_data['type'] == SEXP_ATOM:
            sub_resource_def += f"{indent}atom_subtype = {node_data['subtype']}\n"
            # Escape quotes within the text string for TRES format
            escaped_text = node_data.get('text', '').replace('"', '\\"')
            sub_resource_def += f"{indent}text = \"{escaped_text}\"\n"
            if node_data['subtype'] == SEXP_ATOM_OPERATOR:
                sub_resource_def += f"{indent}op_code = {node_data.get('op_code', -1)}\n"
        elif node_data['type'] == SEXP_LIST:
            children_refs = []
            if 'children' in node_data:
                for child_data in node_data['children']:
                    child_id = build_node_string(child_data, indent) # Recursive call
                    children_refs.append(f"SubResource(\"{child_id}\")")
            sub_resource_def += f"{indent}children = [{', '.join(children_refs)}]\n"

        sub_resources[node_id] = sub_resource_def
        return node_id

    # Build the main resource string
    root_node_id = build_node_string(parsed_data, "")
    tres_string += "[resource]\n"
    tres_string += "script = ExtResource(\"1_abcde\")\n"
    # Reference the root sub-resource properties directly
    root_node_def = sub_resources.pop(root_node_id) # Get root def and remove from sub_resources
    # Extract properties from the root node definition string (simple parsing)
    for line in root_node_def.splitlines():
        if "=" in line and not line.strip().startswith("[sub_resource"):
             tres_string += line.strip() + "\n"

    # Append sub-resource definitions
    tres_string += "\n"
    for node_id, node_def in sub_resources.items():
        tres_string += node_def + "\n"

    return tres_string


# --- Main Execution ---
if __name__ == "__main__":
    # Example Usage
    # sexp_input = '(is-destroyed "alpha 1")'
    # sexp_input = '(+ 10 (mission-time))'
    # sexp_input = '(and (> (hits-left "beta 1") 50) (is-destroyed "gamma wing"))'
    sexp_input = '(when (equals @MyVariable "active") (send-message "Attack Command" "Command" 1))'
    output_filename = "test_sexp.tres"
    output_dir = "migration_tools/converted/sexp_test/"

    print(f"Input SEXP: {sexp_input}")

    try:
        tokens = tokenize_sexp(sexp_input)
        parsed_tree, remaining_tokens = parse_sexp_recursive(list(tokens)) # Pass a copy

        if remaining_tokens:
            print(f"Warning: Unparsed tokens remaining: {remaining_tokens}")

        print("\nParsed Tree (Python Dict):")
        print(json.dumps(parsed_tree, indent=2))

        tres_output = format_to_tres(parsed_tree, "res://scripts/scripting/sexp/sexp_node.gd")

        print(f"\nGenerated TRES Output (saving to {output_filename}):")
        print(tres_output)

        # Ensure output directory exists
        os.makedirs(output_dir, exist_ok=True)
        output_path = os.path.join(output_dir, output_filename)

        with open(output_path, "w") as f:
            f.write(tres_output)
        print(f"Successfully saved to {output_path}")

    except ValueError as e:
        print(f"\nParsing Error: {e}")
    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}")
