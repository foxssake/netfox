@icon("res://addons/netfox.extras/physics/network-rigid-body-3d.gd")
extends RigidBody3D
class_name NetworkRigidBody3D

## A rollback / state synchronizer class for RigidBody3D.
## Set state property path to physics_state to synchronize the state of this body.

## The body's direct state, as reported by the physics server.
## [br][br]
## [i]Note:[/i] this is fetched on access instead of being cached, so that
## the handle cannot go stale after the body is freed.
var direct_state: PhysicsDirectBodyState3D:
	get: return PhysicsServer3D.body_get_direct_state(get_rid())

var physics_state: Array:
	get: return get_state()
	set(v): set_state(v)

enum {
	ORIGIN,
	QUAT,
	LIN_VEL,
	ANG_VEL,
	SLEEPING
}

func _notification(notification: int):
	if notification == NOTIFICATION_READY:
		add_to_group("network_rigid_body")

func get_state() -> Array:
	var rid := get_rid()
	var body_transform: Transform3D = PhysicsServer3D.body_get_state(
		rid, PhysicsServer3D.BODY_STATE_TRANSFORM
	)

	var body_state: Array = [Vector3.ZERO, Quaternion.IDENTITY, Vector3.ZERO, Vector3.ZERO, false]
	body_state[ORIGIN] = body_transform.origin
	body_state[QUAT] = body_transform.basis.get_rotation_quaternion()
	body_state[LIN_VEL] = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
	body_state[ANG_VEL] = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
	body_state[SLEEPING] = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_SLEEPING)
	return body_state

func set_state(remote_state: Array) -> void:
	var rid := get_rid()
	PhysicsServer3D.body_set_state(
		rid, PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(Basis(remote_state[QUAT]), remote_state[ORIGIN])
	)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, remote_state[LIN_VEL])
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, remote_state[ANG_VEL])

	# Sleeping state is restored last, as setting transform and velocities wakes
	# the body
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_SLEEPING, remote_state[SLEEPING])


## Override and apply any logic, forces or impulses to the rigid body as you would in physics_process
## The physics engine will run its simulation during rollback_tick with other nodes
func _physics_rollback_tick(_delta, _tick):
	pass

## Override to run once per network tick, before any physics sub-step
## Receives the full tick delta and the tick being simulated
func _before_physics_rollback_tick(_delta, _tick):
	pass
