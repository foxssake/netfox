extends Effect

@export var bonus_mass: float = 1.0

func _apply():
	get_target().mass += bonus_mass
	NetworkRollback.mutate(get_target())

func _cease():
	get_target().mass -= bonus_mass
	NetworkRollback.mutate(get_target())
