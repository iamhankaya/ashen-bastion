extends GutTest
## Karakterizasyon (plan Faz 4 madde 11): başarım akışları. Her senaryo betikli olay akışı -> tracker sayaçları (19 stat),
## kademe ilerlemesi, depo JSON'u. Tüm aggregate türleri (toplam, en iyi, sayı) ve durumlu reducer'lar (süre/temiz süre,
## elit kümesi, buff koşulu, farklı karakterler) ayrı senaryoda. R8 (metrik kaydı + reducer eklentileri) bu testlere
## karşı yeşil kalır. Baz: rf_ach_flows.json, rf_ach_flows_legacy.json. Depo yolu AchKit.tmp_path; after_each temizler.

const ELITES: Array[StringName] = [&"elit_piyade", &"elit_karga", &"elit_sovalye"]


func after_each() -> void:
	AchKit.cleanup()


func _stats(r: Dictionary) -> Array:
	var tr: AchievementTracker = r["tracker"]
	var seen := {}
	for d in tr.data.achievements:
		seen[str(d.stat)] = true
	var names := seen.keys()
	names.sort()
	var vals := {}
	for n in names:
		vals[n] = tr.value_of(StringName(n))
	var prog := {}
	for d in tr.data.achievements:
		prog[str(d.id)] = tr.progress(d)
	return [vals, prog]


func _snap(r: Dictionary) -> Dictionary:
	var tr: AchievementTracker = r["tracker"]
	var sp := _stats(r)
	return {
		"values": sp[0],
		"progress": sp[1],
		"store": (r["store"] as AchievementStore).to_raw(),
		"run_unlocked": Array(tr.run_unlocked()),
		"run_new_steps": tr.run_new_steps(),
	}


func _finish_stats(time: float, level: int, score: int) -> Dictionary:
	return {"time": time, "level": level, "score": score, "kills": 0}


func _scenarios(make: Callable) -> Dictionary:
	var out := {}
	# 1) yalnız öldürme (toplam + koşu sayacı)
	var r1: Dictionary = make.call(&"gunslinger")
	AchKit.kills(r1["bus"], 1100)
	out["kills"] = _snap(r1)
	# 2) elit kümesi: aynı tür tekrarı kümeyi büyütmez; elit_piyade ayrı sayaç; boss_kills toplamı
	var r2: Dictionary = make.call(&"gunslinger")
	for t in [ELITES[0], ELITES[0], ELITES[0], ELITES[1], ELITES[2], ELITES[1]]:
		AchKit.kills(r2["bus"], 1, t)
	out["elites"] = _snap(r2)
	# 3) buff koşulu: sınırsız buff sırasındaki öldürmeler; yenilemede sıfırlanmaz; bitince sayılmaz
	var r3: Dictionary = make.call(&"gunslinger")
	var b3: SimBus = r3["bus"]
	b3.buff_started.emit(&"unlimited", 5.0)
	AchKit.kills(b3, 30)
	b3.buff_started.emit(&"unlimited", 5.0)
	AchKit.kills(b3, 5)
	b3.buff_ended.emit(&"unlimited")
	AchKit.kills(b3, 7)
	b3.buff_started.emit(&"damage", 5.0)
	out["buff_unlimited"] = _snap(r3)
	# 4) en iyi (max) türleri ve sayaçlar
	var r4: Dictionary = make.call(&"gunslinger")
	var b4: SimBus = r4["bus"]
	for lv in [2, 9, 31, 12]:
		b4.level_up.emit(lv)
	for sc in [500, 150000, 40000]:
		b4.score_changed.emit(sc, 3, 10)
	for m in [2, 7, 4]:
		b4.streak_changed.emit(m, 1.0)
	for i in 25:
		b4.pickup_collected.emit(&"x", Vector2.ZERO)
	for i in 4:
		b4.evolution_gained.emit(&"e")
	for i in 12:
		b4.reload_started.emit(1.0)
	for h in [3, 9, 5]:
		b4.bomb_hits.emit(Vector2.ZERO, 10.0, h)
	out["max_and_counts"] = _snap(r4)
	# 5) süre ve temiz süre (hasarsız); ilk hasardan sonra temiz süre donar
	var r5: Dictionary = make.call(&"gunslinger")
	r5["tracker"].poll(AchKit.sim_at(400.0))
	r5["bus"].player_damaged.emit(5.0, 95.0)
	r5["tracker"].poll(AchKit.sim_at(1250.0))
	out["time_and_clean"] = _snap(r5)
	# 6) etkin yuva sayısı (poll)
	var r6: Dictionary = make.call(&"gunslinger")
	var s6 := AchKit.sim_at(0.0)
	AchKit.fill_actives(s6, 6)
	r6["tracker"].poll(s6)
	out["active_slots"] = _snap(r6)
	# 7) koşu sonu: kazanılan koşu, toplamlar, en iyi; ikinci finish ve sonraki olaylar sayılmaz
	var r7: Dictionary = make.call(&"gunslinger")
	AchKit.kills(r7["bus"], 50)
	r7["tracker"].finish(true, _finish_stats(1210.0, 31, 125000))
	var after_first := _snap(r7)
	r7["tracker"].finish(false, _finish_stats(5.0, 1, 1))
	AchKit.kills(r7["bus"], 99)
	out["finish_won"] = after_first
	out["finish_idempotent"] = _snap(r7)
	assert_eq(out["finish_idempotent"], after_first, "ikinci finish ve sonraki olaylar no-op")
	# 8) farklı karakterler: 5 dk üstü koşular aynı depoda
	var r8: Dictionary = make.call(&"gunslinger")
	for c in [&"gunslinger", &"barutcu", &"zyfen", &"barutcu", &"gunslinger"]:
		var tr := AchievementTracker.new(r8["tracker"].data, r8["store"], c, AchKit.clock())
		tr.attach(SimBus.new())
		tr.finish(false, _finish_stats(320.0, 5, 1000))
	out["chars5"] = {"store": (r8["store"] as AchievementStore).to_raw()}
	# 9) kısa koşu: 300 sn altı char5 saymaz
	var r9: Dictionary = make.call(&"gunslinger")
	r9["tracker"].finish(false, _finish_stats(120.0, 2, 10))
	out["short_run"] = _snap(r9)
	return out


func test_rf_achievement_flows_with_family_data() -> void:
	var out := _scenarios(func(c: StringName) -> Dictionary: return AchKit.rig(c))
	assert_eq(out["kills"]["values"]["total_kills"], 1100, "toplam öldürme sayılır")
	assert_eq(out["elites"]["values"]["run_elite_kinds"], 3, "üç farklı elit türü")
	RfBaseline.check(self, "rf_ach_flows", out)


func test_rf_achievement_flows_with_legacy_single_tier_data() -> void:
	var out := _scenarios(func(c: StringName) -> Dictionary: return AchKit.legacy_rig(c))
	RfBaseline.check(self, "rf_ach_flows_legacy", out)


func test_rf_achievement_flows_are_repeatable() -> void:
	var a := _scenarios(func(c: StringName) -> Dictionary: return AchKit.rig(c))
	AchKit.cleanup()
	var b := _scenarios(func(c: StringName) -> Dictionary: return AchKit.rig(c))
	assert_eq(RfBaseline.canon(a), RfBaseline.canon(b), "aynı akış aynı sonuç (sızıntı yok)")
