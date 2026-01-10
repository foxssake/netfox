extends VestTest

func get_suite_name() -> String:
	return "Snapshot"

func suite() -> void:
	var node := Node3D.new()

	define("make_patch()", func():
		test("should return empty on same", func():
			var snapshot := Snapshot.new(1)
			snapshot.set_property(node, "position", Vector3.ZERO, true)
			snapshot.set_property(node, "scale", Vector3.ONE, true)
			
			expect_empty(Snapshot.make_patch(snapshot, snapshot))
		)
		
		test("should include differing property", func():
			var from := Snapshot.new(1)
			from.set_property(node, "position", Vector3.ZERO, true)
			from.set_property(node, "scale", Vector3.ONE, true)
			
			var to := Snapshot.new(2)
			to.set_property(node, "position", Vector3.ONE, true)
			to.set_property(node, "scale", Vector3.ONE, true)
			
			var expected := Snapshot.new(2)
			expected.set_property(node, "position", Vector3.ONE, true)
			
			expect_equal(Snapshot.make_patch(from, to), expected)
		)
		
		test("should include new property", func():
			var from := Snapshot.new(1)
			from.set_property(node, "position", Vector3.ZERO, true)
			
			var to := Snapshot.new(2)
			to.set_property(node, "position", Vector3.ZERO, true)
			to.set_property(node, "scale", Vector3.ONE, true)
			
			var expected := Snapshot.new(2)
			expected.set_property(node, "scale", Vector3.ONE, true)
			
			expect_equal(Snapshot.make_patch(from, to), expected)
		)
		
		test("patch should yield `to` on merge", func():
			var from := Snapshot.new(1)
			from.set_property(node, "position", Vector3.ZERO, true)
			from.set_property(node, "scale", Vector3.ONE, true)
			
			var to := Snapshot.new(2)
			to.set_property(node, "position", Vector3.ONE, true)
			to.set_property(node, "scale", Vector3.ONE, true)
			
			var patch := Snapshot.make_patch(from, to)
			var applied := from.duplicate()
			applied.tick = to.tick
			applied.merge(patch)
			
			expect_equal(applied, to)
		)
	)
