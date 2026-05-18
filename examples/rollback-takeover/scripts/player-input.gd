extends BaseNetInput
class_name TakeoverPlayerInput

var movement: Vector2
var is_interacting: bool

var _is_interact_buffer := false

@onready var _logger := NetfoxLogger.new("to", "Input:" + self.get_parent().name)

func _ready() -> void:
	super()
	NetworkTime.after_tick.connect(func(_dt, _t): _gather_always())

func _process(_dt) -> void:
	if Input.is_action_just_pressed("action_interact"):
		_is_interact_buffer = true

func _gather() -> void:
	movement = Input.get_vector("move_west", "move_east", "move_north", "move_south")
	is_interacting = _is_interact_buffer
	_is_interact_buffer = false
	
	if is_interacting:
		_logger.debug("Interacting!")

func _gather_always() -> void:
	return
	is_interacting = _is_interact_buffer
	_is_interact_buffer = false
	
	if is_interacting:
		_logger.debug("Interacting!")
