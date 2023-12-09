extends CheckButton

func _toggled(toggle):
	if toggle:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CONFINED)
	else:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
