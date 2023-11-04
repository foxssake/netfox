extends Node
class_name BaseNetInput

## Base class for Input nodes used with rollback.
##
## During rollback, multiple logical ticks are simulated in the span of a single
## actual tick. Since these are just logical ticks, no actual input arrives
## during them from the input devices.
##
## The solution is to gather input before the tick loop, and use that input for
## any new ticks simulated during the rollback.
##
## This class provides a layer of convenience, since the only thing to do here
## is to implement the [code]_gather[/code] method. This method is responsible
## for setting all the properties that you have specified in [RollbackSynchronizer]
## as input.

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
