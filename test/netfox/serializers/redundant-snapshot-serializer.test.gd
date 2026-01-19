extends SnapshotSerializerTest

func get_suite_name() -> String:
	return "RedundantSnapshotSerializer"

func suite() -> void:
	test("should deserialize to same", func():
		var schema := _NetworkSchema.new()
		var serializer := _RedundantSnapshotSerializer.new(schema)

		var subject := Node3D.new()
		Vest.get_tree().root.add_child.call_deferred(subject)
		await subject.ready
		NetworkIdentityServer.register_node(subject)

		var snapshots := [
			Snapshot.of(0, [
				[subject, "position", Vector3(0., 0., 0.)],
				[subject, "quaternion", Quaternion.from_euler(Vector3.ONE)],
				[subject, "scale", Vector3(1., 1., 1.)]
			], [subject]),
			Snapshot.of(1, [
				[subject, "position", Vector3(1., 0., 0.)],
				[subject, "quaternion", Quaternion.from_euler(Vector3.ZERO)],
				[subject, "scale", Vector3(1., .5, 1.)]
			], [subject])
		] as Array[Snapshot]

		var props := _PropertyPool.of([
			[subject, "position"],
			[subject, "quaternion"],
			[subject, "scale"]
		])

		var serialized := serializer.write_for(1, snapshots, props)
		var deserialized := serializer.read_from(1, props, to_buffer(serialized))

		expect_equal(deserialized.size(), snapshots.size(), "Not all snapshots were deserialized!")
		for i in snapshots.size():
			expect_equal(deserialized[i], snapshots[i])

		Vest.message("Serialized %d snapshots to %d bytes" % [snapshots.size(), serialized.size()])
	)
