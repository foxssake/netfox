extends ProgressBar

@export var health: Health

func _process(delta: float):
	value = health.current_health
