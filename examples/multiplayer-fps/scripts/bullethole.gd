extends Node3D
class_name BulletHole

## Spawns a bullethole

## A StandardMaterial3D to use as the bullethole decal.
@export var material: StandardMaterial3D
## Maximum number of bullet holes
@export var instance_limit: int = 20
## The minimum size of the hole
@export var hole_minimum_size: float = 0.15
## The maximum size of the hole
@export var hole_maximum_size: float = 0.2

@export_flags_3d_render var decal_mask := 1
@export_flags_3d_render var decal_layer := 1

var pool := NodePool.new()

func _ready():
	pool.pool_limit = instance_limit
	pool.spawn_root = get_tree().root.get_node("multiplayer-fps/Map/StaticBody3D")
	
	var decal_node: Decal = Decal.new()
	decal_node.cull_mask = decal_mask
	decal_node.layers = decal_layer
	
	pool.target_node = decal_node

## Creates a bullethole decal, applies the texture and rotation/position calculations and removes the bullethole after the pool is full
func action(result: Dictionary) -> void:
	var decal_node: Decal = pool.next()
	create_bullethole.call_deferred(decal_node, result)
	
func create_bullethole(decal_node: Decal, result: Dictionary):
	decal_node.texture_albedo = material.albedo_texture
	decal_node.texture_emission = material.emission_texture
	decal_node.texture_normal = material.normal_texture
	decal_node.size = Vector3(
		randf_range(hole_minimum_size, hole_maximum_size), 
		0.02, 
		randf_range(hole_minimum_size, hole_maximum_size)
	)

	# Extract position and normal from the result dictionary
	var collision_point: Vector3 = result.position
	var collision_normal: Vector3 = result.normal.normalized()

	# Construct a basis where the z-axis aligns with the collision normal
	var z_axis = collision_normal
	var x_axis = z_axis.cross(Vector3.UP).normalized()
	if x_axis.length() == 0:
		x_axis = z_axis.cross(Vector3.RIGHT).normalized()
	var y_axis = z_axis.cross(x_axis).normalized()
	var collision_basis = Basis(x_axis, y_axis, z_axis)

	# Rotate the decal 90 degrees around the x-axis
	var rotation_basis = Basis().rotated(Vector3(1, 0, 0), deg_to_rad(90))
	var transform = Transform3D(rotation_basis, Vector3())

	# Combine the collision basis and the rotation
	decal_node.global_transform = Transform3D(collision_basis, collision_point) * transform

	# Apply random rotation around the normal
	var random_rotation = Basis(collision_normal, randf_range(0, 2 * PI))
	decal_node.global_transform.basis = random_rotation * decal_node.global_transform.basis
