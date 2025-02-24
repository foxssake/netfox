extends RefCounted
class_name RedundancyTransmitter

var redundancy: int = 4:
	get = get_redundancy,
	set = set_redundancy

var is_broadcast: bool = false
var sanitize: bool = false

var _name: String = ""
var _history: _PropertyHistoryBuffer
var _property_cache: PropertyCache

var _logger: _NetfoxLogger

signal on_new_snapshot(tick: int)

func push(tick: int):
	var data := _encode_tick(tick)
	var target_peer := 0 if is_broadcast else 1
	ORPC.rpc(_submit, [tick, data], target_peer, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)

func get_redundancy() -> int:
	return redundancy

func set_redundancy(p_redundancy: int):
	if p_redundancy <= 0:
		_logger.warning(
			"Attempting to set redundancy to %d, which would send no data!", [p_redundancy]
		)
		return

	redundancy = p_redundancy

func _init(p_name: String, p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache):
	_name = p_name
	_history = p_history
	_property_cache = p_property_cache

	_logger = _NetfoxLogger.for_extras("RedundancyTransmitter/" + _name)

	ORPC.register(_submit, _name + "::_submit")

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		ORPC.unregister(_submit)

func _encode_tick(tick: int) -> Array:
	var data : Array[Dictionary] = []
	data.resize(redundancy)

	for i in range(mini(redundancy, _history.size())):
		var offset_tick := tick - i
		data[i] = _history.get_snapshot(offset_tick).as_dictionary()

	return data

func _decode_tick(data: Array) -> Array[_PropertySnapshot]:
	var result: Array[_PropertySnapshot] = []
	result.resize(data.size())

	for i in range(data.size()):
		result[i] = _PropertySnapshot.from_dictionary(data[i])

	return result

func _submit(tick: int, data: Array):
	var snapshots := _decode_tick(data)
	var sender := ORPC.get_remote_sender_id()

	for i in range(snapshots.size()):
		var offset_tick := tick - i
		var snapshot := snapshots[i]

		if offset_tick < NetworkRollback.history_start:
			# Data too old
			_logger.warning(
				"Received data for %s, rejecting because older than %s frames",
				[offset_tick, NetworkRollback.history_limit]
			)

		if sanitize:
			snapshot.sanitize(sender, _property_cache)

		if snapshot.is_empty():
			# No valid properties ( probably after sanitize )
			_logger.warning("Received invalid data from %d for tick %d", [sender, tick])
			continue

		var known_snapshot := _history.get_snapshot(offset_tick)
		if not known_snapshot.equals(snapshot):
			# Received a new snapshot, store and emit signal
			_history.set_snapshot(offset_tick, snapshot)
			on_new_snapshot.emit(offset_tick)
