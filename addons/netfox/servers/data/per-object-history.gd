extends RefCounted
class_name _PerObjectHistory

var _history_size: int
var _data := {} # Object to _HistoryBuffer

func _init(p_history_size: int):
	_history_size = p_history_size

func subjects() -> Array[Object]:
	var result := [] as Array[Object]
	result.assign(_data.keys())
	return result

func is_auth(tick: int, subject: Object) -> bool:
	if not _data.has(subject):
		return false

	var history := _data[subject] as _HistoryBuffer
	if not history.has_at(tick):
		return false

	var snapshot := history.get_at(tick) as ObjectSnapshot
	return snapshot._is_auth

func erase_subject(subject: Object) -> void:
	_data.erase(subject)

func ensure_snapshot(tick: int, subject: Object, carry_forward: bool) -> ObjectSnapshot:
	var has_subject := _data.has(subject)
	if not _data.has(subject):
		_data[subject] = _HistoryBuffer.new(_history_size)

	var history := _data[subject] as _HistoryBuffer
	var has_tick := history.has_at(tick)
	var has_latest := history.has_latest_at(tick)

	if not history.has_at(tick):
		if not history.has_latest_at(tick):
			history.set_at(tick, ObjectSnapshot.new(subject))
			push_warning("Set @%d to new snapshot, no latest: %s" % [tick, history.get_at(tick)])
		elif carry_forward:
			history.set_at(tick, history.get_latest_at(tick).duplicate())
		else:
			history.set_at(tick, ObjectSnapshot.new(subject))

	if history.get_at(tick) == null:
		return ObjectSnapshot.new(subject) # HACK
	assert(history.get_at(tick) != null, "Somehow no snapshot?!")
	return history.get_at(tick) as ObjectSnapshot

func get_latest_snapshot(tick: int, subject: Object) -> ObjectSnapshot:
	if not _data.has(subject):
		return null

	var history := _data[subject] as _HistoryBuffer
	if not history.has_latest_at(tick):
		return null

	return history.get_latest_at(tick) as ObjectSnapshot

func get_latest_tick(tick: int, subject: Object) -> int:
	if not _data.has(subject):
		return -1

	var history := _data[subject] as _HistoryBuffer
	if not history.has_latest_at(tick):
		return -1

	return history.get_latest_index_at(tick)

func set_property(tick: int, subject: Object, property: NodePath, value: Variant) -> void:
	if not _data.has(subject):
		_data[subject] = _HistoryBuffer.new(_history_size)

	var history := _data[subject] as _HistoryBuffer
	if not history.has_at(tick):
		history.set_at(tick, ObjectSnapshot.new(subject))

	var snapshot := history.get_at(tick) as ObjectSnapshot
	snapshot.set_value(property, value)

func has_property(tick: int, subject: Object, property: NodePath) -> bool:
	if not _data.has(subject):
		return false

	var history := _data[subject] as _HistoryBuffer
	if not history.has_at(tick):
		return false

	var snapshot := history.get_at(tick) as ObjectSnapshot
	return snapshot.has_value(property)

func get_property(tick: int, subject: Object, property: NodePath, default: Variant = null) -> Variant:
	if not _data.has(subject):
		return default

	var history := _data[subject] as _HistoryBuffer
	if not history.has_at(tick):
		return default

	var snapshot := history.get_at(tick) as ObjectSnapshot
	return snapshot.get_value(property, default)
