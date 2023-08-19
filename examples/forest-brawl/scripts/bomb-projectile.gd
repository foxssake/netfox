extends ShapeCast3D

@export var speed: float = 12.0
@export var strength: float = 2.0
@export var effect: PackedScene
@export var distance: float = 128.0
var distance_left: float

func _ready():
	NetworkTime.on_tick.connect(_tick)
	distance_left = distance
	
	# Do a tick in advance to interpolate forwards
	await get_tree().process_frame
	_tick(NetworkTime.ticktime, NetworkTime.tick)
	$TickInterpolator.push_state()

func _tick(delta, _t):
	target_position = position
	position += basis.z * speed * delta
	distance_left -= speed * delta

	if distance_left < 0:
		_destroy()
	
	# Check if we've hit anyone
	force_shapecast_update()
	if not collision_result.is_empty():
		# Jump to earliest point of collision
		position = target_position
		for hit in collision_result:
			var point = hit.point as Vector3
			if position.distance_to(target_position) < point.distance_to(target_position):
				position = point

		_destroy()

func _destroy():
	queue_free()
	
	if effect:
		var spawn = effect.instantiate() as Node3D
		get_tree().root.add_child(spawn)
		spawn.global_position = global_position
		spawn.set_multiplayer_authority(get_multiplayer_authority())
		
		if spawn is CPUParticles3D:
			(spawn as CPUParticles3D).emitting = true
