extends SnapshotSerializerTest

func get_suite_name() -> String:
	return "DenseSnapshotSerializer"

func suite() -> void:
	test("should deserialize to same", func():
		var schema := _NetworkSchema.new()
		var serializer := _DenseSnapshotSerializer.new(schema)

		var subject := Node3D.new()
		Vest.get_tree().root.add_child.call_deferred(subject)
		await subject.ready
		NetworkIdentityServer.register_node(subject)

		var snapshot := Snapshot.of(0, [
			[subject, "position", Vector3.ZERO],
			[subject, "quaternion", Quaternion.from_euler(Vector3.ONE)],
			[subject, "scale", Vector3.ONE]
		], [subject])

		var props := _PropertyPool.of([
			[subject, "position"],
			[subject, "quaternion"],
			[subject, "scale"]
		])

		var serialized := serializer.write_for(1, snapshot, props)
		var deserialized := serializer.read_from(1, props, to_buffer(serialized))

		expect_equal(deserialized, snapshot)

		Vest.message("Serialized %d props to %d bytes" % [snapshot.size(), serialized.size()])
	)
