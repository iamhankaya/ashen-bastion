class_name ZyfenFx
extends RefCounted
## Zyfen rüzgar efekt dokuları (assets/gfx/fx/zyfen/): yol sabitleri, önbellekli yükleme ve mermi türü sınıflaması.
## Dokular sağa bakar, merkez pivottur; her kenarda >= %8 şeffaf pay vardır (TEX_FILL = görünür içeriğin tuval oranı).
## Döndürme/ölçek/soldurma çağıran çizim kodundadır; sim'e dokunulmaz.

const DIR := "res://assets/gfx/fx/zyfen/"
const TEX_FILL := 0.88

const KESIK := &"fx_kesik"
const AY_ORAGI := &"fx_ay_oragi"
const HAVA_BICAGI := &"fx_hava_bicagi"
const KESIK_PARCA := &"fx_kesik_parca"
const MIZRAK := &"fx_mizrak"
const GOK_MIZRAGI := &"fx_gok_mizragi"
const GIRDAP := &"fx_girdap"
const HORTUM := &"fx_hortum"
const TUFAN := &"fx_tufan"
const HAVA_CEBI := &"fx_hava_cebi"
const DALGA := &"fx_dalga"
const KASIRGA := &"fx_kasirga"
const AVUC := &"fx_avuc"

## Mermi doku türleri (ProjectileRenderer): tür -> görünür içerik genişliğinin çarpışma yarıçapına oranı.
const PROJECTILE_KINDS := {
	KESIK: 7.5,
	AY_ORAGI: 5.0,
	HAVA_BICAGI: 7.0,
	KESIK_PARCA: 7.0,
	MIZRAK: 20.0,
	GOK_MIZRAGI: 22.0,
}
## Çarpışma yarıçapı bu eşiğin üstündeyse dev hilal (Ay Orağı yarıçapı 40, kesik 14).
const GIANT_RADIUS := 30.0
## Delen kesik/mızrak yarıçapı 10, hızı 1400; Hava Bıçağı yarıçapı 10 ama hızı 900.
const SPEAR_SPEED := 1200.0

## Additive çizilen mermi türleri (ekran görüntüsüyle seçildi: koyu sahnede parlak çekirdek biraz daha okunur).
const ADDITIVE_PROJECTILES := {
	KESIK: true,
	AY_ORAGI: true,
	HAVA_BICAGI: true,
	KESIK_PARCA: true,
	MIZRAK: true,
	GOK_MIZRAGI: true,
}

## Bölge dokuları (Hortum/Tufan/Hava Cebi/Girdap) FxRenderer'ın additive malzemesini kullanır mı; değilse alfa karışımı.
const ZONES_ADDITIVE := false

static var _cache: Dictionary = {}


static func texture(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path := DIR + String(id) + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var r: Variant = load(path)
		if r is Texture2D:
			t = r
	_cache[id] = t
	return t


## Rüzgar mermisi için doku türü. `gok_mizragi` = oyuncunun Göğün Mızrağı evrimi var (mızraklar o dokuyu kullanır).
static func projectile_kind(flags: int, rad: float, speed: float, gok_mizragi: bool) -> StringName:
	if flags & ProjectilePool.FLAG_SPLIT:
		return AY_ORAGI if rad >= GIANT_RADIUS else KESIK_PARCA
	if speed >= SPEAR_SPEED:
		return GOK_MIZRAGI if gok_mizragi else MIZRAK
	if rad < WindUtil.CRESCENT_RADIUS - 0.5:
		return HAVA_BICAGI
	return KESIK
