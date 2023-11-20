extends Node
class_name BaseNetInput

## Base class for Input nodes used with rollback.

func _ready():
	NetworkTime.before_tick_loop.connect(func():
		if is_multiplayer_authority():
			_gather()
	)

## Method for gathering input.
##
## This method is supposed to be overridden with your input logic. The input 
## data itself may be gathered outside of this method ( e.g. gathering it over 
## multiple _process calls ), but this is the point where the input variables 
## must be set.
##
## [i]Note:[/i] This is only called for the local player's input nodes.
func _gather():
	pass
