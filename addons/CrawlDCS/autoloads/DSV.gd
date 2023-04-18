# (D)ictionary (S)chema (V)erifier
# Author: Bryan Miller
# Version: 0.0.6
#
# The intent of this script is to allow users to validate the data contained in
# a dictionary against a specially formatted schema dictionary.
#
# 

@tool
extends Node

# ---
# NOTE: This is crude, ugly, and bare bones. I feel it does the job I need it to
#  but would need heavy work to make it more "universal" and error-proof.
#  You have been warned!
# ---

# ------------------------------------------------------------------------------
# Constants and ENUMs
# ------------------------------------------------------------------------------
const ALLOWED_TYPES : PackedByteArray = [
	TYPE_BOOL,
	TYPE_ARRAY, TYPE_DICTIONARY,
	TYPE_INT, TYPE_FLOAT,
	TYPE_STRING, TYPE_STRING_NAME,
	TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I,
	TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY,
	TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY,
	TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY,
]

const ALLOWED_KEY_TYPES : PackedByteArray = [
	TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME,
	TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I
]

# ------------------------------------------------------------------------------
# Helper Class
# ------------------------------------------------------------------------------
class RefSchema:
	var _refs : Dictionary = {}
	var _parent : RefSchema = null
	
	func _init(parent : RefSchema) -> void:
		_parent = parent
	
	func has_ref_schema(name : StringName) -> bool:
		if name in _refs: return true
		if _parent != null:
			return _parent.has_ref_schema(name)
		return false
	
	func add_ref_schema(name : StringName, schema : Dictionary) -> int:
		if name in _refs:
			return ERR_ALREADY_IN_USE
		if _parent != null:
			if _parent.has_ref_schema(name):
				return ERR_ALREADY_IN_USE
		_refs[name] = schema
		return OK
	
	func get_ref_schema(name : StringName) -> Dictionary:
		if name in _refs:
			return _refs[name]
		if _parent != null:
			return _parent.get_ref_schema(name)
		return {}

# ------------------------------------------------------------------------------
# Static Private Methods
# ------------------------------------------------------------------------------

static func _VerifyIntValue(val : int, def : Dictionary, state : Dictionary) -> int:
	if &"one_of" in def and (typeof(def[&"one_of"]) == TYPE_PACKED_INT32_ARRAY or \
			typeof(def[&"one_of"]) == TYPE_PACKED_INT64_ARRAY or \
			typeof(def[&"one_of"]) == TYPE_PACKED_BYTE_ARRAY or \
			typeof(def[&"one_of"]) == TYPE_ARRAY):
		if def[&"one_of"].find(val) < 0:
			printerr("VALIDATION ERROR [", state[&"path"], "]: Value does not match one of the expected values.")
			return ERR_DOES_NOT_EXIST
	else:
		if &"min" in def and def[&"min"] > val:
			printerr("VALIDATION ERROR [", state[&"path"], "]: Value less than minimum.")
			return ERR_PARAMETER_RANGE_ERROR
		if &"max" in def and def[&"max"] < val:
			printerr("VALIDATION ERROR [", state[&"path"], "]: Value greater than maximum.")
			return ERR_PARAMETER_RANGE_ERROR
	return OK

static func _VerifyFloatValue(val : float, def : Dictionary, state : Dictionary) -> int:
	if &"one_of" in def and (typeof(def[&"one_of"]) == TYPE_PACKED_FLOAT32_ARRAY or \
			typeof(def[&"one_of"]) == TYPE_PACKED_FLOAT64_ARRAY or \
			typeof(def[&"one_of"]) == TYPE_ARRAY):
		if def[&"one_of"].find(val) < 0:
			printerr("VALIDATION ERROR [", state[&"path"], "]: Value does not match one of the expected values.")
			return ERR_DOES_NOT_EXIST
	else:
		if &"min" in def:
			if def[&"min"] > val:
				printerr("VALIDATION ERROR [", state[&"path"], "]: Value less than minimum.")
				return ERR_PARAMETER_RANGE_ERROR
		if &"max" in def:
			if def[&"max"] < val:
				printerr("VALIDATION ERROR [", state[&"path"], "]: Value greater than maximum.")
				return ERR_PARAMETER_RANGE_ERROR
	return OK

static func _VerifyStringValue(s : String, def : Dictionary, state : Dictionary) -> int:
	var allow_empty : bool = true
	if &"one_of" in def and typeof(def[&"one_of"]) == TYPE_PACKED_STRING_ARRAY:
		if def[&"one_of"].find(s) < 0:
			printerr("VALIDATION ERROR [", state[&"path"], "]: Value does not match one of the expected values.")
			return ERR_DOES_NOT_EXIST
	elif &"none_of" in def and typeof(def[&"none_of"]) == TYPE_PACKED_STRING_ARRAY:
		if def[&"none_of"].find(s) >= 0:
			printerr("VALIDATION ERROR [", state[&"path"], "]: Value matches an exclusion value.")
			return ERR_INVALID_DATA
	if &"allow_empty" in def and typeof(def[&"allow_empty"]) == TYPE_BOOL:
		allow_empty = def[&"allow_empty"]
	if allow_empty == false and s.strip_edges() == "":
		printerr("VALIDATION ERROR [", state[&"path"], "]: Value is empty string.")
		return ERR_PARAMETER_RANGE_ERROR
	return OK

static func _VerifyStringNameValue(s : StringName, def : Dictionary, state : Dictionary) -> int:
	var allow_empty : bool = true
	if &"one_of" in def and typeof(def[&"one_of"]) == TYPE_PACKED_STRING_ARRAY:
		if def[&"one_of"].find(s) < 0:
			printerr("VALIDATION ERROR [", state[&"path"], "]: Value does not match one of the expected values.")
			return ERR_DOES_NOT_EXIST
	elif &"none_of" in def and typeof(def[&"none_of"]) == TYPE_PACKED_STRING_ARRAY:
		if def[&"none_of"].find(s) >= 0:
			printerr("VALIDATION ERROR [", state[&"path"], "]: Value matches an exclusion value.")
			return ERR_INVALID_DATA
	if &"allow_empty" in def and typeof(def[&"allow_empty"]) == TYPE_BOOL:
		allow_empty = def[&"allow_empty"]
	if allow_empty == false and s.strip_edges() == &"":
		printerr("VALIDATION ERROR [", state[&"path"], "]: Value is empty string.")
		return ERR_PARAMETER_RANGE_ERROR
	return OK

static func _VerifyVec2IValue(val : Vector2i, def : Dictionary, state : Dictionary) -> int:
	if &"minmax" in def and def[&"minmax"] == true:
		if val.x > val.y:
			printerr("VALIDATION ERROR [", state[&"path"], "]: X(min) and Y(max) out of order.")
			return ERR_PARAMETER_RANGE_ERROR
	return OK

static func _VerifyArrayValue(val : Array, def : Dictionary, state : Dictionary) -> int:
	var base_path : String = state[&"path"]
	var refs : RefSchema = null if not &"refs" in state else state[&"refs"]
	
	var idef : Dictionary = {}
	if &"item_ref" in def:
		if refs != null:
			idef = refs.get_ref_schema(def[&"item_ref"])
		if idef.is_empty():
			printerr("VALIDATION WARNING [", base_path, "]: Referencing undefined sub-schema \"", def[&"item_ref"], "\". Validation may be effected.")
	elif &"item" in def:
		idef = def[&"item"]
	
	if &"size" in def:
		if typeof(def[&"size"]) != TYPE_INT:
			printerr("VALIDATION ERROR [", base_path, "]: Schema property 'size' invalid type.")
			return ERR_INVALID_DECLARATION
		if val.size() != def[&"size"]:
			printerr("VALIDATION ERROR [", base_path, "]: Array size does not match expected size.")
			return ERR_PARAMETER_RANGE_ERROR
	else:
		if &"size_min" in def:
			if typeof(def[&"size_min"]) != TYPE_INT:
				printerr("VALIDATION ERROR [", base_path, "]: Schema property 'size_min' invalid type.")
				return ERR_INVALID_DECLARATION
			if val.size() < def[&"size_min"]:
				printerr("VALIDATION ERROR [", base_path, "]: Array size below minimum.")
				return ERR_PARAMETER_RANGE_ERROR
		if &"size_max" in def:
			if typeof(def[&"size_max"]) != TYPE_INT:
				printerr("VALIDATION ERROR [", base_path, "]: Schema property 'size_max' invalid type.")
				return ERR_INVALID_DECLARATION
			if val.size() > def[&"size_max"]:
				printerr("VALIDATION ERROR [", base_path, "]: Array size above maximum.")
				return ERR_PARAMETER_RANGE_ERROR
	
	if not idef.is_empty():
		for i in range(val.size()):
			var v = val[i]
			var path : String = "%s[%d]"%[base_path, i]
			
			if not &"type" in idef:
				printerr("VALIDATION ERROR [", path, "]: Schema for entry missing required 'type' property.")
				return ERR_INVALID_DECLARATION
			if ALLOWED_TYPES.find(idef[&"type"]) < 0:
				printerr("VALIDATION ERROR [", path, "]: Schema 'type' property invalid value.")
				return ERR_INVALID_DECLARATION
			
			if typeof(v) != idef[&"type"]:
				printerr("VALIDATION ERROR [", path, "]: Unexpected entry type.")
				return ERR_INVALID_DATA
			var res : int = OK
			match idef[&"type"]:
				TYPE_INT:
					res = _VerifyIntValue(v, idef, {&"path":path})
				TYPE_STRING:
					res = _VerifyStringValue(v, idef, {&"path":path})
				TYPE_STRING_NAME:
					res = _VerifyStringNameValue(v, idef, {&"path":path})
				TYPE_VECTOR2I:
					res = _VerifyVec2IValue(v, idef, {&"path":path})
				TYPE_ARRAY:
					res = _VerifyArrayValue(v, idef, {&"path":path, &"refs":refs})
				TYPE_DICTIONARY:
					if &"def" in idef:
						res = _VerifyDictionaryValue(v, idef[&"def"], {&"path":path, &"refs":refs})
			if res != OK:
				return res
	return OK


# NOTE: This method is a helper method for the _VerifyDictionaryValue() method defined below.
static func _VerifyValAgainstSchema(val, schema : Dictionary, key, base_path : String, state : Dictionary) -> int:
	if not &"type" in schema:
		printerr("VALIDATION ERROR [", base_path, "]: Schema for entry missing required 'type' property.")
		return ERR_INVALID_DECLARATION
	if ALLOWED_TYPES.find(schema[&"type"]) < 0:
		printerr("VALIDATION ERROR [", base_path, "]: Schema 'type' property invalid value.")
		return ERR_INVALID_DECLARATION
	
	if typeof(val) != schema[&"type"]:
		printerr("VALIDATION ERROR [", base_path, "]: Data structure property \"", key, "\" value invalid type.")
		return ERR_INVALID_DATA
	
	match schema[&"type"]:
		TYPE_INT:
			var res : int = _VerifyIntValue(val, schema, state)
			if res != OK:
				return res
		TYPE_STRING:
			var res : int = _VerifyStringValue(val, schema, state)
			if res != OK:
				return res
		TYPE_STRING_NAME:
			var res : int = _VerifyStringNameValue(val, schema, state)
			if res != OK:
				return res
		TYPE_VECTOR2I:
			var res : int = _VerifyVec2IValue(val, schema, state)
			if res != OK:
				return res
		TYPE_ARRAY:
			var res : int = _VerifyArrayValue(val, schema, state)
			if res != OK:
				return res
		TYPE_DICTIONARY:
			if &"def" in schema:
				var res : int = _VerifyDictionaryValue(val, schema[&"def"], state)
				if res != OK:
					return res
	return OK

static func _FindSchemaFrom(d : Dictionary, refs : RefSchema, return_source_if_no_ref : bool = false) -> Dictionary:
	if &"ref" in d:
		if refs != null:
			if typeof(d[&"ref"]) == TYPE_STRING or typeof(d[&"ref"]) == TYPE_STRING_NAME:
				return refs.get_ref_schema(d[&"ref"])
	elif not return_source_if_no_ref:
		if &"def" in d:
			if typeof(d[&"def"]) == TYPE_DICTIONARY:
				return d[&"def"]
	else: return d
	
	return {}


static func _ScrapeKeysOfType(schema : Dictionary, refs : RefSchema, base_path : String, key_type_defs : Dictionary) -> int:
	for key in schema.keys():
		if typeof(key) == TYPE_STRING or typeof(key) == TYPE_STRING_NAME:
			if key.begins_with("!"):
				if key.begins_with("!KEY_OF_TYPE_"):
					if not &"type" in schema[key]:
						printerr("SCHEMA ERROR [", base_path, ".", key, "]: Key-type for entry missing required 'type' property.")
						return ERR_INVALID_DECLARATION
					if ALLOWED_KEY_TYPES.find(schema[key][&"type"]) < 0:
						printerr("SCHEMA ERROR [", base_path, ".", key, "]: Key-type 'type' property invalid value.")
						return ERR_INVALID_DECLARATION
					if schema[key][&"type"] in key_type_defs:
						printerr("SCHEMA ERROR [", base_path, ".", key, "]: Key-type definition previously defined.")
						return ERR_ALREADY_IN_USE
					
					# def[key] needs either the property "ref" or "def" and return a non-empty dictionary.
					var key_schema = _FindSchemaFrom(schema[key], refs, false)
					if key_schema.is_empty():
						printerr("SCHEMA ERROR [", base_path, ".", key, "]: Schema definition does not exist or referencing undefined sub-schema.")
						return ERR_DOES_NOT_EXIST
					key_type_defs[schema[key][&"type"]] = schema[key][&"def"]
	return OK


static func _VerifyDictionaryValue(val : Dictionary, def : Dictionary, state : Dictionary) -> int:
	var base_path : String = "ROOT" if not &"path" in state else state[&"path"]
	var refs : RefSchema = null if not &"refs" in state else state[&"refs"]
	
	if &"!REFS" in def and typeof(def[&"!REFS"]) == TYPE_DICTIONARY:
		refs = RefSchema.new(refs)
		for key in def[&"!REFS"]:
			if typeof(def[&"!REFS"][key]) == TYPE_DICTIONARY:
				var res : int = refs.add_ref_schema(key, def[&"!REFS"][key])
				if res != OK:
					printerr("VALIDATION WARNING: Schema redefining sub-schema \"", key, "\". Validation may be effected.")
	
	var key_type_defs : Dictionary = {} # May or may not be used.
	var res : int = _ScrapeKeysOfType(def, refs, base_path, key_type_defs)
	if not res == OK:
		return res
	
	# Determines if only validation should fail if dictionary has keys other than the ones defined.
	# By default, this is true.
	var only_def : bool = true
	if &"!ONLY_DEF" in def and typeof(def[&"!ONLY_DEF"]) == TYPE_BOOL:
		only_def = def[&"!ONLY_DEF"]
	
	if only_def:
		for vkey in val.keys():
			if typeof(vkey) in key_type_defs:
				continue # This key is a valid type.
			
			if not vkey in def:
				printerr("VALIDATION ERROR [", base_path, "]: Object key \"", vkey, "\" not defined in Schema.")
				return ERR_CANT_RESOLVE
	
	for key in def.keys():
		if typeof(key) == TYPE_STRING or typeof(key) == TYPE_STRING_NAME:
			if key.begins_with("!"):
				continue
	
		var path : String = key
		if base_path != "ROOT":
			path = "%s.%s"%[base_path, key]
		
		if not key in val:
			if def[key][&"req"] == true:
				printerr("VALIDATION ERROR [", base_path, "]: Data structure missing required property \"", key, "\".")
				return ERR_INVALID_DECLARATION
			continue
		
		# def[key] needs the property "ref" (and have it be a non-empty dictionary) or def[key] is assumed to be the whole schema.
		var schema : Dictionary = _FindSchemaFrom(def[key], refs, true)
		if schema.is_empty():
			printerr("SCHEMA ERROR [", base_path, "]: Schema definition does not exist or referencing undefined sub-schema.")
			return ERR_DOES_NOT_EXIST
		
		res = _VerifyValAgainstSchema(val[key], schema, key, base_path, {&"path":path, &"refs":refs})
		if res != OK:
			return res

	# If there are key type definitions/schemas
	if not key_type_defs.is_empty():
		# We loop through every defined key type
		for ktype in key_type_defs.keys():
			# and every key in val
			for key in val.keys():
				# and if they match
				if typeof(key) == ktype:
					# Validate the value against the key_type_defs schema!
					var path : String = "%s.%s"%[base_path, key]
					res = _VerifyValAgainstSchema(val[key], key_type_defs[ktype], key, base_path, {
						&"path":path, &"refs":refs
					})
					if res != OK:
						return res
	
	return OK


# ------------------------------------------------------------------------------
# Static Public Methods
# ------------------------------------------------------------------------------

static func verify_schema(s : Dictionary) -> int:
	if s.is_empty():
		pass
	# TODO: You know... actually write this method!
	# Not strictly needed for this current project, but this could be useful
	# in other projects, so, being able to verify schema dictionaries could be
	# rather useful.
	return OK

static func verify(d : Dictionary, schema : Dictionary) -> int:
	return _VerifyDictionaryValue(d, schema, {})


