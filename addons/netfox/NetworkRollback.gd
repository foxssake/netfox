extends Node

var enabled: bool = ProjectSettings.get_setting("netfox/rollback/enabled", true)

var history_limit: int:
	get:
		return ProjectSettings.get_setting("netfox/time/history_limit", 64)
	set(v):
		push_error("Trying to set read-only variable history_limit")

var display_offset: int:
	get:
		return ProjectSettings.get_setting("netfox/time/display_offset", 0)
	set(v):
		push_error("Trying to set read-only variable display_offset")

signal before_loop()
signal on_prepare_tick(tick: int)
signal on_process_tick(tick: int)
signal on_record_tick(tick:int)
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
