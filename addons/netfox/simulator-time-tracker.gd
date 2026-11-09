extends RefCounted
class_name _SimulatorTimeTracker

## Helper class for keeping track of how each client's time relates to the
## host's: the [b]input lead[/b] and the [b]view delay[/b].
##
## [b]Time model[/b]: the host's tick is the truth, the host simulates everyone
## at its current tick. Clients stamp their inputs some ticks ahead of their
## own tick, so the inputs arrive at the host before the host needs them. How
## far ahead is the input lead.
## [br][br]
## [b]Input lead[/b] is computed by each client on its own, from the round
## trip time measured by time synchronization:
## [codeblock]
## lead = ceil((rtt / 2 + rtt_jitter + margin) / ticktime)
## [/codeblock]
## where margin is [code]netfox/simulator/input_lead_margin[/code], in
## seconds. Clients with a good connection get a small lead, clients with a bad
## connection a big one, each only pays for its own connection. The host's own
## inputs need no lead, so it is always 0 on the host.
## [br][br]
## [b]Maximum lead[/b]: the lead never goes above
## [code]netfox/simulator/max_input_lead[/code]. Clients with an even worse
## connection still play, but their inputs may arrive late, and the host
## predicts them. The host drops inputs stamped further ahead than the maximum
## lead plus [constant INPUT_TICK_TOLERANCE], see
## [method is_input_tick_accepted]. Without that, a single input stamped far
## in the future would push everyone's inputs out of the history buffers.
## Example, with 64 ticks of history:
## [codeblock]
## host tick                        | 1000
## input arrives stamped            | 1100
## per tick input buffer now holds  | 1037 .. 1100
## host needs the inputs of 1000    | gone from the buffer, for every player
## [/codeblock]
## [b]History size[/b]: inputs and predicted states are kept for ticks in the
## future too, so the InputSender and Simulator history buffers hold
## [code]history_limit[/code] ticks of the past, plus room for the future, see
## [method get_future_history_ticks]. Example with the defaults, 64 ticks of
## past and 1 second of maximum lead at 30 ticks per second:
## [codeblock]
## room for the future | 30 + 2 (tolerance) = 32 ticks
## buffer size         | 64 + 32 = 96 ticks
## host tick           | 1000
## stamps accepted     | up to 1032
## past always kept    | 937 .. 1000, whatever honest clients stamp
## [/codeblock]
## [br]
## The lead is set once time synchronization is done, then moves by at most 1
## tick every [constant LEAD_CHANGE_INTERVAL] seconds. No input is lost or
## sent twice when it changes, see [_InputSenderServer]:
## [br]- growing by 1 skips a stamp, which is filled with a predicted input,
## see [code]_predict_input[/code] in [InputSender].
## [br]- shrinking by 1 would stamp two inputs with the same tick, so the
## second one is held for a tick and merged into the next one, see
## [code]_merge_input[/code] in [InputSender].
## [br][br]
## [b]View delay[/b] is the number of ticks between the tick a client stamps
## its inputs with ([code]tick + lead[/code]) and the tick of the host's
## simulation that the client is seeing. When a client fires an input stamped
## [code]t[/code], it was seeing the host's simulation at tick
## [code]t - view_delay[/code]. [_SimulatorServer] uses this to find the tick
## to rewind to when registering projectiles.
## [br][br]
## [b]Why the lead is part of the view delay[/b]: the host only knows the
## stamped tick of a fire input, so the view delay has to use the same
## numbers. Example, with a lead of 5:
## [codeblock]
## client tick when firing      | 100
## newest state the client sees | 97
## fire input stamped           | 100 + 5 = 105
## view delay without lead      | 100 - 97 = 3  -> host rewinds to 102, wrong
## view delay with lead         | 105 - 97 = 8  -> host rewinds to 97, right
## [/codeblock]
## [br]
## [b]Measuring[/b]: clients measure their view delay every time a simulator
## state arrives from the host, as [code]current tick - state tick[/code], and
## keep that value until the next state arrives. The lead is added when the
## sample is sent. Full states arrive at least every
## [code]netfox/simulator/full_state_interval[/code] ticks, which keeps the
## measurement fresh.
## [br][br]
## [b]Why on arrival[/b]: with diff states, the host sends nothing while
## nothing changes. Computing [code]current tick - newest received tick[/code]
## every tick instead would keep growing in that case, even though the client
## still sees an up to date world. Example, with a real view delay of 10 ticks
## and nothing changing after tick 100:
## [codeblock]
## client tick | arrives            | every tick | on arrival
## 110         | state for tick 100 | 10         | 10
## 120         | nothing            | 20         | 10
## 130         | nothing            | 30         | 10
## 134         | full state for 124 | 10         | 10
## [/codeblock]
## If the client fires at tick 130, it sees the world as it is at tick 120,
## since nothing changed between 100 and 120. With 30, the host would start the
## projectile at tick 100 and step it 20 ticks too many, so it ends up further
## along its path than where the client fired it. With 10, it starts at 120.
## [br][br]
## The downside is lag spikes: if states are stuck on the network instead,
## the client can't tell that apart from "nothing changed", see the TODO below.
## [br][br]
## [b]Sending[/b]: clients send [code](stamped tick, view delay)[/code]
## samples to the host, 6 bytes each, on an unreliable command. To keep traffic
## low, a sample is sent:
## [br]- periodically, every
## [code]netfox/simulator/view_delay_send_interval[/code] seconds, and
## [br]- immediately, if the view delay changed by at least
## [code]netfox/simulator/view_delay_change_threshold[/code] seconds since the
## last sample sent.
## [br]Changes smaller than that are just network jitter, and are picked up by
## the next periodic sample. A lost sample is fine too, the next one replaces it.
## [br]Both settings are in seconds, so they behave the same at any tick rate.
## They're converted to ticks with the current tick rate every time they're
## used, so they follow the tick rate even if a client adjusts its tick rate
## to the host's, see [code]netfox/time/tickrate_mismatch_action[/code].
## [br][br]
## [b]Storing[/b]: the host keeps a per peer history of samples, mapping
## stamped ticks to view delays. This way every projectile is matched with the
## view delay at the tick it was fired, even if fire events from different
## ticks arrive at the same time, e.g. after a lag spike. Samples are kept in
## buffers as big as the Simulator history, older ones are dropped
## automatically. Samples stamped too far ahead are ignored, same as inputs.
## [br][br]
## Used by [_SimulatorServer] internally.

# TODO: Detect lag spikes? During a spike we should use
# current tick - newest received tick as view delay instead?

## The input lead moves by at most 1 tick this often, in seconds, see the
## class description.
const LEAD_CHANGE_INTERVAL := 1.0

## Clients' ticks follow the host's only as close as time synchronization
## gets them. The host accepts inputs stamped this many ticks past the maximum
## lead, so honest clients are never dropped for a tick of clock difference.
## This also covers a client's predicted state, which is one tick past its
## newest input, see [_SimulatorServer].
const INPUT_TICK_TOLERANCE := 2

var _owner: Node = null
var _cmd_view_delay: _NetworkCommandServer.Command = null
var _history_size: int = 64
var _logger := NetfoxLogger._for_netfox("SimulatorTimeTracker")

# Settings in seconds, set in initialize(). They're converted to ticks when
# used, see the class description.
var _input_lead_margin : float = 0.1
var _max_input_lead : float = 1.0
var _view_delay_send_interval : float = 0.25
var _view_delay_change_threshold : float = 0.06

# Room for the future in the history buffers, set in initialize(). Same value
# the history buffers were created with, see get_future_history_ticks().
var _future_history_ticks : int = 32

# Client side: current input lead in ticks, 0 until round trip time is known
var _input_lead : int = 0

# Client side: whether the lead jumped to its first target yet
var _has_input_lead : bool = false

# Client side: tick of the last lead change, -1 if never changed
var _last_lead_change_tick : int = -1

# Client side: latest measured view delay, before adding the lead. Can be -1
# on very low latency, see _on_simulator_state. Only valid once a state was
# received, see _latest_received_tick.
var _local_view_delay: int = 0

# Client side: newest simulator state tick received from the host, -1 if
# nothing received yet
var _latest_received_tick: int = -1

# Client side: last sample sent, -1 if nothing sent yet
var _last_sent_tick: int = -1
var _last_sent_view_delay: int = -1

# Host side: peer id (int) -> _HistoryBuffer of stamped tick -> view delay
var _view_delay_histories: Dictionary = {}

## Initialize needs to be called by the owner node, from its _ready().
## Commands must be registered in the same order on every peer, which is
## guaranteed for autoloads.
## [br][br]
## [param history_size] is the size of the view delay sample buffers, the same
## as the Simulator history buffers, including the room for the future.
func initialize(owner: Node, command_server: _NetworkCommandServer, synchronization_server: _NetworkSynchronizationServer, history_size: int) -> void:
	_owner = owner
	_history_size = history_size

	_input_lead_margin = ProjectSettings.get_setting("netfox/simulator/input_lead_margin", 0.1) as float
	_max_input_lead = ProjectSettings.get_setting("netfox/simulator/max_input_lead", 1.0) as float
	_view_delay_send_interval = ProjectSettings.get_setting("netfox/simulator/view_delay_send_interval", 0.25) as float
	_view_delay_change_threshold = ProjectSettings.get_setting("netfox/simulator/view_delay_change_threshold", 0.06) as float
	_future_history_ticks = get_future_history_ticks()

	_cmd_view_delay = command_server.register_command(_handle_view_delay, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)

	synchronization_server._on_simulator.connect(_on_simulator_state)
	NetworkTime.after_sync.connect(_on_after_sync)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

	owner.multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	owner.multiplayer.connected_to_server.connect(_reset_client)
	owner.multiplayer.server_disconnected.connect(_reset_client)

## Returns how many ticks the InputSender and Simulator history buffers keep
## for the future, on top of [code]history_limit[/code] ticks of the past:
## [code]netfox/simulator/max_input_lead[/code] in ticks, plus
## [constant INPUT_TICK_TOLERANCE].
## [br][br]
## Static, so NetworkHistoryServer can size its buffers before
## [_SimulatorServer] exists. Uses the tick rate at the time it's called.
## Buffers are created at startup, before any tick rate adjustment.
static func get_future_history_ticks() -> int:
	var max_input_lead := ProjectSettings.get_setting("netfox/simulator/max_input_lead", 1.0) as float
	return maxi(0, ceili(max_input_lead / NetworkTime.ticktime)) + INPUT_TICK_TOLERANCE

## Returns the maximum input lead in ticks, see the class description.
## [br][br]
## Converted with the current tick rate. If the tick rate went up since the
## history buffers were created, e.g. a client adjusted to a faster host, the
## same seconds would be more ticks than the buffers have room for. So it's
## capped to the room the buffers have.
func get_max_input_lead_ticks() -> int:
	var max_ticks := maxi(0, ceili(_max_input_lead / NetworkTime.ticktime))
	return mini(max_ticks, _future_history_ticks - INPUT_TICK_TOLERANCE)

## Returns whether an input stamped [param stamped_tick] is accepted, when our
## current tick is [param current_tick]. Inputs stamped further ahead than the
## maximum lead are not, see the class description.
func is_input_tick_accepted(stamped_tick: int, current_tick: int) -> bool:
	return stamped_tick <= current_tick + get_max_input_lead_ticks() + INPUT_TICK_TOLERANCE

## Returns how many ticks ahead this peer stamps its inputs. Always 0 on the
## host. Only changes between tick loops, so it's the same for a whole loop.
func get_input_lead() -> int:
	if _owner.multiplayer.is_server():
		return 0
	return _input_lead

## Returns the view delay [param peer] had at [param tick], or [param default]
## if there's no sample for it, e.g. the peer hasn't reported yet, or
## [param tick] is older than the history.
## [br][br]
## [param tick] is a tick stamped by the peer, e.g. the tick of its fire input.
func get_view_delay(peer: int, tick: int, default: int) -> int:
	var history := _view_delay_histories.get(peer) as _HistoryBuffer
	if history == null:
		return default

	var view_delay: Variant = history.get_latest_at(tick)
	if view_delay == null:
		return default

	return view_delay as int

## Client side: returns the view delay this client reports to the host, lead
## included, or -1 if no simulator state arrived yet. Same value as the next
## sample sent, see [method _send_view_delay].
func get_reported_view_delay() -> int:
	if _latest_received_tick < 0:
		return -1
	return maxi(0, _local_view_delay + _input_lead)

## Host side: returns the newest view delay [param peer] reported, or -1 if it
## hasn't reported yet. Not clamped to [code]max_view_delay_ticks[/code].
func get_latest_view_delay(peer: int) -> int:
	var newest_accepted_tick := NetworkTime.tick + get_max_input_lead_ticks() + INPUT_TICK_TOLERANCE
	return get_view_delay(peer, newest_accepted_tick, -1)

# Client side, called for every simulator state received from the host.
func _on_simulator_state(snapshot: _Snapshot) -> void:
	# Ignore states arriving out of order, the client already sees a newer one
	if snapshot.tick < _latest_received_tick:
		return

	# The host sends the state after its tick T as T + 1. On very low latency,
	# e.g. LAN, it can arrive while we're still at tick T, so this can be -1.
	# Don't clamp it here, the lead is added when sending, and the sum is
	# clamped there.
	_latest_received_tick = snapshot.tick
	_local_view_delay = NetworkTime.tick - snapshot.tick

# Client side, called when NetworkTime starts ticking. Round trip time is known
# by then, so the lead is set before the first input is stamped.
func _on_after_sync() -> void:
	_input_lead = 0
	_has_input_lead = false
	_last_lead_change_tick = -1

	if _is_connected_client():
		_update_input_lead()

# Client side, called after every tick loop. The lead is updated here, so it
# stays the same for a whole tick loop.
func _after_tick_loop() -> void:
	if not _is_connected_client():
		return

	_update_input_lead()
	_send_view_delay()

# Client side, moves the input lead towards its target, see class description.
func _update_input_lead() -> void:
	if not NetworkTime.is_initial_sync_done():
		# Round trip time not measured yet
		return

	var rtt := NetworkTimeSynchronizer.rtt
	var one_way := rtt / 2.0 + NetworkTimeSynchronizer.rtt_jitter + _input_lead_margin
	var target := mini(ceili(one_way / NetworkTime.ticktime), get_max_input_lead_ticks())

	if not _has_input_lead:
		# First measurement, jump straight to it
		_input_lead = target
		_has_input_lead = true
		_last_lead_change_tick = NetworkTime.tick
		_logger.debug("Input lead set to %d ticks", [_input_lead])
		return

	if target == _input_lead:
		return

	var lead_change_interval_ticks := maxi(1, ceili(LEAD_CHANGE_INTERVAL / NetworkTime.ticktime))
	if NetworkTime.tick - _last_lead_change_tick < lead_change_interval_ticks:
		return

	_input_lead += signi(target - _input_lead)
	_last_lead_change_tick = NetworkTime.tick
	_logger.debug("Input lead changed to %d ticks, target %d", [_input_lead, target])

# Client side, sends a sample if it's time for a periodic one, or if the view
# delay changed enough, see netfox/simulator/view_delay_change_threshold.
func _send_view_delay() -> void:
	if _latest_received_tick < 0:
		# Nothing measured yet
		return

	# This is the tick whose inputs are gathered next, so a fire input made
	# right after this gets this tick stamped with the lead. Both the tick and
	# the view delay are in stamped tick numbers, see class description.
	var tick := NetworkTime.tick + _input_lead
	var view_delay := maxi(0, _local_view_delay + _input_lead)

	# At least 1 tick, in case the interval is shorter than a tick
	var send_interval_ticks := maxi(1, ceili(_view_delay_send_interval / NetworkTime.ticktime))
	# At least 2 ticks, so +/- 1 tick of jitter never counts as a change
	var change_threshold_ticks := maxi(2, ceili(_view_delay_change_threshold / NetworkTime.ticktime))

	var is_periodic := _last_sent_tick < 0 or tick - _last_sent_tick >= send_interval_ticks
	var has_changed := absi(view_delay - _last_sent_view_delay) >= change_threshold_ticks
	if not is_periodic and not has_changed:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.put_u32(tick)
	buffer.put_u16(mini(view_delay, 0xFFFF))
	_cmd_view_delay.send(buffer.data_array, MultiplayerPeer.TARGET_PEER_SERVER)

	_last_sent_tick = tick
	_last_sent_view_delay = view_delay

func _is_connected_client() -> bool:
	var multiplayer := _owner.multiplayer
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		return false

	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

# Host side, stores a sample reported by a client.
func _handle_view_delay(sender: int, data: PackedByteArray) -> void:
	if not _owner.multiplayer.is_server():
		return

	if data.size() != 6:
		_logger.warning("Received malformed view delay from peer #%d, ignoring", [sender])
		return

	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	var tick := buffer.get_u32()
	var view_delay := buffer.get_u16()

	# A sample stamped far ahead would wipe this peer's own samples, same as
	# inputs would, see is_input_tick_accepted()
	if not is_input_tick_accepted(tick, NetworkTime.tick):
		_logger.warning(
			"Dropping view delay from peer #%d stamped @%d, too far ahead of @%d",
			[sender, tick, NetworkTime.tick])
		return

	# Ticks older than the history size are dropped by the buffer itself
	var history := _view_delay_histories.get(sender) as _HistoryBuffer
	if history == null:
		history = _HistoryBuffer.new(_history_size)
		_view_delay_histories[sender] = history

	history.set_at(tick, view_delay)

func _on_peer_disconnected(peer: int) -> void:
	_view_delay_histories.erase(peer)

# Client side, start measuring from scratch on every new connection.
func _reset_client() -> void:
	_local_view_delay = 0
	_latest_received_tick = -1
	_input_lead = 0
	_has_input_lead = false
	_last_lead_change_tick = -1
	_last_sent_tick = -1
	_last_sent_view_delay = -1
