class_name WindRenderer
extends Node2D
## Rüzgar bölgeleri ve Girdap halkası (yalnız görsel; sim'i okur, hiçbir sim durumunu değiştirmez). FxRenderer'ın çocuğudur
## ve harmanlama malzemesini ondan alır. v2 (katmanlı, ZyfenFx dokuları): her bölge ayrı parçalardan kurulur ve parçalar
## kodla canlandırılır. Üç çizim geçişi (düğüm sırası = çizim sırası): ARKA (bu düğüm: taban halkası, arkadaki taşlar,
## gövde), AKIŞ (çocuk: `hortum_akis` gövde alfasına maskeli, yukarı kayan doku; gölgelendirici), ÖN (çocuk: öndeki
## taşlar, şimşek). Girdap oyuncunun çevresinde arka geçişte, bölgelerin altında. Ekran içi bölge sayısı MAX_DRAWN, toplam
## çizim çağrısı MAX_DRAW_CALLS ile sınırlıdır (300 düşman + 3 hortum perf bütçesi); kalabalıkta taş/şimşek sayısı düşürülür.

const MAX_DRAWN := 24
## Üç geçişte toplam doku çizimi tavanı (kalite kademesi bunu garanti eder; test_v202_wind_renderer ölçer).
const MAX_DRAW_CALLS := 110
## Dönüş hızları (rad/sn); taban halkaları ve halkalar yavaş döner.
const TWISTER_SPIN := 0.55
const GIANT_SPIN := 0.35
const POCKET_SPIN := -0.8
const GIRDAP_SPIN := 0.7
## Doğuşta tabandan büyüme ve sönüşte incelme süresi (sn).
const GROW_TIME := 0.55
const FADE_TIME := 0.5
## Hava Cebi bitişinde patlama süresi (sn): küre sönerken `hava_cebi_patlama` genişler.
const BURST_TIME := 0.3
## Gövde tuval genişliği / bölge yarıçapı (Hortum, Tufan); yükseklik doku oranından (1:2). Taban tuval genişliği / yarıçap.
const TWISTER_BODY := 1.25
const GIANT_BODY := 1.6
const BASE_WIDTH := 2.4
## Gövde dokusunda görünür içeriğin alt ucu (tuval yüksekliği oranı): zemin noktası bunun hizasındadır.
const BODY_FOOT := 0.87
## Gövde içi görünür yükseklik (zemin noktasından tepeye, tuval yüksekliği oranı) ve gövde alt/üst çıplak genişlik oranı.
const BODY_SPAN := 0.69
const BODY_HALF := 0.41
## Gövde sallanması: tepe yatay kayma (gövde yüksekliği oranı) ve hızı.
const SWAY_AMOUNT := 0.05
const SWAY_SPEED := 1.7
## Bölge alfası (harmanlama alfa; additive ekranı beyaza boğdu).
const ALPHA_TWISTER := 0.66
const ALPHA_GIANT := 0.7
const ALPHA_POCKET := 0.68
## Hava Cebi küresi ve iç girdabı: iç girdap alfa oranı ile harita paletine yakın sıcak ton (T81, fx-v2d).
const POCKET_INNER := 0.8
const POCKET_TINT := Color(0.93, 0.89, 0.84)
## Girdap: dış halka çok soluk, iç spiral neredeyse görünmez (oyuncu ve düşmanların üstünü kapatmasın).
const ALPHA_GIRDAP := 0.55
const GIRDAP_INNER := 0.6
const GIRDAP_TINT := Color(0.925, 0.89, 0.84)
## Gövde merkez saydamlığı (kenar şeritleri tam görünür).
const BODY_CENTER_ALPHA := 0.7
## Taban alfası ve rengi: soluk, zemin tozu/kül tonunda.
const ALPHA_BASE := 0.65
const BASE_TINT := Color(0.87, 0.81, 0.75)
## Üst üste binen hortumlar: üstte kalan her ek hortumun alfa çarpanı (OVERLAP_MIN altına inmez), binme eşiği (yarıçap
## toplamı oranı) ve ekrandaki toplam hortum sayısına göre genel soluklaşma (CROWD_FADE her ek hortum için, CROWD_MIN tabanı).
const OVERLAP_FADE := 0.55
const OVERLAP_MIN := 0.2
const OVERLAP_REACH := 0.7
const CROWD_FADE := 0.04
const CROWD_MIN := 0.55
## Çizim boyutu tavanı: gövde görünür yüksekliği ekran yüksekliğinin bu oranını aşmaz (yalnız çizim; sim yarıçapı değişmez).
const MAX_BODY_SCREEN := 0.35
## Gövde ölçek nabzı (yatay): dönüyormuş hissi.
const PULSE_AMOUNT := 0.035
const PULSE_SPEED := 5.3
## Akış katmanı alfası ve hız çarpanı (Tufan daha ağır döner).
const FLOW_ALPHA_TWISTER := 0.5
const FLOW_ALPHA_GIANT := 0.46
## Akış dönüş hızı (devir/sn, gövde çevresinde) ve hafif yukarı kayma (doku/sn). Açısal hız sabit: huni genişliği hızı belirler.
const FLOW_SPIN_TWISTER := 0.45
const FLOW_SPIN_GIANT := 0.3
const FLOW_UP := 0.1
## Akış dokusunun gövde üstündeki döşeme boyutu (px, dünya).
const FLOW_TILE_PX := 130.0
## Yörünge: (hız rad/sn, yükseklik oranı, boyut px) taş başına; Tufan'da daha çok ve daha geniş (ikinci halka).
const TWISTER_STONES := [
	Vector3(2.6, 0.30, 24.0),
	Vector3(3.3, 0.58, 20.0),
	Vector3(2.1, 0.45, 22.0),
	Vector3(3.8, 0.72, 17.0),
]
const GIANT_STONES := [
	Vector3(1.9, 0.28, 34.0),
	Vector3(2.5, 0.55, 28.0),
	Vector3(1.6, 0.42, 32.0),
	Vector3(2.9, 0.70, 24.0),
	Vector3(-2.2, 0.22, 30.0),
	Vector3(-1.5, 0.48, 36.0),
	Vector3(-2.7, 0.64, 26.0),
	Vector3(-1.8, 0.80, 22.0),
]
## Taş çizim boyutu çarpanı (tas_* dokuları koyu; telefonda okunur olsun).
const STONE_SCALE := 1.9
## Yörünge elipsinin yükseklik/genişlik oranı (3/4 bakış) ve gövdeden dışa pay (gövde genişliği oranı).
const ORBIT_SQUASH := 0.3
const ORBIT_GAP := 0.14
## Şimşek: çakma aralığı, görünür süre, çakma olasılığı.
const BOLT_PERIOD := 0.55
const BOLT_TIME := 0.16
const BOLT_CHANCE := 0.6
## Kalabalık kademesi: ekranda bu kadar bölgeden sonra taş yarıya, daha çoğunda taşsız/şimşeksiz (çizim çağrısı bütçesi).
const CROWD_HALF := 6
const CROWD_NONE := 12
## Arka katmanlar FxRenderer'ın (z 5) bu kadar altına, ön katman FRONT_Z kadar üstüne çizilir.
const BACK_Z := 10
const FRONT_Z := 5
const PASS_BACK := 0
const PASS_FLOW := 1
const PASS_FRONT := 2
const PASS_BODY := 3

var _sim: GameSim = null
var _camera: CameraRig = null
## Son çizimde çizilen bölge sayısı (testler ve perf ölçümü için).
var drawn_count: int = 0
## Son çizimde her geçişin doku çizim sayısı (ARKA, AKIŞ, ÖN) ve toplamı.
var calls: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Bölge kimliği (ZonePool.gen) -> ilk görüldüğü sim zamanı (doğuşta büyüme için; yalnız görünüm).
var _birth: Dictionary = {}
## Bölge indeksi -> üst üste binme/kalabalık alfa çarpanı (her çizim geçişinde yeniden hesaplanır).
var _fade: PackedFloat32Array = PackedFloat32Array()
var _body_layer: Layer = null
var _flow_layer: Layer = null
var _front_layer: Layer = null


## Akış ve ön geçiş düğümü: çizimi sahibine (WindRenderer) devreder.
class Layer:
	extends Node2D
	var owner_renderer: WindRenderer
	var pass_id: int = 0

	func _draw() -> void:
		owner_renderer._draw_pass(self, pass_id)


func _init() -> void:
	use_parent_material = ZyfenFx.ZONES_ADDITIVE
	# Çizim sırası: gövde ve akış düşman/kürelerin ARKASINDA (z -5), yalnız ön taşlar/şimşek önünde (z 10).
	z_index = -BACK_Z
	_body_layer = _make_layer(PASS_BODY, "Body")
	_flow_layer = _make_layer(PASS_FLOW, "Flow")
	_front_layer = _make_layer(PASS_FRONT, "Front")
	_front_layer.z_index = BACK_Z + FRONT_Z
	var body_shader := ZyfenFx.shader("wind_body")
	if body_shader != null:
		var bm := ShaderMaterial.new()
		bm.shader = body_shader
		bm.set_shader_parameter("center_alpha", BODY_CENTER_ALPHA)
		bm.set_shader_parameter("grade_sat", ZyfenFx.GRADE_SAT)
		_body_layer.material = bm
		_body_layer.use_parent_material = false
	var shader := ZyfenFx.shader("wind_flow")
	if shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("flow", ZyfenFx.texture(ZyfenFx.HORTUM_AKIS))
		ZyfenFx.apply_grade(sm)
		_flow_layer.material = sm
		_flow_layer.use_parent_material = false


func _make_layer(pass_id: int, layer_name: String) -> Layer:
	var l := Layer.new()
	l.name = layer_name
	l.owner_renderer = self
	l.pass_id = pass_id
	l.use_parent_material = ZyfenFx.ZONES_ADDITIVE
	add_child(l)
	return l


func bind(sim: GameSim, camera: CameraRig = null) -> void:
	_sim = sim
	_camera = camera
	drawn_count = 0
	calls.fill(0)
	_birth.clear()
	_redraw_all()


func _redraw_all() -> void:
	queue_redraw()
	_body_layer.queue_redraw()
	_flow_layer.queue_redraw()
	_front_layer.queue_redraw()


## Toplam doku çizim sayısı (üç geçiş).
func draw_calls() -> int:
	return calls[PASS_BACK] + calls[PASS_BODY] + calls[PASS_FLOW] + calls[PASS_FRONT]


## Her kare (FxRenderer.update_fx çağırır): bölge ya da Girdap varsa yeniden çiz, yoksa bir kez temizle.
func refresh() -> void:
	if _sim == null:
		if drawn_count > 0 or draw_calls() > 0:
			drawn_count = 0
			calls.fill(0)
			_redraw_all()
		return
	_note_births()
	if _sim.zones.count > 0 or _girdap_radius() > 0.0 or draw_calls() > 0:
		_redraw_all()


## Yeni bölge kimliklerinin doğuş zamanını kaydeder; ölenleri atar.
func _note_births() -> void:
	var z := _sim.zones
	for i in z.count:
		if not _birth.has(z.gen[i]):
			_birth[z.gen[i]] = _sim.time
	if _birth.size() > z.count + 16:
		var live := {}
		for i in z.count:
			live[z.gen[i]] = _birth[z.gen[i]]
		_birth = live


## Etkin Girdap yarıçapı (yoksa 0).
func _girdap_radius() -> float:
	var st := _sim.loadout.state_of(&"girdap")
	if st == null or st.behavior == null:
		return 0.0
	return float(st.behavior.call(&"current_radius"))


## Dünya uzayında ekran alanı (kamera yoksa sınırsız: testler).
func _view_rect() -> Rect2:
	if _camera == null:
		return Rect2(Vector2(-1.0e6, -1.0e6), Vector2(2.0e6, 2.0e6))
	var size := _camera.view_size()
	return Rect2(_camera.get_screen_center_position() - size * 0.5, size)


## Ekranda görünen bölgelerin indeksleri (en çok MAX_DRAWN). Gövde yukarı uzar: kenar payı yüksekliğe göre.
func _visible_zones() -> PackedInt32Array:
	var out := PackedInt32Array()
	var view := _view_rect()
	var z := _sim.zones
	for i in z.count:
		if out.size() >= MAX_DRAWN:
			break
		var r := z.radius[i]
		var reach := (
			r * (GIANT_BODY * 2.0 if z.kind[i] == ZonePool.KIND_GIANT else TWISTER_BODY * 2.0)
		)
		if z.kind[i] == ZonePool.KIND_POCKET:
			reach = r
		if view.grow(reach).has_point(z.pos[i]):
			out.append(i)
	return out


func _draw() -> void:
	_draw_pass(self, PASS_BACK)


## Üç geçişten biri: `ci` çizilen düğüm. Hepsi sim durumunun ve sim zamanının saf fonksiyonudur.
func _draw_pass(ci: CanvasItem, pass_id: int) -> void:
	calls[pass_id] = 0
	if pass_id == PASS_BACK:
		drawn_count = 0
	if _sim == null:
		return
	_note_births()
	var vis := _visible_zones()
	var quality := 2
	if vis.size() > CROWD_NONE:
		quality = 0
	elif vis.size() > CROWD_HALF:
		quality = 1
	var t := _sim.time
	var z := _sim.zones
	var n := 0
	_compute_fade(vis)
	if pass_id == PASS_BACK:
		drawn_count = vis.size()
		var gr := _girdap_radius()
		if gr > 0.0:
			n += _draw_girdap(ci, gr, t)
	for i in vis:
		match z.kind[i]:
			ZonePool.KIND_POCKET:
				if pass_id == PASS_BACK:
					n += _draw_pocket(ci, i, t)
			ZonePool.KIND_GIANT:
				n += _draw_funnel(ci, pass_id, i, t, true, quality)
			_:
				n += _draw_funnel(ci, pass_id, i, t, false, quality)
	calls[pass_id] = n
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Hortum/Tufan bölgelerinin alfa çarpanı: aynı noktada üst üste binen her ek hortum soluk çizilir (OVERLAP_FADE^k), ekrandaki
## hortum sayısı arttıkça hepsi biraz daha solar. Yalnız çizim; sim'e dokunulmaz.
func _compute_fade(vis: PackedInt32Array) -> void:
	var z := _sim.zones
	_fade.resize(maxi(z.count, 1))
	var funnels := PackedInt32Array()
	for i in vis:
		if z.kind[i] != ZonePool.KIND_POCKET:
			funnels.append(i)
	var crowd := maxf(CROWD_MIN, 1.0 - CROWD_FADE * float(maxi(funnels.size() - 1, 0)))
	for a in funnels.size():
		var i := funnels[a]
		var k := 0
		for b in a:
			var j := funnels[b]
			var reach := (z.radius[i] + z.radius[j]) * OVERLAP_REACH
			if z.pos[i].distance_squared_to(z.pos[j]) < reach * reach:
				k += 1
		_fade[i] = maxf(OVERLAP_MIN, pow(OVERLAP_FADE, float(k))) * crowd


## Gövdenin çizim boyutu çarpanı: görünür yükseklik ekran yüksekliğinin MAX_BODY_SCREEN oranını aşmaz (<= 1).
func _size_cap(hb: float) -> float:
	if _camera == null:
		return 1.0
	var visible_h := hb * BODY_SPAN
	if visible_h <= 0.0:
		return 1.0
	return minf(1.0, MAX_BODY_SCREEN * _camera.view_size().y / visible_h)


## Doğuş büyümesi (0..1, yumuşak) ve sönüş çarpanı (1 -> 0).
func _grow_fade(i: int, t: float) -> Vector2:
	var z := _sim.zones
	var age := t - float(_birth.get(z.gen[i], t - GROW_TIME))
	var g := smoothstep(0.0, 1.0, clampf(age / GROW_TIME, 0.0, 1.0))
	var f := clampf(z.life[i] / FADE_TIME, 0.0, 1.0)
	return Vector2(g, smoothstep(0.0, 1.0, f))


## Hortum/Tufan: ARKA = taban + arkadaki taşlar + gövde, AKIŞ = maskeli akış, ÖN = öndeki taşlar + şimşek.
func _draw_funnel(ci: CanvasItem, pass_id: int, i: int, t: float, giant: bool, quality: int) -> int:
	var z := _sim.zones
	var r := z.radius[i]
	var p := z.pos[i]
	var gf := _grow_fade(i, t)
	var g := gf.x
	var f := gf.y
	var body_id := ZyfenFx.TUFAN_GOVDE if giant else ZyfenFx.HORTUM_GOVDE
	var body_tex := ZyfenFx.texture(body_id)
	if body_tex == null:
		return 0
	var phase := float(z.gen[i]) * 1.7
	var wb0 := r * (GIANT_BODY if giant else TWISTER_BODY)
	var hb0 := wb0 * float(body_tex.get_height()) / float(body_tex.get_width())
	var cap := _size_cap(hb0)
	var wb := wb0 * cap
	var hb := hb0 * cap
	var dims := Vector2(wb, hb)
	# Doğuşta tabandan büyür (önce yükseklik), sönüşte incelir ve alçalır; yatay nabız dönüyormuş hissi verir.
	var pulse := 1.0 + PULSE_AMOUNT * sin(t * PULSE_SPEED + phase)
	var sx := (0.35 + 0.65 * g) * (0.3 + 0.7 * f) * pulse
	var sy := g * (0.6 + 0.4 * f)
	var sway := SWAY_AMOUNT * sin(t * SWAY_SPEED + phase) * (0.6 if giant else 1.0)
	var body_xf := Transform2D(Vector2(sx, 0.0), Vector2(-sway, sy), p)
	var fade := _fade[i] if i < _fade.size() else 1.0
	var alpha := (ALPHA_GIANT if giant else ALPHA_TWISTER) * f * fade
	var n := 0
	var stones: Array = GIANT_STONES if giant else TWISTER_STONES
	var n_stones := stones.size() if quality == 2 else (stones.size() >> 1 if quality == 1 else 0)
	var rect := Rect2(Vector2(-wb * 0.5, -BODY_FOOT * hb), Vector2(wb, hb))
	match pass_id:
		PASS_BACK:
			n += _draw_base(ci, p, r * cap, t, phase, giant, g, f * fade)
			n += _draw_stones(
				ci,
				p,
				dims,
				stones,
				n_stones,
				Vector2(t, phase),
				gf,
				giant,
				false,
				Vector2(fade, cap)
			)
		PASS_BODY:
			ci.draw_set_transform_matrix(body_xf)
			var gm := ZyfenFx.grade(Color(1, 1, 1, alpha))
			ci.draw_texture_rect(body_tex, rect, false, gm)
			n += 1
		PASS_FLOW:
			if _flow_layer.material != null:
				var tile_n := clampf(wb0 / FLOW_TILE_PX, 0.5, 7.9)
				var rate := (FLOW_SPIN_GIANT if giant else FLOW_SPIN_TWISTER) * tile_n * 3.2
				var sx_ph := fposmod(fposmod(phase * 0.37, 1.0) + t * rate, 1.0)
				var sy_ph := fposmod(t * FLOW_UP, 1.0)
				var fa := (FLOW_ALPHA_GIANT if giant else FLOW_ALPHA_TWISTER) * f * g * fade
				ci.draw_set_transform_matrix(body_xf)
				ci.draw_texture_rect(body_tex, rect, false, Color(sx_ph, tile_n / 8.0, sy_ph, fa))
				n += 1
		PASS_FRONT:
			n += _draw_stones(
				ci,
				p,
				dims,
				stones,
				n_stones,
				Vector2(t, phase),
				gf,
				giant,
				true,
				Vector2(fade, cap)
			)
			if giant and quality == 2:
				n += _draw_bolts(ci, body_xf, wb, hb, t, z.gen[i], f * g * fade)
	return n


## Taban halkası: yassı halka daireye açılıp döndürülür, sonra yeniden yassılaştırılır (perspektif içinde dönme).
func _draw_base(
	ci: CanvasItem, p: Vector2, r: float, t: float, phase: float, giant: bool, g: float, f: float
) -> int:
	var tex := ZyfenFx.texture(ZyfenFx.TUFAN_TABAN if giant else ZyfenFx.HORTUM_TABAN)
	if tex == null:
		return 0
	var w := r * BASE_WIDTH * (0.3 + 0.7 * g) * (0.7 + 0.3 * f)
	var h := w * float(tex.get_height()) / float(tex.get_width())
	var spin := t * (GIANT_SPIN if giant else TWISTER_SPIN) + phase
	var squash := h / w
	var xf := Transform2D(0.0, Vector2(1.0, squash), 0.0, p) * Transform2D(spin, Vector2.ZERO)
	ci.draw_set_transform_matrix(xf)
	var c := ZyfenFx.grade(Color(BASE_TINT.r, BASE_TINT.g, BASE_TINT.b, ALPHA_BASE * f))
	ci.draw_texture_rect(tex, Rect2(Vector2(-w * 0.5, -w * 0.5), Vector2(w, w)), false, c)
	return 1


## Yörüngedeki taşlar: `front` = elipsin ön yarısı (gövdenin önünde), değilse arka yarı (gövdenin arkasında).
func _draw_stones(
	ci: CanvasItem,
	p: Vector2,
	dims: Vector2,
	stones: Array,
	count: int,
	tp: Vector2,
	gf: Vector2,
	giant: bool,
	front: bool,
	fade: Vector2
) -> int:
	var wb := dims.x
	var hb := dims.y
	var t := tp.x
	var phase := tp.y
	var g := gf.x
	var f := gf.y
	var n := 0
	for j in count:
		var s: Vector3 = stones[j]
		var th := t * s.x + phase * 0.9 + float(j) * 2.1
		var sn := sin(th)
		if (sn > 0.0) != front:
			continue
		var tex := ZyfenFx.texture(ZyfenFx.STONES[j % ZyfenFx.STONES.size()])
		if tex == null:
			continue
		var hf := s.y
		var half_w := wb * BODY_HALF * (0.18 + 0.82 * hf)
		var rx := (half_w + wb * ORBIT_GAP) * g
		var up := hf * BODY_SPAN * hb * g
		var pos := p + Vector2(cos(th) * rx, sn * rx * ORBIT_SQUASH - up)
		var size := s.z * STONE_SCALE * (0.55 + 0.45 * hf) * (1.3 if giant else 1.0) * g * fade.y
		var a := f * fade.x * (0.5 + 0.5 * absf(sn) if front else 0.75)
		ci.draw_set_transform(pos, t * (2.5 + float(j)) * signf(s.x), Vector2.ONE)
		ci.draw_texture_rect(
			tex,
			Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size)),
			false,
			ZyfenFx.grade(Color(1, 1, 1, a))
		)
		n += 1
	return n


## Tufan bulut tepesinde rastgele çakan şimşek (sim zamanı ve bölge kimliğinden deterministik).
func _draw_bolts(
	ci: CanvasItem, body_xf: Transform2D, wb: float, hb: float, t: float, gen: int, a: float
) -> int:
	var shifted := t + float(gen) * 0.31
	var slot := int(floor(shifted / BOLT_PERIOD))
	var ph := shifted - float(slot) * BOLT_PERIOD
	if ph >= BOLT_TIME or _hash01(slot * 7 + gen * 13) > BOLT_CHANCE:
		return 0
	var which := ZyfenFx.SIMSEK_1 if _hash01(slot * 11 + gen * 5 + 1) < 0.5 else ZyfenFx.SIMSEK_2
	var tex := ZyfenFx.texture(which)
	if tex == null:
		return 0
	var flicker := 1.0 - ph / BOLT_TIME
	flicker *= 0.55 + 0.45 * absf(sin(ph * 90.0))
	var w := wb * 0.34
	var h := w * float(tex.get_height()) / float(tex.get_width())
	var dx := (_hash01(slot * 3 + gen * 17 + 2) - 0.5) * wb * 0.45
	var mirror := -1.0 if _hash01(slot * 5 + gen + 3) < 0.5 else 1.0
	# Bulut gövdenin üst üçte birinde: gövde yerelinde (dx, tepe + 0.3 hb) civarı.
	var cy := (0.34 - BODY_FOOT) * hb
	ci.draw_set_transform_matrix(
		body_xf * Transform2D(0.0, Vector2(mirror, 1.0), 0.0, Vector2(dx, cy))
	)
	ci.draw_texture_rect(
		tex,
		Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)),
		false,
		ZyfenFx.grade(Color(1, 1, 1, a * flicker))
	)
	return 1


## Hava Cebi: küre (şişip söner) + içinde ters dönen iç girdap; bitişte patlama.
func _draw_pocket(ci: CanvasItem, i: int, t: float) -> int:
	var z := _sim.zones
	var r := z.radius[i]
	var p := z.pos[i]
	var phase := float(z.gen[i]) * 1.7
	var gf := _grow_fade(i, t)
	var life := z.life[i]
	var n := 0
	if life > BURST_TIME:
		var pulse := 1.0 + 0.05 * sin(t * 2.6 + phase)
		var a := ALPHA_POCKET * smoothstep(0.0, 1.0, gf.x)
		n += _tex_at(
			ci,
			ZyfenFx.HAVA_CEBI,
			p,
			r * 2.0 / ZyfenFx.TEX_FILL * pulse,
			t * POCKET_SPIN * 0.3 + phase,
			a,
			POCKET_TINT
		)
		n += _tex_at(
			ci,
			ZyfenFx.GIRDAP_IC,
			p,
			r * 1.5 * pulse,
			-t * POCKET_SPIN * 1.4 + phase,
			0.7 * POCKET_INNER * a,
			POCKET_TINT
		)
	else:
		var k := 1.0 - life / BURST_TIME
		var a2 := ALPHA_POCKET * (1.0 - k)
		n += _tex_at(
			ci,
			ZyfenFx.HAVA_CEBI_PATLAMA,
			p,
			r * 2.0 / ZyfenFx.TEX_FILL * (0.85 + 0.6 * k),
			phase + k,
			a2,
			POCKET_TINT
		)
		n += _tex_at(
			ci,
			ZyfenFx.HAVA_CEBI,
			p,
			r * 2.0 / ZyfenFx.TEX_FILL * (1.0 + 0.1 * k),
			phase,
			a2 * 0.5 * (1.0 - k),
			POCKET_TINT
		)
	return n


## Girdap: dış kanatlı halka bir yöne, iç spiral ters yöne döner; halka hafifçe nabız atar.
func _draw_girdap(ci: CanvasItem, gr: float, t: float) -> int:
	var pulse := 1.0 + 0.05 * sin(t * 3.2)
	var a := ALPHA_GIRDAP * (0.9 + 0.1 * sin(t * 3.2))
	var p := _sim.player_pos
	var n := _tex_at(
		ci, ZyfenFx.GIRDAP, p, gr * 2.0 / ZyfenFx.TEX_FILL * pulse, t * GIRDAP_SPIN, a, GIRDAP_TINT
	)
	n += _tex_at(
		ci,
		ZyfenFx.GIRDAP_IC,
		p,
		gr * 1.55 * pulse,
		-t * GIRDAP_SPIN * 1.3,
		a * GIRDAP_INNER,
		GIRDAP_TINT
	)
	return n


## Merkez `p`, tuval genişliği `w` (yükseklik doku oranından), `rot` rad, `alpha`.
func _tex_at(
	ci: CanvasItem,
	id: StringName,
	p: Vector2,
	w: float,
	rot: float,
	alpha: float,
	tint: Color = Color.WHITE
) -> int:
	var tex := ZyfenFx.texture(id)
	if tex == null:
		return 0
	var h := w * float(tex.get_height()) / float(tex.get_width())
	ci.draw_set_transform(p, rot, Vector2.ONE)
	ci.draw_texture_rect(
		tex,
		Rect2(Vector2(-w, -h) * 0.5, Vector2(w, h)),
		false,
		ZyfenFx.grade(Color(tint.r, tint.g, tint.b, alpha))
	)
	return 1


## Tamsayıdan 0..1 sahte rastgele (görünüm; sim RNG'sine dokunmaz).
static func _hash01(n: int) -> float:
	var x := (n * 73856093) ^ 19349663
	x = ((x >> 13) ^ x) & 0x7fffffff
	x = (x * 1103515245 + 12345) & 0x7fffffff
	return float(x) / 2147483647.0
