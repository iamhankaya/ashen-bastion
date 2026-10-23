class_name ArtLoader
extends RefCounted
## Gerçek görsel yükleme yardımcıları: dosya varsa doku, yoksa null (çağıran geçici görsele düşer).
## `placeholder:<ad>` önekli yollar bilinçli olarak "gerçek görsel yok" demektir.

static var _cache: Dictionary = {}


## Gerçek dosya yolu mu (placeholder: değil ve var).
static func exists(path: String) -> bool:
	return path != "" and not path.begins_with("placeholder:") and ResourceLoader.exists(path)


## Doku (önbellekli) ya da null.
static func texture(path: String) -> Texture2D:
	if not exists(path):
		return null
	if _cache.has(path):
		return _cache[path]
	var t := load(path) as Texture2D
	_cache[path] = t
	return t


## Dokunun etrafına `pad` piksel saydam boşluk ekler (kontur/rim için). Önbellekli; null = dosya yok.
static func padded(path: String, pad: int) -> Texture2D:
	var key := "pad%d:%s" % [pad, path]
	if _cache.has(key):
		return _cache[key]
	var src := texture(path)
	if src == null:
		return null
	var img := src.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var out := Image.create_empty(
		img.get_width() + pad * 2, img.get_height() + pad * 2, false, Image.FORMAT_RGBA8
	)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(pad, pad))
	var tex := ImageTexture.create_from_image(out)
	_cache[key] = tex
	return tex


## Yatay şeridi `cells` eşit hücreye böler ve HER hücreyi ayrı `pad` piksel saydam boşlukla çevreler (rim komşu kareye
## sızmasın). Çıktı genişliği cells × (hücre + 2·pad). Önbellekli; dosya yok / hücreye bölünmüyorsa null.
## İçe aktarılmamış dosyayı (ör. user://) da okur: kare şeridi sentetik testlerde çalışma anında yazılır.
static func padded_cells(path: String, cells: int, pad: int) -> Texture2D:
	var key := "padc%d:%d:%s" % [pad, cells, path]
	if _cache.has(key):
		return _cache[key]
	if cells < 1 or path == "" or path.begins_with("placeholder:"):
		return null
	var img := _read_image(path)
	if img == null or img.get_width() % cells != 0:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var cw := img.get_width() / cells
	var ch := img.get_height()
	var out := Image.create_empty(cells * (cw + pad * 2), ch + pad * 2, false, Image.FORMAT_RGBA8)
	for c in cells:
		out.blit_rect(img, Rect2i(c * cw, 0, cw, ch), Vector2i(c * (cw + pad * 2) + pad, pad))
	var tex := ImageTexture.create_from_image(out)
	_cache[key] = tex
	return tex


static func _read_image(path: String) -> Image:
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		return t.get_image() if t != null else null
	if FileAccess.file_exists(path):
		return Image.load_from_file(path)
	return null
