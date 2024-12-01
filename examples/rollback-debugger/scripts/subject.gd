extends Sprite2D

@export var move_speed := 16.

@onready var input := $Input
@onready var rollback_synchronizer := $RollbackSynchronizer as RollbackSynchronizer

func _ready():
	return
	set_multiplayer_authority(2)
	input.set_multiplayer_authority(multiplayer.get_unique_id())

func _rollback_tick(_dt, _t, _if):
	if not rollback_synchronizer.has_input() or rollback_synchronizer.get_input_age() > 0:
		rollback_synchronizer.ignore(self)
		return

	position += input.movement.normalized() * move_speed
