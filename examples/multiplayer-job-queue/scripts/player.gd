extends Node3D

@onready var input := $Input as JobQueuePlayerInput
@onready var camera := get_parent().camera as Camera3D

var click_indicator_scene: PackedScene = load("res://examples/multiplayer-job-queue/scenes/click-indicator.tscn")

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	var cursor_position: Vector2 = input.cursor_position
	$Cursor.position = cursor_position
	%Username.text = name
	
	if input.clicked:
		var ray_origin = camera.project_ray_origin(cursor_position)
		var ray_direction = camera.project_ray_normal(cursor_position)

		# Raycast into the scene
		var space_state = get_world_3d().direct_space_state
		var ray_length = 100  # Maximum ray length
		
		var params := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * ray_length)
		var result = space_state.intersect_ray(params)
		if result.has("position"):
			spawn_indicator(result.position)
			if result.collider.has_method("interact"):
				result.collider.interact()
		
func spawn_indicator(indicator_position: Vector3):
	var instance = click_indicator_scene.instantiate()
	get_tree().root.add_child(instance)
	instance.global_position = indicator_position + Vector3(0, 0.1, 0)
