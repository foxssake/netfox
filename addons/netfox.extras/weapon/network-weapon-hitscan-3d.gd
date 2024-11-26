extends Node3D
class_name NetworkWeaponHitscan3D

## A 3D-specific implementation of a networked hitscan (raycast) weapon.

## Maximum distance to cast the ray
@export var max_distance: float = 1000.0

var _weapon: _NetworkWeaponProxy

func can_fire() -> bool:
	return _weapon.can_fire()

func fire():
	return _weapon.fire()

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

## Determines if the weapon can fire. Always true in this basic implementation.
func _can_fire() -> bool:
	return true

## Allows all peers to use the weapon.
func _can_peer_use(peer_id: int) -> bool:
	return true

## Placeholder for any actions after firing.
func _after_fire():
	pass

## No projectile is spawned for a hitscan weapon.
func _spawn():
	pass

## Collects data needed to synchronize the firing event.
func _get_data() -> Dictionary:
	return {
		"origin": global_transform.origin,
		"direction": -global_transform.basis.z  # Assuming forward direction.
	}

## Reproduces the firing event on all peers.
func _apply_data(data: Dictionary):
	var origin = data["origin"] as Vector3
	var direction = data["direction"] as Vector3

	# Perform the raycast from origin in the given direction.
	var space_state = get_world_3d().direct_space_state

	# Create a PhysicsRayQueryParameters3D object.
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = origin
	ray_params.to = origin + direction * max_distance
	# Optionally, set collision masks or exclude objects:
	# ray_params.collision_mask = your_collision_mask
	# ray_params.exclude = [self]

	var result = space_state.intersect_ray(ray_params)

	if result:
		# Handle the hit result, such as spawning hit effects.
		_on_hit(result)

	# Play firing effects on all peers.
	_on_fire()

## Determines if reconciliation is needed. Always true for hitscan weapons.
func _is_reconcilable(request_data: Dictionary, local_data: Dictionary) -> bool:
	return true

## No reconciliation needed for hitscan weapons in this basic implementation.
func _reconcile(local_data: Dictionary, remote_data: Dictionary):
	pass

## Handles the hit result, such as displaying impact effects.
func _on_hit(result: Dictionary):
	# Implement hit effect logic here.
	var hit_position = result.position
	var hit_normal = result.normal
	var collider = result.collider

	# For example, you might emit a signal or instantiate a hit effect scene:
	# emit_signal("hit_detected", hit_position, hit_normal, collider)
	pass

## Handles firing effects, like muzzle flash or sound.
func _on_fire():
	# Implement firing effect logic here.
	pass
