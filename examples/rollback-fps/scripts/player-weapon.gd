extends Node3D

@export var fire_cooldown: float = 0.25
@export var damage: int = 35

@onready var input := $"../../Input" as ExampleRollbackFPS.PlayerInput
@onready var sound := $AudioStreamPlayer3D as AudioStreamPlayer3D
@onready var rollback_synchronizer := %RollbackSynchronizer as RollbackSynchronizer

var last_fire: int = -1


func _rollback_tick(_dt, tick: int, _if):
	if last_fire == tick - 1:
		var hit = _fire()
		RollbackEffects.record(
			[self, &"fire"],
			func(ctx: RollbackEffects.EffectContext):
				sound.play()
				if hit and hit.has_method("damage_effect"):
					hit.damage_effect()

				ctx.on_revert = func():
					# Any undo logic here. Despawn projectiles, etc.
					print("hit reverted")
		)

	if (
		input.fire
		and _can_fire()
		and (is_multiplayer_authority() or input.is_multiplayer_authority())
	):
		last_fire = tick


func _can_fire() -> bool:
	return NetworkTime.seconds_between(last_fire, NetworkRollback.tick) >= fire_cooldown


func _fire():
	# See what we've hit
	var hit := _raycast()
	if hit.is_empty():
		# No hit, nothing to do
		return

	return _on_hit(hit)


func _raycast() -> Dictionary:
	# Detect hit
	var space := get_world_3d().direct_space_state
	var origin_xform := global_transform
	var query := PhysicsRayQueryParameters3D.create(
		origin_xform.origin, origin_xform.origin + origin_xform.basis.z * 1024.
	)

	return space.intersect_ray(query)


func _on_hit(result: Dictionary):
	if result.collider.has_method("damage"):
		result.collider.damage(damage)
		return result.collider
