extends Object
class_name SnapshotFixtures

static func state_snapshot(p_position: Vector3 = Vector3.ONE) -> _PropertySnapshot:
	return _PropertySnapshot.from_dictionary({
		":position": p_position,
		":velocity": Vector3.ZERO,
		":health": 100.
	})

static func input_snapshot(p_movement: Vector3 = Vector3.ONE) -> _PropertySnapshot:
	return _PropertySnapshot.from_dictionary({
		"Input:movement": p_movement,
		"Input:is_jumping": false
	})

static func input_node() -> InputNode:
	var result := InputNode.new()
	result.name = "Input"
	return result

class InputNode extends Node:
	var movement := Vector3.ZERO
	var is_jumping := false
