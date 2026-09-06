extends RefCounted
class_name _SimulatedCollisionRecorder

## Helper class for recording simulation aware areas and collision shapes.
## Supports CollisionShape3D/2D, Area3D/2D.
##
## Used by [_SimulatorServer] internally.

const SIMULATION_AWARE_GROUP := &"simulation_aware_collision"

var _logger := NetfoxLogger._for_netfox("SimulatedCollisionRecorder")

# tick -> Dictionary[Node, _CollisionSnapshot]
var _snapshots_by_tick : Dictionary[int, Dictionary] = {}
var _tracked_nodes : Array[Node] = []

## Inner base struct for recording collision snapshot per type.
## Specific types extends this base struct.
## Having this solves 2 problems: 1- no unncessary memory, 2- no unneccessary checks for type.
## Each derived struct only stores the fields relevant to its own node type.
class _CollisionSnapshot:
	func restore_node(_node: Node) -> void:
		push_error("_CollisionSnapshot.restore_node is abstract, must be overridden.")

class _ShapeSnapshot3D extends _CollisionSnapshot:
	var global_transform : Transform3D
	var disabled : bool
	
	func _init(node: CollisionShape3D) -> void:
		global_transform = node.global_transform
		disabled = node.disabled
	
	func restore_node(node: Node) -> void:
		node.global_transform = global_transform
		node.disabled = disabled

class _ShapeSnapshot2D extends _CollisionSnapshot:
	var global_transform : Transform2D
	var disabled : bool
	
	func _init(node: CollisionShape2D) -> void:
		global_transform = node.global_transform
		disabled = node.disabled
	
	func restore_node(node: Node) -> void:
		node.global_transform = global_transform
		node.disabled = disabled

class _AreaSnapshot3D extends _CollisionSnapshot:
	var global_transform : Transform3D
	var monitoring : bool
	var monitorable : bool
	var collision_layer : int
	
	func _init(node: Area3D) -> void:
		global_transform = node.global_transform
		monitoring = node.monitoring
		monitorable = node.monitorable
		collision_layer = node.collision_layer
	
	func restore_node(node: Node) -> void:
		node.global_transform = global_transform
		node.monitoring = monitoring
		node.monitorable = monitorable
		node.collision_layer = collision_layer

class _AreaSnapshot2D extends _CollisionSnapshot:
	var global_transform : Transform2D
	var monitoring : bool
	var monitorable : bool
	var collision_layer : int
	
	func _init(node: Area2D) -> void:
		global_transform = node.global_transform
		monitoring = node.monitoring
		monitorable = node.monitorable
		collision_layer = node.collision_layer
	
	func restore_node(node: Node) -> void:
		node.global_transform = global_transform
		node.monitoring = monitoring
		node.monitorable = monitorable
		node.collision_layer = collision_layer

## Initialize needs to be called by owner node.
## Because refcounted classes doesnt have access to scene tree.
func initialize(tree: SceneTree) -> void:
	tree.node_added.connect(_on_node_added)
	
	var existing_nodes := tree.get_nodes_in_group(SIMULATION_AWARE_GROUP)
	_logger.trace(
		"Initializing collision recorder, found %s existing node(s) in group %s",
		[existing_nodes.size(), SIMULATION_AWARE_GROUP]
	)
	
	for node in existing_nodes:
		_track(node)

func _on_node_added(node: Node) -> void:
	if node.is_in_group(SIMULATION_AWARE_GROUP):
		_track(node)

func _track(node: Node) -> void:
	if node in _tracked_nodes:
		return

	if not _is_supported(node):
		_logger.warning(
			"Node %s is in %s group but isn't a supported type (CollisionShape3D/2D, Area3D/2D), ignoring." + \
			"Only supported types should be in this group.",
			[node.name, SIMULATION_AWARE_GROUP]
		)
		return

	_tracked_nodes.push_back(node)
	node.tree_exiting.connect(_untrack.bind(node), CONNECT_ONE_SHOT)
	_logger.trace("Tracking node %s, total tracked: %s", [node.name, _tracked_nodes.size()])

# Called when node's tree_exiting is fired so we can untrack now.
# Old snapshot dicts aren't erased here, we remove invalid nodes while we iterate on record_tick().
func _untrack(node: Node) -> void:
	_tracked_nodes.erase(node)
	_logger.trace("Untracked node %s (tree_exiting), total tracked: %s", [node.name, _tracked_nodes.size()])

# Check if node is type of supported ones.
func _is_supported(node: Node) -> bool:
	return node is CollisionShape3D \
		or node is CollisionShape2D \
		or node is Area3D \
		or node is Area2D

# Takes the snapshot for a node with corresponding snapshot type and returns it.
func _take_snapshot_for_node(node: Node) -> _CollisionSnapshot:
	if node is CollisionShape3D:
		return _ShapeSnapshot3D.new(node)
	elif node is CollisionShape2D:
		return _ShapeSnapshot2D.new(node)
	elif node is Area3D:
		return _AreaSnapshot3D.new(node)
	elif node is Area2D:
		return _AreaSnapshot2D.new(node)
	return null

## Record the given tick for simulation aware collision nodes.
func record_tick(tick: int) -> void:
	var snapshot_dict : Dictionary[Node, _CollisionSnapshot] = {}

	var i := _tracked_nodes.size() - 1
	while i >= 0:
		var node := _tracked_nodes[i]
		
		# While we are iterating tracked_nodes, remove if anyone is invalid.
		
		if not is_instance_valid(node):
			_logger.trace("while recording tick(%s): dropping invalid node at index %s", [tick, i])
			_tracked_nodes.remove_at(i)
			i -= 1
			continue
		
		snapshot_dict[node] = _take_snapshot_for_node(node)
		i -= 1

	_logger.trace("recorded tick(%s): recorded %s node(s)", [tick, snapshot_dict.size()])
	_snapshots_by_tick[tick] = snapshot_dict

## Restore the collision aware nodes to given tick.
## If any of the collision aware nodes was not alive for given tick,
## This function will disable them.
func restore_tick(tick: int) -> void:
	if not _snapshots_by_tick.has(tick):
		_logger.warning(
			"No snapshot recorded for tick %s (maybe older history or never recorded). Skipping restore.",
			[tick]
		)
		return
	
	var snapshot_dict := _snapshots_by_tick[tick] as Dictionary
	var restored_count := 0
	var excluded_count := 0
	
	for node in _tracked_nodes:
		if not is_instance_valid(node):
			continue
		
		if snapshot_dict.has(node):
			var snap : _CollisionSnapshot = snapshot_dict[node]
			snap.restore_node(node)
			restored_count += 1
		else:
			# Not tracked yet at this historical tick -> didn't exist in the sim yet.
			_exclude_from_collision(node)
			excluded_count += 1
	
	_logger.trace(
		"restored tick(%s): restored %s node(s), excluded %s node(s) not yet alive at this tick",
		[tick, restored_count, excluded_count]
	)

## Excludes a node from all collision queries. Not snapshot-driven - a node with no
## recorded snapshot at this tick has no data to restore from, only a fact to enforce
## ("this didn't exist yet"), so this stays a plain type check against the live node.
func _exclude_from_collision(node: Node) -> void:
	_logger.trace("Excluding node %s from collision (not alive at this historical tick)", [node.name])
	if node is CollisionShape3D or node is CollisionShape2D:
		node.disabled = true
	elif node is Area3D or node is Area2D:
		node.monitoring = false
		node.monitorable = false
		node.collision_layer = 0

## Capture the current state of simulation aware collision nodes.
## This is used to restore the latest after our operation is done.
## Internally [_SimulatorServer] will restore to this state by calling restore_snapshot.
func capture_current_state() -> Dictionary:
	var live : Dictionary[Node, _CollisionSnapshot] = {}
	var i := _tracked_nodes.size() - 1
	while i >= 0:
		var node := _tracked_nodes[i]
		if not is_instance_valid(node):
			_logger.trace("capturing current state(): dropping invalid node at index %s", [i])
			_tracked_nodes.remove_at(i)
			i -= 1
			continue

		live[node] = _take_snapshot_for_node(node)
		i -= 1
	
	_logger.trace("captured current state(): captured %s node(s)", [live.size()])
	return live


## Restore simulation aware collision nodes to given snapshot dict.
func restore_snapshot(snapshot_dict: Dictionary) -> void:
	var restored_count := 0
	
	for node in snapshot_dict:
		
		if not is_instance_valid(node):
			continue
		
		var collision_snapshot : _CollisionSnapshot = snapshot_dict[node]
		collision_snapshot.restore_node(node)
		restored_count += 1
	
	_logger.trace("restored snapshot(): restored %s node(s) to captured live state", [restored_count])

## Trim ticks that we dont need anymore.
## Will trim every tick older than param beginning. (not inclusive)
func trim_ticks(beginning: int) -> void:
	for tick in _snapshots_by_tick.keys():
		if tick < beginning:
			_snapshots_by_tick.erase(tick)
			_logger.trace("trimming tick#%s", [tick])
