class_name SettingsFlow
extends RefCounted
## v2.0.3 ayarlar akışı iskeleti (D fazı doldurur): ayarlar iki yerden açılır (ana sayfa, duraklatma); `game_controller.gd`
## yalnız bu sınıfa bağlanır (dosya satır tavanında; D'nin payı en çok +2 satır).

signal closed
signal hareket_azalt_toggled(on: bool)

const SOURCE_MENU := &"menu"
const SOURCE_PAUSE := &"pause"

var source: StringName = SOURCE_MENU


func open(p_source: StringName) -> void:
	source = p_source


func close() -> void:
	closed.emit()
