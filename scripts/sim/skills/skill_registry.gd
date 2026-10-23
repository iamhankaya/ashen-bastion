class_name SkillRegistry
extends RefCounted
## Beceri kimliği -> davranış sınıfı. JSON'daki `behavior` buradan çözülür.
## Sözleşme 12 satırı önceden ekler (alfabetik); uygulama görevleri yalnız ilgili dosyanın gövdesini doldurur.

const BEHAVIORS := {
	&"cift_tabanca": preload("res://scripts/sim/skills/cift_tabanca.gd"),
	&"dinamit": preload("res://scripts/sim/skills/dinamit.gd"),
	&"doldurma_sacilmasi": preload("res://scripts/sim/skills/doldurma_sacilmasi.gd"),
	&"gurleyen_yelpaze": preload("res://scripts/sim/skills/gurleyen_yelpaze.gd"),
	&"keskin_nisan": preload("res://scripts/sim/skills/keskin_nisan.gd"),
	&"kiyamet_mermisi": preload("res://scripts/sim/skills/kiyamet_mermisi.gd"),
	&"mermi_firtinasi": preload("res://scripts/sim/skills/mermi_firtinasi.gd"),
	&"sarapnel": preload("res://scripts/sim/skills/sarapnel.gd"),
	&"seken_mermi": preload("res://scripts/sim/skills/seken_mermi.gd"),
	&"son_mermi_patlar": preload("res://scripts/sim/skills/son_mermi_patlar.gd"),
	&"yelpaze_atis": preload("res://scripts/sim/skills/yelpaze_atis.gd"),
	&"zincirleme_patlama": preload("res://scripts/sim/skills/zincirleme_patlama.gd"),
}
