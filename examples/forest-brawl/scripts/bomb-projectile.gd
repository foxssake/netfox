extends ShapeCast3D
class_name BombProjectile

@export var speed: float = 12.0
@export var strength: float = 2.0
@export var effect: PackedScene
@export var distance: float = 128.0

var distance_left: float
var fired_by: Node
var is_first_tick: bool = true

func _ready():
	NetworkTime.on_tick.connect(_tick)
	distance_left = distance
	
	# Do a tick in advance to interpolate forwards
	await get_tree().process_frame
	_tick(NetworkTime.ticktime, NetworkTime.tick)
	$TickInterpolator.push_state()
	is_first_tick = true

func _tick(delta, _t):
	var dst = speed * delta
	var motion = transform.basis.z * dst
	target_position = Vector3.FORWARD * dst
	distance_left -= dst

	if distance_left < 0:
		queue_free()
	
	# Check if we've hit anyone
	force_shapecast_update()
	
	# Find the closest point of contact
	var collision_points = collision_result\
		.filter(func(it): return it.collider != fired_by)\
		.map(func(it): return it.point)
	collision_points.sort_custom(func(a, b): return position.distance_to(a) < position.distance_to(b))

	if not collision_points.is_empty() and not is_first_tick:
		# Jump to closest point of contact
		var contact = collision_points[0]
		position = contact
		_explode()
	else:
		position += motion
	
	# Skip collisions for a single tick, no more
	is_first_tick = false

func _explode():
	queue_free()
	
	if effect:
		var spawn = effect.instantiate() as Node3D
		get_tree().root.add_child(spawn)
		spawn.global_position = global_position
		spawn.fired_by = fired_by
		spawn.set_multiplayer_authority(get_multiplayer_authority())
		
		if spawn is CPUParticles3D:
			(spawn as CPUParticles3D).emitting = true
