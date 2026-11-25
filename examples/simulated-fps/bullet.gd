extends Node3D
class_name SimulatedBullet

## Generic bullet implementation.

## how much distance this bullet travels in a second.
@export var speed : float = 50.0
@export var life_time_secs : float = 3.0
@export var gravity : float = 9.5
@export var damage : int = 50
@export_flags_3d_physics var collision_mask : int = 0b1
@export var bullet_decal_scene : PackedScene = null

var _velocity := Vector3.ZERO
@onready var _logger := NetfoxLogger._for_netfox("Bullet" + self.name)

func _ready() -> void:
	if not multiplayer.is_server():
		NetworkTime.after_tick.connect(_on_after_tick)

func step(delta : float, _tick : int) -> void:
	life_time_secs -= delta
	
	if life_time_secs <= 0.0:
		queue_free()
		return
	
	var old_position := global_position
	_velocity.y -= gravity * delta
	global_position += _velocity * delta
	
	if _check_hit(old_position, global_position):
		queue_free()

func is_alive() -> bool:
	return not is_queued_for_deletion()

## Fire this bullet
func fire(origin : Vector3, direction : Vector3) -> void:
	position = origin
	_velocity = direction.normalized() * speed
	look_at_from_position(origin, origin + direction, _get_safe_up(direction))
	
	# So that parent node transform does not matter.
	top_level = true

# Manually step this bullet on non-server game.
func _on_after_tick(delta: float, tick: int) -> void:
	step(delta, tick)

# Check the hit by performing raycast from last known position to current position. 
# Returns true if hit something.
func _check_hit(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	query.collide_with_areas = true
	var result := space.intersect_ray(query)
	
	if result.is_empty():
		return false
	
	_on_hit(result)
	return true

func _on_hit(result : Dictionary) -> void:
	var impacted_node := _get_hit_node(result.collider, result.shape)
	
	_logger.debug("Bullet hit to position: %s", [result["position"]])
	
	if multiplayer.is_server():
		if impacted_node.has_method("damage"):
			impacted_node.damage()
	
	_spawn_decal(result["position"], result["normal"])

func _spawn_decal(glob_pos : Vector3, surface_normal : Vector3) -> void:
	if bullet_decal_scene:
		var decal := bullet_decal_scene.instantiate() as Node3D
		get_tree().root.add_child(decal)
		decal.global_position = glob_pos
		
		# adjust the decal
		decal.look_at(decal.global_position + surface_normal, _get_safe_up(surface_normal))
		decal.rotate_object_local(Vector3.RIGHT, -PI / 2.0)

## Returns the node a projectile should damage for a ray or shape cast hit
func _get_hit_node(collider : Object, shape_index : int) -> Node:
	
	var collision_object := collider as CollisionObject3D
	
	if not collision_object:
		return null
	
	var shape_owner := collision_object.shape_owner_get_owner(
		collision_object.shape_find_owner(shape_index)) as Node
	
	if not shape_owner:
		return null
	
	return shape_owner.get_parent()

## Returns an up vector usable with look_at() for the given direction.
## look_at() can't use an up vector parallel to the look direction
## (shooting straight up/down, hitting floors/ceilings), so fall back to FORWARD.
static func _get_safe_up(direction : Vector3) -> Vector3:
	if absf(direction.normalized().dot(Vector3.UP)) > 0.99:
		return Vector3.FORWARD
	return Vector3.UP
