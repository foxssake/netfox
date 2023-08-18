@tool
extends EditorPlugin

const ROOT = "res://addons/netfox.noray"

const AUTOLOADS = [
	{
		"name": "Noray",
		"path": ROOT + "/Noray.gd"
	},
	{
		"name": "PacketHandshake",
		"path": ROOT + "/PacketHandshake.gd"
	}
]


func _enter_tree():
	for autoload in AUTOLOADS:
		add_autoload_singleton(autoload.name, autoload.path)

func _exit_tree():
	for autoload in AUTOLOADS:
		remove_autoload_singleton(autoload.name)
