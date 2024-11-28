extends Object
class_name NetworkClocks

class SystemClock:
	var offset: float = 0.
	
	func get_raw_time() -> float:
		return Time.get_unix_time_from_system()
	
	func get_time() -> float:
		return get_raw_time() + offset
	
	func adjust(p_offset: float):
		offset += p_offset
	
	func set_time(p_time: float):
		offset = p_time - get_raw_time()

class SteppingClock:
	var time: float = 0.
	var last_step: float = get_raw_time()
	
	func get_raw_time() -> float:
		return Time.get_unix_time_from_system()
		
	func get_time() -> float:
		return time
	
	func adjust(p_offset: float):
		time += p_offset
	
	func set_time(p_time: float):
		last_step = get_raw_time()
		time = p_time
	
	func step(p_multiplier: float = 1.):
		var current_step = get_raw_time()
		var step_duration = current_step - last_step
		last_step = current_step

		adjust(step_duration * p_multiplier)
