class_name Motion
extends RefCounted
## Hareket token'ları (ms): docs/design/v1.1/DESIGN.md §5.3, tek kaynak. Görünüm, UI ve denetleyici süreleri buradan okur;
## sihirli sayı yazılmaz. Easing: mevcut `cubic-out`; ölüm devrilme `quad-in`.

# Oyuncu (DESIGN §1.2)
const RECOIL_KICK := 40
const RECOIL_BACK := 110
const MUZZLE_FLASH := 80
const HIT_FLASH := 90
const HIT_TINT := 200
const HIT_KNOCK := 50
const HIT_SPRING := 220  # 12 Hz sönümlü yay
const TURN := 70
const LEVELUP_PREROLL := 180
const LEVELUP_RING := 450
const DEATH_FREEZE := 120
const DEATH_FALL := 600
const DEATH_TOTAL := 1300
const WIN_TOTAL := 1800

# Düşman (DESIGN §1.3)
const ENEMY_FLASH := 125
const ENEMY_DEATH_PIYADE := 420
const ENEMY_DEATH_KARGA := 420
const ENEMY_DEATH_GHOST := 700
const ENEMY_DEATH_ELITE := 900
const ENEMY_DEATH_FAST := 220
const LORD_TELEGRAPH := 600
const LORD_SLAM := 120
const LORD_ENRAGE := 900
## Lord ölümünde yavaş çekim (plan A4): görünüm süresi × LORD_SLOWMO_SCALE.
const LORD_SLOWMO := 1200
const LORD_SLOWMO_SCALE := 0.4

# Eklentiler
const BOMB_FUSE := 800
const PICKUP_FLY := 120
const PICKUP_TOAST := 700

# Skor ve sonuç
const SCORE_EASE := 180
const SCORE_POP_UP := 80
const SCORE_POP_DOWN := 160
const RESULT_COUNT := 900
const RESULT_ROW_STAGGER := 120
const RECORD_STAMP := 280
const RESULT_BUTTONS := 1300
## Sonuç zaman çizelgesinde rekor damgasının düştüğü an (plan E).
const RESULT_STAMP_AT := 1250

# Vuruş donması istekleri (plan A5); tavan HitStop.MAX_SEC ile aynıdır.
const HITSTOP_BOMB := 60
const HITSTOP_LORD_RAGE := 80
const HITSTOP_LORD_DEATH := 150


## ms -> sn.
static func sec(ms: int) -> float:
	return float(ms) / 1000.0
