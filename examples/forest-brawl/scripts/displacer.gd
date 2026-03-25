extends Node3D
class_name Displacer

@export var duration: float = 0.5
@export var strength: float = 1.0
@export var shape: Shape3D = SphereShape3D.new()

var time_remaining := duration
var fired_by: Node

@onready var synchronizer := $PredictiveSynchronizer as PredictiveSynchronizer

static var _displacers := _Set.new()

static func all() -> Array[Displacer]:
	var result := [] as Array[Displacer]
	result.assign(_displacers.values())
	return result

static func overlapping(target: BrawlerController) -> Array[Displacer]:
	var result := [] as Array[Displacer]
	for displacer in _displacers.values():
		if displacer.is_overlapping(target):
			result.append(displacer)
	return result

func is_overlapping(target: BrawlerController) -> bool:
	# TODO: Use physics eventually
	return global_position.distance_to(target.global_position) < (shape as SphereShape3D).radius

func apply_to(target: BrawlerController) -> void:
	# This should not happen, users should call all()` to iterate currently
	# active displacers
	if not synchronizer.is_alive(NetworkRollback.tick):
		return

	var strength_factor := time_remaining / duration
	strength_factor = clampf(strength_factor, 0., 1.)
	strength_factor = pow(strength_factor, 2) * 4.

	var delta := target.global_position - global_position
	var f := clampf(1.0 / (1.0 + delta.length_squared()), 0.0, 1.0)
	if is_zero_approx(f):
		return

	var offset := Vector3(delta.x, max(0, delta.y), delta.z).normalized()
	offset *= strength_factor * strength * f * NetworkTime.ticktime

	target.shove(offset)

	if target != fired_by:
		target.register_hit(fired_by)

func _enter_tree():
	_displacers.add(self)

func _exit_tree():
	_displacers.erase(self)

func _rollback_tick(dt: float, _t: int, _if: bool) -> void:
	time_remaining -= dt
	if time_remaining < 0.:
		synchronizer.despawn()
		return

func _rollback_spawn() -> void:
	show()
	_displacers.add(self)

func _rollback_despawn() -> void:
	hide()
	_displacers.erase(self)
