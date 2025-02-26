extends RefCounted
class_name DiffHistoryEncoder

var full_state_interval: int = 24
var diff_ack_interval: int = 0
var sanitize: bool = true

# TODO: Use PassthroughHistoryEncoder for full states

var _history: _PropertyHistoryBuffer
var _property_cache: PropertyCache

var _ackd_ticks: Dictionary = {}
var _next_full_state_tick: int = -1024
var _next_diff_ack_tick: int = -1024

static var _logger := _NetfoxLogger.for_netfox("DiffHistoryEncoder")

func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache):
	_history = p_history
	_property_cache = p_property_cache

func encode(tick: int, reference_tick: int) -> Dictionary:
	var snapshot := _history.get_snapshot(tick)

	var reference_snapshot := _history.get_history(reference_tick) as _PropertySnapshot
	var diff_snapshot := reference_snapshot.make_patch(snapshot)

	return diff_snapshot.as_dictionary()

func decode(data: Dictionary, sender: int = -1) -> _PropertySnapshot:
	var diff_snapshot := _PropertySnapshot.from_dictionary(data)
	
	if diff_snapshot.is_empty():
		return diff_snapshot
	
	if sanitize and sender > 0:
		diff_snapshot.sanitize(sender, _property_cache)
		if diff_snapshot.is_empty(): return null

	return diff_snapshot

func apply(tick: int, snapshot: _PropertySnapshot):
	_history.merge(snapshot, tick)

func get_ack_type(tick: int, data: Array) -> int:
	return 0

func acknowledge_tick(tick: int, peer: int):
	_ackd_ticks[peer] = tick
