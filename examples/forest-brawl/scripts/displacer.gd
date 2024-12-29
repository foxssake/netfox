extends Node3D

@export var duration: float = 0.5
@export var strength: float = 1.0
@export var shape: Shape3D = SphereShape3D.new()

var birth_tick: int
var death_tick: int
var despawn_tick: int
var fired_by: Node

var _logger := _NetfoxLogger.new("fb", "Displacer")

func _ready():
	birth_tick = NetworkTime.tick
	death_tick = birth_tick + NetworkTime.seconds_to_ticks(duration)
	despawn_tick = death_tick + NetworkRollback.history_limit

	NetworkRollback.on_process_tick.connect(_rollback_tick)
	NetworkTime.on_tick.connect(_tick)

	# Run from birth tick on next loop
	NetworkRollback.notify_resimulation_start(birth_tick)

func _rollback_tick(tick: int):
	if tick < birth_tick or tick > death_tick:
		# Tick outside of range
		return

	var strength_factor := inverse_lerp(death_tick, birth_tick, tick)
	strength_factor = clampf(strength_factor, 0., 1.)
	strength_factor = pow(strength_factor, 2)

	for brawler in _get_overlapping_brawlers():
		var diff := brawler.global_position - global_position
		var f := clampf(1.0 / (1.0 + diff.length_squared()), 0.0, 1.0)

		var offset := Vector3(diff.x, max(0, diff.y), diff.z).normalized()
		offset *= strength_factor * strength * f * NetworkTime.ticktime
		
		brawler.shove(offset)
		NetworkRollback.mutate(brawler)

		_logger.info("Displacing brawler %s: [s=%.2f, sf=%.2f, f=%.2f, d=%s, o=%s]", [brawler.name, strength, strength_factor, f, diff, offset])

		if brawler != fired_by:
			brawler.register_hit(fired_by)

func _tick(_delta, tick):
	if tick >= death_tick:
		visible = false

	if tick > despawn_tick:
		queue_free()

func _find_displaceable(node: Node) -> Displaceable:
	for result in node.get_children().filter(func(it): return it is Displaceable):
		return result
	return null

func _get_overlapping_brawlers() -> Array[BrawlerController]:
	var result: Array[BrawlerController] = []

	var state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform
	
	# TODO: Move map geo and brawlers to separate layers, so map doesn't clog up
	# the 32 max_results
	var hits := state.intersect_shape(query)
	for hit in hits:
		var hit_object = hit["collider"]
		if hit_object is BrawlerController:
			result.push_back(hit_object)

	return result
