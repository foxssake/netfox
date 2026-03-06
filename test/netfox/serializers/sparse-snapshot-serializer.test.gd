extends SnapshotSerializerTest

func get_suite_name() -> String:
	return "SparseSnapshotSerializer"

func suite() -> void:
	test("should deserialize to same", func():
		var schema := _NetworkSchema.new()
		var serializer := _SparseSnapshotSerializer.new(schema)

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

	test("should ignore unknown identifiers", func():
		var schema := _NetworkSchema.new()
		var writer_identity_server := _NetworkIdentityServer.new(TestingCommandServer.new())
		var reader_identity_server := _NetworkIdentityServer.new(TestingCommandServer.new())

		Vest.get_tree().root.add_child.call_deferred(writer_identity_server)
		Vest.get_tree().root.add_child.call_deferred(reader_identity_server)
		await writer_identity_server.ready; await reader_identity_server.ready

		var writer_serializer := _SparseSnapshotSerializer.new(schema, writer_identity_server)
		var reader_serializer := _SparseSnapshotSerializer.new(schema, reader_identity_server)

		var known_subject := await get_subject()
		var unknown_subject := await get_subject()

		var writer_props := _PropertyPool.of([[known_subject, "position"], [unknown_subject, "position"]])
		var reader_props := _PropertyPool.of([[known_subject, "position"]])

		writer_identity_server.register_node(known_subject)
		writer_identity_server.register_node(unknown_subject)

		reader_identity_server.register_node(known_subject)

		var snapshot := Snapshot.of(0, [
			[unknown_subject, "position", Vector3.ZERO],
			[known_subject, "position", Vector3.ZERO]
		], [known_subject, unknown_subject])

		var expected := Snapshot.of(0, [
			[known_subject, "position", Vector3.ZERO]
		], [known_subject])

		var serialized := writer_serializer.write_for(1, snapshot, writer_props)
		var deserialized := reader_serializer.read_from(1, reader_props, to_buffer(serialized))

		expect_equal(deserialized, expected)
	)
