extends GutTest
## MusicPlan.track_for: hangi müzik hangi durumda; geçiş süreleri.


func test_menu_wins_over_everything() -> void:
	assert_eq(
		MusicPlan.track_for(999.0, {"in_menu": true, "won": true, "lord_alive": true}), &"menu"
	)


func test_run_start_plays_savas_1_until_600s() -> void:
	assert_eq(MusicPlan.track_for(0.0, {}), &"savas-1")
	assert_eq(MusicPlan.track_for(599.9, {"boss_alive": true}), &"savas-1")
	assert_eq(MusicPlan.track_for(600.0, {}), &"savas-2")
	assert_eq(
		MusicPlan.track_for(1100.0, {"paused": true}), &"savas-2", "duraklatma parçayı değiştirmez"
	)


func test_lord_music_and_end_screens() -> void:
	assert_eq(MusicPlan.track_for(1201.0, {"lord_alive": true}), &"kale-lordu")
	assert_eq(MusicPlan.track_for(1300.0, {"won": true, "lord_alive": true}), &"kazandin")
	assert_eq(MusicPlan.track_for(300.0, {"lost": true}), &"kaybettin")


func test_every_returned_track_is_a_known_track_with_a_file() -> void:
	for flags in [{"in_menu": true}, {}, {"won": true}, {"lost": true}, {"lord_alive": true}]:
		for t in [0.0, 700.0]:
			var tr := MusicPlan.track_for(t, flags)
			assert_true(MusicPlan.TRACKS.has(tr), "%s" % tr)
			assert_true(
				ResourceLoader.exists("res://assets/audio/music/%s.ogg" % tr), "%s dosyası yok" % tr
			)
	assert_true(ResourceLoader.exists("res://assets/audio/music/%s.ogg" % MusicPlan.STINGER))


func test_fade_durations_follow_the_plan() -> void:
	assert_eq(MusicPlan.fade_seconds(&"menu", &"savas-1"), 1.5)
	assert_eq(MusicPlan.fade_seconds(&"savas-1", &"savas-2"), 4.0)
	assert_eq(MusicPlan.fade_seconds(&"savas-2", &"kale-lordu"), 2.0)
	assert_eq(MusicPlan.fade_seconds(&"", &"menu"), 0.0, "ilk parça anında")
