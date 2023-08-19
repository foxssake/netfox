extends ShapeCast3D

@export var speed: float = 12.0
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
	position += basis.z * speed * delta
	distance_left -= speed * delta

	if distance_left < 0:
		queue_free()
