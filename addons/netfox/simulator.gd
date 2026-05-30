@tool
extends Node
class_name Simulator

## @experimental [Simulator] name is a wip. [br]
## Simulates network logic depending on network authority. Make sure to read
## them before using [Simulator].[br]
##
## There are 3 seperate workflows [Simulator] operate on. [br][br]
##
## 1- Host - this [Simulator] has network authority, but [InputSender]'s
## input_node (your custom player_input.gdcript code) belongs to some other peer.
## This would be your typical server (host) but doesnt have to be if you are going
## for some custom solution (example: mesh network).[br]
##
## On host [Simulator] runs _simulated_tick functions with new inputs which
## is received by [InputSender]. After running _simulated_tick with new received
## inputs, [Simulator] broadcasts ground truth (state properties) to peers.
## Use this to code game logic that must run on host. If you would like to code
## additional host side logic (example: changing team only on host) you can check
## if its host or not in _simulated_tick. [br][br]
##
## 2- Authoritative peer - this [Simulator] doesnt have network authority, but
## [InputSender]s input_node (your custom player_input.gdscript code) belongs to
## local peer. This would be your typical player. [br]
##
## On authoritative peer, [Simulator] runs _simulated_tick with [InputSender]'s
## fresh local inputs (inputs that may or may not have been sent to server at this point).
## Upon receiving ground truth from host, [Simulator] compares difference in state
## and decide whether to use snapping or interpolating depending on threshold.
## After applying true state, [Simulator] re-runs _simulated_tick to reach current
## game state. [br][br]
##
## 3- Puppet peer - both [Simulator] and [InputSender]s input_node (your custom
## player_input.gdscript code) doesnt have authority. This is how you see remote
## players when you are playing the game. For example your friend is a puppet player
## in your game. [br]
##
## On puppet peers, [Simulator] only applies truth received from host and interpolate
## it. For most games this will be enough. Even with [InputSender] broadcast toggled on from
## project settings, there is no point in re-running _simulated_ticks because server
## sends states with inputs at the same time. For puppet peers we simply dont know 
## their future inputs. [br][br]
##
##
## TODO: Simulator can have option to predict if input_broadcast is on for inputsender. [br]
##
## TODO: what about physics and physic stepping? [br]
## It can be coded with _simulated_ticks if you involve some local properties to script
## that has role in godots _physics_process. If we can avoid coding physic stepping we should.

# TODO explore and test order below.
# order insight:
# on before tick, input-sender records and syncronizes inputs
# on tick, input-sender runs its logic and emits its signals but its not related with simulator.
# on-after-tick simulator will run its own logic depending on work mode explained above as 1-2-3.
# after running its logic, simulator will record and syncronize state.
# Saving and syncronizing is done via NetworkTime right after emitting after_tick signal.

## The root node for resolving node paths in properties. Defaults to the parent node.
@export var root: Node = get_parent()

## [Simulator] needs [InputSender] assigned to work with at the first place.
## Any authority change to [InputSender]'s input node (example PlayerInput) requires
## calling [method Simulator.process_settings].
## Changing or assigning [InputSender] during runtime is not recommended by design, but also
## requires call to [method Simulator.process_settings].
@export var listened_input_sender : InputSender = null

## If true, [Simulator] will run _simulated_tick functions with fresh received inputs.
## Set this to true, if you want to code host side logic with client inputs.
## For example: moving a vehicle on server with client inputs.
## NOTE: Dont get confused, if host is also player and owner of [InputSender]
## [Simulator] will run _simulated_tick even though this set to false.
@export var simulate_on_host := true

@export_group("State")
## Properties that define the game state.
## [br][br]
## State properties are recorded for each tick.
## State is restored when host broadcasts truth, [Simulator] then will accept this
## as true state and apply it.[Simulator] will call _simulated_tick for the t.
@export var state_properties: Array[String]

# Simulated nodes.
var _sim_nodes := [] as Array[Node]

## Decides which peers will receive updates
var visibility_filter := PeerVisibilityFilter.new()

@onready var _logger: NetfoxLogger = NetfoxLogger._for_netfox("Simulator:" + root.name)

var _state_properties := _PropertyPool.new()

var _properties_dirty: bool = false

# Flag to connect signals only once.
var _signals_connected : bool = false 

# Latest input tick we did operation. This is saved to remember.
# TODO should we set this to -1 on process_settings?
var _latest_input_tick : int = -1

# Latest snapshot applied from host (source of truth)
var _latest_applied_snapshot : int = -1

# Dictionary (root node) -> (managing simulator)
# Used to check for foreign roots when gathering simulated nodes.
static var _managed_roots := {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	_managed_roots[root] = self
	
	if not visibility_filter:
		visibility_filter = PeerVisibilityFilter.new()
	
	if not visibility_filter.get_parent():
		add_child(visibility_filter)
	
	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync
	
	process_settings.call_deferred()

func _exit_tree() -> void:
	_managed_roots.erase(root)

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()
	elif what == NOTIFICATION_PREDELETE:
		for node in _sim_nodes + _state_properties.get_subjects():
			NetworkSynchronizationServer.deregister(node)
			NetworkIdentityServer.deregister_node(node)
			NetworkHistoryServer.deregister(node)

func _get_configuration_warnings() -> PackedStringArray:
	if not root:
		root = get_parent()
	
	# Explore state and input properties
	if not root:
		return ["No valid root node found!"]
	
	var result := PackedStringArray()
	result.append_array(_NetfoxEditorUtils.gather_properties(root, "_get_simulator_state_properties",
		func(node, prop):
			add_state(node, prop)
	))
	
	return result

## Process settings.
## [br][br]
## Call this after any change to configuration. Updates based on authority too
## ( calls process_authority ).
func process_settings() -> void:
	_sim_nodes.clear()
	
	process_authority()
	
	# Gather simulated nodes.
	var managed_nodes := [root] + _collect_managed_nodes(root)
	_logger.debug("Filtering managed nodes: %s", [managed_nodes])
	for node in managed_nodes:
		if node.has_method("_simulated_tick"):
			_sim_nodes.push_back(node)
	
	# Register identifiers
	for node in _state_properties.get_subjects():
		NetworkIdentityServer.register_node(node)
	
	# Register visibility filter
	for node in _state_properties.get_subjects():
		NetworkSynchronizationServer.register_visibility_filter(node, visibility_filter)
	
	if not _signals_connected:
		_connect_signals()
		_signals_connected = true

## Process settings based on authority.
## [br][br]
## Call this whenever the authority of input node changes.
## Make sure to do this at the same time on all peers.
func process_authority():
	# First de-register.
	for node in _state_properties.get_subjects():
		for property in _state_properties.get_properties_of(node):
			NetworkHistoryServer.deregister_simulator(node, property)
			NetworkSynchronizationServer.deregister_simulator(node, property)
	
	# Process authority
	_state_properties.set_from_paths(root, state_properties)
	
	# Register state properties.
	for node in _state_properties.get_subjects():
		for property in _state_properties.get_properties_of(node):
			NetworkHistoryServer.register_simulator(node, property)
			NetworkSynchronizationServer.register_simulator(node, property)

## Add a state property.
## [br][br]
## Settings will be automatically updated. The [param node] may be a string or
## [NodePath] pointing to a node, or an actual [Node] instance. If the given
## property is already tracked, this method does nothing.
func add_state(node: Variant, property: String):
	var property_path := PropertyEntry.make_path(root, node, property)
	if not property_path or state_properties.has(property_path):
		return
	
	state_properties.push_back(property_path)
	_properties_dirty = true
	_reprocess_settings.call_deferred()

func _reprocess_settings() -> void:
	if not _properties_dirty or Engine.is_editor_hint():
		return
	
	_properties_dirty = false
	
	process_settings()

func _connect_signals() -> void:
	NetworkTime.after_tick.connect(_on_after_tick)

# Do logic depending on mode explained in class description.
func _on_after_tick(delta: float, tick: int) -> void:
	
	# Return if there is no listened input sender assigned.
	if not listened_input_sender:
		_logger.warning("%s listened_input_sender is needed for simulator to operate",
		[name])
		return
	
	# Figure out which mode we are operating on.
	var has_input_authority := listened_input_sender.has_authority_over_input_nodes()
	var has_simulator_authority := is_multiplayer_authority()
	
	if has_input_authority:
		# This is authoritative player
		# Even if this is host application, treat this as authoritative_peer since it has
		# input authority.
		_handle_authoritative_peer(delta, tick)
		return
	
	if has_simulator_authority:
		# This is host
		_handle_host(delta, tick)
		return
	
	# this is puppet peer.
	_handle_puppet_peer(delta, tick)

# Check if there is a new snapshot from host
# if there is a new snapshot, apply and simulate onwards with buffered inputs. 
func _handle_authoritative_peer(_delta: float, tick: int) -> void:
	
	# Get latest tick where we had sync data available for this simulator.
	var latest_simulator_tick := NetworkHistoryServer.get_latest_simulator_for(
		_state_properties.get_subjects(), tick)
	
	# If its -1 we never received snapshot, thus no need to apply it.
	if latest_simulator_tick >= 0:
	# Apply latest_snapshot.
		var latest_received_snapshot := NetworkHistoryServer._get_simulator_snapshot(latest_simulator_tick)
		if latest_received_snapshot:
			_logger.trace("Authoritative peer applying latest received snapshot as truth: %s", [latest_received_snapshot])
			_apply_snapshot_for_self(latest_received_snapshot)
		else:
			_logger.trace("Apply snapshot called but snapshot is invalid, assuming its first frame"+\
			" and snapshot is not received yet.")
	
	# Now that we accepted truth from host, we can run simulated_ticks
	# with our stored inputs.
	
	_logger.trace("Authoritative peer is looping to run simulated ticks, \
	from inclusive tick %s to exclusive tick %s", [latest_simulator_tick, tick])
	
	# TODO double check this range pls.
	for i in range(latest_simulator_tick, tick):
		_logger.trace("Running simulator tick #%s", [i])
		var local_input_snapshot := NetworkHistoryServer._get_input_sender_snapshot(i)
		
		# TODO sometimes local_input_snapshot is null, figure out why!
		if not local_input_snapshot:
			_logger.trace("Authoritative peer is running simulated ticks, \
			local input snapshot is null at tick %s" %i)
			continue
		
		_logger.trace("Authoritative peer is applying input snapshot %s and running tick",
		[local_input_snapshot])
		
		listened_input_sender._apply_snapshot_for_self(local_input_snapshot)
		for node in _sim_nodes:
			node.call("_simulated_tick", NetworkTime.seconds_between(i, i + 1), i)
	

# Host needs to run _simulated_tick with new received inputs.
func _handle_host(delta: float, tick: int) -> void:
	if not simulate_on_host:
		return
	
	# Get latest received input tick.
	var latest_input_tick := listened_input_sender.get_latest_received_information_tick(tick)
	
	if latest_input_tick == -1:
		# Never received input.
		# Cant run simulation without inputs.
		_logger.trace("Host is skipping simulation on #%s because host never received input", [tick])
		return
	
	# If latest equals our stored latest_tick, this means we already run this simulation.
	# Cant run if inputs are not new, return.
	if latest_input_tick == _latest_input_tick:
		_logger.trace("Host is skipping simulation on #%s because there is no new input", [tick])
		return
	
	var ticks_to_run := latest_input_tick - _latest_input_tick
	
	_logger.trace("Host is looping to run simulated ticks, ticks to run: %s", [ticks_to_run])
	for i in range(_latest_input_tick + 1, latest_input_tick + 1):
		
		var snapshot := NetworkHistoryServer._get_input_sender_snapshot(i)
		listened_input_sender._apply_snapshot_for_self(snapshot)
		for node in _sim_nodes:
			node.call("_simulated_tick", NetworkTime.seconds_between(i, i + 1), i)
	
	_latest_input_tick = tick

# For pupper peer we only need to interpolate latest state to new one.
# TODO Do we need to code interpolation? try it first
# TODO add prediction? i dont think its needed
func _handle_puppet_peer(_delta: float, tick: int) -> void:
	var latest_simulator_tick := NetworkHistoryServer.get_latest_simulator_for(
		_state_properties.get_subjects(), tick)
	
	var latest_received_snapshot := NetworkHistoryServer._get_simulator_snapshot(latest_simulator_tick)
	if latest_received_snapshot:
		_apply_snapshot_for_self(latest_received_snapshot)
	
	# TODO interpolation? try with interpolator first.

# Helper function to apply given snapshot for only this node.
# TODO (same todo with input_sender)?
# Applying whole snapshot and iterating over ticks would be nicer
# if we decide to have singleton for this
func _apply_snapshot_for_self(snapshot : _Snapshot) -> void:
	_logger.trace("Applying snapshot for self :%s", [snapshot])
	for subject in _state_properties.get_subjects():
		for property in _state_properties.get_properties_of(subject):
			
			if snapshot.has_property(subject, property):
				var value := snapshot.get_property(subject, property)
				# TODO is this should be node.set_indexed ??
				subject.set_indexed(property, value)

# Find managed nodes recursively from given root, ignoring branches managed by
# a different [Simulator].
func _collect_managed_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		if _is_foreign_simulator_root(child):
			continue
		result.append(child)
		result.append_array(_collect_managed_nodes(child))
	return result

# Returns true if the node is the root of a different [Simulator].
func _is_foreign_simulator_root(node: Node) -> bool:
	if not _managed_roots.has(node):
		# No simulator, treat node as root
		return false
	
	if _managed_roots[node] == self:
		# Node is our own root
		return false
	
	# Node is foreign root
	return true
