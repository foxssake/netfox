extends RefCounted
class_name RewindableRandomNumberGenerator

var _rng: RandomNumberGenerator
var _last_reset_tick := -1
var _last_reset_rollback_tick := -1

static var _logger := _NetfoxLogger.for_extras("RewindableRandomNumberGenerator")

func _init(p_seed: int):
	_rng = RandomNumberGenerator.new()
	_rng.set_seed(p_seed)

func randf() -> float:
	_ensure_state()
	return _rng.randf()

func randf_range(from: float, to: float) -> float:
	_ensure_state()
	return _rng.randf_range(from, to)

func randfn(mean: float = 0.0, deviation: float = 1.0) -> float:
	_ensure_state()
	return _rng.randfn(mean, deviation)

func randi() -> int:
	_ensure_state()
	return _rng.randi()

func randi_range(from: int, to: int) -> int:
	_ensure_state()
	return _rng.randi_range(from, to)

func _ensure_state() -> void:
	if NetworkTime.tick == _last_reset_tick and NetworkRollback.tick == _last_reset_rollback_tick:
		# State already has been set
		return

	if NetworkRollback.is_rollback():
		_rng.state = hash([_rng.seed, NetworkRollback.tick])
	else:
		_rng.state = hash([_rng.seed, NetworkTime.tick])

	_last_reset_rollback_tick = NetworkRollback.tick
	_last_reset_tick = NetworkTime.tick
