extends Effect

@export var bonus_mass: float = 1.0

func _apply():
	get_target().get_node("Displaceable").mass += bonus_mass

func _cease():
	get_target().get_node("Displaceable").mass -= bonus_mass
