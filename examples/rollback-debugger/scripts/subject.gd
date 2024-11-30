extends Sprite2D

@export var move_speed := 16.
@onready var input := $Input

func _rollback_tick(_dt, _t, _if):
	position += input.movement.normalized() * move_speed
