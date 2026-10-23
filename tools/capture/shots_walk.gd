extends SceneTree
## Kareli yürüme ekran görüntüsü dizisi (D4-4 öz-kontrol; çıktı commit'lenebilir küçük montaj). Kullanım:
##   xvfb-run -a -s "-screen 0 720x720x24" godot --path . --rendering-driver opengl3 --resolution 720x720 \
##     -s res://tools/capture/shots_walk.gd -- <çıktı_dizini> synthetic [adım_px]
##   ... -- <çıktı_dizini> real <şerit.png> <manifest.json> [adım_px]
## Oyuncu kareden kareye `adım_px` (varsayılan stride/N) ilerler; kamera oyuncuyu izler, zeminde 20 px'lik cetvel var.
## `synthetic`: şerit çalışma anında üretilir; basan ayak macenta/turkuaz bloktur ve dünya x'i ölçülüp `walk.json`'a yazılır
## (basan ayağın zemin noktası kareden kareye sabit kalmalı = ayak kaymıyor). `real`: gerçek şeridi (kalite kapısı
## adayı) aynı şekilde oynatır; veriye bağlanmaz, yalnız görsel/ölçüm içindir.

const STRIDE := 136.0
const N := 6
const W := 720
const H := 720
const ZOOM := 1.5

var out_dir := "/tmp/shots_walk/"
var view: PlayerView
var sim: GameSim
var cam: Camera2D
var ruler: Ruler


## Zemin cetveli: her 20 px'te çizgi, her 100 px'te kalın çizgi (basan ayağın zeminde sabit kaldığı görülsün).
class Ruler:
	extends Node2D

	func _draw() -> void:
		draw_rect(Rect2(-4000, -1200, 12000, 2400), Color(0.13, 0.11, 0.14))
		for i in range(-100, 400):
			var x := float(i * 20)
			var thick := i % 5 == 0
			draw_line(
				Vector2(x, 0),
				Vector2(x, 0 + (24 if thick else 10)),
				Color(0.8, 0.7, 0.5),
				2.0 if thick else 1.0
			)
		draw_line(Vector2(-4000, 0), Vector2(8000, 0), Color(0.45, 0.38, 0.3), 2.0)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0].path_join("") if args.size() > 0 else out_dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run(args)


func _run(args: PackedStringArray) -> void:
	var mode := args[1] if args.size() > 1 else "synthetic"
	var step := STRIDE / N
	var frames := N
	var strip := "user://shots_walk_strip.png"
	var cell := Vector2i(177, 320)
	var dev: Array = []
	if mode == "real":
		strip = args[2]
		var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[3]))
		frames = int(man["frames"])
		cell = Vector2i(int(man["cell"][0]), int(man["cell"][1]))
		dev = man.get("shoulder_dev", [])
		step = STRIDE / frames
		if args.size() > 4:
			step = float(args[4])
	else:
		_write_synthetic_strip(strip, cell)
		if args.size() > 2:
			step = float(args[2])
	sim = GameSim.new(11, &"gunslinger", {"end_mode": "timer", "end_time": 480.0})
	var rig: Dictionary = sim.character.rig
	rig["walk"] = {
		"frames": frames,
		"stride": STRIDE,
		"strip": strip,
		"cell": [cell.x, cell.y],
		"shoulder_dev": dev
	}
	root.size = Vector2i(W, H)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED  # proje gerilmesi kapalı: 1 dünya px = ZOOM ekran px
	ruler = Ruler.new()
	root.add_child(ruler)
	view = PlayerView.new()
	root.add_child(view)
	cam = Camera2D.new()
	root.add_child(cam)
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.make_current()
	sim.player_pos = Vector2(0, -rig["display_height"] * 0.5)  # ayak y=0 (cetvel çizgisi)
	view.bind(sim)
	print("kare modu: ", view._strip_ready, " kare=", frames, " adım=", step)
	sim.player_pos.x += step * 0.5  # yarım adım: kare sınırlarına tam oturmasın (kayan nokta)
	sim.step_count += 1
	view.update_view(1.0 / 60.0)
	var rows: Array = []
	for i in frames * 2 + 2:
		sim.player_pos.x += step
		sim.step_count += 1
		view.update_view(1.0 / 60.0)
		cam.position = Vector2(sim.player_pos.x, sim.player_pos.y + 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(out_dir + "walk_%02d.png" % i)
		var m := _marker_world_x(img)
		rows.append(
			{
				"i": i,
				"phase": view.anim.walk_phase,
				"vel": view._vel.x,
				"frame": view.anim.frame_a,
				"player_x": sim.player_pos.x,
				"magenta_x": m[0],
				"cyan_x": m[1]
			}
		)
	var f := FileAccess.open(out_dir + "walk.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "  "))
	f.close()
	quit(0)


## Macenta ve turkuaz bloğun dünya x merkezi (yoksa NAN). Kamera ölçeği 1, merkez ekran ortası.
func _marker_world_x(img: Image) -> Array:
	var out: Array = []
	var xf := view.get_global_transform_with_canvas()
	var scl := xf.get_scale().x
	for want in [Color(1, 0, 1), Color(0, 1, 1)]:
		var sx := 0.0
		var cnt := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if (
					absf(c.r - want.r) < 0.25
					and absf(c.g - want.g) < 0.25
					and absf(c.b - want.b) < 0.25
				):
					sx += float(x)
					cnt += 1
		out.append(sim.player_pos.x + (sx / cnt - xf.origin.x) / scl if cnt > 6 else NAN)
	return out


## Duruş görselini her hücreye kopyalar; basan ayak yerine renkli blok: kare f'de (f%3) adım geriye (stride/N), yarım
## çevrimde ayak değişir (ilk yarı macenta, ikinci yarı turkuaz). Bloklar ayak çizgisinin hemen üstünde, hücre dünyası
## ölçeğinde (display_height / duruş px) stride/N = 22,67 px kayar.
func _write_synthetic_strip(path: String, cell: Vector2i) -> void:
	var body := load("res://assets/gfx/char/gunslinger_body.png") as Texture2D
	var src := body.get_image()
	src.convert(Image.FORMAT_RGBA8)
	var k := 200.0 / float(src.get_height())
	var step_px := int(round((STRIDE / N) / k))
	var img := Image.create(cell.x * (N + 1), cell.y, false, Image.FORMAT_RGBA8)
	for c in N + 1:
		img.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(c * cell.x, 0))
		if c == N:
			continue
		var half := c / 3
		var col := Color(1, 0, 1) if half == 0 else Color(0, 1, 1)
		var cx := c * cell.x + cell.x / 2 + int(round(0.5 * 3 * step_px)) - (c % 3) * step_px
		img.fill_rect(Rect2i(cx - 8, cell.y - 14, 16, 12), col)
	img.save_png(path)
