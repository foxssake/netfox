@tool
extends VestResultRow
class_name VestFailResultRow

@onready var type_label := %"Type Label" as Label
@onready var name_label := %"Name Label" as Label
@onready var details_toggle := %"Details Toggle" as Button
@onready var details_container := %"Details Container" as PanelContainer
@onready var details_label := %"Details Label" as Label

func _ready():
	details_toggle.pressed.connect(func():
		details_container.visible = not details_container.visible
		details_toggle.text = "▴" if details_container.visible else "▾"
	)

func update():
	type_label.text = _result.get_status_emoji()
	name_label.text = _result.case.get_display_name()
	details_label.text = "\n".join(_result.messages)
