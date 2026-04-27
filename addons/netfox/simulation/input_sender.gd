@tool
extends Node
class_name InputSender

## Stores inputs and sends them to server.
## [br][br]
## [InputSender] can be used alone or with [Simulator].

## The root node for resolving node paths in inputs. Defaults to the parent node.
@export var root: Node = get_parent()

@export_group("Input")
## Properties that define the input for the game simulation.
## [br][br]
## Input properties drive the simulation, which in turn results in updated state
## properties. Input is recorded after every network tick.
@export var input_properties: Array[String]

@onready var _logger: NetfoxLogger = NetfoxLogger._for_netfox("InputSender:" + root.name)

var _input_properties := _PropertyPool.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync

## Process settings.
## [br][br]
## Call this after any change to configuration. Updates based on authority too
## ( calls process_authority ).
func process_settings() -> void:
	
	# First, deregister what might be registered.
	
	
	
	pass

## Process settings based on authority.
## [br][br]
## Call this whenever the authority of any of the input nodes change.
## Make sure to do this at the same time on all peers.
func process_authority():
	# Deregister all recorded inputs
	for node in _input_properties.get_subjects():
		for property in _input_properties.get_properties_of(node):
			NetworkHistoryServer.deregister_rollback_input(node, property)
			NetworkSynchronizationServer.deregister_rollback_input(node, property)
