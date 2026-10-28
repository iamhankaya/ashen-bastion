class_name V21RefKit
extends RefCounted
## v2.1 K-C10 (b): geç oyun referans karmaları. Senaryo = start_time'dan başlayan sabit hareket betiği, ölmez oyuncu; Lord doğuşu (1200) ve
## Lord ile temas hasarı kapsanır. Kayıt DEĞİŞMEMİŞ (v2.0.4) kodda tools/golden/gen_v21_ref.gd ile üretilir
## (.github/workflows/golden_ref.yml); U2 sonrası aynı karmalar korunmalıdır. Bu dosya ve gen_v21_ref.gd yalnız GameSim/GoldenKit'e bağlıdır.

const FIXTURE := "res://test/fixtures/golden_v20_ref/ref.json"
## [tohum, start_time, adım]
const LATE_CASES: Array = [[11, 600.0, 7200], [23, 1190.0, 7200]]


static func case_key(seed_value: int, start_time: float, steps: int) -> String:
	return "%d:%d:%d" % [seed_value, int(start_time), steps]


## `opts` sim'e eklenir (ör. {"run_profile": RunProfile.legacy()}); kayıt biçimi sürümden bağımsızdır.
static func run_late(
	seed_value: int, start_time: float, steps: int, opts: Dictionary = {}
) -> Dictionary:
	var o := {"data": GameData.load_default(), "start_time": start_time}
	o.merge(opts, true)
	var sim := GameSim.new(seed_value, &"gunslinger", o)
	var seen := {"lord_spawns": 0, "damage": 0.0}
	sim.bus.boss_spawned.connect(
		func(type_id: StringName) -> void:
			if type_id == &"kale_lordu":
				seen["lord_spawns"] += 1
	)
	sim.bus.player_damaged.connect(
		func(amount: float, _hp: float) -> void: seen["damage"] += amount
	)
	var n := 0
	while n < steps and sim.state != GameSim.State.WON and sim.state != GameSim.State.LOST:
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
			continue
		# Ölmez oyuncu: bot Lord'a (1200) varmadan ölüyordu (ilk kayıt: 1190 senaryosu 460. adımda LOST, Lord doğmadı).
		# Seviye seçimi _refresh_stats ile canı kırpar, bu yüzden her adım önce yenilenir.
		sim.max_hp = 1.0e9
		sim.hp = 1.0e9
		sim.step(GoldenKit.move_at(n))
		n += 1
	return {
		"hash": str(sim.state_hash()),
		"steps": n,
		"state": sim.state,
		"kills": sim.kills,
		"level": sim.level,
		"lord_spawns": seen["lord_spawns"],
		"damage_q": roundi(float(seen["damage"]) * 64.0),
		"rng_combat": str(sim.rng_combat.state),
	}


static func load_fixture() -> Dictionary:
	if not FileAccess.file_exists(FIXTURE):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	return v if v is Dictionary else {}
