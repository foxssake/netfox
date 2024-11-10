extends Node
class_name _NetworkTimeSynchronizer

## Continuously synchronizes time to the host's remote clock.
##
## Make sure to read the [i]NetworkTimeSynchronizer Guide[/i] to understand the
## different clocks that the class docs refer to.
## 
## @tutorial(NetworkTimeSynchronizer Guide): https://foxssake.github.io/netfox/netfox/guides/network-time-synchronizer/

## The minimum time in seconds between two sync samples.
## 
## See [member sync_interval]
const MIN_SYNC_INTERVAL := 0.1

## Time between sync samples, in seconds.
## Cannot be less than [member MIN_SYNC_INTERVAL]
## [br][br]
## [i]read-only[/i], you can change this in the Netfox project settings
var sync_interval: float:
	get:
		return maxf(
			ProjectSettings.get_setting("netfox/time/sync_interval", 0.25),
			MIN_SYNC_INTERVAL
		)
	set(v):
		push_error("Trying to set read-only variable sync_interval")

## Number of measurements ( samples ) to use for time synchronization.
## [br][br]
## [i]read-only[/i], you can change this in the Netfox project settings
var sync_samples: int:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_samples", 8)
	set(v):
		push_error("Trying to set read-only variable sync_samples")

## Number of iterations to nudge towards the host's remote clock.
##
## Lower values result in more aggressive changes in clock and may be more 
## sensitive to jitter. Larger values may end up approaching the remote clock
## too slowly.
## [br][br]
## [i]read-only[/i], you can change this in the Netfox project settings
var adjust_steps: int:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_adjust_steps", 8)
	set(v):
		push_error("Trying to set read-only variable adjust_steps")

## Largest tolerated offset from the host's remote clock before panicking.
##
## Once this threshold is reached, the clock will be reset to the remote clock's 
## value, and the nudge process will start from scratch.
## [br][br]
## [i]read-only[/i], you can change this in the Netfox project settings
var panic_threshold: float:
	get:
		return ProjectSettings.get_setting("netfox/time/recalibrate_threshold", 2.)
	set(v):
		push_error("Trying to set read-only variable panic_threshold")

## Measured roundtrip time measured to the host.
##
## This value is calculated from multiple samples. The actual roundtrip times 
## can be anywhere in the [member rtt] +/- [member rtt_jitter] range.
## [br][br]
## [i]read-only[/i]
var rtt: float:
	get:
		return _rtt
	set(v):
		push_error("Trying to set read-only variable rtt")

## Measured jitter in the roundtrip time to the host remote.
##
## This value is calculated from multiple samples. The actual roundtrip times 
## can be anywhere in the [member rtt] +/- [member rtt_jitter] range.
## [br][br]
## [i]read-only[/i]
var rtt_jitter: float:
	get:
		return _rtt_jitter
	set(v):
		push_error("Trying to set read-only variable rtt_jitter")

## Estimated offset from the host's remote clock.
##
## Positive values mean that the host's remote clock is ahead of ours, while
## negative values mean that our clock is behind the host's remote.
## [br][br]
## [i]read-only[/i]
var remote_offset: float:
	get:
		return _offset
	set(v):
		push_error("Trying to set read-only variable remote_offset")

var _active: bool = false
static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("NetworkTimeSynchronizer")

# Samples are stored in a ring buffer
var _sample_buffer: _RingBuffer
var _sample_idx: int = 0
var _awaiting_samples: Dictionary = {}

var _clock: NetworkClocks.SystemClock = NetworkClocks.SystemClock.new()
var _offset: float = 0.
var _rtt: float = 0.
var _rtt_jitter: float = 0.

## Emitted after the initial time sync.
##
## At the start of the game, clients request an initial timestamp to kickstart 
## their time sync loop. This event is emitted once that initial timestamp is 
## received.
signal on_initial_sync()

## Emitted when clocks get overly out of sync and a time sync panic occurs.
##
## Panic means that the difference between clocks is too large. The time sync 
## will reset the clock to the remote clock's time and restart the time sync loop 
## from there. 
## [br][br]
## Use this event in case you need to react to clock changes in your game.
signal on_panic(offset: float)

## Start the time synchronization loop.
##
## Starting multiple times has no effect.
func start():
	if _active:
		return
		
	_clock.set_time(0.)

	if not multiplayer.is_server():
		_active = true
		_sample_idx = 0
		_sample_buffer = _RingBuffer.new(sync_samples)
		
		_request_timestamp.rpc_id(1)

## Stop the time synchronization loop.
func stop():
	_active = false

## Get the current time from the reference clock.
##
## Returns a timestamp in seconds, with a fractional part for extra precision.
func get_time() -> float:
	return _clock.get_time()

func _loop():
	_logger.info("Time sync loop started! Initial timestamp: %ss" % [_clock.get_time()])
	on_initial_sync.emit()

	while _active:
		var sample = NetworkClockSample.new()
		_awaiting_samples[_sample_idx] = sample
		
		sample.ping_sent = _clock.get_time()
		_send_ping.rpc_id(1, _sample_idx)
		
		_sample_idx += 1
		
		await get_tree().create_timer(sync_interval).timeout

func _discipline_clock():
	var sorted_samples := _sample_buffer.get_data()
	
	# Sort samples by latency
	sorted_samples.sort_custom(
		func(a: NetworkClockSample, b: NetworkClockSample):
			return a.get_rtt() < b.get_rtt()
	)
	
	_logger.trace("Using sorted samples: \n%s" % [
		"\n".join(sorted_samples.map(func(it: NetworkClockSample): return "\t" + it.to_string() + " (%.4fs)" % [get_time() - it.ping_sent]))
	])
	
	# Calculate rtt bounds
	var rtt_min = sorted_samples.front().get_rtt()
	var rtt_max = sorted_samples.back().get_rtt()
	_rtt = (rtt_max + rtt_min) / 2.
	_rtt_jitter = (rtt_max - rtt_min) / 2.
	
	# Calculate offset
	var offset := 0.
	var offsets = sorted_samples.map(func(it): return it.get_offset())
	var offset_weight = 0.
	for i in range(offsets.size()):
		var w = log(1 + sorted_samples[i].get_rtt())
		offset += offsets[i] * w
		offset_weight += w
	
	offset /= offset_weight
	
	# Panic / Adjust
	if abs(offset) > panic_threshold:
		# Reset clock, throw away all samples
		_clock.adjust(offset)
		_sample_buffer.clear()
		
		# Also drop in-flight samples
		_awaiting_samples.clear()
		
		_offset = 0.
		
		_logger.warning("Offset %ss is above panic threshold %ss! Resetting clock" % [offset, panic_threshold])
		on_panic.emit(offset)
	else:
		# Nudge clock towards estimated time
		var nudge := offset / adjust_steps
		_clock.adjust(nudge)
		_logger.trace("Adjusted clock by %.2fms, offset: %.2fms, new time: %.4fss" % [nudge * 1000., offset * 1000., _clock.get_time()])
		
		_offset = offset - nudge

@rpc("any_peer", "call_remote", "unreliable")
func _send_ping(idx: int):
	var ping_received = _clock.get_time()
	var sender = multiplayer.get_remote_sender_id()

	_send_pong.rpc_id(sender, idx, ping_received, _clock.get_time())

@rpc("any_peer", "call_remote", "unreliable")
func _send_pong(idx: int, ping_received: float, pong_sent: float):
	var pong_received = _clock.get_time()
	
	if not _awaiting_samples.has(idx):
		# Sample was dropped mid-flight during a panic episode
		return
	
	var sample = _awaiting_samples[idx] as NetworkClockSample
	sample.ping_received = ping_received
	sample.pong_sent = pong_sent
	sample.pong_received = pong_received
	
	_logger.trace("Received sample: %s" % [sample])
	
	# Once a sample is done, remove from in-flight samples and move to sample buffer
	_awaiting_samples.erase(idx)
	_sample_buffer.push(sample)
	
	# Discipline clock based on new sample
	_discipline_clock()

@rpc("any_peer", "call_remote", "reliable")
func _request_timestamp():
	_logger.debug("Requested initial timestamp @ %.4fs raw time" % [_clock.get_raw_time()])
	_set_timestamp.rpc_id(multiplayer.get_remote_sender_id(), _clock.get_time())

@rpc("any_peer", "call_remote", "reliable")
func _set_timestamp(timestamp: float):
	_logger.debug("Received initial timestamp @ %.4fs raw time" % [_clock.get_raw_time()])
	_clock.set_time(timestamp)
	_loop()
