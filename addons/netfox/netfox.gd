@tool
extends EditorPlugin

const ROOT := "res://addons/netfox"
var SETTINGS: Array[Dictionary] = [
	{
		# Setting this to false will make Netfox keep its settings even when
		# disabling the plugin. Useful for developing the plugin.
		"name": "netfox/general/clear_settings",
		"value": true,
		"type": TYPE_BOOL
	},
	# Logging
	NetfoxLogger._make_setting("netfox/logging/netfox_log_level"),
	# Time settings
	{
		"name": "netfox/time/tickrate",
		"value": 30,
		"type": TYPE_INT
	},
	{
		"name": "netfox/time/max_ticks_per_frame",
		"value": 8,
		"type": TYPE_INT
	},
	{
		"name": "netfox/time/recalibrate_threshold",
		"value": 8.0,
		"type": TYPE_FLOAT
	},
	{
		"name": "netfox/time/stall_threshold",
		"value": 1.0,
		"type": TYPE_FLOAT
	},
	{
		# Time to wait between time syncs
		"name": "netfox/time/sync_interval",
		"value": 0.25,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "%s,2,or_greater" % [_NetworkTimeSynchronizer.MIN_SYNC_INTERVAL]
	},
	{
		"name": "netfox/time/sync_samples",
		"value": 8,
		"type": TYPE_INT
	},
	{
		"name": "netfox/time/sync_adjust_steps",
		"value": 8,
		"type": TYPE_INT
	},
	{
		# !! Deprecated
		# Time to wait between time sync samples
		"name": "netfox/time/sync_sample_interval",
		"value": 0.1,
		"type": TYPE_FLOAT
	},
	{
		"name": "netfox/time/sync_to_physics",
		"value": false,
		"type": TYPE_BOOL
	},
	{
		"name": "netfox/time/max_time_stretch",
		"value": 1.25,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1,2,0.05,or_greater"
	},
	{
		"name": "netfox/time/tickrate_mismatch_action",
		"value": NetworkTickrateHandshake.WARN,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Warn,Disconnect,Adjust,Signal"
	},
	{
		"name": "netfox/time/suppress_offline_peer_warning",
		"value": false,
		"type": TYPE_BOOL
	},
	# Rollback settings
	{
		"name": "netfox/rollback/enabled",
		"value": true,
		"type": TYPE_BOOL
	},
	{
		"name": "netfox/rollback/history_limit",
		"value": 64,
		"type": TYPE_INT
	},
	{
		"name": "netfox/rollback/input_redundancy",
		"value": 3,
		"type": TYPE_INT
	},
	{
		"name": "netfox/rollback/display_offset",
		"value": 0,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,4,or_greater"
	},
	{
		"name": "netfox/rollback/input_delay",
		"value": 0,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,4,or_greater"
	},
	{
		"name": "netfox/rollback/enable_diff_states",
		"value": true,
		"type": TYPE_BOOL
	},
	# Events
	{
		"name": "netfox/events/enabled",
		"value": true,
		"type": TYPE_BOOL
	}
]

const AUTOLOADS: Array[Dictionary] = [
	{
		"name": "NetworkTime",
		"path": ROOT + "/network-time.gd"
	},
	{
		"name": "NetworkTimeSynchronizer",
		"path": ROOT + "/network-time-synchronizer.gd"
	},
	{
		"name": "NetworkRollback",
		"path": ROOT + "/rollback/network-rollback.gd"
	},
	{
		"name": "NetworkEvents",
		"path": ROOT + "/network-events.gd"
	},
	{
		"name": "NetworkPerformance",
		"path": ROOT + "/network-performance.gd"
	}
]

const TYPES: Array[Dictionary] = [
	{
		"name": "RollbackSynchronizer",
		"base": "Node",
		"script": ROOT + "/rollback/rollback-synchronizer.gd",
		"icon": ROOT + "/icons/rollback-synchronizer.svg"
	},
	{
		"name": "StateSynchronizer",
		"base": "Node",
		"script": ROOT + "/state-synchronizer.gd",
		"icon": ROOT + "/icons/state-synchronizer.svg"
	},
	{
		"name": "TickInterpolator",
		"base": "Node",
		"script": ROOT + "/tick-interpolator.gd",
		"icon": ROOT + "/icons/tick-interpolator.svg"
	},
	{
		"name": "RewindableAction",
		"base": "Node",
		"script": ROOT + "/rewindable-action.gd",
		"icon": ROOT + "/icons/rewindable-action.svg"
	},
]

func _enter_tree():
	for setting in SETTINGS:
		add_setting(setting)
	
	for autoload in AUTOLOADS:
		add_autoload_singleton(autoload.name, autoload.path)
	
	for type in TYPES:
		add_custom_type(type.name, type.base, load(type.script), load(type.icon))

func _exit_tree() -> void:
	if ProjectSettings.get_setting(&"netfox/general/clear_settings", false):
		for setting in SETTINGS:
			remove_setting(setting)
	
	for autoload in AUTOLOADS:
		remove_autoload_singleton(autoload.name)
	
	for type in TYPES:
		remove_custom_type(type.name)

func add_setting(setting: Dictionary) -> void:
	if ProjectSettings.has_setting(setting.name):
		return

	ProjectSettings.set_setting(setting.name, setting.value)
	ProjectSettings.set_initial_value(setting.name, setting.value)
	ProjectSettings.add_property_info({
		"name": setting.get("name"),
		"type": setting.get("type"),
		"hint": setting.get("hint", PROPERTY_HINT_NONE),
		"hint_string": setting.get("hint_string", "")
	})

func remove_setting(setting: Dictionary) -> void:
	if not ProjectSettings.has_setting(setting.name):
		return
	
	ProjectSettings.clear(setting.name)
