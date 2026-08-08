@icon("res://addons/netfox.extras/icons/network-rigid-body-2d.svg")
extends RigidBody2D
class_name NetworkRigidBody2D

## A rollback / state synchronizer class for RigidBody2D.
## Set state property path to physics_state to synchronize the state of this body.

## The body's direct state, as reported by the physics server.
## [br][br]
## [i]Note:[/i] this is fetched on access instead of being cached, so that
## the handle cannot go stale after the body is freed.
var direct_state: PhysicsDirectBodyState2D:
	get: return PhysicsServer2D.body_get_direct_state(get_rid())

var physics_state: Array:
	get: return get_state()
	set(v): set_state(v)

enum {
	ORIGIN,
	ROT,
	LIN_VEL,
	ANG_VEL,
	SLEEPING
}

func _notification(notification: int):
	if notification == NOTIFICATION_READY:
		add_to_group("network_rigid_body")

func get_state() -> Array:
	var rid := get_rid()
	var body_transform: Transform2D = PhysicsServer2D.body_get_state(
		rid, PhysicsServer2D.BODY_STATE_TRANSFORM
	)

	var body_state: Array = [Vector2.ZERO, 0., Vector2.ZERO, 0., false]
	body_state[ORIGIN] = body_transform.origin
	body_state[ROT] = body_transform.get_rotation()
	body_state[LIN_VEL] = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	body_state[ANG_VEL] = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
	body_state[SLEEPING] = PhysicsServer2D.body_get_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING)
	return body_state

func set_state(remote_state: Array) -> void:
	var rid := get_rid()
	PhysicsServer2D.body_set_state(
		rid, PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(remote_state[ROT], remote_state[ORIGIN])
	)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, remote_state[LIN_VEL])
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, remote_state[ANG_VEL])

	# Sleeping state is restored last, as setting transform and velocities wakes
	# the body
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_SLEEPING, remote_state[SLEEPING])

## Override and apply any logic, forces or impulses to the rigid body as you would in physics_process
## The physics engine will run its simulation during rollback_tick with other nodes
func _physics_rollback_tick(_delta, _tick):
	pass
