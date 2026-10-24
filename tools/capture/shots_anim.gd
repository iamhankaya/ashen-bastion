extends SceneTree
## v1.1.1 oyuncu animasyonu kare dizisi (24 fps, görünüm saati): yürüme / bekleme→atış / doldurma. Kullanım:
##   xvfb-run -a -s "-screen 0 720x720x24" godot --path . --rendering-driver opengl3 --resolution 720x720 \
##     -s res://tools/capture/shots_anim.gd -- <çıktı_dizini> <walk|shoot|reload|walk8> [kademe]
## Çıktı: <senaryo>_NN.png + <senaryo>.json (kare başına rig/kol ölçümü). Montaj: tools/capture/anim_montage.py.
## `kademe` (yalnız v1.1.1+): PlayerAnim.bounce_tier. Eski sürümde (v1.1) bu bağımsız değişken yok sayılır.

const DT := 1.0 / 24.0
const W := 720
const H := 720
const ZOOM := 1.5
const SPEED := 300.0

var out_dir := "/tmp/shots_anim/"
var sim: GameSim
var view: PlayerView
var cam: Camera2D


class Floor:
	extends Node2D

	func _draw() -> void:
		draw_rect(Rect2(-4000, -1200, 12000, 2400), Color(0.13, 0.11, 0.14))
		for i in range(-100, 400):
			var x := float(i * 20)
			var thick := i % 5 == 0
			draw_line(
				Vector2(x, 0),
				Vector2(x, 24 if thick else 10),
				Color(0.8, 0.7, 0.5),
				2.0 if thick else 1.0
			)
		draw_line(Vector2(-4000, 0), Vector2(8000, 0), Color(0.45, 0.38, 0.3), 2.0)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0].path_join("")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var scen := args[1] if args.size() > 1 else "walk"
	if args.size() > 2:
		var pa: GDScript = load("res://scripts/view/player_anim.gd")
		for p in pa.get_script_property_list():
			if p["name"] == "bounce_tier":
				pa.set("bounce_tier", int(args[2]))
	_run(scen)


func _run(scen: String) -> void:
	sim = GameSim.new(11, &"gunslinger", {"end_mode": "timer", "end_time": 480.0})
	root.size = Vector2i(W, H)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.add_child(Floor.new())
	view = PlayerView.new()
	root.add_child(view)
	cam = Camera2D.new()
	root.add_child(cam)
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.make_current()
	sim.player_pos = Vector2(0, -float(sim.character.rig["display_height"]) * 0.5)
	view.bind(sim)
	view.update_view(DT)
	var rows: Array = []
	var n := 24
	for i in n:
		var d := _drive(scen, i)
		view.update_view(DT)
		cam.position = Vector2(sim.player_pos.x, sim.player_pos.y + 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir + "%s_%02d.png" % [scen, i])
		rows.append(_measure(i, d))
	var f := FileAccess.open(out_dir + scen + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "  "))
	f.close()
	quit(0)


## Kare i için sim durumunu sürer; kare etiketi döner.
func _drive(scen: String, i: int) -> String:
	match scen:
		"walk":  # sağa 8 kare, sola 8 kare (yön değiştirme), dur 8 kare
			var v := Vector2.ZERO
			if i < 8:
				v = Vector2(SPEED, 0)
				sim.player_facing_left = false
			elif i < 16:
				v = Vector2(-SPEED, 0)
				sim.player_facing_left = true
			sim.player_pos += v * DT
			_sim_aim_from_move(v)
			return "sağa" if i < 8 else ("sola" if i < 16 else "dur")
		"walk8":  # çapraz (sağ-yukarı) 8, dur 4, yürü-dur 4 kare, sola çapraz 8
			var v := Vector2.ZERO
			if i < 8:
				v = Vector2(SPEED, -SPEED) * 0.7071
				sim.player_facing_left = false
			elif i >= 12 and i < 16:
				v = Vector2(SPEED, 0)
			elif i >= 16:
				v = Vector2(-SPEED, SPEED) * 0.7071
				sim.player_facing_left = true
			sim.player_pos += v * DT
			_sim_aim_from_move(v)
			return "çapraz" if v != Vector2.ZERO else "dur"
		"shoot":  # sağa bakarken eski hedef sol-aşağı (150°); 14. karede sağda hedef belirir, atış
			sim.player_facing_left = false
			if i < 12:
				sim.gun_target[0] = -1
				sim.gun_target[1] = -1
				sim.gun_aim[0] = deg_to_rad(150.0)
				sim.gun_aim[1] = deg_to_rad(150.0)
				return "bekle"
			sim.gun_target[0] = 1
			sim.gun_target[1] = 2
			sim.gun_aim[0] = 0.05
			sim.gun_aim[1] = 0.05
			if i == 14:
				sim.bus.shot_fired.emit(0, Vector2.ZERO, Vector2.RIGHT)
			return "atış"
		"reload":  # hedef var (aim ~11°); doldurma 1 sn; 12. karede hedef sol-yukarıya geçer
			sim.player_facing_left = false
			sim.gun_target[0] = 1
			sim.gun_target[1] = 2
			var a := 0.2
			if i >= 12:
				a = deg_to_rad(165.0)
			sim.gun_aim[0] = a
			sim.gun_aim[1] = a
			if i == 0:
				sim.magazine.start_reload(sim.stats)
			sim.magazine.reload_left = maxf(
				0.0, sim.magazine.reload_total * (1.0 - float(i) / 24.0)
			)
			return "doldurma"
	return ""


## Gerçek sim: hedefsiz ve hareket varken gun_aim = hareket açısı (game_sim.gd _phase_targeting_fire).
func _sim_aim_from_move(v: Vector2) -> void:
	if v.length_squared() > 0.01:
		sim.gun_aim[0] = v.angle()
		sim.gun_aim[1] = v.angle()


func _measure(i: int, label: String) -> Dictionary:
	var rig := view.rig_node
	return {
		"i": i,
		"label": label,
		"rig_rot_deg": rad_to_deg(rig.rotation),
		"rig_y": rig.position.y,
		"body_sx": view.body.scale.x,
		"body_sy": view.body.scale.y,
		"arm0_world_deg": rad_to_deg(rig.rotation + view.near_arm.rotation),
		"arm1_world_deg": rad_to_deg(rig.rotation + view.far_arm.rotation),
		"arm0_flip": signf(view.near_arm.scale.y),
		"aim_sim_deg": rad_to_deg(sim.gun_aim[0]),
		"turn_x": view.anim.turn_x,
		"phase": view.anim.walk_phase,
	}
