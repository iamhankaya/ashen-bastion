extends GutTest
## Doğrulama (T20261023-98): v1.1 paketinin bütünlüğü — dilim simgeleri, kabul dosyaları, tek gerekçeli pending (A19),
## A/B verisi (≥100 tohum) ve kullanıcı doğrulama listesi belgeleri.

const ACC_DIR := "res://test/acceptance/"
const ACC_FILES := [
	"anim",
	"bomb",
	"budget",
	"buffs",
	"determinism",
	"enemy_anim",
	"flow",
	"highscores",
	"pickups",
	"score",
	"tables",
	"ui",
	"ui_logic",
]
const AB_DATA := "res://docs/dev/v1.1-ab-data.json"
const VERIFY_DOC := "res://docs/dev/user-verify.md"
const VERIFY_KEYWORDS := [
	"view_ms",
	"çentik",
	"gölge",
	"1,3",
	"1,8",
	"halka",
	"sarsıntı",
	"F-021",
	"ikon",
	"∞",
	"kupa",
	"highscores.json",
	"omuz",
	"36 px",
]


func test_all_four_slices_are_marked_done() -> void:
	for id in ["D1", "D2", "D3", "D4"]:
		assert_true(V11Slice.done(id), "dilim %s tools/v11_slices.txt içinde" % id)


func test_every_v11_acceptance_file_exists() -> void:
	for n in ACC_FILES:
		assert_true(FileAccess.file_exists(ACC_DIR + "test_acc_v11_%s.gd" % n), n)


func test_only_a19_may_be_pending_in_v11_acceptance_files() -> void:
	var pending_sites: Array[String] = []
	for n in ACC_FILES:
		var src := FileAccess.get_file_as_string(ACC_DIR + "test_acc_v11_%s.gd" % n)
		var lines := src.split("\n")
		for i in lines.size():
			if lines[i].strip_edges().begins_with("pending("):
				pending_sites.append("%s:%d" % [n, i + 1])
	assert_eq(pending_sites.size(), 1, "tek koşullu pending: %s" % str(pending_sites))
	assert_true(pending_sites[0].begins_with("enemy_anim:"), "A19 (gerçek piyade karesi yok)")


func test_ab_data_covers_at_least_100_seeds_per_arm_and_policy() -> void:
	assert_true(FileAccess.file_exists(AB_DATA), "docs/dev/v1.1-ab-data.json")
	if not FileAccess.file_exists(AB_DATA):
		return
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(AB_DATA))
	var seeds := {}
	for r in rows:
		var k := "%s/%s" % [r["policy"], r["pickups"]]
		if not seeds.has(k):
			seeds[k] = {}
		seeds[k][int(r["seed"])] = true
		assert_eq((r["violations"] as Array).size(), 0, "A/B koşusu değişmez ihlali: %s" % k)
	for k in [
		"idle/true",
		"idle/false",
		"kite/true",
		"kite/false",
		"greedy/true",
		"greedy/false",
		"greedy_pickup/true"
	]:
		assert_true(seeds.has(k), "kol var: " + k)
		if seeds.has(k):
			assert_gte((seeds[k] as Dictionary).size(), 100, "≥100 tohum: " + k)


func test_user_verify_has_a_v11_section_with_every_required_item() -> void:
	var src := FileAccess.get_file_as_string(VERIFY_DOC)
	assert_true(src.contains("# v1.1 cihaz kontrol listesi"), "v1.1 bölümü")
	var v11 := src.substr(src.find("# v1.1 cihaz kontrol listesi"))
	for k in VERIFY_KEYWORDS:
		assert_true(v11.contains(k), "kullanıcı listesinde: " + k)
