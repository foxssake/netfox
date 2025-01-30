@tool
class_name CrossHair extends Node2D

## Places a crosshair in the center of the screen

@export var crosshair_sprite: Texture2D
@export var crosshair_scale: Vector2 = Vector2(1, 1)

var sprite2d: Sprite2D = Sprite2D.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	get_tree().get_root().size_changed.connect(_on_window_resized)
	_on_window_resized(DisplayServer.window_get_size())

func _enter_tree() -> void:
	if has_node("Sprite2D"): return
	
	sprite2d.name = "Sprite2D"
	sprite2d.set_texture(crosshair_sprite)
	sprite2d.scale = crosshair_scale;
	add_child(sprite2d)

func _on_window_resized(new_size: Vector2) -> void:
	if Engine.is_editor_hint():
		return

	sprite2d.position = new_size / 2
	sprite2d.scale = crosshair_scale
