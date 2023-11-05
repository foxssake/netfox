extends Node
class_name NetworkWeapon

var _projectiles: Dictionary = {}
var _projectile_data: Dictionary = {}
var _reconcile_buffer: Array = []

func _ready():
	NetworkTime.before_tick_loop.connect(_before_tick_loop)

func can_fire() -> bool:
	return _can_fire()

func fire() -> Node:
	if not can_fire():
		return null
	
	var id = _generate_id()
	var projectile = _spawn()
	_save_projectile(projectile, id)
	var data = _projectile_data[id]
	
	if not is_multiplayer_authority():
		rpc_id(get_multiplayer_authority(), "_request_projectile", id, NetworkTime.tick, data)
	else:
		rpc("_accept_projectile", id, NetworkTime.tick, data)

	return projectile

# virtual
func _can_fire() -> bool:
	return false

# virtual
func _can_peer_use(peer_id: int) -> bool:
	return true

# virtual
func _after_fire(projectile: Node):
	pass

# virtual
func _spawn() -> Node:
	return null

# virtual
func _get_data(projectile: Node) -> Dictionary:
	return {}

# virtual
func _apply_data(projectile: Node, data: Dictionary):
	pass

# virtual
func _is_reconcilable(projectile: Node, request_data: Dictionary, local_data: Dictionary) -> bool:
	return true

# virtual
func _reconcile(projectile: Node, request_data: Dictionary, response_data: Dictionary):
	pass

func _save_projectile(projectile: Node, id: String, data: Dictionary = {}):
	_projectiles[id] = projectile
	projectile.name += " " + id
	projectile.set_multiplayer_authority(get_multiplayer_authority())
	
	if data.is_empty():
		data = _get_data(projectile)
	
	_projectile_data[id] = data

func _before_tick_loop():
	# Reconcile projectiles
	for recon in _reconcile_buffer:
		var projectile = recon[0]
		var local_data = recon[1]
		var response_data = recon[2]
		
		if is_instance_valid(projectile):
			_reconcile(projectile, local_data, response_data)
		else:
			push_warning("Projectile vanished by the time of reconciliation!")

	_reconcile_buffer.clear()

func _generate_id(length: int = 12, charset: String = "abcdefghijklmnopqrstuvwxyz0123456789") -> String:
	var result = ""
	for i in range(length):
		var idx = randi_range(0, charset.length() - 1)
		result += charset[idx]
	return result

@rpc("any_peer", "reliable", "call_remote")
func _request_projectile(id: String, tick: int, request_data: Dictionary):
	var sender = multiplayer.get_remote_sender_id()

	# Reject if sender can't use this input
	if not _can_peer_use(sender) or not _can_fire():
		rpc_id(sender, "_decline_projectile", id)
		push_error("Projectile %s rejected! Peer %s can't use this weapon now" % [id, sender])
		return
	
	# Validate incoming data
	var projectile = _spawn()
	var local_data = _get_data(projectile)
	
	if not _is_reconcilable(projectile, request_data, local_data):
		projectile.queue_free()
		rpc_id(sender, "_decline_projectile", id)
		push_error("Projectile %s rejected! Can't reconcile states: [%s, %s]" % [id, request_data, local_data])
		return
	
	_save_projectile(projectile, id, local_data)
	rpc("_accept_projectile", id, tick, local_data)

@rpc("authority", "reliable", "call_local")
func _accept_projectile(id: String, tick: int, response_data: Dictionary):
	print("[%s] Accepting projectile %s" % [multiplayer.get_unique_id(), id])
	if _projectiles.has(id):
		var projectile = _projectiles[id]
		var local_data = _projectile_data[id]
		_reconcile_buffer.push_back([projectile, local_data, response_data])
	else:
		print("[%s] Spawning brand new projectile %s" % [multiplayer.get_unique_id(), id])
		var projectile = _spawn()
		_apply_data(projectile, response_data)
		_projectile_data.erase(id)
		_after_fire(projectile)

@rpc("authority", "reliable", "call_remote")
func _decline_projectile(id: String):
	if not _projectiles.has(id):
		return
	
	var p = _projectiles[id] as Node
	p.queue_free()
	
	_projectiles.erase(id)
	_projectile_data.erase(id)
