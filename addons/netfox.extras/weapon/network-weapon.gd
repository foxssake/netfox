extends Node
class_name NetworkWeapon

## Base class for creating responsive weapons, by spawning projectiles locally,
## but keeping control on the server.

var _projectiles: Dictionary = {}
var _projectile_data: Dictionary = {}
var _reconcile_buffer: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _fired_tick: int = -1

static var _logger: NetfoxLogger = NetfoxLogger._for_extras("NetworkWeapon")

func _ready():
	_rng.randomize()
	NetworkTime.before_tick_loop.connect(_before_tick_loop)

## Check whether this weapon can be fired.
func can_fire() -> bool:
	return _can_fire()

## Try to fire the weapon and return the projectile.
## [br][br]
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

	_logger.debug("Calling after fire hook for %s", [projectile.name])
	_fired_tick = NetworkTime.tick
	_after_fire(projectile)

	return projectile

## Try to fire multiple projectiles at once and return them as an array.
## [br][br]
## Returns an empty array if the weapon can't be fired.
func fire_multiple(projectile_count: int) -> Array:
	if projectile_count <= 0 or not can_fire():
		return []

	var ids: Array[String] = []
	var datas: Array[Dictionary] = []
	var projectiles: Array[Node] = _spawn_multiple(projectile_count)

	for i in projectile_count:
		var id: String = _generate_id()
		ids.append(id)
		
		_save_projectile(projectiles[i], id)
		
		var data: Dictionary = _projectile_data.get(id, {})
		datas.append(data)

	if not is_multiplayer_authority():
		_request_multiple_projectiles.rpc_id(get_multiplayer_authority(), ids, NetworkTime.tick, datas)
	else:
		_accept_multiple_projectiles.rpc(ids, NetworkTime.tick, datas)

	_logger.debug("Calling after_multiple_fire hook for %s projectiles", [projectiles.size()])
	_fired_tick = NetworkTime.tick
	_after_fire_multiple(projectiles, projectile_count)

	return projectiles

## Get the tick when the weapon was fired.
## [br][br]
## Whenever a weapon gets fired, it takes time for that event to be transmitted
## to the server. To account for this latency, the exact tick is sent along
## with other data, so weapon implementations can compensate for the latency.
## [br][br]
## One way to use this is to manually simulate the projectile after it's
## created:
## [codeblock]
## func _after_fire(projectile: Node3D):
##     last_fire = get_fired_tick()
##     sound.play()
##
##     for t in range(get_fired_tick(), NetworkTime.tick):
##         if projectile.is_queued_for_deletion():
##             break
##         projectile._tick(NetworkTime.ticktime, t)
## [/codeblock]
func get_fired_tick() -> int:
	return _fired_tick

## Override this method with your own can fire logic.
## [br][br]
## This can be used to implement e.g. firing cooldowns and ammo checks.
func _can_fire() -> bool:
	return false

# @public method
## Override this method to check if a given peer can use this weapon.
## [br][br]
## Usually this should check if the weapon's owner is trying to fire it, but
## for some special cases this can be some different logic, e.g. weapons that
## can be used by any player on a given team.
func _can_peer_use(peer_id: int) -> bool:
	return true

# @public method
## Override this method to run any logic needed after successfully firing the
## weapon.
## [br][br]
## This can be used to e.g. reset the firing cooldown or deduct ammo.
func _after_fire(projectile: Node):
	pass

# @public method
## Override this method to run logic after successfully firing a multiple of projectiles.
## [br][br]
## By default, this calls [method _after_fire] for each projectile in the multiple,
## but you could define one behaviour for the whole multiple. It also only gets called
## if there was atleast one projectile spawned rather then, reconsiled!
## [br][br]
## ATTENTION: This method only receives projectiles that were newly spawned.
## Reconciled projectiles (e.g. locally predicted ones) are excluded to prevent
## duplicate code execution, visual or audio effects.
## [br][br]
## This can be used to e.g. reset firing cooldowns, deduct ammo, or add weapon recoil
## for all projectiles individually or as a multiple.
## [param projectiles]: Only contains newly spawned projectile nodes for this peer.
## The size of the projectiles array can therefor be smaller then the count!
## [param total_count]: Total number of projectiles fired in this multiple.
func _after_fire_multiple(projectiles: Array[Node], total_count: int):
	pass

# @public method
## Override this method to spawn and initialize a projectile.
## [br][br]
## Make sure to return the projectile spawned!
func _spawn() -> Node:
	return null

# @public method
## Override this method to transform a projectile based on its index in a multiple.
## [br][br]
## Useful for spread weapons, shotguns, or formations (e.g. fan patterns)
## and even a mixture of projectile types. Use the index to manipulate 
## the projectile in a multiple.
## [param projectile]: The spawned projectile node to transform.
## [param index]: The 0-based index of this projectile inside the multiple.
## [param count]: Total number of projectiles fired in this multiple.
func _configure_multi_projectile(projectile: Node, index: int, count: int) -> Node:
	return projectile

# @public method
## Override this method to extract projectile data that should be synchronized
## over the network.
## [br][br]
## This will be captured both locally and on the server, and will be used for
## reconciliation.
func _get_data(projectile: Node) -> Dictionary:
	return {}

# @public method
## Override this method to apply projectile data that should be synchronized
## over the network.
## [br][br]
## This is used in cases where some other client fires a weapon and the server
## instructs us to spawn a projectile for it.
func _apply_data(projectile: Node, data: Dictionary):
	pass

# @public method
## Override this method to check if two projectile states can be reconciled.
## [br][br]
## This can be used to prevent cheating, for example by not allowing the client
## to say it's firing from the other side of the map compared to its actual
## position.
## [br][br]
## When this method returns false, the server will decline the projectile
## request.
func _is_reconcilable(projectile: Node, request_data: Dictionary, local_data: Dictionary) -> bool:
	return true

# @public method
## Override this method to reconcile the initial local and remote projectile
## state.
## [br][br]
## Let's say the projectile travels in a straight line from its origin, but we
## receive a different origin from the server. In this reconciliation step,
## the projectile's position can be adjusted to account for the different origin.
## [br][br]
## Unless the use case is niche, the best practice is to consider the server's
## state as authorative.
func _reconcile(projectile: Node, local_data: Dictionary, remote_data: Dictionary):
	pass

# @private method
## Dont override this!
func _spawn_multiple(projectile_count: int) -> Array[Node]:
	if projectile_count <= 0:
		return []
	
	var projectiles: Array[Node] = []
	for i in projectile_count:
		var projectile: Node = _spawn()
		if is_instance_valid(projectile):
			projectile = _configure_multi_projectile(projectile, i, projectile_count)
			projectiles.append(projectile)
		else:
			_logger.warning("_spawn() returned invalid projectile: %s !", [projectile])
	
	return projectiles

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
			_logger.warning("Projectile %s vanished by the time of reconciliation!", [projectile_id])

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
	_fired_tick = tick
	if not _can_peer_use(sender) or not _can_fire():
		_decline_projectile.rpc_id(sender, id)
		_logger.error("Projectile %s rejected! Peer %s can't use this weapon now", [id, sender])
		return

	# Validate incoming data
	var projectile = _spawn()
	var local_data: Dictionary = _get_data(projectile)

	if not _is_reconcilable(projectile, request_data, local_data):
		projectile.queue_free()
		_decline_projectile.rpc_id(sender, id)
		_logger.error("Projectile %s rejected! Can't reconcile states: [%s, %s]", [id, request_data, local_data])
		return

	_save_projectile(projectile, id, local_data)
	_accept_projectile.rpc(id, tick, local_data)
	_after_fire(projectile)

@rpc("any_peer", "reliable", "call_remote")
func _request_multiple_projectiles(ids: Array[String], tick: int, request_datas: Array[Dictionary]):
	
	if ids.size() != request_datas.size(): 
		_logger.error("Id's: %s and request datas: %s are unequal in size!", [ids, request_datas])
		return
	
	var sender = multiplayer.get_remote_sender_id()
	
	# Reject if sender can't use this input
	_fired_tick = tick
	if not _can_peer_use(sender) or not _can_fire():
		_decline_multiple_projectiles.rpc_id(sender, ids)
		_logger.error("Projectiles %s rejected! Peer %s can't use this weapon now", [ids, sender])
		return
	
	var projectile_count: int = ids.size()
	
	# multiple spawning projectiles with already applied transformations
	# NOTE: Is there potential to spawn less projectiles then count?
	var projectiles: Array[Node] = _spawn_multiple(projectile_count)
	var local_datas: Array[Dictionary] = []
	
	var was_rejected: bool = false
	for i in ids.size():
		
		var projectile = projectiles[i]
		var request_data = request_datas[i]
		var local_data: Dictionary = _get_data(projectiles[i])
		local_datas.append(local_data)
		
		if not _is_reconcilable(projectile, request_data, local_data):
			was_rejected = true
			break
	
	# If we rejected the multiple at any point.
	if was_rejected:
		for p in projectiles:
			p.queue_free()
		
		_decline_multiple_projectiles.rpc_id(sender, ids)
		_logger.error("Projectiles %s rejected! Can't reconcile states: [%s, %s]", [ids, request_datas, local_datas])
		return
	else:
		for i in projectiles.size():
			_save_projectile(projectiles[i], ids[i], local_datas[i])
	
	_accept_multiple_projectiles.rpc(ids, tick, local_datas)
	_after_fire_multiple(projectiles, projectile_count)

@rpc("authority", "reliable", "call_local")
func _accept_projectile(id: String, tick: int, response_data: Dictionary):
	if multiplayer.get_unique_id() == multiplayer.get_remote_sender_id():
		# Projectile is local, nothing to do
		return

	_logger.info("Accepting projectile %s from %s", [id, multiplayer.get_remote_sender_id()])

	if _projectiles.has(id):
		var projectile = _projectiles[id]
		var local_data = _projectile_data[id]
		_reconcile_buffer.push_back([projectile, local_data, response_data, id])
	else:
		_fired_tick = tick
		var projectile = _spawn()
		_apply_data(projectile, response_data)
		_projectile_data.erase(id) # NOTE: redundant since we overwrite this at the _save_projectile function?
		_save_projectile(projectile, id, response_data)
		_after_fire(projectile)

@rpc("authority", "reliable", "call_local")
func _accept_multiple_projectiles(ids: Array[String], tick: int, response_datas: Array[Dictionary]):
	if multiplayer.get_unique_id() == multiplayer.get_remote_sender_id():
		# Projectile is local, nothing to do
		return
	
	var projectile_count: int = ids.size()
	if projectile_count <= 0:
		# No projectiles to accept
		return
	
	var response_datas_size: int = response_datas.size()
	if projectile_count != response_datas_size: 
		_logger.error("Id's: %s and response datas: %s are unequal in size!", [ids, response_datas])
		return

	_logger.info("Accepting projectile %s from %s", [ids, multiplayer.get_remote_sender_id()])
	
	var projectiles: Array[Node] = []
	
	for i in projectile_count:
		
		var id: String = ids[i]
		var response_data: Dictionary = response_datas[i]
		
		if _projectiles.has(id):
			var projectile = _projectiles[id]
			var local_data = _projectile_data[id]
			_reconcile_buffer.push_back([projectile, local_data, response_data, id])
		else:
			_fired_tick = tick
			var projectile = _spawn()
			projectile = _configure_multi_projectile(projectile, i, projectile_count)
			_apply_data(projectile, response_data)
			_projectile_data.erase(id) # NOTE: redundant since we overwrite this at the _save_projectile function?
			_save_projectile(projectile, id, response_data)
			projectiles.append(projectile)
			
	# NOTE: Only spawned projectiles get passed to the _after_fire_multiple() function!
	# Most of the time, this will probably just be all projectiles or none but
	# the inbetween state is covered here
	if projectiles.size() > 0:
		_after_fire_multiple(projectiles, projectile_count)

@rpc("authority", "reliable", "call_remote")
func _decline_projectile(id: String):
	_decline_projectile_internal(id)

@rpc("authority", "reliable", "call_remote")
func _decline_multiple_projectiles(ids: Array[String]):
	for id: String in ids: 
		_decline_projectile_internal(id)

# NOTE: Dont really like the function name here.
func _decline_projectile_internal(id: String) -> void:
	if not _projectiles.has(id):
		return
	
	var p: Node = _projectiles[id]
	if is_instance_valid(p):
		p.queue_free()

	_projectiles.erase(id)
	_projectile_data.erase(id)
