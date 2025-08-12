extends Object

static func is_equal(actual, expected) -> bool:
	if actual is Object and actual.has_method("equals"):
		return actual.equals(expected)
	return actual == expected

static func is_empty(object: Variant) -> Variant:
	if _is_builtin_container(object) or _is_stringlike(object):
		return object.is_empty()
	elif object is Object:
		if object.has_method("is_empty"):
			return object.is_empty()
		else:
			return ERR_METHOD_NOT_FOUND
	else:
		return ERR_CANT_RESOLVE

static func contains(object: Variant, item: Variant) -> Variant:
	if _is_builtin_container(object):
		return object.has(item)
	elif _is_stringlike(object):
		return object.contains(str(item))
	elif object is Object:
		if object.has_method("has"):
			return object.has(item)
		else:
			return ERR_METHOD_NOT_FOUND
	else:
		return ERR_CANT_RESOLVE

static func _is_builtin_container(object: Variant) -> bool:
	return object is Array or object is Dictionary \
		or object is PackedByteArray or object is PackedColorArray \
		or object is PackedFloat32Array or object is PackedFloat64Array \
		or object is PackedInt32Array or object is PackedInt64Array \
		or object is PackedStringArray \
		or object is PackedVector2Array or object is PackedVector3Array

static func _is_stringlike(object: Variant) -> bool:
	return object is String or object is StringName or object is NodePath
