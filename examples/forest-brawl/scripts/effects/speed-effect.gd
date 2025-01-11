extends Effect

@export var bonus: float = 0.2

func _apply():
	get_target().speed *= 1 + bonus
	NetworkRollback.mutate(get_target())

func _cease():
	get_target().speed /= 1 + bonus
	NetworkRollback.mutate(get_target())
