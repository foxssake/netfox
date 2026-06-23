extends Node
class_name _InterpolationServer

# @public class

## Manages interpolation between network ticks
##
## Handles interpolation for multiple TickInterpolator nodes, storing snapshots
## and applying interpolation based on the network tick factor.

var _property_caches: Dictionary = {}  # {subject Node: PropertyCache}
var _property_entries: Dictionary = {} # {subject Node: Array[PropertyEntry]}
var _interpolators: Dictionary = {}    # {subject Node: {property_path String: Callable}}

var _state_from := _Snapshot.new(0)
var _state_to := _Snapshot.new(0)

var _enabled := _Set.new()
var _recording_enabled := _Set.new()
var _teleported := _Set.new()

static var _logger := NetfoxLogger._for_netfox("InterpolationServer")

## Register a [param property] for interpolation on a [param subject] node.
## [br][br]
## Call [method set_enabled] and [method set_recording] to configure the subject
## after registration. Subjects are enabled and recording by default.
## If the property is already registered for this subject, this is a no-op.
func register(subject: Node, property: String) -> void:
	if not _property_caches.has(subject):
		_property_caches[subject] = PropertyCache.new(subject)
		_property_entries[subject] = [] as Array[PropertyEntry]
		_interpolators[subject] = {}
		_enabled.add(subject)
		_recording_enabled.add(subject)

	var entries := _property_entries[subject] as Array[PropertyEntry]
	for entry in entries:
		if entry.to_string() == property:
			return

	var cache := _property_caches[subject] as PropertyCache
	var entry := cache.get_entry(property)
	entries.push_back(entry)
	_interpolators[subject][property] = Interpolators.find_for(entry.get_value())

## Deregister all properties for a [param subject].
func deregister(subject: Node) -> void:
	var entries := _property_entries.get(subject, [])
	for entry in entries:
		_state_from.erase_subject(entry.node)
		_state_to.erase_subject(entry.node)
	_property_entries.erase(subject)
	_property_caches.erase(subject)
	_interpolators.erase(subject)
	_enabled.erase(subject)
	_recording_enabled.erase(subject)
	_teleported.erase(subject)

## Enable or disable interpolation for a [param subject].
func set_enabled(subject: Node, enabled: bool) -> void:
	if enabled:
		_enabled.add(subject)
	else:
		_enabled.erase(subject)

## Enable or disable automatic state recording for a [param subject].
func set_recording(subject: Node, enabled: bool) -> void:
	if enabled:
		_recording_enabled.add(subject)
	else:
		_recording_enabled.erase(subject)

## Check if interpolation can be done for a [param subject].
func can_interpolate(subject: Node) -> bool:
	if not _enabled.has(subject):
		return false
	if _teleported.has(subject):
		return false
	var entries := _property_entries.get(subject, []) as Array[PropertyEntry]
	return not entries.is_empty()

## Record current state for interpolation.
func push_state(subject: Node) -> void:
	if not _property_entries.has(subject):
		_logger.warning("Trying to push state for unregistered subject %s", [subject])
		return
	var entries := _property_entries[subject] as Array[PropertyEntry]

	for entry in entries:
		var node := entry.node
		var prop := entry.property
		var to_val = _state_to.get_property(node, prop)
		if to_val != null:
			_state_from.set_property(node, prop, to_val)
		_state_to.record_property(node, prop)

## Record current state and skip interpolation for this tick.
func teleport(subject: Node) -> void:
	if _teleported.has(subject):
		return
	if not _property_entries.has(subject):
		_logger.warning("Trying to teleport unregistered subject %s", [subject])
		return
	var entries := _property_entries[subject] as Array[PropertyEntry]

	for entry in entries:
		var value = entry.get_value()
		_state_from.set_property(entry.node, entry.property, value)
		_state_to.set_property(entry.node, entry.property, value)
	_teleported.add(subject)

## Interpolate properties for a [param subject].
func _interpolate_subject(subject: Node, factor: float) -> void:
	if not _enabled.has(subject) or _teleported.has(subject):
		return

	var entries := _property_entries.get(subject, []) as Array[PropertyEntry]
	var interps := _interpolators.get(subject, {}) as Dictionary

	for entry in entries:
		var node := entry.node
		var prop := entry.property

		if not _state_from.has_property(node, prop) or not _state_to.has_property(node, prop):
			continue

		var a = _state_from.get_property(node, prop)
		var b = _state_to.get_property(node, prop)
		var fn: Callable = interps.get(entry.to_string())
		if fn.is_valid():
			entry.set_value(fn.call(a, b, factor))

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

func _before_tick_loop() -> void:
	_clear_teleports()
	_apply_target_state()

func _after_tick_loop() -> void:
	_record_next_state()

func _clear_teleports() -> void:
	_teleported.clear()

func _apply_target_state() -> void:
	_state_to.apply()

func _record_next_state() -> void:
	for subject in _recording_enabled.values():
		if _teleported.has(subject):
			continue
		var entries := _property_entries.get(subject, []) as Array[PropertyEntry]
		for entry in entries:
			var node := entry.node
			var prop := entry.property
			var old_to = _state_to.get_property(node, prop)
			var current = node.get_indexed(prop)
			_state_to.set_property(node, prop, current)
			if old_to != null:
				_state_from.set_property(node, prop, old_to)
				node.set_indexed(prop, old_to)
