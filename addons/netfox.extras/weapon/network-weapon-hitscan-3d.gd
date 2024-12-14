extends Node3D
class_name NetworkWeaponHitscan3D

## A 3D-specific implementation of a networked hitscan (raycast) weapon.

## Maximum distance to cast the ray
@export var max_distance: float = 1000.0

## Mask used to detect raycast hits
@export_flags_3d_physics var collision_mask: int = 0xFFFFFFFF

## Colliders excluded from raycast hits
@export var exclude: Array[RID] = []

var _weapon: _NetworkWeaponProxy

## Try to fire the weapon and return the projectile.
## [br][br]
## Returns true if the weapon was fired.
func fire() -> bool:
	if not can_fire():
		return false
	
	_apply_data(_get_data())
	_after_fire()
	return true

## Check whether this weapon can be fired.
func can_fire() -> bool:
	return _weapon.can_fire()

func _init():
	_weapon = _NetworkWeaponProxy.new()
	add_child(_weapon, true, INTERNAL_MODE_BACK)
	_weapon.owner = self

	_weapon.c_can_fire = _can_fire
	_weapon.c_can_peer_use = _can_peer_use
	_weapon.c_after_fire = _after_fire
	_weapon.c_spawn = _spawn
	_weapon.c_get_data = _get_data
	_weapon.c_apply_data = _apply_data
	_weapon.c_is_reconcilable = _is_reconcilable
	_weapon.c_reconcile = _reconcile

## Override this method with your own can fire logic.
## [br][br]
## See [NetworkWeapon].
func _can_fire() -> bool:
	return true

## Override this method to check if a given peer can use this weapon.
## [br][br]
## See [NetworkWeapon].
func _can_peer_use(peer_id: int) -> bool:
	return true

## Override this method to run any logic needed after successfully firing the 
## weapon.
## [br][br]
## See [NetworkWeapon].
func _after_fire():
	pass

func _spawn():
	# No projectile is spawned for a hitscan weapon.
	pass

func _get_data() -> Dictionary:
	# Collect data needed to synchronize the firing event.
	return {
		"origin": global_transform.origin,
		"direction": -global_transform.basis.z  # Assuming forward direction.
	}

func _apply_data(data: Dictionary):
	# Reproduces the firing event on all peers.
	var origin = data["origin"] as Vector3
	var direction = data["direction"] as Vector3

	# Perform the raycast from origin in the given direction.
	var space_state = get_world_3d().direct_space_state

	# Create a PhysicsRayQueryParameters3D object.
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = origin
	ray_params.to = origin + direction * max_distance

	# Set collision masks or exclude objects:
	ray_params.collision_mask = collision_mask
	ray_params.exclude = exclude

	var result = space_state.intersect_ray(ray_params)

	if result:
		# Handle the hit result, such as spawning hit effects.
		_on_hit(result)

	# Play firing effects on all peers.
	_on_fire()

func _is_reconcilable(request_data: Dictionary, local_data: Dictionary) -> bool:
	# Always reconcilable
	return true

func _reconcile(local_data: Dictionary, remote_data: Dictionary):
	# Nothing to do on reconcile
	pass

## Override to implement raycast hit logic.
## [br][br]
## The parameter is the result of a
## [method PhysicsDirectSpaceState3D.intersect_ray] call.
func _on_hit(result: Dictionary):
	# Implement hit effect logic here.
	# var hit_position = result.position
	# var hit_normal = result.normal
	# var collider = result.collider

	# For example, you might emit a signal or instantiate a hit effect scene:
	# emit_signal("hit_detected", hit_position, hit_normal, collider)
	pass

## Override to implement firing effects, like muzzle flash or sound.
func _on_fire():
	# Implement firing effect logic here.
	pass
