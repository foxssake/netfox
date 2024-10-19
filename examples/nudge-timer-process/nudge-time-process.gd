extends Node

const CLOCK_SAMPLES = 8
const APPROACH_STEPS = 8
const PANIC_THRESHOLD_SECONDS = 2.

class TimeSample:
	var ping_sent: float
	var ping_received: float
	var pong_sent: float
	var pong_received: float
	
	func get_rtt() -> float:
		return pong_received - ping_sent
	
	func get_offset() -> float:
		# See: https://datatracker.ietf.org/doc/html/rfc5905#section-8
		# See: https://support.huawei.com/enterprise/en/doc/EDOC1100278232/729da750/ntp-fundamentals
		return ((ping_received - ping_sent) + (pong_sent - pong_received)) / 2.

class SystemClock:
	var offset: float = 0.
	
	func get_raw_time() -> float:
		return Time.get_unix_time_from_system()
	
	func get_time() -> float:
		return get_raw_time() + offset
	
	func adjust(p_offset: float):
		offset += p_offset
	
	func set_time(p_time: float):
		offset = p_time - get_raw_time()

class SteppingClock:
	var time: float = 0.
	
	func get_raw_time() -> float:
		return time
		
	func get_time() -> float:
		return time
	
	func adjust(p_offset: float):
		time += p_offset
	
	func set_time(p_time: float):
		time = p_time

@export var sample_interval_seconds = .2

var logger = _NetfoxLogger.new("ntp", "ntp")
var samples = {}
var sample_buffer = [] # TODO: Ring buffer
var clock = SystemClock.new()
var first_approach = true

func _ready():
	clock.set_time(0.)
	
	NetworkEvents.on_peer_join.connect(func(id):
		if multiplayer.is_server():
			_send_initial_timestamp.rpc_id(id, clock.get_time())
	)

func _loop():
	logger.info("NTP loop started! Initial timestamp: %s" % [clock.get_time()])

	var sample_idx = 0
	
	while true:
		var sample = TimeSample.new()
		samples[sample_idx] = sample
		
		sample.ping_sent = clock.get_time()
		_send_ping.rpc_id(1, sample_idx)
		
		sample_idx += 1
		
		await get_tree().create_timer(sample_interval_seconds).timeout

func _discipline_clock():
	# https://datatracker.ietf.org/doc/html/rfc5905#section-10
	var clock_samples = sample_buffer.duplicate()
	clock_samples.sort_custom(func(a: TimeSample, b: TimeSample): return a.get_rtt() < b.get_rtt())
	
	var offsets = clock_samples.map(func(it: TimeSample): return it.get_offset())
	
	var offset = 0.
	var offset_weight = 0.
	for i in range(offsets.size()):
		var w = pow(2, -i)
		offset += offsets[i] * w
		offset_weight += w
	offset /= offset_weight
	
	if abs(offset) > PANIC_THRESHOLD_SECONDS:
		logger.error("Offset %ss is above panic threshold %s!" % [offset, PANIC_THRESHOLD_SECONDS])
		clock.adjust(offset)
		sample_buffer.clear()
	else:
		clock.adjust(offset / APPROACH_STEPS)
		logger.info("Adjusted clock, offset: %sms, new time: %ss" % [offset * 1000., clock.get_time()])

@rpc("any_peer", "call_remote", "reliable")
func _send_initial_timestamp(timestamp: float):
	clock.set_time(timestamp)
	logger.info("Received initial timestamp: %s" % [timestamp])
	_loop()

@rpc("any_peer", "call_remote", "unreliable")
func _send_ping(idx: int):
	var ping_received = clock.get_time()
	var sender = multiplayer.get_remote_sender_id()
	
	_send_pong.rpc_id(sender, idx, ping_received, clock.get_time())

@rpc("any_peer", "call_remote", "unreliable")
func _send_pong(idx: int, ping_received: float, pong_sent: float):
	var pong_received = clock.get_time()
	
	var sample = samples[idx] as TimeSample
	sample.ping_received = ping_received
	sample.pong_sent = pong_sent
	sample.pong_received = pong_received
	
	logger.info("Received sample: t1=%s; t2=%s; t3=%s; t4=%s; theta=%sms; delta=%sms" % [
		sample.ping_sent, sample.ping_received, sample.pong_sent, sample.pong_received,
		sample.get_offset() * 1000., sample.get_rtt() * 1000.
	])
	
	# Once a sample is done, remove from in-flight samples and move to sample buffer
	samples.erase(idx)
	sample_buffer.append(sample)
	if sample_buffer.size() > CLOCK_SAMPLES:
		sample_buffer.pop_front()
		
	_discipline_clock()
