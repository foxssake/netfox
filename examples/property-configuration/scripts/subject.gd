@tool
extends "res://examples/property-configuration/scripts/base-subject.gd"

var health := 100

func _get_synchronized_state_properties() -> Array[String]:
	var props := super()
	props.push_back("health")
	
	return props
