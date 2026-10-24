extends GutTest
## Ara denetim #1/#5: düşman ve oyuncu siluet konturu zeminden >= 3:1 (WCAG göreli parlaklık oranı) ayrışır.
## Zemin: gerçek zemin dokusunun ortalaması x GroundView.TINT (oyunda gösterilen).

const MIN_RATIO := 3.0


static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


static func luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func ratio(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Gösterilen zeminin en parlak (95. yüzdelik benzeri: ortalama + 1 sapma) ve ortalama rengi.
func _ground_colors() -> Array[Color]:
	var tex := ArtLoader.texture(GroundView.GROUND_PATH)
	assert_not_null(tex)
	var img := tex.get_image()
	var sum := Vector3.ZERO
	var n := 0
	var lums: Array[float] = []
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var c := img.get_pixel(x, y) * GroundView.TINT
			sum += Vector3(c.r, c.g, c.b)
			n += 1
			lums.append(luminance(c))
	lums.sort()
	var mean := Color(sum.x / n, sum.y / n, sum.z / n)
	# en parlak %5 zemin pikseli (en kötü durum)
	var bright := Color.BLACK
	var target := lums[int(lums.size() * 0.95)]
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var c := img.get_pixel(x, y) * GroundView.TINT
			if luminance(c) >= target:
				bright = c
				break
		if bright != Color.BLACK:
			break
	return [mean, bright]


func test_base_enemy_rim_separates_from_ground() -> void:
	var g := _ground_colors()
	assert_gte(
		ratio(EnemyRenderer.RIM_COLOR, g[0]), MIN_RATIO, "taban düşman kontur / ortalama zemin"
	)
	assert_gte(
		ratio(EnemyRenderer.RIM_COLOR, g[1]), MIN_RATIO, "taban düşman kontur / en parlak zemin"
	)


func test_each_enemy_type_rim_separates_from_ground() -> void:
	var data := GameData.load_default()
	var g := _ground_colors()
	for id in data.enemy_ids:
		var def := data.get_enemy(id)
		var elite := def.ai == &"elite" or def.ai == &"lord"
		var rim := EnemyRenderer.RIM_COLOR
		if elite:
			rim = EnemyRenderer.RIM_ELITE_COLOR  # N6: tint'ten türetilmez
		assert_gte(ratio(rim, g[0]), MIN_RATIO, "%s kontur / zemin" % id)
		assert_gte(ratio(rim, g[1]), MIN_RATIO, "%s kontur / parlak zemin" % id)


func test_player_rim_separates_from_ground() -> void:
	var g := _ground_colors()
	assert_gte(ratio(PlayerView.RIM_COLOR, g[0]), MIN_RATIO)
	assert_gte(ratio(PlayerView.RIM_COLOR, g[1]), MIN_RATIO)


func test_player_is_at_least_180px_tall() -> void:
	var rig := GameData.load_default().get_character(&"gunslinger").rig
	assert_gte(float(rig["display_height"]), 180.0, "makette oyuncu ~200 px (ara denetim #5)")


## N6 (M2): elit/Lord kontur rengi bronz/amber ailesinde (beyaza ya da kırmızıya kaçmaz); shader varsayılanı sabitle aynı.
func test_elite_rim_is_in_the_bronze_amber_family() -> void:
	var c := EnemyRenderer.RIM_ELITE_COLOR
	assert_between(c.h * 360.0, 25.0, 45.0, "ton bronz/amber (25–45°)")
	assert_between(c.s, 0.25, 0.75, "beyaza kaçmaz, doygunluk korunur")
	var base := EnemyRenderer.RIM_COLOR
	assert_between(absf(c.h - base.h) * 360.0, 0.0, 12.0, "taban düşman rimiyle aynı aile")
	var src := FileAccess.get_file_as_string("res://assets/shaders/enemy_flash.gdshader")
	assert_true(
		src.contains("mix(rim_color, rim_elite_color, v_elite)"), "elit rimi tint'ten gelmez"
	)
	assert_false(src.contains("clamp(v_tint * 1.25"), "tint'li rim kalmadı")


## M4 (S-02): seviye halkası koyu zeminde >= 3:1, 4 px çekirdek, α başlangıçta 0,9 ve 450. ms'de 0.
func test_level_ring_is_thick_visible_and_fades_from_point_nine() -> void:
	var g := _ground_colors()
	assert_gte(ratio(UiKit.XP_PARLAK, g[0]), MIN_RATIO, "halka / ortalama zemin")
	assert_gte(ratio(UiKit.XP_PARLAK, g[1]), MIN_RATIO, "halka / en parlak zemin")
	assert_gte(PlayerView.Aura.RING_W, 4.0, "kalınlık >= 4 px")
	# çizimdeki sayılar sabitlerle aynı (kabul testi kaynak metnine bakar: çekirdek 4, ışıma 4 + 8)
	var src := FileAccess.get_file_as_string("res://scripts/view/player_view.gd")
	assert_true(
		src.contains("col, %.1f, true)" % PlayerView.Aura.RING_W), "çekirdek kalınlığı sabit"
	)
	assert_true(
		src.contains("glow, %.1f, true)" % (PlayerView.Aura.RING_W + PlayerView.Aura.RING_GLOW_W)),
		"ışıma kalınlığı sabit"
	)
	assert_almost_eq(PlayerView.Aura.ring_alpha(0.0), 0.9, 1e-4)
	assert_almost_eq(PlayerView.Aura.ring_alpha(PlayerView.Aura.RING_MAX), 0.0, 1e-4)
	assert_gt(PlayerView.Aura.ring_alpha(120.0), 0.2, "yarıdan sonra da seçilir")
	var prev := 1.0
	for r in range(0, 181, 15):
		var a := PlayerView.Aura.ring_alpha(float(r))
		assert_lte(a, prev + 1e-6, "α azalır")
		prev = a
