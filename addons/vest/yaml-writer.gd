extends Object
class_name YAMLWriter

## YAML serializer.
##
## Used for adding extra data to [TAPReporter] reports.
## [br][br]
## For custom types, implement [code]_to_yaml[/code]. It should return a basic
## type, which will be then serialized.
## [br][br]
## Alternatively, implement [code]_to_yaml_raw[/code], which should return the
## raw YAML string.
## [br][br]
## [b]Not recommended for use outside of generating test reports.[/b]

## Convert a value to YAML.
static func stringify(what, indent: int = 0) -> String:
	if indent > 0:
		return _indented(stringify(what), indent)

	var type := typeof(what)

	if what == null:
		return "null"

	if type == TYPE_INT or type == TYPE_FLOAT:
		return str(what)

	if what is String or what is StringName or what is NodePath:
		what = str(what)
		if not what.contains("\n") and not what.contains("\"") and what.strip_edges() == what:
			return what
		return "\"%s\"" % what.c_escape()

	if _is_packed_array(what):
		what = Array(what)

	if what is Array:
		var result = (what
			.map(func(it): return stringify(it))
			.map(func(it): return _indented_value(it, 2))
			.map(func(it): return "- " + it)
		)
		return "\n".join(result)

	if what is Dictionary:
		var result := PackedStringArray()
		for key in what.keys():
			var value = what.get(key)

			var stringified_key := _stringify_key(key)
			stringified_key = stringified_key
			var stringified_value := _stringify_value(value)

			result.append("%s: %s" % [stringified_key, stringified_value])
		return "\n".join(result)

	if what is Object:
		if what.has_method("_to_yaml"):
			return stringify(what.call("_to_yaml", indent))
		elif what.has_method("_to_yaml_raw"):
			return what.call("_to_yaml_raw", indent)

	return stringify(str(what))

static func _indented(what: String, level: int) -> String:
	if level == 0:
		return what

	var prefix := " ".repeat(level)
	var lines := what.split("\n")
	for i in range(lines.size()):
		lines[i] = prefix + lines[i]
	return "\n".join(lines)

static func _indented_value(what: String, level: int) -> String:
	if level == 0 or not what.contains("\n"):
		return what
	else:
		return "\n" + _indented(what, level)

static func _stringify_key(what) -> String:
	match typeof(what):
		TYPE_FLOAT: return str(what)
		TYPE_INT: return str(what)
		TYPE_STRING:
			if RegEx.create_from_string("[\\s\"']").search(what):
				return stringify(what)
			else:
				return what
		_: return stringify(str(what))

static func _stringify_value(what) -> String:
	if _is_complex(what):
		return "\n" + stringify(what, 2)
	return stringify(what)

static func _is_complex(what) -> bool:
	return (
		what is Array or
		what is Dictionary or
		what is Object
	)

static func _is_packed_array(what) -> bool:
	return (
		what is PackedByteArray or
		what is PackedColorArray or
		what is PackedFloat32Array or
		what is PackedFloat64Array or
		what is PackedInt32Array or
		what is PackedInt64Array or
		what is PackedStringArray or
		what is PackedVector2Array or
		what is PackedVector3Array
	)
