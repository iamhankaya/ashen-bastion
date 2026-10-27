extends GutTest
## Kabul (v2.0.3 B): ruh küreleri — tip → görsel, üç tip ayırt edilir, sim değişmez, hareket azaltma.
## Kaynak: çatı kabul ölçütü #3, kullanıcı kararı (2026-10-26: normal–boss "ΔL* >= 15 VEYA boyut >= 1,8x + IoU <= 0,6" yeterli,
## boss koyultulmaz), DESIGN.md §5–6, sözleşme `GemTiers` (eşikler/doku yolları/ORB_PX değişmez).
## Dilim B kapalıyken pending. Test adı öneki `test_orb<N>_`: v2.0 dilim denetimi (tools/v2_slices.txt, simge B) sınıf süzgeci olmadığı için `test_b<N>_` adlarını kendi B dilimi sayıp gate kırıyor (Açık nokta). Ölçüm kuralı sabittir: her küre ORB_PX boyutuna indirilip 80 px tuvale ortalanır; opak = alfa >= 0,5.

const CANVAS := 80
const DELTA_L_MIN := 15.0
const SIZE_RATIO_MIN := 1.8
const IOU_MAX := 0.6

var _saved_reduce: bool = false


func before_each() -> void:
	_saved_reduce = Settings.hareket_azalt


func after_each() -> void:
	Settings.hareket_azalt = _saved_reduce


func _gate() -> bool:
	return V203Slice.require(self, "B")


func _image(tier: int) -> Image:
	var tex := load(GemTiers.TEXTURES[tier]) as Texture2D
	return tex.get_image() if tex != null else null


## Küre tuvali: ORB_PX'e indirilmiş, 80x80 ortalı görüntü.
func _canvas(tier: int) -> Image:
	var img := _image(tier)
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var px: int = GemTiers.ORB_PX[tier]
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var o := (CANVAS - px) / 2
	out.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(o, o))
	return out


static func _lstar(c: Color) -> float:
	var r := _lin(c.r)
	var g := _lin(c.g)
	var b := _lin(c.b)
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * b
	var f := pow(y, 1.0 / 3.0) if y > 0.008856 else 7.787 * y + 16.0 / 116.0
	return 116.0 * f - 16.0


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


## Opak piksellerin ortalama L*.
func _mean_l(img: Image) -> float:
	var sum := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a >= 0.5:
				sum += _lstar(c)
				n += 1
	return sum / float(maxi(n, 1))


func _iou(a: Image, b: Image) -> float:
	var inter := 0
	var uni := 0
	for y in CANVAS:
		for x in CANVAS:
			var pa := a.get_pixel(x, y).a >= 0.5
			var pb := b.get_pixel(x, y).a >= 0.5
			if pa and pb:
				inter += 1
			if pa or pb:
				uni += 1
	return float(inter) / float(maxi(uni, 1))


func _distinct(t1: int, t2: int) -> bool:
	var a := _canvas(t1)
	var b := _canvas(t2)
	if a == null or b == null:
		return false
	var dl := absf(_mean_l(a) - _mean_l(b))
	var big := float(maxi(GemTiers.ORB_PX[t1], GemTiers.ORB_PX[t2]))
	var small := float(mini(GemTiers.ORB_PX[t1], GemTiers.ORB_PX[t2]))
	return dl >= DELTA_L_MIN or (big / small >= SIZE_RATIO_MIN and _iou(a, b) <= IOU_MAX)


# --- görseller ---------------------------------------------------------------------------------------------------------


func test_orb1_three_orb_textures_exist_load_and_are_pairwise_different_files() -> void:
	if _gate():
		return
	var seen := {}
	for t in GemTiers.COUNT:
		var path: String = GemTiers.TEXTURES[t]
		assert_true(ResourceLoader.exists(path), "doku var: %s" % path)
		var img := _image(t)
		assert_not_null(img, path)
		if img == null:
			continue
		assert_lte(
			maxi(img.get_width(), img.get_height()), 512, "%s: APK boyutu için <= 512 px" % path
		)
		assert_false(img.is_invisible(), "%s: görünür piksel var" % path)
		var key := img.get_data().hex_encode().sha256_text()
		assert_false(seen.has(key), "%s başka bir küreyle aynı görsel" % path)
		seen[key] = true


func test_orb2_every_pair_of_orb_types_is_distinguishable_by_the_agreed_rule() -> void:
	if _gate():
		return
	assert_true(_distinct(GemTiers.NORMAL, GemTiers.ELIT), "normal–elit")
	assert_true(_distinct(GemTiers.ELIT, GemTiers.BOSS), "elit–boss")
	assert_true(_distinct(GemTiers.NORMAL, GemTiers.BOSS), "normal–boss (boyut + biçim)")


func test_orb2_boss_orb_is_the_largest_and_orb_sizes_stay_the_contract_values() -> void:
	if _gate():
		return
	assert_eq(GemTiers.ORB_PX, PackedInt32Array([44, 48, 80]))
	assert_gte(
		float(GemTiers.ORB_PX[GemTiers.BOSS]) / float(GemTiers.ORB_PX[GemTiers.NORMAL]),
		SIZE_RATIO_MIN
	)


func test_orb2_boss_orb_is_not_darkened_to_fake_a_difference() -> void:
	if _gate():
		return
	var boss := _canvas(GemTiers.BOSS)
	var normal := _canvas(GemTiers.NORMAL)
	assert_not_null(boss)
	assert_not_null(normal)
	if boss == null or normal == null:
		return
	assert_gte(
		_mean_l(boss),
		_mean_l(normal) - 5.0,
		"boss kürenin ortalama L* değeri normalden belirgin koyu değil"
	)


# --- sim değişmez ----------------------------------------------------------------------------------------------------------


func _sim_with_mixed_gems() -> GameSim:
	var sim := SimKit.make(7, {"data_kind": "quiet"})
	sim.gems.drop(Vector2(500, 500), 1)
	sim.gems.drop(Vector2(520, 500), 5)
	sim.gems.drop(Vector2(540, 500), 80)
	return sim


func test_orb3_rendering_orbs_never_changes_the_sim_hash_or_gem_pool() -> void:
	if _gate():
		return
	var sim := _sim_with_mixed_gems()
	var h0 := sim.state_hash()
	var count0 := sim.gems.count
	var total0 := sim.gems.total_value()
	var r := GemRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	r.refresh()
	r.refresh()
	assert_eq(sim.state_hash(), h0, "görünüm sim hash'ini değiştirmez")
	assert_eq(sim.gems.count, count0)
	assert_eq(sim.gems.total_value(), total0)
	assert_eq(r.visible_count(), count0, "her taş çizilir (tipe göre görsel, sayı aynı)")


func test_orb3_same_seed_same_hash_whether_or_not_a_renderer_watched() -> void:
	if _gate():
		return
	var a := _sim_with_mixed_gems()
	var b := _sim_with_mixed_gems()
	var r := GemRenderer.new()
	add_child_autofree(r)
	r.bind(a)
	for i in 120:
		a.step(Vector2.ZERO)
		b.step(Vector2.ZERO)
		r.refresh()
	assert_eq(a.state_hash(), b.state_hash(), "izleyen çizici sonucu etkilemez")


# --- hareket azaltma -------------------------------------------------------------------------------------------------------


func test_orb4_with_reduced_motion_orb_instances_do_not_drift_between_frames() -> void:
	if _gate():
		return
	Settings.hareket_azalt = true
	var sim := _sim_with_mixed_gems()
	var r := GemRenderer.new()
	add_child_autofree(r)
	r.bind(sim)
	r.refresh()
	var first := r.multimesh.buffer.duplicate()
	await get_tree().create_timer(0.35).timeout
	r.refresh()
	assert_eq(r.multimesh.buffer, first, "hareket azalt AÇIK: süzülme yok (elit/boss küre sabit)")
