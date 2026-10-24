class_name ExpectedTables
extends RefCounted
## Plan tablolarının SABİT kopyası (docs/plan "Denge tabloları"). Veri JSON'u okunmaz; test_acc_tables.gd
## bu tabloları data/** ile karşılaştırır. Sayı değişikliği yalnız denge görevinde ve bu dosya ile birlikte yapılır.
## VARSAYIM: slice-2 aktiflerinin seviye anahtar adları (cooldown/pellets/count/chance/...) plan metninden
## ve docs/data-schema.md'deki anahtar kümesinden türetildi; slice-1 aktiflerinin adları C1 fixture'larındadır.

const U1_ACTIVES: Array[StringName] = [&"cift_tabanca", &"seken_mermi", &"son_mermi_patlar"]
const U2_ACTIVES: Array[StringName] = [
	&"yelpaze_atis", &"dinamit", &"doldurma_sacilmasi", &"sarapnel", &"keskin_nisan"
]
const PASSIVES: Array[StringName] = [
	&"barut_kesesi",
	&"hizli_doldurma",
	&"fazladan_mermi",
	&"agir_kursun",
	&"hizli_parmak",
	&"cevik_cizme",
	&"saglam_yelek",
	&"miknatis"
]
const EVOLUTIONS: Array[StringName] = [
	&"zincirleme_patlama", &"kiyamet_mermisi", &"mermi_firtinasi", &"gurleyen_yelpaze"
]
const U1_ENEMIES: Array[StringName] = [&"curumus_piyade", &"les_kargasi", &"sovalye_hayaleti"]
const U2_ENEMIES: Array[StringName] = [
	&"elit_piyade", &"elit_sovalye", &"elit_karga", &"kale_lordu"
]
const RHYTHM_TAGGED: Array[StringName] = [
	&"seken_mermi",
	&"son_mermi_patlar",
	&"doldurma_sacilmasi",
	&"hizli_doldurma",
	&"fazladan_mermi",
	&"kiyamet_mermisi",
	&"mermi_firtinasi"
]

## Aktifler: anahtar -> 5 seviyelik değer dizisi.
const ACTIVE_LEVELS := {
	&"cift_tabanca":
	{
		"damage": [15, 18, 21, 24, 28],
		"interval": [0.30, 0.28, 0.26, 0.24, 0.22],
	},
	&"seken_mermi":
	{
		"every_n": [3, 3, 3, 2, 2],
		"bounces": [2, 3, 3, 4, 5],
		"damage_mult": [1.0, 1.1, 1.2, 1.3, 1.4],
	},
	&"son_mermi_patlar":
	{
		"ex_damage": [50, 70, 90, 115, 150],
		"ex_radius": [100, 115, 130, 150, 170],
	},
	&"yelpaze_atis":
	{
		"cooldown": [4.0, 3.6, 3.2, 2.8, 2.4],
		"pellets": [5, 6, 7, 8, 9],
		"damage": [9, 10, 11, 12, 14],
	},
	&"dinamit":
	{
		"cooldown": [3.5, 3.2, 2.9, 2.6, 2.2],
		"count": [1, 1, 2, 2, 3],
		"damage": [60, 75, 90, 110, 135],
		"radius": [130, 140, 150, 165, 180],
	},
	&"doldurma_sacilmasi":
	{
		"count": [8, 10, 12, 14, 16],
		"damage": [10, 12, 14, 16, 18],
	},
	&"sarapnel":
	{
		"chance": [0.25, 0.30, 0.35, 0.40, 0.50],
		"pellets": [3, 4, 4, 5, 6],
		"damage": [18, 22, 26, 30, 36],
	},
	&"keskin_nisan":
	{
		"cooldown": [3.0, 2.8, 2.6, 2.4, 2.0],
		"damage": [90, 120, 150, 190, 240],
	},
}

## Pasifler: seviye N'deki TOPLAM değer = anahtar başına adım × N (şema: pasif levels[i] toplamdır).
const PASSIVE_STEPS := {
	&"barut_kesesi": {"area_mult": 0.12, "explosion_dmg_mult": 0.08},
	&"hizli_doldurma": {"reload_time_mult": -0.10},
	&"fazladan_mermi": {"mag_add": 1},
	&"agir_kursun": {"bullet_dmg_mult": 0.10},
	&"hizli_parmak": {"fire_rate_mult": 0.08},
	&"cevik_cizme": {"move_speed_mult": 0.06},
	&"saglam_yelek": {"max_hp_add": 15, "regen": 0.25},
	&"miknatis": {"pickup_mult": 0.25},
}

## Evrim -> [aktif, pasif]. Koşul: aktif max_level (5) + pasif seviye >= 1.
const EVOLUTION_REQUIRES := {
	&"zincirleme_patlama": [&"seken_mermi", &"barut_kesesi"],
	&"kiyamet_mermisi": [&"son_mermi_patlar", &"hizli_doldurma"],
	&"mermi_firtinasi": [&"doldurma_sacilmasi", &"fazladan_mermi"],
	&"gurleyen_yelpaze": [&"yelpaze_atis", &"agir_kursun"],
}

## Düşmanlar: hp, speed, dmg (temas), radius, armor, xp, ai.
const ENEMIES := {
	&"curumus_piyade":
	{"hp": 30, "speed": 95, "dmg": 6, "radius": 26, "armor": 0, "xp": 1, "ai": "ground"},
	&"les_kargasi":
	{"hp": 12, "speed": 210, "dmg": 4, "radius": 18, "armor": 0, "xp": 1, "ai": "air"},
	&"sovalye_hayaleti":
	{"hp": 220, "speed": 70, "dmg": 18, "radius": 36, "armor": 3, "xp": 5, "ai": "ghost"},
	&"elit_piyade":
	{"hp": 1800, "speed": 110, "dmg": 14, "radius": 60, "armor": 2, "xp": 80, "ai": "elite"},
	&"elit_sovalye":
	{"hp": 6500, "speed": 85, "dmg": 28, "radius": 66, "armor": 5, "xp": 160, "ai": "elite"},
	&"elit_karga":
	{"hp": 9000, "speed": 170, "dmg": 30, "radius": 52, "armor": 3, "xp": 260, "ai": "elite"},
	&"kale_lordu":
	{"hp": 45000, "speed": 80, "dmg": 40, "radius": 72, "armor": 6, "xp": 500, "ai": "lord"},
}

const CHARACTER := {
	"id": "gunslinger",
	"max_hp": 100,
	"move_speed": 300,
	"mag_cap": 6,
	"reload_time": 1.0,
	"pickup_radius": 110,
	"collision_radius": 22,
	"starting_skill": "cift_tabanca",
	"range": 700,
}

## Boss çizelgesi: tür -> at (sn). warn her biri için 5.
const BOSSES := {
	&"elit_piyade": 300.0,
	&"elit_sovalye": 600.0,
	&"elit_karga": 900.0,
	&"kale_lordu": 1200.0,
}
const BURST_TIMES: Array[float] = [480.0, 720.0, 960.0]
const BURST_COUNTS := {480: 65, 720: 70, 960: 75}
const BOSS_WARN := 5.0
const END_TIME := 1200.0

## Zorluk sabit noktaları (dk -> [hp, dmg]); alive_cap(sn) noktaları.
const DIFFICULTY_POINTS := {5: [1.6625, 1.2], 10: [2.65, 1.7], 15: [3.9625, 2.2], 20: [5.6, 2.7]}
const CAP_POINTS := {300.0: 130, 600.0: 220, 900.0: 310, 1200.0: 400}

## XpCurve: need(n) sabit noktaları ve cumulative(10).
const XP_NEED := {1: 12, 2: 16, 3: 20, 4: 25, 5: 30, 10: 58, 20: 128, 30: 218, 40: 328}
const XP_CUMULATIVE_10 := 276
