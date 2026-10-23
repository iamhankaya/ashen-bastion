class_name SimEvents
extends RefCounted
## event_log kayıt türleri ve kayıt kurucusu. Tür EKLEMEK serbest (sona); mevcut ad/alan değişmez.
## Kayıt: {"step": int, "type": StringName, …alanlar}. "step" ve "type" alan adı olarak KULLANILMAZ
## (planın kill/spawn/boss_spawn "type" alanı bu yüzden `enemy_type` adını taşır).

const SHOT := &"shot"  # gun, origin, dir, dmg, index_in_mag, is_last
const DAMAGE := &"damage"  # target, amount, raw, kind (bullet|explosion|contact|dot), source
const EXPLOSION := &"explosion"  # pos, radius, dmg, source
const KILL := &"kill"  # enemy_id, enemy_type, pos
const SPAWN := &"spawn"  # enemy_type, id, pos
const SPAWN_DROPPED := &"spawn_dropped"  # enemy_type
const RELOAD_START := &"reload_start"  # duration
const RELOAD_END := &"reload_end"
const REFUND := &"refund"  # n
const DRY_FIRE := &"dry_fire"  # gun
const GEM_DROPPED := &"gem_dropped"  # value
const GEM_COLLECTED := &"gem_collected"  # value
const LEVEL_UP := &"level_up"  # level
const CHOICES := &"choices"  # ids
const CHOICE_MADE := &"choice_made"  # skill_id
const EVOLUTION := &"evolution"  # evo_id
const BOSS_WARNING := &"boss_warning"  # kind
const BOSS_SPAWN := &"boss_spawn"  # enemy_type
const RUN_END := &"run_end"  # won
# v1.1 (eklentiler ve skor)
const PICKUP_SPAWN := &"pickup_spawn"  # kind_id, pos
const PICKUP_COLLECT := &"pickup_collect"  # kind_id, pos
const PICKUP_EXPIRE := &"pickup_expire"  # kind_id
const BUFF_START := &"buff_start"  # kind, duration, refreshed
const BUFF_END := &"buff_end"  # kind
const BOMB_PLANT := &"bomb_plant"  # pos, radius, fuse
const BOMB_EXPLODE := &"bomb_explode"  # pos, radius, hits
const SCORE := &"score"  # gain, total, mult, source (kill|evolution|lord)
const STREAK_RESET := &"streak_reset"  # reason (window|damage)

const ALL: Array[StringName] = [
	SHOT,
	DAMAGE,
	EXPLOSION,
	KILL,
	SPAWN,
	SPAWN_DROPPED,
	RELOAD_START,
	RELOAD_END,
	REFUND,
	DRY_FIRE,
	GEM_DROPPED,
	GEM_COLLECTED,
	LEVEL_UP,
	CHOICES,
	CHOICE_MADE,
	EVOLUTION,
	BOSS_WARNING,
	BOSS_SPAWN,
	RUN_END,
	PICKUP_SPAWN,
	PICKUP_COLLECT,
	PICKUP_EXPIRE,
	BUFF_START,
	BUFF_END,
	BOMB_PLANT,
	BOMB_EXPLODE,
	SCORE,
	STREAK_RESET,
]


static func make(step: int, type: StringName, fields: Dictionary = {}) -> Dictionary:
	var rec := {"step": step, "type": type}
	for k in fields.keys():
		if k != "step" and k != "type":  # kayıt kimliğini alan ezemez
			rec[k] = fields[k]
	return rec
