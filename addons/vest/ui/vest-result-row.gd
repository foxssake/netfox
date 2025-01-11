@tool
extends Control
class_name VestResultRow

var _result: VestTest.Result

func set_result(result: VestTest.Result):
	_result = result
	update()

func update():
	pass
