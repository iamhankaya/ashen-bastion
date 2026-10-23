class_name SimEvents
extends RefCounted
## event_log kayıt türleri ve kayıt kurucusu. Tür EKLEMEK serbest (sona); mevcut ad/alan değişmez.
## Kayıt: {"step": int, "type": StringName, …alanlar}

const SHOT := &"shot"  # gun, origin, dir, dmg, index_in_mag, is_last
const DAMAGE := &"damage"  # target, amount, raw, kind (bullet|explosion|contact|dot), source
const EXPLOSION := &"explosion"  # pos, radius, dmg, source
const KILL := &"kill"  # enemy_id, type, pos
const SPAWN := &"spawn"  # type, id, pos
const SPAWN_DROPPED := &"spawn_dropped"  # type
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
const BOSS_SPAWN := &"boss_spawn"  # type
const RUN_END := &"run_end"  # won

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
]


static func make(step: int, type: StringName, fields: Dictionary = {}) -> Dictionary:
	var rec := {"step": step, "type": type}
	for k in fields.keys():
		rec[k] = fields[k]
	return rec
