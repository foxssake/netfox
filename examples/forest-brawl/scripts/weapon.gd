extends Node3D
# TODO: Provide as extras, with 2D and 3D implementation

@export var input: BrawlerInput
@export var projectile: PackedScene
@export var fire_cooldown: float = 0.15

@export var distance_threshold: float = 0.1

var last_fire: int = -1

var _projectiles: Dictionary = {}
var _origins: Dictionary = {}
var _offsets: Dictionary = {}

func _ready():
	if not input:
		input = $"../Input"
	
	NetworkTime.on_tick.connect(_tick)
	NetworkTime.before_tick_loop.connect(_before_tick_loop)

func _tick(delta, tick):
	# TODO: NetworkTime utilities like time between two ticks, time since tick, tick to time
	if input.is_firing and tick - last_fire > fire_cooldown / delta:
		var id = _generate_id()
		var from = global_transform
		
		if not is_multiplayer_authority():
			_spawn_projectile(from, id)
			rpc_id(get_multiplayer_authority(), "_request_projectile", id, from, tick)
		else:
			rpc("_accept_projectile", id, from, tick)
		last_fire = tick

func _before_tick_loop():
	# Apply all offsets
	for id in _offsets.keys():
		var offset = _offsets[id]
		var projectile = _projectiles[id]
		
		if not projectile:
			push_warning("Projectile %s vanished by the time we tried to apply offset" % [id])
			continue
		
		projectile.global_transform *= offset
	
	_offsets.clear()

func _generate_id(length: int = 12, charset: String = "abcdefghijklmnopqrstuvwxyz0123456789") -> String:
	var result = ""
	for i in range(length):
		var idx = randi_range(0, charset.length() - 1)
		result += charset[idx]
	return result

func _spawn_projectile(at: Transform3D, id: String):
		var p = projectile.instantiate() as Node3D
		get_tree().root.add_child(p, true)
		p.transform = at
		p.name += " " + id
		p.set_multiplayer_authority(get_multiplayer_authority())
		
		_projectiles[id] = p
		_origins[id] = at

func _check_threshold(request: Transform3D, actual: Transform3D) -> bool:
	return request.origin.distance_to(actual.origin) <= distance_threshold

@rpc("any_peer", "reliable", "call_remote")
func _request_projectile(id: String, from: Transform3D, tick: int):
	var sender = multiplayer.get_remote_sender_id()

	# Reject if sender can't use this input
	if sender != input.get_multiplayer_authority():
		rpc_id(sender, "_decline_projectile", id)
		return
	
	# Check if there was enough time since the last shot
	if tick - last_fire <= fire_cooldown * NetworkTime.tickrate:
		rpc_id(sender, "_decline_projectile", id)
		return
	
	# TODO: Rewind
	# TODO: Projectile might need to catch up to current tick on spawn
	
	# Validate incoming transform
	var final_transform = from
	if not _check_threshold(from, global_transform):
		final_transform = global_transform
	
	rpc("_accept_projectile", id, final_transform, tick)

@rpc("authority", "reliable", "call_local")
func _accept_projectile(id: String, from: Transform3D, tick: int):
	print("[%s] Accepting projectile %s" % [multiplayer.get_unique_id(), id])
	if _projectiles.has(id):
		var origin = _origins[id]
		var offset = origin * from.inverse()
		
		if not (origin * offset).is_equal_approx(from):
			print("%s * %s != %s" % [origin, offset, from])
		
		_offsets[id] = offset
	else:
		print("[%s] Spawning brand new projectile %s" % [multiplayer.get_unique_id(), id])
		_spawn_projectile(from, id)
		_origins.erase(id)
		last_fire = max(last_fire, tick)

@rpc("authority", "reliable", "call_remote")
func _decline_projectile(id: String):
	if not _projectiles.has(id):
		return
	
	var p = _projectiles[id] as Node
	p.queue_free()
	
	_projectiles.erase(id)
	_origins.erase(id)
	_offsets.erase(id)

# [l] Create projectile
# [l] Submit request for projectile at tick with starting transform
# [s] Validate spawn and create projectile
# [s] Broadcast projectile
# [c] Create projectile
