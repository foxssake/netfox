extends CPUParticles3D

func _ready():
	one_shot = true

func _process(_delta):
	if not emitting:
		queue_free()
