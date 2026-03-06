extends VestTest

func get_suite_name() -> String:
	return "Snapshot"

func suite() -> void:
	var node := Node3D.new()
	var other_node := Node3D.new()

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
	
	define("merge()", func():
		test("auth should override non-auth", func():
			var snapshot := Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[other_node, "position", Vector3.ZERO]
			], [])

			var patch := Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [node])

			expect_true(snapshot.merge(patch))
			expect_equal(snapshot, Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [node]))
		)

		test("auth should update auth", func():
			var snapshot := Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[other_node, "position", Vector3.ZERO]
			], [node])

			var patch := Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [node])

			expect_true(snapshot.merge(patch))
			expect_equal(snapshot, Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [node]))
		)

		test("non-auth should not update auth", func():
			var snapshot := Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[other_node, "position", Vector3.ZERO]
			], [node])

			var patch := Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [])

			expect_true(snapshot.merge(patch))
			expect_equal(snapshot, Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[other_node, "position", Vector3.ONE]
			], [node]))
		)

		test("non-auth should update non-auth", func():
			var snapshot := Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[other_node, "position", Vector3.ZERO]
			], [])

			var patch := Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [])

			expect_true(snapshot.merge(patch))
			expect_equal(snapshot, Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], []))
		)
	)
