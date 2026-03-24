extends VestTest

func get_suite_name() -> String:
	return "RollbackLivenessServer"

var liveness_server: _RollbackLivenessServer
var subject: LivenessAwareNode

var spawn_tick := 1
var death_tick := 4

func before_case(__) -> void:
	liveness_server = _RollbackLivenessServer.new()
	subject = LivenessAwareNode.new()

func after_case(__) -> void:
	liveness_server.queue_free()
	subject.queue_free()

func suite() -> void:
	define("is_alive()", func():
		test("unknown subject should be alive", func():
			# Subject is not registered
			expect_true(liveness_server.is_alive(subject, spawn_tick))
		)

		test("subject without despawn", func():
			register_subject(subject)
			expect(liveness_server.is_alive(subject, spawn_tick), "Should be alive on spawn tick!")
			expect(liveness_server.is_alive(subject, spawn_tick + 1), "Should be alive after spawn tick!")
			expect_not(liveness_server.is_alive(subject, spawn_tick - 1), "Should be dead before spawn tick!")
		)

		test("subject with spawn and despawn", func():
			register_subject(subject)
			liveness_server.despawn(subject, death_tick)

			expect(liveness_server.is_alive(subject, spawn_tick), "Should be alive on spawn tick!")
			expect(liveness_server.is_alive(subject, spawn_tick + 1), "Should be alive after spawn tick!")
			expect_not(liveness_server.is_alive(subject, spawn_tick - 1), "Should be dead before spawn tick!")

			expect(liveness_server.is_alive(subject, death_tick), "Should be alive on despawn tick!")
			expect(liveness_server.is_alive(subject, death_tick - 1), "Should be alive before despawn tick!")
			expect_not(liveness_server.is_alive(subject, death_tick + 1), "Should be dead after despawn tick!")
		)

		test("single-tick subject", func():
			register_subject(subject)
			liveness_server.despawn(subject, spawn_tick)

			expect(liveness_server.is_alive(subject, spawn_tick), "Should be alive on spawn tick!")
			expect_not(liveness_server.is_alive(subject, spawn_tick + 1), "Should be dead after spawn tick!")
			expect_not(liveness_server.is_alive(subject, spawn_tick - 1), "Should be dead before spawn tick!")
		)
	)

	define("restore_liveness()", func():
		test("should despawn alive", func():
			register_subject(subject)
			liveness_server.despawn(subject, death_tick)

			liveness_server.restore_liveness(death_tick + 1)
			expect_not(subject.is_alive, "Subject should be dead!")
			expect_equal(subject.despawns, 1, "Subject should have been despawned once!")
			expect_equal(subject.spawns, 0, "Subject should not have been respawned!")
		)

		test("should spawn dead", func():
			register_subject(subject)
			liveness_server.despawn(subject, death_tick)

			liveness_server.restore_liveness(death_tick + 1)
			liveness_server.restore_liveness(death_tick - 1)

			expect(subject.is_alive, "Subject should be alive!")
			expect_equal(subject.despawns, 1, "Subject should have been despawned once!")
			expect_equal(subject.spawns, 1, "Subject should have been respawned once!")
		)

		test("should not spawn alive", func():
			register_subject(subject)
			liveness_server.despawn(subject, death_tick)

			liveness_server.restore_liveness(death_tick - 1)

			expect(subject.is_alive, "Subject should be alive!")
			expect_equal(subject.despawns, 0, "Subject should not have been despawned!")
			expect_equal(subject.spawns, 0, "Subject should not have been respawned!")
		)

		test("should not despawn dead", func():
			register_subject(subject)
			liveness_server.despawn(subject, death_tick)

			liveness_server.restore_liveness(death_tick + 1)
			liveness_server.restore_liveness(death_tick + 2)

			expect_not(subject.is_alive, "Subject should be dead!")
			expect_equal(subject.despawns, 1, "Subject should have been despawned once!")
			expect_equal(subject.spawns, 0, "Subject should not have been respawned!")
		)
	)

	define("free_old_subjects()", func():
		test("should not free young subject", func():
			register_subject(subject)

			liveness_server.free_old_subjects(spawn_tick)
			expect_not(subject.is_destroyed, "Should not free subject!")
		)

		test("should free old subject", func():
			register_subject(subject)
			liveness_server.despawn(subject, death_tick)

			liveness_server.free_old_subjects(death_tick + 1)
			expect(subject.is_destroyed, "Should free subject!")
		)
	)

func register_subject(p_subject: LivenessAwareNode, p_spawn_tick: int = spawn_tick) -> void:
	liveness_server.register(p_subject, p_subject._rollback_spawn, p_subject._rollback_despawn, p_subject._rollback_destroy, p_spawn_tick)

class LivenessAwareNode extends Node:
	var is_alive := true
	var is_destroyed := false

	var spawns := 0
	var despawns := 0

	func _rollback_spawn() -> void:
		is_alive = true
		spawns += 1

	func _rollback_despawn() -> void:
		is_alive = false
		despawns += 1

	func _rollback_destroy() -> void:
		is_destroyed = true
