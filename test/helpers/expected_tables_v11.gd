class_name ExpectedTablesV11
extends RefCounted
## v1.1 plan tablolarının SABİT kopyası (docs/plan/v1.1-plan.md "Sayılar"). Veri JSON'u okunmaz;
## test_acc_v11_tables.gd bu tabloları data/** ile karşılaştırır. Sayı değişikliği yalnız denge görevinde ve
## bu dosya ile birlikte yapılır (bu sürümde denge ayarı yok).

const HZ := 60

# --- Eklentiler (pickups.json) -------------------------------------------------------------------------------
const PICKUP_SPAWN := {
	"first": [30, 45],
	"interval": [45, 60],
	"dist": [450, 700],
	"clearance": 40,
	"life": 25,
	"blink_last": 5,
	"collect_radius": 72,
	"max_alive": 2,
}
## Dizi sırası = GameData.pickup_ids sırası (PickupPool.kind_idx).
const PICKUP_ORDER: Array[StringName] = [
	&"kizil_iksir", &"cekim_tasi", &"ofke_barutu", &"kizgin_namlu", &"kara_bomba", &"sonsuz_tambur"
]
const PICKUPS := {
	&"kizil_iksir":
	{"name": "Kızıl İksir", "rarity": "common", "weight": 30.0, "effect": "heal", "amount": 25.0},
	&"cekim_tasi": {"name": "Çekim Taşı", "rarity": "common", "weight": 20.0, "effect": "magnet"},
	&"ofke_barutu":
	{
		"name": "Öfke Barutu",
		"rarity": "uncommon",
		"weight": 15.0,
		"effect": "buff",
		"buff": "damage",
		"mult": 1.5,
		"duration": 12.0,
	},
	&"kizgin_namlu":
	{
		"name": "Kızgın Namlu",
		"rarity": "uncommon",
		"weight": 15.0,
		"effect": "buff",
		"buff": "fire_rate",
		"mult": 1.4,
		"duration": 12.0,
	},
	&"kara_bomba":
	{
		"name": "Kara Bomba",
		"rarity": "uncommon",
		"weight": 15.0,
		"effect": "bomb",
		"radius": 320.0,
		"fuse": 0.8,
		"dmg": 600.0,
		"elite_frac": 0.08,
		"elite_min": 600.0,
	},
	&"sonsuz_tambur":
	{
		"name": "Sonsuz Tambur",
		"rarity": "rare",
		"weight": 5.0,
		"effect": "buff",
		"buff": "unlimited",
		"duration": 10.0,
	},
}
const WEIGHT_TOTAL := 100.0
const HEAL_AMOUNT := 25.0
const DAMAGE_MULT := 1.5
const RATE_MULT := 1.4
const BUFF_STEPS := 720  # 12 sn
const UNLIMITED_STEPS := 600  # 10 sn
const FUSE_STEPS := 48  # 0,8 sn
const LIFE_STEPS := 1500  # 25 sn
const BOMB_RADIUS := 320.0
const BOMB_DMG := 600.0
const ELITE_FRAC := 0.08
const ELITE_MIN := 600.0
const COLLECT_RADIUS := 72.0
const XP_PICKUP_RADIUS := 110.0
const POOL_CAPS := {"pickups": 8, "bombs": 4, "ghosts": 64}

# --- Skor (score.json) ---------------------------------------------------------------------------------------
const KILL_POINTS := {
	&"curumus_piyade": 10,
	&"les_kargasi": 8,
	&"sovalye_hayaleti": 50,
	&"elit_piyade": 400,
	&"elit_sovalye": 1200,
	&"elit_karga": 1500,
	&"kale_lordu": 10000,
}
## (min_seri, çarpan) artan.
const TIERS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(10, 2), Vector2i(25, 3), Vector2i(50, 4), Vector2i(100, 5)
]
const WINDOW_STEPS := 180
const WINDOW_SEC := 3.0
const EVOLUTION_BONUS := 2000
const SURVIVAL_PER_SEC := 5
const LORD_BONUS := 25000
const DISPLAY_CAP := 99999999

# --- Highscore -----------------------------------------------------------------------------------------------
const HS_VERSION := 1
const HS_MAX := 10
const HS_KEYS: Array[String] = ["score", "time", "won", "level", "unix"]

# --- Gecikme / vuruş donması / sonuç zaman çizelgesi (sn) ------------------------------------------------------
const DELAY_DEATH := 1.3
const DELAY_WIN := 1.8
const DELAY_LEVELUP := 0.18
const HITSTOP_MAX := 0.15
const HITSTOP_BOMB := 0.06
const HITSTOP_LORD_RAGE := 0.08
const HITSTOP_LORD_DEATH := 0.15
const COUNT_SEC := 0.9
const ROW_STAGGER_SEC := 0.12
const STAMP_SEC := 1.25
const BUTTONS_SEC := 1.3

# --- Animasyon -----------------------------------------------------------------------------------------------
const WALK_STRIDE := 136.0
const FOOT_SHIFT_6 := 136.0 / 6.0
## Düşman anim tablosu (DESIGN §1.3; elit frekansı hz × √(h₀/h)). rot ve lean derece.
const ENEMY_ANIM := {
	&"curumus_piyade":
	{
		"kind": "crawl",
		"hz": 1.1,
		"bob": 5.0,
		"rot": 5.0,
		"sq": 0.05,
		"lean": 4.0,
		"hover": 0.0,
		"knock": 10.0,
		"hit_sq": 0.12,
		"hit_rot": 0.0,
		"death": "collapse",
		"death_ms": 420,
		"cycle": 72.0,
	},
	&"les_kargasi":
	{
		"kind": "flap",
		"hz": 3.0,
		"bob": 7.0,
		"rot": 12.0,
		"sq": 0.10,
		"lean": 0.0,
		"hover": 36.0,
		"knock": 14.0,
		"hit_sq": 0.12,
		"hit_rot": 15.0,
		"death": "fall",
		"death_ms": 420,
	},
	&"sovalye_hayaleti":
	{
		"kind": "float",
		"hz": 0.7,
		"bob": 6.0,
		"rot": 2.5,
		"sq": 0.03,
		"lean": 0.0,
		"hover": 24.0,
		"knock": 4.0,
		"hit_sq": 0.04,
		"hit_rot": 0.0,
		"death": "ash_up",
		"death_ms": 700,
		"alpha": [0.9, 1.0],
	},
	&"elit_piyade":
	{
		"kind": "crawl",
		"hz": 0.74,
		"bob": 5.0,
		"rot": 5.0,
		"sq": 0.05,
		"lean": 4.0,
		"hover": 0.0,
		"knock": 2.0,
		"hit_sq": 0.03,
		"hit_rot": 0.0,
		"death": "ash_big",
		"death_ms": 900,
		"cycle": 160.0,
	},
	&"elit_sovalye":
	{
		"kind": "float",
		"hz": 0.52,
		"bob": 6.0,
		"rot": 2.5,
		"sq": 0.03,
		"lean": 0.0,
		"hover": 24.0,
		"knock": 2.0,
		"hit_sq": 0.03,
		"hit_rot": 0.0,
		"death": "ash_big",
		"death_ms": 900,
	},
	&"elit_karga":
	{
		"kind": "flap",
		"hz": 1.49,
		"bob": 7.0,
		"rot": 12.0,
		"sq": 0.10,
		"lean": 0.0,
		"hover": 36.0,
		"knock": 2.0,
		"hit_sq": 0.03,
		"hit_rot": 0.0,
		"death": "ash_big",
		"death_ms": 900,
	},
	&"kale_lordu":
	{
		"kind": "stomp",
		"hz": 0.55,
		"bob": 6.0,
		"rot": 2.5,
		"sq": 0.0,
		"lean": 0.0,
		"hover": 0.0,
		"knock": 0.0,
		"hit_sq": 0.015,
		"hit_rot": 0.0,
		"death": "lord",
		"death_ms": 900,
	},
}
## Hayalet ömürleri (ms) E6.
const GHOST_LIFE_MS := {"piyade": 420, "karga": 420, "hayalet": 700, "elit": 900, "lod": 150}

# --- Bütçe ---------------------------------------------------------------------------------------------------
const ATLAS_CELLS := 11
const ATLAS_COLS := 3
const ATLAS_ROWS := 4
const ATLAS_PX := Vector2i(1248, 1664)
const ATLAS_BYTES_MAX := 8_700_000  # ≈ 8,3 MB RGBA (+ tolerans)
const STRIP_BYTES_MAX := 3_000_000
const CELL_RECT_UNIFORM := 16
const DRAW_CALLS_PLUS := 8
