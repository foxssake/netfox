extends RefCounted
class_name RewindableRandomNumberGenerator

## Provides methods for generating pseudo-random numbers in the rollback tick
## loop.
##
## Using a regular [RandomNumberGenerator] in [code]_rollback_tick()[/code]
## would generate different numbers on each peer. It also generates different
## numbers when resimulating the same tick.
## [br][br]
## This class solves all of the above, making it suitable for use during
## rollback.
## [br][br]
## The seed must be provided on instantiation, and must be the same on all peers
## for the random number generator to work properly.
##
## @tutorial(RewindableRandomNumberGenerator Guide): https://foxssake.github.io/netfox/latest/netfox.extras/guides/rewindable-random-number-generator/

var _rng: RandomNumberGenerator
var _last_reset_tick := -1
var _last_reset_rollback_tick := -1

static var _logger := NetfoxLogger._for_extras("RewindableRandomNumberGenerator")

func _init(p_seed: int):
	_rng = RandomNumberGenerator.new()
	_rng.set_seed(p_seed)

## Returns a pseudo-random float between [code]0.0[/code] and [code]1.0[/code]
## (inclusive).
func randf() -> float:
	_ensure_state()
	return _rng.randf()

## Returns a pseudo-random float between [code]from[/code] and [code]to[/code]
## (inclusive).
func randf_range(from: float, to: float) -> float:
	_ensure_state()
	return _rng.randf_range(from, to)

## Returns a normally-distributed, pseudo-random floating-point number from the
## specified [code]mean[/code] and a standard [code]deviation[/code]. This is
## also known as a Gaussian distribution.
func randfn(mean: float = 0.0, deviation: float = 1.0) -> float:
	_ensure_state()
	return _rng.randfn(mean, deviation)

## Returns a pseudo-random 32-bit unsigned integer between [code]0[/code] and
## [code]4294967295[/code] (inclusive).
func randi() -> int:
	_ensure_state()
	return _rng.randi()

## Returns a pseudo-random 32-bit unsigned integer between [code]from[/code] and
## [code]to[/code] (inclusive).
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
