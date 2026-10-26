class_name GemTiers
extends RefCounted
## v2.0.3 küre tipi -> görsel eşlemesi (veri alanları). Yalnız GÖRÜNÜM sınıfı: sim/hash değişmez (game_sim hash'i
## yalnız `count` ve `total_value` kullanır). GemRenderer'ın tipe göre doku/boyut seçimi B fazının işidir.
## Sınıflar (xp değeri): <5 normal, 5..79 elit (sovalye_hayaleti), >=80 ara boss (elit_* bossları, Kale Lordu).

enum { NORMAL, ELIT, BOSS }
const COUNT := 3
const ELIT_MIN := 5
const BOSS_MIN := 80
## Tip sırasıyla işlenmiş doku (B üretir; kaynak: art/source/gem-orbs/).
const TEXTURES: PackedStringArray = [
	"res://assets/gfx/fx/gems/normal.png",
	"res://assets/gfx/fx/gems/elit.png",
	"res://assets/gfx/fx/gems/ara_boss.png",
]
## Tip sırasıyla oyun içi küre boyutu (px; docs/design/v2.0.3).
const ORB_PX: PackedInt32Array = [34, 48, 68]


static func tier_of(value: int) -> int:
	if value >= BOSS_MIN:
		return BOSS
	return ELIT if value >= ELIT_MIN else NORMAL
