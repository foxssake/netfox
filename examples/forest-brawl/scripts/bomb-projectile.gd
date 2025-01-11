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
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.motion = motion
	query.shape = shape
	query.transform = global_transform
	
	var hit_interval := space.cast_motion(query)
	if hit_interval[0] != 1.0 or hit_interval[1] != 1.0 and not is_first_tick:
		# Move to collision
		position += motion * hit_interval[1]
		_explode()
	else:
		position += motion

	# Skip collisions for a single tick, no more
	is_first_tick = false

func _explode():
	queue_free()
	NetworkTime.on_tick.disconnect(_tick)
	
	if effect:
		var spawn = effect.instantiate() as Node3D
		get_tree().root.add_child(spawn)
		spawn.global_position = global_position
		spawn.fired_by = fired_by
		spawn.set_multiplayer_authority(get_multiplayer_authority())
		
		if spawn is CPUParticles3D:
			(spawn as CPUParticles3D).emitting = true
