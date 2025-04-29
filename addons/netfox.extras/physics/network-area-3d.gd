class_name NetworkArea3D
extends Area3D

## Emitted when a body enters this area.
signal rollback_body_entered(body: Node3D, tick: int)
## Emitted when a body exits this area.
signal rollback_body_exited(body: Node3D, tick: int)

## Emitted when the received area enters this area. Requires monitoring to be set to true.
signal rollback_area_entered(area: Area3D, tick: int)
## Emitted when the received area exits this area. Requires monitoring to be set to true.
signal rollback_area_exited(area: Area3D, tick: int)

var _overlapping_bodies := _HistoryBuffer.new()
var _overlapping_areas := _HistoryBuffer.new()

func _notification(what: int):
	if what == NOTIFICATION_READY:
		NetworkTime.on_tick.connect(_tick)

func _tick(_d: float, tick: int):
	_update_bodies(tick)
	_update_areas(tick)

func _update_bodies(tick: int):
	var current := self.get_overlapping_bodies()
	_overlapping_bodies.set_snapshot(tick, current)
	
	if not _overlapping_bodies.has(tick - 1):
		for body in current:
			rollback_body_entered.emit(body, tick)
		return
	
	var prev: Array = _overlapping_bodies.get_snapshot(tick - 1)
	
	if current.hash() != prev.hash():
		for body in current:
			if not prev.has(body):
				rollback_body_entered.emit(body, tick)
		
		for body in prev:
			if not current.has(body):
				rollback_body_exited.emit(body, tick)
	
	_overlapping_bodies.trim(NetworkRollback.history_start)


func _update_areas(tick: int):
	var current := self.get_overlapping_areas()
	_overlapping_areas.set_snapshot(tick, current)
	
	if not _overlapping_areas.has(tick - 1):
		for body in current:
			rollback_body_entered.emit(body, tick)
		return
	
	var prev: Array = _overlapping_areas.get_snapshot(tick - 1)
	
	if current.hash() != prev.hash():
		for body in current:
			if not prev.has(body):
				rollback_area_entered.emit(body, tick)
		
		for body in prev:
			if not current.has(body):
				rollback_area_exited.emit(body, tick)
	
	_overlapping_areas.trim(NetworkRollback.history_start)
