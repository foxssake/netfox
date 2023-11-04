extends Effect

@export var area: Area3D
@export var strength: float = 4.0

func _ready():
	super._ready()

func _rollback_tick(tick):
	super._rollback_tick(tick)

	if not is_active():
		return
	
	for body in area.get_overlapping_bodies():
		if body is BrawlerController and body.is_multiplayer_authority() and body != get_parent_node_3d():
			var displaceable = body.get_node("Displaceable") as Displaceable
			if not displaceable:
				continue

			var diff: Vector3 = body.global_position - global_position
			var f = clampf(1.0 / (1.0 + diff.length_squared()), 0.0, 1.0)
			diff.y = max(0, diff.y)
			displaceable.displace(diff.normalized() * strength * f * NetworkTime.ticktime)
			
			if body is BrawlerController and body != get_parent_node_3d():
				body.register_hit(get_parent_node_3d())
