extends GutTest
## SimSignalBinder (R4): bağlama tablo sırasıyla, release eski sim'i temizler, null sim hiçbir şey bağlamaz.

var _hits: Array = []


func _on_damaged(_amount: float, _hp: float) -> void:
	_hits.append("damaged")


func _on_ended(_won: bool, _stats: Dictionary) -> void:
	_hits.append("ended")


func _binder() -> SimSignalBinder:
	return (
		SimSignalBinder
		. new(
			[
				[&"player_damaged", Callable(self, &"_on_damaged")],
				[&"run_ended", Callable(self, &"_on_ended")],
			]
		)
	)


func _sim() -> GameSim:
	return GameSim.new(11, &"gunslinger", {"end_mode": "lord"})


func test_rf4_attach_connects_every_pair() -> void:
	var b := _binder()
	var sim := _sim()
	b.attach(sim)
	assert_true(sim.bus.is_connected(&"player_damaged", Callable(self, &"_on_damaged")))
	assert_true(sim.bus.is_connected(&"run_ended", Callable(self, &"_on_ended")))
	sim.bus.player_damaged.emit(1.0, 2.0)
	assert_eq(_hits, ["damaged"])


func test_rf4_release_disconnects_the_old_sim_only() -> void:
	var b := _binder()
	var old := _sim()
	b.attach(old)
	b.release()
	var fresh := _sim()
	b.attach(fresh)
	assert_false(old.bus.is_connected(&"player_damaged", Callable(self, &"_on_damaged")))
	assert_false(old.bus.is_connected(&"run_ended", Callable(self, &"_on_ended")))
	assert_true(fresh.bus.is_connected(&"run_ended", Callable(self, &"_on_ended")))


func test_rf4_null_sim_binds_nothing_and_release_is_idempotent() -> void:
	var b := _binder()
	b.attach(null)
	b.release()
	b.release()
	var sim := _sim()
	b.attach(sim)
	b.release()
	b.release()
	assert_false(sim.bus.is_connected(&"run_ended", Callable(self, &"_on_ended")))
