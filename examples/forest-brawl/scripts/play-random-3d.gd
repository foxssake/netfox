extends AudioStreamPlayer3D

@export var sounds: Array[AudioStream] = []

func _ready():
	stream = sounds.pick_random()
	play()
