extends Node
class_name NetworkBootstrapper

static var _is_dedicated_host := false

static func is_dedicated_host() -> bool:
	return _is_dedicated_host

static func set_dedicated_host(p_is_dedicated_host: bool) -> void:
	_is_dedicated_host = p_is_dedicated_host
