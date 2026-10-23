class_name PlaceholderArt
extends RefCounted
## Geçici görseller (U1): kodla üretilen dokular ve 2B dörtgen ağ. Gerçek sanat U2'de assets/gfx'ten gelir.
## Dokular beyaz/gri tonlu çizilir; renk MultiMesh örnek rengi (tint) ile verilir. Önbellekli.

const ENEMY_SIZE := 128
const GEM_SIZE := 48
const BULLET_SIZE := Vector2i(64, 24)
const GROUND_SIZE := 256
const SHADOW_CORE := 0.45

static var _cache: Dictionary = {}


## Merkezli, UV'si 2B'ye göre (sol üst = 0,0) dörtgen ağ. QuadMesh 2B'de UV'yi ters çevirdiği için elle kurulur.
static func quad_mesh(size: Vector2) -> ArrayMesh:
	var key := "quad_%s" % size
	if _cache.has(key):
		return _cache[key]
	var h := size * 0.5
	var verts := PackedVector2Array(
		[Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	)
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var idx := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = mesh
	return mesh


## Alt bölümlü ızgara ağ (gövde salınım shader'ı için; köşe başına UV). Sol üst köşe orijinde.
static func grid_mesh(
	size: Vector2, cols: int, rows: int, origin: Vector2 = Vector2.ZERO
) -> ArrayMesh:
	var key := "grid_%s_%d_%d_%s" % [size, cols, rows, origin]
	if _cache.has(key):
		return _cache[key]
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for r in rows + 1:
		for c in cols + 1:
			var uv := Vector2(float(c) / cols, float(r) / rows)
			uvs.append(uv)
			verts.append(origin + uv * size)
	for r in rows:
		for c in cols:
			var a := r * (cols + 1) + c
			var b := a + 1
			var d := a + cols + 1
			var e := d + 1
			idx.append_array(PackedInt32Array([a, b, e, a, e, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = mesh
	return mesh


## Düşman: koyu konturlu, üstten ışık alan yuvarlak gövde + iki göz (beyaz tonlu; tint ile boyanır).
static func enemy_texture() -> Texture2D:
	if _cache.has("enemy"):
		return _cache["enemy"]
	var s := ENEMY_SIZE
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s, s) * 0.5
	var r := s * 0.46
	for y in s:
		for x in s:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			if d > r:
				continue
			var edge := clampf(r - d, 0.0, 1.0)
			var shade := 0.55 + 0.45 * clampf(1.0 - (p.y - (c.y - r)) / (2.0 * r), 0.0, 1.0)
			if d > r - 6.0:
				shade = 0.18  # kontur
			img.set_pixel(x, y, Color(shade, shade, shade, edge))
	# gözler (sıcak parıltı, tint'ten az etkilenmesi için açık)
	for e in [Vector2(-0.16, -0.12), Vector2(0.16, -0.12)]:
		var ec: Vector2 = c + e * s
		for y in range(int(ec.y) - 6, int(ec.y) + 7):
			for x in range(int(ec.x) - 6, int(ec.x) + 7):
				if Vector2(x, y).distance_to(ec) <= 5.5:
					img.set_pixel(x, y, Color(1, 0.95, 0.8, 1))
	var tex := ImageTexture.create_from_image(img)
	_cache["enemy"] = tex
	return tex


## XP taşı: eşkenar dörtgen kristal.
static func gem_texture() -> Texture2D:
	if _cache.has("gem"):
		return _cache["gem"]
	var s := GEM_SIZE
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var c := float(s) * 0.5
	for y in s:
		for x in s:
			var dx := absf(x + 0.5 - c) / (c * 0.62)
			var dy := absf(y + 0.5 - c) / (c * 0.95)
			var d := dx + dy
			if d > 1.0:
				continue
			var light := 1.0 if x + 0.5 < c else 0.72
			if d > 0.82:
				light = 0.45
			img.set_pixel(x, y, Color(light, light, light, clampf((1.0 - d) * 12.0, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	_cache["gem"] = tex
	return tex


## Mermi: sağa bakan, kuyruğu sönen ışık çizgisi (sıcak çekirdek).
static func bullet_texture() -> Texture2D:
	if _cache.has("bullet"):
		return _cache["bullet"]
	var w := BULLET_SIZE.x
	var h := BULLET_SIZE.y
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var t := float(x) / float(w - 1)  # 0 kuyruk, 1 baş
			var dy := absf(y + 0.5 - h * 0.5) / (h * 0.5)
			var core := clampf(1.0 - dy * (1.6 - 0.6 * t), 0.0, 1.0)
			var a := core * clampf(t * 1.4, 0.0, 1.0)
			if a <= 0.0:
				continue
			img.set_pixel(x, y, Color(1.0, 0.92 + 0.08 * core, 0.7 + 0.3 * core, a))
	var tex := ImageTexture.create_from_image(img)
	_cache["bullet"] = tex
	return tex


## Döşenebilir koyu zemin (dikişsiz gürültü; mor-kahve kül tonları + seyrek taş lekeleri).
static func ground_texture() -> Texture2D:
	if _cache.has("ground"):
		return _cache["ground"]
	var s := GROUND_SIZE
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var nimg := noise.get_seamless_image(s, s, false, false, 0.1, true)
	var dark := Color("#17101a")
	var mid := Color("#211820")
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var v := nimg.get_pixel(x, y).r
			var col := dark.lerp(mid, smoothstep(0.35, 0.75, v))
			if v > 0.8:
				col = col.lerp(Color("#2e2326"), 0.4)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_cache["ground"] = tex
	return tex


## Oyuncu gövdesi (geçici şekil): uzun palto silueti, atkı (bordo), kemik yüz. Sağa bakar.
static func body_texture() -> Texture2D:
	if _cache.has("body"):
		return _cache["body"]
	var w := 96
	var h := 160
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var coat := Color("#3a2a4a")
	var coat_dark := Color("#241a30")
	var scarf := Color("#8f2a36")
	var skin := Color("#cfc4ae")
	var hair := Color("#a39883")
	var boot := Color("#1c1411")
	for y in h:
		for x in w:
			var u := (x + 0.5) / w
			var v := (y + 0.5) / h
			var col := Color(0, 0, 0, 0)
			if v < 0.2:  # baş
				if Vector2(u - 0.5, (v - 0.11) * 1.6).length() < 0.2:
					col = skin if u > 0.48 else hair
			elif v < 0.88:  # palto (aşağı doğru genişler)
				var half := 0.2 + 0.18 * (v - 0.2)
				if absf(u - 0.5) < half:
					col = coat if u > 0.5 else coat_dark
					if v < 0.32 and absf(u - 0.5) < 0.22:
						col = scarf
			elif absf(u - 0.42) < 0.07 or absf(u - 0.6) < 0.07:  # çizmeler
				col = boot
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_cache["body"] = tex
	return tex


## Kol + tabanca (geçici şekil): pivot sol-orta, namlu sağda.
static func arm_texture() -> Texture2D:
	if _cache.has("arm"):
		return _cache["arm"]
	var w := 120
	var h := 48
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var sleeve := Color("#3a2a4a")
	var glove := Color("#2e211c")
	var metal := Color("#a88a5c")
	for y in h:
		for x in w:
			var u := (x + 0.5) / w
			var v := (y + 0.5) / h
			var col := Color(0, 0, 0, 0)
			if u < 0.55 and absf(v - 0.5) < 0.3:
				col = sleeve
			elif u < 0.68 and absf(v - 0.5) < 0.34:
				col = glove
			elif u < 0.98 and v > 0.25 and v < 0.5:
				col = metal  # namlu
			elif u < 0.78 and v >= 0.5 and v < 0.85:
				col = glove.lightened(0.15)  # kabza
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_cache["arm"] = tex
	return tex


## Yer gölgesi diski: ortada düz (yarıçapın SHADOW_CORE'u), kenara yumuşak düşer; soft_circle'dan çok daha dolgun.
static func shadow_disc(size: int = 128) -> Texture2D:
	var key := "shadow_%d" % size
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / c
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 - smoothstep(SHADOW_CORE, 1.0, d)))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Yumuşak daire (parlama).
static func soft_circle(size: int = 64) -> Texture2D:
	var key := "soft_%d" % size
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / c
			img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.5)))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
