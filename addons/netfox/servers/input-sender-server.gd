extends Node
class_name _InputSenderServer

# @public class

## Handles [InputSender] related operations.
##
## InputSenderServer does two jobs, after every tick:
## [br]1. [b]Send our own inputs[/b], on every peer: the input properties of
## InputSenders we have authority over are recorded under a stamp and sent to
## the host. On the host, the stamp is the tick itself. On clients, it's
## tick + input lead, see [method _record_and_send_inputs].
## [br]2. [b]Apply inputs[/b], on the host only: for every InputSender, the
## inputs of the current tick are applied, and
## [signal InputSender.input_applied] is emitted. If the inputs of the tick
## didn't arrive, they're predicted, see [InputSender].
## [br][br]
## Example, on the host at tick 100, with a client stamping 5 ticks ahead:
## [codeblock]
## after_tick 100 | host's own inputs recorded and stamped 100
##                | inputs of 100 applied for every InputSender, the
##                | client's were stamped 100 when it was at tick 95
##                | input_applied(100, false) emitted
## after that     | StateSynchronizers record the result as tick 101
## [/codeblock]
## Inputs that arrive after the host applied their tick are never applied, the
## host already predicted them, and doesn't change the past.

static var _logger := NetfoxLogger._for_netfox("InputSenderServer")

var _history_server : NetworkHistoryServer = null
var _synchronization_server : NetworkSynchronizationServer = null

# A lead change skips at most this many stamps. A bigger jump means time
# jumped forward, e.g. after a pause, and the skipped stamps aren't filled.
const MAX_FILLED_STAMPS := 4

# Latest tick our own inputs were recorded under, -1 if nothing recorded yet.
# Inputs are stamped with tick + input lead, see _SimulatorTimeTracker.
var _last_recorded_tick : int = -1

# Inputs held back for a tick because the input lead shrank, see
# _record_and_send_inputs. Maps InputSender -> input Dictionary.
var _held_inputs : Dictionary = {}

# Every registered InputSender.
var _input_senders : Array[InputSender] = []

func _init(p_history_server: _NetworkHistoryServer = null, p_synchronization_server: _NetworkSynchronizationServer = null):
	_history_server = p_history_server
	_synchronization_server = p_synchronization_server

func _ready():
	# Ensure dependencies
	if not _history_server: _history_server = NetworkHistoryServer
	if not _synchronization_server: _synchronization_server = NetworkSynchronizationServer

	# Inputs are recorded after every tick, the same way as for rollback, so
	# users can gather inputs the same way: set the input properties before
	# the tick, e.g. on NetworkTime.before_tick_loop or before_tick.
	#
	# Inputs are applied right after recording them, still on after_tick.
	# This way the host's own inputs of this tick are already recorded, and
	# whatever input_applied handlers change is recorded by StateSynchronizers
	# as the state of tick + 1, which happens after after_tick.
	NetworkTime.after_tick.connect(_after_tick)

	# Ticks start over when NetworkTime starts, so do the stamps.
	NetworkTime.after_sync.connect(_reset_stamps)

func _after_tick(_delta: float, tick: int) -> void:
	_record_and_send_inputs(tick)

	if multiplayer.is_server():
		_apply_inputs(tick)

# Host side. Applies the inputs of the given tick for every InputSender, and
# emits input_applied. Inputs are read from each player's own history, so
# nothing another player sends can affect it. Missing inputs are predicted
# from the latest ones before the tick, see InputSender.
#
# InputSenders with nothing connected to input_applied are skipped, there's
# nothing to apply the inputs for. This is checked every tick, so connecting
# at any time works from the next tick on.
func _apply_inputs(tick: int) -> void:
	for input_sender in _input_senders:
		if input_sender.input_applied.get_connections().is_empty():
			continue

		var input_subjects := input_sender._input_properties.get_subjects()
		var latest_input_tick := _history_server.get_latest_input_sender_for(input_subjects, tick)
		var is_predicted := latest_input_tick != tick

		# Save the input properties, so the inputs gathered on this peer are
		# untouched by what we apply here.
		input_sender._save_properties()

		# Apply the inputs of this tick, or the latest ones before it. If the
		# player has no inputs at all yet, e.g. it just spawned, apply its
		# default input, the same as SimulatorServer does.
		if latest_input_tick < 0:
			input_sender._set_input(input_sender._default_input)
		else:
			_history_server._restore_input_sender_subjects(input_subjects, tick)
		if is_predicted:
			input_sender._set_input(input_sender._get_predicted_input(input_sender._get_input()))

		input_sender.input_applied.emit(tick, is_predicted)

		input_sender._restore_properties()

# Records our own inputs and sends them to the host. Called after every tick.
#
# Host: the lead is always 0, so the input gathered on tick T is stamped T.
# Ticks go up by one, so every tick gets a new stamp, and none of the lead
# handling below happens. The only exception is a pause, where time jumps.
#
# Client: the input gathered on tick T is stamped T + lead, so it reaches the
# host before the host simulates that tick, see _SimulatorTimeTracker. While
# the lead stays the same, stamps go up by one every tick, just like ticks:
#
#   tick | lead | stamp | sent
#   100  | 5    | 105   | input of 100
#   101  | 5    | 106   | input of 101
#
# Lead grows (5 -> 6): tick 102 is stamped 108, so stamp 107 gets no input.
# The host needs an input for every tick it simulates, so 107 gets an input
# predicted from 106, then 108 gets the input of tick 102:
#
#   tick | lead | stamp | sent
#   102  | 6    | 108   | predicted input under 107, input of 102 under 108
#
# Lead shrinks (6 -> 5): tick 201 was stamped 207, and tick 202 would be
# stamped 207 too. What to do with the input of tick 202?
# - Send it under 207: no, 207 was already sent, and the host never lets a
#   client change an input it already has (cheating).
# - Send it under 208: no, tick 203 is stamped 208, so the clash just moves
#   to the next tick, and the next, forever.
# - Drop it: no, it may contain e.g. a fire press, which would be lost.
# A smaller lead means one stamp less, so two gathered inputs have to share
# one stamp. So we hold the input of tick 202 back, send nothing on this tick,
# and on the next tick send it merged with the input of tick 203 under 208:
#
#   tick | lead | stamp | sent
#   201  | 6    | 207   | input of 201
#   202  | 5    | 207   | nothing, input of 202 held back
#   203  | 5    | 208   | input of 202 merged with input of 203
#
# The lead changes by at most 1 tick per second, so this is rare. Predicting
# and merging is done by InputSender, so users can customize it.
func _record_and_send_inputs(tick: int) -> void:
	var stamped_tick := tick + SimulatorServer._get_input_lead()

	if _last_recorded_tick < 0:
		# First input, nothing to continue from
		_record_inputs(stamped_tick)
		return

	var next_tick := _last_recorded_tick + 1
	var skipped := stamped_tick - next_tick

	if skipped == 0:
		# Lead didn't change
		_record_inputs(stamped_tick)
	elif skipped == -1:
		# Lead shrank, this stamp is taken already. Hold this input back, and
		# merge it into the next one.
		_hold_inputs()
	elif skipped < -1:
		# Ticks went backwards, which only happens when NetworkTime restarts,
		# and we reset on that. Don't hold inputs forever, start over.
		_logger.warning(
			"Input stamp went back from @%d to @%d, starting over",
			[_last_recorded_tick, stamped_tick])
		_held_inputs.clear()
		_record_inputs(stamped_tick)
	elif skipped > MAX_FILLED_STAMPS:
		# Time jumped forward, e.g. after a pause, there's nothing to fill.
		_logger.debug(
			"Input stamp jumped from @%d to @%d, not filling",
			[_last_recorded_tick, stamped_tick])
		_record_inputs(stamped_tick)
	else:
		# Lead grew, fill the skipped stamps with predicted inputs
		_record_predicted_inputs(next_tick, stamped_tick)
		_record_inputs(stamped_tick)

# Records and sends the gathered inputs under the given stamp. If any inputs
# were held back, they're merged into the gathered ones first.
func _record_inputs(stamped_tick: int) -> void:
	if _held_inputs.is_empty():
		_record_and_send(stamped_tick)
	else:
		# InputSender -> input Dictionary
		var merged_inputs : Dictionary = {}
		for input_sender in _held_inputs:
			if is_instance_valid(input_sender):
				merged_inputs[input_sender] = input_sender._get_merged_input(
					_held_inputs[input_sender], input_sender._get_input())
		_held_inputs.clear()

		_record_and_send_with(stamped_tick, merged_inputs)

# Records and sends predicted inputs under the stamps from from_tick to
# to_tick (exclusive). All of them are predicted from the inputs recorded under
# the stamp before from_tick, same as the host does for missing inputs.
func _record_predicted_inputs(from_tick: int, to_tick: int) -> void:
	# InputSender -> input Dictionary
	var predicted_inputs : Dictionary = {}

	for input_sender in _get_local_input_senders():
		# Apply the inputs recorded under the previous stamp to read them
		input_sender._save_properties()
		_history_server._restore_input_sender_subjects(
			input_sender._input_properties.get_subjects(), from_tick - 1)
		var last := input_sender._get_input()
		input_sender._restore_properties()

		predicted_inputs[input_sender] = input_sender._get_predicted_input(last)

	for stamped_tick in range(from_tick, to_tick):
		_record_and_send_with(stamped_tick, predicted_inputs)

# Holds back the gathered inputs, to be merged into the next ones.
func _hold_inputs() -> void:
	for input_sender in _get_local_input_senders():
		if _held_inputs.has(input_sender):
			# Already holding one, shouldn't happen since the lead changes
			# rarely. Merge, so nothing is lost.
			_held_inputs[input_sender] = input_sender._get_merged_input(
				_held_inputs[input_sender], input_sender._get_input())
		else:
			_held_inputs[input_sender] = input_sender._get_input()

# Applies the given inputs, records and sends them under the given stamp, then
# puts back the gathered inputs, so input scripts find them as they left them.
# inputs maps InputSender -> input Dictionary.
func _record_and_send_with(stamped_tick: int, inputs: Dictionary) -> void:
	for input_sender: InputSender in inputs:
		input_sender._save_properties()
		input_sender._set_input(inputs[input_sender] as Dictionary)

	_record_and_send(stamped_tick)

	for input_sender: InputSender in inputs:
		input_sender._restore_properties()

func _record_and_send(stamped_tick: int) -> void:
	_history_server._record_input_sender(stamped_tick)
	_synchronization_server._synchronize_input_sender(stamped_tick)
	_last_recorded_tick = stamped_tick

# InputSenders whose inputs we gather and send.
func _get_local_input_senders() -> Array[InputSender]:
	var result : Array[InputSender] = []
	for input_sender in _input_senders:
		if input_sender.has_authority_over_input_nodes():
			result.push_back(input_sender)
	return result

func _reset_stamps() -> void:
	_last_recorded_tick = -1
	_held_inputs.clear()

func _register_input_sender(input_sender : InputSender) -> void:
	if not _input_senders.has(input_sender):
		_input_senders.push_back(input_sender)

func _deregister_input_sender(input_sender : InputSender) -> void:
	_input_senders.erase(input_sender)
	_held_inputs.erase(input_sender)
