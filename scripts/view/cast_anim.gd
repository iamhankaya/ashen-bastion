class_name CastAnim
extends RefCounted
## Kolsuz rig için atış (cast), rüzgar toplama (gather) ve yürürken savuruş (walk_cast) kare seçimi (saf, görünüm).
## Çıktı `frame()`: mutlak şerit hücre indeksi ya da -1 (geçersiz kılma yok, yürüme/duruş sürer).
## Kare önceliği: cast/walk_cast > gather > yürüme > duruş. `action_while_moving = false` iken cast/gather yalnız oyuncu
## dururken gösterilir; yürürken atış `walk_cast` tanımlıysa onu oynatır, yoksa yürüme sürer (hata değil).
## Cast klibi `fire_frame` karesinden başlar (kesik o karede çıkar). Gather kareleri doldurma ilerlemesine eşlenir:
## 4 karede <0,2 k0, <0,5 k1, <0,85 k2, sonra k3. `holds_walk()` true iken yürüme saati dondurulur (kare sıçraması yok).

const GATHER_CUTS := [0.2, 0.5, 0.85]

var _rig: Dictionary = {}
var _awm: bool = false
var _cast_n: int = 0
var _cast_fire: int = 0
var _cast_fps: float = 24.0
var _gather_n: int = 0
var _wc_n: int = 0
var _wc_fire: int = 0
var _wc_fps: float = 24.0
var _clip: int = -1  # 0 cast, 1 walk_cast, -1 yok
var _clip_t: float = 0.0
var _reload_total: float = 0.0
var _reload_t: float = 0.0
var _reloading: bool = false
var _walking: bool = false


func configure(rig: Dictionary) -> void:
	_rig = rig
	var awm: Variant = rig.get("action_while_moving", false)
	_awm = awm is bool and awm
	_cast_n = _n(rig, "cast")
	_gather_n = _n(rig, "gather")
	_wc_n = _n(rig, "walk_cast")
	var c: Variant = rig.get("cast", null)
	_cast_fire = (
		clampi(int(c.get("fire_frame", 0)), 0, maxi(_cast_n - 1, 0)) if c is Dictionary else 0
	)
	_cast_fps = clampf(float(c.get("fps", 24.0)), 1.0, 120.0) if c is Dictionary else 24.0
	var w: Variant = rig.get("walk_cast", null)
	_wc_fire = clampi(int(w.get("fire_frame", 0)), 0, maxi(_wc_n - 1, 0)) if w is Dictionary else 0
	_wc_fps = clampf(float(w.get("fps", 24.0)), 1.0, 120.0) if w is Dictionary else 24.0
	reset()


func reset() -> void:
	_clip = -1
	_clip_t = 0.0
	_reloading = false
	_reload_t = 0.0
	_reload_total = 0.0
	_walking = false


## Atış anı. Yürürken: walk_cast varsa o set, yoksa (action_while_moving true ise) cast; hiçbiri yoksa yürüme sürer.
func on_shot() -> void:
	var set_id := -1
	if _walking:
		if _wc_n > 0:
			set_id = 1
		elif _awm and _cast_n > 0:
			set_id = 0
	elif _cast_n > 0:
		set_id = 0
	if set_id < 0:
		return
	_clip = set_id
	_clip_t = float(_clip_first(set_id)) / _clip_fps(set_id)


func on_reload(duration: float) -> void:
	if _gather_n < 1:
		return
	_reloading = true
	_reload_total = maxf(duration, 0.001)
	_reload_t = 0.0


func on_reload_end() -> void:
	_reloading = false


## `walking`: oyuncu şu an yürüyor (PlayerAnim.Mode.WALK). Klip yürürken başlamışsa durunca da tamamlanır.
func update(dt: float, walking: bool) -> void:
	_walking = walking
	if dt <= 0.0:
		return
	if _clip >= 0:
		_clip_t += dt
		if _clip_t * _clip_fps(_clip) >= float(_clip_len(_clip)):
			_clip = -1
	if _reloading:
		_reload_t += dt


## Yürüme saati dondurulsun mu (yürürken cast/walk_cast klibi oynuyor).
func holds_walk() -> bool:
	return _walking and (_clip == 1 or (_clip == 0 and _awm))


## Mutlak şerit hücresi; -1 = geçersiz kılma yok.
func frame() -> int:
	if _clip >= 0 and not (_clip == 0 and _walking and not _awm):
		var k := mini(int(_clip_t * _clip_fps(_clip)), _clip_len(_clip) - 1)
		var base := RigFrames.cast_base(_rig) if _clip == 0 else RigFrames.walk_cast_base(_rig)
		return base + k if base >= 0 else -1
	if _reloading and _gather_n > 0 and (not _walking or _awm):
		var base := RigFrames.gather_base(_rig)
		return base + gather_index(_reload_t / _reload_total, _gather_n) if base >= 0 else -1
	return -1


## Doldurma ilerlemesi (0..1) -> gather karesi. 4 karede sabit eşikler, diğer sayılarda eşit bölme.
static func gather_index(progress: float, n: int) -> int:
	if n <= 1:
		return 0
	if n == 4:
		for k in GATHER_CUTS.size():
			if progress < GATHER_CUTS[k]:
				return k
		return 3
	return clampi(int(progress * n), 0, n - 1)


func _clip_len(set_id: int) -> int:
	return _cast_n if set_id == 0 else _wc_n


func _clip_fps(set_id: int) -> float:
	return _cast_fps if set_id == 0 else _wc_fps


func _clip_first(set_id: int) -> int:
	return _cast_fire if set_id == 0 else _wc_fire


static func _n(rig: Dictionary, key: String) -> int:
	var b: Variant = rig.get(key, null)
	return maxi(0, int(b.get("frames", 0))) if b is Dictionary else 0
