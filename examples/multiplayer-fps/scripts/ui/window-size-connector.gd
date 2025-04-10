@tool
class_name WindowSizeConnector extends Node

## Allows you to update node size to the window size

## The nodes to apply the new size to
@export var target_nodes: Array[Node] = []: set = _target_nodes_changed
## The percentage of the window size to fill (1.0 for full size)
@export var size_multiplier: float = 1.0

signal window_size_updated(new_size: Vector2)

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	get_tree().get_root().size_changed.connect(_on_window_resized)
	_on_window_resized(DisplayServer.window_get_size())
	
func _on_window_resized(new_size: Vector2) -> void:
	for node in target_nodes:
		if node and "size" in node:
			node.set_deferred("size", new_size * size_multiplier)
	window_size_updated.emit(new_size)

func _target_nodes_changed(new_value: Array[Node]):
	target_nodes = new_value
	if Engine.is_editor_hint():
		return

	_on_window_resized(Vector2(
		ProjectSettings.get_setting(&"display/window/size/viewport_width"),
		ProjectSettings.get_setting(&"display/window/size/viewport_height")
	))
