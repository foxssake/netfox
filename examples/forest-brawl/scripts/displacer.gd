extends Node3D
class_name Displacer

@export var duration: float = 0.5
@export var strength: float = 1.0
@export var shape: Shape3D = SphereShape3D.new()

var time_remaining := duration
var fired_by: Node

var _logger := NetfoxLogger.new("fb", "Displacer")

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
	# This should not happen, users should call `all()` to iterate currently
	# active displacers
#	assert(RollbackLivenessServer.is_alive(self, NetworkRollback.tick), "Applying inactive displacer!")
	if not RollbackLivenessServer.is_alive(self, NetworkRollback.tick):
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
		RollbackLivenessServer.despawn(self)
		return
	return

	var strength_factor := time_remaining / duration
	strength_factor = clampf(strength_factor, 0., 1.)
	strength_factor = pow(strength_factor, 2) * 8

	for brawler in _get_overlapping_brawlers():
		var diff := brawler.global_position - global_position
		var f := clampf(1.0 / (1.0 + diff.length_squared()), 0.0, 1.0)

		var offset := Vector3(diff.x, max(0, diff.y), diff.z).normalized()
		offset *= strength_factor * strength * f * NetworkTime.ticktime

		brawler.shove(offset)
		# NetworkRollback.mutate(brawler)

		if brawler != fired_by:
			brawler.register_hit(fired_by)

func _rollback_spawn() -> void:
	show()
	_displacers.add(self)

func _rollback_despawn() -> void:
	hide()
	_displacers.erase(self)

func _get_overlapping_brawlers() -> Array[BrawlerController]:
	var result: Array[BrawlerController] = []
	for brawler in BrawlerController.all():
		if global_position.distance_to(brawler.global_position) < (shape as SphereShape3D).radius:
			result.append(brawler)
	return result

	var state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform

	# TODO: Move map geo and brawlers to separate layers, so map doesn't clog up
	# the 32 max_results - this would enable bigger collision shapes
	var hits := state.intersect_shape(query)
	for hit in hits:
		var hit_object = hit["collider"]
		if hit_object is BrawlerController:
			result.push_back(hit_object)

	return result
