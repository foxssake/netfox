extends RefCounted
class_name RecordedProperty

static func key_of(p_node: Node, p_property: NodePath) -> Array:
	return [p_node, p_property]

static func extract(key: Array) -> Variant:
	var node := key[0] as Node
	var property := key[1] as NodePath
	return node.get_indexed(property)

static func apply(key: Array, value: Variant):
	var node := key[0] as Node
	var property := key[1] as NodePath
	node.set_indexed(property, value)

var node: Node
var property: NodePath

func _init(p_node: Node, p_property: NodePath):
	node = p_node
	property = p_property

func extract_value() -> Variant:
	return node.get_indexed(property)

func apply_value(value: Variant) -> void:
	node.set_indexed(property, value)

func equals(other: RecordedProperty) -> bool:
	return node == other.node and property == other.property

func _to_string() -> String:
	return "$(%s:%s)" % [node, property]
