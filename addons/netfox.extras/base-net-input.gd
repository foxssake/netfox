extends Node
class_name BaseNetInput

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
func _gather():
	pass
