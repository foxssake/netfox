extends VestTestMixin

# Manages logs added using [method Vest.message]

func _init():
	super()

	on_case_finish.connect(func(_case):
		var messages := Vest._get_messages()
		if not messages.is_empty():
			_result.data["messages"] = messages
		Vest._clear_messages()
	)
