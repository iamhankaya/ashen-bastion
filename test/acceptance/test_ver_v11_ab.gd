extends GutTest
## Doğrulama (T20261023-98): A/B koşucusunun (`AbRunner`) güvenilirliği. Rapor (`docs/dev/v1.1-ab-report.md`) bu koşucuyla
## üretilir; burada tanımı sınanır: determinizm, eşli tohum (eklenti bayrağı dışında aynı dünya), alan tutarlılığı.


func after_all() -> void:
	SimKit.remove_tmp()


func test_runner_is_deterministic_for_the_same_seed_and_arm() -> void:
	var o := {"seed": 31, "policy": &"greedy_pickup", "pickups": true, "max_steps": 6000}
	var a := AbRunner.run(o)
	var b := AbRunner.run(o)
	assert_eq(a["state_hash"], b["state_hash"])
	assert_eq(a["score"], b["score"])
	assert_eq(a["pickups_collected"], b["pickups_collected"])


func test_arms_share_the_world_until_the_first_pickup_matters() -> void:
	# İlk eklenti ≥ 30 sn'de doğar (P1): idle botta ilk 25 sn'de iki kol bire bir aynı (eşli karşılaştırmanın dayanağı).
	var on := AbRunner.run({"seed": 32, "policy": &"idle", "pickups": true, "max_steps": 1500})
	var off := AbRunner.run({"seed": 32, "policy": &"idle", "pickups": false, "max_steps": 1500})
	assert_eq(on["kills"], off["kills"])
	assert_eq(on["score"], off["score"])
	assert_eq(on["level"], off["level"])


func test_score_parts_sum_to_total_and_fields_are_consistent() -> void:
	var r := AbRunner.run({"seed": 33, "policy": &"kite", "max_steps": 9000})
	var sum := 0
	for k in r["score_parts"] as Dictionary:
		sum += int(r["score_parts"][k])
	assert_eq(sum, int(r["score"]), "bileşenler toplamı = skor (S8)")
	assert_lte(int(r["late_crowd_steps"]), int(r["late_steps"]))
	assert_gte(float(r["hp_min"]), 0.0)
	for k in r["buff_uptime"] as Dictionary:
		assert_lte(
			float(r["buff_uptime"][k]), float(r["time"]) + 0.1, "buff süresi koşudan uzun olamaz"
		)


func test_death_cause_is_a_real_enemy_type_when_lost_and_empty_otherwise() -> void:
	var data := GameData.load_default()
	var r := AbRunner.run({"seed": 34, "policy": &"idle"})  # hareketsiz bot erken ölür
	assert_eq(r["result"], "lost", "idle bot 25 dk içinde ölür")
	assert_true(
		data.enemy_ids.has(StringName(r["death_cause"])), "ölüm nedeni: %s" % r["death_cause"]
	)
	var alive := AbRunner.run({"seed": 34, "policy": &"idle", "max_steps": 60})
	assert_eq(alive["result"], "running")
	assert_eq(alive["death_cause"], "")


func test_ab_script_row_matches_runner_row_keys() -> void:
	# tools/balance/ab_report.py'nin okuduğu alanlar koşucuda var (alan adı kayması = sessiz boş tablo).
	var r := AbRunner.run({"seed": 35, "policy": &"greedy", "max_steps": 600})
	for k in [
		"policy",
		"seed",
		"pickups",
		"result",
		"time",
		"level",
		"kills",
		"score",
		"score_parts",
		"best_mult",
		"max_alive",
		"hp_min",
		"secs_below_half",
		"late_steps",
		"late_crowd_steps",
		"pickups_collected",
		"buff_uptime",
		"death_cause",
		"violations",
	]:
		assert_true(r.has(k), "alan: %s" % k)
