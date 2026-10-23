class_name PlayerView
extends Node2D
## Parçalı geçici şekil rig (plan A1):
## Player (bu düğüm, y_sort) → Glow, Shadow, Aura, Rig (ayak pivotu: FarArm z −1 / Body z 0 / NearArm z +1),
## ReloadRing, MuzzleFlash. Eğim, squash, itme ve devrilme Rig düğümünden yapılır; zemin gölgesi ve ışıması ayağa sabittir.
## Kol hedefe döner (`sim.gun_aim[gun]`, dünya açısı Rig dönüşünden bağımsız korunur); cos(rotation) < 0 ise scale.y = −1.
## Düğüm konumu = sim.player_pos (gövde merkezi, PlayerRig ile aynı). Kollar GÖRÜNÜM omzuna (Rig dönüşümlü), namlu alevi
## GÖRÜNÜM namlusuna (`muzzle_view`) oturur; mermi çıkışı sim'deki `PlayerRig.muzzle_world` olarak kalır (sim sözleşmesi).
## Animasyon durumu PlayerAnim'dedir (saf); bu sınıf yalnız uygular. dt = görünüm süresi (duraklatmada 0).
## Pivot/omuz/namlu headless'ta görsel doğrulanamaz; kullanıcıda ekran görüntüsüyle doğrulanır.

const SWAY_SHADER := "res://assets/shaders/player_sway.gdshader"
const RIM_SHADER := "res://assets/shaders/rim_sprite.gdshader"
const DEFAULT_HEIGHT := 112.0
const FAR_ARM_TINT := Color(0.8, 0.8, 0.8, 1.0)
const RING_RADIUS := 26.0
const PAD := 12  # rim için doku etrafı saydam dolgu (doku pikseli)
const RIM_COLOR := Color(0.80, 0.72, 0.56)
const RIM_SCREEN_PX := 2.1
const RING_PULSE := 0.15  # doldurma bitişinde halka 1→1,5 + solma
const AURA_SIZE := Vector2(80.0, 28.0)
const FLASH_STEP := 1.0 / 30.0  # 3 karelik titreşim
## Kare modunda görünüm omzu sim omzundan en çok bu kadar (px) uzaklaşır (eğim omzu ayaktan ~0,8H yukarıda kaydırır);
## kalan sapma gövde dikişinde kalır. Plan D4-2: omuz uyumu ≤5 px.
const SHOULDER_TOL := 4.5

var far_arm: Sprite2D
var body: MeshInstance2D
var near_arm: Sprite2D
var rig_node: Node2D
var reload_ring: ReloadRing
var shadow: Shadow
var muzzle_flash: MuzzleFlash
var glow: Glow
var aura: Aura
var anim: PlayerAnim = PlayerAnim.new()

var _sim: GameSim = null
var _rig: Dictionary = {}
var _height: float = DEFAULT_HEIGHT
var _arm_len: float = 70.0
var _facing_left: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _last_steps: int = 0
var _vel: Vector2 = Vector2.ZERO
var _sway: float = 0.0
var _pad_world: Vector2 = Vector2.ZERO
var _arm_orig: Vector2 = Vector2(120, 48)
var _real: bool = false
var _hit_dir: Vector2 = Vector2.ZERO
var _ring_pulse: float = 0.0
var _flicker: float = 0.0
## Kare şeridi yüklendi ve geçerli (rig.walk.frames > 0 + şerit hücre düzeni uyumlu): kare modu. Aksi halde, frames > 0
## olsa bile prosedürel yedek çalışır (A24).
var _strip_ready: bool = false
## Kare modunda gövde kutusu = tek hücre (dünya px, dolgu hariç); duruş görseliyle aynı ölçek, ayak = alt kenar.
var _cell_world: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()


## Dünya-uzayı doldurma halkası (amber, oyuncunun başı üstünde).
class ReloadRing:
	extends Node2D
	var progress: float = 0.0
	var radius: float = 26.0
	var pulse: float = 0.0  # 0..1: tamamlanma nabzı (1 = yeni bitti)

	func _draw() -> void:
		var k := 1.0 + 0.5 * (1.0 - pulse) if pulse > 0.0 else 1.0
		var fade := pulse if pulse > 0.0 else 1.0
		draw_arc(
			Vector2.ZERO, radius * k, 0.0, TAU, 40, Color(0.05, 0.035, 0.06, 0.7 * fade), 8.0, true
		)
		if progress > 0.0:
			var a0 := -PI * 0.5
			var col := Color("#e8a24a")
			col.a = fade
			draw_arc(Vector2.ZERO, radius * k, a0, a0 + TAU * progress, 40, col, 6.0, true)


## Oyuncunun altında sıcak amber ışık havuzu (zeminden ayrışma + atmosfer).
class Glow:
	extends Node2D
	var radius: float = 150.0

	func _draw() -> void:
		var tex := PlaceholderArt.soft_circle(128)
		draw_texture_rect(
			tex,
			Rect2(Vector2(-radius, -radius * 0.55), Vector2(radius * 2.0, radius * 1.1)),
			false,
			Color(1.0, 0.62, 0.28, 0.34)
		)


## Ayak altı gölge elipsi.
class Shadow:
	extends Node2D
	var size: Vector2 = Vector2(60, 18)

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, size.y / size.x))
		draw_circle(Vector2.ZERO, size.x * 0.5, Color(0, 0, 0, 0.38))


## Ayak çizgisinde yer halkaları: süreli etki aurası (P13) ve seviye halkası (P11). Merkez = ayak.
class Aura:
	extends Node2D
	var mask: int = 0
	var level_ring: float = -1.0
	var time: float = 0.0

	func _draw() -> void:
		draw_set_transform(
			Vector2.ZERO, 0.0, Vector2(1.0, PlayerView.AURA_SIZE.y / PlayerView.AURA_SIZE.x)
		)
		var rx := PlayerView.AURA_SIZE.x * 0.5
		if mask & 1:  # hasar: bordo halka + 0,8 Hz nabız
			var pulse := 0.5 + 0.5 * sin(time * TAU * 0.8)
			draw_arc(
				Vector2.ZERO,
				rx,
				0.0,
				TAU,
				40,
				Color(0.878, 0.345, 0.31, 0.55 + 0.35 * pulse),
				4.0,
				true
			)
			draw_arc(
				Vector2.ZERO,
				rx + 6.0 * pulse,
				0.0,
				TAU,
				40,
				Color(0.878, 0.345, 0.31, 0.25 * pulse),
				3.0,
				true
			)
		if mask & 2:  # atış hızı: bronz dönen yaylar
			for k in 3:
				var a0 := time * 3.0 + k * TAU / 3.0
				draw_arc(
					Vector2.ZERO,
					rx + 4.0,
					a0,
					a0 + 0.9,
					10,
					Color(0.824, 0.706, 0.494, 0.9),
					4.0,
					true
				)
		if mask & 4:  # sınırsız: amber çift halka
			draw_arc(Vector2.ZERO, rx, 0.0, TAU, 40, Color(0.91, 0.635, 0.29, 0.85), 3.0, true)
			draw_arc(
				Vector2.ZERO, rx + 9.0, 0.0, TAU, 40, Color(0.91, 0.635, 0.29, 0.45), 2.0, true
			)
		if level_ring >= 0.0:
			var u := clampf(level_ring / 180.0, 0.0, 1.0)
			var col := Color("#A98BEF")
			col.a = 1.0 - u * u
			draw_arc(Vector2.ZERO, maxf(level_ring, 1.0), 0.0, TAU, 56, col, 3.0, true)


## Namlu parlaması: yerel noktalar, kalan süreler ve 3 karelik titreşim (dönme ±8°, ölçek 0,8–1,2).
class MuzzleFlash:
	extends Node2D
	var points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	var left := PackedFloat32Array([0.0, 0.0])
	var rot := PackedFloat32Array([0.0, 0.0])
	var scl := PackedFloat32Array([1.0, 1.0])

	func _draw() -> void:
		for g in 2:
			if left[g] <= 0.0:
				continue
			var k := left[g] / Motion.sec(Motion.MUZZLE_FLASH)
			var s := scl[g]
			draw_circle(points[g], (14.0 * k + 4.0) * s, Color(1.0, 0.75, 0.35, 0.55 * k))
			draw_circle(points[g], (7.0 * k + 2.0) * s, Color(1.0, 0.95, 0.8, 0.95 * k))
			var spike := Vector2.from_angle(rot[g]) * (16.0 * k + 6.0) * s
			draw_line(
				points[g] - spike * 0.4, points[g] + spike, Color(1.0, 0.9, 0.6, 0.8 * k), 3.0, true
			)


func _init() -> void:
	y_sort_enabled = true
	_rng.seed = 7
	shadow = Shadow.new()
	shadow.name = "Shadow"
	shadow.z_index = -2
	glow = Glow.new()
	glow.name = "Glow"
	glow.z_index = -3
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	aura = Aura.new()
	aura.name = "Aura"
	aura.z_index = -1
	rig_node = Node2D.new()
	rig_node.name = "Rig"
	far_arm = _make_arm("FarArm", -1)
	far_arm.modulate = FAR_ARM_TINT
	body = MeshInstance2D.new()
	body.name = "Body"
	body.texture = PlaceholderArt.body_texture()
	near_arm = _make_arm("NearArm", 1)
	reload_ring = ReloadRing.new()
	reload_ring.name = "ReloadRing"
	reload_ring.z_index = 3
	reload_ring.visible = false
	muzzle_flash = MuzzleFlash.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.z_index = 2
	add_child(glow)
	add_child(shadow)
	add_child(aura)
	add_child(rig_node)
	rig_node.add_child(far_arm)
	rig_node.add_child(body)
	rig_node.add_child(near_arm)
	add_child(reload_ring)
	add_child(muzzle_flash)
	_apply_rig({})


func bind(sim: GameSim) -> void:
	_disconnect_bus()
	_sim = sim
	var rig: Dictionary = {}
	if sim != null and sim.character != null:
		rig = sim.character.rig
	_apply_rig(rig)
	anim.configure(_anim_rig(rig))
	_hit_dir = Vector2.ZERO
	_ring_pulse = 0.0
	muzzle_flash.left.fill(0.0)
	if sim != null:
		var bus := sim.bus
		bus.shot_fired.connect(_on_shot_fired)
		bus.player_damaged.connect(_on_player_damaged)
		bus.level_up.connect(_on_level_up)
		bus.reload_finished.connect(_on_reload_finished)
		bus.run_ended.connect(_on_run_ended)
		position = sim.player_pos
		_last_pos = sim.player_pos
		_last_steps = sim.step_count
	_vel = Vector2.ZERO
	update_view(0.0)


func _disconnect_bus() -> void:
	if _sim == null:
		return
	var bus := _sim.bus
	if bus.shot_fired.is_connected(_on_shot_fired):
		bus.shot_fired.disconnect(_on_shot_fired)
		bus.player_damaged.disconnect(_on_player_damaged)
		bus.level_up.disconnect(_on_level_up)
		bus.reload_finished.disconnect(_on_reload_finished)
		bus.run_ended.disconnect(_on_run_ended)


## Gövde boyutu (en × boy) karakter verisinden.
static func body_size(rig: Dictionary) -> Vector2:
	var h := float(rig.get("display_height", DEFAULT_HEIGHT))
	return Vector2(h * PlayerRig.BODY_ASPECT, h)


## Omuz noktası (Player yerel; gövde merkezi orijinde) — PlayerRig ile aynı geometri (tek kaynak).
## `frame` verilirse (kare modu) o karenin omuz sapması eklenir; -2 = duruş geometrisi.
static func shoulder_local(
	rig: Dictionary, gun: int, facing_left: bool, frame: int = -2
) -> Vector2:
	if frame == -2:
		return PlayerRig.shoulder_world(gun, Vector2.ZERO, facing_left, rig)
	return PlayerRig.shoulder_world_f(gun, Vector2.ZERO, facing_left, rig, frame)


## Kol dönüşü için dikey ayna: cos(rotation) < 0 ise -1 (kol görseli sağa bakar).
static func arm_flip(rotation_rad: float) -> float:
	return -1.0 if cos(rotation_rad) < 0.0 else 1.0


## Görünüm omzu (dünya): kolun dönüş merkezi, Rig dönüşümü dahil. Eğimle sim omzundan birkaç px ayrışır.
func shoulder_view(gun: int) -> Vector2:
	return position + rig_node.transform * _arm_of(gun).position


## Görünüm namlusu (dünya): kol dönüşü/ölçeği/ayna dahil; PlayerRig.muzzle_world ile aynı kol geometrisi.
func muzzle_view(gun: int) -> Vector2:
	var m: Array = _rig.get("muzzle", [0.98, 0.37])
	var pv: Array = _rig.get("arm_pivot", [0.11, 0.47])
	var local := Vector2(
		(float(m[0]) - float(pv[0])) * _arm_orig.x, (float(m[1]) - float(pv[1])) * _arm_orig.y
	)
	return position + rig_node.transform * (_arm_of(gun).transform * local)


func _arm_of(gun: int) -> Sprite2D:
	return near_arm if gun == 0 else far_arm


## Her kare: sim'i oku, animasyonu ilerlet, rig'i yerleştir. dt <= 0 (duraklatma) animasyonu ilerletmez.
func update_view(dt: float) -> void:
	if _sim == null:
		return
	var pos := _sim.player_pos
	var moved := pos - _last_pos
	_last_pos = pos
	position = pos
	_facing_left = _sim.player_facing_left
	if _sim.state == GameSim.State.LOST and anim.mode != PlayerAnim.Mode.DEAD:
		anim.on_died(_hit_dir)
	var mag := _sim.magazine
	var rp := -1.0
	if mag.reloading:
		rp = clampf(1.0 - mag.reload_left / maxf(mag.reload_total, 0.0001), 0.0, 1.0)
	anim.on_buffs(_aura_mask())
	# Hız sim adımından türetilir (render karesinden değil): sim adımlamayan karede (120 Hz ekran, vuruş donması) son hız korunur.
	var steps := _sim.step_count - _last_steps
	_last_steps = _sim.step_count
	if steps > 0:
		_vel = moved / (float(steps) * GameSim.STEP)
	elif moved != Vector2.ZERO and dt > 0.0:
		_vel = moved / dt  # sim dışı konum değişimi (ışınlanma/test): doğrudan
	anim.update(dt, _vel, _facing_left, rp)
	_apply_pose(dt, moved)
	_update_ring(dt, mag, rp)
	_update_flash(dt)
	aura.mask = anim.aura_mask
	aura.level_ring = anim.level_ring
	aura.time += dt
	if aura.mask != 0 or aura.level_ring >= 0.0 or dt > 0.0:
		aura.queue_redraw()


## Etki aurası maskesi: süre sayaçları doğrudan okunur (BuffManager.active D2 gövdesidir).
func _aura_mask() -> int:
	var m := 0
	var left := _sim.buffs.left_steps
	for k in BuffManager.COUNT:
		if left[k] > 0:
			m |= 1 << k
	return m


## Gövde kutusu: kare modunda hücre, aksi halde duruş kutusu.
func _body_box() -> Vector2:
	return _cell_world if _strip_ready else body_size(_rig)


func _apply_pose(dt: float, moved: Vector2) -> void:
	var size := _body_box()
	var half_h := body_size(_rig).y * 0.5  # Rig pivotu (ayak) duruş kutusundan; kutu yüksekliği değişse de ayak sabit
	var sgn := signf(anim.turn_x)
	# Rig: ayak pivotu; bob/itme/gömülme dönüşümde, dönüş ve solma burada
	var rp := Vector2(0.0, half_h - anim.bob_px + anim.sink_px)
	rp += anim.knock_dir * anim.knock_px + Vector2(-sgn * anim.body_back_px, 0.0)
	rig_node.position = rp
	rig_node.rotation = anim.body_rot
	rig_node.modulate.a = anim.fade
	shadow.modulate.a = anim.fade
	# gövde: ayak sabit, squash/ayna ayak çizgisinden
	body.scale = Vector2(anim.turn_x * anim.sx, anim.sy)
	body.position = Vector2(-size.x * 0.5 * body.scale.x, -size.y * anim.sy)
	var glow_k := maxf(1.0 + anim.halo, 0.0)
	glow.scale = Vector2.ONE * (1.0 + maxf(anim.halo, 0.0))
	glow.modulate.a = clampf(glow_k, 0.0, 1.0)
	# etek salınımı: hareketin tersine, gecikmeli
	var lag := 0.12
	var sway_cfg: Variant = _rig.get("sway", {})
	if sway_cfg is Dictionary:
		lag = float(sway_cfg.get("lag", 0.12))
	var target := 0.0
	if dt > 0.0:
		target = clampf(-moved.x / dt / 300.0, -1.0, 1.0)
		_sway = lerpf(_sway, target, clampf(dt / maxf(lag, 0.001), 0.0, 1.0))
	if body.material is ShaderMaterial:
		var mat := body.material as ShaderMaterial
		mat.set_shader_parameter("sway", _sway * (-1.0 if _facing_left else 1.0))
		mat.set_shader_parameter("hit", anim.hit)
		mat.set_shader_parameter("tint_amt", anim.tint_amt)
		mat.set_shader_parameter("tint", Vector3(anim.tint.r, anim.tint.g, anim.tint.b))
		mat.set_shader_parameter("desat", anim.desat)
		mat.set_shader_parameter("walk_phase", anim.walk_phase)
		mat.set_shader_parameter("scarf_amp", anim.scarf_amp)
		mat.set_shader_parameter("frame_a", float(anim.frame_a))
		mat.set_shader_parameter("frame_b", float(anim.frame_b))
		mat.set_shader_parameter("frame_mix", anim.frame_mix)
	# kollar
	var aims := _aims()
	_place_arm(near_arm, 0, aims[0])
	_place_arm(far_arm, 1, aims[1])


func _update_ring(dt: float, mag: Magazine, rp: float) -> void:
	_ring_pulse = maxf(0.0, _ring_pulse - dt)
	var size := body_size(_rig)
	reload_ring.position = Vector2(0, -size.y * 0.5 - RING_RADIUS - 14.0)
	if mag.reloading:
		reload_ring.visible = true
		reload_ring.progress = rp
		reload_ring.pulse = 0.0
		reload_ring.queue_redraw()
	elif _ring_pulse > 0.0:
		reload_ring.visible = true
		reload_ring.progress = 1.0
		reload_ring.pulse = _ring_pulse / RING_PULSE
		reload_ring.queue_redraw()
	else:
		reload_ring.visible = false


func _update_flash(dt: float) -> void:
	var any := false
	for g in 2:
		if muzzle_flash.left[g] > 0.0:
			muzzle_flash.left[g] = maxf(0.0, muzzle_flash.left[g] - dt)
			any = true
	if any:
		_flicker += dt
		if _flicker >= FLASH_STEP:
			_flicker = 0.0
			for g in 2:
				muzzle_flash.rot[g] = deg_to_rad(_rng.randf_range(-8.0, 8.0))
				muzzle_flash.scl[g] = _rng.randf_range(0.8, 1.2)
		muzzle_flash.queue_redraw()


func _aims() -> PackedFloat32Array:
	var base := PI if _facing_left else 0.0
	var out := PackedFloat32Array([base, base])
	var v := _sim.gun_aim
	if v.size() >= 2:
		out[0] = v[0]
		out[1] = v[1]
	return out


## Kol Rig'in çocuğudur: dünya açısını korumak için dönüşü Rig dönüşünden çıkarır; omuz Rig yerelinde görünüm omzudur.
## Kare modunda omuz = duruş omzu + gösterilen karenin sapması (çapraz solmada iki kare harmanlanır) ve görünüm omzu sim
## omzundan SHOULDER_TOL'den fazla uzaklaşmaz (eğimin omuz kaydırması gövde dikişine bırakılır).
func _place_arm(arm: Sprite2D, gun: int, aim: float) -> void:
	var flip := arm_flip(aim)
	var kx := _arm_len / maxf(_arm_orig.x, 1.0)
	var ky := _arm_len * PlayerRig.ARM_ASPECT / maxf(_arm_orig.y, 1.0)
	var local_aim := aim - rig_node.rotation
	arm.rotation = local_aim - anim.arm_rot[gun] * flip
	arm.scale = Vector2(kx * anim.arm_len[gun], ky * flip)
	var sh := _shoulder_now(gun)
	var half_h := body_size(_rig).y * 0.5
	var in_rig := Vector2(sh.x, (sh.y - half_h) * anim.sy)
	if _strip_ready:
		in_rig = _clamp_shoulder(gun, in_rig)  # kenet omuz tabanına; geri tepme (arm_back) sonradan tam uygulanır
	arm.position = in_rig - Vector2.from_angle(local_aim) * anim.arm_back[gun]


## Gösterilen karenin omzu (Player yerel). Kare modu dışında duruş omzu.
func _shoulder_now(gun: int) -> Vector2:
	if not _strip_ready:
		return shoulder_local(_rig, gun, _facing_left)
	var a := shoulder_local(_rig, gun, _facing_left, anim.frame_a)
	if anim.frame_mix <= 0.0 or anim.frame_b == anim.frame_a:
		return a
	return a.lerp(shoulder_local(_rig, gun, _facing_left, anim.frame_b), anim.frame_mix)


## Görünüm omzunu (Rig dönüşümü sonrası dünya) sim omzuna en çok SHOULDER_TOL kadar yaklaştırır.
func _clamp_shoulder(gun: int, pos_in_rig: Vector2) -> Vector2:
	var view_local := rig_node.transform * pos_in_rig
	var sim_local := shoulder_local(_rig, gun, _facing_left)
	var off := view_local - sim_local
	var d := off.length()
	if d <= SHOULDER_TOL:
		return pos_in_rig
	var target := sim_local + off * (SHOULDER_TOL / d)
	return rig_node.transform.affine_inverse() * target


func _anim_rig(rig: Dictionary) -> Dictionary:
	var w: Variant = rig.get("walk", null)
	if _strip_ready or not (w is Dictionary) or int(w.get("frames", 0)) <= 0:
		return rig
	var out := rig.duplicate(true)
	out["walk"]["frames"] = 0  # şerit yok/geçersiz → prosedürel yedek (A24)
	return out


## rig.walk geçerliyse hücre hücre dolgulu şerit dokusu; değilse null (prosedürel yedek). Geçerlilik: frames 2..12, şerit
## dosyası var, genişlik (frames+1) hücreye ve `cell` boyutuna tam uyuyor.
func _load_strip(rig: Dictionary) -> Texture2D:
	var w: Variant = rig.get("walk", null)
	if not (w is Dictionary):
		return null
	var n := int(w.get("frames", 0))
	var cell: Variant = w.get("cell", null)
	if n < 2 or n > DataV11.WALK_MAX_FRAMES or not (cell is Array) or cell.size() < 2:
		return null
	var tex := ArtLoader.padded_cells(str(w.get("strip", "")), n + 1, PAD)
	if tex == null:
		return null
	var want := Vector2((n + 1) * (int(cell[0]) + 2 * PAD), int(cell[1]) + 2 * PAD)
	if tex.get_size() != want or int(cell[0]) < 1 or int(cell[1]) < 1:
		push_warning("PlayerView: yürüme şeridi 'cell' ile uyuşmuyor: %s" % w.get("strip", ""))
		return null
	return tex


func _apply_rig(rig: Dictionary) -> void:
	_rig = rig
	_height = float(rig.get("display_height", DEFAULT_HEIGHT))
	_arm_len = float(rig.get("arm_scale", 0.62)) * _height
	var stand := body_size(rig)
	var size := stand
	# Görseller: gerçek dosya varsa dolgulu (rim için) doku, yoksa geçici şekil.
	var body_tex := ArtLoader.padded(str(rig.get("body", "")), PAD)
	var arm_tex := ArtLoader.padded(str(rig.get("arm", "")), PAD)
	_real = body_tex != null and arm_tex != null
	var strip_tex: Texture2D = _load_strip(rig) if _real else null
	_strip_ready = strip_tex != null
	_cell_world = Vector2.ZERO
	var cells := 1
	var pad_frac := Vector2.ZERO
	_pad_world = Vector2.ZERO
	if _strip_ready:
		var w: Dictionary = rig["walk"]
		cells = int(w["frames"]) + 1
		var cell_px := Vector2(float(w["cell"][0]), float(w["cell"][1]))
		var stand_px := body_tex.get_size() - Vector2(PAD, PAD) * 2.0  # duruş görseli: dünya ölçeği
		var k := size.y / maxf(stand_px.y, 1.0)
		_cell_world = cell_px * k
		_pad_world = Vector2(PAD, PAD) * k
		body.texture = strip_tex
		pad_frac = Vector2(PAD, PAD) / (cell_px + Vector2(PAD, PAD) * 2.0)
		size = _cell_world
		_arm_orig = arm_tex.get_size() - Vector2(PAD, PAD) * 2.0
		for arm in [near_arm, far_arm]:
			arm.texture = arm_tex
	elif _real:
		body.texture = body_tex
		var ts := body_tex.get_size()
		pad_frac = Vector2(PAD, PAD) / ts
		_pad_world = Vector2(PAD, PAD) / (ts - Vector2(PAD, PAD) * 2.0) * size
		for arm in [near_arm, far_arm]:
			arm.texture = arm_tex
		_arm_orig = arm_tex.get_size() - Vector2(PAD, PAD) * 2.0
	else:
		body.texture = PlaceholderArt.body_texture()
		for arm in [near_arm, far_arm]:
			arm.texture = PlaceholderArt.arm_texture()
		_arm_orig = PlaceholderArt.arm_texture().get_size()
	body.mesh = PlaceholderArt.grid_mesh(size + _pad_world * 2.0, 16, 24, -_pad_world)
	if ResourceLoader.exists(SWAY_SHADER):
		var mat := ShaderMaterial.new()
		mat.shader = load(SWAY_SHADER)
		var sway: Variant = rig.get("sway", {})
		if sway is Dictionary:
			mat.set_shader_parameter("amp", float(sway.get("amp", 6.0)))
			mat.set_shader_parameter("hem_from_y", float(sway.get("hem_from_y", 0.6)))
			var sr: Variant = sway.get("scarf_rect", [])
			if sr is Array and sr.size() >= 4:
				mat.set_shader_parameter(
					"scarf_rect", Vector4(float(sr[0]), float(sr[1]), float(sr[2]), float(sr[3]))
				)
		mat.set_shader_parameter("body_tex", body.texture)
		mat.set_shader_parameter("pad_frac", pad_frac)
		mat.set_shader_parameter("cells", float(cells))
		var texel_world := (
			size.y / maxf(body.texture.get_size().y - 2.0 * (PAD if _real else 0), 1.0)
		)
		mat.set_shader_parameter("rim_px", clampf(RIM_SCREEN_PX / texel_world, 1.0, 12.0))
		mat.set_shader_parameter("rim_color", Vector3(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b))
		body.material = mat
	var pivot := Vector2(0.11, 0.47)
	var pv: Variant = rig.get("arm_pivot", [])
	if pv is Array and pv.size() >= 2:
		pivot = Vector2(float(pv[0]), float(pv[1]))
	var pad_px := Vector2(PAD, PAD) if _real else Vector2.ZERO
	for arm in [near_arm, far_arm]:
		arm.offset = -(pad_px + pivot * _arm_orig)
		if _real and ResourceLoader.exists(RIM_SHADER):
			var am := ShaderMaterial.new()
			am.shader = load(RIM_SHADER)
			am.set_shader_parameter("sprite_tex", arm_tex)
			var kx := _arm_len / maxf(_arm_orig.x, 1.0)
			am.set_shader_parameter("rim_px", clampf(RIM_SCREEN_PX / kx, 1.0, 12.0))
			am.set_shader_parameter("rim_color", Vector3(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b))
			var tint := FAR_ARM_TINT if arm == far_arm else Color.WHITE
			am.set_shader_parameter("tint", Vector4(tint.r, tint.g, tint.b, 1.0))
			arm.material = am
			arm.modulate = Color.WHITE
		elif arm == far_arm:
			arm.modulate = FAR_ARM_TINT
	shadow.size = Vector2(stand.x * 0.9, stand.x * 0.28)
	shadow.position = Vector2(0, stand.y * 0.5)
	aura.position = Vector2(0, stand.y * 0.5)
	glow.position = Vector2(0, stand.y * 0.42)
	glow.radius = stand.y * 0.8
	glow.queue_redraw()
	reload_ring.radius = RING_RADIUS


func _make_arm(node_name: String, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = PlaceholderArt.arm_texture()
	s.centered = false
	s.z_index = z
	return s


# --- sim olayları -----------------------------------------------------------------------------


func _on_shot_fired(gun: int, _origin: Vector2, _dir: Vector2) -> void:
	if gun < 0 or gun > 1 or _sim == null:
		return
	anim.on_shot(gun)
	muzzle_flash.points[gun] = muzzle_view(gun) - position
	muzzle_flash.left[gun] = Motion.sec(Motion.MUZZLE_FLASH)
	muzzle_flash.rot[gun] = deg_to_rad(_rng.randf_range(-8.0, 8.0))
	muzzle_flash.scl[gun] = _rng.randf_range(0.8, 1.2)
	muzzle_flash.queue_redraw()


func _on_player_damaged(amount: float, _hp: float) -> void:
	if _sim == null:
		return
	_hit_dir = _nearest_enemy_dir()
	anim.on_damaged(amount, _hit_dir)


func _on_level_up(_level: int) -> void:
	anim.on_level_up()


func _on_reload_finished() -> void:
	_ring_pulse = RING_PULSE


func _on_run_ended(won: bool, _stats: Dictionary) -> void:
	if won:
		anim.on_won()
	else:
		anim.on_died(_hit_dir)


## Oyuncuya en yakın canlı düşmanın birim yönü (havuz salt okunur, tek tarama); yoksa ZERO.
func _nearest_enemy_dir() -> Vector2:
	var pool := _sim.enemies
	var best := INF
	var dir := Vector2.ZERO
	var p := _sim.player_pos
	for i in EnemyPool.CAP:
		if pool.alive[i] != 1:
			continue
		var d := pool.pos[i] - p
		var l2 := d.length_squared()
		if l2 < best:
			best = l2
			dir = d
	return dir.normalized() if best < INF else Vector2.ZERO
