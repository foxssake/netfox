extends Label

func _ready():
	NetworkTime.on_tick.connect(_tick)

func _tick(delta):
	text = "Time: %.2f at tick #%d" % [NetworkTime.time, NetworkTime.tick]
