extends RefCounted

var _scene_tree: SceneTree
var _remaining: float
var _interval: float

func _init(p_duration: float, p_interval: float, p_scene_tree: SceneTree):
	_remaining = p_duration
	_interval = p_interval
	_scene_tree = p_scene_tree

func until(condition: Callable) -> Error:
	if not _scene_tree:
		push_warning("Missing reference to SceneTree, will return immediately!")
		return ERR_UNAVAILABLE

	if _remaining <= 0.0:
		# Timeout already spent
		return ERR_TIMEOUT

	var start := Vest.time()
	var deadline := start + _remaining
	while Vest.time() < deadline:
		if condition.call():
			_remaining -= Vest.time() - start
			return OK

		if is_zero_approx(_interval): await _scene_tree.process_frame
		else: await _scene_tree.create_timer(_interval).timeout

	return ERR_TIMEOUT
