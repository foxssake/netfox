extends CPUParticles3D

func _ready():
	emitting = true
	one_shot = true

func _process(_delta):
	if not emitting:
		queue_free()
