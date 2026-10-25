class_name ZyfenFx
extends RefCounted
## Zyfen rüzgar efekt dokuları (assets/gfx/fx/zyfen/, v2 katmanlı: 32 parça): yol sabitleri, önbellekli yükleme ve mermi
## türü sınıflaması. Dokular sağa bakar, merkez pivottur; her kenarda >= %8 şeffaf pay vardır (TEX_FILL = görünür içeriğin
## tuval oranı). Hortum/Tufan gövdeleri ayakta (alt orta = zemin noktası), halkalar tepeden. Parçalar ayrı ayrı çizilir;
## döndürme/ölçek/akış/soldurma çağıran çizim kodundadır; sim'e dokunulmaz.

const DIR := "res://assets/gfx/fx/zyfen/"
const SHADER_DIR := "res://assets/shaders/"
const TEX_FILL := 0.88

# Mermiler
const KESIK := &"fx_kesik"
const KESIK_IZ := &"fx_kesik_iz"
const KESIK_PARCA := &"fx_kesik_parca"
const KESIK_KIRILMA := &"fx_kesik_kirilma"
const AY_ORAGI := &"fx_ay_oragi"
const AY_ORAGI_IZ := &"fx_ay_oragi_iz"
const PARILTI := &"fx_parilti"
const HAVA_BICAGI := &"fx_hava_bicagi"
const MIZRAK := &"fx_mizrak"
const MIZRAK_UC := &"fx_mizrak_uc"
const GOK_MIZRAGI := &"fx_gok_mizragi"
const GOK_ISIK := &"fx_gok_isik"
# Alanlar ve hortumlar
const HORTUM_GOVDE := &"fx_hortum_govde"
const HORTUM_AKIS := &"fx_hortum_akis"
const HORTUM_TABAN := &"fx_hortum_taban"
const TAS_1 := &"fx_tas_1"
const TAS_2 := &"fx_tas_2"
const TAS_3 := &"fx_tas_3"
const TAS_4 := &"fx_tas_4"
const TUFAN_GOVDE := &"fx_tufan_govde"
const TUFAN_TABAN := &"fx_tufan_taban"
const SIMSEK_1 := &"fx_simsek_1"
const SIMSEK_2 := &"fx_simsek_2"
const GIRDAP := &"fx_girdap"
const GIRDAP_IC := &"fx_girdap_ic"
const HAVA_CEBI := &"fx_hava_cebi"
const HAVA_CEBI_PATLAMA := &"fx_hava_cebi_patlama"
const DALGA := &"fx_dalga"
const KASIRGA := &"fx_kasirga"
# Atış ve isabet
const AVUC := &"fx_avuc"
const ISABET := &"fx_isabet"
const ISABET_BUYUK := &"fx_isabet_buyuk"

## 32 parçanın tümü (dışa aktarma, yükleme ve test listesi).
const ALL: Array[StringName] = [
	KESIK,
	KESIK_IZ,
	KESIK_PARCA,
	KESIK_KIRILMA,
	AY_ORAGI,
	AY_ORAGI_IZ,
	PARILTI,
	HAVA_BICAGI,
	MIZRAK,
	MIZRAK_UC,
	GOK_MIZRAGI,
	GOK_ISIK,
	HORTUM_GOVDE,
	HORTUM_AKIS,
	HORTUM_TABAN,
	TAS_1,
	TAS_2,
	TAS_3,
	TAS_4,
	TUFAN_GOVDE,
	TUFAN_TABAN,
	SIMSEK_1,
	SIMSEK_2,
	GIRDAP,
	GIRDAP_IC,
	HAVA_CEBI,
	HAVA_CEBI_PATLAMA,
	DALGA,
	KASIRGA,
	AVUC,
	ISABET,
	ISABET_BUYUK,
]
## Hortum/Tufan taşları (yörüngede; sırayla farklı biçim).
const STONES: Array[StringName] = [TAS_1, TAS_2, TAS_3, TAS_4]

## Mermi gövde doku türleri (ProjectileRenderer): tür -> görünür içerik genişliğinin çarpışma yarıçapına oranı.
const PROJECTILE_KINDS := {
	KESIK: 7.5,
	AY_ORAGI: 5.0,
	HAVA_BICAGI: 7.0,
	KESIK_PARCA: 7.0,
	MIZRAK: 20.0,
	GOK_MIZRAGI: 22.0,
}
## Mermi katmanları (arkadan öne çizim sırası): iz/ışık gövdenin arkasında, vurgu (uç, parıltı, kırılma) önünde.
const PROJECTILE_LAYERS: Array[StringName] = [
	GOK_ISIK,
	AY_ORAGI_IZ,
	KESIK_IZ,
	KESIK,
	KESIK_PARCA,
	HAVA_BICAGI,
	AY_ORAGI,
	MIZRAK,
	GOK_MIZRAGI,
	MIZRAK_UC,
	PARILTI,
	KESIK_KIRILMA,
]
## Çarpışma yarıçapı bu eşiğin üstündeyse dev hilal (Ay Orağı yarıçapı 40, kesik 14).
const GIANT_RADIUS := 30.0
## Delen kesik/mızrak yarıçapı 10, hızı 1400; Hava Bıçağı yarıçapı 10 ama hızı 900.
const SPEAR_SPEED := 1200.0

## Additive çizilen mermi katmanları (koyu sahnede parlak çekirdek ve iz okunur; ekran görüntüsüyle seçildi).
const ADDITIVE_PROJECTILES := {
	KESIK: true,
	AY_ORAGI: true,
	HAVA_BICAGI: true,
	KESIK_PARCA: true,
	MIZRAK: true,
	GOK_MIZRAGI: true,
	KESIK_IZ: true,
	AY_ORAGI_IZ: true,
	MIZRAK_UC: true,
	PARILTI: true,
	KESIK_KIRILMA: true,
	GOK_ISIK: true,
}

## Bölge dokuları (Hortum/Tufan/Hava Cebi/Girdap) FxRenderer'ın additive malzemesini kullanır mı; değilse alfa karışımı.
const ZONES_ADDITIVE := false

static var _cache: Dictionary = {}
static var _shaders: Dictionary = {}


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


## Önbellekli gölgelendirici (assets/shaders/<ad>.gdshader); yoksa null (çizim düz dokuya düşer).
static func shader(shader_name: String) -> Shader:
	if _shaders.has(shader_name):
		return _shaders[shader_name]
	var path := SHADER_DIR + shader_name + ".gdshader"
	var s: Shader = null
	if ResourceLoader.exists(path):
		var r: Variant = load(path)
		if r is Shader:
			s = r
	_shaders[shader_name] = s
	return s


## Rüzgar mermisi için doku türü. `gok_mizragi` = oyuncunun Göğün Mızrağı evrimi var (mızraklar o dokuyu kullanır).
static func projectile_kind(flags: int, rad: float, speed: float, gok_mizragi: bool) -> StringName:
	if flags & ProjectilePool.FLAG_SPLIT:
		return AY_ORAGI if rad >= GIANT_RADIUS else KESIK_PARCA
	if speed >= SPEAR_SPEED:
		return GOK_MIZRAGI if gok_mizragi else MIZRAK
	if rad < WindUtil.CRESCENT_RADIUS - 0.5:
		return HAVA_BICAGI
	return KESIK
