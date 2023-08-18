extends Node
## This class manages the network rollback code.
##
## In practice, this is done by emitting several events in the right order, and
## counting on the event handlers to behave as expected.
##
## Note that generally you won't need to use this class directly, using
## [RollbackSynchronizer] should be enough.
##
## This is done by running the following loop after every tick loop as managed
## by [NetworkTime]:
##
## 1. Determine simulation range[br]
##   a. On clients, this is the latest state received from server[br]
##   b. On servers, this is the earliest input received from any client[br]
##   c. In practice, this is done by emitting [signal before_loop]
## 2. Resimulate the given range by[br]
##   a. Preparing the frame by applying the corresponding state and input ( see [signal on_prepare_tick] )[br]
##   b. Running the simulation ( see [signal on_process_tick] )[br]
##   c. Recording the resulting state ( see [signal on_record_tick] )[br]
## 3. Conclude the loop[br]
##   a. This includes restoring the appropriate display state ( see [signal after_loop] )[br]

## Whether rollback is enabled.
var enabled: bool = ProjectSettings.get_setting("netfox/rollback/enabled", true)

## How many ticks to store as history.
##
## The larger the history limit, the further we can roll back into the past, 
## thus the more latency we can manage.
##
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
##
## [i]read-only[/i], you can change this in the project settings
var display_offset: int:
	get:
		return ProjectSettings.get_setting("netfox/rollback/display_offset", 0)
	set(v):
		push_error("Trying to set read-only variable display_offset")

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

var _earliest_input = INF

func notify_input_tick(tick: int):
	_earliest_input = min(_earliest_input, tick)

func _ready():
	NetworkTime.after_tick_loop.connect(_rollback)

func _rollback():
	if not enabled:
		return

	# Ask all rewindables to submit their earliest inputs
	_earliest_input = NetworkTime.tick
	before_loop.emit()
	
	# from = Earliest input amongst all rewindables
	var from = _earliest_input

	# to = Current tick
	var to = NetworkTime.tick
	
	# for tick in from .. to:
	for tick in range(from, to):
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
