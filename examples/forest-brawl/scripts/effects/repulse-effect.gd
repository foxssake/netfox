extends Effect

@export var area: Area3D
@export var strength: float = 4.0

static var _logger := _NetfoxLogger.new("fb", "RepulseEffect")

func _ready():
	super._ready()

func _rollback_tick(tick):
	super._rollback_tick(tick)

	if not is_active():
		return

	for body in area.get_overlapping_bodies():
		if not body is BrawlerController or body == get_parent_node_3d():
			continue
		
		var brawler := body as BrawlerController
		var diff: Vector3 = brawler.global_position - global_position
		var f = clampf(1.0 / (1.0 + diff.length_squared()), 0.0, 1.0)
		f = clampf(1. - diff.length_squared() / 16., 0., 1.)
		diff.y = max(0, diff.y)
		var motion = diff.normalized() * strength * f * NetworkTime.ticktime
		brawler.shove(motion)
		_logger.debug("Shoving %s > %s", [brawler.name, motion])

		brawler.register_hit(get_parent_node_3d())
		NetworkRollback.mutate(brawler)
