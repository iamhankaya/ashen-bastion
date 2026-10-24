class_name GoldenKit
extends RefCounted
## Altın hash senaryosu (v2.0.2 S1): sabit hareket betiği, her seviye atlamada ilk kart, gerçek veri.
## tools/golden/golden_run.gd üretir, test/unit/test_v202_contract_golden.gd doğrular; ikisi de bu senaryoyu kullanır.

const STEPS := 7200
const MIN_LEVEL_UPS := 4
const MAX_STEPS := 24000
const MOVE_PERIOD := 150
const TURN := 2.399963  # altın açı: yön her MOVE_PERIOD adımda bu kadar döner (adım indeksinin saf fonksiyonu)
const FIXTURE := "res://test/fixtures/golden_hashes.json"
const SEEDS_FILE := "res://tools/golden/seeds.txt"
## `zyfen_u3` aşamasının sabit yükü: Tufan, Girdap, Hava Cebi, Nefes Dalgası + Fırtına Gözü/Bilenmiş Rüzgar. (Kasırga
## Patlaması bilerek yok: ekran boyu dalga düşmanları 900 px'te öldürür, taşlar sabit betiğin menzili dışında kalır ve
## "≥ 4 seviye atlama" önkoşulu sağlanamaz.)
const ZYFEN_U3_GRANTS := {
	"tufan": 1,
	"girdap": 5,
	"hava_cebi": 5,
	"nefes_dalgasi": 5,
	"furtina_gozu": 5,
	"agir_kursun": 3,
}


## Adım indeksinin saf fonksiyonu olan hareket betiği.
static func move_at(step_index: int) -> Vector2:
	return Vector2.from_angle(float(step_index / MOVE_PERIOD) * TURN)


## Koşar; ≥ MIN_LEVEL_UPS seviye atlama olana dek en çok MAX_STEPS adıma uzar. Sonuç sözlüğü kayda yazılır.
static func run(
	seed_value: int, character: StringName, steps: int = STEPS, grants: Dictionary = {}
) -> Dictionary:
	var sim := GameSim.new(
		seed_value, character, {"data": GameData.load_default(), "log_events": false}
	)
	for skill_id in grants:  # v2.0.2 U3: Tufan'lı Zyfen koşusu (beceri kimliği -> seviye)
		sim.debug_grant(StringName(skill_id), int(grants[skill_id]))
	var counts := {"elites": 0, "pickups": 0}
	var data := sim.data
	sim.bus.enemy_killed.connect(
		func(type_id: StringName, _pos: Vector2) -> void:
			var def := data.get_enemy(type_id)
			if def != null and def.ai == &"elite":
				counts["elites"] += 1
	)
	sim.bus.pickup_collected.connect(
		func(_kind: StringName, _pos: Vector2) -> void: counts["pickups"] += 1
	)
	var n := 0
	while (
		n < MAX_STEPS
		and (n < steps or sim.level - 1 < MIN_LEVEL_UPS or sim.state != GameSim.State.RUNNING)
	):
		if sim.state == GameSim.State.LEVEL_UP:
			sim.choose(0)
			continue
		if sim.state != GameSim.State.RUNNING:
			break
		sim.step(move_at(n))
		n += 1
	return {
		"hash": sim.state_hash(),
		"steps": n,
		"level_ups": sim.level - 1,
		"kills": sim.kills,
		"elites": counts["elites"],
		"pickups": counts["pickups"],
		"state": sim.state,
		"rng_combat": str(sim.rng_combat.state),  # 64 bit: JSON sayısı olarak 2^53'ü aşar
	}


static func seeds() -> Array[int]:
	var out: Array[int] = []
	for line in FileAccess.get_file_as_string(SEEDS_FILE).split("\n"):
		var t := line.strip_edges()
		if t != "" and not t.begins_with("#"):
			out.append(int(t))
	return out


static func load_fixture() -> Dictionary:
	if not FileAccess.file_exists(FIXTURE):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	return v if v is Dictionary else {}
