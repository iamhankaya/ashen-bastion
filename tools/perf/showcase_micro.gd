extends SceneTree
## v2.0 K3 bilgi ölçümü (gate'e girmez): Karakterler vitrininin `_process` maliyeti ve iş sayacı.
## Kullanım: xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/perf/showcase_micro.gd
## (--headless: çizim yok, yalnız `_process` mantığı ölçülür.) Kayıt/Settings dosyalarına dokunmaz.

const FRAMES := 600


func _initialize() -> void:
	var data := GameData.load_default()
	var scr := CharactersScreen.new()
	root.add_child(scr)
	scr.open(data, null, &"gunslinger")
	await process_frame
	var t0 := Time.get_ticks_usec()
	for i in FRAMES:
		scr._process(1.0 / 60.0)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / FRAMES
	print(
		(
			"görünür: _process %.4f ms/kare; parçacık amount=%d emitting=%s işleme=%s"
			% [ms, scr.particles.amount, scr.particles.emitting, scr.is_processing()]
		)
	)
	scr.visible = false
	await process_frame
	print(
		(
			"gizli:   parçacık emitting=%s işleme=%s (iş sayacı 0 beklenir)"
			% [scr.particles.emitting, scr.is_processing()]
		)
	)
	scr.visible = true
	await process_frame
	print("yeniden görünür: emitting=%s işleme=%s" % [scr.particles.emitting, scr.is_processing()])
	quit(0)
