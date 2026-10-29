extends GutTest
## Karakterizasyon (refactor güvenlik ağı, T20261028-35, plan Faz 4 madde 1 ve 5): statik/global durum sızıntısı.
## R9c (EnemyEscape bayrağı/sayacı artık sim örneğinde, Targeting tamponu havuzda) ve R6a (GameData._default) bu testlere karşı yeşil kalır.
## Yalnız ilişkisel iddialar: mutlak hash yok (mutlak değerler golden_hashes.json'da); Godot sürümünden bağımsız.
## Her hash dizisi her 60 adımda örneklenir (ara hash), son durum + RNG durumları ayrı alanlardır.

const SEED_A := 4101
const SEED_B := 4102
const STEPS := 900
const EVERY := 60


func _make(seed_value: int, escape: bool = true) -> GameSim:
	return GameSim.new(
		seed_value,
		&"gunslinger",
		{"data": GameData.load_default(), "log_events": false, "escape_enabled": escape}
	)


## Tek adım; seviye atlama bekliyorsa ilk kart seçilir (adım sayılmaz). Dönüş: ilerleme oldu mu.
func _advance(sim: GameSim, n: int) -> bool:
	if sim.state == GameSim.State.LEVEL_UP:
		sim.choose(0)
		return true
	if sim.state != GameSim.State.RUNNING:
		return false
	sim.step(GoldenKit.move_at(n))
	return true


## `steps` adım ilerler; her EVERY adımda state_hash kaydeder. Son iz: [ara hash'ler..., rng_combat, step_count].
func _trail(sim: GameSim, steps: int, start: int = 0, toggle_at: int = -1) -> Array:
	var out: Array = []
	var n := start
	while n < start + steps:
		if toggle_at >= 0 and n == toggle_at:
			sim.enemies.escape_enabled = not sim.enemies.escape_enabled
		if not _advance(sim, n):
			break
		if sim.state != GameSim.State.LEVEL_UP:
			n += 1
		if n % EVERY == 0 and sim.state != GameSim.State.LEVEL_UP:
			out.append(sim.state_hash())
	out.append(str(sim.rng_combat.state))
	out.append(sim.step_count)
	return out


func test_rf_trail_is_nontrivial() -> void:
	var t := _trail(_make(SEED_A), STEPS)
	assert_gte(t.size(), STEPS / EVERY, "ara hash'ler üretildi")
	assert_ne(t[0], t[1], "ara hash'ler ilerledikçe değişir")


func test_rf_escape_enabled_and_disabled_are_each_deterministic() -> void:
	var on1 := _trail(_make(SEED_A), STEPS)
	var on2 := _trail(_make(SEED_A), STEPS)
	assert_eq(on1, on2, "açık: aynı tohum aynı iz")
	var off1 := _trail(_make(SEED_A, false), STEPS)
	var off2 := _trail(_make(SEED_A, false), STEPS)
	assert_eq(off1, off2, "kapalı: aynı tohum aynı iz")


func test_rf_escape_toggle_mid_run_is_deterministic() -> void:
	var a := _trail(_make(SEED_A), STEPS, 0, 300)
	var b := _trail(_make(SEED_A), STEPS, 0, 300)
	assert_eq(a, b, "çalışma anında değiştirme: aynı noktada aynı sonuç")


func test_rf_second_sim_in_same_process_is_not_affected_by_first() -> void:
	var solo := _trail(_make(SEED_A), STEPS)
	var other := _trail(_make(SEED_B), STEPS)  # araya başka koşu
	var again := _trail(_make(SEED_A), STEPS)
	assert_ne(other, solo, "araya giren koşu farklı tohum: farklı iz")
	assert_eq(
		again, solo, "ardışık koşular birbirinden sızıntısız (Targeting/EnemyEscape/GameData)"
	)


func test_rf_interleaved_sims_match_their_solo_runs() -> void:
	var solo_a := _trail(_make(SEED_A), STEPS)
	var solo_b := _trail(_make(SEED_B), STEPS)
	var a := _make(SEED_A)
	var b := _make(SEED_B)
	var ta: Array = []
	var tb: Array = []
	var na := 0
	var nb := 0
	while na < STEPS or nb < STEPS:
		# a ve b aralıklı: 7'şer adım (seviye atlamada kart seçimi adım saymaz)
		for _k in 7:
			if na < STEPS and _advance(a, na) and a.state != GameSim.State.LEVEL_UP:
				na += 1
				if na % EVERY == 0:
					ta.append(a.state_hash())
		for _k in 7:
			if nb < STEPS and _advance(b, nb) and b.state != GameSim.State.LEVEL_UP:
				nb += 1
				if nb % EVERY == 0:
					tb.append(b.state_hash())
		if a.state >= GameSim.State.WON and b.state >= GameSim.State.WON:
			break
	ta.append(str(a.rng_combat.state))
	ta.append(a.step_count)
	tb.append(str(b.rng_combat.state))
	tb.append(b.step_count)
	assert_eq(ta, solo_a, "iç içe A = tek başına A")
	assert_eq(tb, solo_b, "iç içe B = tek başına B")


func test_rf_escape_begun_is_per_run_and_does_not_feed_hash() -> void:
	var s1 := _make(SEED_A)
	var t1 := _trail(s1, STEPS)
	var s2 := _make(SEED_A)
	s2.enemies.escape_begun = 12345
	var t2 := _trail(s2, STEPS)
	assert_eq(t1, t2, "escape_begun başlangıç değeri hash'i etkilemez")
	assert_eq(_make(SEED_B).enemies.escape_begun, 0, "yeni sim sayacı sıfırdan başlar")
	assert_gte(s2.enemies.escape_begun, 12345, "sayaç koşu boyunca birikir (azalmaz)")
	assert_eq(s2.enemies.escape_begun - 12345, s1.enemies.escape_begun, "aynı koşu aynı sayı")


func test_rf_enabled_flag_is_per_sim_and_independent() -> void:
	var s1 := _make(SEED_A, false)
	var s2 := _make(SEED_B)
	assert_false(s1.enemies.escape_enabled)
	assert_true(s2.enemies.escape_enabled, "bir sim'in bayrağı ötekini etkilemez")
	var t1 := _trail(s1, 120)
	var t2 := _trail(s2, 120)
	assert_ne(t1, t2, "iki farklı tohum farklı iz")
	assert_false(s1.enemies.escape_enabled, "koşu bayrağı değiştirmez")
