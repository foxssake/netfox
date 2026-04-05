extends VestTest

func get_suite_name() -> String:
	return "IdentityPacketSerializer"

func suite() -> void:
	test("should deserialize to same", func():
		var serializer := _IdentityPacketSerializer.new()
		var ids := {
			"Some Node": 1,
			"Another Node": 2,
			"Some Node/Input": 3
		}
		
		var serialized := serializer.serialize(ids)
		var deserialized := serializer.deserialize(serialized)
		
		expect_equal(deserialized, ids)
	)
