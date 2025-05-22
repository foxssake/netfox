class_name NetworkArea2D
extends Area2D

## Emitted when a body enters this area.
signal rollback_body_entered(body: Node2D, tick: int)
## Emitted when a body exits this area.
signal rollback_body_exited(body: Node2D, tick: int)

## Emitted when the received area enters this area. Requires monitoring to be set to true.
signal rollback_area_entered(area: Area2D, tick: int)
## Emitted when the received area exits this area. Requires monitoring to be set to true.
signal rollback_area_exited(area: Area2D, tick: int)

var _overlapping_bodies := _HistoryBuffer.new()
var _overlapping_areas := _HistoryBuffer.new()


## Returns the result of [method Area2D.get_overlapping_areas] at [param tick]
func rollback_get_overlapping_areas(tick: int) -> Array[Area2D]:
	return _overlapping_areas.get_snapshot(tick) if _overlapping_areas.has(tick) else []

## Returns the result of [method Area2D.get_overlapping_bodies] at [param tick]
func rollback_get_overlapping_bodies(tick: int) -> Array[Node2D]:
	return _overlapping_bodies.get_snapshot(tick) if _overlapping_bodies.has(tick) else []

## Returns the result of [method Area2D.has_overlapping_areas] at [param tick]
func rollback_has_overlapping_areas(tick: int) -> bool:
	return rollback_get_overlapping_areas(tick).size() > 0

## Returns the result of [method Area2D.has_overlapping_bodies] at [param tick]
func rollback_has_overlapping_bodies(tick: int) -> bool:
	return rollback_get_overlapping_bodies(tick).size() > 0

## Returns the result of [method Area2D.overlaps_area] at [param tick]
func rollback_overlaps_area(area: Area2D, tick: int) -> bool:
	return rollback_get_overlapping_areas(tick).has(area)

## Returns the result of [method Area2D.overlaps_body] at [param tick]
func rollback_overlaps_body(body: Node2D, tick: int) -> bool:
	return rollback_get_overlapping_bodies(tick).has(body)


func _notification(what: int):
	# Use notification instead of _ready, so users can write their own _ready 
	# callback without having to call super()
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
		for area in current:
			rollback_area_entered.emit(area, tick)
		return
	
	var prev: Array = _overlapping_areas.get_snapshot(tick - 1)
	
	for area in current:
		if not prev.has(area):
			rollback_area_entered.emit(area, tick)
	
	for area in prev:
		if not current.has(area):
			rollback_area_exited.emit(area, tick)
	
	_overlapping_areas.trim(NetworkRollback.history_start)
