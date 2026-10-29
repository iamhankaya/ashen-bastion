extends GutTest
## AchievementProgressView (R1): CharacterRoster'ın baktığı salt okuma görünüm; null/bozuk depo güvenli yönde kilitli.


class _OpenStore:
	extends AchievementStore
	var open_ids: Array = []

	func is_unlocked(id: StringName) -> bool:
		return open_ids.has(id)


func _store(ids: Array, bad: bool = false) -> AchievementStore:
	var s := _OpenStore.new()
	s.open_ids = ids
	s.corrupt = bad
	return s


func test_null_store_is_corrupt_and_everything_locked() -> void:
	var v := AchievementProgressView.of_store(null)
	assert_true(v.corrupt)
	assert_false(v.is_unlocked(&"herhangi"))


func test_store_view_follows_unlocked_ids() -> void:
	var v := AchievementProgressView.of_store(_store([&"a"]))
	assert_false(v.corrupt)
	assert_true(v.is_unlocked(&"a"))
	assert_false(v.is_unlocked(&"b"))


func test_corrupt_store_locks_even_unlocked_ids() -> void:
	var v := AchievementProgressView.of_store(_store([&"a"], true))
	assert_true(v.corrupt)
	assert_false(v.is_unlocked(&"a"))


func test_of_accepts_view_store_or_null() -> void:
	var v := AchievementProgressView.of_store(_store([&"a"]))
	assert_same(AchievementProgressView.of(v), v)
	assert_true(AchievementProgressView.of(_store([&"a"])).is_unlocked(&"a"))
	assert_true(AchievementProgressView.of(null).corrupt)


func test_view_reads_the_unlocked_dictionary_of_a_plain_store() -> void:
	var s := AchievementStore.new()
	s.unlocked[&"a"] = 1
	var v := AchievementProgressView.of_store(s)
	assert_true(v.is_unlocked(&"a"))
	assert_false(v.is_unlocked(&"b"))
