extends Node


func _ready() -> void:
	NetworkRollback.on_process_tick.connect(_rollback_tick)

func _rollback_tick(_t: int) -> void:
#	print(get_tree().get_nodes_in_group("Players"))
	pass
