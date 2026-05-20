extends Node


class _Effect:
	extends RefCounted
	var on_revert: Callable
	var was_recorded_on_resim: bool = false


class EffectContext:
	extends RefCounted
	var on_revert: Callable


var _effects: Array[Dictionary] = []
var _ticks: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_effects.resize(NetworkRollback.history_limit)
	for i: int in _effects.size():
		_effects[i] = {}

	_ticks.resize(NetworkRollback.history_limit)
	_ticks.fill(-1)

	NetworkRollback.on_prepare_tick.connect(_on_prepare_tick)
	NetworkRollback.after_process_tick.connect(_after_process_tick)


func record(key: Variant, apply: Callable, tick: int = NetworkRollback.tick) -> void:
	var index := _get_index(tick)
	if _ticks[index] != tick:
		_effects[index].clear()
		_ticks[index] = tick

	var tick_effects := _effects[index]
	var effect: _Effect = tick_effects.get(key)
	if effect != null:
		effect.was_recorded_on_resim = true
		return

	var context: EffectContext = EffectContext.new()
	apply.call(context)

	effect = _Effect.new()
	effect.on_revert = context.on_revert
	effect.was_recorded_on_resim = true
	tick_effects[key] = effect


func _on_prepare_tick(tick: int) -> void:
	var index := _get_index(tick)
	if _ticks[index] != tick:
		return

	for effect: _Effect in _effects[index].values():
		effect.was_recorded_on_resim = false


func _after_process_tick(tick: int) -> void:
	var index := _get_index(tick)
	if _ticks[index] != tick:
		return

	var tick_effects := _effects[index]
	for key: Variant in tick_effects.keys():
		var effect: _Effect = tick_effects[key]
		if effect.was_recorded_on_resim:
			continue

		_revert_effect(effect)
		tick_effects.erase(key)


func _get_index(tick: int) -> int:
	return tick % _effects.size()


func _revert_effect(effect: _Effect) -> void:
	if effect == null:
		return

	if not effect.on_revert.is_valid():
		return

	effect.on_revert.call()
