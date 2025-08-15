extends BaseNetInput

var is_jumping: bool = false
var _is_jumping_buffer: bool = false

func _ready():
	super._ready()
	NetworkTime.after_tick.connect(func(_dt, _t): _reset())

func _process(_dt: float) -> void:
	if Input.is_action_just_pressed("move_jump"):
		_is_jumping_buffer = true

func _gather():
	is_jumping = _is_jumping_buffer

func _reset():
	_is_jumping_buffer = false
