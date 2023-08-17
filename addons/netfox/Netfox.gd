@tool
extends EditorPlugin

const ROOT = "res://addons/netfox"
const SETTINGS = [
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
		# Time to wait between time syncs
		"name": "netfox/time/sync_interval",
		"value": 1.0,
		"type": TYPE_FLOAT
	},
	{
		"name": "netfox/time/sync_samples",
		"value": 8,
		"type": TYPE_INT
	},
	{
		# Time to wait between time sync samples
		"name": "netfox/time/sync_sample_interval",
		"value": 0.1,
		"type": TYPE_FLOAT
	},
	{
		"name": "netfox/time/sync_to_physics",
		"value": false,
		"type": TYPE_BOOL
	}
]

const AUTOLOADS = [
	{
		"name": "NetworkTime",
		"path": ROOT + "/NetworkTime.gd"
	},
	{
		"name": "NetworkTimeSynchronizer",
		"path": ROOT + "/NetworkTimeSynchronizer.gd"
	}
]

func _enter_tree():
	print("NetFox entering")
	for setting in SETTINGS:
		print("Adding setting %s", setting.name)
		add_setting(setting)
	
	for autoload in AUTOLOADS:
		add_autoload_singleton(autoload.name, autoload.path)

func _exit_tree():
	print("NetFox leaving")
	# for setting in SETTINGS:
	# 	remove_setting(setting)
	
	for autoload in AUTOLOADS:
		remove_autoload_singleton(autoload.name)

func add_setting(setting: Dictionary):
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

func remove_setting(setting: Dictionary):
	if not ProjectSettings.has_setting(setting.name):
		return
	
	ProjectSettings.clear(setting.name)
