extends StaticBody3D

@export var queue: NetworkJobQueue
@export var worker: NetworkJobWorker

func interact():
	if !is_multiplayer_authority(): return
	
	queue.process_jobs()
