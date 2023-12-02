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
static var module_log_level: Dictionary

var module: String
var name: String

static func _static_init():
	log_level = ProjectSettings.get_setting("netfox/logging/log_level", LOG_MAX)
	module_log_level = {
		"netfox": ProjectSettings.get_setting("netfox/logging/netfox_log_level", LOG_MAX),
		"netfox.noray": ProjectSettings.get_setting("netfox/logging/netfox_noray_log_level", LOG_MAX),
		"netfox.extras": ProjectSettings.get_setting("netfox/logging/netfox_extras_log_level", LOG_MAX)
	}

static func for_netfox(p_name: String) -> _NetfoxLogger:
	return _NetfoxLogger.new("netfox", p_name)

static func for_noray(p_name: String) -> _NetfoxLogger:
	return _NetfoxLogger.new("netfox.noray", p_name)

static func for_extras(p_name: String) -> _NetfoxLogger:
	return _NetfoxLogger.new("netfox.extras", p_name)

static func make_setting(name: String) -> Dictionary:
	return {
		"name": name,
		"value": _NetfoxLogger.LOG_MAX,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "None,Trace,Debug,Info,Warning,Error,All"
	}

func _init(p_module: String, p_name: String):
	module = p_module
	name = p_name

func _check_log_level(level: int) -> bool:
	if log_level < level:
		return false
	
	if module_log_level.has(module):
		return module_log_level.get(module) >= level
	
	return true

func _format_text(text: String) -> String:
	return "[%s::%s] %s" % [module,name, text]

func _log_text(text: String, level: int):
	if _check_log_level(level):
		print(_format_text(text))

func trace(text: String):
	_log_text(text, LOG_TRACE)

func debug(text: String):
	_log_text(text, LOG_TRACE)

func info(text: String):
	_log_text(text, LOG_TRACE)

func warning(text: String):
	if _check_log_level(LOG_WARN):
		push_warning(_format_text(text))

func error(text: String):
	if _check_log_level(LOG_ERROR):
		push_warning(_format_text(text))
