class_name Sfx
extends RefCounted
## Havuzlu ses efekti çalma (16 oyuncu, kimlik başına eşzamanlı sınır; sınırda en eski kesilir). Dosya yoksa
## (assets/audio/sfx/<kimlik>.ogg) sessizce çıkar: SFX paketi gelene kadar oyun sessiz SFX ile çalışır.
## Havuz AudioDirector tarafından `setup` ile kurulur. XP çınlaması ardışık toplamada perde yükseltir.
## Varyasyon: <kimlik>_1.._N dosyaları varsa her çalışta biri rastgele seçilir (üst üste aynısı değil). Seçim sunum
## RNG'siyle yapılır; sim RNG'sine dokunmaz (state_hash değişmez).

const DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 16
const LIMITS := {
	&"shot_right": 4,
	&"shot_left": 4,
	&"hit": 3,
	&"explosion": 3,
	&"enemy_die": 3,
	&"xp_pickup": 2,
}
const COMBO_WINDOW_MS := 600
const COMBO_MAX := 12
const COMBO_STEP := 0.06

static var _players: Array[AudioStreamPlayer] = []
static var _ids: Array[StringName] = []
static var _stamp: PackedInt64Array = PackedInt64Array()
static var _streams: Dictionary = {}
static var _variants: Dictionary = {}  # StringName -> Array[AudioStream] (_1.._N; boşsa tek dosya)
static var _last_variant: Dictionary = {}  # StringName -> son seçilen indeks
static var _rng := RandomNumberGenerator.new()
static var _clock: int = 0
static var _combo: int = 0
static var _last_pickup_ms: int = -100000


## Havuzu `parent` altında kurar (var olan havuz temizlenir).
static func setup(parent: Node) -> void:
	teardown()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		parent.add_child(p)
		_players.append(p)
		_ids.append(&"")
		_stamp.append(0)


static func teardown() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	_ids.clear()
	_stamp.resize(0)
	_combo = 0
	_last_pickup_ms = -100000


## Test/özel kullanım: kimliğe akış bağlar (dosya aramasını atlar).
static func register_stream(id: StringName, stream: AudioStream) -> void:
	_streams[id] = stream
	_variants.clear()


static func clear_registered() -> void:
	_streams.clear()
	_variants.clear()
	_last_variant.clear()


## Test: sunum RNG'sini sabitler (üretimde rastgele tohumlu).
static func seed_presentation(seed_value: int) -> void:
	_rng.seed = seed_value
	_last_variant.clear()


## Ardışık toplama perdesi: 1 + 0,06 x min(combo, 12).
static func xp_pitch(combo: int) -> float:
	return 1.0 + COMBO_STEP * float(mini(maxi(combo, 0), COMBO_MAX))


## Toplama sayacı: pencere içindeyse artar, değilse sıfırlanır. Perde çarpanını döndürür.
static func note_pickup(now_ms: int) -> float:
	if now_ms - _last_pickup_ms > COMBO_WINDOW_MS:
		_combo = 0
	var pitch := xp_pitch(_combo)
	_combo += 1
	_last_pickup_ms = now_ms
	return pitch


## Kimlik şu an kaç oyuncuda çalıyor.
static func playing_count(id: StringName) -> int:
	var n := 0
	for i in _players.size():
		if _ids[i] == id and _players[i].playing:
			n += 1
	return n


static func play(id: StringName, opts: Dictionary = {}) -> void:
	if _players.is_empty():
		return
	var stream := pick_stream(id)
	if stream == null:
		return
	_clock += 1
	var limit: int = LIMITS.get(id, POOL_SIZE)
	var same := 0
	var oldest_same := -1
	for i in _players.size():
		if _ids[i] == id and _players[i].playing:
			same += 1
			if oldest_same < 0 or _stamp[i] < _stamp[oldest_same]:
				oldest_same = i
	var slot := -1
	if same >= limit:
		slot = oldest_same  # sınırda en eski kesilir
	else:
		var oldest := 0
		for i in _players.size():
			if not _players[i].playing:
				slot = i
				break
			if _stamp[i] < _stamp[oldest]:
				oldest = i
		if slot < 0:
			slot = oldest
	var p := _players[slot]
	p.stream = stream
	p.pitch_scale = float(opts.get("pitch", 1.0))
	if id == &"xp_pickup" and not opts.has("pitch"):
		p.pitch_scale = note_pickup(Time.get_ticks_msec())
	p.volume_db = float(opts.get("volume_db", 0.0))
	_ids[slot] = id
	_stamp[slot] = _clock
	p.play()


## Kimliğin bu çalışta kullanılacak akışı: varyasyon varsa rastgele biri (önceki seçimden farklı), yoksa tek dosya.
static func pick_stream(id: StringName) -> AudioStream:
	var list := _variants_of(id)
	if list.is_empty():
		return null
	var n := list.size()
	var idx := 0
	if n > 1:
		var last: int = _last_variant.get(id, -1)
		idx = _rng.randi_range(0, n - 2)
		if last >= 0 and idx >= last:
			idx += 1  # son seçilen hariç n-1 adaydan biri
		_last_variant[id] = idx
	return list[idx]


## Kimliğin varyasyon sayısı (0: ses yok; 1: tek dosya).
static func variant_count(id: StringName) -> int:
	return _variants_of(id).size()


static func _variants_of(id: StringName) -> Array[AudioStream]:
	if _variants.has(id):
		return _variants[id]
	var list: Array[AudioStream] = []
	var direct: AudioStream = _streams.get(id)
	if direct != null:  # açıkça kaydedilmiş (test) tek akış varyasyondan önce gelir
		list.append(direct)
		_variants[id] = list
		return list
	var i := 1
	while true:
		var v := _stream_for(StringName("%s_%d" % [id, i]))
		if v == null:
			break
		list.append(v)
		i += 1
	if list.is_empty():
		var single := _stream_for(id)
		if single != null:
			list.append(single)
	_variants[id] = list
	return list


static func _stream_for(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := DIR + String(id) + ".ogg"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[id] = s
	return s
