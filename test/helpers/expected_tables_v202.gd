class_name ExpectedTablesV202
extends RefCounted
## v2.0.2 Zyfen beklenen sayılar: docs/plan/v2.0.2-zyfen-plan.md "Arayüzler/6" tablosundan ELLE kopyalandı (oyun kodundan ya da
## data/skills/*.json'dan türetilmedi; bağımsız kopya). D fazı bir sayıyı bilerek değiştirirse bu dosya VLAD onayıyla güncellenir.
## Biçim: beceri kimliği -> {"kind", "levels": [{anahtar: değer}, ...]} (sv1..svN). Zyfen'e özel olmayan ayarlar `CHARACTER`'dadır.

const CHARACTER := {
	"id": "zyfen",
	"max_hp": 85.0,
	"move_speed": 310.0,
	"mag_cap": 8,
	"reload_time": 1.3,
	"range": 750.0,
	"pickup_radius": 110.0,
	"collision_radius": 22.0,
	"order": 2,
	"display_upper": "ZYFEN",
	"starting_skill": "ruzgar_kesigi",
}

const SKILLS := {
	"ruzgar_kesigi":
	{
		"kind": "active",
		"levels":
		[
			{"damage": 12.0, "interval": 0.36},
			{"damage": 14.0, "interval": 0.34},
			{"damage": 17.0, "interval": 0.32},
			{"damage": 19.0, "interval": 0.30},
			{"damage": 22.0, "interval": 0.28},
		],
	},
	"hava_bicaklari":
	{
		"kind": "active",
		"levels":
		[
			{"cooldown": 3.4, "pellets": 3, "damage": 10.0, "pierce": 1},
			{"cooldown": 3.1, "pellets": 3, "damage": 11.0, "pierce": 1},
			{"cooldown": 2.8, "pellets": 4, "damage": 12.0, "pierce": 1},
			{"cooldown": 2.5, "pellets": 4, "damage": 13.0, "pierce": 2},
			{"cooldown": 2.2, "pellets": 5, "damage": 15.0, "pierce": 2},
		],
	},
	"girdap":
	{
		"kind": "active",
		"levels":
		[
			{"radius": 90.0, "damage": 6.0, "interval": 0.50, "push": 14.0},
			{"radius": 100.0, "damage": 7.0, "interval": 0.50, "push": 16.0},
			{"radius": 110.0, "damage": 8.0, "interval": 0.45, "push": 18.0},
			{"radius": 120.0, "damage": 10.0, "interval": 0.40, "push": 22.0},
			{"radius": 135.0, "damage": 12.0, "interval": 0.35, "push": 26.0},
		],
	},
	"hortum":
	{
		"kind": "active",
		"levels":
		[
			{
				"cooldown": 6.0,
				"count": 1,
				"damage": 8.0,
				"radius": 150.0,
				"life": 3.0,
				"pull": 70.0,
				"push": 120.0,
				"fling": 0.0
			},
			{
				"cooldown": 5.6,
				"count": 1,
				"damage": 10.0,
				"radius": 165.0,
				"life": 3.2,
				"pull": 80.0,
				"push": 130.0,
				"fling": 0.0
			},
			{
				"cooldown": 5.2,
				"count": 1,
				"damage": 12.0,
				"radius": 180.0,
				"life": 3.5,
				"pull": 90.0,
				"push": 140.0,
				"fling": 0.0
			},
			{
				"cooldown": 4.8,
				"count": 2,
				"damage": 14.0,
				"radius": 200.0,
				"life": 3.8,
				"pull": 100.0,
				"push": 150.0,
				"fling": 0.0
			},
			{
				"cooldown": 4.4,
				"count": 2,
				"damage": 17.0,
				"radius": 220.0,
				"life": 4.2,
				"pull": 115.0,
				"push": 170.0,
				"fling": 0.0
			},
		],
	},
	"delen_ruzgar":
	{
		"kind": "active",
		"levels":
		[
			{"cooldown": 3.2, "damage": 80.0},
			{"cooldown": 3.0, "damage": 105.0},
			{"cooldown": 2.7, "damage": 135.0},
			{"cooldown": 2.4, "damage": 170.0},
			{"cooldown": 2.1, "damage": 215.0},
		],
	},
	"bolunen_kesik":
	{
		"kind": "active",
		"levels":
		[
			{"every_n": 3, "damage_mult": 1.0, "count": 2},
			{"every_n": 3, "damage_mult": 1.1, "count": 2},
			{"every_n": 3, "damage_mult": 1.2, "count": 2},
			{"every_n": 2, "damage_mult": 1.3, "count": 2},
			{"every_n": 2, "damage_mult": 1.4, "count": 3},
		],
	},
	"hava_cebi":
	{
		"kind": "active",
		"levels":
		[
			{"chance": 0.25, "radius": 70.0, "damage": 8.0, "life": 1.2, "pull": 30.0},
			{"chance": 0.30, "radius": 76.0, "damage": 10.0, "life": 1.4, "pull": 35.0},
			{"chance": 0.35, "radius": 82.0, "damage": 12.0, "life": 1.6, "pull": 40.0},
			{"chance": 0.40, "radius": 90.0, "damage": 14.0, "life": 1.8, "pull": 45.0},
			{"chance": 0.50, "radius": 100.0, "damage": 16.0, "life": 2.0, "pull": 50.0},
		],
	},
	"nefes_dalgasi":
	{
		"kind": "active",
		"levels":
		[
			{"radius": 200.0, "damage": 14.0, "push": 120.0},
			{"radius": 230.0, "damage": 17.0, "push": 140.0},
			{"radius": 260.0, "damage": 20.0, "push": 160.0},
			{"radius": 290.0, "damage": 23.0, "push": 180.0},
			{"radius": 320.0, "damage": 27.0, "push": 200.0},
		],
	},
	"furtina_gozu":
	{
		"kind": "passive",
		"levels":
		[
			{"area_mult": 0.12, "wind_time_mult": 0.10},
			{"area_mult": 0.24, "wind_time_mult": 0.20},
			{"area_mult": 0.36, "wind_time_mult": 0.30},
			{"area_mult": 0.48, "wind_time_mult": 0.40},
			{"area_mult": 0.60, "wind_time_mult": 0.50},
		],
	},
	"ay_oragi":
	{
		"kind": "evolution",
		"levels":
		[{"every_n": 2, "damage_mult": 2.0, "radius": 40.0, "speed": 1300.0, "range": 1100.0}],
		"requires": {"active": "bolunen_kesik", "passive": "agir_kursun"},
	},
	"kasirga_patlamasi":
	{
		"kind": "evolution",
		"levels": [{"damage": 36.0, "radius": 900.0, "push": 260.0, "count": 2, "interval": 0.5}],
		"requires": {"active": "nefes_dalgasi", "passive": "hizli_doldurma"},
	},
	"gogun_mizragi":
	{
		"kind": "evolution",
		"levels": [{"cooldown": 1.8, "count": 4, "damage": 100.0, "gap": 0.12}],
		"requires": {"active": "delen_ruzgar", "passive": "hizli_parmak"},
	},
	"tufan":
	{
		"kind": "evolution",
		"levels":
		[
			{
				"cooldown": 9.0,
				"count": 3,
				"radius": 190.0,
				"damage": 20.0,
				"interval": 0.35,
				"pull": 260.0,
				"life": 8.0,
				"push": 220.0,
				"fling": 0.0
			}
		],
		"requires": {"active": "hortum", "passive": "furtina_gozu"},
	},
}

## Ortak pasiflerin Zyfen adları (plan "Arayüzler/2", sv1 -> sv5 ilk/son açıklama anahtar sözcüğü ayrıca testte).
const COMMON_NAMES := {
	"cevik_cizme": ["Çevik Çizme", "Rüzgar Adımı"],
	"saglam_yelek": ["Sağlam Yelek", "Yas Paltosu"],
	"miknatis": ["Mıknatıs", "Çeken Esinti"],
	"agir_kursun": ["Ağır Kurşun", "Bilenmiş Rüzgar"],
	"hizli_parmak": ["Hızlı Parmak", "Çevik Eller"],
	"fazladan_mermi": ["Fazladan Mermi", "Derin Nefes"],
	"hizli_doldurma": ["Hızlı Doldurma", "Çabuk Toplayış"],
}

## Karaktere özel havuzlar (plan "Arayüzler/1").
const GUNSLINGER_ONLY := [
	"cift_tabanca",
	"yelpaze_atis",
	"seken_mermi",
	"son_mermi_patlar",
	"doldurma_sacilmasi",
	"sarapnel",
	"keskin_nisan",
	"barut_kesesi",
	"gurleyen_yelpaze",
	"zincirleme_patlama",
	"kiyamet_mermisi",
	"mermi_firtinasi",
]
