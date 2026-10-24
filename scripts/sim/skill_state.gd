class_name SkillState
extends RefCounted
## Yuvadaki bir becerinin çalışma durumu.

var id: StringName = &""
var level: int = 0
var def: SkillDef = null
var behavior: SkillBehavior = null
## Karaktere göre çözülmüş ikon alanı (variant ikonu ya da def.icon); yuvalar (HUD/duraklatma) bunu okur.
var icon: String = ""
