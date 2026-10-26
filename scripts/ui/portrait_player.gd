class_name PortraitPlayer
extends VideoStreamPlayer
## Hareketli karakter portresi (v2.0.3 A): `.ogv` döngüsü; yalnız karakter seçim ekranında. Statik portre altta durur,
## bu düğüm onun üstüne biner: hareket azaltma açıkken, dosya yokken ya da çözülemeyen videoda hiç görünmez (düşüş = statik).

signal failed

## İlk kare gelmezse (bozuk/çözülemeyen akış) bu süre sonra vazgeçilir.
const START_TIMEOUT_SEC := 1.5

var _waited: float = 0.0
var _live: bool = false


func _init() -> void:
	name = "PortraitVideo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand = true
	loop = true
	autoplay = false
	visible = false
	set_process(false)


## `video_path` boş/yok/akış değilse ya da `reduced` ise statik portreye düşer (false döner).
func show_source(video_path: String, reduced: bool) -> bool:
	_live = false
	stop()
	visible = false
	stream = null
	set_process(false)
	if reduced or video_path == "" or not ResourceLoader.exists(video_path):
		return false
	var s := load(video_path) as VideoStream
	if s == null:
		failed.emit()
		return false
	stream = s
	_waited = 0.0
	play()
	set_process(true)
	return true


func is_live() -> bool:
	return _live


func _process(delta: float) -> void:
	if _live:
		return
	var tex := get_video_texture()
	if tex != null and tex.get_width() > 8 and is_playing():  # bozuk akışta oynatıcı boş doku verir
		_live = true
		visible = true  # ilk kare hazır: siyah çakma olmaz
		set_process(false)
		return
	_waited += delta
	if _waited >= START_TIMEOUT_SEC:
		stop()
		stream = null
		set_process(false)
		failed.emit()
