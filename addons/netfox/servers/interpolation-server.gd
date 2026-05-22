extends Node
class_name _InterpolationServer

# @public class

## Manages interpolation between network ticks
##
## Handles interpolation for multiple TickInterpolator nodes, storing snapshots
## and applying interpolation based on the network tick factor.

class InterpolationGroup:
	var root: Node
	var properties: Array[String]
	var enabled: bool = true
	var enable_recording: bool = true

	var property_cache: PropertyCache
	var property_entries: Array[PropertyEntry] = []
	var interpolators: Dictionary = {}

	var state_from: _PropertySnapshot
	var state_to: _PropertySnapshot
	var is_teleporting: bool = false

	func _init():
		state_from = _PropertySnapshot.new()
		state_to = _PropertySnapshot.new()

var _groups: Dictionary = {} # int (group_id) to InterpolationGroup

static var _logger := NetfoxLogger._for_netfox("InterpolationServer")

## Register an interpolation group for a TickInterpolator node
func register_interpolation_group(group_id: int, root: Node, properties: Array[String], enabled: bool, enable_recording: bool) -> void:

	if _groups.has(group_id):
		deregister_interpolation_group(group_id)

	var group := InterpolationGroup.new()
	group.root = root
	group.properties = properties.duplicate()
	group.enabled = enabled
	group.enable_recording = enable_recording

	group.property_cache = PropertyCache.new(root)
	group.property_entries.clear()
	group.interpolators.clear()

	for property in properties:
		var property_entry = group.property_cache.get_entry(property)
		group.property_entries.push_back(property_entry)
		group.interpolators[property] = Interpolators.find_for(property_entry.get_value())

	_groups[group_id] = group

## Deregister an interpolation group
func deregister_interpolation_group(group_id: int) -> void:
	_groups.erase(group_id)

## Check if an interpolation group can interpolate
func can_interpolate(group_id: int) -> bool:
	var group = _groups.get(group_id)
	if not group:
		return false

	return group.enabled and not group.properties.is_empty() and not group.is_teleporting

## Record current state for interpolation
func push_state(group_id: int) -> void:
	var group = _groups.get(group_id)
	if not group:
		_logger.warning("Trying to push state for unregistered group %d", [group_id])
		return

	group.state_from = group.state_to
	group.state_to = _PropertySnapshot.extract(group.property_entries)

## Record current state and transition without interpolation
func teleport(group_id: int) -> void:
	var group = _groups.get(group_id)
	if not group:
		_logger.warning("Trying to teleport unregistered group %d", [group_id])
		return

	if group.is_teleporting:
		return

	group.state_from = _PropertySnapshot.extract(group.property_entries)
	group.state_to = group.state_from
	group.is_teleporting = true

## Interpolate properties for a group
func interpolate(group_id: int, factor: float) -> void:
	var group = _groups.get(group_id)
	if not group:
		return

	if not group.enabled or group.is_teleporting:
		return

	for i in group.property_entries.size():
		var property_entry = group.property_entries[i]
		var property_path = property_entry.to_string()
		
		if not group.state_from.has(property_path) or not group.state_to.has(property_path):
			continue
		
		var a = group.state_from.get_value(property_path)
		var b = group.state_to.get_value(property_path)
		var interpolate_fn = group.interpolators[property_path]

		property_entry.set_value(interpolate_fn.call(a, b, factor))

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

func _before_tick_loop() -> void:
	for group in _groups.values():
		group.is_teleporting = false
		group.state_to.apply(group.property_cache)

func _after_tick_loop() -> void:
	for group in _groups.values():
		if group.enable_recording and not group.is_teleporting:
			group.state_from = group.state_to
			group.state_to = _PropertySnapshot.extract(group.property_entries)
			group.state_from.apply(group.property_cache)
