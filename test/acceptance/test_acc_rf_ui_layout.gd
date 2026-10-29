extends GutTest
## Karakterizasyon (plan Faz 4 madde 6): UI yerleşim anlık görüntüsü (kontrol dikdörtgenleri JSON). Ekranlar: sonuç
## (3 viewport, güvenli alan, büyük yazı), karakterler, ayarlar, koşu. Animasyon final durumda ölçülür (finish_count).
## Eşik: dikdörtgen +-0 (aynı Godot sürümü/yazı tipi; baz CI'da üretilir). Baz: rf_ui_*.json. R2/R5 bu testlere karşı yeşil kalır.
## Ayar yolu geçici; Settings.buyuk_yazi ve store_path after_each ile geri alınır.

const TMP := "user://rf_ui_tests"
const VIEWPORTS := [Vector2(1080, 2400), Vector2(720, 1600), Vector2(1080, 1920)]
const SAFE := Vector4(0, 96, 0, 72)

var _saved_path := ""
var _saved_big := false


func before_each() -> void:
	CatalogFixtures.pin_default(CatalogFixtures.shipped_trio())  # baz yerleşik 3 modla; yeni veri-yalnız mod bazı değiştirmez
	var s: Node = get_node("/root/Settings")
	_saved_path = s.store_path
	_saved_big = s.buyuk_yazi
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	s.store_path = "%s/settings_%d.cfg" % [TMP, OS.get_process_id()]


func after_each() -> void:
	CatalogFixtures.unpin_default()
	var s: Node = get_node("/root/Settings")
	s.store_path = _saved_path
	s.buyuk_yazi = _saved_big
	var abs_dir := ProjectSettings.globalize_path(TMP)
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))
	DirAccess.remove_absolute(abs_dir)
	AchKit.cleanup()


func _host(size: Vector2) -> Control:
	var h := Control.new()
	h.size = size
	add_child_autofree(h)
	return h


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## Görünür Control'lerin yol|tür|x,y,w,h kaydı (yuvarlama yok: +-0 eşiği); metin içeriği dahil değil.
func _rects(root: Node) -> Array:
	var out := []
	var stack := [[root, _name(root)]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		if n is Control and (n as Control).is_visible_in_tree():
			var c := n as Control
			var r := c.get_global_rect()
			out.append(
				(
					"%s|%s|%s,%s,%s,%s"
					% [
						item[1],
						c.get_class(),
						snappedf(r.position.x, 0.01),
						snappedf(r.position.y, 0.01),
						snappedf(r.size.x, 0.01),
						snappedf(r.size.y, 0.01)
					]
				)
			)
		var kids := n.get_children()
		kids.reverse()
		for k in kids:
			stack.append([k, "%s/%s" % [item[1], _name(k)]])
	return out


## "@Control@778" gibi otomatik adlar türle değiştirilir (koşuya özgü sayaç baza girmez).
func _name(n: Node) -> String:
	var nm := String(n.name)
	return n.get_class() if nm.begins_with("@") else nm


func _stats() -> Dictionary:
	var parts := {
		"kills": 60000, "streak": 30000, "evolution": 4000, "survival": 6000, "lord": 25000
	}
	return {
		"time": 1200.0,
		"level": 31,
		"kills": 4210,
		"evolutions": [&"zincirleme_patlama", &"kiyamet_mermisi"],
		"score": 125000,
		"score_parts": parts,
		"best_mult": 5,
	}


func _combos() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for k in 2:
		rows.append(
			{"id": &"zincirleme_patlama", "name": "Kıyamet Mermisi", "pair": "A + B", "icon": ""}
		)
	return rows


func test_rf_result_screen_rects_3_viewports_safe_area_big_text() -> void:
	var out := {}
	for big in [false, true]:
		(get_node("/root/Settings") as Node).buyuk_yazi = big
		for vp in VIEWPORTS:
			for safe in [Vector4.ZERO, SAFE]:
				var host := _host(vp)
				var r := ResultScreen.new()
				host.add_child(r)
				var record := {
					"rank": 1,
					"is_record": true,
					"previous_best": 90000,
					"needed_for_top10": 0,
					"index": 0
				}
				r.show_result(true, _stats(), _combos(), "", record)
				r.apply_safe_area(safe)
				r.finish_count()
				await _settle()
				out["%s|%s|big=%s" % [vp, safe, big]] = _rects(r)
				host.queue_free()
	assert_eq(out.size(), 12)
	RfBaseline.check(self, "rf_ui_result_rects", out)


func test_rf_characters_screen_rects() -> void:
	var out := {}
	for vp in VIEWPORTS:
		var host := _host(vp)
		var s := CharactersScreen.new()
		host.add_child(s)
		var data := AchKit.data()
		s.open(data, AchKit.store(), &"gunslinger")
		s.apply_safe_area(SAFE)
		await _settle()
		# Portre (Ghost/Portrait/PortraitVideo) canlı nefes hareketi yapar: konum kareye göre kayar, kararsız; dışlanır.
		out[str(vp)] = _rects(s).filter(func(l: String) -> bool: return not l.contains("/Stage/"))
		host.queue_free()
	RfBaseline.check(self, "rf_ui_characters_rects", out)


func test_rf_settings_screen_rects() -> void:
	var out := {}
	for vp in VIEWPORTS:
		var host := _host(vp)
		var s := SettingsScreen.new()
		host.add_child(s)
		s.open()
		s.apply_safe_area(SAFE)
		await _settle()
		out[str(vp)] = _rects(s)
		host.queue_free()
	RfBaseline.check(self, "rf_ui_settings_rects", out)


func test_rf_run_screen_rects() -> void:
	var out := {}
	for big in [false, true]:
		for vp in VIEWPORTS:
			var host := _host(vp)
			var s := RunScreen.new()
			host.add_child(s)
			s.visible = true
			s.set_font_scale(1.4 if big else 1.0)
			s.apply_safe_area(SAFE)
			await _settle()
			out["%s|big=%s" % [vp, big]] = _rects(s)
			host.queue_free()
	RfBaseline.check(self, "rf_ui_run_rects", out)
