class_name SkillRegistry
extends RefCounted
## Beceri kimliği -> davranış sınıfı. JSON'daki `behavior` buradan çözülür.
## Sözleşme satırları önceden eklenir (alfabetik); uygulama görevleri yalnız ilgili dosyanın gövdesini doldurur.
## v2.0.2: Zyfen'in 12 davranışı (S1'de no-op gövde).

const BEHAVIORS := {
	&"ay_oragi": preload("res://scripts/sim/skills/ay_oragi.gd"),
	&"bolunen_kesik": preload("res://scripts/sim/skills/bolunen_kesik.gd"),
	&"cift_tabanca": preload("res://scripts/sim/skills/cift_tabanca.gd"),
	&"delen_ruzgar": preload("res://scripts/sim/skills/delen_ruzgar.gd"),
	&"doldurma_sacilmasi": preload("res://scripts/sim/skills/doldurma_sacilmasi.gd"),
	&"girdap": preload("res://scripts/sim/skills/girdap.gd"),
	&"gogun_mizragi": preload("res://scripts/sim/skills/gogun_mizragi.gd"),
	&"gurleyen_yelpaze": preload("res://scripts/sim/skills/gurleyen_yelpaze.gd"),
	&"hava_bicaklari": preload("res://scripts/sim/skills/hava_bicaklari.gd"),
	&"hava_cebi": preload("res://scripts/sim/skills/hava_cebi.gd"),
	&"hortum": preload("res://scripts/sim/skills/hortum.gd"),
	&"kasirga_patlamasi": preload("res://scripts/sim/skills/kasirga_patlamasi.gd"),
	&"keskin_nisan": preload("res://scripts/sim/skills/keskin_nisan.gd"),
	&"kiyamet_mermisi": preload("res://scripts/sim/skills/kiyamet_mermisi.gd"),
	&"mermi_firtinasi": preload("res://scripts/sim/skills/mermi_firtinasi.gd"),
	&"nefes_dalgasi": preload("res://scripts/sim/skills/nefes_dalgasi.gd"),
	&"ruzgar_kesigi": preload("res://scripts/sim/skills/ruzgar_kesigi.gd"),
	&"sarapnel": preload("res://scripts/sim/skills/sarapnel.gd"),
	&"seken_mermi": preload("res://scripts/sim/skills/seken_mermi.gd"),
	&"son_mermi_patlar": preload("res://scripts/sim/skills/son_mermi_patlar.gd"),
	&"tufan": preload("res://scripts/sim/skills/tufan.gd"),
	&"yelpaze_atis": preload("res://scripts/sim/skills/yelpaze_atis.gd"),
	&"zincirleme_patlama": preload("res://scripts/sim/skills/zincirleme_patlama.gd"),
}
