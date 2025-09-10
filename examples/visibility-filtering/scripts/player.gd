@tool
extends CharacterBody3D

@export var speed := 4.0
@export var jump_velocity := 8.0

@export var input: Node
@export var body_mesh: MeshInstance3D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")

func is_local() -> bool:
	return input.is_multiplayer_authority()

func get_local() -> ExampleVisibilityFiltering.Player:
	return get_tree().get_first_node_in_group("Local Player")

func can_see(target: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	
	var query := PhysicsRayQueryParameters3D.new()
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 2 # Only collide with level geometry
	query.from = global_position
	query.to = target.global_position
	
	return space.intersect_ray(query).is_empty()

func _get_rollback_state_properties() -> Array:
	return [
		"transform",
		"velocity"
	]

func _get_interpolated_properties() -> Array:
	return [
		"transform"
	]

func _ready():
	if Engine.is_editor_hint(): return

	if not input: input = $Input
	if not body_mesh: body_mesh = $"Body Mesh"

	# Set spawn position
	position = Vector3(0, 4, 0)

	# Assign a random color
	var player_id := input.get_multiplayer_authority()

	var color := Color.from_hsv((hash(player_id) % 256) / 256.0, 1.0, 1.0)
	var material := body_mesh.get_active_material(0) as StandardMaterial3D
	material = material.duplicate()
	material.albedo_color = color
	body_mesh.set_surface_override_material(0, material)

	# Save local player
	if is_local():
		add_to_group("Local Player")

func _rollback_tick(dt, _tick, _is_fresh: bool):
	# Add gravity
	_force_update_is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * dt

	var input_dir = input.movement
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# Jump
	if input.is_jumping and is_on_floor():
		velocity.y = jump_velocity

	# move_and_slide assumes physics delta
	# multiplying velocity by NetworkTime.physics_factor compensates for it
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _physics_process(dt: float):
	# Determine visibility
	var is_visible := true
	if not is_local():
		is_visible = get_local().can_see(self)

	# Quick hack to smoothly fade
	body_mesh.transparency = lerpf(body_mesh.transparency, 0.0 if is_visible else 0.5, dt / 0.15)

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

