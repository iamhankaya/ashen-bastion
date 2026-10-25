class_name WindRenderer
extends Node2D
## Rüzgar bölgeleri ve Girdap halkası (yalnız görsel; sim'i okur, hiçbir sim durumunu değiştirmez). FxRenderer'ın çocuğudur
## ve harmanlama malzemesini ondan alır (ZyfenFx dokuları: fx_hortum/fx_tufan/fx_hava_cebi, Girdap için fx_girdap; bölge
## başına tek çizim, döndürme/soldurma kodla). Ekran içi çizim sayısı MAX_DRAWN ile sınırlıdır (300 düşman + 3 hortum perf bütçesi).

const MAX_DRAWN := 24
## Dönüş hızları (rad/sn); bölge dokuları yavaş döner.
const TWISTER_SPIN := 1.6
const GIANT_SPIN := 1.1
const POCKET_SPIN := -0.8
const GIRDAP_SPIN := 1.3
const FADE_TIME := 0.4

var _sim: GameSim = null
var _camera: CameraRig = null
## Son çizimde çizilen bölge sayısı (testler ve perf ölçümü için).
var drawn_count: int = 0


func _init() -> void:
	use_parent_material = ZyfenFx.ZONES_ADDITIVE


func bind(sim: GameSim, camera: CameraRig = null) -> void:
	_sim = sim
	_camera = camera
	drawn_count = 0
	queue_redraw()


## Her kare (FxRenderer.update_fx çağırır): bölge ya da Girdap varsa yeniden çiz, yoksa bir kez temizle.
func refresh() -> void:
	if _sim == null:
		if drawn_count > 0:
			drawn_count = 0
			queue_redraw()
		return
	if _sim.zones.count > 0 or _girdap_radius() > 0.0 or drawn_count > 0:
		queue_redraw()


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


func _draw() -> void:
	drawn_count = 0
	if _sim == null:
		return
	var view := _view_rect()
	var z := _sim.zones
	var t := _sim.time
	for i in z.count:
		if drawn_count >= MAX_DRAWN:
			break
		var r := z.radius[i]
		if not view.grow(r).has_point(z.pos[i]):
			continue
		drawn_count += 1
		var fade := clampf(z.life[i] / FADE_TIME, 0.0, 1.0)
		match z.kind[i]:
			ZonePool.KIND_POCKET:
				_draw_tex(ZyfenFx.HAVA_CEBI, z.pos[i], r, _spin(t, i, POCKET_SPIN), 0.7 * fade)
			ZonePool.KIND_GIANT:
				_draw_tex(ZyfenFx.TUFAN, z.pos[i], r, _spin(t, i, GIANT_SPIN), 0.6 * fade)
			_:
				_draw_tex(ZyfenFx.HORTUM, z.pos[i], r, _spin(t, i, TWISTER_SPIN), 0.7 * fade)
	var gr := _girdap_radius()
	if gr > 0.0:
		_draw_tex(ZyfenFx.GIRDAP, _sim.player_pos, gr, _spin(t, 0, GIRDAP_SPIN), 0.55)


## Bölge dokusu yavaş döner; başlangıç açısı bölge dizinine göre kayar (aynı anda birden çok bölge aynı fazda olmasın).
static func _spin(t: float, idx: int, speed: float) -> float:
	return t * speed + float(idx) * 1.7


## Merkez `p`, görünür yarıçap `r` (doku içeriği TEX_FILL kadarını kaplar), `rot` rad, `alpha` saydamlık.
func _draw_tex(id: StringName, p: Vector2, r: float, rot: float, alpha: float) -> void:
	var tex := ZyfenFx.texture(id)
	if tex == null:
		return
	var half := r / ZyfenFx.TEX_FILL
	draw_set_transform(p, rot, Vector2.ONE)
	draw_texture_rect(
		tex, Rect2(Vector2(-half, -half), Vector2(half, half) * 2.0), false, Color(1, 1, 1, alpha)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
