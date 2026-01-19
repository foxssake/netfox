extends VestTest

func get_suite_name() -> String:
	return "Snapshot"

func suite() -> void:
	var node := Node3D.new()

	define("make_patch()", func():
		test("should return empty on same", func():
			var snapshot := Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[node, "scale", Vector3.ONE]
			], [node])
			
			expect_empty(Snapshot.make_patch(snapshot, snapshot))
		)
		
		test("should include differing property", func():
			var from := Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[node, "scale", Vector3.ONE]
			], [node])
			
			var to := Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[node, "scale", Vector3.ONE]
			], [node])
			
			var expected := Snapshot.of(0, [
				[node, "position", Vector3.ONE]
			], [node])
			
			expect_equal(Snapshot.make_patch(from, to), expected)
		)
		
		test("should include new property", func():
			var from := Snapshot.of(0, [
				[node, "position", Vector3.ZERO]
			], [node])
			
			var to := Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[node, "scale", Vector3.ONE]
			], [node])
			
			var expected := Snapshot.of(0, [
				[node, "scale", Vector3.ONE]
			], [node])
			
			expect_equal(Snapshot.make_patch(from, to), expected)
		)
		
		test("patch should yield `to` on merge", func():
			var from := Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[node, "scale", Vector3.ONE]
			], [node])
			
			var to := Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[node, "scale", Vector3.ONE]
			], [node])
			
			var patch := Snapshot.make_patch(from, to)
			var applied := from.duplicate()
			applied.tick = to.tick
			applied.merge(patch)
			
			expect_equal(applied, to)
		)
	)
	
	define("merge_property()", func():
		test("auth should override non-auth", func(): todo())
		test("auth should update auth", func(): todo())
		test("non-auth should not update auth", func(): todo())
		test("non-auth should update non-auth", func(): todo())
	)

	define("filtered()", func():
		test("should return empty", func(): todo())
		test("should return identical", func(): todo())
		test("should remove property", func(): todo())
	)
