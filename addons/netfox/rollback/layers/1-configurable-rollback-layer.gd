extends "res://addons/netfox/rollback/layers/0-base-rollback-synchronizer.gd"

var _state_property_config: _PropertyConfig = _PropertyConfig.new()
var _input_property_config: _PropertyConfig = _PropertyConfig.new()
var _nodes: Array[Node] = []

func _get_recorded_state_props() -> Array[PropertyEntry]:
	return _state_property_config.get_properties()

func _get_owned_state_props() -> Array[PropertyEntry]:
	return _state_property_config.get_owned_properties()

func _get_recorded_input_props() -> Array[PropertyEntry]:
	return _input_property_config.get_owned_properties()

func _get_owned_input_props() -> Array[PropertyEntry]:
	return _input_property_config.get_owned_properties()
