extends Node
class_name NetworkWeapon

## Base class for creating responsive weapons, by spawning projectiles locally,
## but keeping control on the server.

var _projectiles: Dictionary = {}
var _projectile_data: Dictionary = {}
var _reconcile_buffer: Array = []
var _rng = RandomNumberGenerator.new()

static var _logger: _NetfoxLogger = _NetfoxLogger.for_extras("NetworkWeapon")

func _ready():
	_rng.randomize()
	NetworkTime.before_tick_loop.connect(_before_tick_loop)

## Check whether this weapon can be fired.
func can_fire() -> bool:
	return _can_fire()

## Try to fire the weapon and return the projectile.
##
## Returns null if the weapon can't be fired.
func fire() -> Node:
	if not can_fire():
		return null
	
	var id: String = _generate_id()
	var projectile = _spawn()
	_save_projectile(projectile, id)
	var data = _projectile_data[id]
	
	if not is_multiplayer_authority():
		_request_projectile.rpc_id(get_multiplayer_authority(), id, NetworkTime.tick, data)
	else:
		_accept_projectile.rpc(id, NetworkTime.tick, data)

	_logger.debug("Calling after fire hook for %s" % [projectile.name])
	_after_fire(projectile)

	return projectile

## Override this method with your own can fire logic.
##
## This can be used to implement e.g. firing cooldowns and ammo checks.
func _can_fire() -> bool:
	return false

## Override this method to check if a given peer can use this weapon.
##
## Usually this should check if the weapon's owner is trying to fire it, but 
## for some special cases this can be some different logic, e.g. weapons that 
## can be used by any player on a given team.
func _can_peer_use(peer_id: int) -> bool:
	return true

## Override this method to run any logic needed after successfully firing the 
## weapon.
##
## This can be used to e.g. reset the firing cooldown or deduct ammo.
func _after_fire(projectile: Node):
	pass

## Override this method to spawn and initialize a projectile.
##
## Make sure to return the projectile spawned!
func _spawn() -> Node:
	return null

## Override this method to extract projectile data that should be synchronized
## over the network.
##
## This will be captured both locally and on the server, and will be used for 
## reconciliation.
func _get_data(projectile: Node) -> Dictionary:
	return {}

## Override this method to apply projectile data that should be synchronized 
## over the network.
##
## This is used in cases where some other client fires a weapon and the server 
## instructs us to spawn a projectile for it.
func _apply_data(projectile: Node, data: Dictionary):
	pass

## Override this method to check if two projectile states can be reconciled.
##
## This can be used to prevent cheating, for example by not allowing the client 
## to say it's firing from the other side of the map compared to its actual 
## position.
##
## When this method returns false, the server will decline the projectile
## request.
func _is_reconcilable(projectile: Node, request_data: Dictionary, local_data: Dictionary) -> bool:
	return true

## Override this method to reconcile the initial local and remote projectile
## state.
##
## Let's say the projectile travels in a straight line from its origin, but we
## receive a different origin from the server. In this reconciliation step, 
## the projectile's position can be adjusted to account for the different origin.
##
## Unless the use case is niche, the best practice is to consider the server's
## state as authorative.
func _reconcile(projectile: Node, local_data: Dictionary, remote_data: Dictionary):
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
		var projectile_id = recon[3]
		
		if is_instance_valid(projectile):
			_reconcile(projectile, local_data, response_data)
		else:
			_logger.warning("Projectile %s vanished by the time of reconciliation!" % [projectile_id])

	_reconcile_buffer.clear()

func _generate_id(length: int = 12, charset: String = "abcdefghijklmnopqrstuvwxyz0123456789") -> String:
	var result = ""

	# Generate a random ID
	for i in range(length):
		var idx = _rng.randi_range(0, charset.length() - 1)
		result += charset[idx]

	return result

@rpc("any_peer", "reliable", "call_remote")
func _request_projectile(id: String, tick: int, request_data: Dictionary):
	var sender = multiplayer.get_remote_sender_id()

	# Reject if sender can't use this input
	if not _can_peer_use(sender) or not _can_fire():
		_decline_projectile.rpc_id(sender, id)
		_logger.error("Projectile %s rejected! Peer %s can't use this weapon now" % [id, sender])
		return
	
	# Validate incoming data
	var projectile = _spawn()
	var local_data: Dictionary = _get_data(projectile)
	
	if not _is_reconcilable(projectile, request_data, local_data):
		projectile.queue_free()
		_decline_projectile.rpc_id(sender, id)
		_logger.error("Projectile %s rejected! Can't reconcile states: [%s, %s]" % [id, request_data, local_data])
		return
	
	_save_projectile(projectile, id, local_data)
	_accept_projectile.rpc(id, tick, local_data)
	_after_fire(projectile)

@rpc("authority", "reliable", "call_local")
func _accept_projectile(id: String, tick: int, response_data: Dictionary):
	_logger.info("[%s] Accepting projectile %s from %s" % [multiplayer.get_unique_id(), id, multiplayer.get_remote_sender_id()])
	if multiplayer.get_unique_id() == multiplayer.get_remote_sender_id():
		# Projectile is local, nothing to do
		return
	
	if _projectiles.has(id):
		var projectile = _projectiles[id]
		var local_data = _projectile_data[id]
		_reconcile_buffer.push_back([projectile, local_data, response_data, id])
	else:
		var projectile = _spawn()
		_apply_data(projectile, response_data)
		_projectile_data.erase(id)
		_save_projectile(projectile, id, response_data)
		_after_fire(projectile)

@rpc("authority", "reliable", "call_remote")
func _decline_projectile(id: String):
	if not _projectiles.has(id):
		return
	
	var p = _projectiles[id]
	if is_instance_valid(p):
		p.queue_free()
	
	_projectiles.erase(id)
	_projectile_data.erase(id)
