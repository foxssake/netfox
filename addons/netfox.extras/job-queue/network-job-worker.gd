@tool
extends Node
class_name NetworkJobWorker

@export var worker_name: String = "Worker"
@export var queue: NetworkJobQueue: set = _set_queue

var busy: bool = false

func _get_configuration_warnings():
	return [] if queue else ["This NetworkJobWorker should be registered with a queue."]

## Register the worker with the queue if the parent is a NetworkJobQueue.
func _notification(what: int):
	if what == NOTIFICATION_READY:
		if !queue and get_parent() is NetworkJobQueue:
			queue = get_parent()

func _set_queue(value: NetworkJobQueue) -> void:
	queue = value
	register_with_queue()

## Call this method to register the worker with the queue.
func register_with_queue() -> void:
	if queue:
		queue.register_worker(worker_name, self)

## This method is called by the NetworkJobQueue when a job is enqueued.
func job_enqueued(job: Dictionary) -> void:
	pass

## This method is called by the NetworkJobQueue when a job is ready to be processed. You should extend this node and override this method in your own worker.
func process_job(job: Dictionary) -> void:
	busy = true
	# Do something with the job here
	busy = false
	pass
