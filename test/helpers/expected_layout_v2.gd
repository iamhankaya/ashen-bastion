class_name ExpectedLayoutV2
extends RefCounted
## v2.0 kabul beklenen yerleşim sabitleri (1080×2400 referans). Kaynak: docs/design/v2.0/DESIGN.md ve
## docs/plan/v2.0-plan.md test stratejisi (B4/B6/K3/K5/M kabul listeleri). Değerler buraya sabit yazılır; kodu izlemez.

const REF := Vector2(1080.0, 2400.0)

# --- Bildirim (DESIGN.md §5.2): Rect2(150, 820 + safe_top, 780, 120) ---
const TOAST := Rect2(150.0, 820.0, 780.0, 120.0)

## Bildirimle KESİŞMEMESİ gereken HUD bölgeleri (plan B4 geometri maddesi). [ad, Rect2 (safe_top=0 referans)]
const TOAST_AVOID: Array = [
	["skor_kutusu", Rect2(584.0, 284.0, 460.0, 152.0)],  # x584-1044, y284-436
	["elit_satiri", Rect2(0.0, 506.0, 1080.0, 98.0)],  # y506-604
	["lord_bandi", Rect2(0.0, 520.0, 1080.0, 132.0)],  # y520-652
	["yuva_satiri", Rect2(0.0, 270.0, 1080.0, 70.0)],  # y270-340
	["tambur_rozet", Rect2(0.0, 2160.0, 1080.0, 168.0)],  # y2160-2328
]

# --- Başarımlar ekranı (B6) ---
const ROW_SIZE := Vector2(936.0, 150.0)  # v2.0.3 (DESIGN v2.0.3 §4.2); v2.0: 156
const ROW_TOUCH_MIN := 132.0
const ACH_TOP_MIN := 96.0  # + güvenli üst pay
const ACH_BOTTOM_PAD := 72.0  # 2400 - 72 - güvenli alt pay

# --- Karakterler ekranı (K) ---
const CHAR_SELECT_Y := 2013.0
const CHAR_BACK_Y := 2196.0
const CHAR_CARD := Vector2(252.0, 264.0)

# --- Seviye atlama (K3) ---
const LEVELUP_NAME_Y := 880.0

# --- Sonuç ekranı (M5) ---
const RESULT_DETAIL_MIN_PX := 26
const RESULT_BUTTONS_Y := Vector2(1866.0, 2181.0)
# DESIGN §5.6 sığma kuralı: düğmeler (< 2328) güvenli alt sınırın içinde kalır. 1866–2181 tasarım metninin
# tahmini; gerçek yerleşim kombo satır yüksekliğine (96) bağlı, kesin bağ alt sınırdır (B-tur gerekçesi).
const RESULT_SAFE_BOTTOM := 2328.0

# --- Ok (M7) ---
const ARROW_GLYPH_MIN_EDGE := 36.0

# Güvenli alan payları (sol, üst, sağ, alt): K3/B6/M2 testlerinde üç değer.
const SAFE_NONE := Vector4(0.0, 0.0, 0.0, 0.0)
const SAFE_NOTCH := Vector4(0.0, 100.0, 0.0, 150.0)
const SAFE_WIDE := Vector4(24.0, 60.0, 24.0, 90.0)
