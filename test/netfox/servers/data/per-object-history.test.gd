extends VestTest

func get_suite_name() -> String:
	return "_PerObjectHistory"

func suite() -> void:
	define("truncate_after()", func():
		test("should ignore unknown subject", func():
			var history := _PerObjectHistory.new(16)
			var subject := Node.new()
			
			history.truncate_after(2, subject)
			expect_does_not_contain(history.subjects(), subject)
			
			subject.queue_free()
		)
		
		test("should truncate", func(): 
			var history := _PerObjectHistory.new(16)
			var subject := Node.new()
			
			history.set_property(0, subject, "hp", 12.)
			history.set_property(1, subject, "hp", 16.)
			history.set_property(2, subject, "hp", 20.)
			history.set_property(3, subject, "hp", 24.)
			
			history.truncate_after(2, subject)
			
			expect_contains(history.subjects(), subject)
			expect_equal(history.get_latest_tick(4, subject), 2)
			
			subject.queue_free()
		)
	)
