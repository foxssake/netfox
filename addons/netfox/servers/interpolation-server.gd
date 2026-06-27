extends Node
class_name _InterpolationServer

# @public class

## Manages interpolation between network ticks
##
## Handles interpolation for multiple TickInterpolator nodes, storing snapshots
## and applying interpolation based on the network tick factor.

var _properties := _PropertyPool.new()
var _interpolators: Dictionary = {}    # {subject Node: {property_path String: Interpolator}}

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
func register(subject: Node, property: NodePath, interpolator: Interpolators.Interpolator = null) -> void:
	if not _properties.has_subject(subject):
		# Subject wasn't registered before, setup defaults
		_interpolators[subject] = {}
		_enabled.add(subject)
		_recording_enabled.add(subject)

	if _properties.has(subject, property):
		# Property already registered, do nothing
		return

	_properties.add(subject, property)
	if interpolator == null:
		var value := subject.get_indexed(property)
		_interpolators[subject][property] = Interpolators.find_interpolator_for(value)
	else:
		_interpolators[subject][property] = interpolator

## Deregister all properties for a [param subject].
func deregister(subject: Node) -> void:
	_state_from.erase_subject(subject)
	_state_to.erase_subject(subject)
	
	_properties.erase_subject(subject)
	_interpolators.erase(subject)
	
	_enabled.erase(subject)
	_recording_enabled.erase(subject)
	_teleported.erase(subject)

func has_subject(subject: Node) -> bool:
	return _properties.has_subject(subject)

## Enable or disable interpolation for a [param subject].
func set_enabled(subject: Node, enabled: bool) -> void:
	if enabled:
		_enabled.add(subject)
	else:
		_enabled.erase(subject)

func is_enabled(subject: Node) -> bool:
	return _enabled.has(subject)

## Enable or disable automatic state recording for a [param subject].
func set_recording(subject: Node, enabled: bool) -> void:
	if enabled:
		_recording_enabled.add(subject)
	else:
		_recording_enabled.erase(subject)

func is_recording(subject: Node) -> bool:
	return _recording_enabled.has(subject)

## Check if interpolation can be done for a [param subject].
func can_interpolate(subject: Node) -> bool:
	if not has_subject(subject):
		# Unknown subject, can't interpolate
		return false
	if not is_enabled(subject):
		# Interpolation is disabled for subject
		return false
	if is_teleporting(subject):
		# Subject is teleporting, just snap to target state
		return false

	return true

## Record current state for interpolation.
func push_state(subject: Node) -> void:
	if not has_subject(subject):
		_logger.warning("Trying to push state for unregistered subject %s", [subject])
		return
		
	# Copy to[subject] => from[subject]
	_state_to.copy_subject_to(subject, _state_from)

	# Capture current as to[subject]
	_state_to.erase_subject(subject)
	for property in _properties.get_properties_of(subject):
		var value := subject.get_indexed(property)
		if value == null:
			# NOTE: This shouldn't happen?
			_logger.warning("Captured null value for interpolation on %s:%s; either a bug or wrong usage", [subject, property])
		else:
			_state_to.set_property(subject, property, value)

## Record current state and skip interpolation for this tick.
func teleport(subject: Node) -> void:
	if is_teleporting(subject):
		return
	if not has_subject(subject):
		_logger.warning("Trying to teleport unregistered subject %s", [subject])
		return

	_teleported.add(subject)

func is_teleporting(subject: Node) -> bool:
	return _teleported.has(subject)

## Interpolate properties for a [param subject].
func _interpolate_subject(subject: Node, factor: float) -> void:
	if not can_interpolate(subject):
		return

	var interps := _interpolators.get(subject, {}) as Dictionary
	if interps.is_empty():
		_logger.debug("No interpolators found for %s", [subject])

	for property in _properties.get_properties_of(subject):
		if not _state_from.has_property(subject, property) or not _state_to.has_property(subject, property):
			continue

		var a = _state_from.get_property(subject, property)
		var b = _state_to.get_property(subject, property)
		var interpolator := interps.get(property, Interpolators.DEFAULT_INTERPOLATOR) as Interpolators.Interpolator
		
		var value := interpolator.apply.call(a, b, factor)
		subject.set_indexed(property, value)

func _interpolate(factor: float) -> void:
	for subject in _properties.get_subjects():
		_interpolate_subject(subject, factor)

func _clear_teleports() -> void:
	_teleported.clear()

func _apply_target_state() -> void:
	_state_to.apply()

func _record_next_state() -> void:
	for subject in _recording_enabled.values():
		push_state(subject)
