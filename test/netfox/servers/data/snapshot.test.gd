extends VestTest

func get_suite_name() -> String:
	return "Snapshot"

func suite() -> void:
	var node := Node3D.new()
	var other_node := Node3D.new()

	define("make_patch()", func():
		test("should return empty on same", func():
			var snapshot := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[node, "scale", Vector3.ONE]
			], [node])

			expect_empty(_Snapshot.make_patch(snapshot, snapshot))
		)

		test("should include differing property", func():
			var from := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[node, "scale", Vector3.ONE]
			], [node])

			var to := _Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[node, "scale", Vector3.ONE]
			], [node])

			var expected := _Snapshot.of(0, [
				[node, "position", Vector3.ONE]
			], [node])

			expect_equal(_Snapshot.make_patch(from, to), expected)
		)

		test("should include new property", func():
			var from := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO]
			], [node])

			var to := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[node, "scale", Vector3.ONE]
			], [node])

			var expected := _Snapshot.of(0, [
				[node, "scale", Vector3.ONE]
			], [node])

			expect_equal(_Snapshot.make_patch(from, to), expected)
		)

		test("patch should yield `to` on merge", func():
			var from := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[node, "scale", Vector3.ONE]
			], [node])

			var to := _Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[node, "scale", Vector3.ONE]
			], [node])

			var patch := _Snapshot.make_patch(from, to)
			var applied := from.duplicate()
			applied.tick = to.tick
			applied.merge(patch)

			expect_equal(applied, to)
		)
	)

	define("merge()", func():
		test("auth should override non-auth", func():
			var snapshot := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[other_node, "position", Vector3.ZERO]
			], [])

			var patch := _Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [node])

			expect_true(snapshot.merge(patch))
			expect_equal(snapshot, _Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [node]))
		)

		test("auth should update auth", func():
			var snapshot := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[other_node, "position", Vector3.ZERO]
			], [node])

			var patch := _Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [node])

			expect_true(snapshot.merge(patch))
			expect_equal(snapshot, _Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [node]))
		)

		test("non-auth should not update auth", func():
			var snapshot := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[other_node, "position", Vector3.ZERO]
			], [node])

			var patch := _Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [])

			expect_true(snapshot.merge(patch))
			expect_equal(snapshot, _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[other_node, "position", Vector3.ONE]
			], [node]))
		)

		test("non-auth should update non-auth", func():
			var snapshot := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[other_node, "position", Vector3.ZERO]
			], [])

			var patch := _Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], [])

			expect_true(snapshot.merge(patch))
			expect_equal(snapshot, _Snapshot.of(0, [
				[node, "position", Vector3.ONE],
				[other_node, "position", Vector3.ONE]
			], []))
		)
	)

	define("erase()", func():
		test("should remove subject", func():
			var snapshot := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[node, "quaternion", Quaternion.IDENTITY],
				[other_node, "position", Vector3.ONE]
			], [])

			snapshot.erase_subject(node)

			expect_equal(snapshot, _Snapshot.of(0, [
				[other_node, "position", Vector3.ONE]
			], []))
		)

		test("should ignore unknown subject", func():
			var snapshot := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[node, "quaternion", Quaternion.IDENTITY]
			], [])

			snapshot.erase_subject(other_node)

			expect_equal(snapshot, _Snapshot.of(0, [
				[node, "position", Vector3.ZERO],
				[node, "quaternion", Quaternion.IDENTITY]
			], []))
		)
	)
