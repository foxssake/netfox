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
##
## 2- Authoritative peer - this [Simulator] doesnt have network authority, but
## [InputSender]s input_node (your custom player_input.gdscript code) belongs to
## local peer. This would be your typical player. [br]
##
## On authoritative peer, [Simulator] runs _simulated_tick with [InputSender]'s
## fresh local inputs (inputs that may or may not have been sent to server at this point).
## After applying true state, [Simulator] re-runs _simulated_tick to reach current
## game state. [br][br]
##
## 3- Puppet peer - both [Simulator] and [InputSender]s input_node (your custom
## player_input.gdscript code) doesnt have authority. This is how you see remote
## players when you are playing the game. For example your friend is a puppet player
## in your game. [br]
##
## On puppet peers, [Simulator] only applies truth received from host
## For most games this will be enough. Even with [InputSender] broadcast toggled on from
## project settings, there is no point in re-running _simulated_ticks because server
## sends states with inputs at the same time. For puppet peers we simply dont know
## their future inputs. [br][br]
##
## TODO: Simulator can have option to predict if input_broadcast is on for inputsender. [br]
## [br]
## [b]Ticks[/b]: simulating works the same way as rollback. For tick T, the
## inputs of tick T are applied, then [code]_simulated_tick(delta, T, is_fresh)[/code]
## is called, and the resulting state is recorded as the state of tick T + 1:
## [codeblock]
## func _simulated_tick(delta: float, tick: int, is_fresh: bool) -> void:
##     # Inputs of tick are applied here, the state you leave behind
##     # is the state of tick + 1
##     velocity = input.movement * speed
##     move_and_slide()
## [/codeblock]
## [code]is_fresh[/code] is true the first time a tick is simulated. Local
## authoritative peers simulate the same tick again after receiving the truth
## from the host, with [code]is_fresh[/code] false, so use it for effects like
## sounds that should play once.

## The root node for resolving node paths in properties. Defaults to the parent node.
@export var root: Node = get_parent()

## [Simulator] needs [InputSender] assigned to work with at the first place.
## Any authority change to [InputSender]'s input node (example PlayerInput) requires
## calling [method Simulator.process_settings].
## Changing or assigning [InputSender] during runtime is not recommended by design, but also
## requires call to [method Simulator.process_settings].
@export var listened_input_sender : InputSender = null

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

# Nodes with a schema registered through this Simulator, see set_schema()
var _schema_nodes := _Set.new()

var _properties_dirty: bool = false

# Dictionary (root node) -> (managing simulator)
# Used to check for foreign roots when gathering simulated nodes.
static var _managed_roots := {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	process_settings.call_deferred()

	# Reprocess authority on connect
	if NetworkEvents.enabled:
		# User might change `multiplayer` - `NetworkEvents` handles that
		NetworkEvents.on_client_start.connect(func(__): process_settings())
	else:
		multiplayer.connected_to_server.connect(process_settings)

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	_managed_roots[root] = self

	if not visibility_filter:
		visibility_filter = PeerVisibilityFilter.new()

	if not visibility_filter.get_parent():
		add_child(visibility_filter)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_managed_roots.erase(root)


	for node in _sim_nodes + _state_properties.get_subjects():
		NetworkSynchronizationServer.deregister(node)
		NetworkIdentityServer.deregister_node(node)
		NetworkHistoryServer.deregister(node)

	SimulatorServer.deregister_simulator(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()

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

## Process settings based on authority.
## [br][br]
## Call this whenever the authority of input node changes.
## Make sure to do this at the same time on all peers.
func process_authority():
	# First de-register.
	SimulatorServer.deregister_simulator(self)

	for node in _state_properties.get_subjects():
		for property in _state_properties.get_properties_of(node):
			NetworkHistoryServer.deregister_simulator(node, property)
			NetworkSynchronizationServer.deregister_simulator(node, property)

	# Process authority
	_state_properties.set_from_paths(root, state_properties)

	if not listened_input_sender:
		_logger.error("Simulator needs listened_input_sender configured and valid.")
		return

	# Register state properties.
	for node in _state_properties.get_subjects():
		for property in _state_properties.get_properties_of(node):
			NetworkHistoryServer.register_simulator(node, property)
			NetworkSynchronizationServer.register_simulator(node, property)

	SimulatorServer.register_simulator(self)

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

## Set the schema for transmitting properties over the network.
## [br][br]
## The [param schema] must be a dictionary, with the keys being property path
## strings, and the values are the associated [NetworkSchemaSerializer] objects.
## Properties are interpreted relative to the [member root] node. The schema
## should contain state properties, input properties are set on the
## [member listened_input_sender] instead. Properties not specified in the
## schema will use a generic fallback serializer. By using the right serializer
## for the right property, bandwidth usage can be lowered.
## [br][br]
## The schema must be the same on every peer.
## [br][br]
## See [NetworkSchemas] for many common serializers.
## [br][br]
## Example:
## [codeblock]
##    simulator.set_schema({
##        ":global_transform": NetworkSchemas.transform3f32(),
##        ":velocity": NetworkSchemas.vec3f32()
##    })
## [/codeblock]
func set_schema(schema: Dictionary) -> void:
	# Remove previous schema
	clear_schema()

	# Register new schema
	merge_schema(schema)

## Add serializers from [param schema].
## [br][br]
## See [method set_schema] for specifying [param schema]. As opposed to [method
## set_schema], this method updates the schema, instead of overriding it. If
## a property had a serializer specified previously, this will replace it.
func merge_schema(schema: Dictionary) -> void:
	for prop in schema:
		var prop_entry := PropertyEntry.parse(root, prop)
		var serializer := schema[prop] as NetworkSchemaSerializer
		NetworkSynchronizationServer.register_schema(prop_entry.node, prop_entry.property, serializer)
		_schema_nodes.add(prop_entry.node)

## Clear any serializers specified earlier.
## [br][br]
## See [method set_schema].
func clear_schema() -> void:
	for node in _schema_nodes:
		NetworkSynchronizationServer.deregister_schema_for(node)
	_schema_nodes.clear()

## Check if this [Simulator] has authority over its inputs via listened_input_sender
## This helper is used by SimulatorServer internally.
func has_authority_over_inputs() -> bool:
	if not listened_input_sender:
		return false

	return listened_input_sender.has_authority_over_input_nodes()

func _reprocess_settings() -> void:
	if not _properties_dirty or Engine.is_editor_hint():
		return

	_properties_dirty = false

	process_settings()

# Helper function to run simulation with given parameters.
# This function is used by SimulatorServer internally.
func _run_simulation(delta : float, tick : int, is_fresh : bool) -> void:
	for node in _sim_nodes:
		if node:
			node.call("_simulated_tick", delta, tick, is_fresh)

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
