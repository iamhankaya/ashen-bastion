class_name EnemyAtlas
extends RefCounted
## Düşman görsellerini tek dokuda toplar (tek MultiMesh = tek çizim). Hücre CELL x CELL, sprite hücre merkezinde,
## çevresinde saydam boşluk (rim konturu için). Çok kareli dosya (kargalar) `assets/gfx/manifest.json`'daki `frames`
## kadar hücre kaplar. Gerçek dosyası olmayan tür geçici görseli (PlaceholderArt) hücreye ölçeklenerek alır.

const CELL := 416
const COLS := 3
const MANIFEST := "res://assets/gfx/manifest.json"

## sprite yolu -> {"cell": ilk hücre, "frames": kare sayısı, "size": Vector2 (tek kare piksel boyutu)}
var cells: Dictionary = {}
var texture: Texture2D = null
var rows: int = 1


## `sprites`: benzersiz sprite yolları (sıra korunur). Döner: kendisi (zincirleme).
func build(sprites: Array[String]) -> EnemyAtlas:
	var frames_of := _manifest_frames()
	var plan: Array = []  # [path, frames, Image]
	var total := 0
	for path in sprites:
		var frames := 1
		var img: Image = null
		var tex := ArtLoader.texture(path)
		if tex != null:
			img = tex.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
			frames = int(frames_of.get(path.trim_prefix("res://"), 1))
		else:
			img = PlaceholderArt.enemy_texture().get_image()
		plan.append([path, frames, img])
		total += frames
	rows = maxi(1, ceili(float(total) / COLS))
	var atlas := Image.create_empty(COLS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	var cell := 0
	for p in plan:
		var path: String = p[0]
		var frames: int = p[1]
		var img: Image = p[2]
		var fw := img.get_width() / frames
		var fh := img.get_height()
		var scale := minf(1.0, float(CELL - 24) / float(maxi(fw, fh)))
		for f in frames:
			var frame := img.get_region(Rect2i(f * fw, 0, fw, fh))
			if scale < 1.0:
				frame.resize(
					maxi(1, roundi(fw * scale)),
					maxi(1, roundi(fh * scale)),
					Image.INTERPOLATE_LANCZOS
				)
			var cx := (cell + f) % COLS
			var cy := (cell + f) / COLS
			var dst := Vector2i(
				cx * CELL + (CELL - frame.get_width()) / 2,
				cy * CELL + (CELL - frame.get_height()) / 2
			)
			atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), dst)
		cells[path] = {"cell": cell, "frames": frames, "size": Vector2(fw, fh) * scale}
		cell += frames
	texture = ImageTexture.create_from_image(atlas)
	return self


static func _manifest_frames() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(MANIFEST):
		return out
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if d is Dictionary and d.get("files") is Dictionary:
		for k in d["files"].keys():
			out[k] = int(d["files"][k].get("frames", 1))
	return out
