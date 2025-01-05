@tool
extends VestResultRow
class_name VestSuccessResultRow

@onready var name_label := %"Name Label" as Label

func update():
	name_label.text = "%s - %s" % [_result.case.module, _result.case.name]
