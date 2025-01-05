extends StaticBody3D

@export var queue: NetworkJobQueue
@export var worker: NetworkJobWorker

func interact():
	if !is_multiplayer_authority(): return
	
	queue.enqueue_job({
		"index": 0
	}, worker)
