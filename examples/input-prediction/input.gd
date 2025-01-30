extends BaseNetInput

var movement: Vector3
var confidence: float = 1.

@onready var _rollback_synchronizer := $"../RollbackSynchronizer" as RollbackSynchronizer

func _ready():
	super()
	NetworkRollback.after_prepare_tick.connect(_predict)

func _gather():
	movement = Vector3(
		Input.get_axis("move_east", "move_west"),
		Input.get_action_strength("move_jump"),
		Input.get_axis("move_south", "move_north")
	)

func _predict(_t):
	if not _rollback_synchronizer.is_predicting():
		# Not predicting, nothing to do
		confidence = 1.
		return
	
	if not _rollback_synchronizer.has_input():
		confidence = 0.
		return
	
	# Decay input over a short time
	var decay_time := NetworkTime.seconds_to_ticks(.15)
	var input_age := _rollback_synchronizer.get_input_age()
	
	# **ALWAYS** cast either side to float, otherwise the integer-integer 
	# division yields either 1 or 0 confidence
	confidence = input_age / float(decay_time)
	confidence = clampf(1. - confidence, 0., 1.)

	# Modulate input based on confidence
	movement *= confidence
