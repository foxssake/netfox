extends Node
class_name ChannelManager

var _available_channels: Array = []
var _assigned_channels: Dictionary = {}
var _channel_limit: int
var _is_enabled: bool = false

func _ready():
	_channel_limit = ProjectSettings.get_setting("netfox/channel_manager/channel_limit", 16)
	_init_channels()

func _init_channels() -> void:
	_available_channels.resize(_channel_limit)
	for i in _channel_limit:
		_available_channels[i] = i + 1 # Channel 0 is default, start from 1

func is_enabled() -> bool:
	return ProjectSettings.get_setting("netfox/channel_manager/enabled", false)

func get_channel() -> int:
	if _available_channels.is_empty():
		return -1 # No channels available
	return _available_channels.pop_front()

func free_channel(channel: int) -> void:
	if channel in _assigned_channels:
		_assigned_channels.erase(channel)
		_available_channels.append(channel)

func assign_channel(node: Node, channel: int) -> void:
	_assigned_channels[channel] = node

func has_channel(channel: int) -> bool:
	return channel in _assigned_channels

func set_channel_limit(limit: int) -> void:
	_channel_limit = limit
	_available_channels.clear()
	_init_channels()
