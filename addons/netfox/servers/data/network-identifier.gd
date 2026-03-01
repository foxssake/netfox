class_name _NetworkIdentifier
extends RefCounted

var _subject: Object
var _full_name: String
var _ids: Dictionary = {} # peer to id
var _local_id: int

signal on_id(peer: int, id: int)

func _init(subject: Object, full_name: String, local_id: int, local_peer: int):
	_subject = subject
	_full_name = full_name
	_local_id = local_id
	_ids[local_peer] = local_id

func has_id_for(peer: int) -> bool:
	return _ids.has(peer)

func get_id_for(peer: int) -> int:
	return _ids.get(peer, -1)

func set_id_for(peer: int, id: int) -> void:
	assert(not _ids.has(peer), "ID for peer #%d is already set!" % [peer])
	_ids[peer] = id
	on_id.emit(peer, id)

func get_local_id() -> int:
	return _local_id

func get_full_name() -> String:
	return _full_name

func get_subject() -> Object:
	return _subject

func get_known_peers() -> Array[int]:
	var result := [] as Array[int]
	result.assign(_ids.keys())
	return result

func reference_for(peer: int) -> _NetworkIdentityReference:
	if has_id_for(peer):
		return _NetworkIdentityReference.of_id(get_id_for(peer))
	else:
		return _NetworkIdentityReference.of_full_name(get_full_name())

func _to_string() -> String:
	return "NetworkIdentifier(%s)" % [_full_name]
