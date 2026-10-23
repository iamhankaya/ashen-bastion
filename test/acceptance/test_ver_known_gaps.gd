extends GutTest
## Doğrulama (T20261023-64): önceki raporlardan bilinen açıkların DURUMU. Bunlar yeni bulgu değildir; testler bugünkü
## davranışı olduğu gibi sabitler (`karakterizasyon (F-xxx)`). Biri düzeltilince ilgili test kırmızıya döner:
## o zaman testi tersine çevirin (kusur kapandı demektir). Kapsam ve sayılar kapanış raporunda.
##   F-ver-002  komşu chunk sınırında katı harabe çakışması
##   F-ver-003  SFX dosyası yok (sessiz yer tutucu)
##   F-ver-004  HUD güvenli alanı yalnız _build'de uygulanır (çalışma anında yeniden uygulanmaz)
##   F-ver-005  düşman shader'ı cell_rect[16] sınırı (koruma testi: şu an 16'nın altında)

const SEEDS := 20


func _overlapping_pairs(m: MapSim, same_chunk: bool) -> int:
	var pairs := 0
	var solid: Array[int] = []
	for i in m.count:
		if m.ob_solid[i] == 1:
			solid.append(i)
	for a in solid.size():
		for b in range(a + 1, solid.size()):
			var i: int = solid[a]
			var j: int = solid[b]
			var same := MapSim.chunk_of(m.ob_pos[i]) == MapSim.chunk_of(m.ob_pos[j])
			if same != same_chunk:
				continue
			if m.ob_pos[i].distance_to(m.ob_pos[j]) < m.ob_r[i] + m.ob_r[j]:
				pairs += 1
	return pairs


func test_karakterizasyon_f_ver_002_neighbor_chunk_solid_ruins_overlap() -> void:
	var data := SimKit.data_for("real")
	var cross := 0
	var within := 0
	for s in range(1, SEEDS + 1):
		var m := MapSim.new(s, data.ruins)
		for cx in range(-4, 5):
			for cy in range(-4, 5):
				m.ensure(Vector2(cx * 1024.0 + 512.0, cy * 1024.0 + 512.0))
		cross += _overlapping_pairs(m, false)
		within += _overlapping_pairs(m, true)
	assert_eq(within, 0, "aynı chunk içinde katı harabeler çakışmaz (MIN_GAP kuralı çalışır)")
	assert_gt(
		cross,
		0,
		"KARAKTERİZASYON (F-ver-002): komşu chunk'larda %d çakışan çift (20 tohum)" % cross
	)


func test_karakterizasyon_f_ver_002_overlap_lens_can_leave_the_player_inside_a_ruin() -> void:
	var data := SimKit.data_for("real")
	var penetrating := 0
	for s in range(1, SEEDS + 1):
		var m := MapSim.new(s, data.ruins)
		for cx in range(-4, 5):
			for cy in range(-4, 5):
				m.ensure(Vector2(cx * 1024.0 + 512.0, cy * 1024.0 + 512.0))
		var solid: Array[int] = []
		for i in m.count:
			if m.ob_solid[i] == 1:
				solid.append(i)
		for a in solid.size():
			for b in range(a + 1, solid.size()):
				var i: int = solid[a]
				var j: int = solid[b]
				var d := m.ob_pos[i].distance_to(m.ob_pos[j])
				var rr: float = m.ob_r[i] + m.ob_r[j]
				if d >= rr:
					continue
				var dir: Vector2 = (m.ob_pos[j] - m.ob_pos[i]).normalized()
				var mid: Vector2 = m.ob_pos[i] + dir * (m.ob_r[i] - (rr - d) * 0.5)
				var res := m.resolve(mid, 22.0)
				for k in solid:
					if res.distance_to(m.ob_pos[k]) < m.ob_r[k] + 22.0 - 0.5:
						penetrating += 1
						break
	assert_gt(
		penetrating,
		0,
		"KARAKTERİZASYON (F-ver-002): resolve sonrası hâlâ içeride kalan nokta: %d" % penetrating
	)


func test_karakterizasyon_f_ver_003_no_sfx_files_ship_yet() -> void:
	var n := 0
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://assets/audio/sfx")):
		for f in DirAccess.get_files_at("res://assets/audio/sfx"):
			if f.ends_with(".ogg") or f.ends_with(".wav"):
				n += 1
	assert_eq(n, 0, "KARAKTERİZASYON (F-ver-003): SFX dosyası yok; atış/doldurma/patlama sessiz")
	# sessiz çalma hata vermez
	var host := Node.new()
	add_child_autofree(host)
	Sfx.setup(host)
	Sfx.play(&"shot_right")
	Sfx.play(&"explosion")
	Sfx.teardown()
	var music := 0
	for f in DirAccess.get_files_at("res://assets/audio/music"):
		if f.ends_with(".ogg"):
			music += 1
	assert_eq(
		music,
		7,
		"yedi müzik parçası mevcut (menü, savaş-1/2, boss uyarısı, Lord, kazandın, kaybettin)"
	)


func test_karakterizasyon_f_ver_004_hud_safe_area_is_applied_only_at_build_time() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	assert_eq(src.count("apply_safe_area("), 2, "çağrı + tanım: yalnız bir çağrı noktası (_build)")
	var build_start := src.find("func _build()")
	var build_end := src.find("\nfunc ", build_start + 5)
	assert_true(src.substr(build_start, build_end - build_start).contains("apply_safe_area()"))
	assert_false(
		src.contains("size_changed"),
		"KARAKTERİZASYON (F-ver-004): yeniden boyutlanmada yeniden uygulanmaz"
	)
	# işlev doğru çalışır: verilen pay safe katmanına işlenir
	var h := Hud.new()
	add_child_autofree(h)
	h.apply_safe_area(Vector4(40, 90, 40, 70))
	assert_eq(h.safe.offset_left, 40.0)
	assert_eq(h.safe.offset_top, 90.0)
	assert_eq(h.safe.offset_right, -40.0)
	assert_eq(h.safe.offset_bottom, -70.0)


func test_f_ver_005_enemy_atlas_cell_count_fits_the_shader_uniform_array() -> void:
	var shader := FileAccess.get_file_as_string("res://assets/shaders/enemy_flash.gdshader")
	assert_true(shader.contains("uniform vec4 cell_rect[16]"), "shader dizisi 16 hücre")
	var data := SimKit.data_for("real")
	var paths: Array[String] = []
	for id in data.enemy_ids:
		var sp := data.get_enemy(id).sprite
		if not paths.has(sp):
			paths.append(sp)
	var atlas := EnemyAtlas.new().build(paths)
	var used := 0
	for p in atlas.cells.values():
		used += int(p["frames"])
	assert_lte(used, 16, "kullanılan atlas hücresi (%d) shader sınırının altında" % used)
	assert_lt(
		used, 16, "uyarı: sınıra dayandı; yeni düşman/kare eklenirse shader dizisi büyütülmeli"
	)
