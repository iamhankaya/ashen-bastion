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
			rim = (def.tint * 1.25).clamp()
		assert_gte(ratio(rim, g[0]), MIN_RATIO, "%s kontur / zemin" % id)
		assert_gte(ratio(rim, g[1]), MIN_RATIO, "%s kontur / parlak zemin" % id)


func test_player_rim_separates_from_ground() -> void:
	var g := _ground_colors()
	assert_gte(ratio(PlayerView.RIM_COLOR, g[0]), MIN_RATIO)
	assert_gte(ratio(PlayerView.RIM_COLOR, g[1]), MIN_RATIO)


func test_player_is_at_least_180px_tall() -> void:
	var rig := GameData.load_default().get_character(&"gunslinger").rig
	assert_gte(float(rig["display_height"]), 180.0, "makette oyuncu ~200 px (ara denetim #5)")
