extends SceneTree
## Zyfen efekt v2 (katmanlı) öz-kontrolü (masaüstü render; çıktı docs/design/v2.0.2/fx-v2/ altına konur). Kullanım:
##   xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 \
##     -s res://tools/capture/shots_zyfen_fx.gd -- <çıktı_dizini> [senaryo,senaryo]
## Sabit tohum (SEED): aynı komut aynı sahneyi verir. Senaryolar: levelup (aktif + pasif kartları), hortum, tufan, girdap,
##   pocket (Hava Cebi + patlama), wave (Nefes Dalgası), hurricane (Kasırga Patlaması), basic (Rüzgar Kesiği + iz),
##   moon (Ay Orağı), split (Bölünen Kesik + kırılma), blades (Hava Bıçakları), delen (Delen Rüzgar + uç), spear (Göğün
##   Mızrağı), palm (avuç + isabet + büyük isabet), storm (Tufan+Hortum+Girdap), crowd (300 düşman + 3 hortum).
## Her senaryo yakın plan için `_zoom` ekleri üretir (kamera yakınlaştırması yalnız görünümdür).

const SEED := 20261025

var out_dir := "/tmp/shots_zyfen_fx/"
var scenarios: PackedStringArray = [
	"levelup",
	"hortum",
	"tufan",
	"girdap",
	"pocket",
	"wave",
	"hurricane",
	"basic",
	"moon",
	"split",
	"blades",
	"delen",
	"spear",
	"palm",
	"storm",
	"crowd",
]
var c: Node
var waves: int = 0
var zoom_base: Vector2 = Vector2.ONE


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0].path_join("")
	if args.size() > 1:
		scenarios = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir + n + ".png")
	print("shot ", n, " ", img.get_width(), "x", img.get_height())


## Yakın plan: kamerayı `z` kat yakınlaştırır, `n` kare bekler ve görüntü alır, sonra eski yakınlaştırmaya döner.
func shot_zoom(n: String, z: float) -> void:
	zoom_base = c.camera.zoom
	c.camera.zoom = zoom_base * z
	await frames(3)
	await shot(n)
	c.camera.zoom = zoom_base


func frames(n: int) -> void:
	for i in n:
		await process_frame


func tick(n: int, move: Vector2 = Vector2.ZERO) -> void:
	for i in n:
		if c.sim.state == GameSim.State.RUNNING:
			c.sim.step(move)
		c._update_views(1.0 / 60.0)
		c.fx_renderer.update_fx(1.0 / 60.0)


func fresh(grants: Dictionary = {}, character: String = "zyfen") -> void:
	if c != null:
		c.queue_free()
		await process_frame
	seed(SEED)
	root.get_node("Settings").character_id = character
	c = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(c)
	await frames(3)
	seed(SEED)
	c.start_run()
	await frames(2)
	waves = 0
	c.sim.fx.wind_wave.connect(func(_o: Vector2, _r: float, _b: bool) -> void: waves += 1)
	for k in grants:
		c.sim.debug_grant(StringName(k), int(grants[k]))
	c.sim.max_hp = 1.0e9
	c.sim.hp = 1.0e9
	c.set_process(false)


func ring(n: int, dist: float = 230.0, speed: float = 0.0) -> void:
	for k in n:
		var id: int = c.sim.debug_spawn(
			&"curumus_piyade",
			c.sim.player_pos + Vector2.from_angle(TAU * k / n) * (dist + 40.0 * (k % 3))
		)
		c.sim.enemies.speed[EnemyPool.index_of(id)] = speed


func row(n: int, tough: bool = false) -> void:
	for k in n:
		var id: int = c.sim.debug_spawn(
			&"curumus_piyade", c.sim.player_pos + Vector2(260.0 + 70.0 * k, -20.0 + 22.0 * (k % 3))
		)
		c.sim.enemies.speed[EnemyPool.index_of(id)] = 0.0
		if tough:
			c.sim.enemies.hp[EnemyPool.index_of(id)] = 1.0e6


## Koşul sağlanana kadar (en çok `limit` adım) tikler; sağlandıysa true.
func tick_until(cond: Callable, limit: int) -> bool:
	for i in limit:
		tick(1)
		if cond.call():
			return true
	return false


func _level_up(ids: Array[StringName], name: String) -> void:
	await fresh()
	c.sim.debug_force_choices(ids)
	c.sim.debug_add_xp(100000)
	c.sim.step(Vector2.ZERO)
	c._after_step()
	print(name, " state ", c.sim.state)
	c.flush_delay()
	await frames(50)
	await shot(name)


## Bölge (tür) indeksi; yoksa -1.
func zone_of(kind: int) -> int:
	var z: ZonePool = c.sim.zones
	for i in z.count:
		if z.kind[i] == kind:
			return i
	return -1


## Tufanlar aynı hedefe yığılır: ekran görüntüsü için (yalnız sahne düzeni) birbirinden ayırıp durdurur.
func _spread_giants() -> void:
	var z: ZonePool = c.sim.zones
	var k := 0
	for i in z.count:
		if z.kind[i] == ZonePool.KIND_GIANT:
			z.pos[i] = (
				c.sim.player_pos + Vector2.from_angle(-1.2 + 1.6 * k) * 330.0 * float(k + 1) * 0.6
			)
			z.speed[i] = 0.0
			k += 1


func wait_zone(kind: int, limit: int = 1500) -> bool:
	return tick_until(func() -> bool: return zone_of(kind) >= 0, limit)


## Bölge ömrü `left` sn altına inene kadar tikler.
func wait_zone_life(kind: int, left: float, limit: int = 2000) -> bool:
	return tick_until(
		func() -> bool:
			var i := zone_of(kind)
			return i >= 0 and c.sim.zones.life[i] < left,
		limit
	)


func zone_pos(kind: int) -> Vector2:
	var i := zone_of(kind)
	return c.sim.zones.pos[i] if i >= 0 else c.sim.player_pos


## Kamerayı `at`e alıp `z` kat yakınlaştırır, görüntü alır, geri döner. Bir sonraki tick kamerayı oyuncuya geri alır.
func close_up(n: String, at: Vector2, z: float = 1.8) -> void:
	zoom_base = c.camera.zoom
	c.camera.zoom = zoom_base * z
	c.camera.position = at
	c.camera.offset = Vector2.ZERO
	await frames(3)
	await shot(n)
	c.camera.zoom = zoom_base
	c.camera.position = c.sim.player_pos


func first_projectile(min_rad: float = 0.0, min_speed: float = 0.0) -> int:
	var p: ProjectilePool = c.sim.projectiles
	for i in p.count:
		if p.rad[i] >= min_rad and p.vel[i].length() >= min_speed:
			return i
	return -1


func projectile_pos(min_rad: float = 0.0, min_speed: float = 0.0) -> Vector2:
	var i := first_projectile(min_rad, min_speed)
	return c.sim.projectiles.pos[i] if i >= 0 else c.sim.player_pos


func _run() -> void:
	for sc in scenarios:
		match sc:
			"levelup":
				await _level_up([&"hava_bicaklari", &"girdap", &"hortum"], "fx_levelup_active")
				await _level_up(
					[&"agir_kursun", &"cevik_cizme", &"fazladan_mermi"], "fx_levelup_passive_a"
				)
				await _level_up(
					[&"hizli_doldurma", &"hizli_parmak", &"miknatis"], "fx_levelup_passive_b"
				)
				await _level_up(
					[&"saglam_yelek", &"tufan", &"kasirga_patlamasi"], "fx_levelup_mixed"
				)
			"hortum":
				await fresh({"hortum": 5})
				ring(24, 260.0, 0.0)
				print("hortum ", wait_zone(ZonePool.KIND_TWISTER))
				tick(8)
				await shot("fx_hortum_dogus")
				tick(70)
				await shot("fx_hortum_ayakta")
				await close_up(
					"fx_hortum_ayakta_yakin", zone_pos(ZonePool.KIND_TWISTER) + Vector2(0, -120)
				)
				tick(20)
				await close_up(
					"fx_hortum_ayakta_yakin_b", zone_pos(ZonePool.KIND_TWISTER) + Vector2(0, -120)
				)
				wait_zone_life(ZonePool.KIND_TWISTER, 0.2)
				await close_up(
					"fx_hortum_sonus", zone_pos(ZonePool.KIND_TWISTER) + Vector2(0, -120)
				)
			"tufan":
				await fresh({"tufan": 1, "hortum": 1})
				ring(30, 300.0, 0.0)
				print("tufan ", wait_zone(ZonePool.KIND_GIANT))
				_spread_giants()
				tick(10)
				await shot("fx_tufan_dogus")
				tick(60)
				await shot("fx_tufan_ayakta")
				var at := zone_pos(ZonePool.KIND_GIANT) + Vector2(0, -200)
				await close_up("fx_tufan_ayakta_yakin", at, 1.4)
				# şimşek çakışını yakala (sim zamanı deterministik)
				for k in 40:
					tick(3)
					var t: float = (
						c.sim.time + float(c.sim.zones.gen[zone_of(ZonePool.KIND_GIANT)]) * 0.31
					)
					if (
						fposmod(t, WindRenderer.BOLT_PERIOD) < 0.08
						and (
							WindRenderer._hash01(
								(
									int(floor(t / WindRenderer.BOLT_PERIOD)) * 7
									+ c.sim.zones.gen[zone_of(ZonePool.KIND_GIANT)] * 13
								)
							)
							<= WindRenderer.BOLT_CHANCE
						)
					):
						break
				await close_up(
					"fx_tufan_simsek_yakin", zone_pos(ZonePool.KIND_GIANT) + Vector2(0, -200), 1.4
				)
				wait_zone_life(ZonePool.KIND_GIANT, 0.2)
				await close_up(
					"fx_tufan_sonus", zone_pos(ZonePool.KIND_GIANT) + Vector2(0, -200), 1.4
				)
			"girdap":
				await fresh({"girdap": 5})
				ring(20, 150.0, 20.0)
				tick(60)
				await shot("fx_girdap_a")
				await close_up("fx_girdap_yakin_a", c.sim.player_pos, 1.6)
				tick(25)
				await close_up("fx_girdap_yakin_b", c.sim.player_pos, 1.6)
			"pocket":
				await fresh({"hava_cebi": 5})
				ring(24, 220.0, 20.0)
				print("pocket ", wait_zone(ZonePool.KIND_POCKET))
				tick(30)
				await shot("fx_pocket")
				await close_up("fx_pocket_yakin", zone_pos(ZonePool.KIND_POCKET), 2.0)
				wait_zone_life(ZonePool.KIND_POCKET, WindRenderer.BURST_TIME * 0.6)
				await close_up("fx_pocket_patlama", zone_pos(ZonePool.KIND_POCKET), 2.0)
			"wave":
				await fresh({"nefes_dalgasi": 5})
				ring(24, 200.0, 0.0)
				var reached := tick_until(func() -> bool: return waves > 0, 900)
				print("wave ring ", reached)
				tick(6)
				await shot("fx_wave_a")
				tick(12)
				await shot("fx_wave_b")
				tick(14)
				await shot("fx_wave_c")
			"hurricane":
				await fresh({"kasirga_patlamasi": 5})
				ring(24, 200.0, 0.0)
				tick_until(func() -> bool: return waves > 0, 1500)
				tick(5)
				await shot("fx_hurricane_a")
				tick(10)
				await shot("fx_hurricane_b")
				tick(14)
				await shot("fx_hurricane_c")
			"basic":
				await fresh()
				row(8)
				tick(18)
				await shot("fx_basic")
				await close_up("fx_basic_yakin", projectile_pos(), 2.2)
			"moon":
				await fresh({"ay_oragi": 5})
				row(8)
				tick_until(func() -> bool: return first_projectile(30.0) >= 0, 900)
				tick(8)
				await shot("fx_moon")
				await close_up("fx_moon_yakin", projectile_pos(30.0), 1.8)
				tick(11)
				await close_up("fx_moon_yakin_b", projectile_pos(30.0), 1.8)
			"split":
				await fresh({"bolunen_kesik": 5})
				row(8)
				var burst := func() -> bool:
					var pr: ProjectileRenderer = c.projectile_renderer
					for b in ProjectileRenderer.MAX_BURSTS:
						if c.sim.time - pr._burst_t0[b] < 0.09 and c.sim.time >= pr._burst_t0[b]:
							return true
					return false
				print("split ", tick_until(burst, 1500))
				await shot("fx_split")
				var bp: Vector2 = c.projectile_renderer._burst_pos[
					(c.projectile_renderer._burst_head + ProjectileRenderer.MAX_BURSTS - 1)
					% ProjectileRenderer.MAX_BURSTS
				]
				await close_up("fx_split_kirilma_yakin", bp, 2.2)
				tick(7)
				await close_up("fx_split_parca_yakin", bp, 2.2)
			"blades":
				await fresh({"hava_bicaklari": 3})
				row(8)
				tick(20)
				await shot("fx_blades")
				await close_up("fx_blades_yakin", projectile_pos(), 2.4)
				tick(2)
				await close_up("fx_blades_yakin_b", projectile_pos(), 2.4)
			"delen":
				await fresh({"delen_ruzgar": 5})
				row(8)
				tick_until(
					func() -> bool: return first_projectile(0.0, ZyfenFx.SPEAR_SPEED) >= 0, 900
				)
				tick(6)
				await shot("fx_delen")
				await close_up("fx_delen_yakin", projectile_pos(0.0, ZyfenFx.SPEAR_SPEED), 2.2)
				var hit_soon := func() -> bool:
					var pr: ProjectileRenderer = c.projectile_renderer
					for h in ProjectileRenderer.MAX_HITS:
						if c.sim.time - pr._hit_t[h] < 0.05 and c.sim.time >= pr._hit_t[h]:
							return true
					return false
				print("delen isabet ", tick_until(hit_soon, 300))
				await close_up(
					"fx_delen_isabet_yakin", projectile_pos(0.0, ZyfenFx.SPEAR_SPEED), 2.2
				)
			"spear":
				await fresh({"gogun_mizragi": 5})
				row(8)
				tick_until(
					func() -> bool: return first_projectile(0.0, ZyfenFx.SPEAR_SPEED) >= 0, 900
				)
				tick(2)
				await shot("fx_spear")
				await close_up(
					"fx_spear_cikis_yakin",
					projectile_pos(0.0, ZyfenFx.SPEAR_SPEED) - Vector2(120, 0),
					1.7
				)
				tick(6)
				await close_up("fx_spear_yakin", projectile_pos(0.0, ZyfenFx.SPEAR_SPEED), 2.2)
			"palm":
				await fresh()
				row(6, true)
				var shots := [0]
				c.sim.bus.shot_fired.connect(
					func(_g: int, _o: Vector2, _d: Vector2) -> void: shots[0] += 1
				)
				tick_until(func() -> bool: return shots[0] > 0, 600)
				tick(2)
				await shot("fx_palm_cast")
				await close_up("fx_palm_cast_yakin", c.sim.player_pos + Vector2(30, -30), 2.6)
				var hit_now := func() -> bool:
					return c.fx_renderer._hit_left.count(0.0) < FxRenderer.MAX_HITS
				print("palm isabet ", tick_until(hit_now, 600))
				var hp: Vector2 = c.fx_renderer._hit_pos[
					(c.fx_renderer._hit_head + FxRenderer.MAX_HITS - 1) % FxRenderer.MAX_HITS
				]
				await close_up("fx_isabet_yakin", hp, 2.6)
				await fresh({"ay_oragi": 5})
				row(6, true)
				var big := func() -> bool:
					for k in FxRenderer.MAX_HITS:
						if c.fx_renderer._hit_left[k] > 0.0 and c.fx_renderer._hit_big[k] != 0:
							return true
					return false
				print("buyuk isabet ", tick_until(big, 900))
				var hp2: Vector2 = c.fx_renderer._hit_pos[
					(c.fx_renderer._hit_head + FxRenderer.MAX_HITS - 1) % FxRenderer.MAX_HITS
				]
				await close_up("fx_isabet_buyuk_yakin", hp2, 2.2)
			"storm":
				await fresh({"tufan": 1, "hortum": 5, "girdap": 5})
				ring(40, 300.0, 20.0)
				tick(100)
				await shot("fx_storm")
				tick(40)
				await shot("fx_storm_b")
			"crowd":
				await fresh({"tufan": 1, "hortum": 5, "girdap": 5})
				c.sim.debug_fill(&"curumus_piyade", 300, 420.0)
				tick(240)
				await shot("fx_crowd")
				var wr: WindRenderer = c.fx_renderer.wind_renderer
				print(
					"crowd zones ",
					c.sim.zones.count,
					" drawn ",
					wr.drawn_count,
					" draw_calls ",
					wr.draw_calls(),
					" (tavan ",
					WindRenderer.MAX_DRAW_CALLS,
					")"
				)
	quit()
