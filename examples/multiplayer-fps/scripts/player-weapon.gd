extends Node3D
class_name PlayerFPSWeapon

@export var fire_cooldown: float = 0.25

@onready var input := $"../../Input" as PlayerInputFPS
@onready var sound := $AudioStreamPlayer3D as AudioStreamPlayer3D
@onready var bullethole := $BulletHole as BulletHole
@onready var fire_action := $"Fire Action" as RewindableAction
@onready var rollback_synchronizer := %RollbackSynchronizer as RollbackSynchronizer

var last_fire: int = -1

func _ready():
	fire_action.mutate(self)
	NetworkTime.after_tick_loop.connect(_after_loop)

func _rollback_tick(_dt, tick: int, _if):
	if rollback_synchronizer.is_predicting():
		return

	fire_action.toggle(input.fire and _can_fire())
	match fire_action.get_status():
		RewindableAction.CONFIRMING, RewindableAction.ACTIVE:
			# Fire if action has just activated or is active
			_fire()
		RewindableAction.CANCELLING:
			# Whoops, turns out we couldn't have fired, undo
			_unfire()

func _after_loop():
	if fire_action.has_confirmed():
		# sound.play()
		pass

func _can_fire() -> bool:
	return NetworkTime.seconds_between(last_fire, NetworkTime.tick) >= fire_cooldown

func _fire():
	last_fire = NetworkRollback.tick

	# See what we've hit
	var hit := _raycast()
	if hit.is_empty():
		# No hit, nothing to do
		return

	_on_hit(hit)

func _unfire():
	_on_cancel_hit()

func _raycast() -> Dictionary:
	# Detect hit
	var space := get_world_3d().direct_space_state
	var origin_xform := global_transform
	var query := PhysicsRayQueryParameters3D.create(
		origin_xform.origin,
		origin_xform.origin + origin_xform.basis.z * 1024.
	)

	return space.intersect_ray(query)

func _on_hit(result: Dictionary):
	bullethole.action(result)
	if result.collider.has_method("damage"):
		result.collider.damage()
		NetworkRollback.mutate(result.collider)

func _on_cancel_hit():
	pass
