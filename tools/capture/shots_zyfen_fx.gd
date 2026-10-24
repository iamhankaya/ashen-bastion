extends SceneTree
## Zyfen ikon + efekt öz-kontrolü (v2.0.2 A2a; masaüstü render, çıktı commit'lenmez). Kullanım:
##   xvfb-run -a -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 --resolution 720x1280 \
##     -s res://tools/capture/shots_zyfen_fx.gd -- <çıktı_dizini> [senaryo,senaryo]
## Senaryolar: levelup (aktif + pasif kartları), storm (Tufan+Hortum+Girdap), pocket (Hava Cebi), wave (Nefes Dalgası),
##   hurricane (Kasırga Patlaması), moon (Ay Orağı), spear (Göğün Mızrağı), bolt (kesik, Hava Bıçakları, Delen Rüzgar).

var out_dir := "/tmp/shots_zyfen_fx/"
var scenarios: PackedStringArray = [
	"levelup", "storm", "pocket", "wave", "hurricane", "moon", "spear", "bolt"
]
var c: Node
var waves: int = 0


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


func frames(n: int) -> void:
	for i in n:
		await process_frame


func tick(n: int, move: Vector2 = Vector2.ZERO) -> void:
	for i in n:
		if c.sim.state == GameSim.State.RUNNING:
			c.sim.step(move)
		c._update_views(1.0 / 60.0)
		c.fx_renderer.update_fx(1.0 / 60.0)


func fresh(grants: Dictionary = {}) -> void:
	if c != null:
		c.queue_free()
		await process_frame
	root.get_node("Settings").character_id = "zyfen"
	c = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(c)
	await frames(3)
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


func row(n: int) -> void:
	for k in n:
		var id: int = c.sim.debug_spawn(
			&"curumus_piyade", c.sim.player_pos + Vector2(260.0 + 70.0 * k, -20.0 + 22.0 * (k % 3))
		)
		c.sim.enemies.speed[EnemyPool.index_of(id)] = 0.0


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
			"storm":
				await fresh({"tufan": 1, "hortum": 5, "girdap": 5})
				ring(40, 300.0, 20.0)
				tick(100)
				await shot("fx_storm")
				tick(40)
				await shot("fx_storm_b")
			"pocket":
				await fresh({"hava_cebi": 5})
				ring(24, 220.0, 20.0)
				tick_until(func() -> bool: return c.sim.zones.count > 0, 600)
				tick(30)
				await shot("fx_pocket")
			"wave":
				await fresh({"nefes_dalgasi": 5})
				ring(24, 200.0, 0.0)
				var reached := tick_until(func() -> bool: return waves > 0, 900)
				print("wave ring ", reached)
				tick(8)
				await shot("fx_wave_a")
				tick(10)
				await shot("fx_wave_b")
			"hurricane":
				await fresh({"kasirga_patlamasi": 5})
				ring(24, 200.0, 0.0)
				tick_until(func() -> bool: return waves > 0, 1500)
				tick(10)
				await shot("fx_hurricane_a")
				tick(18)
				await shot("fx_hurricane_b")
			"moon":
				await fresh({"ay_oragi": 5})
				row(8)
				tick_until(func() -> bool: return _has_rad(30.0), 900)
				tick(8)
				await shot("fx_moon")
			"spear":
				await fresh({"gogun_mizragi": 5})
				row(8)
				tick_until(func() -> bool: return _fast(), 900)
				tick(4)
				await shot("fx_spear")
			"bolt":
				await fresh({"hava_bicaklari": 3})
				row(8)
				tick(20)
				await shot("fx_bolt_blades")
				await fresh()
				row(8)
				tick(25)
				await shot("fx_bolt_basic")
				await fresh({"bolunen_kesik": 5})
				row(8)
				tick(80)
				await shot("fx_bolt_split")
				await fresh({"delen_ruzgar": 5})
				row(8)
				tick(60)
				await shot("fx_bolt_delen")
	quit()


func _has_rad(r: float) -> bool:
	var p: ProjectilePool = c.sim.projectiles
	for i in p.count:
		if p.rad[i] >= r:
			return true
	return false


func _fast() -> bool:
	var p: ProjectilePool = c.sim.projectiles
	for i in p.count:
		if p.vel[i].length() >= ZyfenFx.SPEAR_SPEED:
			return true
	return false
