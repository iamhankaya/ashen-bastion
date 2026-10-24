class_name WindRenderer
extends Node2D
## Rüzgar bölgeleri ve Girdap halkası (yalnız görsel; sim'i okur, hiçbir sim durumunu değiştirmez). FxRenderer'ın çocuğudur
## ve onun ek (additive) malzemesini kullanır. Yer tutucu kod çizimi: dönen yay demetleri + yumuşak leke; gerçek doku
## sonradan aynı sınıfa bağlanır. Ekran içi çizim sayısı MAX_DRAWN ile sınırlıdır (300 düşman + 3 hortum perf bütçesi).

const MAX_DRAWN := 24
const COLOR_TWISTER := Color(0.66, 0.88, 0.92)
const COLOR_GIANT := Color(0.78, 0.9, 1.0)
const COLOR_POCKET := Color(0.7, 0.8, 0.95)
const COLOR_RING := Color(0.7, 0.9, 0.95)
const FADE_TIME := 0.4

var _sim: GameSim = null
var _camera: CameraRig = null
## Son çizimde çizilen bölge sayısı (testler ve perf ölçümü için).
var drawn_count: int = 0


func _init() -> void:
	use_parent_material = true


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
	var soft := PlaceholderArt.soft_circle(64)
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
				_draw_pocket(z.pos[i], r, fade, t, soft)
			ZonePool.KIND_GIANT:
				_draw_swirl(z.pos[i], r, fade, t, COLOR_GIANT, 5, soft)
			_:
				_draw_swirl(z.pos[i], r, fade, t, COLOR_TWISTER, 3, soft)
	var gr := _girdap_radius()
	if gr > 0.0:
		_draw_ring(_sim.player_pos, gr, t)


## Dönen yay demeti: iç içe `arms` yay, dışa doğru incelen; alt tabanda yumuşak leke.
func _draw_swirl(
	p: Vector2, r: float, fade: float, t: float, col: Color, arms: int, soft: Texture2D
) -> void:
	draw_texture_rect(
		soft,
		Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0),
		false,
		Color(col.r, col.g, col.b, 0.16 * fade)
	)
	for k in arms:
		var f := float(k + 1) / float(arms)
		var a0 := t * (2.2 + 0.5 * f) + TAU * float(k) / float(arms)
		draw_arc(
			p,
			r * f,
			a0,
			a0 + PI * 0.9,
			20,
			Color(col.r, col.g, col.b, 0.75 * fade),
			3.0 + 2.0 * (1.0 - f),
			true
		)
	draw_circle(p, r * 0.08, Color(1.0, 1.0, 1.0, 0.5 * fade))


## Hava Cebi: içe doğru büzülen halka + soluk leke.
func _draw_pocket(p: Vector2, r: float, fade: float, t: float, soft: Texture2D) -> void:
	var pulse := 0.75 + 0.25 * sin(t * 9.0)
	draw_texture_rect(
		soft,
		Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0),
		false,
		Color(COLOR_POCKET.r, COLOR_POCKET.g, COLOR_POCKET.b, 0.2 * fade)
	)
	draw_arc(
		p,
		r * pulse,
		0.0,
		TAU,
		28,
		Color(COLOR_POCKET.r, COLOR_POCKET.g, COLOR_POCKET.b, 0.7 * fade),
		2.5,
		true
	)


## Girdap: oyuncuyu saran, dönen kesik halka.
func _draw_ring(p: Vector2, r: float, t: float) -> void:
	for k in 4:
		var a0 := t * 3.0 + TAU * float(k) / 4.0
		draw_arc(
			p,
			r,
			a0,
			a0 + PI * 0.35,
			12,
			Color(COLOR_RING.r, COLOR_RING.g, COLOR_RING.b, 0.55),
			3.0,
			true
		)
