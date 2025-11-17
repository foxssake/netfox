extends Node
class_name _NetworkRollback

## Orchestrates the rollback loop.
##
## @tutorial(NetworkRollback Guide): https://foxssake.github.io/netfox/latest/netfox/guides/network-rollback/
## @tutorial(Modifying objects during rollback): https://foxssake.github.io/netfox/latest/netfox/tutorials/modifying-objects-during-rollback/

## Whether rollback is enabled.
var enabled: bool = ProjectSettings.get_setting(&"netfox/rollback/enabled", true)

## Whether diff states are enabled.
## [br][br]
## Diff states send only the state properties that have changed.
var enable_diff_states: bool = ProjectSettings.get_setting(&"netfox/rollback/enable_diff_states", true)

## How many ticks to store as history.
## [br][br]
## The larger the history limit, the further we can roll back into the past,
## thus the more latency we can manage. The drawback is, with higher history
## limit comes more history data stored, thus higher memory usage.
## [br][br]
## Rollback won't go further than this limit, regardless of inputs received.
## [br][br]
## [i]read-only[/i], you can change this in the project settings
var history_limit: int:
	get:
		return _history_limit
	set(v):
		push_error("Trying to set read-only variable history_limit")

## The earliest tick that history is retained for.
## [br][br]
## Determined by [member history_limit].
## [br][br]
## [i]read-only[/i]
var history_start: int:
	get:
		return maxi(0, NetworkTime.tick - history_limit)
	set(v):
		push_error("Trying to set read-only variable history_start")

## Offset into the past for display, in ticks.
## [br][br]
## After the rollback, we have the option to not display the absolute latest
## state of the game, but let's say the state two frames ago ( offset = 2 ).
## This can help with hiding latency, by giving more time for an up-to-date
## state to arrive before we try to display it.
## [br][br]
## [i]read-only[/i], you can change this in the project settings
var display_offset: int:
	get:
		return _display_offset
	set(v):
		push_error("Trying to set read-only variable display_offset")

## The currently displayed tick.
## [br][br]
## This is the current tick as returned by [member _NetworkTime.tick], minus
## the [member display_offset]. By configuring the [member display_offset], a
## past tick may be displayed to the player, so that updates from the server
## have slightly more time to arrive, masking latency.
## [br][br]
## [i]read-only[/i]
var display_tick: int:
	get:
		if enabled:
			return maxi(0, NetworkTime.tick - NetworkRollback.display_offset)
		else:
			return NetworkTime.tick
	set(v):
		push_error("Trying to set read-only variable display_tick")

## Offset into the future to submit inputs, in ticks.
##
## By submitting inputs into the future, they don't happen instantly, but with
## some delay. This can help hiding latency - even if input takes some time to
## arrive, it will still be up to date, as it was timestamped into the future.
## This only works if the input delay is greater than the network latency.
## [br][br]
## In cases where the latency is greater than the input delay, this can still
## reduce the amount of resimulated frames, resulting in less compute.
## [br][br]
## [b]Note:[/b] the [code]is_fresh[/code] parameter may not work as expected
## with input latency higher than network latency.
## [br][br]
## [i]read-only[/i], you can change this in the project settings

var input_delay: int:
	get:
		return _input_delay
	set(v):
		push_error("Trying to set read-only variable input_delay")

## How many previous input frames to send along with the current one.
## [br][br]
## As inputs are sent over an unreliable channel, packets may get lost or appear
## out of order. To mitigate packet loss, we send the current and previous n
## ticks of input data. This way, even if the input for a given tick gets lost
## in transmission, the next (n-1) packets will contain the data for it.
## [br][br]
## [i]read-only[/i], you can change this in the project settings

var input_redundancy: int:
	get:
		return max(1, _input_redundancy)
	set(v):
		push_error("Trying to set read-only variable input_redundancy")

## The current [i]rollback[/i] tick.
## [br][br]
## Note that this is different from [member _NetworkTime.tick], and only makes
## sense in the context of a rollback loop.
var tick: int:
	get:
		return _tick
	set(v):
		push_error("Trying to set read-only variable tick")

## Event emitted before running the network rollback loop.
signal before_loop()

## Event emitted in preparation of each rollback tick.
## [br][br]
## Handlers should apply the state and input corresponding to the given tick.
signal on_prepare_tick(tick: int)

## Event emitted after preparing each rollback tick.
## [br][br]
## Handlers may process the prepared tick, e.g. modulating the input by its age
## to implement input prediction.
signal after_prepare_tick(tick: int)

## Event emitted to process the given rollback tick.
## [br][br]
## Handlers should check if they *need* to resimulate the given tick, and if so,
## generate the next state based on the current data ( applied in the prepare
## tick phase ).
signal on_process_tick(tick: int)

## Event emitted after the given rollback tick was processed.
signal after_process_tick(tick: int)

## Event emitted to record the given rollback tick.
## [br][br]
## By this time, the tick is advanced from the simulation, handlers should save
## their resulting states for the given tick.
signal on_record_tick(tick: int)

## Event emitted after running the network rollback loop.
signal after_loop()

# Settings
var _history_limit: int = ProjectSettings.get_setting(&"netfox/rollback/history_limit", 64)
var _display_offset: int = ProjectSettings.get_setting(&"netfox/rollback/display_offset", 0)
var _input_delay: int = ProjectSettings.get_setting(&"netfox/rollback/input_delay", 0)
var _input_redundancy: int = ProjectSettings.get_setting(&"netfox/rollback/input_redundancy", 3)

# Timing
var _tick: int = 0
var _resim_from: int

var _rollback_from: int = -1
var _rollback_to: int = -1
var _rollback_stage: String = ""

# Resim + mutations
var _is_rollback: bool = false
var _simulated_nodes: _Set = _Set.new()
var _mutated_nodes: Dictionary = {}
var _input_submissions: Dictionary = {}

const _STAGE_BEFORE := "B"
const _STAGE_PREPARE := "P"
const _STAGE_SIMULATE := "S"
const _STAGE_RECORD := "R"
const _STAGE_AFTER := "A"

static var _logger: NetfoxLogger = NetfoxLogger._for_netfox("NetworkRollback")

## Submit the resimulation start tick for the current loop.
##
## This is used to determine the resimulation range during each loop.
func notify_resimulation_start(tick: int) -> void:
	_resim_from = min(_resim_from, tick)

## Submit node for simulation.
##
## This is used mostly internally by [RollbackSynchronizer]. The idea is to
## submit each affected node while preparing the tick, and then run only the
## nodes that need to be resimulated.
func notify_simulated(node: Node) -> void:
	_simulated_nodes.add(node)


## Check if node was submitted for simulation.
##
## This is used mostly internally by [RollbackSynchronizer]. The idea is to
## submit each affected node while preparing the tick, and then use
## [member is_simulated] to run only the nodes that need to be resimulated.
func is_simulated(node: Node) -> bool:
	return _simulated_nodes.has(node)

## Check if a network rollback is currently active.
func is_rollback() -> bool:
	return _is_rollback

## Checks if a given object is rollback-aware, i.e. has the
## [code]_rollback_tick[/code] method implemented.
##
## This is used by [RollbackSynchronizer] to see if it should simulate the
## given object during rollback.
func is_rollback_aware(what: Object) -> bool:
	return what.has_method(&"_rollback_tick")

## Calls the [code]_rollback_tick[/code] method on the target, running its
## simulation for the given rollback tick.
## [br][br]
## This is used by [RollbackSynchronizer] to resimulate ticks during rollback.
## While the [code]_rollback_tick[/code] method could be called directly as
## well, this method exists to future-proof the code a bit, so the method name
## is not repeated all over the place.
## [br][br]
## [i]Note:[/i] Make sure to check if the target is rollback-aware, because if
## it's not, this method will run into an error.
func process_rollback(target: Object, delta: float, p_tick: int, is_fresh: bool) -> void:
	target._rollback_tick(delta, p_tick, is_fresh)

## Marks the target object as mutated.
## [br][br]
## Mutated objects will be re-recorded for the specified tick, and resimulated
## from the given tick onwards.
## [br][br]
## For special cases, you can specify the tick when the mutation happened. Since
## it defaults to the current rollback [member tick], this parameter rarely
## needs to be specified.
## [br][br]
## Note that registering a mutation into the past will yield a warning.
## [br][br]
## @experimental: The Mutations API is experimental!
func mutate(target: Object, p_tick: int = tick) -> void:
	_mutated_nodes[target] = mini(p_tick, _mutated_nodes.get(target, p_tick))

	if is_rollback() and p_tick < tick:
		_logger.warning(
			"Trying to mutate object %s in the past, for tick %d!",
			[target, p_tick]
		)

## Check whether the target object was mutated in or after the given tick via
## [method mutate].
## [br][br]
## @experimental: The Mutations API is experimental!
func is_mutated(target: Object, p_tick: int = tick) -> bool:
	if _mutated_nodes.has(target):
		return p_tick >= _mutated_nodes.get(target)
	else:
		return false

## Check whether the target object was mutated specifically in the given tick
## via [method mutate].
## [br][br]
## @experimental: The Mutations API is experimental!
func is_just_mutated(target: Object, p_tick: int = tick) -> bool:
	if _mutated_nodes.has(target):
		return _mutated_nodes.get(target) == p_tick
	else:
		return false

## Register that a node has submitted its input for a specific tick
func register_input_submission(root_node: Node, tick: int) -> void:
	if not _input_submissions.has(root_node):
		_input_submissions[root_node] = tick
	else:
		_input_submissions[root_node] = maxi(_input_submissions[root_node], tick)

## Get the latest input tick submitted by a specific root node
## [br][br]
## Returns [code]-1[/code] if no input was submitted for the node, ever.
func get_latest_input_tick(root_node: Node) -> int:
	if _input_submissions.has(root_node):
		return _input_submissions[root_node]
	return -1

## Check if a node has submitted input for a specific tick (or later)
func has_input_for_tick(root_node: Node, tick: int) -> bool:
	return _input_submissions.has(root_node) and _input_submissions[root_node] >= tick

## Free all input submission data for a node
## [br][br]
## Use this once the node is freed.
func free_input_submission_data_for(root_node: Node) -> void:
	_input_submissions.erase(root_node)

func _ready():
	NetfoxLogger.register_tag(_get_rollback_tag)
	NetworkTime.after_tick_loop.connect(_rollback)

func _exit_tree():
	NetfoxLogger.free_tag(_get_rollback_tag)

func _get_rollback_tag() -> String:
	if _is_rollback:
		return "%s@%d|%d>%d" % [_rollback_stage, _tick, _rollback_from, _rollback_to]
	else:
		return "_"

func _rollback() -> void:
	if not enabled:
		return

	# Ask all rewindables to submit their earliest inputs
	_resim_from = NetworkTime.tick
	before_loop.emit()

	# Only set _is_rollback *after* emitting before_loop
	_is_rollback = true
	_rollback_stage = _STAGE_BEFORE

	# from = Earliest input amongst all rewindables
	var from := _resim_from

	# to = Current tick
	var to := NetworkTime.tick

	# Limit number of rollback ticks
	if to - from > history_limit:
		_logger.warning(
			"Trying to run rollback for ticks %d to %d, past the history limit of %d",
			[from, to, history_limit]
		)
		from = NetworkTime.tick - history_limit

	# for tick in from .. to:
	_rollback_from = from
	_rollback_to = to
	for tick in range(from, to):
		_tick = tick
		_simulated_nodes.clear()

		# Prepare state
		#	Done individually by Rewindables ( usually Rollback Synchronizers )
		#	Restore input and state for tick
		_rollback_stage = _STAGE_PREPARE
		on_prepare_tick.emit(tick)
		after_prepare_tick.emit(tick)

		# Simulate rollback tick
		#	Method call on rewindables
		#	Rollback synchronizers go through each node they manage
		#	If current tick is in node's range, tick
		#		If authority: Latest input >= tick >= Latest state
		#		If not: Latest input >= tick >= Earliest input
		_rollback_stage = _STAGE_SIMULATE
		on_process_tick.emit(tick)
		after_process_tick.emit(tick)

		# Record state for tick + 1
		_rollback_stage = _STAGE_RECORD
		on_record_tick.emit(tick + 1)

	# Restore display state
	_rollback_stage = _STAGE_AFTER
	after_loop.emit()

	# Cleanup
	_mutated_nodes.clear()
	_is_rollback = false

# Insight 1:
#	state(x) = simulate(state(x - 1), input(x - 1))
#	state(x + 1) = simulate(state(x), input(x))
# Insight 2:
#	Server is authorative over all state, client over its own input, i.e.
#	Server broadcasts state
#	Client sends input to server
# Flow:
#	Clients send in their inputs
#	Server simulates frames from earliest input to current
#	Server broadcasts simulated frames
#	Clients receive authorative states
#	Clients simulate local frames
