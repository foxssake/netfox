extends Control

@onready var health_bar := $ProgressBar as ProgressBar

var player: ExampleRollbackFPS.Player

static var _inst

static func set_player(p_player: ExampleRollbackFPS.Player) -> void:
	if not _inst: return

	_inst.player = p_player
	_inst.visible = true
	_inst.set_process(true)

func _ready():
	visible = false
	set_process(false)
	_inst = self

func _process(_dt) -> void:
	if not is_instance_valid(player):
		set_process(false)
		return

	health_bar.value = player.health
