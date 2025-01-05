@tool
extends Node
class_name NetworkJobQueue

## Halt processing any items
@export var paused: bool = false

# An internal list to hold our queued jobs (as Dictionaries).
var queue: Array[Dictionary] = []

# A mapping of worker_name -> worker_node, so we can find the right worker.
var _workers := {}
var _id_counter := 0

func _get_configuration_warnings():
	const MISSING_SYNCHRONIZER_ERROR := \
		"NetworkJobQueue is not managed by a RollbackSynchronizer! Add it as a sibling node to fix this."
	const INVALID_SYNCHRONIZER_CONFIG_ERROR := \
		"RollbackSynchronizer configuration is invalid, it can't manage this job queue!" + \
		"\nNote: You may need to reload this scene after fixing for this warning to disappear."
	const MISSING_PROPERTY_ERROR := \
		"Queue is not managed by RollbackSynchronizer! Add `queue` property to the synchronizer to fix this. " + \
		"\nNote: You may need to reload this scene after fixing for this warning to disappear."
	
	# Check if there's a rollback synchronizer
	var rollback_synchronizer_node = get_parent().find_children("*", "RollbackSynchronizer", false).pop_front()
	if not rollback_synchronizer_node:
		return [MISSING_SYNCHRONIZER_ERROR]
	
	var rollback_synchronizer := rollback_synchronizer_node as RollbackSynchronizer
	
	# Check if its configuration is valid
	# TODO: Expose this as a property?
	if not rollback_synchronizer.root:
		return [INVALID_SYNCHRONIZER_CONFIG_ERROR]
	
	# Check if it manages our `queue` property
	for state_property_path in rollback_synchronizer.state_properties:
		var property = PropertyEntry.parse(rollback_synchronizer.root, state_property_path)
		if property.node == self and property.property == "queue":
			return []

	return [MISSING_PROPERTY_ERROR]

func _get_uid() -> int:
	_id_counter += 1
	return _id_counter

func get_queue_position(uid: int):
	for i in range(queue.size()):
		var job: Dictionary = queue[i]
		if job._uid == uid:
			return i

## Call this method so workers can "register" themselves with the queue.
func register_worker(worker_name: String, worker_node: NetworkJobWorker) -> void:
	if !worker_node.queue:
		worker_node.queue = self
	_workers[worker_name] = worker_node

## Add a dictionary job to the queue. For example: enqueue_job({"worker": "MyWorker", "payload": "Hello World!"})
func enqueue_job(job: Dictionary, worker: NetworkJobWorker = null) -> int:
	var uid: int = _get_uid()
	job[&"_uid"] = uid
	
	if worker:
		job[&"worker"] = worker.worker_name
		worker.job_enqueued(job)
		
	queue.append(job)
	return uid

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if paused or queue.size() == 0: return
	
	for worker_name in _workers.keys():
		var jobs: Array[Dictionary] = queue.filter(func(x): x[&"worker"] == worker_name)
		var worker: NetworkJobWorker = _workers[worker_name]
		if worker.busy: continue
		
		var next_job = jobs[0]
		for job_index in range(queue.size()):
			var job = queue[job_index]
			if job._uid == next_job._uid:
				queue.remove_at(job_index)
				break
				
		worker.process_job(next_job)
