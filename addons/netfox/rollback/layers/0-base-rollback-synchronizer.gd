extends Node

## The root node for resolving node paths in properties. Defaults to the parent
## node.
@export_category("Rollback Synchronizer")
@export var root: Node = get_parent()

var _states := _PropertyHistoryBuffer.new()
var _inputs := _PropertyHistoryBuffer.new()

var _property_cache := PropertyCache.new(root)

var _is_initialized: bool = false

static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("RollbackSynchronizer")

func process_settings() -> void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync

	process_settings.call_deferred()

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync
	_connect_signals.call_deferred()
	process_settings.call_deferred()

func _exit_tree() -> void:
	if Engine.is_editor_hint(): return

	# _is_initialized = false # TODO
	_disconnect_signals()

func _connect_signals() -> void:
	pass

func _disconnect_signals() -> void:
	pass
