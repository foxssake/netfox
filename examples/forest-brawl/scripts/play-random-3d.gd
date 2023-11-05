extends AudioStreamPlayer3D
class_name PlayRandomStream3D

@export var sounds: Array[AudioStream] = []

static var idx = 0

func _ready():
	if autoplay:
		play_random()

func play_random():
	stream = sounds.pick_random()
	play()
