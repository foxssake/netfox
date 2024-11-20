extends RefCounted
class_name _NetfoxLogger

enum {
	LOG_MIN,
	LOG_TRACE,
	LOG_DEBUG,
	LOG_INFO,
	LOG_WARN,
	LOG_ERROR,
	LOG_MAX
}

const DEFAULT_LOG_LEVEL := LOG_DEBUG

static var log_level: int
static var module_log_level: Dictionary

var module: String
var name: String

const level_prefixes: Array[String] = [
	"",
	"TRC",
	"DBG",
	"INF",
	"WRN",
	"ERR",
	""
]

static func for_netfox(p_name: String) -> _NetfoxLogger:
	return _NetfoxLogger.new("netfox", p_name)

static func for_noray(p_name: String) -> _NetfoxLogger:
	return _NetfoxLogger.new("netfox.noray", p_name)

static func for_extras(p_name: String) -> _NetfoxLogger:
	return _NetfoxLogger.new("netfox.extras", p_name)

static func make_setting(name: String) -> Dictionary:
	return {
		"name": name,
		"value": DEFAULT_LOG_LEVEL,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "All,Trace,Debug,Info,Warning,Error,None"
	}

static func _static_init():
	log_level = ProjectSettings.get_setting("netfox/logging/log_level", DEFAULT_LOG_LEVEL)
	module_log_level = {
		"netfox": ProjectSettings.get_setting("netfox/logging/netfox_log_level", DEFAULT_LOG_LEVEL),
		"netfox.noray": ProjectSettings.get_setting("netfox/logging/netfox_noray_log_level", DEFAULT_LOG_LEVEL),
		"netfox.extras": ProjectSettings.get_setting("netfox/logging/netfox_extras_log_level", DEFAULT_LOG_LEVEL)
	}

func _init(p_module: String, p_name: String):
	module = p_module
	name = p_name

func _check_log_level(level: int) -> bool:
	var cmp_level = log_level
	if level < cmp_level:
		return false
	
	if module_log_level.has(module):
		var module_level = module_log_level.get(module)
		return level >= module_level
	
	return true

func _format_text(text: String, values: Array, level: int) -> String:
	level = clampi(level, LOG_MIN, LOG_MAX)
	var peer_id := NetworkEvents.multiplayer.get_unique_id()
	var tick := NetworkTime.tick
	
	var prefix := "[%s][@%s][#%s][%s::%s] " % [level_prefixes[level], tick, peer_id, module, name]
	
	if values.is_empty():
		return prefix + text
	else:
		return prefix + (text % values)

func _log_text(text: String, values: Array, level: int):
	if _check_log_level(level):
		print(_format_text(text, values, level))

func trace(text: String, values: Array = []):
	_log_text(text, values, LOG_TRACE)

func debug(text: String, values: Array = []):
	_log_text(text, values, LOG_DEBUG)

func info(text: String, values: Array = []):
	_log_text(text, values, LOG_INFO)

func warning(text: String, values: Array = []):
	if _check_log_level(LOG_WARN):
		var formatted_text = _format_text(text, values, LOG_WARN)
		push_warning(formatted_text)
		# Print so it shows up in the Output panel too
		print(formatted_text)

func error(text: String, values: Array = []):
	if _check_log_level(LOG_ERROR):
		var formatted_text = _format_text(text, values, LOG_ERROR)
		push_error(formatted_text)
		# Print so it shows up in the Output panel too
		print(formatted_text)
