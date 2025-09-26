extends Object

class PhysicsDriverToggle:
	const INACTIVE_SUFFIX := ".off"

	func get_name() -> String:
		return "???"

	func get_files() -> Array[String]:
		return []

	func get_error_messages() -> Array[String]:
		return []

	func is_enabled() -> bool:
		return get_files().any(func(it): return FileAccess.file_exists(it))

	func toggle() -> Array[String]:
		var errors := get_error_messages()
		if not errors.is_empty():
			return errors

		var enable := not is_enabled()
		
		var uid_files := get_files().map(func(it): return it + ".uid")
		var renames = (get_files() + uid_files).map(func(it):
			if enable: return [it + INACTIVE_SUFFIX, it]
			else: return [it, it + INACTIVE_SUFFIX]
		)
		
		for rename in renames:
			var result := DirAccess.rename_absolute(rename[0], rename[1])
			if result != OK:
				errors.append(
					"Failed rename \"%s\" -> \"%s\"; reason: %s" %
					[rename[0], rename[1], error_string(result)]
				)
		return errors

class Rapier2DPhysicsDriverToggle extends PhysicsDriverToggle:
	func get_name() -> String:
		return "Rapier2D"

	func get_files() -> Array[String]:
		return [
			"res://addons/netfox.extras/physics/rapier_driver_2d.gd",
		]

	func get_error_messages() -> Array[String]:
		if not ClassDB.class_exists("RapierPhysicsServer2D"):
			return ["Rapier physics is not available! Is the extension installed?"]
		return []

class Rapier3DPhysicsDriverToggle extends PhysicsDriverToggle:
	func get_name() -> String:
		return "Rapier3D"

	func get_files() -> Array[String]:
		return [
			"res://addons/netfox.extras/physics/rapier_driver_3d.gd",
		]

	func get_error_messages() -> Array[String]:
		if not ClassDB.class_exists("RapierPhysicsServer3D"):
			return ["Rapier physics is not available! Is the extension installed?"]
		return []

class GodotPhysicsDriverToggle extends PhysicsDriverToggle:
	func get_name() -> String:
		return "Godot"

	func get_files() -> Array[String]:
		return [
			"res://addons/netfox.extras/physics/godot_driver_3d.gd",
			"res://addons/netfox.extras/physics/godot_driver_2d.gd"
		]

	func get_error_messages() -> Array[String]:
		if not PhysicsServer3D.has_method("space_step") or not PhysicsServer2D.has_method("space_step"):
			return ["Physics stepping is not available! Is this the right Godot build?"]
		return []

static func all() -> Array[PhysicsDriverToggle]:
	return [
		Rapier2DPhysicsDriverToggle.new(),
		Rapier3DPhysicsDriverToggle.new(),
		GodotPhysicsDriverToggle.new()
	]
