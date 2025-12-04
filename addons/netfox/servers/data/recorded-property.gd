extends RefCounted
class_name RecordedProperty

var node: Node
var property: NodePath

func _init(p_node: Node, p_property: NodePath):
	node = p_node
	property = p_property

func extract_value() -> Variant:
	return node.get_indexed(property)

func apply_value(value: Variant) -> void:
	node.set_indexed(property, value)
