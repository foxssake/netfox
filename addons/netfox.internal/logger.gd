extends RefCounted
class_name _NetfoxLogger

enum {
	LOG_NONE,
	LOG_TRACE,
	LOG_DEBUG,
	LOG_INFO,
	LOG_WARN,
	LOG_ERROR,
	LOG_MAX
}

static var log_level: int

var module: String
var name: String

static func _static_init():
	log_level = ProjectSettings.get_setting("netfox/general/log_level", LOG_MAX)

static func for_netfox(p_name: String) -> _NetfoxLogger:
	return _NetfoxLogger.new("netfox", p_name)

func _init(p_module: String, p_name: String):
	name = p_name

func _format_text(text: String) -> String:
	return "[%s::%s] %s" % [module,name, text]

func _log_text(text: String, level: int):
	if log_level >= level:
		print(_format_text(text))

func trace(text: String):
	_log_text(text, LOG_TRACE)

func debug(text: String):
	_log_text(text, LOG_TRACE)

func info(text: String):
	_log_text(text, LOG_TRACE)

func warning(text: String):
	if log_level >= LOG_WARN:
		push_warning(_format_text(text))

func error(text: String):
	if log_level >= LOG_ERROR:
		push_warning(_format_text(text))
