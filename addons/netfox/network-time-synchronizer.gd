extends Node

## Time between syncs, in seconds.
##
## [i]read-only[/i], you can change this in the Netfox project settings
var sync_interval: float:
	get:
		# return ProjectSettings.get_setting("netfox/time/sync_interval", 0.25)
		return 0.25
	set(v):
		push_error("Trying to set read-only variable sync_interval")

## Number of measurements ( samples ) to take to guess latency.
##
## [i]read-only[/i], you can change this in the Netfox project settings
var sync_samples: int:
	get:
		# return ProjectSettings.get_setting("netfox/time/sync_samples", 8)
		return 8
	set(v):
		push_error("Trying to set read-only variable sync_samples")

# TODO: Doc
var adjust_steps: int:
	get:
		return 8

# TODO: Doc
var panic_threshold: float:
	get:
		return 2.

var _active: bool = false
static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("NTP")

var _sample_buffer: Array[NetworkClockSample] = []
var _sample_buf_size: int = 0
var _sample_idx: int = 0
var _awaiting_samples: Dictionary = {}

var _clock := NetworkClocks.SystemClock.new()

# TODO: Doc
signal on_initial_sync()

## Start the time synchronization loop.
##
## Starting multiple times has no effect.
func start():
	if _active:
		return

	if multiplayer.is_server():
		_clock.set_time(0.)
	else:
		_active = true
		
		_sample_buffer.clear()
		_sample_buffer.resize(sync_samples)
		_sample_buf_size = 0
		_sample_idx = 0
		
		_clock.set_time(0.)
		
		_request_timestamp.rpc_id(1)

## Stop the time synchronization loop.
func stop():
	_active = false

# TODO: Doc
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
	# https://datatracker.ietf.org/doc/html/rfc5905#section-10
	# Sort samples by latency
	var sorted_samples := _sample_buffer.slice(0, _sample_buf_size) as Array[NetworkClockSample]
	sorted_samples.sort_custom(
		func(a: NetworkClockSample, b: NetworkClockSample):
			return a.get_rtt() < b.get_rtt()
	)
	
	var offset = 0.
	var offset_weight = 0.
	for i in range(sorted_samples.size()):
		var w = pow(2, -i)
		offset += sorted_samples[i].get_offset() * w
		offset_weight += w
	offset /= offset_weight
	
	if abs(offset) > panic_threshold:
		# Reset clock, throw away all samples
		_clock.adjust(offset)
		_sample_buffer.fill(null)
		_sample_buf_size = 0
		
		_logger.warning("Offset %ss is above panic threshold %ss! Resetting clock" % [offset, panic_threshold])
	else:
		# Nudge clock towards estimated time
		_clock.adjust(offset / adjust_steps)
		_logger.trace("Adjusted clock, offset: %sms, new time: %ss" % [offset * 1000., _clock.get_time()])

@rpc("any_peer", "call_remote", "unreliable")
func _send_ping(idx: int):
	var ping_received = _clock.get_time()
	var sender = multiplayer.get_remote_sender_id()
	
	_send_pong.rpc_id(sender, idx, ping_received, _clock.get_time())

@rpc("any_peer", "call_remote", "unreliable")
func _send_pong(idx: int, ping_received: float, pong_sent: float):
	var pong_received = _clock.get_time()
	
	var sample = _awaiting_samples[idx] as NetworkClockSample
	sample.ping_received = ping_received
	sample.pong_sent = pong_sent
	sample.pong_received = pong_received
	
	_logger.trace("Received sample: t1=%s; t2=%s; t3=%s; t4=%s; theta=%sms; delta=%sms" % [
		sample.ping_sent, sample.ping_received, sample.pong_sent, sample.pong_received,
		sample.get_offset() * 1000., sample.get_rtt() * 1000.
	])
	
	# Once a sample is done, remove from in-flight samples and move to sample buffer
	_awaiting_samples.erase(idx)
	
	_sample_buffer[_sample_buf_size % _sample_buffer.size()] = sample
	_sample_buf_size += 1
	
	# Discipline clock based on new sample
	_discipline_clock()

@rpc("any_peer", "call_remote", "reliable")
func _request_timestamp():
	_set_timestamp.rpc_id(multiplayer.get_remote_sender_id(), _clock.get_time())

@rpc("any_peer", "call_remote", "reliable")
func _set_timestamp(timestamp: float):
	_clock.set_time(timestamp)
	_loop()
