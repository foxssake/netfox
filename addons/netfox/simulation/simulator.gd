@tool
extends Node
class_name Simulator

## Simulates for the ticks clients dont have information yet.
## [br][br]
## [Simulator] doesnt participate in RollBack at all, and will simulate only on local clients. [br]
## Its good idea to use [Simulator] whenever you want to give control of something to local player.

## The root node for resolving node paths in properties. Defaults to the parent node.
@export var root: Node = get_parent()

@export_group("State")
## Properties that define the game state.
## [br][br]
## State properties are recorded for each tick.
## State is restored when server broadcasts truth, [Simulator] then will accept this
## as true state and apply it. Only then if we have inputs for future ticks it will simulate them.
@export var state_properties: Array[String]

@onready var _logger: NetfoxLogger = NetfoxLogger._for_netfox("Simulator:" + root.name)

var _input_properties := _PropertyPool.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync
