extends RefCounted
class_name NetfoxLogger

## Logger implementation for use with netfox
##
## NetfoxLoggers implement distinct log levels. These can be used to filter
## which messages are actually emitted. All messages are output using [method 
## @GlobalScope.print]. Warnings and errors are also pushed to the debug panel,
## using [method @GlobalScope.push_warning] and [method @GlobalScope.push_error]
## respectively, if [member push_to_debugger] is enabled.
## [br][br]
## Every logger has a name, and belongs to a module. Logging level can be
## overridden per module, using [member module_log_level].
## [br][br]
## Loggers also support tags. Tags can be used to provide extra pieces of 
## information that are logged with each message. Some tags are provided by
## netfox. Additional tags can be added using [method register_tag].
##
## @tutorial(Logging Guide): https://foxssake.github.io/netfox/latest/netfox/guides/logging/


enum {
	LOG_ALL,	## Filter level to log every message
	LOG_TRACE,	## Trace logs, the most verbose level
	LOG_DEBUG,	## Debug logs
	LOG_INFO,	## Info logs
	LOG_WARN,	## Warnings
	LOG_ERROR,	## Errors
	LOG_NONE	## Filter level to log no messages
}

## Default log level to fall back on, if not configured
const DEFAULT_LOG_LEVEL := LOG_DEBUG

const _LEVEL_PREFIXES: Array[String] = [
	"",
	"TRC",
	"DBG",
	"INF",
	"WRN",
	"ERR",
	""
]

## Global logging level, used by all loggers
static var log_level: int

## Per-module logging level, used only by loggers belonging to the given module
## [br][br]
## This is a dictionary that associates module names ( strings ) to log levels
## ( int, e.g. [constant LOG_DEBUG] ).
static var module_log_level: Dictionary

## Set to true to enable calling [@GlobalScope.push_warning] and
## [@GlobalScope.push_error]
static var push_to_debugger := true

static var _tags: Dictionary = {}
static var _ordered_tags: Array[Callable] = []

## Logger module
var module: String
## Logger name
var name: String


## Register a tag
## [br][br]
## Tags are callables that provide pieces of context, included in all log
## messges. The [param tag] callable must return a string.
static func register_tag(tag: Callable, priority: int = 0) -> void:
	# Save tag
	if not _tags.has(priority):
		_tags[priority] = [tag]
	else:
		_tags[priority].push_back(tag)

	# Recalculate tag order
	_ordered_tags.clear()
	
	var prio_groups = _tags.keys()
	prio_groups.sort()

	for prio_group in prio_groups:
		var tag_group = _tags[prio_group]
		_ordered_tags.append_array(tag_group)

## Free an already registered tag
static func free_tag(tag: Callable) -> void:
	for priority in _tags.keys():
		var priority_group := _tags[priority] as Array
		priority_group.erase(tag)

		# NOTE: Arrays are passed as reference, no need to re-assign after modifying
		if priority_group.is_empty():
			_tags.erase(priority)

	_ordered_tags.erase(tag)

static func _static_init():
	log_level = ProjectSettings.get_setting(&"netfox/logging/log_level", DEFAULT_LOG_LEVEL)
	module_log_level = {
		"netfox": ProjectSettings.get_setting(&"netfox/logging/netfox_log_level", DEFAULT_LOG_LEVEL),
		"netfox.noray": ProjectSettings.get_setting(&"netfox/logging/netfox_noray_log_level", DEFAULT_LOG_LEVEL),
		"netfox.extras": ProjectSettings.get_setting(&"netfox/logging/netfox_extras_log_level", DEFAULT_LOG_LEVEL)
	}

static func _for_netfox(p_name: String) -> NetfoxLogger:
	return NetfoxLogger.new("netfox", p_name)

static func _for_noray(p_name: String) -> NetfoxLogger:
	return NetfoxLogger.new("netfox.noray", p_name)

static func _for_extras(p_name: String) -> NetfoxLogger:
	return NetfoxLogger.new("netfox.extras", p_name)

static func _make_setting(name: String) -> Dictionary:
	return {
		"name": name,
		"value": DEFAULT_LOG_LEVEL,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "All,Trace,Debug,Info,Warning,Error,None"
	}


func _init(p_module: String, p_name: String):
	module = p_module
	name = p_name

## Log a trace message
## [br][br]
## Traces are the most verbose, usually used for drilling down into very niche
## bugs.
func trace(text: String, values: Array = []):
	_log_text(text, values, LOG_TRACE)

## Log a debug message
## [br][br]
## Debug messages are verbose, usually used to reconstruct and investigate bugs.
func debug(text: String, values: Array = []):
	_log_text(text, values, LOG_DEBUG)

## Log an info message
## [br][br]
## Info messages provide general notifications about application events.
func info(text: String, values: Array = []):
	_log_text(text, values, LOG_INFO)

## Log a warning message
## [br][br]
## This is also forwarded to [method @GlobalScope.push_warning], if enabled with
## [member push_to_debugger]. Warning messages usually indicate that something
## has gone wrong, but is recoverable.
func warning(text: String, values: Array = []):
	if _check_log_level(LOG_WARN):
		var formatted_text = _format_text(text, values, LOG_WARN)
		if push_to_debugger:
			push_warning(formatted_text)

		# Print so it shows up in the Output panel too
		print(formatted_text)

## Log an error message
## [br][br]
## This is also forwarded to [method @GlobalScope.push_error], if enabled with
## [member push_to_debugger]. Error messages usually indicate an issue that
## can't be recovered from.
func error(text: String, values: Array = []):
	if _check_log_level(LOG_ERROR):
		var formatted_text = _format_text(text, values, LOG_ERROR)
		if push_to_debugger:
			push_error(formatted_text)

		# Print so it shows up in the Output panel too
		print(formatted_text)

func _check_log_level(level: int) -> bool:
	var cmp_level = log_level
	if level < cmp_level:
		return false
	
	if module_log_level.has(module):
		var module_level = module_log_level.get(module)
		return level >= module_level
	
	return true

func _format_text(text: String, values: Array, level: int) -> String:
	level = clampi(level, LOG_TRACE, LOG_ERROR)
	
	var result := PackedStringArray()
	
	result.append("[%s]" % [_LEVEL_PREFIXES[level]])
	for tag in _ordered_tags:
		result.append("[%s]" % [tag.call()])
	result.append("[%s::%s] " % [module, name])
	
	if values.is_empty():
		result.append(text)
	else:
		result.append(text % values)
	
	return "".join(result)

func _log_text(text: String, values: Array, level: int):
	if _check_log_level(level):
		print(_format_text(text, values, level))
