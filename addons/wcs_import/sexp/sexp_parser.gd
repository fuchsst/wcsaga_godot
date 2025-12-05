@tool
extends RefCounted
class_name SexpParser

const SexpNodeRef = preload("res://scripts/resources/sexp/sexp_node.gd")

# Parses a raw SEXP string into a SexpNode tree.
# Returns the root SexpNode (usually an OPERATOR) or null on failure.
static func parse(sexp_string: String) -> Resource:
	var tokens = _tokenize(sexp_string)
	if tokens.is_empty():
		return null
	
	var context = {"index": 0, "tokens": tokens}
	return _parse_expression(context)

# Recursive parsing function
static func _parse_expression(context: Dictionary) -> Resource:
	var tokens = context["tokens"]
	if context["index"] >= tokens.size():
		return null
	
	var token: String = tokens[context["index"]]
	context["index"] += 1
	
	if token == "(":
		# Start of a list (Operator)
		# The next token should be the operator name
		if context["index"] >= tokens.size():
			push_error("SEXP Parse Error: Unexpected end of file after '('")
			return null
			
		var operator_name = tokens[context["index"]]
		
		# Handle empty list ()
		if operator_name == ")":
			context["index"] += 1
			# Treat empty list as null/void? or just empty operator?
			# In FS2 SEXPs, typically ( operator ... )
			# We'll create a dummy or handle it. 
			# But usually first item is op.
			# Let's check if it IS nested list ((...)) -> FS2 sometimes does weird things but mostly (op args)
			# Actually in basic lisp ( ( ... ) ) is valid.
			# But for FS2 sexps, the first element is ALWAYS the operator.
			# If the next token is also '(', then we have a list where the first element is a list.
			# This implies the list itself is the operator? Unlikely for FS2.
			# FS2 syntax: ( operator arg1 arg2 ... )
			pass

		var node = SexpNodeRef.new(SexpNodeRef.Type.OPERATOR, operator_name)
		context["index"] += 1 # Consume operator name
		
		while context["index"] < tokens.size():
			var peek = tokens[context["index"]]
			if peek == ")":
				context["index"] += 1 # Consume closing paren
				return node
			else:
				var arg_node = _parse_expression(context)
				if arg_node:
					node.add_argument(arg_node)
				else:
					# Error or end
					break
		return node

	elif token == ")":
		push_error("SEXP Parse Error: Unexpected ')'")
		return null
	
	else:
		# Atom (String, Number, Bool, Variable)
		return _parse_atom(token)

static func _parse_atom(token: String) -> Resource:
	# String literal
	if token.begins_with("\"") and token.ends_with("\""):
		# Strip quotes
		var val = token.substr(1, token.length() - 2)
		# Logic to unescape quotes if needed
		return SexpNodeRef.new(SexpNodeRef.Type.STRING, val)
	
	# Variable
	if token.begins_with("@"):
		return SexpNodeRef.new(SexpNodeRef.Type.VARIABLE, token)
	
	# Boolean
	if token == "true":
		return SexpNodeRef.new(SexpNodeRef.Type.BOOLEAN, true)
	if token == "false":
		return SexpNodeRef.new(SexpNodeRef.Type.BOOLEAN, false)
		
	# Number (Float or Int)
	if token.is_valid_float():
		var f = token.to_float()
		# check if int
		if token.find(".") == -1:
			return SexpNodeRef.new(SexpNodeRef.Type.NUMBER, token.to_int())
		else:
			return SexpNodeRef.new(SexpNodeRef.Type.NUMBER, f)
			
	# Fallback: Treat as unknown or string identifier (could be an enum val or something)
	# In SEXP, some args are just text tokens like "Friendly" or "Alpha 1" (if not quoted?) 
	# Usually names are strings.
	# But strictly speaking, if it's not one of above, we treat it as a string value
	# OR we might want to flag it.
	return SexpNodeRef.new(SexpNodeRef.Type.STRING, token)

static func _tokenize(text: String) -> PackedStringArray:
	var tokens = PackedStringArray()
	var current_token = ""
	var in_string = false
	var i = 0
	
	while i < text.length():
		var c = text[i]
		
		if in_string:
			if c == "\"":
				# Check for escaped quote? simple parsing for now
				in_string = false
				current_token += c
				tokens.append(current_token)
				current_token = ""
			else:
				current_token += c
		else:
			if c == "(":
				if current_token.length() > 0:
					tokens.append(current_token)
					current_token = ""
				tokens.append("(")
			elif c == ")":
				if current_token.length() > 0:
					tokens.append(current_token)
					current_token = ""
				tokens.append(")")
			elif c == "\"":
				if current_token.length() > 0:
					tokens.append(current_token) # Value before quote? should separate
					current_token = ""
				in_string = true
				current_token += c
			elif c == " " or c == "\t" or c == "\n" or c == "\r":
				if current_token.length() > 0:
					tokens.append(current_token)
					current_token = ""
			else:
				current_token += c
		
		i += 1
		
	if current_token.length() > 0:
		tokens.append(current_token)
		
	return tokens
