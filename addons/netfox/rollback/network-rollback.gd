extends Node
class_name _NetworkRollback

## Whether rollback is enabled.
var enabled: bool = ProjectSettings.get_setting("netfox/rollback/enabled", true)

## How many ticks to store as history.
##
## The larger the history limit, the further we can roll back into the past, 
## thus the more latency we can manage.
## [br][br]
## Rollback won't go further than this limit, regardless of inputs received.
## [br][br]
## [i]read-only[/i], you can change this in the project settings
var history_limit: int:
	get:
		return ProjectSettings.get_setting("netfox/rollback/history_limit", 64)
	set(v):
		push_error("Trying to set read-only variable history_limit")

## Offset into the past for display.
##
## After the rollback, we have the option to not display the absolute latest
## state of the game, but let's say the state two frames ago ( offset = 2 ).
## This can help with hiding latency, by giving more time for an up-to-date
## state to arrive before we try to display it.
## [br][br]
## [i]read-only[/i], you can change this in the project settings
var display_offset: int:
	get:
		return ProjectSettings.get_setting("netfox/rollback/display_offset", 0)
	set(v):
		push_error("Trying to set read-only variable display_offset")

## How many previous input frames to send along with the current one.
##
## With UDP - packets may be lost, arrive late or out of order.
## To mitigate this, we send the current and previous n ticks of input data.
## [br][br]
## [i]read-only[/i], you can change this in the project settings
var input_redundancy: int:
	get:
		var value = ProjectSettings.get_setting("netfox/rollback/input_redundancy", 3)
		return max(1, value)
	set(v):
		push_error("Trying to set read-only variable input_redundancy")

var tick: int:
	get:
		return _tick
	set(v):
		push_error("Trying to set read-only variable tick")

## Event emitted before running the network rollback loop
signal before_loop()

## Event emitted in preparation of each rollback tick.
##
## Handlers should apply the state and input corresponding to the given tick.
signal on_prepare_tick(tick: int)

## Event emitted to process the given rollback tick.
##
## Handlers should check if they *need* to resimulate the given tick, and if so,
## generate the next state based on the current data ( applied in the prepare
## tick phase ).
signal on_process_tick(tick: int)

## Event emitted to record the given rollback tick.
##
## By this time, the tick is advanced from the simulation, handlers should save
## their resulting states for the given tick.
signal on_record_tick(tick: int)

## Event emitted after running the network rollback loop
signal after_loop()

var _tick: int = 0
var _resim_from: int

var _is_rollback: bool = false
var _simulated_nodes: Dictionary = {}

static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("NetworkRollback")

## Submit the resimulation start tick for the current loop.
##
## This is used to determine the resimulation range during each loop.
func notify_resimulation_start(tick: int):
	_resim_from = min(_resim_from, tick)

## Submit node for simulation.
##
## This is used mostly internally by [RollbackSynchronizer]. The idea is to 
## submit each affected node while preparing the tick, and then run only the
## nodes that need to be resimulated.
func notify_simulated(node: Node):
	_simulated_nodes[node] = true


## Check if node was submitted for simulation.
##
## This is used mostly internally by [RollbackSynchronizer]. The idea is to 
## submit each affected node while preparing the tick, and then use
## [member is_simulated] to run only the nodes that need to be resimulated.
func is_simulated(node: Node):
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
	return what.has_method("_rollback_tick")

## Calls the [code]_rollback_tick[/code] method on the target, running its
## simulation for the given rollback tick.
##
## This is used by [RollbackSynchronizer] to resimulate ticks during rollback.
## While the [code]_rollback_tick[/code] method could be called directly as 
## well, this method exists to future-proof the code a bit, so the method name
## is not repeated all over the place.
## [br][br]
## [i]Note:[/i] Make sure to check if the target is rollback-aware, because if
## it's not, this method will run into an error.
func process_rollback(target: Object, delta: float, p_tick: int, is_fresh: bool):
	target._rollback_tick(delta, p_tick, is_fresh)

func _ready():
	NetworkTime.after_tick_loop.connect(_rollback)

func _rollback():
	if not enabled:
		return

	_is_rollback = true

	# Ask all rewindables to submit their earliest inputs
	_resim_from = NetworkTime.tick
	before_loop.emit()
	
	# from = Earliest input amongst all rewindables
	var from = _resim_from

	# to = Current tick
	var to = NetworkTime.tick

	# Limit number of rollback ticks
	if to - from > history_limit:
		_logger.warning(
			"Trying to run rollback for ticks %d to %d, past the history limit of %d" %
			[from, to, history_limit]
		)
		from = NetworkTime.tick - history_limit

	# for tick in from .. to:
	for tick in range(from, to):
		_tick = tick
		_simulated_nodes.clear()

		# Prepare state
		#	Done individually by Rewindables ( usually Rollback Synchronizers )
		#	Restore input and state for tick
		on_prepare_tick.emit(tick)

		# Simulate rollback tick
		#	Method call on rewindables
		#	Rollback synchronizers go through each node they manage
		#	If current tick is in node's range, tick
		#		If authority: Latest input >= tick >= Latest state
		#		If not: Latest input >= tick >= Earliest input
		on_process_tick.emit(tick)

		# Record state for tick + 1
		on_record_tick.emit(tick + 1)
	
	# Restore display state
	after_loop.emit()
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
