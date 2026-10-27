extends GutTest
## Kabul (v1.1): arayüz - HUD skor sütunu, etki rozetleri, ∞ tambur, ekran dışı ok, sonuç ekranı, En İyi Skorlar,
## ana menü, gecikme/atlama, güvenli alan (U1-U15). Dilimler: D2 (U4-U6, U12), D3 (U1-U3, U7-U11, U14-U15);
## U8/U12/U13/U14 gerçek (S3) parçaları dilimsiz koşar. Ölçüler DESIGN §2-3 (1080×2400).
## Metin/konum ölçümü düğüm adına değil görünür Label/Button metnine ve dikdörtgenine bakar (iç yapı sözleşmede yok).

const W := 1080.0
const H := 2400.0
const SAFE_BOTTOM := 72.0
const SAFE_TOP := 96.0
const UNIX := 1_700_000_000
const ROOT := "user://v11_ui_tests"

var _n: int = 0
var _dir: String = ""


func before_each() -> void:
	_n += 1
	_dir = "%s/%d_%d" % [ROOT, OS.get_process_id(), _n]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))


func after_all() -> void:
	_rm(ProjectSettings.globalize_path(ROOT))


func _rm(abs_path: String) -> void:
	for f in DirAccess.get_files_at(abs_path):
		DirAccess.remove_absolute(abs_path.path_join(f))
	for d in DirAccess.get_directories_at(abs_path):
		_rm(abs_path.path_join(d))
	DirAccess.remove_absolute(abs_path)


# --- yardımcılar ---------------------------------------------------------------------------------------------


func _host() -> Control:
	var host := Control.new()
	host.custom_minimum_size = Vector2(W, H)
	host.size = Vector2(W, H)
	add_child_autofree(host)
	return host


func _frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame


## Ağaçtaki tüm görünür (is_visible_in_tree) Control'ler.
func _controls(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	if root is Control and (root as Control).is_visible_in_tree():
		out.append(root)
	for ch in root.get_children():
		out.append_array(_controls(ch))
	return out


## Label/Button metinleri + `text` özelliği olan özel çizimli denetimler (ör. sonuç çipi).
func _texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	for c in _controls(root):
		if c is Label:
			out.append((c as Label).text)
		elif c is Button:
			out.append((c as Button).text)
		elif "text" in c and c.get("text") is String and c.get("text") != "":
			out.append(c.get("text"))
	return out


## `rank` özelliği olan görünür denetimlerin değerleri (sıra rozetleri özel çizilir).
func _ranks(root: Node) -> Array[int]:
	var out: Array[int] = []
	for c in _controls(root):
		if "rank" in c and c.get("rank") is int:
			out.append(c.get("rank"))
	return out


## Skor sütununun SERİ çipi: özel çizimliyse `chip` alt denetimi (mult/fraction), değilse görünür metinden.
func _chip(sb: Control) -> Dictionary:
	var chip: Variant = sb.get("chip")
	if chip is Control:
		return {
			"visible": (chip as Control).is_visible_in_tree(),
			"mult": int(chip.get("mult")),
			"fraction": float(chip.get("fraction")),
		}
	var m := 0
	for t in _texts(sb):
		if t.begins_with("×") and t.substr(1).is_valid_int():
			m = int(t.substr(1))
	return {"visible": _has_text_containing(sb, "SERİ"), "mult": m, "fraction": -1.0}


## Sayı metni: biçimli değer, isteğe bağlı "+" önekiyle.
func _has_amount(root: Node, n: int) -> bool:
	var f := UiKit.format_thousands(n)
	return _has_text(root, f) or _has_text(root, "+" + f)


func _has_text(root: Node, text: String) -> bool:
	return _texts(root).has(text)


func _has_text_containing(root: Node, part: String) -> bool:
	for t in _texts(root):
		if t.contains(part):
			return true
	return false


func _label(root: Node, text: String) -> Label:
	for c in _controls(root):
		if c is Label and (c as Label).text == text:
			return c
	return null


func _button(root: Node, text: String) -> Button:
	for c in _controls(root):
		if c is Button and (c as Button).text == text:
			return c
	return null


## Arka plan/tam ekran dışı, "içerik" sayılan yaprak denetimleri (Label, Button, dokulu TextureRect).
func _content(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for c in _controls(root):
		var is_leaf := (
			c is Label or c is Button or (c is TextureRect and (c as TextureRect).texture != null)
		)
		if not is_leaf:
			continue
		var r := c.get_global_rect()
		if r.size.x >= W * 0.95 and (r.size.y >= H * 0.5 or c is TextureRect):
			continue  # tam ekran zemin/vinyet/ışıma süsü
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		out.append(c)
	return out


func _effective_alpha(node: Control, stop: Node) -> float:
	var a := 1.0
	var n: Node = node
	while n != null and n != stop:
		if n is CanvasItem:
			a *= (n as CanvasItem).modulate.a * (n as CanvasItem).self_modulate.a
		n = n.get_parent()
	if node is Label:
		a *= (node as Label).get_theme_color(&"font_color").a
	return a


func _record(rank: int, prev: int, need: int = 0) -> Dictionary:
	return {
		"rank": rank,
		"is_record": rank == 1,
		"previous_best": prev,
		"needed_for_top10": need,
		"index": rank - 1 if rank > 0 else -1,
	}


func _stats(won: bool, lord: int = 25000, best_mult: int = 5) -> Dictionary:
	var parts := {
		"kills": 60000, "streak": 30000, "evolution": 4000, "survival": 6000, "lord": lord
	}
	var total := 0
	for v in parts.values():
		total += int(v)
	return {
		"time": 1200.0,
		"level": 31,
		"kills": 4210,
		"evolutions": [&"zincirleme_patlama", &"kiyamet_mermisi"],
		"score": total,
		"score_parts": parts,
		"best_mult": best_mult,
	}


func _combos(n: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for k in n:
		rows.append(
			{"id": &"zincirleme_patlama", "name": "Kıyamet Mermisi", "pair": "A + B", "icon": ""}
		)
	return rows


func _result(won: bool, n_combos: int, record: Dictionary, stats: Dictionary = {}) -> ResultScreen:
	var host := _host()
	var r := ResultScreen.new()
	host.add_child(r)
	var st := stats if not stats.is_empty() else _stats(won)
	r.show_result(won, st, _combos(n_combos), "", record)
	return r


func _entries(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in n:
		out.append(
			{
				"score": 90000 - 7000 * k,
				"time": 1290 - 90 * k,
				"won": k % 2 == 0,
				"level": 30 - k,
				"unix": UNIX + 86400 * k
			}
		)
	return out


func _scores_screen(n: int, extra: Variant = null) -> HighscoreScreen:
	var host := _host()
	var s := HighscoreScreen.new()
	host.add_child(s)
	if extra != null:
		s.apply_safe_area(extra)
	s.show_scores(_entries(n))
	return s


# --- U1-U3: HUD skor sütunu ----------------------------------------------------------------------------------


func _hud(sim: GameSim) -> Hud:
	var host := _host()
	var hud := Hud.new()
	host.add_child(hud)
	hud.bind(sim)
	return hud


func _kill_n(sim: GameSim, n: int) -> void:
	for k in n:
		var id := SimKit.add_enemy(
			sim, &"curumus_piyade", Vector2(2500.0 + 40.0 * (k % 50), 40.0 * (k / 50))
		)
		sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
		sim.damage_enemy(id, 1.0e9, &"bullet")


func test_u1_score_column_sits_top_right_and_shows_label_and_value() -> void:
	if V11Slice.require(self, "D3"):
		return
	var sim := SimKit.make(1)
	var hud := _hud(sim)
	await _frames()
	hud.refresh(0.016)
	var sb: Control = hud.score_block
	assert_true(sb.is_visible_in_tree(), "skor sütunu görünür")
	assert_eq(sb.offset_right, -36.0, "sağ 36")
	assert_eq(sb.offset_top, 284.0, "üst 284")
	assert_true(_has_text(sb, "SKOR"), "SKOR etiketi")
	assert_true(_has_text(sb, "0"), "değer 0")
	assert_false(_has_text_containing(sb, "SERİ"), "×1'de SERİ çipi gizli")


func test_u1_streak_chip_appears_from_x2_with_time_bar_and_hides_when_window_closes() -> void:
	if V11Slice.require(self, "D3"):
		return
	var sim := SimKit.make(2)
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	var hud := _hud(sim)
	await _frames()
	_kill_n(sim, 9)
	hud.refresh(0.016)
	await _frames()
	assert_false(_chip(hud.score_block)["visible"], "×1'de (9 öldürme) çip gizli")
	_kill_n(sim, 1)
	hud.refresh(0.016)
	await _frames()
	var c := _chip(hud.score_block)
	assert_true(c["visible"], "×2'de SERİ çipi görünür")
	assert_eq(c["mult"], 2)
	if c["fraction"] >= 0.0:
		assert_gte(c["fraction"], 0.95, "kalan süre çubuğu dolu (3 sn)")
	SimKit.run(sim, 90)
	hud.refresh(0.016)
	c = _chip(hud.score_block)
	if c["fraction"] >= 0.0:
		assert_almost_eq(c["fraction"], 0.5, 0.1, "1,5 sn sonra çubuk yarıda")
	SimKit.run(sim, 91)  # pencere doldu (toplam 181 adım)
	for i in 30:  # çip bozulma animasyonu (220 ms) bitsin
		hud.refresh(1.0 / 60.0)
	await _frames()
	assert_false(_chip(hud.score_block)["visible"], "pencere dolunca çip gizlenir")


func test_u1_streak_chip_text_follows_the_multiplier() -> void:
	if V11Slice.require(self, "D3"):
		return
	var sim := SimKit.make(3)
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	var hud := _hud(sim)
	await _frames()
	_kill_n(sim, 25)
	hud.refresh(0.016)
	await _frames()
	assert_eq(_chip(hud.score_block)["mult"], 3, "25. öldürme: ×3")
	_kill_n(sim, 25)
	hud.refresh(0.016)
	await _frames()
	assert_eq(_chip(hud.score_block)["mult"], 4, "50. öldürme: ×4")
	assert_true(_chip(hud.score_block)["visible"])


func test_u2_eased_value_reaches_target_within_180_ms_and_never_overshoots() -> void:
	if V11Slice.require(self, "D3"):
		return
	var shown := 0.0
	for i in 11:  # 11 x 16,7 ms = 183 ms
		shown = ScoreBlock.eased(shown, 5000, 1.0 / 60.0)
		assert_lte(shown, 5000.0, "aşmaz")
	assert_gte(shown, 5000.0 * 0.9, "180 ms'de hedefin >= %%90'ı (%.0f)" % shown)
	assert_eq(ScoreBlock.eased(5000.0, 5000, 0.016), 5000.0, "hedefteyken sabit")
	assert_eq(ScoreBlock.eased(0.0, 5000, 0.0), 0.0, "dt=0: değişmez")
	var prev := 0.0
	for i in 30:
		var nxt := ScoreBlock.eased(prev, 5000, 1.0 / 60.0)
		assert_gte(nxt, prev, "monoton")
		prev = nxt
	assert_almost_eq(prev, 5000.0, 1.0, "yarım saniyede hedef")


func test_u2_hud_value_label_tracks_sim_score_after_180_ms() -> void:
	if V11Slice.require(self, "D3"):
		return
	var sim := SimKit.make(4)
	var hud := _hud(sim)
	await _frames()
	sim.score.kills_part = 5000  # tek seferlik +5000
	for i in 12:
		hud.refresh(1.0 / 60.0)
	await _frames()
	var texts := _texts(hud.score_block)
	var seen := 0
	for t in texts:
		var digits := t.replace(".", "")
		if digits.is_valid_int() and int(digits) >= 4500:
			seen += 1
	assert_gte(seen, 1, "180 ms sonra gösterilen değer hedefe yaklaştı: %s" % str(texts))
	for i in 40:
		hud.refresh(1.0 / 60.0)
	await _frames()
	assert_true(
		_has_text(hud.score_block, UiKit.format_thousands(sim.score.total())), "sonunda tam değer"
	)


func test_u3_pop_only_for_gain_50_plus_and_300_ms_apart_big_gain_400_plus() -> void:
	if V11Slice.require(self, "D3"):
		return
	assert_false(ScoreBlock.should_pop(49, 10.0), "49: pop yok")
	assert_true(ScoreBlock.should_pop(50, 0.3), "50 ve 300 ms: pop")
	assert_false(ScoreBlock.should_pop(50, 0.29), "300 ms dolmadı")
	assert_true(ScoreBlock.should_pop(1500, 5.0))
	assert_false(ScoreBlock.should_pop(10, 5.0))
	assert_false(ScoreBlock.is_big_gain(399))
	assert_true(ScoreBlock.is_big_gain(400))
	assert_true(ScoreBlock.is_big_gain(25000))
	assert_eq(ScoreBlock.tier_of(1), 0, "x1 gizli")
	assert_eq(ScoreBlock.tier_of(2), 1)
	assert_eq(ScoreBlock.tier_of(3), 2)
	assert_eq(ScoreBlock.tier_of(4), 2)
	assert_eq(ScoreBlock.tier_of(5), 3)


func test_u3_big_gain_headline_shows_plus_amount() -> void:
	if V11Slice.require(self, "D3"):
		return
	var sim := SimKit.make(5)
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	var hud := _hud(sim)
	await _frames()
	var id := SimKit.add_enemy(sim, &"elit_karga", Vector2(2500, 0))
	sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
	sim.damage_enemy(id, 1.0e9, &"bullet")
	hud.refresh(0.016)
	await _frames()
	assert_true(_has_text_containing(hud.score_block, "+1.500"), "kazanç başlığı +1.500")


func test_u3_small_gain_shows_no_headline() -> void:
	if V11Slice.require(self, "D3"):
		return
	var sim := SimKit.make(6)
	sim.gun_cd = PackedFloat32Array([1.0e9, 1.0e9])
	var hud := _hud(sim)
	await _frames()
	_kill_n(sim, 1)
	hud.refresh(0.016)
	await _frames()
	assert_false(_has_text_containing(hud.score_block, "+10"), "10 puan: başlık yok")


# --- U4-U5: etki rozetleri ve ∞ tambur -----------------------------------------------------------------------


func test_u4_buff_row_statics() -> void:
	if V11Slice.require(self, "D2"):
		return
	assert_eq(BuffRow.badge_x(0), 231.0)
	assert_eq(BuffRow.badge_x(1), 351.0)
	assert_eq(BuffRow.badge_x(2), 471.0)
	assert_eq(BuffRow.seconds_text(720), "12")
	assert_eq(BuffRow.seconds_text(719), "12", "ceil")
	assert_eq(BuffRow.seconds_text(661), "12")
	assert_eq(BuffRow.seconds_text(660), "11")
	assert_eq(BuffRow.seconds_text(61), "2")
	assert_eq(BuffRow.seconds_text(60), "1")
	assert_eq(BuffRow.seconds_text(1), "1")
	assert_true(BuffRow.blinking(3.0), "son 3 sn (dahil)")
	assert_true(BuffRow.blinking(0.5))
	assert_false(BuffRow.blinking(3.01))
	assert_false(BuffRow.blinking(12.0))


func test_u4_buff_row_shows_at_most_three_badges_and_drops_closed_ones() -> void:
	if V11Slice.require(self, "D2"):
		return
	var sim := SimKit.make(7, {"data_kind": "quiet_pickups"})
	var hud := _hud(sim)
	await _frames()
	var row: Control = hud.buff_row
	assert_true(
		row.has_method("badge_count"),
		"BuffRow.badge_count() (özel çizimli rozetler için gözlem yüzeyi)"
	)
	if not row.has_method("badge_count"):
		return
	hud.refresh(0.016)
	assert_eq(row.call("badge_count"), 0, "etki yokken rozet yok")
	sim.buffs.start(BuffManager.Kind.DAMAGE, 720, 1.5)
	sim.buffs.start(BuffManager.Kind.FIRE_RATE, 300, 1.4)
	sim.buffs.start(BuffManager.Kind.UNLIMITED, 600)
	hud.refresh(0.016)
	await _frames()
	assert_true(row.is_visible_in_tree())
	assert_eq(row.call("badge_count"), 3, "en çok 3 rozet")
	assert_lte(BuffManager.COUNT, 3)
	sim.buffs.left_steps[BuffManager.Kind.DAMAGE] = 0  # ilk rozet kapanır
	for i in 40:  # kapanış (220 ms) + kayma (180 ms)
		hud.refresh(1.0 / 60.0)
	await _frames()
	assert_eq(row.call("badge_count"), 2, "kapanan rozet gider, kalanlar sola kayar")


func test_u5_unlimited_drum_describes_infinite_and_ignores_reload_state() -> void:
	if V11Slice.require(self, "D2"):
		return
	var drum := MagazineDrum.new()
	add_child_autofree(drum)
	drum.set_state(4, 6, false, 0.0)
	assert_eq(drum.describe(), "Şarjör 4 / 6")
	drum.set_unlimited(true)
	assert_eq(drum.describe(), "Şarjör sınırsız")
	drum.set_state(0, 6, true, 0.5)
	assert_eq(drum.describe(), "Şarjör sınırsız", "etkinken doldurma halkası/durumu yok")
	drum.set_unlimited(false)
	drum.set_state(3, 6, false, 0.0)
	assert_eq(drum.describe(), "Şarjör 3 / 6")


func test_u5_hud_drum_follows_unlimited_buff() -> void:
	if V11Slice.require(self, "D2"):
		return
	var sim := SimKit.make(8, {"data_kind": "quiet_pickups"})
	var hud := _hud(sim)
	await _frames()
	hud.refresh(0.016)
	assert_eq(hud.drum.describe(), "Şarjör 6 / 6")
	sim.debug_spawn_pickup(&"sonsuz_tambur", sim.player_pos)
	sim.debug_collect_pickups()
	hud.refresh(0.016)
	assert_eq(hud.drum.describe(), "Şarjör sınırsız")
	SimKit.run(sim, 620)
	hud.refresh(0.016)
	assert_eq(hud.drum.describe(), "Şarjör 6 / 6", "bitince normale döner")


# --- U6: ekran dışı ok ---------------------------------------------------------------------------------------


func test_u6_offscreen_arrow_hidden_when_target_on_screen() -> void:
	if V11Slice.require(self, "D2"):
		return
	var view := Vector2(W, H)
	var safe := Rect2(36, 120, 1008, 2160)
	var cam := Vector2(5000, -3000)
	for off in [Vector2.ZERO, Vector2(300, 500), Vector2(-500, -1000), Vector2(500, 1100)]:
		var r := OffscreenArrow.place(cam + off, cam, view, safe, 42.0)
		assert_false(r["visible"], "ekranda: gizli %s" % off)


func test_u6_offscreen_arrow_four_directions_edge_and_angle() -> void:
	if V11Slice.require(self, "D2"):
		return
	var view := Vector2(W, H)
	var safe := Rect2(36, 120, 1008, 2160)
	var margin := 42.0
	var cam := Vector2(5000, -3000)
	var inner := safe.grow(-margin)
	var cases := [
		[Vector2(3000, 0), 0.0, "sağ"],
		[Vector2(-3000, 0), PI, "sol"],
		[Vector2(0, -4000), -PI * 0.5, "yukarı"],
		[Vector2(0, 4000), PI * 0.5, "aşağı"],
	]
	for c in cases:
		var r := OffscreenArrow.place(cam + c[0], cam, view, safe, margin)
		assert_true(r["visible"], "%s: görünür" % c[2])
		var p: Vector2 = r["pos"]
		assert_true(inner.grow(0.6).has_point(p), "%s: güvenli dikdörtgen içinde %s" % [c[2], p])
		assert_almost_eq(
			absf(angle_difference(float(r["angle"]), float(c[1]))), 0.0, 0.06, "%s: açı" % c[2]
		)
	var right := OffscreenArrow.place(cam + Vector2(3000, 0), cam, view, safe, margin)
	assert_almost_eq(float(right["pos"].x), inner.end.x, 1.0, "sağ kenarda")
	var up := OffscreenArrow.place(cam + Vector2(0, -4000), cam, view, safe, margin)
	assert_almost_eq(float(up["pos"].y), inner.position.y, 1.0, "üst kenarda")


func test_u6_offscreen_arrow_corner_is_clamped_inside_safe_rect_with_true_bearing() -> void:
	if V11Slice.require(self, "D2"):
		return
	var view := Vector2(W, H)
	var safe := Rect2(36, 120, 1008, 2160)
	var margin := 42.0
	var cam := Vector2.ZERO
	var inner := safe.grow(-margin)
	for d in [
		Vector2(3000, -5000), Vector2(-3000, -5000), Vector2(3000, 5000), Vector2(-3000, 5000)
	]:
		var r := OffscreenArrow.place(cam + d, cam, view, safe, margin)
		assert_true(r["visible"])
		assert_true(inner.grow(0.6).has_point(r["pos"]), "köşe %s içeride: %s" % [d, r["pos"]])
		assert_almost_eq(
			absf(angle_difference(float(r["angle"]), d.angle())), 0.0, 0.06, "köşe açısı %s" % d
		)


# --- U7-U9: sonuç ekranı -------------------------------------------------------------------------------------


func test_u7_result_layout_zero_and_four_combos_fit_with_buttons_below_content() -> void:
	if V11Slice.require(self, "D3"):
		return
	for n in [0, 4]:
		var r := _result(true, n, _record(1, 154200))
		await _frames()
		r.finish_count()
		await _frames()
		var limit := H - SAFE_BOTTOM
		var over := PackedStringArray()
		for c in _content(r):
			if c.get_global_rect().end.y > limit + 0.5:
				over.append("%s %.0f" % [c.name, c.get_global_rect().end.y])
		assert_eq(over.size(), 0, "%d kombo: alt güvenli alanı aşan: %s" % [n, str(over)])
		var by: float = r.replay_button.get_global_rect().position.y
		assert_gte(by, 1500.0 - 0.5, "%d kombo: düğmeler y >= 1500" % n)
		var above := 0.0
		for c in _content(r):
			if not c is Button:
				above = maxf(above, c.get_global_rect().end.y)
		assert_gte(
			by, above + 24.0 - 1.0, "%d kombo: düğmeler içeriğin (%.0f) 24 px altında" % [n, above]
		)
		assert_lte(r.content_bottom(), limit, "%d kombo: content_bottom() güvenli alt sınırda" % n)
		if n == 4:
			assert_lte(r.menu_button.get_global_rect().end.y, 2328.5, "4 kombo: düğme alt <= 2328")


func test_u7_fifth_combo_collapses_into_plus_one_row() -> void:
	if V11Slice.require(self, "D3"):
		return
	var r := _result(true, 5, _record(1, 1))
	await _frames()
	assert_true(_has_text(r, "+1"), "5. kombo yerine '+1'")
	var names := 0
	for t in _texts(r):
		if t == "KIYAMET MERMİSİ":
			names += 1
	assert_eq(names, 4, "en çok 4 kombo satırı")


func test_u8_buttons_ready_time_rules_and_timeline_constants() -> void:
	if V11Slice.require(self, "D3"):
		return
	assert_almost_eq(ResultTimeline.buttons_ready_at(-1.0), 1.3, 1e-4, "atlanmadı")
	assert_almost_eq(ResultTimeline.buttons_ready_at(0.2), 0.8, 1e-4, "t=0,2 -> 0,8")
	assert_almost_eq(ResultTimeline.buttons_ready_at(0.0), 0.8, 1e-4, "alt sınır 0,8")
	assert_almost_eq(ResultTimeline.buttons_ready_at(0.5), 0.9, 1e-4, "t+0,4")
	assert_almost_eq(ResultTimeline.buttons_ready_at(1.0), 1.3, 1e-4, "t=1,0 -> üst sınır 1,3")
	assert_almost_eq(ResultTimeline.buttons_ready_at(5.0), 1.3, 1e-4)


func test_u8_motion_tokens_for_result_timeline() -> void:
	assert_eq(Motion.sec(Motion.RESULT_COUNT), ExpectedTablesV11.COUNT_SEC, "sayma 0,9 sn")
	assert_eq(
		Motion.sec(Motion.RESULT_ROW_STAGGER),
		ExpectedTablesV11.ROW_STAGGER_SEC,
		"satır aralığı 0,12"
	)
	assert_eq(Motion.sec(Motion.RESULT_STAMP_AT), ExpectedTablesV11.STAMP_SEC, "damga 1,25 sn")
	assert_eq(Motion.sec(Motion.RESULT_BUTTONS), ExpectedTablesV11.BUTTONS_SEC, "düğme 1,3 sn")
	assert_eq(Motion.sec(Motion.DEATH_TOTAL), ExpectedTablesV11.DELAY_DEATH)
	assert_eq(Motion.sec(Motion.WIN_TOTAL), ExpectedTablesV11.DELAY_WIN)
	assert_eq(Motion.sec(Motion.LEVELUP_PREROLL), ExpectedTablesV11.DELAY_LEVELUP)
	assert_eq(Motion.sec(Motion.HITSTOP_BOMB), ExpectedTablesV11.HITSTOP_BOMB)
	assert_eq(Motion.sec(Motion.HITSTOP_LORD_RAGE), ExpectedTablesV11.HITSTOP_LORD_RAGE)
	assert_eq(Motion.sec(Motion.HITSTOP_LORD_DEATH), ExpectedTablesV11.HITSTOP_LORD_DEATH)
	assert_eq(Motion.sec(Motion.SCORE_EASE), 0.18)
	assert_lte(Motion.sec(Motion.HITSTOP_LORD_DEATH), HitStop.MAX_SEC, "istekler tavanı aşmaz")


func test_u9_record_rank_one_shows_stamp_and_previous_best() -> void:
	if V11Slice.require(self, "D3"):
		return
	var r := _result(true, 1, _record(1, 154200))
	await _frames()
	r.finish_count()
	await _frames()
	assert_eq(r.title_label.text, "KAZANDIN")
	assert_true(_has_text(r, "YENİ REKOR"), "YENİ REKOR damgası")
	assert_true(_has_text(r, "Önceki en iyi: 154.200"), "önceki en iyi")
	assert_true(_has_text(r, UiKit.format_thousands(125000)), "skor hero değeri")


func test_u9_record_rank_two_to_ten_shows_pill_with_rank() -> void:
	if V11Slice.require(self, "D3"):
		return
	var r := _result(false, 0, _record(4, 154200))
	await _frames()
	r.finish_count()
	await _frames()
	assert_eq(r.title_label.text, "OYUN BİTTİ")
	assert_true(_has_text(r, "EN İYİ 10'A GİRDİN · 4. SIRA"), "pill metni: %s" % str(_texts(r)))
	assert_false(_has_text(r, "YENİ REKOR"))
	var r2 := _result(false, 0, _record(10, 154200))
	await _frames()
	assert_true(_has_text(r2, "EN İYİ 10'A GİRDİN · 10. SIRA"))


func test_u9_outside_top_ten_shows_needed_score() -> void:
	if V11Slice.require(self, "D3"):
		return
	var rec := _record(0, 154200, 62400)
	var r := _result(false, 0, rec)
	await _frames()
	assert_true(_has_text(r, "10. sıra için gereken: 62.400"), "metin: %s" % str(_texts(r)))
	assert_false(_has_text(r, "YENİ REKOR"))
	assert_false(_has_text_containing(r, "GİRDİN"))


func test_u9_first_game_counts_as_record() -> void:
	if V11Slice.require(self, "D3"):
		return
	var r := _result(false, 0, _record(1, 0))
	await _frames()
	assert_true(_has_text(r, "YENİ REKOR"), "liste boşken tüm skorlar rekor")
	assert_false(_has_text(r, "Önceki en iyi: 0"), "önceki en iyi yok")


func test_u9_score_breakdown_rows_and_details() -> void:
	if V11Slice.require(self, "D3"):
		return
	var r := _result(true, 1, _record(1, 1))
	await _frames()
	r.finish_count()
	await _frames()
	for t in ["Öldürme", "Seri çarpanı", "Evrim bonusu", "Hayatta kalma", "Lord bonusu"]:
		assert_true(_has_text(r, t), "döküm satırı %s" % t)
	assert_true(_has_text_containing(r, "en yüksek ×5"), "seri ayrıntısı")
	assert_true(_has_text_containing(r, "2 evrim"), "evrim ayrıntısı")
	assert_true(_has_text_containing(r, "20:00"), "hayatta kalma ayrıntısı")
	for v in [60000, 30000, 4000, 6000, 25000]:
		assert_true(_has_amount(r, v), "değer %d (metinler: %s)" % [v, str(_texts(r))])


func test_u9_lost_lord_row_is_dim_dash_with_hint() -> void:
	if V11Slice.require(self, "D3"):
		return
	var r := _result(false, 0, _record(0, 1, 100), _stats(false, 0, 3))
	await _frames()
	r.finish_count()
	await _frames()
	var hint := _label(r, "Lord'u yen")
	assert_not_null(hint, "kaybedilen Lord satırı ayrıntısı")
	var dash := _label(r, "—")
	assert_not_null(dash, "değer yerine —")
	if dash != null:
		assert_almost_eq(_effective_alpha(dash, r.get_parent()), 0.35, 0.03, "%35 opak")


# --- U10: En İyi Skorlar -------------------------------------------------------------------------------------


func test_u10_empty_state_texts_play_button_and_default_focus() -> void:
	if V11Slice.require(self, "D3"):
		return
	var s := _scores_screen(0)
	await _frames(3)
	assert_true(s.visible)
	assert_true(_has_text(s, "EN İYİ SKORLAR"), "başlık")
	assert_true(_has_text(s, "HENÜZ SKOR YOK"))
	assert_true(
		_has_text(s, HighscoreScreen.empty_text_for(&"normal", &"normal")), "v2.1 boş sekme metni"
	)
	var play := _button(s, "BU AYARLA OYNA")
	var back := _button(s, "GERİ")
	assert_not_null(play, "boşken BU AYARLA OYNA düğmesi")
	assert_not_null(back, "GERİ düğmesi")
	if play != null:
		assert_eq(
			get_viewport().gui_get_focus_owner(), play, "boş durumda varsayılan odak BU AYARLA OYNA"
		)
		assert_almost_eq(play.get_global_rect().position.y, 1500.0, 2.0, "BU AYARLA OYNA y 1500")


func test_u10_three_entries_chips_times_dates_and_focus_on_back() -> void:
	if V11Slice.require(self, "D3"):
		return
	var s := _scores_screen(3)
	await _frames(3)
	assert_false(_has_text(s, "HENÜZ SKOR YOK"))
	assert_null(_button(s, "BU AYARLA OYNA"), "dolu listede BU AYARLA OYNA yok")
	var back := _button(s, "GERİ")
	assert_not_null(back)
	if back != null:
		assert_eq(get_viewport().gui_get_focus_owner(), back, "dolu listede varsayılan odak GERİ")
	var es := _entries(3)
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	for k in 3:
		assert_true(_has_text(s, UiKit.format_thousands(es[k]["score"])), "skor %d" % k)
		assert_true(_has_text(s, UiKit.format_time(float(es[k]["time"]))), "süre %d" % k)
		assert_true(_has_text(s, Highscores.format_date(es[k]["unix"], bias)), "tarih %d" % k)
	assert_true(_has_text_containing(s, "KAZANDI"), "kazanılan çip (✓ glifi ya da çizili onay)")
	assert_true(_has_text(s, "YENİLDİ"), "kaybedilen çip")
	var dashes := 0
	for t in _texts(s):
		if t == "—":
			dashes += 1
	var faded := 0
	for c in _controls(s):
		if "faded" in c and c.get("faded") == true:
			faded += 1
	assert_eq(maxi(dashes, faded), 7, "kalan 7 sıra boş yuva (— metni ya da soluk rozet)")


func test_u10_ten_rows_stay_between_y_590_and_2172_and_show_rank_digits() -> void:
	if V11Slice.require(self, "D3"):
		return
	var s := _scores_screen(10)
	await _frames(3)
	var es := _entries(10)
	var top := 1.0e9
	var bottom := -1.0e9
	for k in 10:
		var lab := _label(s, UiKit.format_thousands(es[k]["score"]))
		assert_not_null(lab, "skor satırı %d" % k)
		if lab != null:
			var rect := lab.get_global_rect()
			top = minf(top, rect.position.y)
			bottom = maxf(bottom, rect.end.y)
	assert_gte(top, 590.0 - 0.5, "ilk satır y >= 590 (v2.1: iki sıra sekme)")
	assert_lte(bottom, 2172.5, "son satır y <= 2172")
	var ranks := _ranks(s)
	if ranks.is_empty():
		for rank in range(1, 11):
			assert_true(_has_text(s, str(rank)), "sıra rozeti %d" % rank)
	else:
		ranks.sort()
		assert_eq(ranks, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] as Array[int], "10 sıra rozeti (1-10)")


func test_u10_back_and_play_signals() -> void:
	if V11Slice.require(self, "D3"):
		return
	var s := _scores_screen(0)
	await _frames(2)
	watch_signals(s)
	var back := _button(s, "GERİ")
	var play := _button(s, "BU AYARLA OYNA")
	assert_not_null(back)
	assert_not_null(play)
	if back != null:
		back.pressed.emit()
	if play != null:
		play.pressed.emit()
	assert_signal_emitted(s, "back_requested")
	assert_signal_emitted(s, "play_requested")


# --- U11: ana menü -------------------------------------------------------------------------------------------


func _menu() -> MainMenu:
	var host := _host()
	var m := MainMenu.new()
	host.add_child(m)
	return m


func test_u11_menu_order_column_top_hero_box_and_signal() -> void:
	if V11Slice.require(self, "D3"):
		return
	var m := _menu()
	await _frames(3)
	assert_not_null(m.scores_button, "scores_button var")
	if m.scores_button == null:
		return
	var play := m.play_button.get_global_rect()
	var scores := m.scores_button.get_global_rect()
	var settings := m.settings_button.get_global_rect()
	assert_eq(m.scores_button.text, "EN İYİ SKORLAR")
	assert_lt(play.end.y, scores.position.y, "OYNA -> EN İYİ SKORLAR")
	assert_almost_eq(
		settings.position.y, scores.position.y, 1.0, "AYARLAR, EN İYİ SKORLAR'ın yanında"
	)
	assert_gte(play.position.y, 1763.0 - 1.0, "sütun üstü >= 1763 (v2.0.3)")
	assert_almost_eq(scores.size.x, 454.0, 4.0, "v2.0.3: yarım düğme")
	assert_almost_eq(scores.size.y, 132.0, 1.0)
	var half := m.characters_button.get_global_rect()
	assert_almost_eq(
		play.position.y + play.size.y + 27.0, half.position.y, 2.0, "OYNA -> KARAKTERLER aralık 27"
	)
	assert_almost_eq(
		half.end.y + 27.0, scores.position.y, 2.0, "KARAKTERLER -> EN İYİ SKORLAR aralık 27"
	)
	assert_not_null(m.hero, "ana görsel")
	if m.hero != null:
		var hr := m.hero.get_global_rect()
		assert_almost_eq(hr.size.x, 640.0, 1.0)
		assert_almost_eq(hr.size.y, 932.0, 1.0)
		assert_lte(hr.end.y, 1532.5, "karakter alt <= 1532 (v2.0.3)")
		assert_gte(hr.position.y, 600.0 - 1.0, "karakter üst >= 600 (v2.0.3)")
	watch_signals(m)
	m.scores_button.pressed.emit()
	assert_signal_emitted(m, "scores_requested")


# --- U15: güvenli alan ---------------------------------------------------------------------------------------


## Denetimin görünür alt kenarı: kaydırmalı Label'da dikdörtgen değil metin satırlarının alt kenarı.
func _visible_bottom(c: Control) -> float:
	var r := c.get_global_rect()
	if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
		var lab := c as Label
		var lines := maxi(lab.get_line_count(), 1)
		var text_h := float(lines) * float(lab.get_line_height())
		return r.position.y + minf(r.size.y, text_h)
	return r.end.y


func _assert_inside_safe(root: Node, extra: Vector4, what: String) -> void:
	var top := SAFE_TOP + extra.y
	var bottom := H - SAFE_BOTTOM - extra.w
	var bad := PackedStringArray()
	for c in _content(root):
		var r := c.get_global_rect()
		var end_y := _visible_bottom(c)
		if r.position.y < top - 0.5 or end_y > bottom + 0.5:
			bad.append("%s y %.0f..%.0f" % [c.name, r.position.y, end_y])
	assert_eq(
		bad.size(),
		0,
		(
			"%s: içerik üst >= %.0f, alt <= %.0f dışında: %s"
			% [what, top, bottom, str(bad.slice(0, 4))]
		)
	)


func test_u15_safe_area_extra_moves_highscore_screen_content_inside() -> void:
	if V11Slice.require(self, "D3"):
		return
	var extra := Vector4(0, 100, 0, 150)
	var s := _scores_screen(10, extra)
	await _frames(3)
	_assert_inside_safe(s, extra, "En İyi Skorlar (10 satır)")
	var e := _scores_screen(0, extra)
	await _frames(3)
	_assert_inside_safe(e, extra, "En İyi Skorlar (boş)")


func test_u15_safe_area_extra_moves_result_screen_content_inside() -> void:
	if V11Slice.require(self, "D3"):
		return
	var extra := Vector4(0, 100, 0, 150)
	var host := _host()
	var r := ResultScreen.new()
	host.add_child(r)
	r.apply_safe_area(extra)
	r.show_result(true, _stats(true), _combos(2), "", _record(1, 154200))
	await _frames(3)
	r.finish_count()
	await _frames(2)
	_assert_inside_safe(r, extra, "Sonuç ekranı (2 kombo)")
	assert_lte(r.content_bottom(), H - SAFE_BOTTOM - extra.w + 0.5)


func test_u15_safe_area_extra_moves_main_menu_content_inside() -> void:
	if V11Slice.require(self, "D3"):
		return
	var extra := Vector4(0, 100, 0, 150)
	var m := _menu()
	m.apply_safe_area(extra)
	await _frames(3)
	_assert_inside_safe(m, extra, "Ana menü")
