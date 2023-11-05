extends HSlider

func _value_changed(new_value):
	var f = new_value / 100.0
	var volume = lerp(-60, 0, f)
	var mute = f < 0.01
	
	AudioServer.set_bus_volume_db(0, volume)
	AudioServer.set_bus_mute(0, mute)
