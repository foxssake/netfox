extends PhysicsDriver

class_name RapierDriver

## Base class for the Rapier physics drivers.
## [br][br]
## Rewinding the space to a state from before a body spawned wipes that body
## on the engine side. Cached space states are therefore pruned up to the
## tick a body first appears in, so rollback never rewinds past it.

# Ticks before this are frozen during a rollback loop, -1 for none
var _space_hold_until: int = -1

var _known_bodies: Dictionary = {}

# StateManager2D / StateManager3D, created by subclasses
var _state

static var _logger: NetfoxLogger = NetfoxLogger._for_extras("RapierDriver")

func _enter_tree():
	super()
	if rollback_physics_space:
		NetworkRollback.before_loop.connect(_on_before_rollback_loop)

func _exit_tree():
	if NetworkRollback.before_loop.is_connected(_on_before_rollback_loop):
		NetworkRollback.before_loop.disconnect(_on_before_rollback_loop)
	super()

func before_tick(delta: float, tick: int) -> void:
	# Check before the snapshot in super(), so new bodies are included in it
	if rollback_physics_space:
		_check_for_spawned_bodies()
	super(delta, tick)

func on_prepare_tick(tick: int) -> void:
	if tick < _space_hold_until:
		return
	super(tick)

func on_process_tick(tick: int) -> void:
	if tick < _space_hold_until:
		return
	super(tick)

func after_tick_loop() -> void:
	super()
	_space_hold_until = -1

## Override to return true for physics bodies this driver simulates.
func _is_tracked_body(_body: Node) -> bool:
	return true

## Drop cached space states up to and including [param tick].
func invalidate_space_cache_through(tick: int) -> int:
	var tags: Array = _state.ordered_cache_tags()
	var dropped: int = 0
	for i: int in range(tags.size() - 1, -1, -1):
		if int(tags[i]) <= tick:
			_state.remove_cached_by_index(i)
			dropped += 1
	return dropped

## Drop cached space states up to the current tick, e.g. after spawning
## raw physics bodies that are not in the "network_rigid_body" group.
static func _invalidate_for_spawn(tree: SceneTree, group: StringName) -> void:
	var driver: RapierDriver = tree.get_first_node_in_group(group) as RapierDriver
	if driver != null:
		driver.invalidate_space_cache_through(NetworkTime.tick)

## Prune states that predate newly spawned bodies.
## Returns true if any bodies appeared since the last check.
func _check_for_spawned_bodies() -> bool:
	var has_new_bodies := false
	for body: Node in get_tree().get_nodes_in_group("network_rigid_body"):
		if not _is_tracked_body(body) or _known_bodies.has(body):
			continue
		_known_bodies[body] = true
		# Forget on exit, so a re-added body (e.g. pooled) counts as spawning again
		body.tree_exiting.connect(_on_tracked_body_exiting.bind(body), CONNECT_ONE_SHOT)
		has_new_bodies = true

	if has_new_bodies:
		var dropped: int = invalidate_space_cache_through(NetworkTime.tick)
		if dropped > 0:
			_logger.debug("Pruned %d space cache states through tick %d for newly spawned bodies", [dropped, NetworkTime.tick])
	return has_new_bodies

func _on_tracked_body_exiting(body: Node) -> void:
	_known_bodies.erase(body)

func _on_before_rollback_loop() -> void:
	if _check_for_spawned_bodies():
		# The tick's snapshot predates the new bodies, so cache a fresh one
		_snapshot_space(NetworkTime.tick)

func _rollback_space(tick: int) -> void:
	# Tags are ordered oldest first. A tick may be cached more than once
	# while history is being rewritten, so look it up by tag.
	var cache_tags: Array = _state.ordered_cache_tags()
	var index: int = cache_tags.rfind(tick)
	if index < 0:
		if cache_tags.is_empty() or tick > int(cache_tags[0]):
			_logger.error("No space cache for tick %d during rollback rewind - replaying from the current space state", [tick])
			return
		# Tick predates all cached states, e.g. because bodies spawned since.
		# Rewind to the oldest state and hold, so earlier ticks are not resimulated.
		index = 0
		_space_hold_until = int(cache_tags[0])
		_logger.warning("No space cache for tick %d during rollback rewind - rewinding to the oldest cached state @%d and holding until then", [tick, _space_hold_until])

	_state.load_cached_state(physics_space, index)
	_nudge_bodies_awake()

## After a rewind, rapier may consider awake bodies at rest and stop syncing
## them with their nodes. Toggling sleeping nudges them awake again.
func _nudge_bodies_awake() -> void:
	for body: Node in get_tree().get_nodes_in_group("network_rigid_body"):
		if not _is_tracked_body(body):
			continue
		if body is RigidBody3D:
			_nudge_body_3d_awake(body)
		elif body is RigidBody2D:
			_nudge_body_2d_awake(body)

func _nudge_body_3d_awake(body: RigidBody3D) -> void:
	# Read and write velocities on the server state; node properties may be stale after the rewind
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state == null or state.sleeping:
		return
	var linear_velocity: Vector3 = state.linear_velocity
	var angular_velocity: Vector3 = state.angular_velocity
	body.sleeping = true
	body.sleeping = false
	state.linear_velocity = linear_velocity
	state.angular_velocity = angular_velocity

func _nudge_body_2d_awake(body: RigidBody2D) -> void:
	var state: PhysicsDirectBodyState2D = PhysicsServer2D.body_get_direct_state(body.get_rid())
	if state == null or state.sleeping:
		return
	var linear_velocity: Vector2 = state.linear_velocity
	var angular_velocity: float = state.angular_velocity
	body.sleeping = true
	body.sleeping = false
	state.linear_velocity = linear_velocity
	state.angular_velocity = angular_velocity
