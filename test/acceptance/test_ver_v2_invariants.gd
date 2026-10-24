extends GutTest
## Doğrulama (T20261024-65) (a), gate'te kısaltılmış sürüm: iki karakter × 3 politika × 3 tohum × 2400 adım ölümsüz
## koşu, her 60 adımda `check_invariants()` boş; aynı tohum iki koşu aynı `state_hash` (iki karakterle determinizm);
## iki karakter birbirinden farklı koşu üretir. Uzun varyant: test/long/test_ver_v2_long.gd (verify_long.sh).

const STEPS := 2400
const SEEDS := [31, 32, 33]


func test_ver_both_characters_keep_invariants_clean_on_all_policies() -> void:
	for cid in VerV2Run.CHARACTERS:
		for policy in Bots.POLICIES:
			for sd in SEEDS:
				var r := (
					VerV2Run
					. run(
						{
							"seed": sd,
							"policy": policy,
							"character": cid,
							"max_steps": STEPS,
							"check_every": 60,
							"godmode": true,
						}
					)
				)
				var tag := "%s/%s/tohum %d" % [cid, policy, sd]
				assert_eq(r["violations"], PackedStringArray(), "değişmez ihlali " + tag)
				assert_eq(int(r["steps"]), STEPS, "tam koşu " + tag)
				assert_gte(int(r["checks"]), STEPS / 60, "her 60 adımda denetim " + tag)


func test_ver_same_seed_same_state_hash_per_character() -> void:
	for cid in VerV2Run.CHARACTERS:
		for policy in Bots.POLICIES:
			var a := VerV2Run.run(
				{"seed": 41, "policy": policy, "character": cid, "max_steps": STEPS}
			)
			var b := VerV2Run.run(
				{"seed": 41, "policy": policy, "character": cid, "max_steps": STEPS}
			)
			assert_eq(
				a["state_hash"], b["state_hash"], "aynı tohum aynı hash %s/%s" % [cid, policy]
			)
			assert_eq(a["steps"], b["steps"], "aynı adım sayısı %s/%s" % [cid, policy])


func test_ver_tracker_attached_does_not_change_state_hash_with_either_character() -> void:
	for cid in VerV2Run.CHARACTERS:
		for policy in Bots.POLICIES:
			var bare := VerV2Run.run(
				{"seed": 42, "policy": policy, "character": cid, "max_steps": STEPS}
			)
			var obs := (
				VerV2Run
				. run(
					{
						"seed": 42,
						"policy": policy,
						"character": cid,
						"max_steps": STEPS,
						"tracker": true,
					}
				)
			)
			assert_eq(
				bare["state_hash"],
				obs["state_hash"],
				"gözlemci hash'i değiştirmez %s/%s" % [cid, policy]
			)


func test_ver_characters_produce_different_runs_with_expected_stats() -> void:
	var g := VerV2Run.run(
		{"seed": 43, "policy": &"kite", "character": &"gunslinger", "max_steps": 600}
	)
	var b := VerV2Run.run({"seed": 43, "policy": &"kite", "character": &"zyfen", "max_steps": 600})
	assert_ne(g["state_hash"], b["state_hash"], "iki karakter aynı koşuyu üretmemeli")
	assert_eq(int(b["steps"]), 600)
