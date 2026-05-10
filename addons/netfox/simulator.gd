@tool
extends Node
class_name Simulator

## @experimental [Simulator] name is a wip. [br]
## Simulates network logic depending on network authority. Make sure to read
## them before using [Simulator].[br]
##
## There are 3 seperate workflows [Simulator] operate on. [br][br]
##
## 1- Host - this [Simulator] has network authority, but [InputSender]'s
## input_node (your custom player_input.gdcript code) belongs to some other peer.
## This would be your typical server (host) but doesnt have to be if you are going
## for some custom solution (example: mesh network).[br]
##
## On host [Simulator] runs _simulated_tick functions with new inputs which
## is received by [InputSender]. After running _simulated_tick with new received
## inputs, [Simulator] broadcasts ground truth (state properties) to peers.
## Use this to code game logic that must run on host. If you would like to code
## additional host side logic (example: changing team only on host) you can check
## if its host or not in _simulated_tick. [br][br]
##
## 2- Authoritative peer - this [Simulator] doesnt have network authority, but
## [InputSender]s input_node (your custom player_input.gdscript code) belongs to
## local peer. This would be your typical player. [br]
##
## On authoritative peer, [Simulator] runs _simulated_tick with [InputSender]'s
## fresh local inputs (inputs that may or may not have been sent to server at this point).
## Upon receiving ground truth from host, [Simulator] compares difference in state
## and decide whether to use snapping or interpolating depending on threshold.
## After applying true state, [Simulator] re-runs _simulated_tick to reach current
## game state. [br][br]
##
## 3- Puppet peer - both [Simulator] and [InputSender]s input_node (your custom
## player_input.gdscript code) doesnt have authority. This is how you see remote
## players when you are playing the game. For example your friend is a puppet player
## in your game. [br]
##
## On puppet peers, [Simulator] only applies truth received from host and interpolate
## it. For most games this will be enough. Even with [InputSender] broadcast toggled on from
## project settings, there is no point in re-running _simulated_ticks because server
## sends states with inputs at the same time. For puppet peers we simply dont know 
## their future inputs. [br][br]
##
##
## TODO: Simulator can have option to predict if input_broadcast is on for inputsender. [br]
##
## TODO: what about physics and physic stepping? [br]
## It can be coded with _simulated_ticks if you involve some local properties to script
## that has role in godots _physics_process. If we can avoid coding physic stepping we should.

## The root node for resolving node paths in properties. Defaults to the parent node.
@export var root: Node = get_parent()

## [Simulator] needs [InputSender] assigned to work with at the first place.
## Any authority change to [InputSender]'s input node (example PlayerInput) requires
## calling [method Simulator.process_settings].
## Changing or assigning [InputSender] during runtime is not recommended by design, but also
## requires call to [method Simulator.process_settings].
@export var listened_input_sender : InputSender = null

## If true, [Simulator] will run _simulated_tick functions with fresh received inputs.
## Set this to true, if you want to code host side logic with client inputs.
## For example: moving a vehicle on server with client inputs.
## NOTE: Dont get confused, if host is also player and owner of [InputSender]
## [Simulator] will run _simulated_tick even though this set to false (default).
@export var simulate_on_host := false

## If enabled, takes a snapshot immediately upon instantiation, instead of
## waiting for the first network tick. Useful for objects that start moving
## instantly, like projectiles.
@export var record_first_state: bool = true

@export_group("State")
## Properties that define the game state.
## [br][br]
## State properties are recorded for each tick.
## State is restored when host broadcasts truth, [Simulator] then will accept this
## as true state and apply it.[Simulator] will call _simulated_tick for the t.
@export var state_properties: Array[String]

@onready var _logger: NetfoxLogger = NetfoxLogger._for_netfox("Simulator:" + root.name)


var _input_properties := _PropertyPool.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync
