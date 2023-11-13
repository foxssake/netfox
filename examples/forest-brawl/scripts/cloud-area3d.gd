extends Area3D

@export var clouds: Array[PackedScene] = []
@export var count: int = 16

@export var float_direction: Vector3 = Vector3.RIGHT
@export var float_speed_min: float = 4.0
@export var float_speed_max: float = 8.0

var _clouds: Array[Node3D] = []
var _speeds: Array[float] = []
var _aabb: AABB

func _ready():
	_aabb = _find_aabb()
	if not _aabb.has_volume():
		push_error("CloudArea required a box shape!")
		queue_free()
		return

	for i in range(count):
		var cloud = _spawn_cloud()
		cloud.position = _aabb.position + _aabb.size * Vector3(randf(), randf(), randf())
		
		_clouds.push_back(cloud)
		_speeds.push_back(randf_range(float_speed_min, float_speed_max))

func _process(delta):
	for i in range(count):
		var cloud = _clouds[i]
		var speed = _speeds[i]
		
		cloud.position += float_direction * speed * delta
		
		if not _aabb.has_point(cloud.position):
			cloud.queue_free()
			
			cloud = _spawn_cloud()
			cloud.position = _aabb.position + _aabb.size * \
				Vector3(randf(), randf(), randf()) * \
				(Vector3.ONE * 0.5 - float_direction * 0.5)
			
			_clouds[i] = cloud
			_speeds[i] = randf_range(float_speed_min, float_speed_max)

func _spawn_cloud() -> Node3D:
	var cloud_template = clouds.pick_random() as PackedScene
	var cloud = cloud_template.instantiate() as Node3D
	add_child(cloud)
	cloud.owner = self
	
	return cloud

func _find_aabb() -> AABB:
	var shape_owners = get_shape_owners()
	for shape_owner in shape_owners:
		for i in range(shape_owner_get_shape_count(shape_owner)):
			var shape = shape_owner_get_shape(shape_owner, i)
			
			if shape is BoxShape3D:
				var pos = shape_owner_get_transform(shape_owner).origin
				var size = shape.size
				return AABB(pos - size / 2, size)
	
	return AABB(Vector3.ZERO, Vector3.ZERO)
